# Fork 仓库 & 推送修改流程记录

---

## 背景

原仓库 `milla-jovovich/mempalace` 无写权限，需要 Fork 到自己账号后推送修改。

---

## 操作步骤

### 1. GitHub 上 Fork 仓库

在 `https://github.com/milla-jovovich/mempalace` 页面点击 **Fork** 按钮，Fork 到自己账号下。

### 2. 生成 Personal Access Token

GitHub Settings > Developer settings > Personal access tokens > Fine-grained tokens：

| 配置项 | 值 |
|--------|------|
| Repository access | Only select repositories → 选你的 fork 仓库 |
| Contents | **Read and write**（推送代码必须） |
| Metadata | Read-only（默认） |
| **workflow** | **Read and write**（仓库有 `.github/workflows/` 时必须勾选） |

> 如果用 Classic token，需要勾选 `repo` + `workflow` 两个权限。

### 3. 添加 Fork 为 remote

```bash
# 查看当前 remote
git remote -v
# → origin  https://github.com/milla-jovovich/mempalace (fetch/push)

# 添加自己的 fork（TOKEN 替换为实际值）
git remote add myfork https://<用户名>:<TOKEN>@github.com/<用户名>/mempalace.git
```

### 4. 创建分支并提交

```bash
# 新建功能分支
git checkout -b feat/cosine-multilingual

# 暂存源码修改
git add mempalace/cli.py mempalace/config.py mempalace/convo_miner.py \
        mempalace/layers.py mempalace/mcp_server.py mempalace/miner.py \
        mempalace/palace_graph.py mempalace/searcher.py

# 提交源码修改
git commit -m "fix: switch to cosine distance + multilingual embedding model"

# 暂存文档
git add docs/

# 提交文档
git commit -m "docs: add Chinese documentation and changelog"
```

### 5. 推送到 Fork

```bash
git push -u myfork feat/cosine-multilingual
```

### 6. 常见报错及解决

| 报错 | 原因 | 解决 |
|------|------|------|
| `403 Permission denied` | Token 没有 Contents 写权限 | Token 设置中 Contents → Read and write |
| `refusing to allow ... without workflow scope` | 仓库有 GitHub Actions 工作流文件 | Token 额外勾选 **workflow** 权限 |
| `repository not found` | Fork 未完成或用户名写错 | 确认 Fork 仓库 URL 正确 |

---

## 安全提醒

- **永远不要在聊天、代码、日志中暴露 Token**
- 推送完成后如果 Token 有泄露风险，立即去 GitHub 撤销（Revoke）并重新生成
- 建议给 Token 设置过期时间（如 30 天）

---

## 本次推送结果

- Fork 仓库：`https://github.com/snowINsummer/mempalace`
- 分支：`feat/cosine-multilingual`
- Commit 1：`fix: switch to cosine distance + multilingual embedding model`（8 个文件，92 行增，16 行删）
- Commit 2：`docs: add Chinese documentation and changelog`（7 个文件，1703 行增）
