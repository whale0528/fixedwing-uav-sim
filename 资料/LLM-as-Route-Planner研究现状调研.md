# LLM-as-Route-Planner 研究现状调研

> **调研缘起**：NELV 论文在其五级自动化分类法中，将 L2 定义为 "LLM-as-Route-Planner"（LLM 即航线规划器），并指出当前通用 LLM 尚不具备该能力。本文调研该能力层级的现有研究工作、技术路线与实际达成度。
> **调研时间范围**：以 2023–2026 年为主
> **方法论说明**：本文基于公开检索（网络检索工具，约 20 轮查询）。**受环境限制，未能下载并通读全部原文**；部分工作的判断依据为标题、检索摘要与二次文献，已在相应位置标注。所有结论性判断均给出依据，未经验证者明确标记。

---

## 摘要

本文调研"大语言模型作为航线规划器"（LLM-as-Route-Planner）的研究现状。首先依据 NELV 的原始定义，将 L2 能力拆解为五项子能力，并给出"严格标准"与"宽松标准"两条判据。随后提出**按 LLM 输出物分类**的四类框架（输出节点序列 / 输出求解模型 / 输出工具调用 / 输出参数），并补充航空领域专门工作与评测基准两节。调研发现：**按严格标准，尚不存在真正意义上让 LLM 自主完成"节点选择 + 顺序优化 + 约束下取舍"的成熟工作**；现有研究普遍将数值计算与约束求解外包给确定性工具，LLM 的实际角色退化为调度者或形式化者。领域证据（消融实验、方法论批判、专用基准）一致表明，让 LLM 直接产出最优解会落入"启发式陷阱"，其失败模式为**静默次优**。据此，本文认为 NELV 对 L2 的定义（LLM 接管 OR-Tools 的位置）应当修正为"**LLM 生成优化模型、求解器求解**"的双层结构。

**关键词**：大语言模型；航线规划；组合优化；任务分配；形式化建模；运行时保障

---

## 1. 问题的界定

### 1.1 NELV 的原始定义

NELV 论文对 L2 的描述包含以下要素：

> "L2 级 LLM-as-Route-Planner 要求 LLM 具备运行环境的全面知识，具体关于节点，包括其地理位置、运行状态，以及其他任务关键参数，如燃油价格。除知识获取外，LLM-as-Route-Planner 还必须对人类飞行员指令进行复杂分析，展示上下文推理能力，理解人类飞行员偏好，并制定最优规划方案。"

据此可拆解为**五项子能力**：

| # | 子能力 | 说明 |
|---|---|---|
| ① | 节点领域知识 | 掌握节点的地理坐标、运行状态、燃油价格等属性 |
| ② | 数值计算 | 计算飞行时长、消耗、排序等 |
| ③ | 显性偏好理解 | "最经济"、"尽快"、"最近"等直接表述的偏好 |
| ④ | **隐性偏好理解** | 源自人类经验判断、未在指令中直接表述的偏好 |
| ⑤ | 硬约束下的最优求解 | 在燃油容量、航程、时间窗等约束下求最优 |

论文对 ④ 明确指出"可能通过基于人类反馈的强化学习（RLHF）解决"，但**未予实现**。

### 1.2 判据的设定

由于"LLM 参与规划"的表述极为宽泛，需要设定明确的判据。

**严格标准**：LLM **自主完成**节点的选择、顺序的确定与约束下的取舍，**不将优化外包给确定性求解器**。

**宽松标准**：LLM **主导决策过程**（提出方案、理解偏好、组织流程），数值计算与约束求解可借助工具。

**分水岭在于子能力 ② 与 ⑤**：若 LLM 将计算与求解外包，则其在实质上承担的是**调度（orchestration）或形式化（formulation）**职能，而非规划职能。

本文同时报告两条标准下的结果。

---

## 2. 分类框架

现有工作按**LLM 的输出物**可划分为四类，另有航空领域专门工作与评测基准两节。

