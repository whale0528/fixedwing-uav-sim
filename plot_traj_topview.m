% PLOT_TRAJ_TOPVIEW 飞行轨迹俯视图（2D）
% 用法：跑完仿真后，命令窗口输入 plot_traj_topview 回车。
% 读取 base 工作区的 out（run_orbit_sim 会写入；原截击任务 sim 后同样可用）。
% 显示：飞行器地面轨迹（横轴=东向，纵轴=北向）+ 起终点，无地图元素。

if evalin('base', 'exist(''out'',''var'')') ~= 1
    error('plot_traj_topview:noOut', 'base 工作区没有 out，请先跑仿真');
end
out = evalin('base', 'out');
xn = out.simout.Data(:,1);
xe = out.simout.Data(:,2);
h  = -out.simout.Data(:,3);

figure('Color', 'w', 'Position', [100 100 900 780]);
hold on; grid on; axis equal;

% 飞行轨迹（横轴=东向，纵轴=北向）
plot(xe, xn, 'b-', 'LineWidth', 1.6, 'DisplayName', '飞行轨迹');
plot(xe(1), xn(1), 'ko', 'MarkerFaceColor', 'w', 'MarkerSize', 9, ...
     'DisplayName', '起点');
plot(xe(end), xn(end), 'rx', 'MarkerSize', 12, 'LineWidth', 2, ...
     'DisplayName', '终点');

xlabel('东向 (m)'); ylabel('北向 (m)');
title(sprintf('飞行轨迹俯视图（%.0f s，高度 %.0f~%.0f m）', out.tout(end), min(h), max(h)));
legend('Location', 'best'); box on;
