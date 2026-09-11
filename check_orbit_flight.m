function report = check_orbit_flight(out, params)
% CHECK_ORBIT_FLIGHT 从仿真输出判定 orbit 执行结果
% out.simout 约定（同 plotmake.m）：Data(:,1)=x_north, Data(:,2)=x_east, Data(:,3)=x_down
    report = struct('turns', 0, 'radius_rmse', NaN, 'direction', '', ...
                    'bank_max_deg', NaN, 'complete', false);
    xn = out.simout.Data(:,1); xe = out.simout.Data(:,2);
    c = params.center; r = params.radius_m;
    d = hypot(xn - c(1), xe - c(2));
    in_band = abs(d - r) <= 0.3*r;
    if ~any(in_band), return; end
    th = unwrap(atan2(xe(in_band) - c(2), xn(in_band) - c(1)));
    report.turns = (max(th) - min(th)) / (2*pi);
    report.radius_rmse = sqrt(mean((d(in_band) - r).^2));
    report.direction = ternary(mean(diff(th)) > 0, 'CCW', 'CW');
    if isfield(out, 'phi')
        report.bank_max_deg = max(abs(out.phi.Data)) * 180/pi;
    end
    report.complete = report.turns >= params.turns - 0.1 && report.radius_rmse <= 0.1*r;
end

function r = ternary(cond, a, b)
    if cond, r = a; else, r = b; end
end
