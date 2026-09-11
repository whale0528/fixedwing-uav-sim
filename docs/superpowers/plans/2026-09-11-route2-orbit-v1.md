# 路线二首版（自然语言 → orbit 机动，圆航点方案）实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 让用户用一句自然语言指令（如"在训练空域中心上空顺时针绕 3 圈，半径 300 米"），驱动 `b0307.mdl` 里的固定翼 6DOF 模型完成绕圈飞行，并自动判定执行结果。

**架构：** LLM 只做参数抽取（严格 JSON、temperature=0），MATLAB 确定性层做校验/查表/轨迹生成（LLM 不算数、不生成坐标），Simulink 执行端**零改动**——生成现有 `fly_pt` 格式的圆航点（type-2 圆心机制），复用现有"航路跟踪 → 巡航制导 → BTT → 控制器 → 6DOF"链路。

**技术栈：** MATLAB R2025b（matlab.unittest、webwrite、jsondecode）+ Simulink/Stateflow（b0307.mdl，不改动）+ DeepSeek API（OpenAI 兼容 chat/completions）。

---

## 首版关键决策（有分歧时以本节为准）

| 决策 | 结论 | 理由 |
|---|---|---|
| 方案 A 还是 B | **A（航点），圆用正多边形逼近（48 边/圈，全部直线段）** | 实测发现 `fly_phase` 的圆弧切换（扫角 + mod 卷绕 + 0.01 rad 提前量）在长弧串联下不可靠（整圈跳过/方向反转）；直线切换是位置判定且被原任务证明鲁棒。B（standoff 制导律）留作阶段二 |
| 飞行速度 | **固定 34 m/s（配平速度），不取 LLM 给的速度** | 控制器增益在 34 m/s 配平点设计，变速需重配平/增益调度（阶段二） |
| 绕圈半径下限 | **1600 m**（巡航制导 P 通道稳态上限 0.075 g → 34 m/s 最小可跟踪半径 ≈1573 m），演示用 **2000 m** | 实测 300 m 圆必然失稳：需 0.39 g 过载，制导稳态最多给 0.075 g（kdy=0.005 × 侧偏饱和 ±15 m） |
| 平飞高度 | **固定 z=300**（与现有 `fly_planfjy.mat` 的 `pz=300` 约定一致） | v1 不引入高度剖面的新问题 |
| 多轮消歧 | **不做，单轮 + `assumptions` 列表** | 多轮对话是独立难度，留阶段二 |
| 圈数簿记 | 每圈 **48 个多边形顶点**（7.5°/边，弦矢高 4.3 m，弦长 262 m），圈间自然衔接 | 无圆弧簿记；实测绕圈 RMSE ≈10 m |
| 坐标系 | 沿用现有约定：fly_pt 行 = `[x_north, y_east, z, type, info]`，方位角 θ = atan2(E−Ec, N−Nc) | 与 `fly_phase`、`dubins_path_planning.m` 一致 |
| 演示地标 | "训练空域中心" (8000, 2000)，另把 `raw_obs` 的 4 个圆柱障碍记作塔A–D | (8000,2000) 距所有障碍 >3.9 km，r=2000 绕圈 + 切入路径均安全 |

**现有接口约定（从代码中确认，改动即破坏兼容）：**

- `fly_pt` 行格式：type=1 直线段终点（info=0）；type=2 且 info∈{1,2} 为圆弧**起点**行（1=CW/右转/θ递减，2=CCW/左转/θ递增）；type=2 且 info>2 为**圆心**行（info=半径）；终止行 `[x,y,z,-10000,-10000]`。
- "已过滤"格式（`fly_planfjy.mat` 里的实际形态）：圆弧终点行与下一段起点行合并为一行（同坐标、type 2），每段圆弧 = 起点行 + 圆心行，末段圆弧另有 type-1 终点行。
- `fly_phase` 圆弧切换：CW `total_sweep=mod(θe−θx,2π)`，CCW `total_sweep=mod(θx−θe,2π)`；相邻行距离 <0.5 m 自动跳过。
- 模型通过 Constant 块（Value=`fly_pt`）从 **base 工作区**读取航点（`init.m` 里 `load('fly_planfjy.mat')`）。

---

## 文件结构

**创建：**

| 文件 | 职责 |
|---|---|
| `+dubins/core.m` | Dubins 最短路径求解（从 `dubins_path_planning.m` 局部函数提取） |
| `+dubins/words.m` | LSL/RSR/LSR/RSL 四种 word 的参数求解（同上提取） |
| `+dubins/interp_seg.m` | 单段（S/L/R）几何插值（同上提取） |
| `+dubins/append_segments.m` | 把 Dubins 路径转为航点行（照搬 `append_dubins_path`，行为不变，含圆弧终点行） |
| `+dubins/filter_waypoints.m` | 航点过滤：合并坐标重合的圆弧起点行、清除 <40 m 杂点、保留圆心行（照搬 `dubins_path_planning.m` 36–63 行） |
| `landmarks.xlsx` | 地标表：name / xn / xe / alt 四列 |
| `check_orbit_params.m` | 确定性校验层：schema 检查、范围检查、默认值注入、坐标查表（LLM 输出 → 规范化 params 结构体） |
| `make_orbit_plan.m` | params → 切入 Dubins + N 圈圆 + 切出直线 的 `fly_pt` 航点表 |
| `check_orbit_flight.m` | 仿真输出 → 实际圈数/半径 RMSE/方向/完成判定 |
| `run_orbit_sim.m` | params → 生成航点 → 写入 base 工作区 → `sim('b0307')` → 判定（LLM 无关，供测试与演示复用） |
| `llm2orbit.m` | 自然语言 → LLM 抽取（webwrite 调 DeepSeek + 重试） |
| `parse_llm_json.m` | 解析 LLM 回复中的 JSON 文本（独立纯函数，供离线测试直接调用） |
| `run_orbit_demo.m` | 端到端演示脚本：指令 → LLM → 校验 → 仿真 → 报告（脚本，与现有 `dubins_path_planning.m` 风格一致） |
| `tests/test_check_orbit_params.m` | check_orbit_params 单元测试 |
| `tests/test_make_orbit_plan.m` | make_orbit_plan 几何测试 |
| `tests/test_parse_llm_json.m` | parse_llm_json 离线测试（fixture 字符串内置） |
| `llm_key.txt` | DeepSeek API key（**不入库**，加入 .gitignore） |

**修改：**

| 文件 | 改动 |
|---|---|
| `dubins_path_planning.m` | 局部函数改为调用 `+dubins` 包；行为不变（回归对比 fly_planfjy.mat） |
| `.gitignore` | 追加 `llm_key.txt`（详见任务 2） |
| `UAV与LLM两条技术路线总结.md` | 任务 8 勾销待办（方案 A/B 决定、模型结构确认） |

**不改：** `b0307.mdl`（模型零改动是本计划的核心卖点，任何任务都不得动它）。

---

## 前提条件

- MATLAB R2025b + Simulink/Stateflow（现成，b0307 可跑，accelerator 模式）；
- 一个活跃的 MATLAB 会话（当前 MCP 未连接，需先启动 MATLAB）；
- DeepSeek API key（任务 6 起需要；任务 0–5 完全离线）；
- 网络可达 `https://api.deepseek.com`（任务 6 起需要）。

---

