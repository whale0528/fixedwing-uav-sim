# fixedwing-uav-sim

固定翼无人机 6DOF 飞行仿真与自主任务实验项目（MATLAB/Simulink R2025b）。

## 项目内容

- **6DOF 仿真模型** `b0307.mdl`：动力学/运动学（含风场、ISA 大气）、BTT 控制、巡航/末制导、俯仰过载与滚转姿态控制器、带 Dubins 圆弧的航路跟踪（`fly_pt` 圆心机制）、Stateflow 模式切换
- **航路规划链**：`Astar.m`（栅格 A* + 障碍膨胀 + 转弯半径可行化稀疏）→ `dubins_path_planning.m`（Dubins 航点，`+dubins` 工具包）→ `fly_planfjy.mat` → Simulink 航路跟踪
- **气动数据**：`AERODATA_ALPHA_0225.xlsx`、`AERODATA_BETA_0225.xlsx`、`DEF_ELE.xlsx`（`airdate.m` 生成 `aerodata.mat`）
- **LLM 路线**：`run_llm_mission.m`（自然语言任务入口）、`docs/`（讨论与设计记录）、`资料/`（文献笔记）

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
- LLM 功能（`llm2route.m` 等）需在仓库根目录放置 DeepSeek API key 于 `llm_key.txt`（已加入 .gitignore）

## 文件管理

- `docs/paper_notes/`：组会讲解稿；`资料/`：文献解读；`experiments/`：实验脚本和复现结果。
- `资料/local/`：仅本机保留的论文 PDF，不提交 Git。
- `tmp/`、`slprj/`、`*.slxc` 和 `_view_fig.png` 是临时文件或缓存，关闭相关任务后可清理。
- `*.autosave` 是模型恢复副本，确认模型已保存后再清理。
- `aerodata.mat` 由 `init.m` 中的 `airdate` 从气动 Excel 重建；初始化前须已有 `fly_planfjy.mat`，可按快速开始步骤生成。
- `baseline_fly_plan.mat` 保留为基准航路资料；`debug_replay_flyphase.m` 保留用于航段切换调试。
