function out = run_route_sim(fly_pt, total_len, stop_time)
% RUN_ROUTE_SIM 通用仿真执行：任意航点表 → base 工作区 → sim('b0307')
% fly_pt    : make_route_plan / make_orbit_plan 生成的 Nx5 航点表
% total_len : 计划路径总长度 (m)；stop_time 缺省时用它自动定仿真时长
% stop_time : 可选，显式指定（0 或缺省 = 自动：total_len/32 + 4 s）
% 说明：仿真前后不触碰模型文件；结果写入 base 工作区的 out（供 plotmake/plot_traj_topview 使用）。
    num_fly_pt = size(fly_pt, 1);
    save('fly_planfjy.mat', 'fly_pt', 'num_fly_pt');   % 持久化，与原工作流兼容
    assignin('base', 'fly_pt', fly_pt);                % 模型 Constant 块读 base 工作区
    assignin('base', 'num_fly_pt', num_fly_pt);
    load_system('b0307');                              % set_param 前必须先载入模型
    if nargin < 3 || isempty(stop_time) || stop_time <= 0
        stop_time = ceil(total_len/32) + 4;            % 实测含起飞平均速度 ≈32 m/s
    end
    set_param('b0307', 'StopTime', num2str(stop_time));
    fprintf('航点 %d 行，计划路径 %.0f m，仿真时长 %.0f s\n', num_fly_pt, total_len, stop_time);
    out = sim('b0307');
    assignin('base', 'out', out);                      % 画图脚本读 base 工作区的 out
end
