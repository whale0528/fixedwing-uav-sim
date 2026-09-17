function [ok, issues, p] = check_params_only(raw, opt)
% CHECK_PARAMS_ONLY "逐参数范围检查"层（Prompted to Fly 的 V_S 级别）
% 只做 类型/范围/枚举/默认值 检查，**不含任何跨参数耦合约束**。
% 用途：H2 对照实验中的"现有系统"一侧（与本项目的 feasible_orbit 契约层对照）。
%
% raw  : struct，含半径/速度/高度/圈数/方向等字段（可由 LLM 抽取得到）
% 返回 ：ok（是否放行）、issues（问题清单）、p（解析出的参数）
    arguments
        raw struct
        opt.dir_enum (1,:) string = ["CW", "CCW"]
        opt.r_range (1,2) double = [30 5000]      % 文档 §7.2 的参数定义域
        opt.h_range (1,2) double = [30 3000]
        opt.N_range (1,2) double = [1 200]
        opt.v_default (1,1) double = 34
    end
    issues = {};
    ok = false;
    p = struct('r', NaN, 'v', NaN, 'h', NaN, 'N', NaN, 'dir', "CW");   % 先占位，early return 时字段仍存在

    % ---- 半径 ----
    if isfield(raw, 'radius_m') && ~isempty(raw.radius_m) && isnumeric(raw.radius_m)
        p.r = double(raw.radius_m);
    else
        p.r = 500;  issues{end+1} = 'radius_m 缺失，用默认值 500 m';
    end
    if p.r < opt.r_range(1) || p.r > opt.r_range(2)
        issues{end+1} = sprintf('半径 %.0f m 超出定义域 [%.0f, %.0f]', p.r, opt.r_range(1), opt.r_range(2));
        return;
    end

    % ---- 速度（缺省即巡航速度；范围检查不含失速下界——那是契约层的事）----
    if isfield(raw, 'speed_ms') && ~isempty(raw.speed_ms) && isnumeric(raw.speed_ms)
        p.v = double(raw.speed_ms);
    else
        p.v = opt.v_default;  issues{end+1} = sprintf('speed_ms 缺失，用默认值 %g m/s', opt.v_default);
    end
    if p.v <= 0 || p.v > 200
        issues{end+1} = sprintf('速度 %.1f m/s 非正或离谱（>200）', p.v);
        return;
    end

    % ---- 高度 ----
    if isfield(raw, 'alt_m') && ~isempty(raw.alt_m) && isnumeric(raw.alt_m)
        p.h = double(raw.alt_m);
    else
        p.h = 300;
    end
    if p.h < opt.h_range(1) || p.h > opt.h_range(2)
        issues{end+1} = sprintf('高度 %.0f m 超出定义域 [%.0f, %.0f]', p.h, opt.h_range(1), opt.h_range(2));
        return;
    end

    % ---- 圈数 ----
    if isfield(raw, 'turns') && ~isempty(raw.turns) && isnumeric(raw.turns)
        p.N = double(raw.turns);
    else
        p.N = 1;  issues{end+1} = 'turns 缺失，用默认值 1';
    end
    if p.N < opt.N_range(1) || p.N > opt.N_range(2) || p.N ~= round(p.N)
        issues{end+1} = sprintf('圈数 %g 超出定义域 [%g, %g] 或非整数', p.N, opt.N_range(1), opt.N_range(2));
        return;
    end

    % ---- 方向 ----
    p.dir = "CW";
    dir_ok = false;
    if isfield(raw, 'direction') && ~isempty(raw.direction)
        d = upper(strtrim(string(raw.direction)));
        if ~isempty(d) && ~any(ismissing(d)) && any(strcmpi(d, opt.dir_enum))
            p.dir = d;  dir_ok = true;
        end
    end
    if ~dir_ok
        issues{end+1} = 'direction 缺失/非法，默认 CW';
    end

    ok = true;    % 逐参数检查通过 = 放行
end
