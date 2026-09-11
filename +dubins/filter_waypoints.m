function fly_pt = filter_waypoints(fly_pt)
% DUBINS.FILTER_WAYPOINTS 航点过滤：合并坐标重合的圆弧起点行、清除 <40m 杂点（保留圆心行）
% 照搬 dubins_path_planning.m 36-63 行，行为不变：fly_pt 末行须为终止行 [-10000,-10000]。
    temp_pt = fly_pt(1,:);
    for k = 2:size(fly_pt,1)-1
        dist = norm(fly_pt(k,1:2) - temp_pt(end,1:2));

        % 坐标完全重合（或极近）的点
        if dist < 1e-3
            % 新点是圆弧起点(类型2，标志位1或2)，携带转向方向信息，覆盖前一个坐标相同的直线终点
            if fly_pt(k,4) == 2 && (fly_pt(k,5) == 1 || fly_pt(k,5) == 2)
                temp_pt(end,:) = fly_pt(k,:);
            end
            continue;
        end

        % 圆心点（类型2 且参数大于2(即半径)）永远保留
        is_coc = (fly_pt(k,4) == 2 && fly_pt(k,5) > 2);

        % 清除距离过近的杂点，但保留圆心
        if dist < 40 && ~is_coc
            continue;
        else
            temp_pt = [temp_pt; fly_pt(k,:)];
        end
    end

    % 加上终点
    fly_pt = [temp_pt; fly_pt(end,:)];
end
