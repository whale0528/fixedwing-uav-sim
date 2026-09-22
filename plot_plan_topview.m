function ax = plot_plan_topview(src, plan, opt)
% PLOT_PLAN_TOPVIEW 计划路线俯视图（只画计划，不跑仿真）
%
% 用法（四选一）：
%   report = run_llm_mission("向北飞2000米后绕训练空域中心顺时针转两圈", 'RunSim', false);
%   plot_plan_topview(report)         % ① 直接给 report（推荐）
%   plot_plan_topview(fly_pt)         % ② 给 N×5 航点表
%   plot_plan_topview                 % ③ 不给参数：从 base 工作区取 fly_pt
%   plot_plan_topview(report.plan)    % ④ 只给 plan：用 base 的起点重新生成航点
%
% 显示：计划路线折线 + 起点/终点 + 地标（读 landmarks.xlsx）+ 绕圈圆心与半径虚线
%
% 与 plot_traj_topview 的区别：
%   plot_traj_topview  画**仿真实际飞出来的**轨迹 → 需要 base 工作区里有 out（必须先跑仿真）
%   本函数             画**计划**                 → 不载模型、不仿真、秒出图
%
% 可选参数：
%   'Landmarks', true/false   是否叠加地标（默认 true；表不存在时自动跳过）
%   'LandmarksFile', 文件名   默认 landmarks.xlsx
%   'Title', 字符串           自定义标题
%
% 输出 ax：坐标轴句柄。

    arguments
        src = []
        plan = []
        opt.Landmarks (1,1) logical = true
        opt.LandmarksFile (1,:) char = 'landmarks.xlsx'
        opt.Title (1,:) char = ''
    end

    % ---------- 1) 取到 fly_pt 与 plan ----------
    fly_pt = [];
    if isempty(src)
        if evalin('base', 'exist(''fly_pt'',''var'')') == 1
            fly_pt = evalin('base', 'fly_pt');
        else
            error('plot_plan_topview:noSource', ['base 工作区没有 fly_pt。请先运行：\n' ...
                '    report = run_llm_mission("你的指令", ''RunSim'', false);\n' ...
                '    plot_plan_topview(report);']);
        end
    elseif isstruct(src)
        if isfield(src, 'fly_pt') && ~isempty(src.fly_pt)
            fly_pt = src.fly_pt;                                   % report 结构
            if isempty(plan) && isfield(src, 'plan'), plan = src.plan; end
        elseif isfield(src, 'segments')
            plan = src;                                            % 只给了 plan
        else
            error('plot_plan_topview:badStruct', '结构体里既没有 fly_pt（report）也没有 segments（plan）');
        end
    elseif isnumeric(src)
        fly_pt = src;
    else
        error('plot_plan_topview:badInput', '输入必须是 report / plan / N×5 航点表');
    end

    % 只给 plan 时：用 base 工作区的起点现算航点（需要先运行 init）
    if isempty(fly_pt) && ~isempty(plan)
        if evalin('base', 'exist(''x_0'',''var'')') ~= 1
            error('plot_plan_topview:noStart', '只给 plan 时需要 base 里有 x_0/y_0/psi_0（先运行 init）');
        end
        sp = [evalin('base', 'x_0'), evalin('base', 'y_0'), evalin('base', 'psi_0')];
        [fly_pt, ~, ~] = make_route_plan(plan.segments, sp, struct('turn_radius', 500));
    end

    if isempty(fly_pt) || size(fly_pt, 2) < 5
        error('plot_plan_topview:badFlyPt', '航点表必须是 N×5：[x_north, y_east, z, type, info]');
    end
    keep = fly_pt(:, 4) ~= -10000;                 % 去掉终止行（type = -10000）
    P = fly_pt(keep, :);
    if size(P, 1) < 2
        error('plot_plan_topview:tooFew', '去掉终止行后不足 2 个航点，无法画线');
    end
    xn = P(:, 1); xe = P(:, 2); hz = P(:, 3);
    plen = sum(hypot(diff(xe), diff(xn)));

    % ---------- 2) 画图 ----------
    figure('Color', 'w', 'Position', [100 100 900 780]);
    ax = axes; hold(ax, 'on'); grid(ax, 'on');

    plot(xe, xn, 'b-', 'LineWidth', 1.8, 'DisplayName', '计划路线');
    plot(xe(1), xn(1), 'ko', 'MarkerFaceColor', 'w', 'MarkerSize', 9, 'DisplayName', '起点');
    plot(xe(end), xn(end), 'rx', 'MarkerSize', 12, 'LineWidth', 2, 'DisplayName', '终点');

    % 地标（可选）
    if opt.Landmarks && isfile(opt.LandmarksFile)
        try
            lm = readtable(opt.LandmarksFile);
            for i = 1:height(lm)
                if i == 1
                    plot(lm.xe(i), lm.xn(i), '.', 'Color', [.55 .55 .55], 'MarkerSize', 16, ...
                         'DisplayName', '地标');
                else
                    plot(lm.xe(i), lm.xn(i), '.', 'Color', [.55 .55 .55], 'MarkerSize', 16, ...
                         'HandleVisibility', 'off');
                end
                text(lm.xe(i) + 80, lm.xn(i) + 80, char(string(lm.name(i))), ...
                     'FontSize', 8, 'Color', [.35 .35 .35]);
            end
        catch
            warning('plot_plan_topview:landmarks', '地标表 %s 读取失败，已跳过关标叠加', opt.LandmarksFile);
        end
    end

    % 绕圈：圆心 + 半径虚线（把"计划里的圆"和"实际多边形航点"对照起来看）
    if ~isempty(plan) && isstruct(plan) && isfield(plan, 'segments')
        th = linspace(0, 2*pi, 240);
        first = true;
        for k = 1:numel(plan.segments)
            g = plan.segments{k};
            if numel(g) >= 5 && strcmpi(char(g{1}), 'orbit')
                c = g{2}; r = g{3}; dir = char(g{4}); n = g{5};
                if first
                    plot(c(2) + r*cos(th), c(1) + r*sin(th), '--', 'Color', [.85 .33 .1], ...
                         'LineWidth', 1.2, 'DisplayName', '绕圈（圆心/半径）');
                    first = false;
                else
                    plot(c(2) + r*cos(th), c(1) + r*sin(th), '--', 'Color', [.85 .33 .1], ...
                         'LineWidth', 1.2, 'HandleVisibility', 'off');
                end
                plot(c(2), c(1), '+', 'Color', [.85 .33 .1], 'MarkerSize', 10, ...
                     'LineWidth', 1.4, 'HandleVisibility', 'off');
                text(c(2) + 0.25*r, c(1) - 0.6*r, sprintf('r=%.0f m ×%d %s', r, n, dir), ...
                     'Color', [.85 .33 .1], 'FontSize', 9);
            end
        end
    end

    xlabel('东向 (m)'); ylabel('北向 (m)');
    axis(ax, 'equal');
    if isempty(opt.Title)
        title(sprintf('计划路线俯视图（%d 航点，折线 %.0f m，高度 %.0f m）', ...
                      size(P, 1), plen, hz(1)));
    else
        title(opt.Title);
    end
    legend('Location', 'best'); box on;

    fprintf(['计划路线：%d 航点，折线 %.0f m，高度 %.0f m；' ...
             '起点 (%.0f, %.0f) → 终点 (%.0f, %.0f)\n'], ...
            size(P, 1), plen, hz(1), xe(1), xn(1), xe(end), xn(end));
end
