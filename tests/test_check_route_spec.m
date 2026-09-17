% TEST_CHECK_ROUTE_SPEC 路线校验层检查（脚本版，F5 直接运行）
% 检查 check_route_spec：把 LLM 返回的路线 JSON 变成可信动作单。
% 用法：编辑器打开本文件按 F5；或命令窗口 run('F:\练习\tests\test_check_route_spec.m')。

cd(fileparts(mfilename('fullpath')));
cd('..');
addpath(pwd);
clear functions;
rehash path;

R = {};
fprintf('=== check_route_spec 检查（脚本版） ===\n');

lm = struct('name', ["塔A"; "塔B"; "训练空域中心"], 'xn', [1500; 5500; 8000], 'xe', [1500; 5000; 2000]);

% ---- 1. 合法动作单：转正北 → 直飞 2 km → 绕训练空域中心 500 m 两圈 ----
raw = struct();
raw.segments = { ...
    struct('type', 'turn_to', 'heading_deg', 0), ...
    struct('type', 'line',    'dist_m', 2000), ...
    struct('type', 'orbit',   'center_ref', "训练空域中心", 'radius_m', 500, ...
           'direction', 'CW', 'turns', 2)};
raw.assumptions = {"用户未说退出行为"};
[plan, issues, ok] = check_route_spec(raw, lm);
R = check(R, '1a. 合法动作单通过', ok && isempty(issues));
R = check(R, '1b. 段数与类型正确', numel(plan.segments) == 3 && ...
          strcmp(plan.segments{1}{1}, 'turn_to') && strcmp(plan.segments{3}{1}, 'orbit'));
R = check(R, '1c. 地标已解析为坐标', isequal(plan.segments{3}{2}, [8000 2000]));
R = check(R, '1d. assumptions 透传', ~isempty(plan.assumptions));

% ---- 2. 未知段类型 → 致命 ----
raw = struct('segments', struct('type', 'teleport', 'x', 100));
[~, issues, ok] = check_route_spec(raw, lm);
R = check(R, '2. 未知段类型拒绝（ok=false）', ~ok && any(contains(issues, '未知段类型')));

% ---- 3. 地标不存在 → 致命 ----
raw = struct('segments', struct('type', 'orbit', 'center_ref', "不存在的地标", 'radius_m', 500, ...
                                'direction', 'CW', 'turns', 1));
[~, issues, ok] = check_route_spec(raw, lm);
R = check(R, '3. 未知地标拒绝', ~ok && any(contains(issues, '未知地标')));

% ---- 4. LLM 直接给坐标 → 致命（原则：LLM 不生成坐标）----
raw = struct('segments', struct('type', 'orbit', 'center', [3000 0], 'radius_m', 500, ...
                                'direction', 'CW', 'turns', 1));
[~, issues, ok] = check_route_spec(raw, lm);
R = check(R, '4. LLM 直接给坐标被拒绝', ~ok && any(contains(issues, '坐标')));

% ---- 5. 半径过小 → 钳制到 400 + issue ----
raw = struct('segments', struct('type', 'orbit', 'center_ref', "训练空域中心", 'radius_m', 120, ...
                                'direction', 'CW', 'turns', 1));
[plan, issues, ok] = check_route_spec(raw, lm);
R = check(R, '5. 半径 120 m 钳制到 400 m', ok && plan.segments{1}{3} == 400 && ...
          any(contains(issues, '半径')));

% ---- 6. 圈数非法 → 钳制 + issue ----
raw = struct('segments', struct('type', 'orbit', 'center_ref', "训练空域中心", 'radius_m', 500, ...
                                'direction', 'CW', 'turns', 99));
[plan, issues, ok] = check_route_spec(raw, lm);
R = check(R, '6. 圈数 99 钳制到 50', ok && plan.segments{1}{5} == 50 && any(contains(issues, '圈数')));

% ---- 7. 方向非法 → 默认 CW + issue ----
raw = struct('segments', struct('type', 'orbit', 'center_ref', "训练空域中心", 'radius_m', 500, ...
                                'direction', 'sideways', 'turns', 1));
[plan, issues, ok] = check_route_spec(raw, lm);
R = check(R, '7. 非法方向默认 CW', ok && strcmp(plan.segments{1}{4}, 'CW') && ...
          any(contains(issues, 'direction')));

% ---- 8. 段数超限 → 致命 ----
segs = repmat(struct('type', 'line', 'dist_m', 1000), 1, 15);
[~, issues, ok] = check_route_spec(struct('segments', segs), lm);
R = check(R, '8. 段数 15 超限被拒绝', ~ok && any(contains(issues, '段数')));

% ---- 9. 距离超限 → 钳制 + issue ----
raw = struct('segments', struct('type', 'line', 'dist_m', 99000));
[plan, issues, ok] = check_route_spec(raw, lm);
R = check(R, '9. 直线 99 km 钳制到 20 km', ok && plan.segments{1}{2} == 20000 && ...
          any(contains(issues, '距离')));

% ---- 10. goto 航向可为空（自由）与指定两种 ----
raw = struct();
raw.segments = { ...
    struct('type', 'goto', 'target_ref', "塔A", 'heading_deg', []), ...
    struct('type', 'goto', 'target_ref', "塔B", 'heading_deg', 90)};
[plan, ~, ok] = check_route_spec(raw, lm);
R = check(R, '10. goto 航向空=NaN、指定=90', ok && isnan(plan.segments{1}{2}(3)) && ...
          plan.segments{2}{2}(3) == 90);

% ---- 11. 空/非结构输入 → 致命 ----
[~, ~, ok1] = check_route_spec(struct(), lm);
[~, ~, ok2] = check_route_spec([], lm);
R = check(R, '11. 空输入被拒绝', ~ok1 && ~ok2);

% ---- 12. 集成：校验输出可直接喂 make_route_plan ----
raw = struct();
raw.segments = { ...
    struct('type', 'turn_to', 'heading_deg', 0), ...
    struct('type', 'line', 'dist_m', 1500), ...
    struct('type', 'orbit', 'center_ref', "训练空域中心", 'radius_m', 600, ...
           'direction', 'CCW', 'turns', 1)};
[plan, ~, ok] = check_route_spec(raw, lm);
try
    [fp, n, L] = make_route_plan(plan.segments, [0 0 0], struct('turn_radius', 600));
    R = check(R, sprintf('12. 校验输出可直接生成航点（%d 行, %.0f m）', n, L), ...
              ok && n > 40 && L > 8000);
catch ME
    R = check(R, '12. 校验输出可直接生成航点', false);
    fprintf('      错误: %s\n', ME.message);
end

% ---- 汇总 ----
fprintf('\n=== 结果：%d 通过 / %d 失败 ===\n', sum(strcmp(R,'P')), sum(strcmp(R,'F')));
if all(strcmp(R, 'P'))
    fprintf('全部通过 ✓\n');
else
    fprintf('存在失败项，检查上面 [FAIL] 行\n');
end

% ================= 局部函数 =================
function R = check(R, name, cond)
    if cond
        R{end+1} = 'P';                     %#ok<AGROW>
        fprintf('  [PASS] %s\n', name);
    else
        R{end+1} = 'F';                     %#ok<AGROW>
        fprintf('  [FAIL] %s\n', name);
    end
end
