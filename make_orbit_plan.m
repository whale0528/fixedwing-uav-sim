function [fly_pt, num_fly_pt, total_len] = make_orbit_plan(params, start_xy, start_heading)
% MAKE_ORBIT_PLAN 生成"（可选途经点 →）切入 + N 圈圆 + 切出（可选）"航点表
% params        : struct，字段 center(1x2)、radius_m、direction('CW'/'CCW')、turns(正整数)；
%                 可选字段：
%                   via_poses : cell of [x,y,psi]，绕圈前依次经过的位姿（goto 段）
%                   exit_len  : 切出直线长度 (m)，默认 3000；0 = 绕完即止（不加切出段）
% start_xy      : 当前水平位置 [x_north, y_east]（m）
% start_heading : 当前航向 psi（rad，北偏东为正）
% 输出 fly_pt    : N行x5 航点表（格式同 fly_planfjy.mat，见下）
% 输出 total_len : 计划路径总长度 (m)，供自动定仿真时长
%   [x_north, y_east, z, type, info]；type=1 直线终点；type=2+info∈{1,2} 圆弧起点(1=CW,2=CCW)；
%   type=2+info>2 圆心行(info=半径)；终止行 [.., -10000, -10000]。
%
% 设计决策（经实测教训收敛）：
% 1) 全部路径只用 type=1 直线航点：Dubins 弧段一律按 ~7.5° 离散成短直线（同圆的
%    多边形处理）。模型 fly_phase 的圆弧切换（扫角+mod 卷绕+提前量）不可靠，
%    实测导致切入段切换错位 → 大侧偏 → BTT 滚转失控；直线切换是位置判定，鲁棒。
% 2) 切入用"直接到圆上切点"的 Dubins（航向对齐切线）——全部离散为直线后，
%    圆弧机制的"骑圆"问题不复存在；远圆心场景下切入末段可能沿圆接近切点，
%    圈数度量会略高（执行不受影响）。
% 3) 半径约束：制导调参后 P 通道稳态上限 = kdy×侧偏饱和 = 0.02×15 = 0.3 g，
%    34 m/s 下最小可跟踪半径 ≈ 393 m，下限取 400 m 留裕量。
    Vc = 34; g = 9.8;
    r = params.radius_m; c = params.center;
    r_min_track = Vc^2 / (0.02*15*g);    % ≈ 393 m：kdy=0.02 × 侧偏饱和 15 m = 0.3 g 稳态上限
    if r < max(r_min_track, 400)
        error('make_orbit_plan:radius', ...
              '半径 %.0f m 小于巡航制导可跟踪下限 %.0f m（稳态过载上限 0.3 g）', r, max(r_min_track, 400));
    end
    if params.turns ~= round(params.turns) || params.turns < 1 || params.turns > 50
        error('make_orbit_plan:turns', '圈数 %g 需为 [1,50] 内整数', params.turns);
    end
    dir_type = 2*strcmpi(params.direction,'CCW') + 1*strcmpi(params.direction,'CW');
    if dir_type == 0, error('make_orbit_plan:direction', 'direction 必须是 CW 或 CCW'); end
    sgn = 1 - 2*(dir_type == 1);      % CCW=+1（方位角递增），CW=-1
    z = 300;                          % 与现有 fly_planfjy 相同的平飞高度约定

    if isfield(params, 'via_poses') && ~isempty(params.via_poses)
        via_poses = params.via_poses;
    else
        via_poses = {};
    end
    if isfield(params, 'exit_len') && ~isempty(params.exit_len)
        exit_len = params.exit_len;
    else
        exit_len = 3000;
    end

    total_len = 0;
    fly_pt = [start_xy, z, 1, 0];                     % 首行：当前位置（与现有格式一致）
    curr = [start_xy, start_heading];

    % ---- 0) 前置途经位姿（goto 段：Dubins 求形 → 离散成直线航点）----
    % via_poses 元素为 [x, y, psi]；psi 填 NaN 表示"航向自由"——
    % 在 16 个候选航向上选最短 Dubins，得到近乎直线的逼近（避免指定航向
    % 导致的大钩子路径，如"向东起飞后要去正北 2 km 处"）。
    for v = 1:numel(via_poses)
        vp = via_poses{v};                            % [x, y, psi]
        if numel(vp) < 3 || isnan(vp(3))
            best = []; bestL = inf; bestH = 0;
            for h = 0:22.5:337.5
                cand = dubins.core(curr, [vp(1), vp(2), deg2rad(h)], r);
                if cand.valid
                    L = sum([cand.param.t, cand.param.p, cand.param.q]) * r;
                    if L < bestL, bestL = L; best = cand; bestH = h; end
                end
            end
            if isempty(best)
                error('make_orbit_plan:dubins', '途经点 %d 无可行 Dubins 路径', v);
            end
            dp = best;
        else
            dp = dubins.core(curr, vp, r);
            if ~dp.valid, error('make_orbit_plan:dubins', '途经位姿 %d 的 Dubins 无解', v); end
            bestH = rad2deg(vp(3));
        end
        fly_pt = append_polyline(fly_pt, dp, z, r);
        total_len = total_len + sum([dp.param.t, dp.param.p, dp.param.q]) * r;
        curr = [vp(1), vp(2), deg2rad(bestH)];        % 下一段从这里接着飞
    end

    % ---- 1) 切入：Dubins 直接到圆上切点（航向对齐切线），离散成直线 ----
    % 航点已全部直线化（无圆弧机制），不再有"骑圆"问题，无需 p_pre 退避；
    % 代价：当切入路径末段恰好沿绕圈圆接近切点时，判定带内的圈数会计入这部分
    % 扫角（远圆心任务常见），属度量问题而非执行问题。
    th_near = atan2(curr(2) - c(2), curr(1) - c(1));
    p_entry = c + r*[cos(th_near), sin(th_near)];
    psi_entry = th_near + sgn*pi/2;                   % 切向航向
    dpath = dubins.core(curr, [p_entry, psi_entry], r);
    if ~dpath.valid, error('make_orbit_plan:dubins', 'Dubins 切入无解'); end
    fly_pt = append_polyline(fly_pt, dpath, z, r);
    total_len = total_len + sum([dpath.param.t, dpath.param.p, dpath.param.q]) * r;

    % ---- 2) N 圈圆：正多边形逼近（直线段，位置判定切换）----
    n_seg = 48;                                       % 每圈边数（7.5°/边）
    dth_seg = 2*pi / n_seg;
    chord_len = 2*r*sin(dth_seg/2);
    th0 = th_near;
    for k = 1:params.turns*n_seg - 1
        th = th0 + sgn*k*dth_seg;                     % 顶点方位（CW 递减 / CCW 递增）
        fly_pt = [fly_pt; c(1) + r*cos(th), c(2) + r*sin(th), z, 1, 0];
    end
    total_len = total_len + (params.turns*n_seg - 1)*chord_len;
    th_last = th0 + sgn*(params.turns*n_seg - 1)*dth_seg;
    p_last = c + r*[cos(th_last), sin(th_last)];

    % ---- 3) 切出（exit_len=0 则绕完即止）----
    if exit_len > 0
        psi_exit = th_last + sgn*pi/2;
        p_out = p_last + exit_len*[cos(psi_exit), sin(psi_exit)];
        fly_pt = [fly_pt; p_out, z, 1, 0; p_out(1), p_out(2), z, -10000, -10000];
        total_len = total_len + exit_len;
    else
        fly_pt = [fly_pt; p_last(1), p_last(2), z, -10000, -10000];
    end

    % ---- 4) 过滤（清重合点与 <40 m 杂点；本方案无圆弧行，保留逻辑以防万一）----
    fly_pt = dubins.filter_waypoints(fly_pt);
    num_fly_pt = size(fly_pt, 1);
end

function fly_pt = append_polyline(fly_pt, path, pz_val, r)
% APPEND_POLYLINE 把一条 Dubins 路径离散成短直线航点（全部 type=1）
% 弧段按 ~7.5° 采样，直线段只取终点；模型只做位置判定的直线切换，规避圆弧切换的脆弱性。
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
            n = max(1, round(plens(j) / (7.5*pi/180)));   % 每 7.5° 一个点
        end
        for k = 1:n
            q = dubins.interp_seg(curr, plens(j)*k/n, types(j), r);
            fly_pt = [fly_pt; q(1), q(2), pz_val, 1, 0];   %#ok<AGROW>
        end
        curr = dubins.interp_seg(curr, plens(j), types(j), r);
    end
end