```
                        LLM 输出什么？
                              │
   ┌───────────┬──────────────┼──────────────┬───────────┐
   │           │              │              │           │
 A. 节点序列  B. 求解模型    C. 工具调用    D. 参数
 （严格L2）   （形式化者）   （调度者）     （Parser变体）
   │           │              │              │
 极少        方法论最正确    最流行        最多，但不算规划
```

| 类别 | LLM 输出 | 谁做优化 | 是否满足严格标准 | 是否满足宽松标准 |
|---|---|---|---|---|
| A | 有序节点序列 | LLM 自己 | ✅ | ✅ |
| B | 优化模型 / 求解代码 | 求解器 | ❌ | ✅ |
| C | 工具调用序列 | 工具（求解器） | ❌ | ✅（弱） |
| D | 结构化参数 | 下游模块 | ❌ | ❌ |

---

## 3. A 类：直接输出节点序列

**这是严格意义上最接近 L2 的一类，也是数量最少的一类。**

| 工作 | 年份 | 内容 | 关键点 |
|---|---|---|---|
| **From Words to Routes: Applying Large Language Models to Vehicle Routing** | 2024 | 将 LLM 直接应用于车辆路径问题（VRP） | **定义了三个评测指标**以评估解的质量。属于"诚实检验 L2 可行性"的代表性工作 |
| **Employing in-context learning prompts with LLMs for drone routing in delivery services** | 2025 | **无人机配送路径规划** | ★ **所检索到的唯一直接面向无人机路径规划的工作**。采用 in-context learning 提示，**无需领域训练数据**，从而绕开了"缺乏无人机数据集"这一瓶颈；并与**演化算法**进行了性能对比 |
| **Large Language Models as End-to-end Combinatorial Optimization Solvers** | 2025 | 将 LLM 作为端到端组合优化求解器 | NeurIPS 2025。标题即为其所检验的主张 |
| **LaT: LLM-as-Trainer for Multi-Task Vehicle Routing Solvers** | 2026 | LLM 不作为求解器，而是**训练**求解器 | 报告了具体最优性差距数值（如 8.684%、2.380%）。**角色的再次转移**：LLM 从"求解者"变为"训练者" |
| **LLMs vs. Heuristics: Tackling the Traveling Salesman Problem** | — | LLM 与启发式算法在 TSP 上的正面比较 | 非学术出版物（技术博客），可作为工程视角参考 |

**该类别的总体特征**：在小规模实例上具备可行性；实例规模增大后性能显著下降；与精确求解器相比存在明确的最优性差距。

**代码可得性**：From Words to Routes 与 LaT 均为 arXiv 预印本，代码可得性未确认；PLOS ONE 一篇为开放获取。

---

## 4. B 类：输出求解模型（形式化者）

**该类别不要求 LLM 给出答案，而要求其将问题表述为数学规划模型，交由求解器求解。** 从方法论角度，这是目前被认为最正确的范式。

