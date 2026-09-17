function [plan, issues, ok] = check_route_spec(raw, landmarks)
% CHECK_ROUTE_SPEC LLM 路线 JSON → 可信动作单（确定性校验层）
% 原则：LLM 不算数、不生成坐标；本层做结构检查、地标查表、范围钳制与默认值注入。
%
% raw       : struct，LLM 返回并 jsondecode 后的结果：
%               .segments : 对象数组（cell 或 struct 数组），每段含 type 及各型参数：
%                   turn_to  : heading_deg（度）
%                   line     : dist_m（米）
%                   line_to  : target_ref（地标名；禁止直接给坐标）
%                   goto     : target_ref（地标名）+ heading_deg（可空 = 航向自由）
%                   orbit    : center_ref（地标名）+ radius_m + direction + turns
%                   exit_line: dist_m（米）
%               .assumptions : 可选，字符串数组
% landmarks : table 或 struct，含 name、xn、xe 字段（地标查表）
% plan      : struct，字段 segments（可直接喂 make_route_plan 的 cell）、
%             assumptions、total_est、ok
% issues    : cellstr，人类可读问题清单（ok=false 时为致命问题）
% ok        : logical，能否执行
%
% 约束来源：绕圈半径下限 400 m（制导 P 通道稳态上限 0.3 g）；段数上限 12；
%           直线距离上限 20000 m；坐标必须落在地图 10 km × 10 km 内。

    plan = struct('segments', {{}}, 'assumptions', {{}}, 'total_est', 0, 'ok', false);
    issues = {};
    ok = false;                       % 默认不可执行；全部校验通过后才置 true

    if ~isstruct(raw) || ~isfield(raw, 'segments') || isempty(raw.segments)
        issues{end+1} = '缺少 segments（动作单为空）'; return;
    end
    cseg = to_cell(raw.segments);
    if isempty(cseg)
        issues{end+1} = 'segments 必须是对象数组'; return;
    end
    if numel(cseg) > 12
        issues{end+1} = sprintf('段数 %d 超过上限 12', numel(cseg)); return;
    end

    segs_out = {};
    last_xy = [];
    total_est = 0;
    for k = 1:numel(cseg)
        s = cseg{k};
        if ~isstruct(s) || ~isfield(s, 'type')
            issues{end+1} = sprintf('第 %d 段缺少 type 字段', k); return;
        end
        t = lower(strtrim(safestr(s.type)));

        switch t
            case 'turn_to'
                [hd, iss] = get_num(s, 'heading_deg', '航向', 0, 0, 360);
                append_iss(iss);
                hd = mod(hd, 360);
                segs_out{end+1} = {'turn_to', hd};                        %#ok<AGROW>
                total_est = total_est + 500*pi/2;                          % 估个转向弧量级

            case {'line', 'exit_line'}
                [d, iss] = get_num(s, 'dist_m', '距离', 1000, 100, 20000);
                append_iss(iss);
                segs_out{end+1} = {t, d};                                  %#ok<AGROW>
                total_est = total_est + d;

            case {'line_to', 'goto'}
                if isfield(s, 'target') || isfield(s, 'target_xy') || isfield(s, 'xy')
                    issues{end+1} = sprintf('第 %d 段：LLM 不得直接生成坐标，请用 target_ref（地标名）', k);
                    return;
                end
                if ~isfield(s, 'target_ref') || isempty(s.target_ref)
                    issues{end+1} = sprintf('第 %d 段缺少 target_ref', k); return;
                end
                [xy, found] = lookup_landmark(landmarks, s.target_ref);
                if ~found
                    issues{end+1} = sprintf('未知地标: %s', safestr(s.target_ref)); return;
                end
                if strcmp(t, 'line_to')
                    segs_out{end+1} = {'line_to', xy};                     %#ok<AGROW>
                else
                    hd = NaN;                                              % 航向自由
                    if isfield(s, 'heading_deg') && ~isempty(s.heading_deg) && ...
                            isnumeric(s.heading_deg) && isscalar(s.heading_deg) && isfinite(s.heading_deg)
                        hd = mod(double(s.heading_deg), 360);
                    end
                    segs_out{end+1} = {'goto', [xy, hd]};                  %#ok<AGROW>
                end
                if ~isempty(last_xy), total_est = total_est + norm(xy - last_xy); end
                [bad, iss] = check_bounds(xy); append_iss(iss);
                if ~isempty(bad), issues{end+1} = bad; return; end
                last_xy = xy;

            case 'orbit'
                if isfield(s, 'center') || isfield(s, 'center_ned') || isfield(s, 'center_xy')
                    issues{end+1} = sprintf('第 %d 段：LLM 不得直接生成坐标，请用 center_ref（地标名）', k);
                    return;
                end
                if ~isfield(s, 'center_ref') || isempty(s.center_ref)
                    issues{end+1} = sprintf('第 %d 段缺少 center_ref', k); return;
                end
                [xy, found] = lookup_landmark(landmarks, s.center_ref);
                if ~found
                    issues{end+1} = sprintf('未知地标: %s', safestr(s.center_ref)); return;
                end
                [r, iss] = get_num(s, 'radius_m', '半径', 500, 400, 5000);
                append_iss(iss);
                [turns, iss] = get_num(s, 'turns', '圈数', 1, 1, 50);
                append_iss(iss);
                turns = round(turns);
                dir = 'CW';
                if isfield(s, 'direction') && ~isempty(s.direction)
                    d = upper(strtrim(string(s.direction)));
                    if ~isempty(d) && ~any(ismissing(d)) && any(strcmpi(d, ["CW", "CCW"]))
                        dir = d;
                    else
                        issues{end+1} = 'direction 缺失/非法，默认 CW';
                    end
                else
                    issues{end+1} = 'direction 缺失/非法，默认 CW';
                end
                segs_out{end+1} = {'orbit', xy, r, char(dir), turns};       %#ok<AGROW>
                if ~isempty(last_xy), total_est = total_est + norm(xy - last_xy); end
                [bad, iss] = check_bounds(xy); append_iss(iss);
                if ~isempty(bad), issues{end+1} = bad; return; end
                total_est = total_est + turns*2*pi*r + 1000;                % 切入近似
                last_xy = xy;

            otherwise
                issues{end+1} = sprintf('未知段类型: %s', t); return;
        end
    end

    if total_est > 60000
        issues{end+1} = sprintf('估算总路径 %.0f m 过长（>60 km），请缩减动作', total_est);
    end

    plan.segments = segs_out;
    plan.total_est = total_est;
    if isfield(raw, 'assumptions') && ~isempty(raw.assumptions)
        a = raw.assumptions;
        if ischar(a)
            plan.assumptions = {a};
        elseif isstring(a)
            plan.assumptions = cellstr(a);
        elseif iscell(a)
            plan.assumptions = cellfun(@safestr, a, 'UniformOutput', false);
        end
        plan.assumptions = plan.assumptions(:)';      % 统一成行向量，便于与 issues 拼接
    end
    plan.ok = true;
    ok = true;

    % ---------- 嵌套函数：把 issue 汇总到外层 ----------
    function append_iss(iss)
        if ~isempty(iss)
            if iscell(iss), issues = [issues, iss(:)']; else, issues{end+1} = iss; end %#ok<AGROW>
        end
    end
end

% ================= 辅助函数 =================
function str = safestr(x)
% 安全转字符串：MATLAB 的 string(NaN) 会得到 <missing>，直接 sprintf 会报错
    if ischar(x)
        str = x;
    elseif isstring(x)
        if isscalar(x) && ~ismissing(x)
            str = char(x);
        else
            str = strjoin(cellstr(x), ',');
        end
    elseif iscell(x) && ~isempty(x)
        str = safestr(x{1});
    elseif isnumeric(x) && isscalar(x) && isfinite(x)
        str = num2str(x);
    else
        str = ['<' class(x) '>'];
    end
end

function c = to_cell(segs)
% 统一成 cell（jsondecode 对同构对象数组给 struct 数组，异构给 cell）
    if isstruct(segs)
        c = cell(1, numel(segs));
        for k = 1:numel(segs), c{k} = segs(k); end
    elseif iscell(segs)
        c = segs(:)';
    else
        c = {};
    end
    c = c(~cellfun(@isempty, c));
end

function [v, iss] = get_num(s, name, label, def, lo, hi)
% 取数值字段：缺失 → 默认值；非数值 → 默认值；越界 → 钳制；全部记 issue
    iss = '';
    v = def;
    if isfield(s, name) && ~isempty(s.(name))
        val = s.(name);
        if isnumeric(val) && isscalar(val) && isfinite(val)
            v = double(val);
        else
            iss = sprintf('%s 非有效数值，用默认值 %g', label, def);
        end
    else
        iss = sprintf('%s 缺失，用默认值 %g', label, def);
    end
    if v < lo
        v = lo; iss = sprintf('%s 越界（下限 %g），已钳制', label, lo);
    elseif v > hi
        v = hi; iss = sprintf('%s 越界（上限 %g），已钳制', label, hi);
    end
end

function [xy, found] = lookup_landmark(landmarks, ref)
% 地标查表：支持 table 或 struct（含 name、xn、xe）
    names = string(landmarks.name);
    idx = find(strcmpi(names, string(safestr(ref))), 1);
    found = ~isempty(idx);
    if found
        xy = [double(landmarks.xn(idx)), double(landmarks.xe(idx))];
    else
        xy = [NaN NaN];
    end
end

function [iss_bad, iss] = check_bounds(xy)
% 坐标必须在 10 km × 10 km 地图内（略超出 → 警告；大幅超出 → 致命）
    iss = '';
    iss_bad = '';
    out = max([-xy(1), xy(1)-10000, -xy(2), xy(2)-10000]);
    if out > 2000
        iss_bad = sprintf('坐标 (%.0f, %.0f) 远超地图范围', xy(1), xy(2));
    elseif out > 0
        iss = sprintf('坐标 (%.0f, %.0f) 略超出地图边界', xy(1), xy(2));
    end
end
