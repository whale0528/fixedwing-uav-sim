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
% 1) 绕圈用正多边形（48 边/圈，直线段）逼近——模型直线切换（位置判定）鲁棒，
%    圆弧切换（扫角+mod 卷绕+提前量）长弧串联不可靠；
% 2) 切入用"切向直线段"：Dubins 先到切线上、圆外 2.5r 处的预切点，避免末段弧"骑圆"；
% 3) 半径约束：制导调参后 P 通道稳态上限 = kdy×侧偏饱和 = 0.02×40 = 0.8 g，
%    34 m/s 下最小可跟踪半径 ≈ 147 m，下限取 200 m 留裕量。
    Vc = 34; g = 9.8;
    r = params.radius_m; c = params.center;
    r_min_track = Vc^2 / (0.02*40*g);    % ≈ 147 m
    if r < max(r_min_track, 200)
        error('make_orbit_plan:radius', ...
              '半径 %.0f m 小于巡航制导可跟踪下限 %.0f m（稳态过载上限 0.8 g）', r, max(r_min_track, 200));
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

    % ---- 0) 前置途经位姿（goto 段，Dubins 依次连接）----
    for v = 1:numel(via_poses)
        vp = via_poses{v};                            % [x, y, psi]
        dp = dubins.core(curr, vp, r);
        if ~dp.valid, error('make_orbit_plan:dubins', '途经位姿 %d 的 Dubins 无解', v); end
        fly_pt = dubins.append_segments(fly_pt, vp, dp, z, r);
        total_len = total_len + sum([dp.param.t, dp.param.p, dp.param.q]) * r;
        curr = vp;
    end

    % ---- 1) 切入：Dubins 到切线上、圆外 2.5r 处的预切点，再沿切向直线切入 ----
    % 关键：若 Dubins 直接切到圆上切点，其末段圆弧可能与绕圈圆共圆心（"骑圆"），
    % 整圈弧会被 mod 卷绕瞬间跳过；切向直线段的切换是位置判定，可靠。
    th_near = atan2(curr(2) - c(2), curr(1) - c(1));
    p_entry = c + r*[cos(th_near), sin(th_near)];
    psi_entry = th_near + sgn*pi/2;                   % 切向航向
    L_tan = 2.5*r;                                    % 切向直线段长度（保证末段弧不进入绕圈圆）
    p_pre = p_entry - L_tan*[cos(psi_entry), sin(psi_entry)];
    dpath = dubins.core(curr, [p_pre, psi_entry], r);
    if ~dpath.valid, error('make_orbit_plan:dubins', 'Dubins 切入无解'); end
    fly_pt = dubins.append_segments(fly_pt, [p_pre, psi_entry], dpath, z, r);
    total_len = total_len + sum([dpath.param.t, dpath.param.p, dpath.param.q]) * r + L_tan;
    fly_pt = [fly_pt; p_entry(1), p_entry(2), z, 1, 0];   % 切向直线段终点（圆上切点）

    % ---- 2) N 圈圆：正多边形逼近（全部直线段，位置判定切换）----
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

    % ---- 4) 过滤合并（重合的终点行/起点行 → 单行；清杂点；保留圆心行）----
    fly_pt = dubins.filter_waypoints(fly_pt);
    num_fly_pt = size(fly_pt, 1);
end
