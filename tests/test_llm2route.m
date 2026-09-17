% TEST_LLM2ROUTE 抽取层检查（脚本版，F5 直接运行）
% 第一部分：parse_llm_json 离线解析（不需要网络/key）
% 第二部分：llm2route 在线抽取 + check_route_spec 校验（需要 llm_key.txt 与网络）
% 用法：命令窗口 run('F:\练习\tests\test_llm2route.m')

cd(fileparts(mfilename('fullpath')));
cd('..');
addpath(pwd);
clear functions;
rehash path;

R = {};
fprintf('=== 第一部分：parse_llm_json 离线解析 ===\n');

% 1. 标准结构
r = parse_llm_json('{"segments":[{"type":"line","dist_m":2000}],"assumptions":["缺方向"]}');
R = check(R, '1. 标准 JSON 解析出 segments', isstruct(r) && isfield(r,'segments'));

% 2. 顶层数组 → 包成 segments
r = parse_llm_json('[{"type":"line","dist_m":1000},{"type":"orbit","turns":2}]');
R = check(R, '2. 顶层数组自动包成 segments', isstruct(r) && isfield(r,'segments') && numel(r.segments) == 2);

% 3. 嵌套一层 → 自动拆开
r = parse_llm_json('{"plan":{"segments":[{"type":"line","dist_m":500}]}}');
R = check(R, '3. 嵌套 plan 自动拆开', isstruct(r) && isfield(r,'segments'));

% 4. 非法 JSON → 空
R = check(R, '4. 非法 JSON 返回空', isempty(parse_llm_json('这不是 JSON')));

% 5. 无 segments 字段 → 空
R = check(R, '5. 无 segments 返回空', isempty(parse_llm_json('{"foo":1}')));

% 6. markdown 包裹 → 空（决策：不洗文本，交给重试）
R = check(R, '6. markdown 包裹不解析（交给重试）', isempty(parse_llm_json(sprintf('```json\n{"segments":[]}\n```'))));

fprintf('\n=== 第二部分：在线抽取（需 llm_key.txt） ===\n');
if ~isfile('llm_key.txt') || contains(fileread('llm_key.txt'), '请把这一行')
    fprintf('  [SKIP] 未配置 llm_key.txt，跳过在线检查\n');
else
    lm = readtable('landmarks.xlsx');

    % 7. 你的任务原话
    try
        raw = llm2route('向北飞2000米后绕训练空域中心半径500米顺时针转两圈');
        [plan, issues, ok] = check_route_spec(raw, lm);
        fprintf('  抽取结果: %s\n', strtrim(jsonencode(raw)));
        R = check(R, '7a. 北飞+绕圈：校验通过', ok);
        R = check(R, '7b. 段数=3 且末段为 orbit 半径500 两圈', numel(plan.segments) == 3 && ...
                  strcmp(plan.segments{3}{1}, 'orbit') && plan.segments{3}{3} == 500 && plan.segments{3}{5} == 2);
        R = check(R, '7c. 地标解析为 (8000,2000)', isequal(plan.segments{3}{2}, [8000 2000]));
    catch ME
        R = check(R, '7. 北飞+绕圈（调用失败）', false);
        fprintf('      错误: %s\n', ME.message);
    end

    % 8. 换地标 + 逆时针
    try
        raw = llm2route('去塔A上空逆时针绕3圈，半径800米');
        [plan, ~, ok] = check_route_spec(raw, lm);
        fprintf('  抽取结果: %s\n', strtrim(jsonencode(raw)));
        seg = plan.segments{end};
        R = check(R, '8. 塔A 逆时针 3 圈 800 m', ok && strcmp(seg{1},'orbit') && ...
                  isequal(seg{2}, [1500 1500]) && strcmp(seg{4}, 'CCW') && seg{5} == 3 && seg{3} == 800);
    catch ME
        R = check(R, '8. 塔A 逆时针（调用失败）', false);
        fprintf('      错误: %s\n', ME.message);
    end

    % 9. 缺参数：只说"绕圈"，看是否走 assumptions/默认值
    try
        raw = llm2route('在训练空域中心上空盘旋一会儿');
        [plan, issues, ok] = check_route_spec(raw, lm);
        fprintf('  抽取结果: %s\n  校验 issues: %s\n', strtrim(jsonencode(raw)), strjoin(issues, ' | '));
        R = check(R, '9. 模糊指令兜底（能执行且有提示）', ok && ~isempty([issues, plan.assumptions]));
    catch ME
        R = check(R, '9. 模糊指令（调用失败）', false);
        fprintf('      错误: %s\n', ME.message);
    end

    % 10. 缺方向 + 单位混用（米/公里）
    try
        raw = llm2route('先向正东飞3公里，然后绕塔B顺时针转2圈，半径1公里');
        [plan, issues, ok] = check_route_spec(raw, lm);
        fprintf('  抽取结果: %s\n  校验 issues: %s\n', strtrim(jsonencode(raw)), strjoin(issues, ' | '));
        R = check(R, '10. 公里/方向混合表达能抽出动作单', ok && numel(plan.segments) >= 2);
    catch ME
        R = check(R, '10. 混合表达（调用失败）', false);
        fprintf('      错误: %s\n', ME.message);
    end

    % 11. 地标表含"起飞点"（返航目标）
    T = readtable('landmarks.xlsx');
    R = check(R, '11. 地标表含"起飞点"', any(strcmpi(string(T.name), "起飞点")));

    % 12. 返航：说法里"返回起飞点"应抽成 goto 起飞点
    try
        lm_names = string(T.name)';
        raw = llm2route('向北飞2000米后绕训练空域中心转3圈再返回起飞点', 'Landmarks', lm_names);
        [plan, ~, ok] = check_route_spec(raw, T);
        fprintf('  抽取结果: %s\n', strtrim(jsonencode(raw)));
        last = plan.segments{end};
        R = check(R, '12. "返回起飞点"抽成 goto(0,0)', ok && strcmp(last{1}, 'goto') && ...
                  isequal(last{2}(1:2), [0 0]));
    catch ME
        R = check(R, '12. 返回起飞点（调用失败）', false);
        fprintf('      错误: %s\n', ME.message);
    end
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
