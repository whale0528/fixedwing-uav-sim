function report = run_orbit_sim(params, start_xy, start_heading, stop_time)
% RUN_ORBIT_SIM params → 圆航点 → base 工作区 → sim('b0307') → 判定（与 LLM 无关）
    arguments
        params (1,1) struct
        start_xy (1,2) double
        start_heading (1,1) double
        stop_time (1,1) double = 600
    end
    [fly_pt, num_fly_pt] = make_orbit_plan(params, start_xy, start_heading);
    save('fly_planfjy.mat', 'fly_pt', 'num_fly_pt');   % 持久化，与现有工作流兼容
    assignin('base', 'fly_pt', fly_pt);                % 模型 Constant 块读 base 工作区
    assignin('base', 'num_fly_pt', num_fly_pt);
    load_system('b0307');                              % set_param 前必须先载入模型
    set_param('b0307', 'StopTime', num2str(stop_time));
    out = sim('b0307');
    assignin('base', 'out', out);                      % plotmake 脚本读 base 工作区的 out
    report = check_orbit_flight(out, params);
end