| 工作 | 年份/出处 | 内容 |
|---|---|---|
| **Formalize, Don't Optimize: The Heuristic Trap in LLM-Generated Combinatorial Solvers** | 2026, arXiv:2605.12421 | ★ **核心批判性工作**。论点：当要求 LLM 直接产出解时，它会落入"启发式陷阱"——生成看似合理、实则系统性次优甚至违反约束的解；正确做法是令其输出形式化模型 |
| **DRoC: Elevating Large Language Models for Complex Vehicle Routing via Decomposed Retrieval of Constraints** | ICLR 2025 | 针对复杂 VRP 的约束做**分解式检索**，使 LLM 能够处理其不擅长的复杂约束组合。**代码开源**（github.com/Summer142857/DRoC） |
| **OptiMUS / LLMOPT / COOPA** | 2024–2026 | "LLM 自动构建优化模型"整条技术线。COOPA 为面向运筹问题的模块化 LLM 智能体架构 |
| **LLM-based optimization framework: An architectural overview** | 2026 | 该方向的体系结构综述 |
| **Mathematical Programming Through the Lens of LLMs: Systematic Evidence and Empirical Gaps** | 2026, IEEE | 对该类工作的**系统性证据检视**，专门评估其证据充分性 |
| **Large Language Models in Operations Research: Methods, Applications, and Challenges** | 2025 | 运筹学与 LLM 交叉的综述 |
| **LLMs Can Solve Real-World Planning Rigorously with Formal Verification Tools** | NAACL 2025 | LLM 生成 + 形式化验证器背书 |
| **Grounding Generative Planners in Verifiable Logic: A Hybrid Architecture for Trustworthy Embodied AI** | ICLR 2026 | 将生成式规划器锚定于可验证逻辑 |
| **EvoPlan: Evolutionary Neuro-Symbolic Robot Planning with Spatio-Temporal Guarantees** | 2026, arXiv:2607.06724 | 神经符号规划，带时空保证 |

**该类别的工作分工**：LLM 负责建模（变量、目标函数、约束），求解器负责求解并给出最优性界或可行性证明。

**需要注意的定位问题**：该类别中的 LLM **仍然可被称为"规划器"，但它规划的是"问题的形式"而非"具体的路线"**。这一区分在学术表述中往往被模糊化。

---

## 5. C 类：输出工具调用（调度者）

**该类别是目前工程上最流行、也最接近"可运行系统"的做法。**

| 工作 | 年份/出处 | 内容 | 关键证据 |
|---|---|---|---|
| **Hierarchical LLMs in-the-Loop Optimization for Real-Time Multi-Robot Target Tracking Under Unknown Hazards** | arXiv:2409.12274；IEEE | Vijay Kumar 课题组。**高层 LLM 负责任务分配（即节点序列），低层采用经典优化进行实时跟踪控制** | ★ **代码开源**（github.com/Zhourobotics/hierarchical-llms）。"in-the-loop optimization"的表述本身即表明 LLM 不替代优化器 |
| **Say the Mission, Execute the Swarm: Agent-Enhanced LLM Reasoning in the Web-of-Drones** | arXiv:2605.03788；IEEE | 无人机集群的任务执行 | ★ **关键消融实验**：论文图示显示，**任务成功率强烈依赖于"区域覆盖规划器"工具是否可用**。移除该工具后成功率显著下降 |
| **TACOS: Task Agnostic Coordinator of a Multi-Drone System** | MDPI *Drones* 2026, 10(4):251 | 任务无关的多无人机协调器架构 | 期刊论文，可获取 |
| **MultiUAV-Plat: An LLM-Oriented Platform, Benchmark and Framework for Multi-UAV Collaborative Task Planning** | arXiv:2606.31073 | 多无人机协同任务规划的**平台 + 基准 + 框架** | 提供基准，较纯演示类工作更具可比性 |
| **Deployment Method for Emergency Delivery of Multi-Agent UAV Swarms Driven by Large Language Models** | IEEE, 2026 | LLM 驱动多机应急投送部署方法 | 摘要级信息 |
| **LEHiD: LLM-Empowered Hierarchical DRL Framework for Path Planning in UAV Networks** | 2026 | LLM + 分层深度强化学习 | 与学习方法结合 |
| **A Large Language Model-Driven Heterogeneous Air-Ground Search Swarm** | ICLR 2025 Workshop | 空地异构搜索集群 | 会议 workshop |
| **EchoPilot**（开源项目） | GitHub | Ollama + LangGraph + MAVSDK + MCP 的语音控制无人机 | 工程实现，非学术产出 |

**该类别的实质**：LLM 输出"先调用工具 A，再调用工具 B"的序列。**最困难的优化工作由工具承担，LLM 承担流程组织。** 因此其名义上是 Planner，实质上更接近 **Orchestrator（调度者）**。