## 任务 0：基线回归——确认现有管线能跑

**文件：** 无改动（只验证）。

- [ ] **步骤 1：跑通现有管线**（MATLAB 命令窗口，当前目录 `F:\练习`）

```matlab
run Astar.m            % 生成 feasible_pts.mat，并在 base 工作区留下 px, py
run dubins_path_planning.m   % 生成 fly_planfjy.mat
run init.m             % clear all + 载入气动/控制器/目标 + 载入 fly_planfjy.mat
out = sim('b0307');    % accelerator 模式
run plotmake.m         % 3D 截击轨迹图
```

预期：`plotmake` 画出飞行器/目标 3D 轨迹，命令窗打印脱靶量；无报错。

- [ ] **步骤 2：留基线快照**

```matlab
save('baseline_fly_plan.mat', 'fly_pt', 'num_fly_pt');
```

- [ ] **步骤 3：确认 git 状态干净**

```bash
git status   # 预期：仅新增 baseline_fly_plan.mat（如不想提交，可加 .gitignore）
```

- [ ] **步骤 4：Commit（如有快照文件）**

```bash
git add baseline_fly_plan.mat && git commit -m "test: 基线 fly_planfjy 快照（路线二开发前）"
```

---

## 任务 1：提取 Dubins 工具为 `+dubins` 包（DRY，供 make_orbit_plan 复用）

**文件：**
- 创建：`+dubins/core.m`、`+dubins/words.m`、`+dubins/interp_seg.m`、`+dubins/append_segments.m`、`+dubins/filter_waypoints.m`
- 修改：`dubins_path_planning.m`（调用点 + 删除局部函数与内联过滤逻辑）

- [ ] **步骤 1：创建 `+dubins/words.m`**（内容照抄现有 `dubins_words` 局部函数）

```matlab
function [ok, t, p, q] = words(alpha, beta, d, type)
% DUBINS.WORDS LSL/RSR/LSR/RSL 四种 word 的弧长参数求解
% 提取自 dubins_path_planning.m 的局部函数 dubins_words，逻辑未改动
    ok = false; t=0; p=0; q=0; ca=cos(alpha); sa=sin(alpha); cb=cos(beta); sb=sin(beta); cab=cos(alpha-beta);
    switch type
        case 'LSL', p2=2+d^2-2*cab+2*d*(sa-sb); if p2>=0, p=sqrt(p2); t=mod(-alpha+atan2(cb-ca,d+sa-sb),2*pi); q=mod(beta-atan2(cb-ca,d+sa-sb),2*pi); ok=true; end
        case 'RSR', p2=2+d^2-2*cab+2*d*(sb-sa); if p2>=0, p=sqrt(p2); t=mod(alpha-atan2(ca-cb,d-sa+sb),2*pi); q=mod(-beta+atan2(ca-cb,d-sa+sb),2*pi); ok=true; end
        case 'LSR', p2=-2+d^2+2*cab+2*d*(sa+sb); if p2>=0, p=sqrt(p2); t=mod(-alpha+atan2(-ca-cb,d+sa+sb)-atan2(-2,p),2*pi); q=mod(-beta+atan2(-ca-cb,d+sa+sb)-atan2(-2,p),2*pi); ok=true; end
        case 'RSL', p2=-2+d^2+2*cab-2*d*(sa+sb); if p2>=0, p=sqrt(p2); t=mod(alpha-atan2(ca+cb,d-sa-sb)+atan2(2,p),2*pi); q=mod(beta-atan2(ca+cb,d-sa-sb)+atan2(2,p),2*pi); ok=true; end
    end
end
```

- [ ] **步骤 2：创建 `+dubins/core.m`**

```matlab
function path = core(q0, q1, rho)
% DUBINS.CORE 两姿态间最短 Dubins 路径（LSL/RSR/LSR/RSL 取最短）
% 提取自 dubins_path_planning.m 的局部函数 dubins_core，逻辑未改动
    dx = q1(1) - q0(1); dy = q1(2) - q0(2); d = sqrt(dx^2 + dy^2)/rho;
    phi = atan2(dy, dx); alpha = mod(q0(3)-phi, 2*pi); beta = mod(q1(3)-phi, 2*pi);
    best_c = inf; best_p = []; types = {'LSL','RSR','LSR','RSL'};
    for i = 1:4
        [ok,t,p,q] = dubins.words(alpha,beta,d,types{i});
        if ok && (t+p+q) < best_c, best_c = t+p+q; best_p = struct('type',types{i},'t',t,'p',p,'q',q); end
    end
    path.valid = ~isempty(best_p);
    if path.valid, path.q0 = q0; path.param = best_p; end
end
```

- [ ] **步骤 3：创建 `+dubins/interp_seg.m`**

```matlab
function q_next = interp_seg(q_start, s_norm, type, rho)
% DUBINS.INTERP_SEG 单段（S/L/R）几何插值
% 提取自 dubins_path_planning.m 的局部函数 interpolate_seg_global，逻辑未改动
    x = q_start(1); y = q_start(2); th = q_start(3);
    s = s_norm * rho;
    if type == 'L', qn = [sin(s/rho), 1-cos(s/rho), s/rho];
    elseif type == 'R', qn = [sin(s/rho), -(1-cos(s/rho)), -s/rho];
    else, qn = [s/rho, 0, 0]; end
    q_next = [x + rho*(qn(1)*cos(th) - qn(2)*sin(th)), y + rho*(qn(1)*sin(th) + qn(2)*cos(th)), th + qn(3)];
end
```

- [ ] **步骤 4：创建 `+dubins/append_segments.m`**（**照搬** `append_dubins_path`，只改函数名与调用方式，逻辑一字不动——回归对比要求逐位一致）

```matlab
function fly_pt = append_segments(fly_pt, q1, path, pz_val, rho)
% DUBINS.APPEND_SEGMENTS 把一条 Dubins 路径转成航点行
% 照搬 dubins_path_planning.m 的局部函数 append_dubins_path（含圆弧终点行），行为不变。
% 行格式：[x_north, y_east, z, type, info]；type=1 直线终点；type=2+info∈{1,2} 圆弧起点(1=CW,2=CCW)；
%         type=2+info>2 圆心行(info=半径)。终点行的合并交给 dubins.filter_waypoints。
    params = [path.param.t, path.param.p, path.param.q];
    types = path.param.type;
    curr_q = path.q0;

    for j = 1:3
        seg_len = params(j) * rho;

        if seg_len < 34 && types(j) ~= 'S'
            curr_q = dubins.interp_seg(curr_q, params(j), types(j), rho);
            continue;
        end

        if types(j) == 'S'
            curr_q = dubins.interp_seg(curr_q, params(j), 'S', rho);
            if norm(fly_pt(end,1:2) - curr_q(1:2)) > 10
                fly_pt = [fly_pt; curr_q(1), curr_q(2), pz_val, 1, 0];
            end
        else
            dir_type = (types(j) == 'L')*2 + (types(j) == 'R')*1;
            if types(j) == 'L'
                xc = curr_q(1) + rho * cos(curr_q(3) + pi/2);
                yc = curr_q(2) + rho * sin(curr_q(3) + pi/2);
            else
                xc = curr_q(1) + rho * cos(curr_q(3) - pi/2);
                yc = curr_q(2) + rho * sin(curr_q(3) - pi/2);
            end
            fly_pt = [fly_pt; curr_q(1), curr_q(2), pz_val, 2, dir_type];
            fly_pt = [fly_pt; xc, yc, pz_val, 2, rho];
            curr_q = dubins.interp_seg(curr_q, params(j), types(j), rho);
            fly_pt = [fly_pt; curr_q(1), curr_q(2), pz_val, 1, 0];
        end
    end

    if norm(fly_pt(end,1:2) - q1(1:2)) > 1
        fly_pt = [fly_pt; q1(1), q1(2), pz_val, 1, 0];
    end
end
```

