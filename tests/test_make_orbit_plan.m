function tests = test_make_orbit_plan
    tests = functiontests(localfunctions);
end

function params = make_p
    params = struct('center', [8000 2000], 'radius_m', 300, ...
                    'direction', 'CW', 'turns', 3);
end

function testRowStructure(testCase)
    [fly_pt, num_fly_pt] = make_orbit_plan(make_p(), [0 0], deg2rad(77.8));
    testCase.verifyEqual(size(fly_pt, 2), 5);
    testCase.verifyEqual(num_fly_pt, size(fly_pt, 1));
    testCase.verifyEqual(fly_pt(end, 4:5), [-10000 -10000]);   % 终止行
    testCase.verifyEqual(fly_pt(1, 1:2), [0 0]);                % 首行=起点位置（类型取决于切入首段是直线还是圆弧）
end

function testCircleCentersAndRadius(testCase)
    [fly_pt, ~] = make_orbit_plan(make_p(), [0 0], deg2rad(77.8));
    cen = fly_pt(fly_pt(:,4)==2 & fly_pt(:,5)>2, :);            % 所有圆心行
    testCase.verifyTrue(all(cen(:,5)==300));                    % info=半径
    on_target = all(cen(:,1:2) == [8000 2000], 2);              % 圆心在目标中心的圆心行数 = 圈数
    testCase.verifyEqual(sum(on_target), 3);
end

function testCircleBearingProgression(testCase)
    p = make_p();
    [fly_pt, ~] = make_orbit_plan(p, [0 0], deg2rad(77.8));
    cen_idx = find(all(fly_pt(:,1:2) == p.center, 2));
    st_idx = cen_idx - 1;                                       % 圆弧起点行 = 圆心行的前一行
    th = atan2(fly_pt(st_idx,2)-p.center(2), fly_pt(st_idx,1)-p.center(1));
    dth = mod(diff(th), 2*pi);                                  % CW：每圈起点方位递增 ε=0.05
    testCase.verifyLessThan(max(abs(dth - 0.05)), 1e-6);
end

function testDirectionInfoCorrect(testCase)
    [fly_pt, ~] = make_orbit_plan(make_p(), [0 0], deg2rad(77.8));
    cen_idx = find(all(fly_pt(:,1:2) == [8000 2000], 2));
    testCase.verifyTrue(all(fly_pt(cen_idx-1, 5) == 1));        % CW → dir_type=1
    p2 = make_p(); p2.direction = 'CCW';
    [fly_pt2, ~] = make_orbit_plan(p2, [0 0], deg2rad(77.8));
    cen_idx2 = find(all(fly_pt2(:,1:2) == [8000 2000], 2));
    testCase.verifyTrue(all(fly_pt2(cen_idx2-1, 5) == 2));      % CCW → dir_type=2
end

function testRadiusTooSmallErrors(testCase)
    p = make_p(); p.radius_m = 200;
    testCase.verifyError(@() make_orbit_plan(p, [0 0], 0), 'make_orbit_plan:radius');
end
