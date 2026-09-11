# fixedwing-uav-sim

固定翼无人机 6DOF 飞行仿真与自主任务实验项目（MATLAB/Simulink R2025b）。

## 项目内容

- **6DOF 仿真模型** `b0307.mdl`：动力学/运动学（含风场、ISA 大气）、BTT 控制、巡航/末制导、俯仰过载与滚转姿态控制器、带 Dubins 圆弧的航路跟踪（`fly_pt` 圆心机制）、Stateflow 模式切换
- **航路规划链**：`Astar.m`（栅格 A* + 障碍膨胀 + 转弯半径可行化稀疏）→ `dubins_path_planning.m`（Dubins 航点，`+dubins` 工具包）→ `fly_planfjy.mat` → Simulink 航路跟踪
- **气动数据**：`AERODATA_ALPHA_0225.xlsx`、`AERODATA_BETA_0225.xlsx`、`DEF_ELE.xlsx`（`airdate.m` 生成 `aerodata.mat`）
- **LLM 路线**：`UAV与LLM两条技术路线总结.md`（文献调研与两条技术路线）、`docs/superpowers/plans/`（路线二"自然语言 → orbit 机动"实现计划）

## 快速开始

```matlab
cd <本仓库目录>
run Astar.m                 % A* 航路规划，生成 feasible_pts.mat
run dubins_path_planning.m  % Dubins 航点，生成 fly_planfjy.mat
run init.m                  % 初始化气动/控制器/目标/航点
out = sim('b0307');         % 6DOF 仿真（accelerator 模式）
run plotmake.m              % 3D 截击轨迹图
```

## 环境

- MATLAB R2025b + Simulink / Stateflow / Aerospace Blockset
- 仿真模式：accelerator
- LLM 功能（`llm2orbit.m` 等）需在仓库根目录放置 DeepSeek API key 于 `llm_key.txt`（已加入 .gitignore）
