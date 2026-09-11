function tests = test_make_orbit_plan
    tests = functiontests(localfunctions);
end

function params = make_p
    params = struct('center', [8000 2000], 'radius_m', 2000, ...
                    'direction', 'CW', 'turns', 3);
end

function testRowStructure(testCase)
    [fly_pt, num_fly_pt] = make_orbit_plan(make_p(), [0 0], deg2rad(77.8));
    testCase.verifyEqual(size(fly_pt, 2), 5);
    testCase.verifyEqual(num_fly_pt, size(fly_pt, 1));
    testCase.verifyEqual(fly_pt(end, 4:5), [-10000 -10000]);   % 终止行
    testCase.verifyEqual(fly_pt(1, 1:2), [0 0]);                % 首行=起点位置
end

function testPolygonVertexCountAndRadius(testCase)
    % 绕圈用正多边形逼近：圆上 type=1 顶点数 = 切入切点 + (N*48 - 1) = N*48
    [fly_pt, ~] = make_orbit_plan(make_p(), [0 0], deg2rad(77.8));
    c = [8000 2000]; r = 2000; n_seg = 48;
    on_circle = fly_pt(:,4) == 1 & abs(hypot(fly_pt(:,1)-c(1), fly_pt(:,2)-c(2)) - r) < 0.5;
    testCase.verifyEqual(sum(on_circle), 3*n_seg);
    % 其余行不得落在圆上（切入段在圆外）
    others = find(~on_circle & fly_pt(:,4) ~= -10000);
    for k = 1:numel(others)
        d = hypot(fly_pt(others(k),1)-c(1), fly_pt(others(k),2)-c(2));
        testCase.verifyGreaterThan(abs(d - r), 0.5);
    end
end

function testPolygonBearingSteps(testCase)
    % 顶点方位角步进 = ±7.5°/边，方向与 CW/CCW 一致
    n_seg = 48; dth_seg = 2*pi/n_seg;
    for dir = ["CW", "CCW"]
        p = make_p(); p.direction = dir;
        [fly_pt, ~] = make_orbit_plan(p, [0 0], deg2rad(77.8));
        c = p.center;
        rows = fly_pt(fly_pt(:,4)==1 & abs(hypot(fly_pt(:,1)-c(1), fly_pt(:,2)-c(2)) - 2000) < 0.5, :);
        th = atan2(rows(:,2)-c(2), rows(:,1)-c(1));
        d = mod(diff(th) + pi, 2*pi) - pi;    % 卷绕安全的相邻差
        expected = strcmp(dir, "CW") * (-dth_seg) + strcmp(dir, "CCW") * dth_seg;
        testCase.verifyLessThan(max(abs(d - expected)), 1e-9);
    end
end

function testRadiusTooSmallErrors(testCase)
    p = make_p(); p.radius_m = 1500;   % 低于制导可跟踪下限 1600 m
    testCase.verifyError(@() make_orbit_plan(p, [0 0], 0), 'make_orbit_plan:radius');
end

function testEntryPathClearsOrbitCircle(testCase)
    % 防回归：切入段不得进入绕圈圆内部。
    % 若切入 Dubins 末段弧与绕圈圆共圆心（"骑圆"），飞机到达绕圈起点时
    % 方位角在 mod 卷绕意义上已越过终点，圆弧会被瞬间跳过（实测教训）。
    p = make_p();
    start = [0 0 deg2rad(77.8)];
    c = p.center; r = p.radius_m;
    th_near = atan2(start(2)-c(2), start(1)-c(1));
    psi_entry = th_near - pi/2;    % CW 切向（make_p 为 CW）
    p_pre = c + r*[cos(th_near), sin(th_near)] - 2.5*r*[cos(psi_entry), sin(psi_entry)];
    dp = dubins.core(start, [p_pre, psi_entry], r);
    plens = [dp.param.t, dp.param.p, dp.param.q];
    curr = start; dmin = inf;
    for j = 1:3
        for s = linspace(0, plens(j), 300)
            q = dubins.interp_seg(curr, s, dp.param.type(j), r);
            dmin = min(dmin, hypot(q(1)-c(1), q(2)-c(2)));
        end
        curr = dubins.interp_seg(curr, plens(j), dp.param.type(j), r);
    end
    testCase.verifyGreaterThan(dmin, r);
end
