    Vc = 34; g = 9.8; roll_max = 30*pi/180;
    r_max = Vc^2 / (g * tan(roll_max)) % 最小转弯半径
    %目标性能
    theta_t = 0;
    psi_t = 0;
    V_t = 0;
    xt0 = 6500;
    yt0 = 9000;
    zt0 = 0;

    mapWidth = 10000; res = 15;
    mapHeight = 10000;
    rows = ceil(mapHeight / res) + 1; 
    cols = ceil(mapWidth / res) + 1;
    
    % 膨胀半径：
    inflation_radius =  1.2*r_max; 
    
    % 障碍物
    raw_obs = [1500, 1500, 800; 5500, 5000, 800; 3500, 6500, 800;5500,7500,900;];
    save('raw_obs.mat', 'raw_obs');
    
    % 地图 (0: 通路, 1: 障碍)
    map = zeros(rows, cols);
    for i = 1:size(raw_obs, 1)
        [E_grid, N_grid] = meshgrid((0:cols-1)*res, (0:rows-1)*res);
        dist = sqrt((N_grid - raw_obs(i,1)).^2 + (E_grid - raw_obs(i,2)).^2);
        map(dist < (raw_obs(i,3) + inflation_radius)) = 1;
    end
    
    startPos = [0, 0]; goalPos = [xt0, yt0];
    startIdx = round(startPos / res) + 1;
    goalIdx = round(goalPos / res) + 1;
    map(startIdx(1), startIdx(2)) = 0; map(goalIdx(1), goalIdx(2)) = 0;
    
    %% 2. 可视化
    figure('Color', 'w', 'Name', 'A*动态搜索');
    colormap([1 1 1; 1 0.8 0.8]);
    imagesc([0, mapWidth], [0, mapHeight], map); 
    set(gca, 'YDir', 'normal'); hold on; grid on;
    axis equal;
    xlabel('东向 Y / m'); ylabel('北向 X / m');
    title('A*算法 — 动态搜索');
    
    t_circle = linspace(0, 2*pi, 50);
    for i = 1:size(raw_obs, 1)
        fill(raw_obs(i,2) + raw_obs(i,3)*cos(t_circle), ...
             raw_obs(i,1) + raw_obs(i,3)*sin(t_circle), [0.8 0 0], 'EdgeColor', 'none');
    end
    
    h_explored = plot(NaN, NaN, 'c.', 'MarkerSize', 8);
    h_path_temp = plot(NaN, NaN, 'b-', 'LineWidth', 1.5); 
    
    %% 3. A* 算法
    openList = [norm(startIdx-goalIdx), 0, startIdx(1), startIdx(2), 0, 0]; 
    closedList = false(rows, cols);
    gScore = inf(rows, cols); gScore(startIdx(1), startIdx(2)) = 0;
    parentR = zeros(rows, cols); parentC = zeros(rows, cols);
    
    found = false;
    iter = 0;
    while ~isempty(openList)
        iter = iter + 1;
        [~, idx] = min(openList(:,1));
        curr = openList(idx,:); openList(idx,:) = [];
        r = curr(3); c = curr(4);
        
        if closedList(r, c), continue; end
        closedList(r, c) = true;
        
        if mod(iter, 15) == 0
            explored_pts = find(closedList);
            [er, ec] = ind2sub([rows, cols], explored_pts);
            set(h_explored, 'XData', (ec-1)*res, 'YData', (er-1)*res);
            drawnow limitrate;
        end
        
        if r == goalIdx(1) && c == goalIdx(2), found = true; break; end
        
        for dr = -1:1
            for dc = -1:1
                if dr==0 && dc==0, continue; end
                nr = r + dr; nc = c + dc;
                if nr>=1 && nr<=rows && nc>=1 && nc<=cols && map(nr,nc)==0
                    moveCost = sqrt(dr^2 + dc^2);
                    newG = gScore(r, c) + moveCost;
                    if newG < gScore(nr, nc)
                        gScore(nr, nc) = newG;
                        f = newG + norm([nr, nc] - goalIdx);
                        openList = [openList; f, newG, nr, nc, r, c];
                        parentR(nr, nc) = r; parentC(nr, nc) = c;
                    end
                end
            end
        end
    end
    
    %% 4. 稀疏化 
    if found
        % 1. 提取原始栅格路径
        res_path = [goalIdx(1), goalIdx(2)];
        while any(res_path(1,:) ~= startIdx)
            currP = res_path(1,:);
            res_path = [parentR(currP(1), currP(2)), parentC(currP(1), currP(2)); res_path];
        end
        path_w = (res_path - 1) * res;
        
        % 2.仅保留拐点
        turning_pts = path_w(1, :);
        for i = 2:size(path_w, 1)-1
            v1 = path_w(i,:) - path_w(i-1,:); 
            v2 = path_w(i+1,:) - path_w(i, :);
            if norm(cross([v1/norm(v1), 0], [v2/norm(v2), 0])) > 5/57.3
                turning_pts = [turning_pts; path_w(i, :)]; 
            end
        end
        turning_pts = [turning_pts; path_w(end, :)];
    
        % 3. 保留满足转弯半径约束的关键点
        feasible_pts = turning_pts(1,:);
        margin = 0.5 * r_max;
        i = 2;
    
        while i < size(turning_pts, 1)
            candidate = turning_pts(i,:);
            prev_pt = feasible_pts(end,:);
            next_idx = i + 1;
            keep_candidate = false;
    
            while next_idx <= size(turning_pts, 1)
                next_pt = turning_pts(next_idx,:);
                v_in = candidate - prev_pt;
                v_out = next_pt - candidate;
    
                if norm(v_in) < 1e-6 || norm(v_out) < 1e-6
                    next_idx = next_idx + 1;
                    continue;
                end
    
                phi = acos(max(-1, min(1, dot(v_in, v_out) / (norm(v_in) * norm(v_out)))));
                if phi < 17 * pi / 180
                    keep_candidate = false;
                    break;
                end
    
                d_tan = r_max * tan(phi / 2);
                if min(norm(v_in), norm(v_out)) >= d_tan + margin
                    keep_candidate = true;
                    break;
                end
    
                next_idx = next_idx + 1;
            end
    
            if keep_candidate
                feasible_pts = [feasible_pts; candidate];
            end
    
            i = i + 1;
        end
    
        if norm(feasible_pts(end,:) - turning_pts(end,:)) > 1e-6
            feasible_pts = [feasible_pts; turning_pts(end,:)];
        end
    
        % 4. 去除冗余的中间点
        reduced_pts = feasible_pts(1,:);
        for i = 2:size(feasible_pts, 1)-1
            if ~line_is_free(reduced_pts(end,:), feasible_pts(i+1,:), map, res)
                reduced_pts = [reduced_pts; feasible_pts(i,:)];
            end
        end
        reduced_pts = [reduced_pts; feasible_pts(end,:)];

        px = reduced_pts(:,1);
        py = reduced_pts(:,2);

        plot_astar_phases(raw_obs, map, mapWidth, mapHeight, ...
                          path_w, turning_pts, feasible_pts, reduced_pts);

        % 绘制最终结果
        plot(path_w(:,2), path_w(:,1), 'b-', 'LineWidth', 1); % 原始蓝线
        plot(py, px, 'yo', 'MarkerSize', 10, 'MarkerFaceColor', 'r'); % 稀疏化后的红点
        title(['A*规划轨迹: ']);
        fprintf('稀疏化后关键点数量: %d\n', length(px));
        save('feasible_pts.mat', 'feasible_pts');
    else
        title('路径未找到！');
    end
    
    function is_free = line_is_free(p0, p1, map, res)
        segment_len = norm(p1 - p0);
        sample_count = max(2, ceil(segment_len / res));
        samples = linspace(0, 1, sample_count);
        is_free = true;
    
        for idx = 1:length(samples)
            pt = p0 + samples(idx) * (p1 - p0);
            row = round(pt(1) / res) + 1;
            col = round(pt(2) / res) + 1;
            row = min(max(row, 1), size(map, 1));
            col = min(max(col, 1), size(map, 2));
            if map(row, col) ~= 0
                is_free = false;
                return;
            end
        end
    end