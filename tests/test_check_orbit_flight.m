function tests = test_check_orbit_flight
    tests = functiontests(localfunctions);
end

function out = synth_out(c, r, turns)
% 合成一个绕点 c、半径 r 的理想圆轨迹输出（turns 圈，方位角从 0 递增）
    th = linspace(0, 2*pi*turns, 4000)';
    xn = c(1) + r*cos(th); xe = c(2) + r*sin(th);
    out = struct('simout', struct('Data', [xn, xe, zeros(size(xn))]));
end

function testCountsThreeLoops(testCase)
    p = struct('center', [8000 2000], 'radius_m', 300, 'turns', 3);
    out = synth_out(p.center, p.radius_m, 3);
    rep = check_orbit_flight(out, p);
    testCase.verifyEqual(round(rep.turns, 2), 3);
    testCase.verifyLessThan(rep.radius_rmse, 1e-6);
    testCase.verifyTrue(rep.complete);
    testCase.verifyEqual(rep.direction, 'CCW');
end

function testDirectionCW(testCase)
    p = struct('center', [8000 2000], 'radius_m', 300, 'turns', 1);
    th = linspace(0, -2*pi, 4000)';    % 方位角递减 = CW
    xn = p.center(1) + 300*cos(th); xe = p.center(2) + 300*sin(th);
    out = struct('simout', struct('Data', [xn, xe, zeros(size(xn))]));
    rep = check_orbit_flight(out, p);
    testCase.verifyEqual(rep.direction, 'CW');
end