- [ ] **步骤 5：创建 `+dubins/filter_waypoints.m`**（**照搬** `dubins_path_planning.m` 36–63 行"修正后的航点过滤逻辑"）

```matlab
function fly_pt = filter_waypoints(fly_pt)
% DUBINS.FILTER_WAYPOINTS 航点过滤：合并坐标重合的圆弧起点行、清除 <40m 杂点（保留圆心行）
% 照搬 dubins_path_planning.m 36-63 行，行为不变：fly_pt 末行须为终止行 [-10000,-10000]。
    temp_pt = fly_pt(1,:);
    for k = 2:size(fly_pt,1)-1
        dist = norm(fly_pt(k,1:2) - temp_pt(end,1:2));

        % 坐标完全重合（或极近）的点
        if dist < 1e-3
            % 新点是圆弧起点(类型2，标志位1或2)，携带转向方向信息，覆盖前一个坐标相同的直线终点
            if fly_pt(k,4) == 2 && (fly_pt(k,5) == 1 || fly_pt(k,5) == 2)
                temp_pt(end,:) = fly_pt(k,:);
            end
            continue;
        end

        % 圆心点（类型2 且参数大于2(即半径)）永远保留
        is_coc = (fly_pt(k,4) == 2 && fly_pt(k,5) > 2);

        % 清除距离过近的杂点，但保留圆心
        if dist < 40 && ~is_coc
            continue;
        else
            temp_pt = [temp_pt; fly_pt(k,:)];
        end
    end

    % 加上终点
    fly_pt = [temp_pt; fly_pt(end,:)];
end
```

- [ ] **步骤 6：修改 `dubins_path_planning.m`**（`edit dubins_path_planning.m`）
  1. 第 21 行 `path = dubins_core(q0, q1, r_max);` → `path = dubins.core(q0, q1, r_max);`
  2. 第 24 行 `fly_pt = append_dubins_path(fly_pt, q0, q1, path, pz(i+1), r_max);` → `fly_pt = dubins.append_segments(fly_pt, q1, path, pz(i+1), r_max);`
  3. 第 36–63 行（"===== 修正后的航点过滤逻辑 ====="整块）删除，替换为一行 `fly_pt = dubins.filter_waypoints(fly_pt);`
  4. 第 159 行 `path = dubins_core(q0, q1, r_max);` → `path = dubins.core(q0, q1, r_max);`
  5. 第 175、182 行 `interpolate_seg_global(...)` → `dubins.interp_seg(...)`
  6. 删除脚本底部局部函数 `interpolate_seg_global`、`angdiff`、`dubins_core`、`dubins_words`、`append_dubins_path`（第 71–140 行）。

- [ ] **步骤 7：回归验证——fly_planfjy.mat 必须逐位一致**

```matlab
run Astar.m
run dubins_path_planning.m
s = load('fly_planfjy.mat');
b = load('baseline_fly_plan.mat');
isequal(s.fly_pt, b.fly_pt), isequal(s.num_fly_pt, b.num_fly_pt)
```

预期：两个 `ans` 均为 `1`。若不一致，diff 行定位差异后再修（不得直接改模型或基线）。

- [ ] **步骤 8：Commit**

```bash
git add +dubins/ dubins_path_planning.m && git commit -m "refactor: 提取 dubins 局部函数与过滤逻辑为 +dubins 包，行为不变"
```

---

## 任务 2：地标表 + 密钥忽略

**文件：**
- 创建：`landmarks.xlsx`（name / xn / xe / alt 四列）
- 修改：`.gitignore`

- [ ] **步骤 1：创建 `landmarks.xlsx`**（MATLAB 命令窗）

```matlab
name = ["塔A"; "塔B"; "塔C"; "塔D"; "训练空域中心"];
xn   = [1500; 5500; 3500; 5500; 8000];
xe   = [1500; 5000; 6500; 7500; 2000];
alt  = [800; 800; 800; 900; 0];   % 塔高供将来展示；训练空域中心为地面点
T = table(name, xn, xe, alt);
writetable(T, 'landmarks.xlsx');
```

- [ ] **步骤 2：验证读取**

```matlab
T2 = readtable('landmarks.xlsx');
assert(isequal(height(T2), 5)); assert(isequal(T2.xn(5), 8000));
```

- [ ] **步骤 3：修改 `.gitignore`**，追加两行：

```gitignore
# LLM 密钥与本地生成物
llm_key.txt
```

- [ ] **步骤 4：Commit**

```bash
git add landmarks.xlsx .gitignore && git commit -m "feat: 添加地标表（塔A-D、训练空域中心），忽略 LLM 密钥文件"
```

---

## 任务 3：圆航点生成 `make_orbit_plan.m`（TDD）

**文件：**
- 测试：`tests/test_make_orbit_plan.m`
- 创建：`make_orbit_plan.m`

- [ ] **步骤 1：写失败测试** `tests/test_make_orbit_plan.m`

```matlab
function tests = test_make_orbit_plan
    tests = functiontests(localfunctions);
end

function params = make_p
    params = struct('center', [8000 2000], 'radius_m', 300, ...
                    'direction', 'CW', 'turns', 3);
end

function testRowStructure(testCase)
    [fly_pt, num_fly_pt] = make_orbit_plan(make_p(), [0 0], deg2rad(77.8));
    testCase.verifyEqual(size(fly_pt, 2), 5);
    testCase.verifyEqual(num_fly_pt, size(fly_pt, 1));
    testCase.verifyEqual(fly_pt(end, 4:5), [-10000 -10000]);   % 终止行
    testCase.verifyEqual(fly_pt(1, 1:2), [0 0]);                % 首行=起点位置（类型取决于切入首段是直线还是圆弧）
end

function testCircleCentersAndRadius(testCase)
    [fly_pt, ~] = make_orbit_plan(make_p(), [0 0], deg2rad(77.8));
    cen = fly_pt(fly_pt(:,4)==2 & fly_pt(:,5)>2, :);            % 所有圆心行
    testCase.verifyTrue(all(cen(:,5)==300));                    % info=半径
    on_target = all(cen(:,1:2) == [8000 2000], 2);              % 圆心在目标中心的圆心行数 = 圈数
    testCase.verifyEqual(sum(on_target), 3);
end

function testCircleBearingProgression(testCase)
    p = make_p();
    [fly_pt, ~] = make_orbit_plan(p, [0 0], deg2rad(77.8));
    cen_idx = find(all(fly_pt(:,1:2) == p.center, 2));
    st_idx = cen_idx - 1;                                       % 圆弧起点行 = 圆心行的前一行
    th = atan2(fly_pt(st_idx,2)-p.center(2), fly_pt(st_idx,1)-p.center(1));
    dth = mod(diff(th), 2*pi);                                  % CW：每圈起点方位递增 ε=0.05
    testCase.verifyLessThan(max(abs(dth - 0.05)), 1e-6);
end

function testDirectionInfoCorrect(testCase)
    [fly_pt, ~] = make_orbit_plan(make_p(), [0 0], deg2rad(77.8));
    cen_idx = find(all(fly_pt(:,1:2) == [8000 2000], 2));
    testCase.verifyTrue(all(fly_pt(cen_idx-1, 5) == 1));        % CW → dir_type=1
    p2 = make_p(); p2.direction = 'CCW';
    [fly_pt2, ~] = make_orbit_plan(p2, [0 0], deg2rad(77.8));
    cen_idx2 = find(all(fly_pt2(:,1:2) == [8000 2000], 2));
    testCase.verifyTrue(all(fly_pt2(cen_idx2-1, 5) == 2));      % CCW → dir_type=2
end

function testRadiusTooSmallErrors(testCase)
    p = make_p(); p.radius_m = 200;
    testCase.verifyError(@() make_orbit_plan(p, [0 0], 0), 'make_orbit_plan:radius');
end
```

