close all;
clc;
clear all;
load("aerodata.mat");
load('fly_planfjy.mat');
%几何参数
b_ref = 2.24;  % 参考展长
S_ref = 0.7;   % 参考面积
c_ref = 0.165; % 平均气动弦长
x_cg=.907;
y_cg=.0;
z_cg=-.0046;%重心
%物理参数
g=9.8;
mass=27.1;
I_x = 0.595; I_y = 6.282; I_z = 6.779;
I_xy = 0.00000915; I_xz = 0.07; I_yz = 0.006;
%I_xy = 0; I_xz = 0; I_yz = 0;
I = [I_x -I_xy -I_xz;
    -I_xy I_y -I_yz;
    -I_xz -I_yz I_z];
I_inv = inv(I);
%测试条件
t=0;
x_0=0;y_0=0;z_0=0;
rho = 1.225;
theta_0 = 30 * (pi/180);  % 初始俯仰角
psi_0 =0 * (pi/180);    % 初始偏航角
phi_0=0;
deltal=0*3.14/180;deltar=0*3.14/180;
Vc_0 = 37.4;     % 初速
Vc = 34;
q_0 = 0.5*Vc_0^2*1.225;
alpha_0 = 0 * (pi/180);  % 初始迎角
beta_0 =  0 * (pi/180);   % 初始侧滑
v_0 = Vc_0*sin(beta_0);
u_0 = Vc_0*cos(beta_0)*cos(alpha_0);
w_0 = Vc_0*cos(beta_0)*sin(alpha_0);
%控制器初始参数
delta_max = 15;
pitch_max=30;
roll_max=30;
% 风场参数（NED 分量，m/s, 默认无风）
W_north = 0;
W_east = 0;
W_down = 0;

airdate;
controller;
target;
theta_t = 0;
psi_t = 0;
V_t = 0;
xt0 = 6500;
yt0 = 9000;
zt0 = 0;
r_max = Vc^2 / (g * tan(roll_max*pi/180)) ;% 最小转弯半径