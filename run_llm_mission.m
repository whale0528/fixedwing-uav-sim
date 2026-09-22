function report = run_llm_mission(instruction, opt)
% RUN_LLM_MISSION 一句话任务全流程：自然语言 → 抽取 → 校验 → 航点 → 仿真 → 判定
% 前置：先运行 init（载入气动数据/控制器，并设好起点 x_0,y_0,psi_0）
% 用法：
%   cd('F:\练习'); init
%   report = run_llm_mission("向北飞2000米后绕训练空域中心半径500米顺时针转两圈")
%   plot_traj_topview
%
% 只看计划、不跑仿真（秒出图）：
%   report = run_llm_mission("向北飞2000米后绕训练空域中心顺时针转两圈", 'RunSim', false)
%   plot_plan_topview(report)        % 计划路线俯视图（不载模型、不仿真）
%
% 可选参数：
%   LandmarksFile 地标表文件（默认 landmarks.xlsx；**同时作为 LLM 的可用地标白名单**，
%                 往表里加地标即可让 LLM 认识新地点）
%   StartPose     起点 [x y psi]；缺省从 base 工作区取 x_0,y_0,psi_0
%   RunSim        false 时只做抽取+校验+生成航点，不跑仿真（快速看计划）
%   Raw           直接给 LLM 风格的 JSON（测试钩子，跳过在线调用）
%   StopTime      显式指定仿真时长（缺省自动）
%
% report 字段：ok（校验是否通过）、issues、raw、plan、fly_pt、total_len、
%              out（若跑仿真）、verdict（check_route_flight 结果）
    arguments
        instruction (1,:) char
        opt.LandmarksFile (1,:) char = 'landmarks.xlsx'
        opt.StartPose (1,3) double = [NaN NaN NaN]
        opt.RunSim (1,1) logical = true
        opt.Raw = []
        opt.StopTime (1,1) double = 0
        opt.Confirm (1,1) logical = true        % HITL：执行前让人确认
        opt.AutoConfirm (1,1) logical = false   % true = 跳过提问直接确认（脚本/测试用）
        opt.UseLLMConfirm (1,1) logical = true  % 是否用 LLM 回译计划（失败自动回退）
    end

    report = struct('ok', false, 'issues', {{}}, 'raw', [], 'plan', [], ...
                    'fly_pt', [], 'total_len', 0, 'confirmed', false, ...
                    'out', [], 'verdict', []);

    % ---- 1) 地标表（同时作为 LLM 的可用地标白名单）----
    if ~isfile(opt.LandmarksFile)
        error('run_llm_mission:noLandmarks', '找不到地标表 %s', opt.LandmarksFile);
    end
    landmarks = readtable(opt.LandmarksFile);
    lm_names = string(landmarks.name)';
    fprintf('地标白名单（%d 个）: %s\n', numel(lm_names), strjoin(lm_names, '、'));

    % ---- 2) 起点 ----
    sp = opt.StartPose;
    if any(isnan(sp))
        sp = [evalin('base', 'x_0'), evalin('base', 'y_0'), evalin('base', 'psi_0')];
    end

    % ---- 3) 抽取（LLM 或测试钩子）----
    if isempty(opt.Raw)
        raw = llm2route(instruction, 'Landmarks', lm_names);   % 白名单来自地标表
    else
        raw = opt.Raw;
    end
    report.raw = raw;
    fprintf('\n[1/5] LLM 抽取结果：\n  %s\n', strtrim(jsonencode(raw)));

    % ---- 4) 校验（安全门）----
    [plan, issues, ok] = check_route_spec(raw, landmarks);
    report.plan = plan; report.issues = issues; report.ok = ok;
    fprintf('[2/5] 校验：%s\n', string(ok));
    for i = 1:numel(issues), fprintf('      · %s\n', issues{i}); end
    if ~ok
        fprintf('      校验未通过，流程终止（不生成航点、不仿真）\n');
        return;
    end

    % ---- 5) 生成航点 ----
    [fly_pt, n, total_len] = make_route_plan(plan.segments, sp, struct('turn_radius', 500));
    report.fly_pt = fly_pt; report.total_len = total_len;
    fprintf('[3/5] 航点：%d 行，计划路径 %.0f m，预计仿真 %.0f s\n', n, total_len, total_len/32 + 4);

    if ~opt.RunSim
        % 与跑仿真的分支保持一致：把计划和航点放到 base 工作区，便于画图/查看
        assignin('base', 'fly_pt', fly_pt);
        assignin('base', 'num_fly_pt', n);
        assignin('base', 'plan', plan);
        fprintf('      （RunSim=false，跳过确认与仿真；已把 fly_pt/plan 放到 base）\n');
        fprintf('      看计划图： plot_plan_topview(report)   或   plot_plan_topview\n');
        return;
    end

    % ---- 6) 人工确认（HITL：LLM 回译 + y/n）----
    if opt.Confirm
        confirmed = confirm_route(plan, 'UseLLM', opt.UseLLMConfirm, 'AutoYes', opt.AutoConfirm);
        report.confirmed = confirmed;
        if ~confirmed
            fprintf('[4/5] 已取消，不执行仿真。\n');
            return;
        end
        fprintf('[4/5] 已确认。\n');
    else
        report.confirmed = true;
        fprintf('[4/5] 已跳过确认（Confirm=false）。\n');
    end

    % ---- 7) 仿真 + 判定 ----
    out = run_route_sim(fly_pt, total_len, opt.StopTime);
    report.out = out;
    verdict = check_route_flight(out, plan);
    report.verdict = verdict;
    fprintf('[5/5] 执行判定：%s\n', string(verdict.overall));
    for i = 1:numel(verdict.items)
        it = verdict.items(i);
        fprintf('      [%s] %s —— %s\n', string(it.ok), it.name, it.detail);
    end
end
