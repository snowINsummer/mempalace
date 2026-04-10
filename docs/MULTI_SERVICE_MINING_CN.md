# 前后端分离 / 多服务项目的 Mining 指南

针对前后端分离及多服务架构，如何将多个服务目录 mine 成一个整体。

---

## 核心机制

每次 `mempalace mine` 只能指向一个目录，且该目录必须有 `mempalace.yaml`。但所有数据最终存入同一个 palace（`~/.mempalace/palace`）。利用这一点，可以通过多次 mine 将多个服务归入同一个整体。

---

## 策略一：多次 mine，同一个 wing（推荐）

用 `--wing` 强制指定相同的翼名，把多个服务归为一个整体：

```bash
# 每个服务目录先 init（生成各自的 mempalace.yaml）
mempalace init ~/projects/frontend
mempalace init ~/projects/backend
mempalace init ~/projects/user-service
mempalace init ~/projects/order-service

# 挖掘时统一用同一个 wing 名
mempalace mine ~/projects/frontend      --wing myapp
mempalace mine ~/projects/backend       --wing myapp
mempalace mine ~/projects/user-service  --wing myapp
mempalace mine ~/projects/order-service --wing myapp
```

效果：所有服务的代码都在 `wing_myapp` 下，但**房间自动区分**（每个目录的文件夹结构会产生不同的 room）。搜索时：

```bash
# 搜整个项目
mempalace search "认证流程" --wing myapp

# 搜特定模块
mempalace search "认证流程" --wing myapp --room backend
```

---

## 策略二：不同 wing，靠 tunnel 关联

每个服务用自己的 wing（默认行为，翼名 = 目录名）：

```bash
mempalace mine ~/projects/frontend
mempalace mine ~/projects/backend
mempalace mine ~/projects/user-service
```

当不同 wing 中出现相同的 room 名（如 `auth`、`api`），会自动产生 tunnel 跨翼关联。搜索时不加 `--wing` 就能跨服务搜索：

```bash
# 跨所有服务搜
mempalace search "JWT token 刷新逻辑"

# 只看某个服务
mempalace search "JWT token" --wing backend
```

---

## 关键：定制 mempalace.yaml

`init` 自动生成的房间可能不够精准。对于多服务项目，建议手动编辑每个目录的 `mempalace.yaml`，让房间名在服务间保持一致：

```yaml
# frontend/mempalace.yaml
wing: myapp           # ← 统一翼名
rooms:
  - name: auth
    description: "认证相关前端组件"
    keywords: [login, auth, token, session]
  - name: api
    description: "API 调用层"
    keywords: [api, fetch, request, endpoint]
  - name: ui
    description: "UI 组件"
    keywords: [component, page, layout, style]
  - name: general
    description: "其他"
    keywords: []
```

```yaml
# backend/mempalace.yaml
wing: myapp           # ← 同一个翼名
rooms:
  - name: auth
    description: "认证服务端逻辑"
    keywords: [auth, jwt, middleware, permission]
  - name: api
    description: "API 路由和控制器"
    keywords: [router, controller, endpoint, handler]
  - name: database
    description: "数据库模型和迁移"
    keywords: [model, migration, schema, sql]
  - name: general
    description: "其他"
    keywords: []
```

这样前端的 `auth` 文件和后端的 `auth` 文件都进同一个 room，搜索"认证"能同时找到两端的实现。

---

## 写个脚本一键搞定

```bash
#!/bin/bash
# mine_all.sh - 一键挖掘所有服务
WING="myapp"
SERVICES=(frontend backend user-service order-service gateway)

for svc in "${SERVICES[@]}"; do
  echo "Mining $svc..."
  mempalace mine ~/projects/$svc --wing $WING
done

echo "Done. Status:"
mempalace status
```

---

## 总结

| 需求 | 做法 |
|------|------|
| 当作一个整体搜索 | 所有服务 mine 到同一个 `--wing` |
| 保留服务边界但能跨服务搜 | 各用各的 wing，不加 `--wing` 搜索 |
| 精准分模块 | 手动编辑 `mempalace.yaml`，统一 room 命名 |
| 重复挖掘（代码更新后） | 直接重新 `mine`，已有的文件会按 mtime 跳过未变更的 |
