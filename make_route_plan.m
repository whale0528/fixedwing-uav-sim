function [fly_pt, num_fly_pt, total_len] = make_route_plan(segments, start_pose, opt)
% MAKE_ROUTE_PLAN 通用路线生成：段原语列表 → fly_pt 航点表（全部直线航点）
% 用法（像写一张动作单，按顺序列出来）：
%   segments = {
%       {'turn_to', 0},                          % 转向正北
%       {'line',    2000},                       % 直飞 2000 m
%       {'goto',    [6000 2000 90]},             % 去 (6000,2000) 航向 90°（航向填 NaN = 自由）
%       {'orbit',   [3000 0], 500, 'CW', 2},     % 绕 (3000,0) 半径 500 m 顺时针 2 圈
%       {'exit_line', 3000}                      % 沿切线切出 3000 m（可选，末段即终止）
%   };
%   [fly_pt, num_fly_pt, total_len] = make_route_plan(segments, [0 0 psi0]);
%
% 支持的原语：
%   {'turn_to', heading_deg}              最短转向到指定航向（弧按 7.5° 离散）
%   {'line',    dist_m}                   沿当前航向直飞
%   {'line_to', [x, y]}                   转向目标方位后直飞到位
%   {'goto',    [x, y, heading_deg]}      位姿连接（Dubins；heading 可 NaN = 航向自由）
%   {'orbit',   center, r, dir, turns}    绕圈：Dubins 直达切点 + 正 48 边形逼近
%   {'exit_line', dist_m}                 沿当前航向切出直线（末段，自带终止行）
%
% start_pose : [x, y, psi]（psi 可省，默认 0）；x=北向，y=东向，psi 北偏东为正
% opt        : struct，可选字段
%                z           平飞高度（默认 300，与现有 fly_planfjy 约定一致）
%                turn_radius 转向/Dubins 弧半径（默认 500 m，须 ≥ 制导可跟踪下限）
% 输出 fly_pt    : N行x5 [x_north, y_east, z, type, info]（type 仅 1 与 -10000）
% 输出 total_len : 计划路径总长度 (m)，供自动定仿真时长
%
% 设计约束（实测收敛）：
% 1) 所有弧段一律离散成短直线航点——模型 fly_phase 的圆弧切换（扫角+mod 卷绕）
%    不可靠（整圈跳过/方向反转/滚转失控），直线切换是位置判定，鲁棒；
% 2) 任何弧半径 ≥ ~400 m（制导 P 通道稳态上限 0.3 g 决定的曲率下限）。
    if nargin < 3, opt = struct(); end
    if ~isfield(opt, 'z') || isempty(opt.z),               opt.z = 300;  end
    if ~isfield(opt, 'turn_radius') || isempty(opt.turn_radius), opt.turn_radius = 500; end
    z = opt.z; rho = opt.turn_radius;

    start_pose = start_pose(:)';
    if numel(start_pose) < 3, start_pose(3) = 0; end

    fly_pt = [start_pose(1), start_pose(2), z, 1, 0];   % 首行：起点
    curr = start_pose;
    total_len = 0;
    last_kind = '';

    for k = 1:numel(segments)
        seg = segments{k};
        if isempty(seg), continue; end
        kind = lower(char(seg{1}));
        last_kind = kind;
        switch kind
            case 'turn_to'
                [fly_pt, curr, L] = add_turn(fly_pt, curr, deg2rad(seg{2}), rho, z);

            case 'line'
                d = seg{2};
                p_end = curr(1:2) + d*[cos(curr(3)), sin(curr(3))];
                fly_pt = [fly_pt; p_end(1), p_end(2), z, 1, 0];   %#ok<AGROW>
                curr = [p_end, curr(3)];
                L = d;

            case 'line_to'
                tgt = seg{2}(:)' ;
                hd = atan2(tgt(2) - curr(2), tgt(1) - curr(1));
                [fly_pt, curr, L1] = add_turn(fly_pt, curr, hd, rho, z);
                d = norm(tgt(1:2) - curr(1:2));
                fly_pt = [fly_pt; tgt(1), tgt(2), z, 1, 0];        %#ok<AGROW>
                curr = [tgt(1), tgt(2), hd];
                L = L1 + d;

            case 'goto'
                [fly_pt, curr, L] = add_goto(fly_pt, curr, seg{2}, rho, z);

            case 'orbit'
                [fly_pt, curr, L] = add_orbit(fly_pt, curr, seg{2}, seg{3}, seg{4}, seg{5}, rho, z);

            case 'exit_line'
                d = seg{2};
                p_out = curr(1:2) + d*[cos(curr(3)), sin(curr(3))];
                fly_pt = [fly_pt; p_out(1), p_out(2), z, 1, 0; ...
                          p_out(1), p_out(2), z, -10000, -10000];  %#ok<AGROW>
                curr = [p_out, curr(3)];
                L = d;

            otherwise
                error('make_route_plan:segment', '未知段原语: %s', kind);
        end
        total_len = total_len + L;
    end

    % 末段不是 exit_line 时，补终止行（绕完即止）
    if ~strcmp(last_kind, 'exit_line')
        fly_pt = [fly_pt; curr(1), curr(2), z, -10000, -10000];
    end

    fly_pt = dubins.filter_waypoints(fly_pt);
    num_fly_pt = size(fly_pt, 1);
end

