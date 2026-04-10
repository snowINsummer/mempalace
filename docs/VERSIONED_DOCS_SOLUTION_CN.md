# 多版本迭代文档的 Mining 方案

解决"多份迭代文档中，后面的修改了前面的，MemPalace 无法自动识别最新结论"的问题。

---

## 问题背景

MemPalace 的设计哲学是"逐字原文存储，绝不丢弃"。当存在多版本迭代文档时：

- `需求v1.md`："用户系统采用手机号注册"
- `需求v2.md`："取消手机号，改为邮箱注册"

两条都会被存入 palace，搜索按语义相似度排序，不考虑时间先后。AI 可能返回已过时的 v1 内容。

搜索代码（`searcher.py`）中没有任何时间权重，纯 cosine distance 排序。文件更新检测（`file_already_mined`）只处理同一文件路径的 mtime 变化，不处理不同文件间的覆盖关系。

---

## 推荐方案：双层存储

**原文照常 mine（保留历史上下文），额外生成一份"当前真相"文档（确保搜索命中最新结论）。**

```
┌────────────────────────────────────────────┐
│  room: requirements-current  (当前真相)     │  ← AI 搜索优先命中这里
│  只有一个文件，每次迭代覆盖更新              │
│  "用户注册：邮箱注册（v3 确定）"             │
└────────────────────────────────────────────┘
           ↑ 自动生成
┌────────────────────────────────────────────┐
│  room: requirements-history  (历史原文)     │  ← 需要追溯"为什么改"时搜这里
│  v1.md, v2.md, v3.md ... 全部保留           │
│  "v2: 取消手机号，改用邮箱，原因是..."       │
└────────────────────────────────────────────┘
```

---

## 具体实现

### 第一步：目录结构

```
requirements/
  current/                  ← mine 这个目录，room 映射到 requirements-current
    _CURRENT_TRUTH.md       ← AI 生成，每次覆盖
  history/                  ← mine 这个目录，room 映射到 requirements-history
    v1_立项需求.md
    v2_alpha测试调整.md
    v3_公测修改.md
```

### 第二步：mempalace.yaml 配置

```yaml
# requirements/current/mempalace.yaml
wing: mygame
rooms:
  - name: requirements-current
    description: "当前生效的需求结论"
    keywords: [requirement, current, truth]

# requirements/history/mempalace.yaml
wing: mygame
rooms:
  - name: requirements-history
    description: "历史需求文档原文"
    keywords: [requirement, history, version]
```

### 第三步：AI 预处理脚本

```python
#!/usr/bin/env python3
"""generate_current_truth.py — 从迭代文档生成当前真相"""

import os
import glob
from pathlib import Path
from anthropic import Anthropic

client = Anthropic()

def generate_truth(docs_dir: str, output_path: str):
    # 1. 按文件名/修改时间排序，确定迭代顺序
    files = sorted(glob.glob(f"{docs_dir}/*.md"), key=os.path.getmtime)

    # 2. 拼接所有文档，标注顺序
    all_content = ""
    for i, f in enumerate(files, 1):
        name = Path(f).name
        text = Path(f).read_text()
        all_content += f"\n\n=== 第{i}版: {name} ===\n{text}"

    # 3. 让 AI 提取当前生效的结论
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=4096,
        messages=[{
            "role": "user",
            "content": f"""以下是一个项目的多版本需求文档，按时间顺序排列，后面的文档可能修改前面的内容。

请提取【当前生效】的所有需求结论，输出为一份结构化文档。规则：
1. 如果后面的版本修改了前面的内容，以最新版本为准
2. 每条结论标注"来源：vN"表明出自哪个版本
3. 如果某个需求被后续版本明确取消，标注"[已取消]"
4. 保留原文关键措辞，不要过度概括

{all_content}"""
        }]
    )

    # 4. 写入当前真相文档
    truth = response.content[0].text
    Path(output_path).write_text(
        f"# 当前需求真相（自动生成）\n"
        f"# 生成时间: {Path(files[-1]).name} 之后\n"
        f"# 源文档数: {len(files)}\n\n"
        f"{truth}"
    )
    print(f"生成完成: {output_path}，基于 {len(files)} 份文档")

# 用法
generate_truth(
    docs_dir="~/game/design/requirements/history/",
    output_path="~/game/design/requirements/current/_CURRENT_TRUTH.md"
)
```

### 第四步：每次迭代的操作脚本

```bash
#!/bin/bash
# update_requirements.sh — 新迭代文档加入后执行

# 1. AI 生成当前真相（覆盖旧文件，mine 时自动 upsert）
python generate_current_truth.py

# 2. 重新 mine（当前真相因为 mtime 变了会更新，历史文档新增的会追加）
mempalace mine ~/game/design/requirements/current --wing mygame
mempalace mine ~/game/design/requirements/history --wing mygame

echo "Done. 当前真相已更新，历史原文已归档。"
```

---

## 搜索效果示例

**问当前结论：**

```
你: "用户注册用什么方式？"

AI 搜到:
  [1] requirements-current / _CURRENT_TRUTH.md
      "用户注册：邮箱注册（来源：v3）"              相似度 0.95  ← 命中最新结论

  [2] requirements-history / v3_公测修改.md
      "取消手机号注册，改为邮箱，原因是短信成本..."    相似度 0.88  ← 有上下文

AI 回答: "当前采用邮箱注册（v3 确定），原因是短信验证码成本过高。"
```

**问历史原因：**

```
你: "为什么取消了手机号注册？"

AI 搜到:
  [1] requirements-history / v3_公测修改.md
      "取消手机号，原因：短信成本高，转化率低..."      相似度 0.94  ← 历史原文有详细原因

  [2] requirements-current / _CURRENT_TRUTH.md
      "用户注册：邮箱注册（来源：v3）[已取消：手机号]" 相似度 0.87

AI 回答: "v3 取消了手机号注册，原因是短信验证码成本高且转化率低。"
```

当前结论和历史原因都能找到。

---

## 进阶：按模块拆分真相文档

需求文档通常涵盖很多模块。可以让 AI 按模块输出多个真相文件，搜索更精准：

```
current/
  _TRUTH_用户系统.md
  _TRUTH_战斗系统.md
  _TRUTH_经济系统.md
  _TRUTH_社交系统.md
```

修改 `generate_current_truth.py` 的 prompt，要求按模块分文件输出即可。

---

## 方案对比

| 方案 | 优点 | 缺点 |
|------|------|------|
| 人工维护一个文档 | 最准确 | 不现实，成本太高 |
| AI 总结成一个文档，只 mine 总结 | 简单 | 丢失历史上下文 |
| **双层存储（推荐）** | **最新结论 + 历史原因都有** | **需要一个预处理脚本** |
| 全部原文 mine，不做处理 | 零成本 | 新旧冲突，AI 可能答错 |

---

## 核心原则

一个 `generate_current_truth.py` 脚本 + 两个目录的 mine，就能解决"多版本文档谁是最新"的问题，同时不丢失"为什么改"的历史上下文。