- [ ] **步骤 2：运行测试确认失败**

```matlab
runtests('tests')
```

预期：`test_make_orbit_plan` 全部 FAIL（函数不存在）。

- [ ] **步骤 3：实现 `make_orbit_plan.m`**

```matlab
function [fly_pt, num_fly_pt] = make_orbit_plan(params, start_xy, start_heading)
% MAKE_ORBIT_PLAN 生成"切入 + N 圈圆 + 切出"航点表（fly_pt 已过滤格式）
% params        : struct（与任务 5 的 check_orbit_params 输出同构；本任务测试用手工构造），字段 center(1x2)、radius_m、
%                 direction('CW'/'CCW')、turns(正整数)
% start_xy      : 当前水平位置 [x_north, y_east]（m）
% start_heading : 当前航向 psi（rad，北偏东为正）
% 输出 fly_pt    : N行x5 航点表，格式与 fly_planfjy.mat 一致：
%   [x_north, y_east, z, type, info]；type=1 直线终点；type=2+info∈{1,2} 圆弧起点(1=CW,2=CCW)；
%   type=2+info>2 圆心行(info=半径)；终止行 [.., -10000, -10000]。
% 设计要点：每圈扫角 2π-ε（ε=0.05 rad），终点行与下一圈起点行坐标重合，
% 由 dubins.filter_waypoints 合并为一行，满足 fly_phase 的切换条件 sweep >= total_sweep - 0.01。
    Vc = 34; g = 9.8; roll_max = deg2rad(30);
    r = params.radius_m; c = params.center;
    r_min = Vc^2 / (g * tan(roll_max));
    if r < 1.2*r_min
        error('make_orbit_plan:radius', '半径 %.0f m 小于安全下限 %.0f m', r, 1.2*r_min);
    end
    if params.turns ~= round(params.turns) || params.turns < 1 || params.turns > 50
        error('make_orbit_plan:turns', '圈数 %g 需为 [1,50] 内整数', params.turns);
    end
    dir_type = 2*strcmpi(params.direction,'CCW') + 1*strcmpi(params.direction,'CW');
    if dir_type == 0, error('make_orbit_plan:direction', 'direction 必须是 CW 或 CCW'); end
    sgn = 1 - 2*(dir_type == 1);      % CCW=+1（方位角递增），CW=-1
    eps = 0.05;                       % 每圈航点簿记裕量 (rad)
    z = 300;                          % 与现有 fly_planfjy 相同的平飞高度约定

    % ---- 1) 切入：Dubins 从起点到圆上最近方位切点（rho=r，曲率连续）----
    th_near = atan2(start_xy(2) - c(2), start_xy(1) - c(1));
    p_entry = c + r*[cos(th_near), sin(th_near)];
    psi_entry = th_near + sgn*pi/2;                           % 切向航向
    dpath = dubins.core([start_xy, start_heading], [p_entry, psi_entry], r);
    if ~dpath.valid, error('make_orbit_plan:dubins', 'Dubins 切入无解'); end

    fly_pt = [start_xy, z, 1, 0];                             % 首行：当前位置（与现有格式一致）
    fly_pt = dubins.append_segments(fly_pt, [p_entry, psi_entry], dpath, z, r);

    % ---- 2) N 圈圆：每圈 2π-ε；终点行与下一圈起点行坐标重合，过滤时合并 ----
    th0 = th_near;                                            % 第 1 圈起点方位
    for k = 1:params.turns
        th_s = th0 - sgn*(k-1)*eps;                           % 本圈起点方位
        th_x = th_s + sgn*(2*pi - eps);                       % 本圈终点方位
        p_s = c + r*[cos(th_s), sin(th_s)];
        p_x = c + r*[cos(th_x), sin(th_x)];
        fly_pt = [fly_pt; p_s, z, 2, dir_type; c, z, 2, r; p_x, z, 1, 0];
    end
    th_last = th0 - sgn*params.turns*eps;                     % 末圈终点方位
    p_last = c + r*[cos(th_last), sin(th_last)];

    % ---- 3) 切出直线 500 m + 终止行 ----
    psi_exit = th_last + sgn*pi/2;
    p_out = p_last + 500*[cos(psi_exit), sin(psi_exit)];
    fly_pt = [fly_pt; p_out, z, 1, 0; p_out(1), p_out(2), z, -10000, -10000];

    % ---- 4) 过滤合并（重合的终点行/起点行 → 单行；清杂点；保留圆心行）----
    fly_pt = dubins.filter_waypoints(fly_pt);
    num_fly_pt = size(fly_pt, 1);
end
```

- [ ] **步骤 4：运行测试确认通过**

```matlab
runtests('tests')
```

预期：`test_make_orbit_plan` 5 个用例全部 PASS。

- [ ] **步骤 5：Commit**

```bash
git add tests/test_make_orbit_plan.m make_orbit_plan.m && git commit -m "feat: 圆航点生成 make_orbit_plan（切入 Dubins + N圈 2π-ε + 切出）"
```

---

## 任务 4：仿真执行与结果判定（模型零改动，方向约定实测）

**文件：**
- 创建：`check_orbit_flight.m`、`run_orbit_sim.m`
- 测试：`tests/test_check_orbit_flight.m`（合成数据，不跑仿真）

- [ ] **步骤 1：实现 `check_orbit_flight.m`**

```matlab
function report = check_orbit_flight(out, params)
% CHECK_ORBIT_FLIGHT 从仿真输出判定 orbit 执行结果
% out.simout 约定（同 plotmake.m）：Data(:,1)=x_north, Data(:,2)=x_east, Data(:,3)=x_down
    report = struct('turns', 0, 'radius_rmse', NaN, 'direction', '', ...
                    'bank_max_deg', NaN, 'complete', false);
    xn = out.simout.Data(:,1); xe = out.simout.Data(:,2);
    c = params.center; r = params.radius_m;
    d = hypot(xn - c(1), xe - c(2));
    in_band = abs(d - r) <= 0.3*r;
    if ~any(in_band), return; end
    th = unwrap(atan2(xe(in_band) - c(2), xn(in_band) - c(1)));
    report.turns = (max(th) - min(th)) / (2*pi);
    report.radius_rmse = sqrt(mean((d(in_band) - r).^2));
    report.direction = ternary(mean(diff(th)) > 0, 'CCW', 'CW');
    if isfield(out, 'phi')
        report.bank_max_deg = max(abs(out.phi.Data)) * 180/pi;
    end
    report.complete = report.turns >= params.turns - 0.1 && report.radius_rmse <= 0.1*r;
end

function r = ternary(cond, a, b)
    if cond, r = a; else, r = b; end
end
```

