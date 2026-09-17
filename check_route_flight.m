function report = check_route_flight(out, plan)
% CHECK_ROUTE_FLIGHT 按动作单判定执行结果（通用判定器）
% out  : run_route_sim 的仿真输出
% plan : check_route_spec 的输出（plan.segments 中坐标已解析为数值）
% report.items   : struct 数组，每项含 type/name/ok/detail
% report.overall : 所有关注项是否达标
% 判定口径：
%   goto / line_to ：轨迹到目标点的最近距离 < 50 m
%   orbit          ：判定带（半径 ±30%）内扫角 ≥ 要求圈数−0.1，且半径 RMSE ≤ 10% 半径
    xn = out.simout.Data(:,1);
    xe = out.simout.Data(:,2);
    items = struct('type', {}, 'name', {}, 'ok', {}, 'detail', {});

    for k = 1:numel(plan.segments)
        s = plan.segments{k};
        t = s{1};
        switch t
            case {'goto', 'line_to'}
                xy = s{2}(1:2);
                d = hypot(xn - xy(1), xe - xy(2));
                dmin = min(d);
                items(end+1) = struct('type', t, ...
                    'name',   sprintf('飞往 (%.0f, %.0f)', xy(1), xy(2)), ...
                    'ok',     dmin < 50, ...
                    'detail', sprintf('最近距离 %.0f m', dmin));            %#ok<AGROW>

            case 'orbit'
                c = s{2}; r = s{3}; turns = s{5};
                d = hypot(xn - c(1), xe - c(2));
                band = abs(d - r) <= 0.3*r;
                name = sprintf('绕 (%.0f, %.0f) r=%.0f m ×%d 圈', c(1), c(2), r, turns);
                if ~any(band)
                    items(end+1) = struct('type', 'orbit', 'name', name, ...
                        'ok', false, 'detail', '未进入判定带');                %#ok<AGROW>
                else
                    th = unwrap(atan2(xe(band) - c(2), xn(band) - c(1)));
                    n_turn = (max(th) - min(th)) / (2*pi);
                    rmse = sqrt(mean((d(band) - r).^2));
                    items(end+1) = struct('type', 'orbit', 'name', name, ...
                        'ok', n_turn >= turns - 0.1 && rmse <= 0.1*r, ...
                        'detail', sprintf('实际 %.2f 圈，半径 RMSE %.0f m', n_turn, rmse)); %#ok<AGROW>
                end
        end
    end

    if isempty(items)
        overall = true;                     % 只有直线/转向，无位置判定项
    else
        overall = all([items.ok]);
    end
    report = struct('items', items, 'overall', overall);
end
