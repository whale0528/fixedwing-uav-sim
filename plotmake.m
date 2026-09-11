
    xn = out.simout.Data(:,1); 
xe = out.simout.Data(:,2);
xd = out.simout.Data(:,3);
h = -xd; 
t_sim = out.tout; 
target_xn = out.target_pose.Data(:,1); 
target_xe = out.target_pose.Data(:,2); 
target_h  = out.target_pose.Data(:,3); 
miss_distance = norm([xe(end)-target_xe(end), xn(end)-target_xn(end), h(end)-(-target_h(end))]);

figure('Color', 'w', 'Position', [100, 100, 900, 750]);
hold on;
color_M  = [0.8500, 0.3250, 0.0980]; 
color_T  = [0.0000, 0.4470, 0.7410]; 
color_sh = [0.75, 0.75, 0.75];      
color_md = [0.4660, 0.6740, 0.1880]; 

plot3(xe, xn, zeros(size(h)), 'Color', color_sh, 'LineWidth', 1.5, 'LineStyle', '-.', 'HandleVisibility','off');
plot3(target_xe, target_xn, zeros(size(target_h)), 'Color', color_sh, 'LineWidth', 1.5, 'LineStyle', '-.', 'HandleVisibility','off');

plot3(xe, xn, h, 'LineWidth', 2.5, 'Color', color_M, 'DisplayName', '飞行器轨迹'); 

plot3(target_xe, target_xn, -target_h, 'LineWidth', 2.5, 'Color', color_T, 'LineStyle', '--', 'DisplayName', '目标轨迹');


plot3(xe(1), xn(1), h(1), 'o', 'MarkerSize', 7, 'MarkerEdgeColor', color_M, 'MarkerFaceColor', 'w', 'LineWidth', 1.5, 'DisplayName', '飞行器起点'); 
plot3(target_xe(1), target_xn(1), -target_h(1), 'o', 'MarkerSize', 7, 'MarkerEdgeColor', color_T, 'MarkerFaceColor', 'w', 'LineWidth', 1.5, 'DisplayName', '目标起点');


plot3(xe(end), xn(end), h(end), 'd', 'MarkerSize', 8, 'MarkerFaceColor', color_M, 'MarkerEdgeColor', 'k', 'DisplayName', '截击位置 (飞行器)');
plot3(target_xe(end), target_xn(end), -target_h(end), 'h', 'MarkerSize', 9, 'MarkerFaceColor', color_T, 'MarkerEdgeColor', 'k', 'DisplayName', '截击位置 (目标)');


line([xe(end) target_xe(end)], [xn(end) target_xn(end)], [h(end) -target_h(end)], ...
    'Color', color_md, 'LineStyle', ':', 'LineWidth', 2, 'DisplayName', sprintf('末端视线 (脱靶量: %.2f m)', miss_distance));


% text_x = (xe(end) + target_xe(end))/2;
% text_y = (xn(end) + target_xn(end))/2;
% text_z = (h(end) + (-target_h(end)))/2 + 20; 
% text(text_x, text_y, text_z, sprintf(' 脱靶量: %.2f m', miss_distance), ...
%     'FontSize', 11, 'FontWeight', 'bold', 'Color', color_md, ...
%     'BackgroundColor', [1 1 1 0.1], 'EdgeColor', color_md, 'Margin', 3);

grid on;
set(gca, 'GridLineStyle', ':', 'GridColor', 'k', 'GridAlpha', 0.15); 
axis equal; 

curr_ax = axis; 

x_margin = (curr_ax(2) - curr_ax(1)) * 0.1;
y_margin = (curr_ax(4) - curr_ax(3)) * 0.1;
z_margin = (max(max(h), max(-target_h))) * 0.1;

new_axis = [curr_ax(1)-x_margin, curr_ax(2)+x_margin, ... 
            curr_ax(3)-y_margin, curr_ax(4)+y_margin, ... 
            0, max(max(h), max(-target_h)) + z_margin + 50]; % 高度底线锁死在0    
axis(new_axis);

set(gca, 'FontName', 'Times New Roman', 'FontSize', 11);
xlabel('\bf 东向 East (m)', 'FontSize', 12, 'FontName', 'Microsoft YaHei'); 
ylabel('\bf 北向 North (m)', 'FontSize', 12, 'FontName', 'Microsoft YaHei'); 
zlabel('\bf 高度 Height (m)', 'FontSize', 12, 'FontName', 'Microsoft YaHei');

% 标题与图例设定
title('\bf 飞行器与目标 3D 截击轨迹仿真', 'FontSize', 14, 'FontName', 'Microsoft YaHei');
leg = legend('Location', 'northeast');
set(leg, 'Box', 'off', 'FontSize', 11, 'FontName', 'Microsoft YaHei', 'Color', 'none');

view(35, 25); 

box on;