- [ ] **步骤 2：实现 `run_orbit_sim.m`**

```matlab
function report = run_orbit_sim(params, start_xy, start_heading, stop_time)
% RUN_ORBIT_SIM params → 圆航点 → base 工作区 → sim('b0307') → 判定（与 LLM 无关）
    arguments
        params (1,1) struct
        start_xy (1,2) double
        start_heading (1,1) double
        stop_time (1,1) double = 600
    end
    [fly_pt, num_fly_pt] = make_orbit_plan(params, start_xy, start_heading);
    save('fly_planfjy.mat', 'fly_pt', 'num_fly_pt');   % 持久化，与现有工作流兼容
    assignin('base', 'fly_pt', fly_pt);                % 模型 Constant 块读 base 工作区
    assignin('base', 'num_fly_pt', num_fly_pt);
    load_system('b0307');                              % set_param 前必须先载入模型
    set_param('b0307', 'StopTime', num2str(stop_time));
    out = sim('b0307');
    assignin('base', 'out', out);                      % plotmake 脚本读 base 工作区的 out
    report = check_orbit_flight(out, params);
end
```

- [ ] **步骤 3：写判定函数的合成数据测试** `tests/test_check_orbit_flight.m`

```matlab
function tests = test_check_orbit_flight
    tests = functiontests(localfunctions);
end

function out = synth_out(c, r, turns)
% 合成一个绕点 c、半径 r 的理想圆轨迹输出（turns 圈，方位角从 0 递增）
    th = linspace(0, 2*pi*turns, 4000)';
    xn = c(1) + r*cos(th); xe = c(2) + r*sin(th);
    out = struct('simout', struct('Data', [xn, xe, zeros(size(xn))]));
end

function testCountsThreeLoops(testCase)
    p = struct('center', [8000 2000], 'radius_m', 300, 'turns', 3);
    out = synth_out(p.center, p.radius_m, 3);
    rep = check_orbit_flight(out, p);
    testCase.verifyEqual(round(rep.turns, 2), 3);
    testCase.verifyLessThan(rep.radius_rmse, 1e-6);
    testCase.verifyTrue(rep.complete);
    testCase.verifyEqual(rep.direction, 'CCW');
end

function testDirectionCW(testCase)
    p = struct('center', [8000 2000], 'radius_m', 300, 'turns', 1);
    th = linspace(0, -2*pi, 4000)';    % 方位角递减 = CW
    xn = p.center(1) + 300*cos(th); xe = p.center(2) + 300*sin(th);
    out = struct('simout', struct('Data', [xn, xe, zeros(size(xn))]));
    rep = check_orbit_flight(out, p);
    testCase.verifyEqual(rep.direction, 'CW');
end
```

- [ ] **步骤 4：运行测试确认通过**

```matlab
runtests('tests')
```

预期：`test_check_orbit_flight` 3 个用例全部 PASS。

- [ ] **步骤 5：实测 a——1 圈 CW 方向约定验证**（MATLAB 命令窗，需活跃 MATLAB 会话）

```matlab
init;
p = struct('center', [8000 2000], 'radius_m', 300, 'direction', 'CW', 'turns', 1);
rep = run_orbit_sim(p, [x_0, y_0], psi_0, 600);
rep   % 预期 rep.direction == 'CW' 且 rep.turns 在 0.9~1.1 之间
```

预期：`rep.complete == true`。若 `direction == 'CCW'`（飞机实际反向绕圈）或 turns≈0（未锁上圆），说明 dir_type/sgn 映射与 fly_phase 约定相反——修 `make_orbit_plan.m` 的 `dir_type` 定义，重新跑直到通过。**这是本计划唯一需要实测校准的约定点，不得跳过。**

- [ ] **步骤 6：实测 b——3 圈完整飞行 + 轨迹图**

```matlab
init;
p = struct('center', [8000 2000], 'radius_m', 300, 'direction', 'CW', 'turns', 3);
rep = run_orbit_sim(p, [x_0, y_0], psi_0, 600);
fprintf('圈数 %.2f / 3, RMSE %.1f m, 完成 %d\n', rep.turns, rep.radius_rmse, rep.complete);
plotmake;
```

预期：`rep.complete == true`，`rep.turns ≈ 3`，RMSE 在风扰 0 时 < 10 m 量级；轨迹图可见切入弧线 + 3 圈圆 + 切出直线。若 RMSE 大，先检查控制器/制导是否受风场默认值影响（init.m 里 W_north/W_east/W_down 默认 0）。

- [ ] **步骤 7：Commit**

```bash
git add check_orbit_flight.m run_orbit_sim.m tests/test_check_orbit_flight.m && git commit -m "feat: 仿真执行与结果判定（check_orbit_flight/run_orbit_sim），CW/CCW 约定实测通过"
```

---

## 任务 5：确定性校验层 `check_orbit_params.m`（TDD）

**文件：**
- 测试：`tests/test_check_orbit_params.m`
- 创建：`check_orbit_params.m`

- [ ] **步骤 1：写失败测试** `tests/test_check_orbit_params.m`

```matlab
function tests = test_check_orbit_params
    tests = functiontests(localfunctions);
end

function lm = make_lm
    lm = struct('name', ["塔A"; "训练空域中心"], 'xn', [1500; 8000], 'xe', [1500; 2000]);
end

function testValidParams(testCase)
    raw = struct('action','orbit','center_ref','训练空域中心','radius_m',300, ...
                 'alt_m',300,'direction','CW','turns',3,'speed_ms',34, ...
                 'assumptions',{{"用户未说退出行为"}});
    [p, issues] = check_orbit_params(raw, make_lm());
    testCase.verifyTrue(p.ok);
    testCase.verifyEqual(p.center, [8000 2000]);
    testCase.verifyEqual(p.turns, 3);
    testCase.verifyEqual(p.direction, 'CW');
    testCase.verifyEmpty(issues);
end

function testWrongActionAborts(testCase)
    raw = struct('action','goto');
    [p, issues] = check_orbit_params(raw, make_lm());
    testCase.verifyFalse(p.ok);
    testCase.verifyTrue(any(contains(issues, 'action')));
end

function testUnknownLandmarkAborts(testCase)
    raw = struct('action','orbit','center_ref','不存在的地标');
    [p, issues] = check_orbit_params(raw, make_lm());
    testCase.verifyFalse(p.ok);
    testCase.verifyTrue(any(contains(issues, '未知地标')));
end

function testLLMMustNotGiveCoordinates(testCase)
    raw = struct('action','orbit','center_ned',[100 200 300]);
    [p, issues] = check_orbit_params(raw, make_lm());
    testCase.verifyFalse(p.ok);
    testCase.verifyTrue(any(contains(issues, '坐标')));
end

function testMissingFieldsGetDefaults(testCase)
    raw = struct('action','orbit','center_ref','训练空域中心');
    [p, issues] = check_orbit_params(raw, make_lm());
    testCase.verifyTrue(p.ok);
    testCase.verifyEqual(p.radius_m, 300);
    testCase.verifyEqual(p.turns, 1);
    testCase.verifyEqual(p.direction, 'CW');
    testCase.verifyFalse(isempty(issues));   % 有缺省注入提示
end

function testRadiusTooSmallClamps(testCase)
    raw = struct('action','orbit','center_ref','训练空域中心','radius_m',200);
    [p, issues] = check_orbit_params(raw, make_lm());
    testCase.verifyTrue(p.ok);
    testCase.verifyEqual(p.radius_m, 250);
    testCase.verifyTrue(any(contains(issues, '坡度约束')));
end

function testSpeedOtherThanTrimWarns(testCase)
    raw = struct('action','orbit','center_ref','训练空域中心','speed_ms',15);
    [p, issues] = check_orbit_params(raw, make_lm());
    testCase.verifyTrue(p.ok);
    testCase.verifyEqual(p.speed_ms, 34);
    testCase.verifyTrue(any(contains(issues, '34')));
end
```