% ================= 原语发射器 =================
function [fly_pt, curr, L] = add_turn(fly_pt, curr, hd, rho, z)
% 最短转向到 hd（弧按 7.5° 离散成直线点）
    dpsi = mod(hd - curr(3) + pi, 2*pi) - pi;
    L = rho*abs(dpsi);
    if abs(dpsi) < 1e-9, return; end
    seg_type = 'L';
    if dpsi < 0, seg_type = 'R'; end
    n = max(1, round(abs(dpsi)/(7.5*pi/180)));
    q = curr;
    for k = 1:n
        q = dubins.interp_seg(curr, abs(dpsi)*k/n, seg_type, rho);
        fly_pt = [fly_pt; q(1), q(2), z, 1, 0];   %#ok<AGROW>
    end
    curr = [q(1), q(2), hd];
end

function [fly_pt, curr, L] = add_goto(fly_pt, curr, vp, rho, z)
% 位姿连接：vp = [x, y, psi]；psi 为 NaN 表示航向自由（16 个候选取最短）
    vp = vp(:)';
    if numel(vp) < 3 || isnan(vp(3))
        best = []; bestL = inf; bestH = 0;
        for h = 0:22.5:337.5
            cand = dubins.core(curr, [vp(1), vp(2), deg2rad(h)], rho);
            if cand.valid
                Lc = sum([cand.param.t, cand.param.p, cand.param.q]) * rho;
                if Lc < bestL, bestL = Lc; best = cand; bestH = h; end
            end
        end
        if isempty(best)
            error('make_route_plan:dubins', 'goto 目标 (%.0f, %.0f) 无可行 Dubins 路径', vp(1), vp(2));
        end
        dp = best;
    else
        dp = dubins.core(curr, vp, rho);
        if ~dp.valid
            error('make_route_plan:dubins', 'goto 目标 (%.0f, %.0f) 的 Dubins 无解', vp(1), vp(2));
        end
        bestH = rad2deg(vp(3));
    end
    fly_pt = append_polyline(fly_pt, dp, z, rho);
    L = sum([dp.param.t, dp.param.p, dp.param.q]) * rho;
    curr = [vp(1), vp(2), deg2rad(bestH)];
end

function [fly_pt, curr, L] = add_orbit(fly_pt, curr, c, r, dir, turns, rho, z)
% 绕圈：Dubins 直达圆上切点 + 正多边形逼近；r 须 ≥ 制导可跟踪下限
    c = c(:)';
    Vc = 34; g = 9.8;
    r_min_track = Vc^2 / (0.02*15*g);         % ≈ 393 m（kdy=0.02 × 侧偏饱和 15 m = 0.3 g）
    if r < max(r_min_track, 400)
        error('make_route_plan:radius', ...
              '半径 %.0f m 小于巡航制导可跟踪下限 %.0f m（稳态过载上限 0.3 g）', r, max(r_min_track, 400));
    end
    if turns ~= round(turns) || turns < 1 || turns > 50
        error('make_route_plan:turns', '圈数 %g 需为 [1,50] 内整数', turns);
    end
    dir_type = 2*strcmpi(dir, 'CCW') + 1*strcmpi(dir, 'CW');
    if dir_type == 0
        error('make_route_plan:direction', 'direction 必须是 CW 或 CCW');
    end
    sgn = 1 - 2*(dir_type == 1);              % CCW=+1（方位角递增），CW=-1

    % 切入：Dubins 直接到圆上切点（航向对齐切线）
    th_near = atan2(curr(2) - c(2), curr(1) - c(1));
    p_entry = c + r*[cos(th_near), sin(th_near)];
    psi_entry = th_near + sgn*pi/2;
    dpath = dubins.core(curr, [p_entry, psi_entry], rho);
    if ~dpath.valid
        error('make_route_plan:dubins', '绕圈切入的 Dubins 无解');
    end
    fly_pt = append_polyline(fly_pt, dpath, z, rho);
    L = sum([dpath.param.t, dpath.param.p, dpath.param.q]) * rho;

    % N 圈圆：正多边形逼近（48 边/圈）
    n_seg = 48;
    dth_seg = 2*pi / n_seg;
    th0 = th_near;
    for k = 1:turns*n_seg - 1
        th = th0 + sgn*k*dth_seg;
        fly_pt = [fly_pt; c(1) + r*cos(th), c(2) + r*sin(th), z, 1, 0];   %#ok<AGROW>
    end
    L = L + (turns*n_seg - 1) * 2*r*sin(dth_seg/2);

    th_last = th0 + sgn*(turns*n_seg - 1)*dth_seg;
    p_last = c + r*[cos(th_last), sin(th_last)];
    curr = [p_last, th_last + sgn*pi/2];      % 末顶点航向 = 切向
end

function fly_pt = append_polyline(fly_pt, path, pz_val, r)
% 把一条 Dubins 路径离散成短直线航点（弧按 ~7.5° 采样，直线段只取终点）
    plens = [path.param.t, path.param.p, path.param.q];
    types = path.param.type;
    curr = path.q0;
    for j = 1:3
        if plens(j) * r < 1
            curr = dubins.interp_seg(curr, plens(j), types(j), r);
            continue;
        end
        if types(j) == 'S'
            n = 1;
        else
            n = max(1, round(plens(j) / (7.5*pi/180)));
        end
        for k = 1:n
            q = dubins.interp_seg(curr, plens(j)*k/n, types(j), r);
            fly_pt = [fly_pt; q(1), q(2), pz_val, 1, 0];   %#ok<AGROW>
        end
        curr = dubins.interp_seg(curr, plens(j), types(j), r);
    end
end
