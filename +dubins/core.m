function path = core(q0, q1, rho)
% DUBINS.CORE 两姿态间最短 Dubins 路径（LSL/RSR/LSR/RSL 取最短）
% 提取自 dubins_path_planning.m 的局部函数 dubins_core，逻辑未改动
    dx = q1(1) - q0(1); dy = q1(2) - q0(2); d = sqrt(dx^2 + dy^2)/rho;
    phi = atan2(dy, dx); alpha = mod(q0(3)-phi, 2*pi); beta = mod(q1(3)-phi, 2*pi);
    best_c = inf; best_p = []; types = {'LSL','RSR','LSR','RSL'};
    for i = 1:4
        [ok,t,p,q] = dubins.words(alpha,beta,d,types{i});
        if ok && (t+p+q) < best_c, best_c = t+p+q; best_p = struct('type',types{i},'t',t,'p',p,'q',q); end
    end
    path.valid = ~isempty(best_p);
    if path.valid, path.q0 = q0; path.param = best_p; end
end
