function [ok, rep] = feasible_orbit(r, v, N, opt)
% FEASIBLE_ORBIT 参数化盘旋（orbit）机动的动力学可行性判定（解析层原型）
% 这是"动力学可行性契约"的第一块砖：给出跨参数耦合约束 + 违反报告（哪条、差多少、怎么改）。
%
% 用法：
%   [ok, rep] = feasible_orbit(150, 34)        % 半径150 m、速度34 m/s、1 圈
%   [ok, rep] = feasible_orbit(500, 34, 2)     % 半径500 m、速度34 m/s、2 圈
%
% 约束（★ 为跨参数耦合，逐参数检查抓不到）：
%   C1 失速下界      v >= V_stall                        （升力约束）
%   C2 速度上界      v <= V_max                          （推力约束，假设值）
%   C3 ★配平/坡度   phi = atan(v^2/(g r)) <= phi_max     （力的平衡）
%   C4 ★过载        n = 1/cos(phi) <= n_max              （结构/升力）
%   C5 ★制导可跟踪  r >= r_min_guide(v)                  （执行层实测边界）
%   C6 ★能量/续航   N*2*pi*r/v <= endurance              （仿真平台无油耗模型时取 Inf）
%   C7 高度范围      h ∈ [h_min, h_max]
%
% 输出 rep：逐条约束的 值/界/裕度/是否违反/建议，以及总判定与建议的可行域
    arguments
        r (1,1) double
        v (1,1) double = 34
        N (1,1) double = 1
        opt.h (1,1) double = 300
        opt.endurance (1,1) double = Inf
        opt.h_range (1,2) double = [30 3000]
        opt.lim = []
    end
    if isempty(opt.lim), lim = vehicle_limits(); else, lim = opt.lim; end

    phi = atan(v^2 / (lim.g * r));            % 维持该圆所需坡度
    n   = 1 / cos(phi);                       % 对应过载
    items = struct('id', {}, 'name', {}, 'value', {}, 'limit', {}, ...
                   'violated', {}, 'margin', {}, 'suggestion', {});

    % ---- C1 失速下界 ----
    items(end+1) = mk('C1', '失速下界', v, lim.V_stall, 'm/s', v < lim.V_stall, true, ...
        sprintf('速度至少提高到 V_stall = %.1f m/s', lim.V_stall));

    % ---- C2 速度上界 ----
    items(end+1) = mk('C2', '速度上界', v, lim.V_max, 'm/s', v > lim.V_max, true, ...
        sprintf('速度降至 %.1f m/s 以下（V_max 为假设值，需按动力核算）', lim.V_max));

    % ---- C3 配平/坡度（跨参数耦合）----
    v_max_at_r = sqrt(lim.g * r * tan(lim.phi_max));      % 该半径下的速度上限
    sug = sprintf('r=%.0f m 下速度需 ≤ %.1f m/s', r, v_max_at_r);
    if v_max_at_r < lim.V_stall
        sug = sprintf('%s；且该半径连失速速度都放不下 → 半径至少 %.0f m', sug, lim.r_min_aero(lim.V_stall));
    end
    items(end+1) = mk('C3', sprintf('配平/坡度（需 %.1f°）', rad2deg(phi)), rad2deg(phi), ...
        rad2deg(lim.phi_max), 'deg', phi > lim.phi_max, true, sug);

    % ---- C4 过载 ----
    items(end+1) = mk('C4', '过载', n, lim.n_max, 'g', n > lim.n_max, true, ...
        sprintf('过载超限：减小坡度（降速或加大半径）'));

    % ---- C5 制导可跟踪性（执行层经验边界，★最容易被忽略）----
    r_g = lim.r_min_guide(v);
    sug5 = sprintf('r=%.0f m 低于制导可跟踪下限 %.0f m：半径加大到 %.0f m 以上，或速度降到 %.1f m/s 以下', ...
                   r, r_g, r_g, sqrt(0.3 * lim.g * r));
    items(end+1) = mk('C5', '制导可跟踪半径', r, r_g, 'm', r < r_g, true, sug5);

    % ---- C6 能量/续航 ----
    need = N * 2*pi*r / v;                                % 该机动的飞行时间
    items(end+1) = mk('C6', sprintf('能量/续航（需 %.0f s）', need), need, opt.endurance, 's', ...
        need > opt.endurance, true, ...
        sprintf('圈数降到 %d 圈以内', max(0, floor(opt.endurance * v / (2*pi*r)))));

    % ---- C7 高度范围 ----
    items(end+1) = mk('C7', '高度范围', opt.h, opt.h_range(2), 'm', ...
        opt.h < opt.h_range(1) || opt.h > opt.h_range(2), true, ...
        sprintf('高度需在 [%.0f, %.0f] m 内', opt.h_range(1), opt.h_range(2)));

    % ---- 汇总 ----
    ok = ~any([items.violated]);
    bad = items([items.violated]);
    rep = struct('ok', ok, 'items', items, 'violated_ids', {{items([items.violated]).id}}, ...
                 'phi_deg', rad2deg(phi), 'n', n, 'flight_time_s', need, ...
                 'feasible_region', feasible_region(lim, v, r), 'lim', lim);
    if ok
        rep.summary = sprintf('可行：phi=%.1f°, n=%.2f, 需时 %.0f s', rad2deg(phi), n, need);
    else
        rep.summary = sprintf('不可行：违反 %d 条（%s）', numel(bad), strjoin({bad.id}, ', '));
    end
end

% ================= 辅助 =================
function it = mk(id, name, value, limit, unit, violated, is_upper, suggestion)
% 组装一条约束记录（is_upper=true 表示上限约束）
    if is_upper, margin = limit - value; else, margin = value - limit; end
    it = struct('id', id, 'name', name, ...
                'value', sprintf('%.3g %s', value, unit), ...
                'limit', sprintf('%.3g %s', limit, unit), ...
                'violated', violated, ...
                'margin', margin, ...
                'suggestion', suggestion);
end

function s = feasible_region(lim, v, r)
% 给出当前参数附近的可行域建议（供报告/反馈使用）
    r_lb = max(lim.r_min_aero(v), lim.r_min_guide(v));
    v_ub = min([lim.V_max, sqrt(lim.g * r * tan(lim.phi_max)), sqrt(0.3 * lim.g * r)]);
    s = sprintf('给定 v=%.1f m/s → r ≥ %.0f m；给定 r=%.0f m → v ≤ %.1f m/s（且 v ≥ %.1f m/s）', ...
                v, r_lb, r, v_ub, lim.V_stall);
end
