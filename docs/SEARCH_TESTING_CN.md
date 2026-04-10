# MemPalace 搜索测试指南

init 和 mine 之后，如何验证数据是否正确存入、搜索是否命中。

---

## 测试流程

```bash
# 1. 先看存了什么
mempalace status
# → WING: myapp
# →   ROOM: backend     120 drawers
# →   ROOM: frontend     85 drawers
# →   ROOM: general       30 drawers

# 2. 搜一个你明确知道存在的内容（比如你项目里有登录功能）
mempalace search "登录功能"

# 3. 看返回结果
# =============================================================
#   Results for: "登录功能"
# =============================================================
#
#   [1] myapp / backend
#       Source: auth_controller.py
#       Match:  0.847              ← 相似度，越接近 1 越好
#
#       def login(username, password):
#           """用户登录接口"""
#           ...

# 4. 测试翼/房间过滤是否生效
mempalace search "登录功能" --wing myapp --room backend

# 5. 测试语义搜索（换个说法，不用原文关键词）
mempalace search "用户怎么认证的"
# → 应该也能命中 auth 相关代码，即使原文里没有"认证"这个词
```

---

## 判断标准

| 结果 | 说明 |
|------|------|
| Match >= 0.8 | 强命中，内容高度相关 |
| Match 0.6-0.8 | 一般命中，内容有关联 |
| Match < 0.6 | 弱命中，可能不太相关 |
| No results found | 没命中，检查 wing/room 过滤是否写错 |

---

## 没命中时的排查思路

```bash
# 确认文件被 mine 进去了
mempalace status
# → 看 drawers 数量是否 > 0

# 确认不是被 gitignore 排除了
mempalace mine ~/projects/myapp --dry-run
# → 看目标文件是否在列表中

# 确认文件格式在支持范围内
# 只支持: .txt .md .py .js .ts .json .yaml .html .css .java .go .rs .rb .sh .csv .sql .toml

# 确认文件内容不是太短（< 50 字符会被跳过）
```