**该类别的关键风险**：见 §7.2。

---

## 6. D 类：输出结构化参数（Parser 的变体）

**该类工作与 NELV 的 L1 最为接近**：LLM 抽取参数或生成受限代码，规划工作完全交由下游。

| 工作 | 年份/出处 | 内容 |
|---|---|---|
| **Skypilot: Fine-Tuning LLM with Physical Grounding for AAV Coverage Search** | arXiv:2511.18270 | 以物理接地方式微调 LLM，执行自主飞行器**覆盖搜索**。报告 CSI = CR × SR（覆盖率 × 成功率）指标 |
| **Prompted to Fly: Translating Free-Form Instructions into Schema-Constrained Mission Generation for UAVs Using LLMs** | IEEE BigData 2025 | **schema 约束**的任务生成 + 归一化校验 + 导入检查 + SITL 验证 |
| **AeroGen: Agentic Drone Autonomy through Single-Shot Structured Prompting & Drone SDK** | arXiv:2603.14236 | 单次结构化提示生成控制程序；**仿真与真机部署生成的程序结构一致** |
| **UAV-VLA: Vision-Language-Action System for Large Scale Aerial Mission Generation** | HRI 2025 | 大规模空中任务生成。代码开源（github.com/c6ai/UAV-VLA） |
| **FineCog-Nav** | arXiv:2604.16298 | 细粒度认知模块的零样本多模态无人机导航 |

**该类别证明了一件事**：领域微调确实有效，**但其代价是需要领域数据，且微调后的 LLM 往往退化为"结构化生成器"，而非优化器**。

---

## 7. E 类：航空/通航领域专门工作

**该类工作与 NELV 用例 3（远程多跳转场）的场景最为接近。**

| 工作 | 出处 | 内容 | 架构关键词 |
|---|---|---|---|
| **MIT Lincoln Laboratory：agentic AI 生成飞行航路** | 官方新闻发布 | 联邦实验室将 agentic AI 用于飞行路径生成 | 表明该问题已进入严肃工程阶段 |
| **FRAMe: End-to-End LLM Flight Planning with RAG-based Memory and Multi-modal Coach Agent** | arXiv:2607.06964；**ICML 2026** | 端到端 LLM 飞行计划 | ★ **RAG-based memory**（知识外挂）+ **Coach Agent**（监督者）。架构为"LLM + 检索 + 监督者"，而非"LLM 求最优" |
| **AI Flight Dispatcher with Claude, MCP, and Live NOTAMs** | 技术博客 | 以 MCP 接入实时 NOTAM 与气象数据，实现飞行签派 | MCP 工具调用 |
| **Agentic AI-Driven Flight Planning: A Collaborative Approach with Mistral Large and GPT-5** | 技术博客 | 多模型协作的飞行计划生成 | 多模型 |
| **A Formalized Approach to Agentic Control: Flight Plan Generation and Constraint Satisfaction** | 技术博客 | 飞行计划生成与约束满足 | "Formalized" 与 "Constraint Satisfaction" |
| **Aerospace MCP / Navigation Toolkit MCP** | 工具服务 | 将飞行计划 API 封装为 LLM 可调用的工具 | 工具化 |
| **jjasghar/ai-airport-simulation** | GitHub | 在沙盒机场环境中测试 LLM 能否实时做出正确决策 | 评测性实验 |

**该类别的共同特征**：**无一例外地采用"检索 + 工具调用 + 规则校验"的组合，而非让 LLM 自主求解最优航路。**

---

## 8. 评测基准

判断"LLM 能否作为航线规划器"需依赖系统性评测。检索到的相关基准如下：

