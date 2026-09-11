# 无人机 + LLM：两条技术路线总结

> **整理用途**：后续研究 / 项目立项参考
> **背景材料**：`C:\Users\fjy\Zotero\storage` 下 6 篇文献（文末附清单）
> **个人技术背景**：飞行器动力学/运动学建模、传统控制器、传统制导律、航路规划算法（Simulink 仿真）；无 PX4/ROS 经验；无经典任务规划（AI Planning）基础

---

## 0. 核心共识（6 篇文献收敛出的共同结论）

1. **LLM 当"指挥官"，不当"飞行员"**：LLM 适合放在高层语义层（理解意图、任务分解、规划、决策、解释），不碰实时、安全关键的控制执行。
2. **结构化输出 + 确定性校验是落地关键**：LLM 的自由文本不能直接执行，必须用 schema/语法约束解码 + 确定性校验层（不是让 LLM 自查）。
3. **混合架构**：语义层（LLM）+ 执行层（经典规划器 / 制导律 / 控制器），中间用结构化契约连接，保留回退机制。
4. **LLM 不做数值计算**：坐标、距离矩阵、单位换算、边界裁剪等一律交给确定性模块；LLM 只输出符号/语义（如点名称、动作类型、参数意图）。
5. **按任务特性决定用不用 LLM**：任务结构固定（如固定点巡检）→ TSP + Stateflow 就够，别上 LLM；任务多变 / 有依赖约束 / 自然语言临时下达 → 才用 LLM。
6. **"学术—工业鸿沟"真实存在**（Chen 2026 实证）：学术侧重理论/多机复杂规划，工业侧重稳定/低成本/快速部署；82.7% 开发者偏好"混合（机载辅助）"模式而非直接控制。
7. **校验点有两处**：① 调用求解器**前**校验 LLM 生成的输入（格式/合法性）；② 调用求解器**后**校验输出的计划（约束满足/可执行性）。

---

## 1. 路线一：自然语言 → 任务规划（神经符号路线）

### 1.1 解决的问题

把人的高层意图翻译成「机器能理解、能验证的任务计划」，重点解决：
- **逻辑依赖**（"先充电才能去 B"）
- **资源约束**（电量、载荷、时间窗）
- **条件分支**（"若侦察到目标则检查，否则去别处"）
- **任务结构不固定**（现场临时用自然语言下达）

### 1.2 完整流程（注意顺序与两处校验）

```
自然语言指令
   │
   ▼
① LLM：意图澄清（多轮对话）+ 约束抽取（隐含约束显式化）+ 格式生成
   │
   ▼
② 任务类型路由（二选一）：
   - LLM 自己选（function calling / tool use）
   - 固定路由器（规则/分类器，更可控）
   │
   ├── 纯排序问题 ──→ TSP/VRP 求解器（输入：点集 + 距离矩阵）
   ├── 依赖/资源推理 → PDDL 规划器（输入：domain.pddl + problem.pddl）
   └── 其他 ────────→ 专用求解器 / 参数化执行（如 Stateflow 参数）
   │
   ▼
③ 【校验点 1】确定性校验「输入」：PDDL 语法/类型检查、JSON schema、距离矩阵维度
   │ 不合法 → 报错回 LLM 重写
   ▼
④ 调用规划器求解
   │
   ▼
⑤ 【校验点 2】校验「输出计划」：前置条件满足、可导入地面站、仿真可执行
   │
   ▼
⑥ LLM 回译计划成自然语言 → 人确认（HITL）
   │
   ▼
⑦ 执行（航路规划 → 制导 → 控制 → 动力学）
   │
   └── 执行反馈（失败/冲突）→ 回 LLM 修正（闭环）
```

### 1.3 关键概念速查（无 AI Planning 基础时的最小知识）

| 概念 | 与本人已有知识的对应 |
|---|---|
| 状态 | 连续状态 x=[p,v,...] → 换成**一组"真/假"事实**（at(drone,A)、charged(drone)） |
| 动作 | 连续控制量 u → 换成**离散算子**（前置条件 + 效果），即"条件→结果"规则 |
| 目标 | 终端状态 → 一组**要满足的事实**（visited(A) ∧ visited(B)） |
| 规划器 | 就是**图搜索**（A* 的精神）：节点=符号状态，边=动作；Fast Downward 是工程化实现 |
| PDDL | 规划域定义语言：domain（动作规则）+ problem（初始态+目标） |

