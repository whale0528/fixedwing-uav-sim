
## 1. 运营层

- 空中交通管制（ATC）：管制指令结构化提取（[TU Delft](https://repository.tudelft.nl/record/uuid:dd741afd-f5c8-4ce7-b2d8-e1424923260f)）；[LLM 作为冲突解决的人机对齐接口](https://xplorestaging.ieee.org/document/11257297)——管制员意图解析、冲突建议
- 航班调度、延误管理
- 辅助飞行员决策

## 2. 任务与决策层

### 2.1 任务/航路规划（最大头）

- 输入自然语言 → 输出任务序列/航点 JSON，代表性系统几乎都自带「校验/约束」模块：
  - Say'n'Fly（LLM 生成 + 形式化校验器否决，LLM-Modulo 路线）
  - PEACE（Planner–Executor + Constraint Enforcement）
  - Next-Generation LLM for UAV（自然语言到自主飞行）
  - 多任务无人机操作（Feng & Snoussi，仿真环境）
- 共同点：LLM 只负责语义翻译，几何可飞性交给传统模块

### 2.2 编队协同与指挥控制（C2，快速升温）

- [CoordField：低空城市 UAV 任务分配的协调场](https://www.aminer.cn/pub/6814223e163c01c850bfd3d8/coordfield-coordination-field-for-agentic-uav-task-allocation-in-low-altitude-urban)（agentic 任务分配）
- [Swarm-Steward：异构空地机器人自然语言协同](https://portal.findresearcher.sdu.dk/da/publications/swarm-steward-scalable-and-reliable-natural-language-coordination/)（自然语言协调整个集群）
- [LLM-Guided Distributed MPC for Decentralized UAV Formations](https://ieeexplore.ieee.org/document/11296797)（LLM 给分布式 MPC 出权重/约束，2/3 层跨界）
- SkyAgent（双机自适应协同路径规划，LLM + RL）
- 角色定位：LLM 当「协调者/仲裁者」，管队形、分配、冲突消解

### 2.3 在线重规划与自适应（飞行中决策）

- [LLM-Driven Pareto-Optimal Multi-Mode RL for Adaptive UAV Navigation in Urban Wind](https://ieeexplore.ieee.org/stamp/stamp.jsp?arnumber=11168480)（城市风场下多模式自适应切换）
- Intent-based UAV Control（数字孪生路线，Elsevier 章节）
- 共同点：环境变化/新指令 → 模式切换或重规划，核心词是「自适应」

### 2.4 异常处置与配置修复

- [RisConFix：LLM 自动修复有风险的无人机配置](https://ieeexplore.ieee.org/document/11576647)（[arXiv 2512.07122](https://ar5iv.labs.arxiv.org/html/2512.07122)）
- 应急返航预案、故障下决策生成

## 3. 控制层

### 3.1 调参与制导律选择（最成熟、最安全）

- 经典源头：ChatGPT for Robotics（2023）PID 调参示例
- [LLM-Assisted Multi-Agent Control Framework（LLM 迭代推理调 PID 超参数）](https://arxiv.org/html/2511.22975)
- LLM-Guided DMPC（LLM 调 MPC 权重）——MPC 是 LLM 进入控制层最热的结合点
- 关键性质：控制律结构不变，LLM 只改参数 → 稳定性论证可继承，这是学界接受 LLM 进控制层的「安全门」

### 3.2 控制模式/策略切换（中风险）

- RB-LLM Control（规则库约束 LLM 决策，LLM 只选「用哪条规则/模式」，执行仍是确定性控制器）
- LLM-Driven Multi-Mode RL（Pareto 最优模式切换）
- 关键性质：LLM 选策略，控制器本身不动

### 3.3 直接控制探索（最激进、极少）

- [Fine-Tuned Language Models as Space Systems Controllers](https://ui.adsabs.harvard.edu/abs/2025arXiv250116588Z/abstract)（微调 LLM 直接当航天系统控制器，微调路线）
- 单 LLM 直接控制无人机的工程实践与约束边界（社区工程文章：[架构](https://blog.hotdry.top/posts/2026/01/27/single-llm-drone-control-architecture/)、[约束边界](https://blog.hotdry.top/posts/2026/01/27/llm-single-model-drone-control-constraints/)）
- 争议焦点：非原理上不可能，但推理延迟（秒级）对不上控制环（毫秒级）、数值不可靠、无法证明——安全关键场景公认不可用

## 4. 感知与交互层

- 视觉-语言导航：VLM 看图导航
- 语音/自然语言指挥接口：语音控制、意图理解
- 态势理解与解释

## 5. 其他

- 设计：气动结构优化多智能体（[OpenAeroStruct LLM Agent](https://github.com/ideas-um/openaerostruct-llm-agent)）、概念设计辅助
- 维修 MRO：维修事件/成本建模的数字孪生（[GenAI Digital Twin](https://www.aircraftit.com/webinars/genai-powered-digital-twin-and-aviation-data-platform-for-modelling-aircraft-maintenance-events-and-costs-lease-transactions-future-scenarios-demo-webinar/?area=mro)）、维修手册问答、故障诊断
- 安全分析：ASRS 事故报告摘要与分析（[UMD 论文](https://www.cs.umd.edu/sites/default/files/scholarly_papers/Spring_2025_Basil,_Ehaab_Scholarly_Paper.pdf)）、NTSB 数据集 AI 分析
- 训练与文档：飞行员/操作员培训、适航文档生成

