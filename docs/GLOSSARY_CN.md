# MemPalace 术语表

供学习和参考的中文术语解释，覆盖项目架构、检索技术、评估指标、基准测试和竞品对比。

---

## 目录

1. [记忆宫殿架构](#1-记忆宫殿架构)
2. [记忆层级系统](#2-记忆层级系统)
3. [AAAK 方言](#3-aaak-方言)
4. [检索与搜索技术](#4-检索与搜索技术)
5. [评估指标](#5-评估指标)
6. [基准测试与方法论](#6-基准测试与方法论)
7. [技术栈](#7-技术栈)
8. [数据处理流程](#8-数据处理流程)
9. [知识图谱](#9-知识图谱)
10. [竞品系统](#10-竞品系统)

---

## 1. 记忆宫殿架构

灵感来自古希腊"位置记忆法"（Method of Loci）：演说家把要记的内容放在想象中建筑的不同房间里，走一遍建筑就能回忆全部内容。MemPalace 将同样的原理应用于 AI 记忆组织。

### Palace（宫殿）

顶层容器，即整个记忆数据库。物理上是一个 ChromaDB 向量数据库，默认存储在 `~/.mempalace/palace`。所有记忆都"住在宫殿里"。

### Wing（翼）

宫殿的一级分区。每个人或项目拥有独立的一翼。例如所有关于"Kai"的记忆在 `wing_kai`，所有关于"Driftwood"项目的记忆在 `wing_driftwood`。作为 ChromaDB 文档的元数据字段存储，是检索时的**主要过滤维度**。

### Room（房间）

翼内的二级分区，代表一个具体主题。例如 `auth-migration`（认证迁移）、`graphql-switch`（GraphQL 切换）、`ci-pipeline`（CI 流水线）。同一个房间名可以出现在多个翼中，此时自动产生 Tunnel（隧道）。

### Hall（走廊）

连接房间的通道，按**记忆类型**分类。每个翼都有相同的走廊：

| 走廊 | 存储内容 |
|------|---------|
| `hall_facts` | 已做出的决定、锁定的选择 |
| `hall_events` | 会话、里程碑、调试记录 |
| `hall_discoveries` | 突破、新发现 |
| `hall_preferences` | 习惯、喜好、观点 |
| `hall_advice` | 建议和解决方案 |
| `hall_diary` | Agent 日记条目 |

### Tunnel（隧道）

跨翼连接。当同一个房间名（如 `auth-migration`）出现在两个以上的翼中时，这些房间自动通过隧道关联。隧道使得跨项目、跨人员的查询成为可能。

```
wing_kai       / auth-migration  ← "Kai 调试了 OAuth token 刷新"
       ↕ tunnel
wing_driftwood / auth-migration  ← "团队决定迁移到 Clerk"
       ↕ tunnel
wing_priya     / auth-migration  ← "Priya 批准了 Clerk 方案"
```

### Closet（衣橱）

房间和抽屉之间的**摘要层**。衣橱存储内容的概览摘要，指向底层的抽屉原文。AI 先看衣橱知道"这里大概有什么"，再按需打开抽屉看原文。当前版本使用纯文本摘要，未来计划用 AAAK 编码。

### Drawer（抽屉）

最小存储单元。存储**逐字原文**，绝不做摘要裁剪。每个抽屉是 ChromaDB 中的一条文档记录，带有 `wing`、`room`、`source_file` 等元数据。抽屉 ID 由内容哈希生成，相同内容不会重复存储。

### Palace Graph（宫殿图）

由 `palace_graph.py` 构建的内存导航图。节点是房间，边是隧道。支持从任意房间出发做 BFS（广度优先搜索）遍历，找到跨翼的关联信息。

---

## 2. 记忆层级系统

MemPalace 采用四层架构，按需加载，越往上成本越低：

| 层级 | 名称 | 大小 | 加载时机 |
|------|------|------|---------|
| **L0** | Identity（身份） | ~50 token | 每次启动自动加载 |
| **L1** | Essential Story（关键故事） | ~120-800 token | 每次启动自动加载 |
| **L2** | On-Demand（按需召回） | ~200-500 token/次 | 话题出现时加载 |
| **L3** | Deep Search（深度搜索） | 不限 | 明确要求时搜索 |

### L0 / Identity（身份层）

存储在 `~/.mempalace/identity.txt`，定义"这个 AI 是谁"。每次会话开始时自动注入上下文，约 50 token。

### L1 / Essential Story（关键故事层）

从所有抽屉中自动筛选重要度最高的 15 条记录（按 emotional_weight 评分），按房间分组，压缩到 3200 字符以内。这是 AI "醒来"后立即了解的世界概览。

### L2 / On-Demand（按需层）

根据当前话题的翼/房间做元数据过滤检索（不是语义搜索，是精确的元数据匹配）。当对话涉及某个特定项目或人时触发。

### L3 / Deep Search（深度搜索层）

完整的语义向量搜索，可选翼/房间过滤。当用户明确要求"搜一下之前关于 X 的讨论"时触发。

### Wake-up（唤醒）

AI 启动时的初始化流程：加载 L0 + L1，约 170 token。让 AI 在用户开口之前就已经"认识你的世界"。CLI 命令：`mempalace wake-up`。

### Palace Protocol（宫殿协议）

嵌入在 `mempalace_status` 工具返回中的行为规则。指导 AI：启动时调用 status、回答过去事件前先查询、每次会话结束写日记、发现过时事实及时失效。将"存储"转化为真正的"记忆"。

---

## 3. AAAK 方言

AAAK 是一种有损缩写系统（不是无损压缩），用于将重复出现的实体名称和关系压缩为更少的 token。任何 LLM 都能直接阅读，无需解码器。

**当前状态**：实验性。小规模文本下不省 token（编码开销超过节省量）。大规模重复实体场景下有效。在 LongMemEval 上 AAAK 模式（84.2%）低于原文模式（96.6%）。

### Zettel（知识卡片）

AAAK 格式中的一条结构化记忆单元。名称借自 Zettelkasten（卡片盒笔记法）。包含：实体代码、主题关键词、关键引用、情感权重、情绪代码和标记。

格式示例：

```
ZID:KAI,ORI|auth.oauth.token|"spent 3 hours debugging refresh"|0.85|frust,relief|TECHNICAL
```

### ZID（Zettel ID）

知识卡片的短标识符，用于在 AAAK 编码文件中唯一标识一条记忆。

### Entity Code（实体代码）

3 个大写字母的缩写，代表一个人或实体。自动由名字前 3 个字符生成（`Alice → ALC`，`Jordan → JOR`），也可手动指定。在 AAAK 中替代反复出现的全名。

### AAAK Flags（标记）

标记一条 Zettel 的重要程度和类型：

| 标记 | 含义 |
|------|------|
| `ORIGIN` | 起源时刻 |
| `CORE` | 核心信念/身份支柱 |
| `SENSITIVE` | 需要小心处理 |
| `PIVOT` | 情感转折点 |
| `GENESIS` | 直接导致某事产生 |
| `DECISION` | 明确的决定或选择 |
| `TECHNICAL` | 技术架构或实现细节 |

### Emotional Arc（情感弧线）

记录一次会话的情感轨迹。格式：`ARC:grief->hope->peace`（从悲伤到希望到平静）。

### Emotional Weight（情感权重）

0.0 到 1.0 的浮点数，表示一条记忆的重要程度。L1 层生成时用这个分数筛选最重要的抽屉（默认阈值 0.85）。

---

## 4. 检索与搜索技术

### Semantic Search（语义搜索）

把查询文本转换为向量（embedding），在向量数据库中找距离最近的文档。MemPalace 默认的检索方式。不依赖关键词精确匹配，而是理解语义相似度。

**例子**：搜索 "为什么切换到 GraphQL" 能找到包含 "REST API 已经满足不了需求了" 的会话，虽然没有 "GraphQL" 这个词。

### Cosine Similarity / Cosine Distance（余弦相似度 / 余弦距离）

衡量两个向量方向接近程度的指标。

- **相似度** = 1 时完全相同，0 时完全无关
- **距离** = 1 - 相似度
- ChromaDB 返回距离值，距离越小越相关

### Embedding（嵌入/向量化）

将文本转换为固定长度数值向量的过程。MemPalace 使用 sentence-transformers 模型自动完成。向量捕捉文本的语义特征，使得语义相近的文本在向量空间中距离很近。

### Verbatim Storage（逐字原文存储）

MemPalace 的核心设计：**存原文，不摘要**。其他系统用 LLM 提取"用户偏好 Postgres"然后丢掉原文，丢失了"为什么"的上下文。MemPalace 保留每一个字，让搜索去找。这是 96.6% R@5 基线成绩的关键。

### Hybrid Scoring（混合评分）

在语义搜索之上叠加关键词匹配的两阶段检索：

1. 语义搜索取 top-50 候选
2. 计算查询关键词在每个文档中的重叠率，按重叠率缩小距离值

公式：`fused_dist = dist × (1.0 - hybrid_weight × overlap)`

经历了 v1 到 v5 的迭代，每一版针对具体失败模式做改进。

### Keyword Overlap（关键词重叠率）

去除停用词后，查询关键词在候选文档中出现的比例。例如查询有 5 个关键词，文档中出现 3 个，则重叠率为 0.6。用于混合评分的加权信号。

### Stop Words（停用词）

常见的无意义词（the, is, a, in 等），在关键词提取时被排除，确保只有有意义的内容词参与重叠计算。

### Temporal Boost（时序加权）

对日期接近问题时间参照点的会话给予距离缩减（最高 40%）。例如问"上个月做了什么"，上个月的会话会得到加权提升。Hybrid v2 引入。

### Quoted Phrase Boost（引用短语加权）

查询中出现引号括起来的精确短语时，包含该短语的会话距离缩减 60%。Hybrid v4 引入，解决了特定失败案例。

### Person Name Boost（人名加权）

从查询中提取大写专有名词（排除常见非人名词），包含该人名的会话距离缩减 40%。Hybrid v4 引入。

### Preference Extraction（偏好提取）

在索引（ingest）阶段用 16 条正则表达式扫描用户表达偏好的模式（如 "I usually prefer X"、"I always do Y"），生成合成文档（"User has mentioned: preference for X"）和原文一起存储。**弥合词汇鸿沟**：用户搜"数据库偏好"能匹配到原文中说的"我觉得 Postgres 更可靠"。

### LLM Rerank（LLM 重排序）

检索后的可选步骤：将 top-K 候选和问题一起发给 LLM（Claude Haiku 或 Sonnet），让 LLM 判断哪个文档最相关并重新排序。嵌入模型衡量的是语义相似度，而 LLM 能推理"哪个真正回答了问题"。成本约 $0.001/次（Haiku）。

### Two-Pass Retrieval（两遍检索）

Palace 模式中使用：

- **第一遍**：在推断出的走廊/房间内做精确搜索（高精度）
- **第二遍**：全库搜索，走廊/房间匹配作为加分项（防止分类错误导致遗漏）

### Fused Distance（融合距离）

经过所有混合评分调整后的最终距离值。综合了语义距离、关键词重叠、引用短语加权、人名加权等信号。

### top-K

检索返回的结果数量。原始模式通常取 top-5 或 top-10；混合模式先取 top-50 候选做重排序再裁剪。**注意**：检索池大小和最终报告的 top-K 不同，对基准测试完整性很重要。

### Session Granularity / Dialog Granularity（会话粒度 / 对话粒度）

构建检索文档的方式：

- **会话粒度**：一次完整对话（所有轮次合并）= 一个文档
- **对话粒度**：每个单独的对话轮次 = 一个文档

会话粒度在大多数基准测试上表现更好。

### Exchange Pair（交换对）

对话挖掘的默认分块单位。一个用户发言 + 紧随其后的 AI 回复 = 一个交换对 = 一个抽屉。

---

## 5. 评估指标

### Recall（召回率）

"正确答案是否出现在了检索结果中？"衡量的是能不能找到，不管排在第几。

### R@5 / Recall@5（Top-5 召回率）

正确会话出现在 top-5 检索结果中的问题比例。MemPalace 标杆成绩：

- 原文模式：96.6%
- Hybrid v4 + Haiku 重排序：100%

**LongMemEval 的标题指标。**

### R@10 / Recall@10（Top-10 召回率）

正确会话出现在 top-10 检索结果中的比例。通常高于 R@5。

### NDCG@10（归一化折损累积增益）

不仅关心"找没找到"，还关心"排在第几"。排名越靠前得分越高，使用对数折扣函数：排第 1 比排第 10 值更多。

- 公式：`NDCG = DCG / 理想DCG`
- `DCG = Σ(relevance_i / log₂(i + 2))`
- 取值 0~1，1 表示完美排序

MemPalace 原文模式 NDCG@10 = 0.889，Hybrid v4 + Haiku = 0.976。

### DCG（折损累积增益）

NDCG 的非归一化版本。衡量检索结果的实际排序质量。

---

## 6. 基准测试与方法论

### LongMemEval

AI 记忆领域的标准基准。500 个问题，每个问题需要从约 53 个对话会话（"haystack"）中找到正确的那个。六类问题：

| 类型 | 含义 |
|------|------|
| knowledge-update | 随时间变化的事实 |
| multi-session | 跨多个会话的信息 |
| temporal-reasoning | 需要时间推理 |
| single-session-user | 用户说过的内容 |
| single-session-preference | 间接表达的偏好 |
| single-session-assistant | AI 说过的内容 |

### LoCoMo

Snap Research 发布的多跳对话记忆基准。10 段长对话，每段 19-32 个会话，共 1986 个 QA 对。五个类别：

| 类别 | 难度 | 说明 |
|------|------|------|
| Single-hop | 中 | 单步事实检索 |
| Temporal | 中高 | 时间相关的事实 |
| Temporal-inference | 高 | 跨多个会话的时间推理 |
| Open-domain | 中 | 开放域问题 |
| Adversarial | 高 | 故意误导的问题（如问 A 的信息但相关内容在 B 的会话中） |

### ConvoMem

Salesforce 发布的大规模基准，75,000+ 个 QA 对，六个类别：用户事实、助手事实、变化中的事实、应弃权的问题、偏好、隐含关联。

### MemBench

ACL 2025 基准，8500 题，涵盖聚合、比较、知识更新、简单回忆、高层推理、推荐、后处理、条件推理、噪声干扰共 10 个类别。其中"噪声"类别对逐字存储最具挑战（43.4%）。

### Haystack（大海捞针）

LongMemEval 中每个问题对应的会话集合。在约 53 个会话中找到包含正确答案的那一个，类似于"大海捞针"。

### Held-Out（留出集）

为最终评估保留的、开发过程中**从未看过**的数据。MemPalace 将 LongMemEval 的 500 题分为：

- **50 题 dev（开发集）**：可以反复调试
- **450 题 held-out（留出集）**：只看一次，出最终分数

Hybrid v4 在留出集上的干净分数：**98.4% R@5**。

### Train/Test Contamination（训练/测试污染）

方法论问题：如果你看着测试题的错误答案来修改算法，那测试就不再客观了。MemPalace 项目在文档中**主动披露**了这个问题：Hybrid v4 的 3 个定向修复是针对具体失败题目开发的，属于"teaching to the test"。这是该项目创建 dev/held-out 分割的原因。

### Teaching to the Test（应试优化）

针对已知的测试失败案例来调优，而非从通用的失败模式中总结规律。在学术论文中是严重的方法论问题。MemPalace 的处理方式是：承认问题 + 创建干净分割。

### Diary Mode（日记模式）

基准测试模式之一。索引时用 Claude Haiku 读取每个会话并生成主题摘要，作为合成文档和原文一起存储。弥合词汇鸿沟（如搜"瑜伽课"能匹配到说"今天早上去了，教练练得很狠"的会话）。

### Palace Cache（宫殿缓存）

缓存 LLM 为 LoCoMo 会话分配的房间标签，避免重复调用 LLM。`palace_cache_locomo.json` 包含 272 条预计算的会话-房间映射。

### Coverage（覆盖率）

在日记模式中，已预计算摘要的会话占总会话的比例。65% 覆盖率时得分 98.2%，未覆盖的会话导致不对称降低了分数。

---

## 7. 技术栈

### ChromaDB

MemPalace 的向量数据库后端。所有抽屉作为带嵌入向量的文档存储在 ChromaDB 中。两种客户端模式：

- **PersistentClient**：写入磁盘，用于生产环境
- **EphemeralClient**：纯内存，用于基准测试（更快，避免 SQLite 累积问题）

### Vector Database（向量数据库）

专门存储和检索高维向量（即文本嵌入）的数据库。核心能力是"给一个向量，快速找到最相似的 K 个向量"。ChromaDB 是众多向量数据库之一，其他常见的有 Pinecone、Weaviate、Milvus。

### MCP（Model Context Protocol，模型上下文协议）

Anthropic 发布的协议，用于让 AI 工具（Claude Code、Cursor 等）调用外部工具。MemPalace 的 MCP Server 通过 stdin/stdout 传输 JSON-RPC 消息，暴露 19 个工具。

### all-MiniLM-L6-v2

ChromaDB 默认的嵌入模型。产出 384 维向量。96.6% 基线成绩就是用这个模型取得的。轻量、快速，但精度不如更大的模型。

### bge-large（BAAI/bge-large-en-v1.5）

更高质量的嵌入模型，1024 维。通过 fastembed 加载。在 LoCoMo top-10 上达到 92.4% R@10（vs all-MiniLM 的 88.9%），但模型文件约 1.3GB。

### fastembed

本地运行嵌入模型的 Python 库。用于加载 bge-large 等替代模型。可选依赖，未安装时回退到 ChromaDB 默认模型。

### Sentence Transformers

生成句子级嵌入向量的模型家族。all-MiniLM-L6-v2 是其中之一。将任意长度的文本映射为固定维度的向量。

### SQLite / WAL 模式

知识图谱的存储后端。WAL（Write-Ahead Logging，预写日志）模式提升并发读取性能。不需要额外的数据库服务器。

### tiktoken

OpenAI 的分词器。用于准确计算 token 数量。项目早期用 `len(text)//3` 的粗略估算导致夸大了 AAAK 压缩比，后来切换到 tiktoken 得到准确计数。

### Token（词元）

LLM 输入/输出的计量单位。大约 1 token = 0.75 个英文单词 = 1-2 个中文字。MemPalace 以 token 衡量记忆效率：唤醒 170 token，5 次搜索 ~13,500 token，而把 6 个月对话全部粘贴需要 1950 万 token。

### Context Window（上下文窗口）

LLM 单次能处理的最大 token 数。MemPalace 的设计目标是尽量少占用上下文窗口：唤醒只用 170 token，按需搜索时才加载更多。

### JSON-RPC

MCP 使用的远程过程调用协议。请求和响应是以换行分隔的 JSON 对象，通过 stdin/stdout 传输。

---

## 8. 数据处理流程

### Mining（挖掘）

数据摄入过程。`mempalace mine <dir>` 扫描目录，分块，存储为抽屉。三种模式：

| 模式 | 命令 | 处理对象 |
|------|------|---------|
| projects | `mempalace mine <dir>` | 代码和文档 |
| convos | `mempalace mine <dir> --mode convos` | 对话导出文件 |
| general | `--mode convos --extract general` | 自动分类到决策/偏好/里程碑/问题/情感 |

### Normalization（标准化）

将各种聊天导出格式转换为 MemPalace 统一的转录格式（以 `>` 引用标记区分发言者）。支持的格式：

- Claude.ai JSON
- ChatGPT `conversations.json`
- Claude Code JSONL
- OpenAI Codex JSONL
- Slack JSON 导出
- 纯文本

### Chunking（分块）

将长文本切分为合适大小的块，每块成为一个抽屉。主要策略：

- **Exchange Pair**（交换对）：一个用户发言 + 一个 AI 回复 = 一个块（默认策略）
- **Paragraph**（段落）：按双换行拆分（无交换对标记时的后备策略）
- **Line Group**（行组）：每 25 行一组（无段落分隔时的最终后备）

### Split（拆分）

预处理命令。当聊天导出工具把多次对话拼成一个大文件时，`mempalace split` 把它拆成单次会话文件，再进行挖掘。

### General Extractor（通用提取器）

不依赖 LLM 的关键词/模式启发式分类器。将对话块分为 5 类记忆：

| 类型 | 检测模式 |
|------|---------|
| decision（决策） | "decided", "chose", "tradeoff" |
| preference（偏好） | "always", "prefer", "never", "hate" |
| milestone（里程碑） | "it worked", "shipped", "deployed" |
| problem（问题） | "bug", "crash", "workaround" |
| emotional（情感） | 情感表达、脆弱时刻 |

### Room Detection（房间检测）

自动给对话内容打标签，确定归入哪个房间。对内容按主题关键词字典打分，匹配最高分的主题：`technical`、`architecture`、`planning`、`decisions`、`problems`、`general`。

### Entity Detection（实体检测）

自动识别文本中的人名和项目名。`entity_detector.py` 扫描候选词，`entity_registry.py` 通过上下文模式判断歧义词（如"May"是人名还是月份）。

### Entity Registry（实体注册表）

持久化的 JSON 文件（`~/.mempalace/entity_registry.json`），存储已知的人和项目，包括置信度分数、来源（onboarding/learned/wiki）、别名和歧义标记。

---

## 9. 知识图谱

### Knowledge Graph / KG（知识图谱）

基于 SQLite 的时序实体关系图。存储带时间窗口的三元组事实。类似 Zep 的 Graphiti，但完全本地、免费。

### Triple（三元组）

知识图谱的原子事实单位：**主语 → 谓语 → 宾语**。

```python
kg.add_triple("Kai", "works_on", "Orion", valid_from="2025-06-01")
#              主语      谓语        宾语        生效时间
```

### Temporal Validity（时间有效性）

每个三元组有一个时间窗口（`valid_from` 到 `valid_to`）。`valid_to=NULL` 表示当前仍然成立。查询可以指定 `as_of=日期` 只看该时间点成立的事实。

### Invalidate（失效）

标记一个事实不再成立。设置 `valid_to` 字段。例如 Kai 不再参与 Orion 项目时：

```python
kg.invalidate("Kai", "works_on", "Orion", ended="2026-03-01")
```

历史查询仍能看到这条记录，但当前查询不会返回它。

### Timeline（时间线）

按 `valid_from` 时间顺序列出某个实体的所有事实，形成该实体的完整故事。

### Contradiction Detection / Fact Checker（矛盾检测 / 事实核查）

独立工具 `fact_checker.py`，用于检查新断言是否与已知事实矛盾。能捕捉归因错误（"Soren 完成了认证迁移" vs 记录中 Maya 负责）、过时日期、错误任期等。目前尚未接入自动化流程。

---

## 10. 竞品系统

### Mem0

商业 AI 记忆系统。用 LLM 从对话中提取事实。**问题**：LLM 提取错了就永远丢失了。ConvoMem 得分 30-45%，不到 MemPalace 的一半。收费 $19-249/月。Mem0 是 MemPalace "逐字存储优于 LLM 提取"论点的主要反面教材。

### Mastra

用 GPT-5-mini 观察对话并提取记忆的系统。LongMemEval 得分 94.87%，在 MemPalace 之前是最高的已验证生产环境分数。

### Supermemory / ASMR

两个层级：生产版（~85% LongMemEval）和实验性 ASMR（Agentic Search and Memory Recall，~99%）。ASMR 用 LLM 做多轮代理式搜索。

### Zep / Graphiti

商业图记忆系统。使用 Neo4j 图数据库和实体提取。$25/月起。MemPalace 的知识图谱是其本地免费替代。

### Letta / MemGPT

操作系统风格的 LLM 上下文管理框架。MemGPT 是学术名称，Letta 是产品名称。收费 $20-200/月。MemPalace 的翼+日记方式是其本地替代。

### Hindsight

时间感知向量检索系统。LongMemEval 得分 91.4%，由弗吉尼亚理工验证。

### OpenViking

字节跳动的文件系统范式上下文数据库。在 LoCoMo10 上测试（52% 任务完成率，91% token 节省）。需要 Go + Rust + C++ + VLM API，基础设施负担最重。

### BM25

传统的稀疏关键词检索基线。不使用嵌入向量，纯靠词频匹配。LongMemEval 约 70%。常作为"最低基线"参考。

### Contriever / Stella

学术界的稠密检索基线模型。LongMemEval 分别约 78% 和 85%。

---

## 附：核心理念总结

MemPalace 的核心洞察可以用一句话概括：

> **别让 AI 决定什么值得记住。全部存下来，让搜索去找。**

其他系统用 LLM 提取"用户偏好 Postgres"然后扔掉原文 —— 丢失了"为什么"、"考虑过哪些替代方案"、"权衡了什么"。MemPalace 把每个字都留着，用嵌入向量做语义搜索。

96.6% 的成绩不是靠复杂的 AI 管道，而是靠**做最简单的事并且做对**：存原文 + 好的嵌入模型 + 结构化的组织。
