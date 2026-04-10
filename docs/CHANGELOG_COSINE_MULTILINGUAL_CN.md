# 源码修改记录：Cosine 距离 + 多语言 Embedding 支持

---

## 修改背景

使用 MemPalace mine 中文项目后，搜索返回的 Match 分数极低甚至为负数。

**根因分析：**

1. **距离度量问题**：ChromaDB 默认使用 L2（欧氏距离），代码中 `similarity = 1 - dist` 在 L2 距离 > 1 时会变成负数
2. **Embedding 模型问题**：默认的 `all-MiniLM-L6-v2` 只支持英文，中文内容生成的向量质量极差，导致语义搜索完全不准

---

## 修改内容

### 1. `mempalace/config.py` — 新增共享 Embedding 函数

```python
from chromadb.utils.embedding_functions import SentenceTransformerEmbeddingFunction

DEFAULT_EMBEDDING_MODEL = "paraphrase-multilingual-MiniLM-L12-v2"

def get_embedding_function():
    """返回多语言 embedding 函数（单例缓存）"""
```

- 模型：`paraphrase-multilingual-MiniLM-L12-v2`（支持 50+ 语言，包括中文）
- 单例模式，避免重复加载模型

### 2. 所有 `create_collection` 调用 — 添加 Cosine 距离

```python
client.create_collection(
    "mempalace_drawers",
    metadata={"hnsw:space": "cosine"},  # 新增
    embedding_function=ef,               # 新增
)
```

### 3. 所有 `get_collection` 调用 — 传入 Embedding 函数

```python
client.get_collection("mempalace_drawers", embedding_function=ef)
```

---

## 修改的文件清单

| 文件 | 修改点 | 说明 |
|------|--------|------|
| `mempalace/config.py` | 新增 `get_embedding_function()` | 共享 embedding 函数工厂 |
| `mempalace/miner.py` | `get_collection()` | 项目文件挖掘的 collection 操作 |
| `mempalace/convo_miner.py` | `get_collection()` | 对话挖掘的 collection 操作 |
| `mempalace/searcher.py` | 2 处 `get_collection` | CLI 搜索 + MCP 搜索 |
| `mempalace/mcp_server.py` | `_get_collection()` | MCP 服务的 collection 缓存 |
| `mempalace/layers.py` | 5 处 `get_collection` | 4 层记忆栈的所有读取点 |
| `mempalace/cli.py` | repair + compress | 修复命令 + 压缩命令 |
| `mempalace/palace_graph.py` | `_get_collection()` | 宫殿导航图 |

共修改 **8 个文件**，涉及 **约 15 处** collection 调用。

---

## 操作步骤

修改源码后，需要按以下顺序执行：

```bash
# 1. 卸载旧版本
pip uninstall mempalace -y

# 2. 安装 sentence-transformers（多语言模型依赖）
pip install sentence-transformers

# 3. 以开发模式重新安装（-e 表示 editable，修改源码即时生效）
pip install -e .

# 4. 删除旧的 palace 缓存（旧数据用 L2 + 英文模型生成，必须重建）
rm -rf ~/.mempalace/palace

# 5. 验证 CLI 正常
mempalace --help

# 6. 重新 init + mine 项目
mempalace init ~/projects/myapp
mempalace mine ~/projects/myapp

# 7. 测试搜索（Match 应在 0.6~1.0 之间）
mempalace search "你的关键词"
```

---

## 预期效果

| 指标 | 修改前 | 修改后 |
|------|--------|--------|
| Match 分数范围 | -0.5 ~ 0.3（大量负数） | 0.6 ~ 1.0 |
| 中文搜索准确度 | 极差（英文模型） | 正常（多语言模型） |
| 距离度量 | L2（欧氏距离） | Cosine（余弦相似度） |
| Embedding 模型 | all-MiniLM-L6-v2 | paraphrase-multilingual-MiniLM-L12-v2 |

---

## 注意事项

- 删除 `~/.mempalace/palace` 后**所有已挖掘数据会丢失**，需要重新 mine
- 首次运行 mine 时会自动下载多语言模型（约 500MB），需联网
- 模型下载后会缓存在 `~/.cache/huggingface/`，后续使用无需再下载
- 知识图谱数据（`~/.mempalace/knowledge_graph.sqlite3`）不受影响，无需重建
