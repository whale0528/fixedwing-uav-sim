% TEST_CONFIRM_ROUTE 人工确认环检查（脚本版）
% 检查 confirm_route / route2nl：LLM 回译 + 确定性清单 + 确认返回值。
% 交互提问部分用 AutoYes 跳过（无法自动化 y/n 输入）。

cd(fileparts(mfilename('fullpath')));
cd('..');
addpath(pwd);
clear functions;
rehash path;

R = {};
fprintf('=== confirm_route 检查（脚本版） ===\n');

lm = readtable('landmarks.xlsx');
raw = struct();
raw.segments = {struct('type','turn_to','heading_deg',0), ...
                struct('type','line','dist_m',2000), ...
                struct('type','orbit','center_ref',"训练空域中心",'radius_m',500, ...
                       'direction','CW','turns',2), ...
                struct('type','goto','target_ref',"起飞点",'heading_deg',[])};
[plan, ~, ok] = check_route_spec(raw, lm);
R = check(R, '1. 动作单校验通过（前置条件）', ok);

% 2. LLM 回译非空且提到地标坐标
txt = route2nl(plan);
R = check(R, '2. LLM 回译非空且含关键信息', ~isempty(txt) && ...
          (contains(txt, "8000") || contains(txt, "训练空域中心")) && contains(txt, "500"));
fprintf('     回译：%s\n', txt);

% 3. AutoYes 确认返回 true
R = check(R, '3. AutoYes 确认返回 true', confirm_route(plan, 'AutoYes', true));

% 4. 离线回退（不调 LLM）也能确认
R = check(R, '4. UseLLM=false 回退仍可确认', ...
          confirm_route(plan, 'AutoYes', true, 'UseLLM', false));

fprintf('\n=== 结果：%d 通过 / %d 失败 ===\n', sum(strcmp(R,'P')), sum(strcmp(R,'F')));
if all(strcmp(R, 'P'))
    fprintf('全部通过 ✓\n');
else
    fprintf('存在失败项，检查上面 [FAIL] 行\n');
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
