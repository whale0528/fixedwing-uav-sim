function [fly_pt, num_fly_pt] = make_orbit_plan(params, start_xy, start_heading)
% MAKE_ORBIT_PLAN 生成"切入 + N 圈圆 + 切出"航点表（fly_pt 已过滤格式）
% params        : struct（与任务 5 的 check_orbit_params 输出同构；本任务测试用手工构造），
%                 字段 center(1x2)、radius_m、direction('CW'/'CCW')、turns(正整数)
% start_xy      : 当前水平位置 [x_north, y_east]（m）
% start_heading : 当前航向 psi（rad，北偏东为正）
% 输出 fly_pt    : N行x5 航点表，格式与 fly_planfjy.mat 一致：
%   [x_north, y_east, z, type, info]；type=1 直线终点；type=2+info∈{1,2} 圆弧起点(1=CW,2=CCW)；
%   type=2+info>2 圆心行(info=半径)；终止行 [.., -10000, -10000]。
%
% 设计决策（经 3 次实测教训收敛）：
% 1) 绕圈不用圆弧航点，改用正多边形（短直线段）逼近：
%    模型 fly_phase 的圆弧切换按"扫角 + mod 卷绕 + 0.01 rad 提前量"判定，长弧串联时
%    出现整圈弧被瞬间跳过、第 3 圈方向反转等不可靠行为；直线切换是位置判定（投影
%    距离），且被原任务证明鲁棒。每圈 n_seg=48 边（7.5°/边，弦矢高 4.3 m，弦长 262 m）。
% 2) 切入用"切向直线段"：Dubins 先到切线上、圆外 2.5r 处的预切点，再沿切线直线切入，
%    避免 Dubins 末段弧与绕圈圆共圆心（"骑圆"）。
% 3) 半径约束：巡航制导律 P 通道稳态上限 0.075 g（kdy=0.005 × 侧偏饱和 15 m），
%    34 m/s 下最小可跟踪半径 ≈ 1573 m，故 r 下限取 1600 m（推荐 2000 m）。
    Vc = 34; g = 9.8;
    r = params.radius_m; c = params.center;
    r_min_track = Vc^2 / (0.005*15*g);   % ≈ 1573 m，制导稳态能力下限
    if r < max(r_min_track, 1600)
        error('make_orbit_plan:radius', ...
              '半径 %.0f m 小于巡航制导可跟踪下限 %.0f m（稳态过载上限 0.075 g）', r, max(r_min_track, 1600));
    end
    if params.turns ~= round(params.turns) || params.turns < 1 || params.turns > 50
        error('make_orbit_plan:turns', '圈数 %g 需为 [1,50] 内整数', params.turns);
    end
    dir_type = 2*strcmpi(params.direction,'CCW') + 1*strcmpi(params.direction,'CW');
    if dir_type == 0, error('make_orbit_plan:direction', 'direction 必须是 CW 或 CCW'); end
    sgn = 1 - 2*(dir_type == 1);      % CCW=+1（方位角递增），CW=-1
    z = 300;                          % 与现有 fly_planfjy 相同的平飞高度约定

    % ---- 1) 切入：Dubins 到切线上、圆外 2.5r 处的预切点，再沿切向直线切入 ----
    th_near = atan2(start_xy(2) - c(2), start_xy(1) - c(1));
    p_entry = c + r*[cos(th_near), sin(th_near)];
    psi_entry = th_near + sgn*pi/2;                           % 切向航向
    L_tan = 2.5*r;                                            % 切向直线段长度（保证末段弧不进入绕圈圆）
    p_pre = p_entry - L_tan*[cos(psi_entry), sin(psi_entry)];
    dpath = dubins.core([start_xy, start_heading], [p_pre, psi_entry], r);
    if ~dpath.valid, error('make_orbit_plan:dubins', 'Dubins 切入无解'); end

    fly_pt = [start_xy, z, 1, 0];                             % 首行：当前位置（与现有格式一致）
    fly_pt = dubins.append_segments(fly_pt, [p_pre, psi_entry], dpath, z, r);
    fly_pt = [fly_pt; p_entry(1), p_entry(2), z, 1, 0];       % 切向直线段终点（圆上切点）

    % ---- 2) N 圈圆：正多边形逼近（全部直线段，位置判定切换）----
    n_seg = 48;                                               % 每圈边数（7.5°/边）
    dth_seg = 2*pi / n_seg;
    th0 = th_near;
    for k = 1:params.turns*n_seg - 1
        th = th0 + sgn*k*dth_seg;                             % 顶点方位（CW 递减 / CCW 递增）
        fly_pt = [fly_pt; c(1) + r*cos(th), c(2) + r*sin(th), z, 1, 0];
    end
    th_last = th0 + sgn*(params.turns*n_seg - 1)*dth_seg;     % 末顶点方位
    p_last = c + r*[cos(th_last), sin(th_last)];

    % ---- 3) 切出直线 3000 m + 终止行（足够长，让航向在制导冻结前被拉正）----
    psi_exit = th_last + sgn*pi/2;
    p_out = p_last + 3000*[cos(psi_exit), sin(psi_exit)];
    fly_pt = [fly_pt; p_out, z, 1, 0; p_out(1), p_out(2), z, -10000, -10000];

    % ---- 4) 过滤合并（重合的终点行/起点行 → 单行；清杂点；保留圆心行）----
    fly_pt = dubins.filter_waypoints(fly_pt);
    num_fly_pt = size(fly_pt, 1);
end