| 基准 | 出处 | 测什么 | 与本问题的关系 |
|---|---|---|---|
| **CostBench** | arXiv:2511.02734 | **多轮成本最优规划与动态环境适应**，面向工具使用型 Agent | ★ **与 L2 问题最直接相关**：直接测量 LLM 能否找到成本最优方案 |
| **TREK: A Travel Reasoning and Evaluation Kit** | arXiv:2607.26977 | 复杂行程规划中 LLM Agent 的推理与评测 | 行程规划与"节点序列 + 多约束 + 偏好"同构。**代码开源** |
| **MobilityBench** | arXiv:2602.22638；ACM | 真实出行场景中的路线规划 Agent | 地面出行域，**不能直接迁移至航空** |
| **TravelPlanner** | 2024 | 多日多城行程规划 | 被广泛引用的早期基准 |
| **HiMAP-Travel** | ICML 2026 | 长时程约束行程的层级多智能体规划 | 层级架构 |
| **MultiUAV-Plat** | arXiv:2606.31073 | 多无人机协同任务规划 | 见 §5 |

**这些基准的存在本身具有意义**：它表明学界已开始系统性地检验"LLM 作为路线规划器"的能力，而非仅停留在演示层面。

---

## 9. 量化证据与总体结论

### 9.1 三条相互印证的证据链

**证据一：消融实验**

*Say the Mission, Execute the Swarm* 显示，移除区域覆盖规划器工具后任务成功率显著下降。**含义**：空间优化的困难完全由工具承担，LLM 仅负责调用决策；其自身不具备补足该缺口的能力。

**证据二：方法论批判**

*Formalize, Don't Optimize* 论证：令 LLM 直接产出解会落入"启发式陷阱"，生成看似合理但系统性次优或违反约束的解。**含义**：这类失败是**静默的**——输出格式正确、数值正确、外观合理，因而难以察觉。

**证据三：范式转移**

LaT 将 LLM 的角色从"求解器"改为"求解器的训练者"；DRoC、OptiMUS 等将 LLM 的角色定为"建模者"；航空类工作普遍采用"检索 + 工具 + 校验"。**含义**：领域正在系统性地将 LLM 移出优化回路。

### 9.2 与 NELV L2 定义的逐项对照

| NELV 的子能力 | 达成状况 | 说明 |
|---|---|---|
| ① 节点领域知识 | ⚠️ 部分 | 依靠 RAG / 工具调用外挂，而非内化于模型参数 |
| ② **数值计算** | ❌ 未达成 | **未检索到让 LLM 自主完成规划相关数值计算的成熟工作**；普遍外包 |
| ③ 显性偏好理解 | ✅ 基本达成 | 多篇工作涉及（如 LLMAP） |
| ④ **隐性偏好理解** | ❌ 未达成 | **NELV 点名 RLHF，但检索中未发现航空/无人机领域的实现** |
| ⑤ **硬约束下的最优求解** | ❌ 未达成（严格标准下） | 现有做法为：LLM 建模，求解器求解 |

### 9.3 严格标准下的结论

**按严格标准（LLM 自主完成节点选择、顺序优化与约束下取舍），尚不存在成熟工作。**

原因并非"技术尚未尝试"，而是**已有多条证据表明该路线存在结构性缺陷**：

1. LLM 的数值与约束推理可靠性不足；
2. 其失败模式为静默次优，对安全关键系统不可接受；
3. 组合优化问题存在成熟、快速、可给出最优性保证的经典求解器，用 LLM 替代并无收益。

---

## 10. 未解决的问题

| 缺口 | 具体说明 |
|---|---|
| **缺乏同类实例上的严格对比** | **未检索到任何工作在"远程多跳加油机场选择"这类问题上，对 LLM 直接规划与 OR-Tools 精确求解做同实例的最优性差距与耗时对比**。这是最直接的空白 |
| **航空领域的 L2 专用基准缺失** | CostBench、TREK、MobilityBench 均属地面出行域，不能直接迁移 |
| **隐性偏好学习几近空白** | 该能力是 LLM 相对规则系统的**唯一结构性优势**（规则系统无法习得经验判断），且 NELV 明确点名 RLHF，但**无人实现** |
| **NELV 作者自身未实现 L2** | 其前作 LLMAP（EMNLP 2025 Findings）为最接近的已发表工作，但 NELV 正文未将其作为 L2 实现 |
| **形式化范式的鲁棒性评估不足** | B 类工作报告了建模准确率，但"模型写错"与"解求错"的失效边界尚不清楚 |

