function q_next = interp_seg(q_start, s_norm, type, rho)
% DUBINS.INTERP_SEG 单段（S/L/R）几何插值
% 提取自 dubins_path_planning.m 的局部函数 interpolate_seg_global，逻辑未改动
    x = q_start(1); y = q_start(2); th = q_start(3);
    s = s_norm * rho;
    if type == 'L', qn = [sin(s/rho), 1-cos(s/rho), s/rho];
    elseif type == 'R', qn = [sin(s/rho), -(1-cos(s/rho)), -s/rho];
    else, qn = [s/rho, 0, 0]; end
    q_next = [x + rho*(qn(1)*cos(th) - qn(2)*sin(th)), y + rho*(qn(1)*sin(th) + qn(2)*cos(th)), th + qn(3)];
end
