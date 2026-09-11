function fly_pt = append_segments(fly_pt, q1, path, pz_val, rho)
% DUBINS.APPEND_SEGMENTS 把一条 Dubins 路径转成航点行
% 照搬 dubins_path_planning.m 的局部函数 append_dubins_path（含圆弧终点行），行为不变。
% 行格式：[x_north, y_east, z, type, info]；type=1 直线终点；type=2+info∈{1,2} 圆弧起点(1=CW,2=CCW)；
%         type=2+info>2 圆心行(info=半径)。终点行的合并交给 dubins.filter_waypoints。
    params = [path.param.t, path.param.p, path.param.q];
    types = path.param.type;
    curr_q = path.q0;

    for j = 1:3
        seg_len = params(j) * rho;

        if seg_len < 34 && types(j) ~= 'S'
            curr_q = dubins.interp_seg(curr_q, params(j), types(j), rho);
            continue;
        end

        if types(j) == 'S'
            curr_q = dubins.interp_seg(curr_q, params(j), 'S', rho);
            if norm(fly_pt(end,1:2) - curr_q(1:2)) > 10
                fly_pt = [fly_pt; curr_q(1), curr_q(2), pz_val, 1, 0];
            end
        else
            dir_type = (types(j) == 'L')*2 + (types(j) == 'R')*1;
            if types(j) == 'L'
                xc = curr_q(1) + rho * cos(curr_q(3) + pi/2);
                yc = curr_q(2) + rho * sin(curr_q(3) + pi/2);
            else
                xc = curr_q(1) + rho * cos(curr_q(3) - pi/2);
                yc = curr_q(2) + rho * sin(curr_q(3) - pi/2);
            end
            fly_pt = [fly_pt; curr_q(1), curr_q(2), pz_val, 2, dir_type];
            fly_pt = [fly_pt; xc, yc, pz_val, 2, rho];
            curr_q = dubins.interp_seg(curr_q, params(j), types(j), rho);
            fly_pt = [fly_pt; curr_q(1), curr_q(2), pz_val, 1, 0];
        end
    end

    if norm(fly_pt(end,1:2) - q1(1:2)) > 1
        fly_pt = [fly_pt; q1(1), q1(2), pz_val, 1, 0];
    end
end
