% TEST_MAKE_ORBIT_PLAN 绕圈航点生成检查（脚本版，F5 直接运行）
% 与原来的框架版测试（matlab.unittest）检查同一组性质，共 5 组。
% 用法：在编辑器打开本文件按 F5；或命令窗口 run('F:\练习\tests\test_make_orbit_plan.m')。
% 注意：本脚本会自动 cd 到项目根目录并刷新函数缓存，可在任意目录启动。

cd(fileparts(mfilename('fullpath')));   % 本脚本在 tests\ 下
cd('..');                               % 回到项目根 F:\练习
addpath(pwd);
clear functions;
rehash path;

R = {};   % 结果记录：'P' 通过 / 'F' 失败
fprintf('=== make_orbit_plan 检查（脚本版） ===\n');

% ---- 1. 行结构 ----
p = make_p();
[fly_pt, num_fly_pt] = make_orbit_plan(p, [0 0], deg2rad(77.8));
R = check(R, '1a. 每行 5 列',        size(fly_pt, 2) == 5);
R = check(R, '1b. num_fly_pt 与行数一致', num_fly_pt == size(fly_pt, 1));
R = check(R, '1c. 末行为终止行 [-10000 -10000]', ...
          isequal(fly_pt(end, 4:5), [-10000 -10000]));
R = check(R, '1d. 首行 = 起点 (0,0)', isequal(fly_pt(1, 1:2), [0 0]));

% ---- 2. 多边形顶点数与半径 ----
c = p.center; r = p.radius_m;
on_circle = fly_pt(:,4) == 1 & abs(hypot(fly_pt(:,1)-c(1), fly_pt(:,2)-c(2)) - r) < 0.5;
R = check(R, sprintf('2a. 圆上顶点数 ≥ %d×48（%d 圈应 144，切入段可能额外贡献）', p.turns, p.turns), ...
          sum(on_circle) >= p.turns*48);
others = find(~on_circle & fly_pt(:,4) ~= -10000);
dmin_out = inf;
for k = 1:numel(others)
    dmin_out = min(dmin_out, abs(hypot(fly_pt(others(k),1)-c(1), fly_pt(others(k),2)-c(2)) - r));
end
R = check(R, '2b. 其余航点不在圆上（切入/切出段）', dmin_out > 0.5);

% ---- 3. 顶点方位步进（CW 递减 / CCW 递增，每步 7.5°）----
n_seg = 48; dth_seg = 2*pi/n_seg;
for dir = ["CW", "CCW"]
    pd = make_p(); pd.direction = dir;
    [fpd, ~] = make_orbit_plan(pd, [0 0], deg2rad(77.8));
    rows = fpd(fpd(:,4)==1 & abs(hypot(fpd(:,1)-c(1), fpd(:,2)-c(2)) - r) < 0.5, :);
    th = atan2(rows(:,2)-c(2), rows(:,1)-c(1));
    dd = mod(diff(th) + pi, 2*pi) - pi;                      % 卷绕安全的相邻方位差
    expected = strcmp(dir,"CW")*(-dth_seg) + strcmp(dir,"CCW")*dth_seg;
    R = check(R, sprintf('3. 顶点方位步进正确（%s, 7.5°/边）', dir), ...
              max(abs(dd - expected)) < 1e-9);
end

% ---- 4. 半径低于制导可跟踪下限（调参后为 400 m）必须报错 ----
p_bad = make_p(); p_bad.radius_m = 350;
try
    make_orbit_plan(p_bad, [0 0], 0);
    R = check(R, '4. 半径 350 m 应报错', false);
catch ME
    R = check(R, '4. 半径 350 m 应报错', strcmp(ME.identifier, 'make_orbit_plan:radius'));
end

% ---- 5. 航点表必须全为直线（type=1），不得使用圆弧行 ----
% 圆弧切换（扫角+mod 卷绕）实测不可靠（整圈跳过/方向反转/滚转失控），
% 本方案已把 Dubins 弧段全部离散成短直线。
R = check(R, '5. 航点全为直线，无圆弧行（type=2 不存在）', ~any(fly_pt(:,4) == 2));

% ---- 汇总 ----
fprintf('\n=== 结果：%d 通过 / %d 失败 ===\n', sum(strcmp(R,'P')), sum(strcmp(R,'F')));
if all(strcmp(R, 'P'))
    fprintf('全部通过 ✓\n');
else
    fprintf('存在失败项，检查上面 [FAIL] 行\n');
end

% ================= 局部函数（脚本末尾） =================
function p = make_p
    p = struct('center', [8000 2000], 'radius_m', 2000, ...
               'direction', 'CW', 'turns', 3);
end

function R = check(R, name, cond)
    if cond
        R{end+1} = 'P';                     %#ok<AGROW>
        fprintf('  [PASS] %s\n', name);
    else
        R{end+1} = 'F';                     %#ok<AGROW>
        fprintf('  [FAIL] %s\n', name);
    end
end
