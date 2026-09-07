# LLM 在飞行器制导控制领域应用 — 调研清单

- 创建日期：2026-09-07
- 用途：导师布置的调研任务，产出支撑开题报告「研究现状 / 研究意义 / 技术路线」三节
- 使用方法：每答完一题打勾，并补一句话结论 + 2~3 条支撑文献；全部完成后把 E 类答案收敛为课题定位句

## 检索与筛选建议

- 检索式：`large language model + UAV/drone + guidance/control/mission planning/autonomy`
- 数据库：arXiv (cs.RO)、IEEE Xplore、MDPI Drones、航空学报 / 自动化学报
- 时间窗：2023 年至今（领域在 GPT-4 之后爆发）

## 起步文献

**综述（先读建立地图）：**

- [Large Language Model-Assisted UAV Operations and Communications: A Multifaceted Survey and Tutorial](https://ar5iv.labs.arxiv.org/html/2602.19534)
- [Large Language Models for UAV Autonomy from a Perception–Cognition–Action Perspective](https://www.mdpi.com/2504-446X/10/9/669)
- [When Large Language Models Meet UAVs: How Far Are We?](https://browse-export.arxiv.org/pdf/2509.12795)
- [A Review of Vision-Language Navigation Models for UAVs](https://zrb.bjb.scut.edu.cn/EN/10.12141/j.issn.1000-565X.260003)

**代表系统工作：**

- [A Universal Large Language Model - Drone Command and Control Interface](https://arxiv-org.ezproxy.obspm.fr/html/2601.15486v2)
- [Large Language Models to Enhance Multi-task Drone Operations in Simulated Environments](https://www.semanticscholar.org/paper/Large-Language-Models-to-Enhance-Multi-task-Drone-Feng-Snoussi/22d7a7e4fef85356eb822d347faab68e955d72bb)
- [Intent-based UAV Control through LLM-based Digital Twin](https://www.sciencedirect.com/science/chapter/edited-volume/abs/pii/B9780443455735000021)
- 经典开山：Microsoft "ChatGPT for Robotics"（2023）；"Foundation Models in Robotics: A Survey"（2023）

## A. 定位类

- [ ] 1. 学界怎么定义 LLM 在制导控制中的应用？主流分层是什么？与传统算法是替代还是互补、边界在哪？
  - 结论：
  - 文献：
- [ ] 2. 引入 LLM 的动机共识是什么？它解决了传统方法的什么结构性短板？
  - 结论：
  - 文献：

## B. 技术路线类

- [ ] 3. 主流技术架构有哪几类？各自的输入输出形态（语言 → 航点/任务/参数/动作）？
  - 结论：
  - 文献：
- [ ] 4. LLM 与哪些传统方法结合、结合点在哪？模型选型（开源/闭源）有无结论？
  - 结论：
  - 文献：
- [ ] 5. 实验用什么平台（仿真/真机）？有没有公开基准与评价指标？
  - 结论：
  - 文献：

## C. 能力与效果类

- [ ] 6. 目前的能力上限：哪些任务能稳定完成？相比纯传统方法，提升在哪、代价在哪？
  - 结论：
  - 文献：
- [ ] 7. 真机实验占比有多高，还是大多停留在仿真？
  - 结论：
  - 文献：

## D. 局限与风险类

- [ ] 8. 公认的局限是什么（幻觉、实时性、可复现性）？安全靠什么兜底？
  - 结论：
  - 文献：
- [ ] 9. 适航/军用认证的障碍讨论到什么程度？
  - 结论：
  - 文献：

## E. 空白与机会类

- [ ] 10. 哪些子问题、平台、任务还是空白？（固定翼、高动态飞行器、导弹制导……）
  - 结论：
  - 文献：
- [ ] 11. "LLM + 传统制导控制"混合架构与可靠性量化（校验层/纠错统计）研究充分吗？
  - 结论：
  - 文献：
- [ ] 12. 国内团队的工作现状如何？
  - 结论：
  - 文献：

## F. 方法类

- [ ] 13. 代表性综述有哪些、必引文献是什么？
  - 结论：
  - 文献：

## 汇总区

- **课题定位句：**（由 E 类答案收敛，一句话说明「做什么、凭什么、和现有工作的差异」）
- **回填设计规格：** 调研结论用于更新 `docs/superpowers/specs/2026-09-07-vlm-nl-waypoint-uav-design.md` 第 2 节「为什么引入 VLM」，把动机论证升级为带文献支撑的学术表述
