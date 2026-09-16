function [fly_pt, num_fly_pt, total_len] = make_orbit_plan(params, start_xy, start_heading)
% MAKE_ORBIT_PLAN 绕圈任务封装：把绕圈参数翻译成"段原语列表"交给通用生成器
% 通用生成器见 make_route_plan（支持 turn_to / line / line_to / goto / orbit / exit_line）。
% 本函数保留原有接口，等价于下列动作单：
%   [转向 heading_deg + 直飞 dist_m（若有 goto）] → [依次 goto 各 via_poses]
%   → [绕圈 center/radius/direction/turns] → [切出 exit_len（>0 时）]
%
% params        : struct，字段 center(1x2)、radius_m、direction('CW'/'CCW')、turns(正整数)；
%                 可选字段：
%                   goto      : struct('heading_deg', ψ, 'dist_m', d)，先转向再直飞
%                   via_poses : cell of [x,y,psi]，绕圈前依次经过的位姿（psi 可 NaN=自由）
%                   exit_len  : 切出直线长度 (m)，默认 3000；0 = 绕完即止
% start_xy      : 当前水平位置 [x_north, y_east]（m）
% start_heading : 当前航向 psi（rad，北偏东为正）
% 输出 fly_pt / num_fly_pt / total_len 同 make_route_plan。
%
% 设计约束（实测收敛）：
% 1) 全部弧段离散成短直线航点——模型 fly_phase 的圆弧切换（扫角+mod 卷绕）不可靠；
% 2) 任何弧半径 ≥ ~400 m（制导 P 通道稳态上限 0.3 g 决定的曲率下限）。
    segs = {};

    % goto：先转向再严格直飞（如"向正北飞 2000 m"）
    if isfield(params, 'goto') && ~isempty(params.goto) && params.goto.dist_m > 0
        segs{end+1} = {'turn_to', params.goto.heading_deg};
        segs{end+1} = {'line',    params.goto.dist_m};
    end

    % via_poses：绕圈前依次经过的位姿
    if isfield(params, 'via_poses') && ~isempty(params.via_poses)
        for v = 1:numel(params.via_poses)
            segs{end+1} = {'goto', params.via_poses{v}};   %#ok<AGROW>
        end
    end

    % 绕圈
    segs{end+1} = {'orbit', params.center, params.radius_m, params.direction, params.turns};

    % 切出（默认 3000 m；0 = 绕完即止）
    if isfield(params, 'exit_len') && ~isempty(params.exit_len)
        exit_len = params.exit_len;
    else
        exit_len = 3000;
    end
    if exit_len > 0
        segs{end+1} = {'exit_line', exit_len};
    end

    % 转向/Dubins 弧半径沿用绕圈半径（与原有行为一致）
    opt = struct('z', 300, 'turn_radius', params.radius_m);
    [fly_pt, num_fly_pt, total_len] = make_route_plan(segs, [start_xy, start_heading], opt);
end