---

## 11. 结论与建议

### 11.1 结论

1. **"LLM-as-Route-Planner" 存在相关研究，但按 NELV 的严格定义（LLM 自主计算与求解），尚不存在成熟工作。**

2. **现有多数工作实质上属于三类角色之一**：**调度者**（输出工具调用，最流行）、**形式化者**（输出优化模型，方法论最正确）、**参数抽取者**（输出结构化参数，实为 Parser 变体）。

3. **领域正在收敛于一个共识架构**：

   ```
   ┌──────────────────────────────────────────────────────┐
   │ 翻译层   LLM：语义理解 · 任务分解 · 形式化建模         │
   │          （不承担优化求解）                           │
   └────────────────────┬─────────────────────────────────┘
                        │ 形式化模型 / 工具调用
   ┌────────────────────▼─────────────────────────────────┐
   │ 决策层   求解器 + 规则库 + 验证器                     │
   │          （提供最优性界与可行性证明）                  │
   └────────────────────┬─────────────────────────────────┘
                        │ 解 + 保证
   ┌────────────────────▼─────────────────────────────────┐
   │ 裁决层   人 / 独立验证器                              │
   └──────────────────────────────────────────────────────┘
   ```

4. **据此，NELV 对 L2 的定义应作修正**：从"LLM 接管 OR-Tools 的位置"改为"**LLM 生成优化模型与约束、求解器求解**"。这一修正不违反 L2 的原意（LLM 仍然决定模型、目标与约束），但将其从"不可验证"转为"可验证"。

### 11.2 对后续研究的建议

| 优先级 | 建议 | 理由 |
|---|---|---|
| **高** | 在同类实例（如远程多跳加油机场选择）上做 **LLM 直接规划 vs. 精确求解** 的严格对比，报告最优性差距、可行率与耗时 | 直接填补最大空白，且方法学清晰 |
| **高** | 实现并评测**隐性偏好学习**（以飞行员的实际选择行为为监督信号） | 该能力是 LLM 唯一的结构性优势，且无人涉足 |
| **中** | 建立**航空领域的 L2 基准**（含硬约束、时间窗、燃油经济性） | 现有基准均为地面出行域 |
| **中** | 研究**规划器失效的可验证性**："LLM 提议 + 独立验证器裁决"架构在航空场景下的完备性 | 承接口述方向与适航要求 |
| **低** | 将 FAA 法规形式化为可调用的规则库 | 价值高但属知识工程，工作量密集 |

---

## 附录 A：文献总表

