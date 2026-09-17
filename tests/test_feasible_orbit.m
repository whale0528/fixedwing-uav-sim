% TEST_FEASIBLE_ORBIT 机动可行性判定器检查（脚本版，F5 直接运行）
% 用途：验证 vehicle_limits / feasible_orbit 的解析计算与违反报告正确。
% 用法：命令窗口 run('F:\练习\tests\test_feasible_orbit.m')

cd(fileparts(mfilename('fullpath')));
cd('..');
addpath(pwd);
clear functions;
rehash path;

R = {};
fprintf('=== 解析能力边界与可行性判定检查 ===\n');

lim = vehicle_limits();

% ---- 1. 失速速度（用真实 CL_max）----
R = check(R, sprintf('1. 失速速度 %.1f m/s 落在合理区间 [22,30]', lim.V_stall), ...
          lim.V_stall > 22 && lim.V_stall < 30);

% ---- 2. 巡航最小盘旋半径（气动界）----
R = check(R, sprintf('2. 气动最小半径(34 m/s) = %.1f m ≈ 204 m', lim.r_min_aero(34)), ...
          abs(lim.r_min_aero(34) - 204.3) < 1);

% ---- 3. 制导界严于气动界（本轮实测发现）----
R = check(R, sprintf('3. 制导界(%.0f m) 严于气动界(%.0f m)', lim.r_min_guide(34), lim.r_min_aero(34)), ...
          lim.r_min_guide(34) > lim.r_min_aero(34));

% ---- 4. 文档算例 1：r=150, v=34 → 违反坡度约束，建议 v ≤ 29.1 ----
[ok1, rep1] = feasible_orbit(150, 34);
R = check(R, '4a. r=150,v=34 判定不可行', ~ok1);
R = check(R, '4b. 坡度 38.2° 且建议 v ≤ 29.1 m/s', ...
          abs(rep1.phi_deg - 38.2) < 0.2 && contains(rep1.items(3).suggestion, '29.1'));

% ---- 5. 文档算例 2：r=50, v=40 → 坡度 73°、过载 3.41 ----
[ok2, rep2] = feasible_orbit(50, 40);
R = check(R, '5. r=50,v=40 不可行（坡度 73°、过载 3.41）', ~ok2 && ...
          abs(rep2.phi_deg - 73.0) < 0.3 && abs(rep2.n - 3.41) < 0.02);

% ---- 6. ★关键证据：实测失败点 r=300,v=34 —— 气动层放行，制导层拦截 ----
[ok3, rep3] = feasible_orbit(300, 34);
aero_only = abs(rep3.phi_deg) < 30;      % 仅气动/坡度看：21.5° < 30° → 合法
R = check(R, sprintf('6a. r=300,v=34 气动层放行（坡度 %.1f° < 30°）', rep3.phi_deg), aero_only);
R = check(R, '6b. 但判定器拦截（违反仅 C5 制导界）', ~ok3 && numel(rep3.violated_ids) == 1 && ...
          strcmp(rep3.violated_ids{1}, 'C5'));

% ---- 7. 实测成功点 r=500,v=34 → 可行 ----
[ok4, rep4] = feasible_orbit(500, 34, 2);
R = check(R, '7. r=500,v=34,2圈 判定可行', ok4);
R = check(R, sprintf('7b. 坡度 %.1f°、需要时间 %.0f s', rep4.phi_deg, rep4.flight_time_s), ...
          abs(rep4.phi_deg - 13.3) < 0.2 && abs(rep4.flight_time_s - 184.8) < 1);

% ---- 8. 边界搜索一致性：v=34 时最小可行半径 = 制导界 ----
r_scan = 200:5:600;
ok_scan = arrayfun(@(x) feasible_orbit(x, 34), r_scan);
r_min_found = min(r_scan(ok_scan));
R = check(R, sprintf('8. 扫描得最小可行半径 %.0f m ≈ 制导界 %.0f m', r_min_found, lim.r_min_guide(34)), ...
          abs(r_min_found - lim.r_min_guide(34)) <= 5);

% ---- 9. 速度升高时制导界按 v² 放大（r=400,v=45 → 制导界 689 m）----
[ok5, rep5] = feasible_orbit(400, 45);
R = check(R, sprintf('9. r=400,v=45 不可行（坡度仅 %.1f°，但制导界升至 %.0f m）', ...
          rep5.phi_deg, lim.r_min_guide(45)), ...
          ~ok5 && any(strcmp(rep5.violated_ids, 'C5')) && lim.r_min_guide(45) > 600);

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