- [ ] **步骤 2：运行测试确认失败**

```matlab
runtests('tests')
```

预期：`test_check_orbit_params` 全部 FAIL，报错 `Unrecognized function or variable 'check_orbit_params'`。

- [ ] **步骤 3：实现 `check_orbit_params.m`**

```matlab
function [params, issues] = check_orbit_params(raw, landmarks)
% CHECK_ORBIT_PARAMS LLM 原始 JSON → 规范化 orbit 参数（确定性校验层）
% 原则：LLM 不算数、不生成坐标；这里做 schema 检查、坐标查表、范围检查与默认值注入。
% raw       : struct，LLM 返回的 JSON 解码结果
% landmarks : struct/table，含 name(字符串数组)、xn、xe 字段
% params    : struct，含 center(1x2)、radius_m、alt_m、direction('CW'/'CCW')、
%             turns(整数)、speed_ms、assumptions(cell)、ok(logical，可否执行)
% issues    : cellstr，人类可读的问题列表（ok=false 时为致命问题）
    params = struct('center', [nan nan], 'radius_m', 300, 'alt_m', 300, ...
                    'direction', 'CW', 'turns', 1, 'speed_ms', 34, ...
                    'assumptions', {{}}, 'ok', false);
    issues = {};

    if ~isstruct(raw) || ~isfield(raw, 'action')
        issues{end+1} = '缺少 action 字段'; return;
    end
    if ~strcmpi(raw.action, 'orbit')
        issues{end+1} = sprintf('action 必须是 orbit，收到: %s', raw.action); return;
    end

    % ---- 1) center：只能查表，禁止 LLM 直接给坐标 ----
    if isfield(raw, 'center_ned') && ~isempty(raw.center_ned)
        issues{end+1} = 'LLM 不得直接生成坐标，center 必须用地标名 (center_ref)';
        return;
    end
    if ~isfield(raw, 'center_ref') || isempty(raw.center_ref)
        issues{end+1} = '缺少 center_ref（地标名）'; return;
    end
    idx = find(strcmpi(string(landmarks.name), string(raw.center_ref)), 1);
    if isempty(idx)
        issues{end+1} = sprintf('未知地标: %s', raw.center_ref); return;
    end
    params.center = [landmarks.xn(idx), landmarks.xe(idx)];

    % ---- 2) 数值参数：类型检查 + 默认值注入（缺失/空一律用默认）----
    defaults = struct('radius_m', 300, 'alt_m', 300, 'turns', 1, 'speed_ms', 34);
    for fn = fieldnames(defaults)'
        key = fn{1};
        if isfield(raw, key) && ~isempty(raw.(key))
            v = raw.(key);
            if ~(isnumeric(v) && isscalar(v) && isfinite(v) && isreal(v))
                issues{end+1} = sprintf('%s 必须是有限实数标量，已用默认值 %.0f', key, defaults.(key));
                v = defaults.(key);
            end
            params.(key) = v;
        else
            issues{end+1} = sprintf('%s 缺失，已用默认值 %.0f', key, defaults.(key));
        end
    end

    % ---- 3) 范围检查与钳制（LLM 不算数，这里算）----
    if params.speed_ms ~= 34
        issues{end+1} = sprintf('速度 %g m/s 偏离配平点，v1 固定 34 m/s', params.speed_ms);
        params.speed_ms = 34;
    end
    if params.radius_m < 250
        issues{end+1} = sprintf('半径 %g m 不满足 34 m/s 下 30°坡度约束（下限 250 m），已钳制为 250 m', params.radius_m);
        params.radius_m = 250;
    elseif params.radius_m > 2000
        issues{end+1} = sprintf('半径 %g m 超出上限 2000 m，已钳制为 2000 m', params.radius_m);
        params.radius_m = 2000;
    end
    if params.turns ~= round(params.turns) || params.turns < 1 || params.turns > 50
        issues{end+1} = sprintf('圈数 %g 需为 [1,50] 内整数，已钳制', params.turns);
        params.turns = max(1, min(50, round(params.turns)));
    end
    if params.alt_m ~= 300
        issues{end+1} = sprintf('高度 %g m：v1 固定 300 m 平飞', params.alt_m);
        params.alt_m = 300;
    end

    % ---- 4) direction 枚举 ----
    if isfield(raw, 'direction') && any(strcmpi(raw.direction, {'CW', 'CCW'}))
        params.direction = upper(string(raw.direction));
    else
        issues{end+1} = 'direction 缺失/非法，默认 CW';
    end

    % ---- 5) assumptions 透传 ----
    if isfield(raw, 'assumptions') && ~isempty(raw.assumptions)
        params.assumptions = raw.assumptions;
    end

    params.ok = true;
end
```

- [ ] **步骤 4：运行测试确认通过**

```matlab
runtests('tests')
```

预期：7 个用例全部 PASS。

- [ ] **步骤 5：Commit**

```bash
git add tests/test_check_orbit_params.m check_orbit_params.m && git commit -m "feat: 确定性校验层 check_orbit_params（schema/查表/范围/默认值）"
```

---

## 任务 6：LLM 抽取 `llm2orbit.m`（离线可测）

**文件：**
- 测试：`tests/test_parse_llm_json.m`
- 创建：`parse_llm_json.m`、`llm2orbit.m`（调用 `parse_llm_json`，不内置局部函数——局部函数无法被测试文件调用）
- 创建：`llm_key.txt`（手工填写，不入库）

- [ ] **步骤 1：写失败测试** `tests/test_parse_llm_json.m`

```matlab
function tests = test_parse_llm_json
    tests = functiontests(localfunctions);
end

function testValidJson(testCase)
    r = parse_llm_json('{"action":"orbit","turns":3}');
    testCase.verifyTrue(isstruct(r));
    testCase.verifyEqual(r.turns, 3);
end

function testInvalidJsonEmpty(testCase)
    testCase.verifyTrue(isempty(parse_llm_json('这不是 JSON')));
end

function testJsonWithoutActionEmpty(testCase)
    testCase.verifyTrue(isempty(parse_llm_json('{"foo":1}')));
end

function testMarkdownFenceRejected(testCase)
    % 决策：v1 不洗 markdown，交给 Retry（response_format=json_object 下罕见）
    testCase.verifyTrue(isempty(parse_llm_json('```json\n{"action":"orbit"}\n```')));
end

function testArrayPicksActionItem(testCase)
    r = parse_llm_json('[{"foo":1},{"action":"orbit","turns":2}]');
    testCase.verifyEqual(r.turns, 2);
end
```

