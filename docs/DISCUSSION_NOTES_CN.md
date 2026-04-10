# MemPalace 讨论笔记

基于项目分析过程中的讨论整理，供后续参考。

---

## 目录

1. [Agent 如何判断用 MemPalace 还是 AI 自身知识](#1-agent-如何判断用-mempalace-还是-ai-自身知识)
2. [MemPalace 与传统 RAG 的区别和优势](#2-mempalace-与传统-rag-的区别和优势)
3. [项目级私有"模型"的可行性与边界](#3-项目级私有模型的可行性与边界)

---

## 1. Agent 如何判断用 MemPalace 还是 AI 自身知识

**短答案：靠 prompt 规则引导，不是靠硬编码路由。**

### 机制拆解

整个判断链分三层：

**第 1 层：Palace Protocol（协议指令）**

当 AI 第一次调用 `mempalace_status` 时，返回中嵌入了一段行为协议：

```
1. ON WAKE-UP: Call mempalace_status to load palace overview
2. BEFORE RESPONDING about any person, project, or past event:
   call mempalace_search FIRST. Never guess — verify.
3. IF UNSURE about a fact: say "let me check" and query the palace.
   Wrong is worse than slow.
4. AFTER EACH SESSION: call mempalace_diary_write to record what happened.
5. WHEN FACTS CHANGE: call mempalace_kg_invalidate + mempalace_kg_add.
```

核心 —— **通过返回的文本指令告诉 AI "涉及人、项目、历史事件时，先查 palace 再回答"**。

**第 2 层：MCP 工具描述**

AI 能看到 19 个工具的描述，例如：

- `mempalace_search` — "Semantic search, optional wing/room filter"
- `mempalace_kg_query` — "Entity relationships with time filtering"

Claude 的 tool use 机制会根据用户问题和工具描述，自主判断是否需要调用工具。问"上个月为什么切了 GraphQL"时，Claude 看到有 `mempalace_search` 可用，就会主动调用。

**第 3 层：Hook 自动触发**

插件注册了两个 Hook：
- **Stop Hook**：每 15 条消息自动拦截，提示 AI 保存记忆
- **PreCompact Hook**：上下文压缩前自动拦截，紧急保存

这些是被动触发的，不需要 AI 主动判断。

### 实际判断逻辑（AI 视角）

| 用户问题类型 | AI 的判断 | 用什么 |
|-------------|----------|--------|
| "Python 的 list 和 tuple 区别" | 通用知识，palace 里不会有 | AI 自身知识 |
| "我们上个月为什么换了 GraphQL" | 涉及"我们"+"过去事件" → 触发协议第 2 条 | `mempalace_search` |
| "Kai 现在负责什么项目" | 涉及具体人名 → 触发协议第 2、3 条 | `mempalace_kg_query` |
| "帮我写个排序算法" | 编码任务，无历史依赖 | AI 自身能力 |
| "之前讨论的认证方案是哪个" | "之前讨论" → 明确的历史回忆 | `mempalace_search` |

### 本质

**没有硬路由逻辑。** 不是 if-else 判断，而是：

1. MCP 给了 AI 一套工具（能力）
2. Palace Protocol 给了 AI 一套行为规范（什么时候该用）
3. Claude 的 tool use 推理能力负责最终决策

跟给新同事说"不确定的事先查文档别瞎答"是一个道理，只不过这个"规矩"是通过 MCP 工具的返回值注入给 AI 的。

---

## 2. MemPalace 与传统 RAG 的区别和优势

### 一句话区分

> **RAG 是"搜了就答"，MemPalace 是"住在记忆里"。**

RAG 解决的是"单次查询增强"，MemPalace 解决的是"跨会话长期记忆"。它们不是替代关系，MemPalace 的底层检索本身就是 RAG，但在 RAG 之上加了一整套记忆系统。

### 架构对比

| 维度 | 传统 RAG | MemPalace |
|------|---------|-----------|
| **存储** | 文档切块 → 向量库，扁平结构 | 宫殿分层：Wing → Room → Drawer，有结构 |
| **检索** | 每次查询都是全库语义搜索 | 先定位翼/房间再搜，缩小范围后精准命中 |
| **上下文** | 无状态，每次从零开始 | 4 层记忆栈，启动就带 170 token 背景知识 |
| **知识管理** | 没有，只存只搜 | 知识图谱 + 时间有效性 + 矛盾检测 |
| **记忆行为** | 被动（你问它才查） | 主动（协议规定"先查再答""会后写日记"） |
| **跨会话** | 不支持（会话结束就忘） | 核心能力（存的就是跨会话记忆） |

### 具体优势

#### 2.1 结构化检索 vs 扁平搜索

传统 RAG：
```
用户问 "认证方案" → 在 10 万个 chunk 里语义搜索 → 返回 top-5
```

MemPalace：
```
用户问 "认证方案" → 定位 wing_myapp → 定位 room_auth → 在几百个 chunk 里搜索
```

项目自己的基准测试显示：

```
全库搜索:          60.9%  R@10
限定翼:            73.1%  (+12%)
限定翼+走廊:       84.8%  (+24%)
限定翼+房间:       94.8%  (+34%)
```

**结构本身就是一个 34% 的检索提升。** 传统 RAG 没有这层组织。

#### 2.2 常驻记忆 vs 无状态

传统 RAG 每次对话从零开始，不知道你是谁、做什么项目。

MemPalace 的 4 层栈：

```
L0 (永远加载):  "我是张三的助手，主要做 myapp 项目"     ~50 token
L1 (永远加载):  "团队有 Kai/Maya/Priya，上月迁移了认证"   ~120 token
L2 (按需):      话题涉及 auth 时自动加载相关房间
L3 (深搜):      明确问"之前讨论过什么"时全库搜索
```

AI 一醒来就知道你的世界，不需要每次重新建立上下文。

#### 2.3 原文保留 vs 信息丢失

很多 RAG + 记忆系统的做法：

```
对话 → LLM 提取摘要 "用户偏好 Postgres" → 存摘要 → 丢弃原文
```

问题：丢掉了"为什么选 Postgres"、"考虑过什么替代方案"、"当时的权衡是什么"。

MemPalace：

```
对话 → 原文逐字存储 → 语义搜索找到原文
```

96.6% 的基线成绩就是这么来的 —— 不丢信息，让搜索去找。

#### 2.4 时序知识图谱 vs 无时间概念

传统 RAG 没有时间维度。你问"Kai 现在负责什么"，它可能返回半年前的过期信息。

MemPalace 的 KG 有时间窗口：

```python
# 2025年6月的事实
kg.add_triple("Kai", "works_on", "Orion", valid_from="2025-06-01")
# 2026年3月失效
kg.invalidate("Kai", "works_on", "Orion", ended="2026-03-01")

# 查"现在"→ 不返回 Orion
# 查"2025年8月"→ 返回 Orion
```

#### 2.5 主动行为 vs 被动响应

RAG 的模式：

```
用户问了 → 检索 → 拼上下文 → 回答
（不问就不查，没有记忆行为）
```

MemPalace 通过 Palace Protocol 注入行为规范：

```
- 涉及人/项目/历史 → 先查再答（即使用户没明确说"帮我搜"）
- 每次会话结束 → 自动写日记
- 事实变化 → 主动更新知识图谱
- 上下文要压缩了 → Hook 紧急保存
```

#### 2.6 跨翼关联 vs 孤立检索

MemPalace 的 tunnel 自动连接不同领域的相同主题：

```
wing_kai       / room_auth  → "Kai 调试了 OAuth"
wing_driftwood / room_auth  → "团队决定用 Clerk"
wing_priya     / room_auth  → "Priya 批准了方案"
```

搜"认证方案"，三个翼的相关信息通过 tunnel 一起返回。传统 RAG 不知道这三条信息有内在关联。

### 它们的关系

```
┌─────────────────────────────────────────────┐
│              MemPalace                       │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │  Palace Protocol (行为规范)          │    │
│  │  "先查再答、会后写日记、事实过期更新"    │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ┌──────────────┐  ┌───────────────────┐    │
│  │  记忆层栈     │  │  知识图谱 (KG)     │    │
│  │  L0/L1/L2/L3 │  │  时序三元组+失效   │    │
│  └──────────────┘  └───────────────────┘    │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │  结构化组织                          │    │
│  │  Wing → Hall → Room → Tunnel        │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │  RAG (底层检索)                      │    │  ← 传统 RAG 只有这一层
│  │  ChromaDB 向量搜索 + 语义匹配        │    │
│  └─────────────────────────────────────┘    │
│                                             │
└─────────────────────────────────────────────┘
```

**MemPalace 不是 RAG 的替代品，是 RAG 的上层建筑。**

---

## 3. 项目级私有"模型"的可行性与边界

### 核心结论

MemPalace 可以建立项目级别的私有知识库（"私有模型"），**对文本类内容非常有效，但无法处理图片、3D 模型、音频等二进制文件**。

### 能处理的内容（文本类）

MemPalace 支持的文件扩展名：
`.txt .md .py .js .ts .jsx .tsx .json .yaml .yml .html .css .java .go .rs .rb .sh .csv .sql .toml`

以游戏项目为例：

| 游戏开发内容 | MemPalace 能力 |
|-------------|---------------|
| 需求文档 / GDD | 直接 mine，按 room 分（gameplay、level-design、monetization） |
| Bug 记录 | 对话导出 mine，或通过 MCP 手动存 |
| 代码 | .py .ts .cs .java .go 等 21 种文本格式 |
| 配置文件 | .json .yaml .toml .csv .sql |
| 会议纪要 / Slack 讨论 | 对话模式 mine |
| 决策记录 | "为什么用 UE5 不用 Unity" → 知识图谱 |
| 技术方案 | .md 文档直接 mine |

### 无法处理的内容（二进制/多媒体）

| 内容 | 为什么不行 |
|------|-----------|
| 概念原画 / UI 设计稿 (.png .psd .fig) | ChromaDB 只存文本嵌入，无法处理图像 |
| 3D 模型 (.fbx .blend) | 二进制文件，无法文本化 |
| 音频 (.wav .mp3) | 同上 |
| 视频 (.mp4) | 同上 |
| Shader / 材质 (部分二进制) | 取决于格式，纯文本的 .shader 可以 |

### 游戏项目实际落地方案

#### 文本部分：MemPalace 直接覆盖

```bash
# 按游戏开发维度组织
mempalace init ~/game/design       # 策划文档
mempalace init ~/game/client       # 前端代码
mempalace init ~/game/server       # 后端代码
mempalace init ~/game/tools        # 工具链

# 统一 wing
mempalace mine ~/game/design  --wing mygame
mempalace mine ~/game/client  --wing mygame
mempalace mine ~/game/server  --wing mygame
mempalace mine ~/game/tools   --wing mygame

# 对话记录（策划讨论、Bug 分析、技术方案）
mempalace mine ~/game/chats/  --mode convos --wing mygame

# 知识图谱记录关键决策（AI 自动调用）：
#   kg_add("team", "chose", "UE5", valid_from="2025-01-15")
#   kg_add("auth-system", "migrated_to", "EOS", valid_from="2025-06-01")
```

#### 非文本部分：存描述不存文件

**方式一：手动给素材写文本描述存入 MemPalace**

```python
mempalace_add_drawer(
  wing="mygame",
  room="art-assets",
  content="主角概念原画 v3 - 赛博朋克风，双刀武器，霓虹配色。路径: assets/character/hero_v3.psd。美术: 张三，2025-03-15 定稿。"
)
```

搜索"主角设计"时能找到这条描述 + 文件路径。

**方式二：结合多模态工具生成描述再存入**

```python
# 用 Claude Vision 或其他多模态模型描述图片
description = claude.describe_image("assets/character/hero_v3.png")
# → "赛博朋克风格的双刀角色，霓虹色调..."

# 把描述存入 MemPalace
mempalace_add_drawer(wing="mygame", room="art-assets", content=description)
```

**方式三：对接专业资产管理系统**

| 内容类型 | 推荐方案 | 和 MemPalace 的关系 |
|---------|---------|-------------------|
| 图片/原画 | Perforce + ShotGrid / Notion | MemPalace 存文字描述和决策，指向实际文件路径 |
| 3D 模型 | Perforce / Git LFS | 同上 |
| 音频 | Wwise + 版本管理 | 同上 |
| Bug 追踪 | Jira / Linear | 导出讨论 → mine 到 MemPalace |
| 任务管理 | Jira / Notion | 同上 |

### 整体架构

```
┌──────────────────────────────────────────────────┐
│              游戏项目"私有模型"                     │
│                                                  │
│  ┌────────────────────────────────────────┐      │
│  │  MemPalace（文本记忆层）                 │      │
│  │  需求文档 + 代码 + 对话 + 决策 + Bug     │      │
│  │  → 语义搜索 + 知识图谱 + 时间线          │      │
│  └────────────────────────────────────────┘      │
│                    ↕ 文本描述/路径引用             │
│  ┌────────────────────────────────────────┐      │
│  │  资产管理系统（非文本层）                  │      │
│  │  原画 + 模型 + 音频 + 视频               │      │
│  │  → Perforce / Git LFS / ShotGrid       │      │
│  └────────────────────────────────────────┘      │
└──────────────────────────────────────────────────┘
```

MemPalace 做的是**文本知识的长期记忆**，相当于项目的"大脑"。图片、模型这些二进制素材需要专业资产管理工具做"仓库"，MemPalace 通过存储描述和路径引用来**桥接**两者。
