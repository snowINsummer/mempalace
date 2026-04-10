# MemPalace 使用指南

---

## 一、安装

```bash
pip install mempalace
```

依赖很少：`chromadb >= 0.5.0` + `pyyaml >= 6.0`。无需 API key，无需联网（安装后）。

---

## 二、初始化

```bash
mempalace init ~/projects/myapp
```

这会：
1. 扫描目录，自动检测人名和项目名
2. 根据文件夹结构推断房间（backend、docs、tests 等）
3. 生成 `myapp/mempalace.yaml`（翼+房间配置，挖掘时必须有这个文件）
4. 生成 `~/.mempalace/config.json`（全局配置）

你还可以手动创建身份文件（L0 层）：
```bash
echo "我是张三的 AI 助手，主要协助 myapp 项目开发..." > ~/.mempalace/identity.txt
```

---

## 三、挖掘数据（Mining）

**3 种模式：**

```bash
# 1. 挖掘项目文件（代码、文档）
mempalace mine ~/projects/myapp

# 2. 挖掘对话记录（Claude、ChatGPT、Slack 导出）
mempalace mine ~/chats/ --mode convos

# 3. 对话 + 自动分类（分为决策/偏好/里程碑/问题/情感）
mempalace mine ~/chats/ --mode convos --extract general
```

**常用选项：**

| 选项 | 说明 |
|------|------|
| `--wing NAME` | 指定翼名（默认用目录名） |
| `--dry-run` | 预览，不实际存储 |
| `--limit N` | 限制处理文件数 |
| `--no-gitignore` | 不跟随 .gitignore 排除规则 |

**支持的对话格式**（自动识别）：
- Claude.ai JSON 导出
- ChatGPT `conversations.json`
- Claude Code JSONL
- OpenAI Codex JSONL
- Slack JSON 导出
- 纯文本（`>` 标记区分发言者）

**大文件先拆分：**
```bash
mempalace split ~/chats/ --dry-run    # 预览
mempalace split ~/chats/              # 拆成单次会话文件
```

---

## 四、搜索

```bash
# 搜索所有记忆
mempalace search "为什么切换到 GraphQL"

# 限定项目
mempalace search "数据库决策" --wing myapp

# 限定主题
mempalace search "认证流程" --room backend

# 返回更多结果
mempalace search "rate limiting" --results 10
```

搜索是**语义搜索**，不需要精确匹配关键词。

---

## 五、查看状态

```bash
mempalace status          # 宫殿概览：多少翼、多少房间、多少抽屉
mempalace wake-up         # 查看 AI 唤醒时会看到什么（L0+L1，约 170 token）
mempalace wake-up --wing myapp  # 某个项目的唤醒上下文
```

---

## 六、接入 AI 工具（日常使用核心）

初始化和挖掘是一次性的，日常使用靠 AI 工具自动调用。

**方式一：Claude Code 插件（推荐）**

```bash
claude plugin marketplace add milla-jovovich/mempalace
claude plugin install --scope user mempalace
```

重启 Claude Code，输入 `/skills` 验证。

**方式二：MCP 手动接入（Claude Code / Cursor / Gemini）**

```bash
claude mcp add mempalace -- python -m mempalace.mcp_server
```

接入后 AI 自动获得 19 个工具，你问"上个月关于认证的讨论是什么"，AI 会自动调用 `mempalace_search`。

**方式三：本地模型（Llama、Mistral 等）**

```bash
# 导出唤醒上下文，粘贴到系统提示
mempalace wake-up > context.txt

# 或按需搜索，结果注入提示
mempalace search "auth decisions" > results.txt
```

---

## 七、对话记忆：自动保存 vs 手动归档

MemPalace 能提炼 Claude、ChatGPT、Slack 等对话内容。有两种方式，推荐**同时使用**。

### 方式一：Hook 自动保存（日常兜底）

配置后无需手动操作，AI 在对话过程中自动保存关键信息。

编辑 `.claude/settings.local.json`：
```json
{
  "hooks": {
    "Stop": [{
      "matcher": "*",
      "hooks": [{"type": "command", "command": "/path/to/hooks/mempal_save_hook.sh", "timeout": 30}]
    }],
    "PreCompact": [{
      "hooks": [{"type": "command", "command": "/path/to/hooks/mempal_precompact_hook.sh", "timeout": 30}]
    }]
  }
}
```

- **Save Hook**：每 15 条消息自动提醒 AI 保存记忆
- **PreCompact Hook**：上下文压缩前紧急保存
- AI 通过 MCP 工具（`mempalace_add_drawer`）直接写入 palace
- 存的是 **AI 判断的关键信息**，不是完整对话原文，可能遗漏

### 方式二：手动 mine 对话导出（定期全量归档）

导出对话文件后手动执行，存的是**完整对话原文**，一字不漏。

```bash
# Claude.ai → 网页导出 JSON → 下载到本地
mempalace mine ~/Downloads/claude-export/ --mode convos --wing myproject

# Claude Code → 会话记录默认在 ~/.claude/
mempalace mine ~/.claude/projects/ --mode convos --wing myproject

# ChatGPT → 导出 conversations.json
mempalace mine ~/Downloads/chatgpt-export/ --mode convos --wing myproject

# Slack → 导出 JSON
mempalace mine ~/Downloads/slack-export/ --mode convos --wing myproject
```

格式自动识别（`normalize.py`），无需手动转换。

### 两者对比

| | Hook 自动保存 | 手动 mine 对话导出 |
|--|-------------|------------------|
| 触发 | 自动，无需操作 | 手动执行命令 |
| 存什么 | AI 判断的关键信息 | 完整对话原文 |
| 覆盖面 | 可能遗漏 | 全部保留 |
| 频率 | 实时（每 15 条消息） | 按需（建议每周/每迭代一次） |
| 推荐场景 | 日常兜底 | 定期归档 |

### 推荐做法

**两个都用**：Hook 日常自动兜底，定期手动 mine 一次完整对话导出做全量归档。

---

## 八、知识图谱（Python API）

```python
from mempalace.knowledge_graph import KnowledgeGraph

kg = KnowledgeGraph()

# 添加事实
kg.add_triple("Kai", "works_on", "Orion", valid_from="2025-06-01")

# 查询
kg.query_entity("Kai")                        # Kai 的所有关系
kg.query_entity("Maya", as_of="2026-01-20")   # Maya 在某个时间点的状态
kg.timeline("Orion")                           # Orion 项目的时间线

# 事实过期
kg.invalidate("Kai", "works_on", "Orion", ended="2026-03-01")
```

---

## 九、AAAK 压缩（实验性）

```bash
mempalace compress --wing myapp --dry-run   # 预览
mempalace compress --wing myapp             # 执行有损压缩
```

压缩结果存在单独的集合 `mempalace_compressed` 中，原文不受影响。当前阶段小规模不省 token，大规模重复实体场景才有效。

---

## 十、维护

```bash
# 宫殿损坏时修复
mempalace repair
```

---

## 典型工作流总结

```
第一次:  pip install → init → mine → 接入 AI 工具
日常:    正常和 AI 对话，AI 自动查询/保存记忆
定期:    mine 新的对话导出、新的项目文件
```

**所有数据存储位置：**

```
~/.mempalace/
  palace/                      # ChromaDB 向量数据库
  knowledge_graph.sqlite3      # 知识图谱
  config.json                  # 全局配置
  identity.txt                 # L0 身份文件（你手写）
  people_map.json              # 人名映射

<项目目录>/
  mempalace.yaml               # 翼+房间配置（mine 时必须有）
```
