function plot_astar_phases(raw_obs, map, mapWidth, mapHeight, ...
                            path_w, turning_pts, feasible_pts, reduced_pts)
%PLOT_ASTAR_PHASES 分阶段输出 A* 路径规划的可视化结果

t_circle = linspace(0, 2*pi, 50);

%% 图1 — 仅障碍物地图
figure('Color', 'w', 'Name', 'A*障碍物地图');
colormap([1 1 1; 1 0.8 0.8]);
imagesc([0, mapWidth], [0, mapHeight], map);
set(gca, 'YDir', 'normal'); hold on; grid on;
axis equal;
xlabel('东向 Y / m'); ylabel('北向 X / m');
title('A*路径规划 — 障碍物分布');

for i = 1:size(raw_obs, 1)
    fill(raw_obs(i,2) + raw_obs(i,3)*cos(t_circle), ...
         raw_obs(i,1) + raw_obs(i,3)*sin(t_circle), ...
         [0.8 0 0], 'EdgeColor', 'none');
end

%% 图2 — 原始栅格路径
figure('Color', 'w', 'Name', 'A*原始路径');
colormap([1 1 1; 1 0.8 0.8]);
imagesc([0, mapWidth], [0, mapHeight], map);
set(gca, 'YDir', 'normal'); hold on; grid on;
axis equal;
xlabel('东向 Y / m'); ylabel('北向 X / m');
title(sprintf('A*路径规划 — 原始路径点 (%d个)', size(path_w,1)));

for i = 1:size(raw_obs, 1)
    fill(raw_obs(i,2) + raw_obs(i,3)*cos(t_circle), ...
         raw_obs(i,1) + raw_obs(i,3)*sin(t_circle), ...
         [0.8 0 0], 'EdgeColor', 'none');
end
plot(path_w(:,2), path_w(:,1), 'b.', 'MarkerSize', 12);

%% 图3 — 拐点检测
removed_3 = setdiff(path_w, turning_pts, 'rows');
figure('Color', 'w', 'Name', 'A*拐点检测');
colormap([1 1 1; 1 0.8 0.8]);
imagesc([0, mapWidth], [0, mapHeight], map);
set(gca, 'YDir', 'normal'); hold on; grid on;
axis equal;
xlabel('东向 Y / m'); ylabel('北向 X / m');
title(sprintf('A*路径规划 — 拐点检测 (保留%d个)', size(turning_pts,1)));

for i = 1:size(raw_obs, 1)
    fill(raw_obs(i,2) + raw_obs(i,3)*cos(t_circle), ...
         raw_obs(i,1) + raw_obs(i,3)*sin(t_circle), ...
         [0.8 0 0], 'EdgeColor', 'none');
end
plot(path_w(:,2), path_w(:,1), 'b-', 'LineWidth', 1);
if ~isempty(removed_3)
    plot(removed_3(:,2), removed_3(:,1), '.', 'Color', [0.7 0.7 0.7], 'MarkerSize', 8);
end
plot(turning_pts(:,2), turning_pts(:,1), 'go', 'MarkerSize', 8, 'MarkerFaceColor', 'g');

%% 图4 — 转弯半径筛选
removed_4 = setdiff(turning_pts, feasible_pts, 'rows');
figure('Color', 'w', 'Name', 'A*转弯半径筛选');
colormap([1 1 1; 1 0.8 0.8]);
imagesc([0, mapWidth], [0, mapHeight], map);
set(gca, 'YDir', 'normal'); hold on; grid on;
axis equal;
xlabel('东向 Y / m'); ylabel('北向 X / m');
title(sprintf('A*路径规划 — 转弯半径筛选 (保留%d个)', size(feasible_pts,1)));

for i = 1:size(raw_obs, 1)
    fill(raw_obs(i,2) + raw_obs(i,3)*cos(t_circle), ...
         raw_obs(i,1) + raw_obs(i,3)*sin(t_circle), ...
         [0.8 0 0], 'EdgeColor', 'none');
end
plot(path_w(:,2), path_w(:,1), 'b-', 'LineWidth', 1);
if ~isempty(removed_4)
    plot(removed_4(:,2), removed_4(:,1), '.', 'Color', [0.7 0.7 0.7], 'MarkerSize', 8);
end
plot(feasible_pts(:,2), feasible_pts(:,1), 'co', 'MarkerSize', 8, 'MarkerFaceColor', 'c');

%% 图5 — 视线通视剪枝
removed_5 = setdiff(feasible_pts, reduced_pts, 'rows');
figure('Color', 'w', 'Name', 'A*视线剪枝');
colormap([1 1 1; 1 0.8 0.8]);
imagesc([0, mapWidth], [0, mapHeight], map);
set(gca, 'YDir', 'normal'); hold on; grid on;
axis equal;
xlabel('东向 Y / m'); ylabel('北向 X / m');
title(sprintf('A*路径规划 — 视线通视剪枝 (保留%d个)', size(reduced_pts,1)));

for i = 1:size(raw_obs, 1)
    fill(raw_obs(i,2) + raw_obs(i,3)*cos(t_circle), ...
         raw_obs(i,1) + raw_obs(i,3)*sin(t_circle), ...
         [0.8 0 0], 'EdgeColor', 'none');
end
plot(path_w(:,2), path_w(:,1), 'b-', 'LineWidth', 1);
if ~isempty(removed_5)
    plot(removed_5(:,2), removed_5(:,1), '.', 'Color', [0.7 0.7 0.7], 'MarkerSize', 8);
end
plot(reduced_pts(:,2), reduced_pts(:,1), 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');

end
