# 学界 LLM 在飞行器领域应用全景（顶层到底层）

- 创建日期：2026-09-07
- 用途：调研清单第 1 问的补充材料；供开题报告「研究现状」一节做领域地图
- 总体规律：**越靠近底层，工作越少、争议越大**——热度分布呈「哑铃形」：最顶层（空管/工程）与任务层最热，控制层最冷

## 1. 体系与运营层（最顶层，热度很高）

| 领域 | 代表性工作 |
|------|-----------|
| 空中交通管制（ATC） | 管制指令结构化提取（[TU Delft](https://repository.tudelft.nl/record/uuid:dd741afd-f5c8-4ce7-b2d8-e1424923260f)）；[LLM 作为冲突解决的人机对齐接口](https://xplorestaging.ieee.org/document/11257297)——管制员意图解析、冲突建议 |
| 航司运营 | 航班调度、延误管理、运营决策辅助 |

## 2. 任务与决策层（工作最密集）

- 任务/航路规划：自然语言 → 航点/任务序列（UAV 领域最大头）
- 编队协同与指挥控制：多机任务分配、集群指令理解
- 任务运营管理：[LLM-based expert agent for mission operation management](https://fub-hagen.digibib.net/search/eds/record/edsdoj:edsdoj.b5bdee1be28e43cabbf7bc35b3ade258)（卫星/任务运营场景）
- 在线重规划与异常处置：飞行中改航、应急决策

## 3. 控制层（工作显著变少）

- 调参与制导律选择：PID 增益、MPC 权重、控制模式切换——散见于 UAV 工作，无独立大流派
- 直接控制探索：极少数激进尝试，安全争议最大

## 4. 感知与交互层

- 视觉-语言导航（VLN）：VLM 看图导航
- 语音/自然语言指挥接口：语音控制、意图理解
- 态势理解与解释：LLM 用自然语言解释飞行意图、给操作员讲「为什么这么飞」

## 5. 全生命周期工程层（横向贯穿，不参与飞行，但体量很大）

- 设计：气动结构优化多智能体（[OpenAeroStruct LLM Agent](https://github.com/ideas-um/openaerostruct-llm-agent)）、概念设计辅助
- 维修 MRO：维修事件/成本建模的数字孪生（[GenAI Digital Twin](https://www.aircraftit.com/webinars/genai-powered-digital-twin-and-aviation-data-platform-for-modelling-aircraft-maintenance-events-and-costs-lease-transactions-future-scenarios-demo-webinar/?area=mro)）、维修手册问答、故障诊断
- 安全分析：ASRS 事故报告摘要与分析（[UMD 论文](https://www.cs.umd.edu/sites/default/files/scholarly_papers/Spring_2025_Basil,_Ehaab_Scholarly_Paper.pdf)）、NTSB 数据集 AI 分析
- 训练与文档：飞行员/操作员培训、适航文档生成

## 6. 空间与跨域

- 卫星任务规划：巨型星座 GPU 大规划模型（[IEEE](https://ieeexplore.ieee.org/document/11382728)）、在轨异常处置
- 导弹制导：几乎空白——只有零星讨论，本身即是调研第 10 问的「空白」证据

## 观察与结论

1. 热度分布呈「哑铃形」：最顶层（空管/工程）和任务层最热，控制层最冷——学界默认「LLM 别碰控制」
2. 本项目卡位：任务与决策层（第 2 层）既是工作最密集的层，又是「LLM + 传统制导控制」混合架构验证最需要的地方