- [ ] **步骤 2：运行测试确认失败**

```matlab
runtests('tests')
```

预期：FAIL（`parse_llm_json` 不存在）。

- [ ] **步骤 3：实现 `parse_llm_json.m` 与 `llm2orbit.m`**

先创建 `parse_llm_json.m`（独立纯函数，测试直接调用）：

```matlab
function raw = parse_llm_json(txt)
% PARSE_LLM_JSON 解析 LLM 回复中的 JSON 文本（纯函数，供离线测试）
% 返回：struct（含 action 字段）或空 []。
    raw = [];
    if ~ischar(txt) && ~isstring(txt), return; end
    try
        v = jsondecode(txt);
    catch
        return;
    end
    if isstruct(v) && isfield(v, 'action'), raw = v; end
    if isstruct(v) && numel(v) > 1              % 结构数组：取第一个含 action 的项
        has = arrayfun(@(s) isfield(s, 'action'), v);
        if any(has), raw = v(find(has, 1)); end
    end
end
```

再创建 `llm2orbit.m`：

```matlab
function raw = llm2orbit(instruction, opts)
% LLM2ORBIT 自然语言 → LLM 抽取 orbit 参数（DeepSeek，temperature=0，严格 JSON）
% 只负责"抽取"；校验交给 check_orbit_params。重试次数内拿不到合法 JSON 则报错。
    arguments
        instruction (1,:) char
        opts.Key (1,:) char = ''
        opts.KeyFile (1,:) char = 'llm_key.txt'
        opts.BaseUrl (1,:) char = 'https://api.deepseek.com/chat/completions'
        opts.Model (1,:) char = 'deepseek-chat'
        opts.Retry (1,1) double {mustBeInteger, mustBePositive} = 3
        opts.Timeout (1,1) double = 60
    end
    if isempty(opts.Key) && isfile(opts.KeyFile)
        opts.Key = strtrim(fileread(opts.KeyFile));
    end
    if isempty(opts.Key)
        error('llm2orbit:noKey', '缺少 API Key：请填写 llm_key.txt 或传入 opts.Key');
    end

    sys = ['你是无人机任务参数抽取器。把用户的自然语言指令转换成 orbit（绕圈）任务参数。' ...
           '只输出一个 JSON 对象，不要输出任何其他文字。JSON 只允许以下字段：' ...
           '{"action":"orbit","center_ref":"<地标名>","radius_m":<数字>,"alt_m":<数字>,' ...
           '"direction":"CW 或 CCW","turns":<正整数>,"speed_ms":<数字>,"assumptions":[<字符串数组>]}。' ...
           '硬性规则：' ...
           '1. center_ref 只能用地标表中的名称（塔A、塔B、塔C、塔D、训练空域中心），禁止输出坐标。' ...
           '2. 禁止做任何数值计算：半径、圈数、距离只允许照抄用户原话给出的数字，否则省略该字段。' ...
           '3. 缺失或含糊的参数不得编造：省略该字段并写入 assumptions。' ...
           '4. 飞机巡航速度固定 34 m/s，绕圈半径不得小于 250 m，所有距离单位一律为米。' ...
           '5. direction 只能是 CW（顺时针）或 CCW（逆时针）。'];

    body = struct('model', opts.Model, 'temperature', 0, ...
                  'response_format', struct('type', 'json_object'), ...
                  'messages', {{ ...
                      struct('role', 'system', 'content', sys), ...
                      struct('role', 'user',   'content', ['指令：' instruction]) }});

    wo = weboptions('RequestMethod', 'post', 'MediaType', 'application/json', ...
                    'HeaderFields', {'Authorization', ['Bearer ' opts.Key]}, ...
                    'ContentType', 'json', 'Timeout', opts.Timeout);

    last_err = '';
    for k = 1:opts.Retry
        try
            resp = webwrite(opts.BaseUrl, jsonencode(body), wo);
            if ischar(resp) || isstring(resp), resp = jsondecode(resp); end
            txt = resp.choices(1).message.content;
            raw = parse_llm_json(txt);
            if ~isempty(raw), return; end
            last_err = sprintf('第 %d 次：未返回合法 action JSON', k);
        catch ME
            last_err = sprintf('第 %d 次：%s', k, ME.message);
        end
    end
    error('llm2orbit:parse', '多次尝试后仍失败。%s', last_err);
end
```

- [ ] **步骤 4：运行测试确认通过**

```matlab
runtests('tests')
```

预期：5 个用例全部 PASS。

- [ ] **步骤 5：准备密钥文件**（手工）

在 `F:\练习\llm_key.txt` 中写入 DeepSeek API key（一行，无引号）。确认 `.gitignore` 已忽略（任务 2）。

- [ ] **步骤 6：冒烟测试（在线）**

```matlab
raw = llm2orbit('在训练空域中心上空顺时针绕 3 圈，半径 300 米');
raw
```

预期：返回含 `action=orbit`、`turns=3`、`radius_m=300` 的结构体。

- [ ] **步骤 7：Commit**

```bash
git add llm2orbit.m parse_llm_json.m tests/test_parse_llm_json.m && git commit -m "feat: LLM 参数抽取 llm2orbit（DeepSeek + JSON schema + 重试）"
```

---

## 任务 7：端到端演示 `run_orbit_demo.m`

**文件：** 创建 `run_orbit_demo.m`（脚本，与现有 `dubins_path_planning.m` 同为脚本风格）

- [ ] **步骤 1：实现 `run_orbit_demo.m`**

```matlab
% RUN_ORBIT_DEMO 端到端：自然语言 → LLM 抽取 → 确定性校验 → 圆航点 → 仿真 → 判定
% 用法：MATLAB 命令窗 cd 到本目录后 run run_orbit_demo
% 注意顺序：init 必须先跑（clear all + 气动/控制器/目标初始化），
%           之后 LLM 调用与校验层全部在 base 工作区进行。
instruction = "在训练空域中心上空顺时针绕 3 圈，半径 300 米";

init;                                    % clear all + 载入气动/控制器 + 旧 fly_plan
landmarks = readtable('landmarks.xlsx');
raw = llm2orbit(instruction);
[params, issues] = check_orbit_params(raw, landmarks);
fprintf('--- 参数校验 ---\n');
for i = 1:numel(issues), fprintf('  [issue] %s\n', issues{i}); end
if ~params.ok
    error('run_orbit_demo:params', '参数校验未通过，无法执行');
end
fprintf('  地标 -> 中心 (%.0f, %.0f) m, r=%.0f m, %s, %d 圈\n', ...
        params.center(1), params.center(2), params.radius_m, params.direction, params.turns);

report = run_orbit_sim(params, [x_0, y_0], psi_0, 600);
fprintf('--- 执行结果 ---\n');
fprintf('  实际圈数: %.2f / %d\n', report.turns, params.turns);
fprintf('  半径 RMSE: %.1f m\n', report.radius_rmse);
fprintf('  实际方向: %s\n', report.direction);
fprintf('  完成: %d\n', report.complete);
plotmake;
```

- [ ] **步骤 2：运行端到端演示**

```matlab
run run_orbit_demo
```

预期：命令窗依次输出参数校验（无致命 issue）、执行结果（`完成: 1`），并画出 3D 轨迹图。

