% RUN_TESTS 一键运行全部检查（路线二项目）
% 用法：命令窗口输入 run_tests 回车；或在编辑器里直接按 F5。
% 三行防坑说明（都是本项目实测踩过的）：
%   1) cd 到本脚本所在目录（F:\练习），保证 +dubins 包与被测函数可见；
%   2) addpath 项目根目录——runtests 会把工作目录切到 tests\ 子文件夹，
%      不加这行会报"未定义函数"；
%   3) clear functions + rehash：强制 MATLAB 重新加载被外部修改过的 .m 文件，
%      否则会跑到缓存的旧代码（测试"假通过"的坑）。

cd(fileparts(mfilename('fullpath')));
addpath(pwd);
clear functions;
rehash path;

fprintf('===== 1/2：绕圈航点生成检查（脚本版） =====\n');
run('tests/test_make_orbit_plan.m');

fprintf('\n===== 2/2：仿真判定检查（框架版） =====\n');
res = runtests('tests/test_check_orbit_flight.m');
disp(res);
