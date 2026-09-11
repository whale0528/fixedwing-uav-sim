%% alpha
alpha_matrix = readmatrix("AERODATA_ALPHA_0225.xlsx");
alpha_vector = [-8 -4 -2 0 2 3 4 5 6 8 10 12]';
CD_alpha = alpha_matrix(1:length(alpha_vector), 3);
CY_alpha = alpha_matrix(1:length(alpha_vector), 4);
CL_alpha = alpha_matrix(1:length(alpha_vector), 5);
Cl_alpha = alpha_matrix(1:length(alpha_vector), 6);
Cm_alpha = alpha_matrix(1:length(alpha_vector), 7);
Cn_alpha = alpha_matrix(1:length(alpha_vector), 8);

%% beta 
beta_matrix = readmatrix("AERODATA_BETA_0225.xlsx");
alpha_vector1 = [-4, 0, 4, 8];
beta_vector1 = [-8, -4, 0, 4, 8];
n_beta = length(beta_vector1);
n_alpha1 = length(alpha_vector1);
% 使用reshape是列优先，先填满一列再填下一列
CD_beta = reshape(beta_matrix(:, 3), [n_beta, n_alpha1]);
CY_beta = reshape(beta_matrix(:, 4), [n_beta, n_alpha1]);
CL_beta = reshape(beta_matrix(:, 5), [n_beta, n_alpha1]);
Cl_beta = reshape(beta_matrix(:, 6), [n_beta, n_alpha1]);
Cm_beta = reshape(beta_matrix(:, 7), [n_beta, n_alpha1]);
Cn_beta = reshape(beta_matrix(:, 8), [n_beta, n_alpha1]);
%% 左舵 
def_ELE_L_matrix = readmatrix("DEF_ELE.xlsx");
alpha_vector2 = [-4, 0, 4, 8];
def_ELE_L_vector = [-15, -5, 0, 5, 15];
n_ele = length(def_ELE_L_vector);
n_alpha2 = length(alpha_vector2);
CD_ELE = reshape(def_ELE_L_matrix(:, 4), [n_ele, n_alpha2]);
CY_ELE = reshape(def_ELE_L_matrix(:, 5), [n_ele, n_alpha2]);
CL_ELE = reshape(def_ELE_L_matrix(:, 6), [n_ele, n_alpha2]);
Cl_ELE = reshape(def_ELE_L_matrix(:, 7), [n_ele, n_alpha2]);
Cm_ELE = reshape(def_ELE_L_matrix(:, 8), [n_ele, n_alpha2]);
Cn_ELE = reshape(def_ELE_L_matrix(:, 9), [n_ele, n_alpha2]);
%% 右舵
def_ELE_R_vector = [-15, -5, 0, 5, 15];
CY_ELER = -CY_ELE;
Cl_ELER = -Cl_ELE;
Cn_ELER = -Cn_ELE;
matrix_orig = readmatrix("DEF_ELE.xlsx");
alpha_vec = [-4, 0, 4, 8]; 
def_ELE_L_vct = [-15, -5, 0, 5, 15];
%基准值
base_idx = 3:5:20;
Cm_base_v = matrix_orig(base_idx, 8); % 长度为 4 的列向量
CL_base_v = matrix_orig(base_idx, 6);

%扩展基准值
Cm_0 = repelem(Cm_base_v, 5, 1);
CL_0 = repelem(CL_base_v, 5, 1);
%计算增量
delta_Cm = matrix_orig(:, 8) - Cm_0;
delta_CL = matrix_orig(:, 6) - CL_0;

Cm_ELE_All = Cm_0 + 2 * delta_Cm;
CL_ELE_ALL = CL_0 + 2 * delta_CL;

%构造alpha 和 def_ELE 列
alpha = repelem(alpha_vec', 5, 1);
def_ELE = repmat(def_ELE_L_vct', 4, 1);

Cm_ELE_all = [alpha, def_ELE, Cm_ELE_All];
CL_ELE_all = [alpha, def_ELE, CL_ELE_ALL];

Cm_AL_ELE = reshape(Cm_ELE_All, [5, 4])';
CL_AL_ELE = reshape(CL_ELE_ALL, [5, 4])';

save aerodata.mat alpha_vector alpha_vector1 alpha_vector2 beta_vector1 def_ELE_L_vector...
                  CD_alpha CD_beta CD_ELE CY_alpha CY_beta CY_ELE CL_alpha CL_beta CL_ELE...
                  Cl_alpha Cl_beta Cl_ELE Cm_alpha Cm_beta Cm_ELE Cn_alpha Cn_beta Cn_ELE ...
                  def_ELE_R_vector CY_ELER Cl_ELER Cn_ELER