- [ ] **步骤 3：Commit**

```bash
git add run_orbit_demo.m && git commit -m "feat: 端到端演示脚本 run_orbit_demo"
```

---

## 任务 8：说法鲁棒性测试 + 文档待办勾销

**文件：**
- 创建：`tests/llm_phrasing_cases.m`（说法清单 + 期望值，供手工批量验证）
- 修改：`UAV与LLM两条技术路线总结.md`

- [ ] **步骤 1：创建说法测试清单** `tests/llm_phrasing_cases.m`

```matlab
function cases = llm_phrasing_cases
% 说法鲁棒性测试清单：{说法, 期望关键字段}。手工或脚本逐条跑 llm2orbit + check_orbit_params。
cases = {
  '在训练空域中心上空顺时针绕 3 圈，半径 300 米',            struct('center_ref','训练空域中心','turns',3,'radius_m',300,'direction','CW');
  '绕训练空域中心转十圈',                                    struct('turns',10);
  '逆时针绕塔A转两圈',                                       struct('center_ref','塔A','turns',2,'direction','CCW');
  '在训练空域中心盘旋一会儿',                                 struct('center_ref','训练空域中心','turns',1);
  '绕训练空域中心转 3 圈，半径 200 米，速度 15 米每秒',       struct('radius_m',200,'speed_ms',15);
  '从训练空域中心出发绕大圈 3 次',                            struct('turns',3);
  '去塔B上面绕 5 圈',                                        struct('center_ref','塔B','turns',5);
  '绕圈圈圈圈',                                              struct();
  };
end
```

- [ ] **步骤 2：逐条验证并记录**（MATLAB 命令窗）

```matlab
init;
landmarks = readtable('landmarks.xlsx');
cases = llm_phrasing_cases;
for i = 1:size(cases,1)
    fprintf('\n[%d] %s\n', i, cases{i,1});
    raw = llm2orbit(cases{i,1});
    [p, issues] = check_orbit_params(raw, landmarks);
    fprintf('  ok=%d 参数: %s\n', p.ok, jsonencode(p));
    if ~isempty(issues), fprintf('  issues: %s\n', strjoin(issues, ' | ')); end
end
```

预期：前 7 条抽取正确、校验通过/正确钳制（第 5 条应被钳制 r→250、v→34 并给出 issue）；第 8 条（无意义输入）应走校验失败或 assumptions 兜底。把结果表追加到总结文档。

- [ ] **步骤 3：勾销总结文档待办**（`edit UAV与LLM两条技术路线总结.md`）

  1. "决定方案 A（航点）还是方案 B（standoff 直给制导律）作为首版" → 勾选并注明：**方案 A 已实现（make_orbit_plan.m + 现有 fly_phase），方案 B 列阶段二**；
  2. "确认现有 Simulink 模型结构（6DOF + 制导律 + 控制器）" → 勾选并注明：**b0307 = 6DOF + 巡航/末制导 + BTT + 过载/滚转控制器 + 风场 + 带 Dubins 圆弧的航路跟踪（fly_pt type-2 圆心机制），Constant 块从 base 工作区读 fly_pt**；
  3. 路线二 2.2 节的参数表加一行：**可行域约束：r ≥ 250 m @ 34 m/s（tan(30°) ≥ v²/(g·r)），v1 定速 34 m/s、定高 300 m**。

- [ ] **步骤 4：Commit**

```bash
git add tests/llm_phrasing_cases.m "UAV与LLM两条技术路线总结.md" && git commit -m "test: 说法鲁棒性清单；docs: 勾销路线二落地相关待办"
```

---

## 阶段二预览（本计划不实现，各立独立计划）

1. **方案 B**：standoff 制导律直出加速度指令 + Stateflow（切入→Orbit→退出）+ 风估计补偿（现有"风场计算"模块可注入 NED 风做对比实验）；
2. **多轮消歧**：缺失参数反问 + 退出行为确认（悬停/返航）——固定翼 v1 以"切出直线 500 m"代替；
3. **变速/增益调度**：让 LLM 给的速度真正生效（配平点增益调度或重配平）；
4. **多动作指令**（goto/巡线/orbit 组合）与任务边界反馈闭环（完成/异常 → 回 LLM）。

## 风险与对策

| 风险 | 对策 |
|---|---|
| CW/CCW 方向约定与 fly_phase 相反 | 实测 a 已验证：CW → dir_type=1 映射正确 |
| LLM 输出 JSON 不稳 | temperature=0 + response_format=json_object + 3 次重试；离线 fixture 测试覆盖解析路径 |
| 半径/速度参数不可行 | 校验层钳制（r≥1600、v=34、alt=300），issue 全量打印 |
| init.m 的 `clear all` 清掉参数 | 顺序固定：`init → llm2orbit → check → run_orbit_sim`（demo 脚本已固化） |
| 仿真发散/飞不进圆 | 已实测排除（见"实测记录"）；必要时调切入 Dubins 半径 rho 或换地标 |
| API 网络/计费 | 任务 0–5 完全离线；key 文件不入库 |
| MATLAB 外部改文件后运行旧缓存代码 | 每次改 .m 后执行 `clear functions; rehash path;`（本计划踩过两次：测试"假通过"、回放脚本"假超时"） |

## 实测记录（2026-09-11，b0307 零改动）

执行层验证按"失败 → 根因 → 修复"迭代了三轮，全部通过 MCP + SDI 信号定位：

| 轮次 | 方案 | 结果 | 根因 |
|---|---|---|---|
| 1 | r=300 m 圆弧航点 | 失败（turns 0.35、RMSE 52 m，切过圆心后飞走） | 巡航制导 P 通道稳态上限 0.075 g（kdy=0.005 × 侧偏饱和 ±15 m）< 300 m 圆所需 0.39 g；圆弧切换只看扫角不看径向误差，飞机偏离数百米仍按扫角"完成"圆弧 |
| 2 | r=2000 m 圆弧航点 | 实测 a 通过（RMSE 12.6 m），实测 b 失败 | 切入 Dubins 末段弧与绕圈圆共圆心（"骑圆"），整圈弧被 mod 卷绕瞬间跳过 |
| 3 | r=2000 m + 切向直线切入 | 实测 a 通过；实测 b 失败（turns 2.2） | fly_phase 圆弧切换带 0.01 rad 提前量，圈间点重合衔接使每圈到达时方位角已越过下一圈起点 → 偶数圈被瞬间跳过 |
| 4 | **r=2000 m + 切向直线切入 + 正多边形绕圈（48 边/圈）** | **实测 b 通过：turns 3.20、绕圈 RMSE 10.2 m、complete=1、切出精确落在切线末端** | 直线切换是位置判定（投影距离），绕开圆弧切换的全部脆弱点 |

**执行层结论：**
- 半径必须 ≥1600 m（制导稳态能力上限 0.075 g 决定），演示用 2000 m；LLM 校验层将据此钳制；
- 绕圈一律走正多边形直线段（`make_orbit_plan` 已实现，n_seg=48）；
- 切入 = Dubins 到切线上圆外 2.5r 处 + 切向直线切入；切出 = 3000 m 切线 + 终止行；
- 模型 `b0307.mdl` 全程未改动；改小半径需要调 `航向制导回路` 的 kdy/kdy_dot/饱和限（列为阶段二可选任务）。