| # | 工作 | 年份 | 类别 | LLM 输出 | 谁做优化 | 量化评测 | URL / 标识 |
|---|---|---|---|---|---|---|---|
| 1 | From Words to Routes | 2024 | A | 节点序列 | LLM | 三个指标 | arXiv:2403.10795 |
| 2 | Drone routing with in-context learning | 2025 | A | 节点序列 | LLM | 与演化算法对比 | 10.1371/journal.pone.0321917 |
| 3 | LLMs as End-to-end CO Solvers | 2025 | A | 解 | LLM | 待确认 | NeurIPS 2025 |
| 4 | LaT: LLM-as-Trainer for VRP Solvers | 2026 | A | 训练信号 | 求解器 | 有 gap 数值 | arXiv:2607.17708 |
| 5 | **Formalize, Don't Optimize** | 2026 | B | 形式化模型 | 求解器 | 批判性论证 | arXiv:2605.12421 |
| 6 | DRoC | 2025 | B | 约束表示 | 求解器 | 有 | ICLR 2025；代码开源 |
| 7 | OptiMUS / LLMOPT / COOPA | 2024–26 | B | 优化模型 | 求解器 | 有 | 多篇 |
| 8 | LLMs Can Solve Planning with Formal Verification | 2025 | B | 模型 + 验证 | 求解器/验证器 | 有 | NAACL 2025 |
| 9 | Grounding Generative Planners in Verifiable Logic | 2026 | B | 可验证逻辑 | 求解器 | 有 | ICLR 2026 |
| 10 | **Hierarchical LLMs in-the-Loop** | 2024 | C | 任务分配 | 经典优化 | 有 | arXiv:2409.12274；代码开源 |
| 11 | **Say the Mission, Execute the Swarm** | 2026 | C | 工具调用 | 工具 | **消融实验** | arXiv:2605.03788 |
| 12 | TACOS | 2026 | C | 协调策略 | 工具 | 有 | MDPI Drones 10(4):251 |
| 13 | MultiUAV-Plat | 2026 | C | 任务方案 | 工具 | 提供基准 | arXiv:2606.31073 |
| 14 | Skypilot | 2026 | D | 参数 | 下游 | CSI 指标 | arXiv:2511.18270 |
| 15 | Prompted to Fly | 2025 | D | schema 参数 | 下游 | SITL 验证 | IEEE 11401432 |
| 16 | AeroGen | 2026 | D | 控制程序 | 下游 | 仿真+真机 | arXiv:2603.14236 |
| 17 | **FRAMe（LLM 飞行计划）** | 2026 | E | 飞行计划 | RAG+校验 | 待确认 | arXiv:2607.06964；ICML 2026 |
| 18 | MIT Lincoln Laboratory agentic flight paths | 2025 | E | 航路 | 待确认 | 待确认 | 官方新闻 |
| 19 | CostBench | 2025 | 基准 | — | — | 成本最优性 | arXiv:2511.02734 |
| 20 | TREK | 2026 | 基准 | — | — | 行程规划 | arXiv:2607.26977；代码开源 |
| 21 | MobilityBench | 2026 | 基准 | — | — | 路线规划 Agent | arXiv:2602.22638 |
| 22 | **LLMAP**（NELV 作者前作） | 2025 | B/A | 多目标路线 | 求解器 | 有 | Findings of EMNLP 2025 |

## 附录 B：最值得精读的五篇

1. **Say the Mission, Execute the Swarm**（arXiv:2605.03788）—— 其消融实验是"LLM 无法自主完成空间优化"最直接的实验证据。
2. **Formalize, Don't Optimize**（arXiv:2605.12421）—— 从方法论层面论证了"为何不应让 LLM 直接产出解"。
3. **CostBench**（arXiv:2511.02734）—— 直接测量 LLM 能否达到成本最优，是 L2 问题的判据性基准。
4. **Employing in-context learning prompts with LLMs for drone routing**（PLOS ONE）—— 唯一直接面向无人机路径规划的工作，且方法绕开了数据瓶颈。
5. **LLMAP**（Findings of EMNLP 2025）—— NELV 作者自身的 L2 雏形，信息密度高于 NELV 正文的 L2 章节。

## 附录 C：调研方法论与局限性声明

**检索方式**：网络检索工具，约 20 轮查询，覆盖英文与中文关键词。

**局限**：

1. **未能通读全部原文。** 受运行环境网络访问限制，部分工作的判断依据为标题、检索摘要与二次文献。此类判断已在正文标注，或在附录 A 的"量化评测"列标记为"待确认"。
2. **覆盖度有限。** 检索以 arXiv、IEEE、MDPI、ACL Anthology 等来源为主，可能遗漏部分会议论文与工业界成果。
3. **时间边界。** 以 2023–2026 年为主，更早的经典工作（如 LLM+P、SayCan）未纳入分类统计。
4. **分类存在主观性。** "LLM 输出物"的分类依据论文自述与摘要，部分工作可能同时跨越两类。