> 本质认知：**任务规划 = A* 换了状态表示**。本人熟悉的图搜索机制原封不动。

### 1.4 TSP / Stateflow / PDDL 的边界（什么时候用什么）

| 工具 | 角色 | 能表达 | 表达不了 |
|---|---|---|---|
| TSP/VRP | 组合优化（排序） | 访问一组点的最优顺序 | 依赖、资源、条件分支 |
| Stateflow | 过程式执行 | 执行逻辑、异常处理 | 逻辑复杂时手工图爆炸、改需求=改图 |
| PDDL 规划 | 声明式推理 | 依赖/资源/分支，自动推导序列 | 连续空间、实时控制 |

> **判据**：任务「固定、无依赖、无资源、无分支」→ TSP + Stateflow 就是最优解；
> 出现「逻辑依赖、资源约束、条件分支、任务不固定」→ 才用 PDDL 声明式规划。

### 1.5 代表性文献（按权威性分档）

**权威奠基（顶会/已发表，优先读）**
- **LLM+P**（ICLR 2024）：NL→PDDL→规划器→回译 的范式开山作。官方代码 [Cranial-XIX/llm-pddl](https://github.com/Cranial-XIX/llm-pddl)，论文 [ar5iv](https://ar5iv.labs.arxiv.org/html/2304.11477)
- **HuggingGPT**（NeurIPS 2023）："判断任务类型→路由到不同模型"的权威实现。代码 microsoft/JARVIS
- **SayCan**（CoRL 2022, Google）：语言接地到机器人可执行技能（affordance 过滤）。社区实现 [kyegomez/SayCan](https://github.com/kyegomez/saycan)
- **Code as Policies**（ICRA 2023, Google）：LLM 生成执行代码
- **Prompted to Fly**（IEEE BigData 2025，文件夹内）：schema 约束 + 归一化校验 + 导入检查 + SITL；招牌例子即"绕塔转三圈"

**UAV 专项预印本（新、对口、未同行评议）**
- **SPAR**（arXiv 2509.13691）：LLM 自动生成 PDDL **domain**（不只 problem），aerial robotics
- **MultiUAV-Plat**（arXiv 2606.31073）：多 UAV 协同任务规划平台 + 基准 + 框架
- **PEACE**（arXiv 2606.00104）：无人机 Planner–Executor Agent + 约束强制
- **MUTP-LLM**、**TPML**、**TACOS**：多机任务规划/协调

**综述**
- Emami 2026（文件夹内，IEEE）：LLM 辅助 UAV 操作与通信综述（三层框架、RAG、MLLM、伦理）
- Xiong 2026（文件夹内，Drones/MDPI）：P–C–A 视角综述（输出表征、S0–S3 验证层级）
- COLING 2025：[LLM Agent 的工具使用/规划/反馈综述](https://aclanthology.org/2025.coling-main.652/)

---

## 2. 路线二：自然语言 → 参数化机动 → 制导执行（本人的想法）

### 2.1 解决的问题（例子："在某点上空转十圈"）

**转圈任务 = 参数化任务**，不需要 PDDL/TSP，只需抽取参数 + 交给熟悉的制导/路径规划系统执行。

任务参数表（orbit 例子）：

| 参数 | 例子 | 来源 |
|---|---|---|
| 中心点 | 某塔台上空 | 用户说（需消歧） |
| 半径 r | 200 m | 用户说 / 默认值 |
| 高度 h | 100 m AGL | 用户说 / 默认值 |
| 方向 | 顺/逆时针 | 用户说 |
| 圈数 N | 10 | 用户说 |
| 速度 v | 15 m/s | 用户说 / 默认值 |
| 进入方式 | 切向切入（Dubins） | 执行端决定 |

### 2.2 完整流程（Simulink 环境版）

```
自然语言 "在某点上空顺时针转十圈"
   │
   ▼
① LLM 调用（MATLAB webwrite 调 API，temperature=0，要求严格 JSON）
   │  输出示例：
   │  {"action":"orbit","center_ref":"tower_A","radius_m":200,"alt_m":100,
   │   "alt_ref":"AGL","direction":"CW","turns":10,"speed_ms":15,"assumptions":[]}
   ▼
② 确定性层（纯 MATLAB 脚本）：
   - 范围检查、默认值注入、单位统一（LLM 不算数）
   - 坐标查表："tower_A" → [x,y,z]（LLM 不生成坐标）
   - 生成圆参考轨迹 x_ref/y_ref，或输出制导律参数 (r, v, 方向, N)
   ▼
③ Simulink 执行端（本人主场）：
   - 圆轨道跟踪：standoff 制导律（保持到中心距离=r、速度切向）
   - 进入轨道：Dubins 切向切入
   - 圈数计数：相对方位角积分累计 2π×N → 完成
   - 模式切换：Stateflow（进场切入 → Orbit → 退出）
   - 风补偿：有风时轨迹为摆线，制导律需风估计补偿
   │
   ▼
④ 执行反馈：圈数/状态 → 回 LLM（完成确认 / 异常重规划）
```

### 2.3 两种输出方案对比

| | 方案 A：输出给路径规划 | 方案 B：输出给制导系统 |
|---|---|---|
| 做法 | LLM 参数 → 确定性模块离散成圆航点 → 现有航路规划器 | LLM 参数 → Stateflow 切 orbit 模式 → standoff 制导律直出加速度指令 |
| 优点 | 完全复用已有系统，最稳妥 | 连续无离散误差，天然抗风，更优雅 |
| 缺点 | 多一层离散化，航点密度要调 | 需要制导系统有 orbit 模式 |
| 建议 | 起步用它 | 熟悉后升级 |

### 2.4 LLM 职责边界（防越权）

1. LLM 只做：参数抽取 + 消歧（缺失参数反问或 `assumptions` 记录）+ 严格 JSON 输出；
2. LLM 不做：坐标生成、距离/圈数计算、单位换算——全部由确定性层完成；
3. 退出行为（十圈后悬停/返航）也要在消歧时覆盖。

### 2.5 代表性文献

**论文**
- **NELV**（arXiv 2510.21739）：自然语言→航线规划→路径规划→控制执行→监控 的端到端框架。项目页 [liangqiyuan.github.io/NeLV](https://liangqiyuan.github.io/NeLV/)
- **TypeFly**（arXiv 2312.14950）：MiniSpec 精简控制语言 + 流式解释，LLM 生成控制代码，响应降 62%。[arXiv](https://arxiv.org/abs/2312.14950)
- **Prompted to Fly**（文件夹内）：同款任务（"orbit clockwise for three turns"）+ schema 约束 + SITL 验证
- **Taking Flight with Dialogue**（arXiv 2506.07509）：对话式 PX4 控制（多轮消歧参考）

**工程仓库（非学术权威，但能跑；本人无 PX4 经验，仅作架构参考）**
- [EchoPilot](https://github.com/Bilalileri/EchoPilot---Ollama---PX4---MCP)：Ollama + LangGraph + MAVSDK + MCP 的语音控制无人机
- [DroneFlow_llm](https://github.com/Alambdasystem/DroneFlow_llm)：PX4 + LLM
- [sky-track-vision-dev](https://github.com/oaslananka/sky-track-vision-dev)：AirSim + LLM 任务飞行员 + 确定性安全门（架构最接近"LLM 规划 + 校验"）
- [mavlink-mcp](https://lobehub.com/mcp/deepak61296-mavlink-mcp)：MAVLink 封装为 MCP 工具（LLM 直接调飞控指令的现成桥）

**转圈任务的飞控底层知识（本人已有，用于对照）**
- MAVLink `LOITER_TURNS` 命令（参数含圈数）——转圈在真实飞控里的标准形态
- Standoff 制导律（Frew 等）：绕点跟踪、风补偿

---

## 3. 两条路线的关系与组合

两条路线不是二选一，而是**同一套原则在两个层级上的应用**：

```
路线一（顶层，离散/符号）     路线二（中下层，连续/机动）
"先侦察 A，若发现目标检查，    "在某点上空转十圈"
 否则去 B，回来前充电"
        │                        │
   LLM 翻译 + 路由          LLM 参数抽取（JSON）
        │                        │
   PDDL/TSP 规划器          确定性层（校验/查坐标/生成轨迹）
        │                        │
   动作序列：侦察A→...        orbit 参数 / 圆参考轨迹
        │                        │
        └──────────┬─────────────┘
                   ▼
          执行层：航路规划 → 制导律 → 控制器 → 动力学模型
                   （路线一输出的"动作/航点"，落到路线二的执行机制）
```

**组合示例（完整系统）**：
> 用户："检查 A、B 两点，每个点上空绕 3 圈拍照，A 检查完才能去 B，全程别出划定的作业区。"
> - 路线一：LLM 抽取依赖（A→B）+ 约束（作业区）→ PDDL/TSP 生成动作序列（去A→绕圈→去B→绕圈→返航）
> - 路线二：序列中的每个"绕圈"动作 → LLM 抽参数 → standoff 制导执行
> - 校验与反馈贯穿两层

---

## 4. 文献清单总表（含文件夹内 6 篇）

| 文献 | 来源/年份 | 与本人的相关性 | 可复现性 |
|---|---|---|---|
| Prompted to Fly（Sharma） | IEEE BigData 2025，文件夹 | 路线一+二：schema 约束、转圈例子、SITL | 论文称有 public harnesses |
| Emami：LLM-Assisted UAV Ops & Comms | IEEE 综述 2026，文件夹 | 三层框架、RAG、MLLM、伦理；查相关工作的索引 | — |
| Xiong：P–C–A 视角综述 | Drones/MDPI 2026，文件夹 | 输出表征、接口、S0–S3 验证层级 | — |
| Chen：When LLM Meet UAV Projects | arXiv 2509.12795，文件夹（存了 PDF+HTML 两份） | 实证：学术-工业鸿沟、9 任务 4 工作流 | 数据公开（GitHub 补充材料） |
| Wu：LLM-Driven Pareto-Optimal MMRL | IEEE Access 2025，文件夹 | 路线"决策器/元控制器"（后续可关注） | — |
| AirTrafficGen | LAW 2025，文件夹 | 场景生成（路线一的邻近应用） | — |
| LLM+P | ICLR 2024 | 路线一奠基 | ✅ 官方代码 |
| HuggingGPT | NeurIPS 2023 | 路线一的"路由"思想 | ✅ microsoft/JARVIS |
| SayCan / Code as Policies | CoRL 2022 / ICRA 2023 | 语言接地执行（通用机器人） | 部分开源 |
| NELV | arXiv 2510.21739 | 路线二端到端 | 项目页 |
| TypeFly | arXiv 2312.14950 | 路线二实时执行 | arXiv |
| SPAR | arXiv 2509.13691 | 路线一 PDDL domain 生成 | 待确认 |
| MultiUAV-Plat / PEACE | arXiv 2606.x | 路线一多机/约束强制（新） | 待确认 |
| EchoPilot / DroneFlow_llm / sky-track-vision-dev | GitHub | 路线二工程参考（PX4 生态，本人在 Simulink 做可不深究） | ✅ 可直接 clone |

---

## 5. 落地建议（按本人 Simulink 环境）

**近期（路线二，先做能跑的东西）**
1. 写 `llm2orbit.m`：API 调用（webwrite，temperature=0）+ JSON 校验 + 坐标查表 + 圆参考轨迹生成；
2. Simulink 搭执行端：圆参考轨迹 → 现有制导律 → 控制器 → 6DOF 模型；加圈数计数器（atan2+积分+阈值）；
3. 先不用 LLM 跑通"转十圈"闭环（纯制导问题，已有能力）；
4. 再接 LLM，测试不同说法能否稳定抽对参数；
5. 升级：Stateflow 模式切换（切入→Orbit→退出）+ 风扰下 standoff 补偿。

**中期（路线一，视需要）**
1. 复现 LLM+P（官方代码 + Fast Downward）→ 掌握"NL→PDDL→规划器"全链路；
2. 若任务出现依赖/资源/分支 → 引入 PDDL 路线，与路线二组合成完整系统。

**待办/开放问题**
- [ ] MATLAB 会话连接本工作环境（MCP 桥接），以便直接协助调试
- [ ] 确认现有 Simulink 模型结构（6DOF + 制导律 + 控制器）
- [ ] 选 LLM API（DeepSeek 性价比高；需处理网络与 key）
- [ ] 决定方案 A（航点）还是方案 B（standoff 直给制导律）作为首版
