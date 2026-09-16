function report = run_orbit_sim(params, start_xy, start_heading, stop_time)
% RUN_ORBIT_SIM 绕圈任务一键执行：参数 → 航点 → 仿真 → 判定
% 通用路线请直接用：make_route_plan（生成航点）+ run_route_sim（执行仿真）。
% stop_time: 可选显式指定；缺省或 0 时按计划路径总长度自动计算（完成后即停）。
    arguments
        params (1,1) struct
        start_xy (1,2) double
        start_heading (1,1) double
        stop_time (1,1) double = 0
    end
    [fly_pt, ~, total_len] = make_orbit_plan(params, start_xy, start_heading);
    out = run_route_sim(fly_pt, total_len, stop_time);
    report = check_orbit_flight(out, params);
end
