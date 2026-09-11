function [fly_pt, num_fly_pt] = make_orbit_plan(params, start_xy, start_heading)
% MAKE_ORBIT_PLAN 生成"切入 + N 圈圆 + 切出"航点表（fly_pt 已过滤格式）
% params        : struct（与任务 5 的 check_orbit_params 输出同构；本任务测试用手工构造），
%                 字段 center(1x2)、radius_m、direction('CW'/'CCW')、turns(正整数)
% start_xy      : 当前水平位置 [x_north, y_east]（m）
% start_heading : 当前航向 psi（rad，北偏东为正）
% 输出 fly_pt    : N行x5 航点表，格式与 fly_planfjy.mat 一致：
%   [x_north, y_east, z, type, info]；type=1 直线终点；type=2+info∈{1,2} 圆弧起点(1=CW,2=CCW)；
%   type=2+info>2 圆心行(info=半径)；终止行 [.., -10000, -10000]。
% 设计要点：每圈扫角 2π-ε（ε=0.05 rad），终点行与下一圈起点行坐标重合，
% 由 dubins.filter_waypoints 合并为一行，满足 fly_phase 的切换条件 sweep >= total_sweep - 0.01。
    Vc = 34; g = 9.8; roll_max = deg2rad(30);
    r = params.radius_m; c = params.center;
    r_min = Vc^2 / (g * tan(roll_max));
    if r < 1.2*r_min
        error('make_orbit_plan:radius', '半径 %.0f m 小于安全下限 %.0f m', r, 1.2*r_min);
    end
    if params.turns ~= round(params.turns) || params.turns < 1 || params.turns > 50
        error('make_orbit_plan:turns', '圈数 %g 需为 [1,50] 内整数', params.turns);
    end
    dir_type = 2*strcmpi(params.direction,'CCW') + 1*strcmpi(params.direction,'CW');
    if dir_type == 0, error('make_orbit_plan:direction', 'direction 必须是 CW 或 CCW'); end
    sgn = 1 - 2*(dir_type == 1);      % CCW=+1（方位角递增），CW=-1
    eps = 0.05;                       % 每圈航点簿记裕量 (rad)
    z = 300;                          % 与现有 fly_planfjy 相同的平飞高度约定

    % ---- 1) 切入：Dubins 从起点到圆上最近方位切点（rho=r，曲率连续）----
    th_near = atan2(start_xy(2) - c(2), start_xy(1) - c(1));
    p_entry = c + r*[cos(th_near), sin(th_near)];
    psi_entry = th_near + sgn*pi/2;                           % 切向航向
    dpath = dubins.core([start_xy, start_heading], [p_entry, psi_entry], r);
    if ~dpath.valid, error('make_orbit_plan:dubins', 'Dubins 切入无解'); end

    fly_pt = [start_xy, z, 1, 0];                             % 首行：当前位置（与现有格式一致）
    fly_pt = dubins.append_segments(fly_pt, [p_entry, psi_entry], dpath, z, r);

    % ---- 2) N 圈圆：每圈 2π-ε；终点行与下一圈起点行坐标重合，过滤时合并 ----
    th0 = th_near;                                            % 第 1 圈起点方位
    for k = 1:params.turns
        th_s = th0 - sgn*(k-1)*eps;                           % 本圈起点方位
        th_x = th_s + sgn*(2*pi - eps);                       % 本圈终点方位
        p_s = c + r*[cos(th_s), sin(th_s)];
        p_x = c + r*[cos(th_x), sin(th_x)];
        fly_pt = [fly_pt; p_s, z, 2, dir_type; c, z, 2, r; p_x, z, 1, 0];
    end
    th_last = th0 - sgn*params.turns*eps;                     % 末圈终点方位
    p_last = c + r*[cos(th_last), sin(th_last)];

    % ---- 3) 切出直线 500 m + 终止行 ----
    psi_exit = th_last + sgn*pi/2;
    p_out = p_last + 500*[cos(psi_exit), sin(psi_exit)];
    fly_pt = [fly_pt; p_out, z, 1, 0; p_out(1), p_out(2), z, -10000, -10000];

    % ---- 4) 过滤合并（重合的终点行/起点行 → 单行；清杂点；保留圆心行）----
    fly_pt = dubins.filter_waypoints(fly_pt);
    num_fly_pt = size(fly_pt, 1);
end
