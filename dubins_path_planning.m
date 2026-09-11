%% 1. 初始化
pz = 300 * ones(size(px));
n = length(px);
Vc = 34; g = 9.8; roll_max = 15*pi/180;
r_max = Vc^2 / (g * tan(roll_max));

theta = zeros(n,1);
for i = 1:n
    if i < n
        theta(i) = atan2(py(i+1)-py(i), px(i+1)-px(i));
    else
        theta(i) = atan2(py(n)-py(n-1), px(n)-px(n-1));
    end
end

fly_pt = [px(1), py(1), pz(1), 1, 0];

for i = 1:n-1
    q0 = [px(i), py(i), theta(i)];
    q1 = [px(i+1), py(i+1), theta(i+1)];
    path = dubins.core(q0, q1, r_max);

    if path.valid
        fly_pt = dubins.append_segments(fly_pt, q1, path, pz(i+1), r_max);
    else
        if norm(fly_pt(end,1:2) - q1(1:2)) > 1
            fly_pt = [fly_pt; q1(1), q1(2), pz(i+1), 1, 0];
        end
    end
end
% 终止符
fly_pt = [fly_pt; px(end), py(end), pz(end), -10000, -10000];


% ===== 修正后的航点过滤逻辑（已提取到 +dubins 包）=====
fly_pt = dubins.filter_waypoints(fly_pt);

num_fly_pt = size(fly_pt, 1);
save('fly_planfjy.mat', 'fly_pt', 'num_fly_pt');
% ===================================



figure('Color', 'w', 'Position', [100, 100, 800, 600]);
hold on; grid on; axis equal;

% plot(East, North) -> plot(py, px)
xlabel('东向 Y (米)');
ylabel('北向 X (米)');
title('Dubins路径');

% 定义颜色
colorMap = struct('L', [1 0 0], 'R', [0 0 1], 'S', [0 0.8 0]);
legend_handles = [];

fprintf('\n--- 航段详细数据 (北-东坐标系) ---\n');
for i = 1:n-1
    q0 = [px(i), py(i), theta(i)];
    q1 = [px(i+1), py(i+1), theta(i+1)];
    path = dubins.core(q0, q1, r_max);

    if path.valid
        fprintf('路段 %d (%s):\n', i, path.param.type);
        curr_q = q0;
        params = [path.param.t, path.param.p, path.param.q];
        types = path.param.type;

        for j = 1:3
            seg_type = types(j);
            seg_len = params(j) * r_max;

            t_samples = linspace(0, params(j), max(50, ceil(seg_len/5)));
            pts_x = zeros(length(t_samples), 1);
            pts_y = zeros(length(t_samples), 1);

            for k = 1:length(t_samples)
                temp_q = dubins.interp_seg(curr_q, t_samples(k), seg_type, r_max);
                pts_x(k) = temp_q(1);
                pts_y(k) = temp_q(2);
            end

            h = plot(pts_y, pts_x, 'LineWidth', 2.5, 'Color', colorMap.(seg_type));

            % 收集图例句柄（仅收集前三种类型的代表）
            if i == 1, legend_handles(j) = h; end

            fprintf('  - %c 段: %.2f m\n', seg_type, seg_len);
            curr_q = dubins.interp_seg(curr_q, params(j), seg_type, r_max);
        end
    else
        plot([py(i) py(i+1)], [px(i) px(i+1)], 'k--', 'LineWidth', 1);
        fprintf('路段 %d: Dubins 无解，使用直线连接\n', i);
    end
end

% 绘制航点 (Y, X)
plot(py, px, 'ko', 'MarkerFaceColor', 'y', 'MarkerSize', 8, 'DisplayName', '航点');

% 绘制航向箭头
% quiver(py, px, sin(theta), cos(theta), 0.05, 'k', 'LineWidth', 1.5);

% 修正图例
legend(legend_handles, {'右转 (R)', '直行 (S)', '左转 (S)'}, 'Location', 'best');

set(gca, 'YDir', 'normal', 'XDir', 'normal');
