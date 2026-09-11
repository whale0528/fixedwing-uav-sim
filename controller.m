zeta = 0.8;
wn = 8;
Tr = 1;
%% Z_al
CL_al = (CL_alpha(10)-CL_alpha(9))*57.3/(alpha_vector(10)-alpha_vector(9));
Z_al = (CD_alpha(10)+CL_al)*(q_0*S_ref/(mass*Vc));

%% kq
Cm_delata_e = (Cm_AL_ELE(4,3)-Cm_AL_ELE(4,2))*57.3/(def_ELE_L_vct(3)-def_ELE_L_vct(2));
a_25 = - Cm_delata_e*(q_0*S_ref*c_ref/I_y);
kq = -(2*zeta*wn) / a_25;

%% kal
for i = 2:10
    Cm_al = (Cm_alpha(i)-Cm_alpha(i-1))*57.3 / (alpha_vector(i)-alpha_vector(i-1));
    a_24(i-1) = Cm_al*(q_0*S_ref*c_ref/I_y);
end
kal= (wn^2-a_24(3))/(2*zeta*wn);
%% kn
kn = (-2.2*wn^2*g)/(Tr*(wn^2+a_24(3))*Vc*Z_al);

%% kphi
zeta2 = 0.8;
Tr2 = 0.5;
wn2 = 12;
Cl_delta_a =(matrix_orig(18,7)-matrix_orig(17,7))/(def_ELE_L_vct(3)-def_ELE_L_vct(2));%da
N_delatr_bar = Cl_delta_a*(q_0*S_ref*b_ref/I_x);
kp = 2*zeta2*wn2/N_delatr_bar;
kphi = wn2/2/zeta2;
ki = 0.1*kphi;

CL_delta_e = 2*(matrix_orig(18,6)-matrix_orig(17,6)) / (def_ELE_L_vct(3)-def_ELE_L_vct(2));
Mbar_delta_e = Cm_delata_e*(q_0*S_ref*c_ref/I_y);
Z_delta_e = CL_delta_e*(q_0*S_ref/(mass*Vc_0));
for i = 2:10
    Cm_al = (Cm_alpha(i)-Cm_alpha(i-1))*57.3 / (alpha_vector(i)-alpha_vector(i-1));
    Mbar_al(i-1) = Cm_al*(q_0*S_ref*c_ref/I_y);
end
Cm_q_bar = -122.945258;
Cm_q = Cm_q_bar*c_ref/(2*Vc_0);
Mbar_q = Cm_q*c_ref/(2*Vc_0)*(q_0*S_ref*c_ref/I_y);
% %% --- 校核    ---
% %  舵机
% f=13;
% T_dj = 1 / (2*pi * f);
% G_dj = tf(1, [T_dj^2, 2*0.7*T_dj, 1]); % 舵机传递函数
% % 纵向传递函数
% 
% G_de_q = tf([Mbar_delta_e, (Z_al*Mbar_delta_e-Z_delta_e*Mbar_al(3))], [1, (Z_al-Mbar_q), -(Mbar_q*Z_al+Mbar_al(3))]);
% 
% G1 = kq * G_dj * G_de_q;
% T1 = feedback(G1, 1); 
% G2 = kal * T1 * tf(1, [1, Z_al]);
% T2 = feedback(G2, 1);
% 
% G3 = tf(kn, [1, 0]) * T2 * (-Vc * Z_al / g);
% T3 = feedback(G3, 1); 
% % 开环传递函数
% G_open_pitch = -kq*(1+kal*tf(1, [1, Z_al]))*G_dj*tf([-Mbar_delta_e, -Z_al*Mbar_delta_e], [1, (Z_al-Mbar_q), -(Mbar_q*Z_al+Mbar_al(3))]);
% [GM1, PM1] = margin(G_open_pitch);
% %  滚转通道传递函数构建
% Cl_p_bar = -0.499051;
% Cl_p = Cl_p_bar*b_ref/(2*Vc_0);
% Lbar_p = -Cl_p*(q_0*S_ref*b_ref^2) / (2*Vc_0*I_x);
% c1 = Lbar_p;
% G_Dr_p = tf(N_delatr_bar,[1,c1]);
% G4 = kp * G_dj * G_Dr_p;
% T4 = feedback(G4, 1);
% G5 = tf([kphi, ki], [1,0])*T4*tf(1,[1,0]);
% T5 = feedback(G5, 1);
% % 从舵机处断开
% G_open2 = G4*(1+tf(1,[1,0]*tf([kphi, ki], [1,0])));
% [GM2, PM2] = margin(G_open2);
% % 纵向过载指令响应
% figure('Name', '阶跃响应(n_z)');
% step(T3); 
% grid on; 
% title('纵向过载阶跃响应');
% ylabel('过载 (g)'); % 修改纵轴标题和单位
% % 纵向稳定性裕度
% figure('Name', '纵向稳定性裕度');
% margin(G_open_pitch); grid on;
% % 滚转角指令响应
% figure('Name', '阶跃响应(phi)');
% step(T5); 
% grid on; 
% title('滚转角阶跃响应');
% ylabel('滚转角 (rad)'); % 修改纵轴标题和单位
% % 滚转稳定性裕度
% figure('Name', '滚转稳定性裕度');
% margin(G_open2); grid on;
% fprintf('纵向相角裕度 PM: %.2f deg, 滚转相角裕度 PM: %.2f deg\n', PM1, PM2);
% fprintf('纵向幅值裕度 GM: %.2f db, 滚转幅值裕度 GM: %.2f db', GM1, GM2);