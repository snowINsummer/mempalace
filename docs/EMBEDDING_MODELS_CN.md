# 可用的多语言 Embedding 模型列表

修改位置：`mempalace/config.py` 中的 `DEFAULT_EMBEDDING_MODEL`

```python
DEFAULT_EMBEDDING_MODEL = "paraphrase-multilingual-mpnet-base-v2"  # ← 改这里
```

修改后需要：
```bash
rm -rf ~/.mempalace/palace   # 删旧缓存（新旧模型维度不同，不兼容）
mempalace mine <dir>         # 重新挖掘
```

---

## Sentence-Transformers 多语言模型（全部免费、本地运行）

### 推荐：通用多语言

| 模型 | 参数量 | 维度 | 大小 | 中文质量 | 说明 |
|------|--------|------|------|----------|------|
| **paraphrase-multilingual-mpnet-base-v2** | 278M | 768 | ~1.1GB | **最佳** | **当前使用，推荐** |
| paraphrase-multilingual-MiniLM-L12-v2 | 118M | 384 | ~500MB | 良好 | 轻量替代，速度快 |
| distiluse-base-multilingual-cased-v2 | 135M | 512 | ~540MB | 一般 | 老模型，兼容性好 |

### 专注中文（如果项目全中文）

| 模型 | 参数量 | 维度 | 大小 | 中文质量 | 说明 |
|------|--------|------|------|----------|------|
| shibing624/text2vec-base-chinese | 102M | 768 | ~400MB | **极佳** | 中文专用，纯中文项目首选 |
| DMetaSoul/sbert-chinese-general-v2 | 102M | 768 | ~400MB | 极佳 | 中文通用语义 |
| moka-ai/m3e-base | 102M | 768 | ~400MB | 极佳 | 中文检索优化 |

> 注意：中文专用模型英文能力弱，中英混合项目用多语言模型更稳。

### 新一代高性能（模型更大、效果更好）

| 模型 | 参数量 | 维度 | 大小 | 中文质量 | 说明 |
|------|--------|------|------|----------|------|
| intfloat/multilingual-e5-large | 560M | 1024 | ~2.2GB | **顶级** | 查询需加前缀 `query:` |
| BAAI/bge-m3 | 568M | 1024 | ~2.3GB | **顶级** | 支持稠密+稀疏+多向量 |
| BAAI/bge-large-zh-v1.5 | 326M | 1024 | ~1.3GB | **顶级** | 中文 SOTA，查询加前缀 `为这个句子生成表示以用于检索中文文档：` |

> 注意：e5 和 bge 系列需要给查询文本加前缀才能发挥最佳效果，直接用需要改 searcher.py 的查询逻辑。当前架构直接替换模型名即可使用，但效果可能未达最佳。

### 仅英文（参考）

| 模型 | 参数量 | 维度 | 说明 |
|------|--------|------|------|
| all-MiniLM-L6-v2 | 22M | 384 | MemPalace 原默认，不支持中文 |
| all-mpnet-base-v2 | 109M | 768 | 英文最佳，不支持中文 |

---

## 选型建议

| 场景 | 推荐模型 |
|------|---------|
| 中英混合项目（大多数情况） | **paraphrase-multilingual-mpnet-base-v2**（当前） |
| 纯中文项目，追求中文精度 | shibing624/text2vec-base-chinese |
| 不在乎大小，追求极致效果 | intfloat/multilingual-e5-large（需改代码加前缀） |
| 资源受限（如 CI/CD 环境） | paraphrase-multilingual-MiniLM-L12-v2 |

---

## 模型缓存位置

下载的模型缓存在 `~/.cache/huggingface/hub/`，可手动清理不用的旧模型：

```bash
# 查看缓存大小
du -sh ~/.cache/huggingface/hub/

# 清理特定模型（例如清理旧的 MiniLM）
rm -rf ~/.cache/huggingface/hub/models--sentence-transformers--paraphrase-multilingual-MiniLM-L12-v2
```
