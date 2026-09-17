function lim = vehicle_limits(opt)
% VEHICLE_LIMITS 飞行器解析能力边界（供机动可行性判定使用）
% 数据来源：aerodata.mat（气动表）+ init.m 的几何/质量参数 + 实测制导边界
%
% 返回 struct lim，字段：
%   m, S, W_over_S      质量、参考面积、翼载
%   CL_max, alpha_CLmax 气动表给出的最大升力系数及其迎角（注意：表内未含失速段）
%   V_stall             失速速度（升力约束下界）
%   phi_max             滚转限制（rad）
%   n_max               过载限制（结构假设值，需按实际结构核算）
%   V_max               速度上界（推力假设值，需按动力核算）
%   r_min_aero(v)       气动/配平约束下的最小盘旋半径（函数句柄）
%   r_min_guide         制导层实测最小可跟踪半径（经验值，来自 b0307 调参后实测）
%
% 可选参数 opt：phi_max_deg(30), n_max(3.0), V_max(55), rho(1.225)
    arguments
        opt.phi_max_deg (1,1) double = 30
        opt.n_max (1,1) double = 3.0
        opt.V_max (1,1) double = 55
        opt.rho (1,1) double = 1.225
    end

    % ---- 气动表 ----
    if ~isfile('aerodata.mat'), airdate; end
    S = load('aerodata.mat');
    CL_tab = S.CL_alpha(:);
    alpha_tab = S.alpha_vector(:);
    [lim.CL_max, i_max] = max(CL_tab);
    lim.alpha_CLmax = alpha_tab(i_max);

    % ---- 几何/质量（init.m）----
    lim.m = 27.1;
    lim.S = 0.7;
    lim.g = 9.8;
    lim.W_over_S = lim.m * lim.g / lim.S;          % ≈ 379.4 N/m^2

    % ---- 失速速度：V_stall = sqrt(2*W/S / (rho*CL_max)) ----
    lim.V_stall = sqrt(2 * lim.W_over_S / (opt.rho * lim.CL_max));

    % ---- 其它限制 ----
    lim.phi_max = deg2rad(opt.phi_max_deg);
    lim.n_max = opt.n_max;
    lim.V_max = opt.V_max;
    lim.rho = opt.rho;

    % ---- 解析最小盘旋半径：r = v^2 / (g*tan(phi_max)) ----
    lim.r_min_aero = @(v) v.^2 / (lim.g * tan(lim.phi_max));

    % ---- 制导层实测边界（经验值）----
    % kdy=0.02、侧偏饱和 ±15 m → 稳态过载上限 0.3 g → r_min = v^2/(0.3g) ≈ 393 m @34 m/s
    lim.r_min_guide = @(v) v.^2 / (0.3 * lim.g);
    lim.r_min_guide_34 = lim.r_min_guide(34);      % ≈ 393 m

    % ---- 完成判定的经验保证（来自实测：500 m 圆稳态偏差 12 m、RMSE 22 m）----
    lim.radius_err_frac = 0.05;                    % 半径误差经验分位（500 m 圆实测 12 m ≈ 2.4%）
    lim.notes = ["V_stall 用表内 CL_max 计算；表未含失速段，真实 CL_max 可能更大（V_stall 更小）", ...
                 "n_max / V_max 为假设值，需按结构与动力核算", ...
                 "r_min_guide 为 b0307 调参后实测边界（300 m 失败 / 500 m 成功）"];
end
