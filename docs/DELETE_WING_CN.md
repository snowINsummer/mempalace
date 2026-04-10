# 删除指定 Wing 的 Mine 数据

MemPalace 没有内置删除命令，需要通过 Python 脚本操作 ChromaDB。

---

## 查看当前数据

```bash
mempalace status
```

输出示例：
```
WING: autotest-platform
  ROOM: src                    811 drawers
  ROOM: documentation           55 drawers

WING: framework-launcher
  ROOM: external              6865 drawers
  ROOM: technical             1474 drawers
```

---

## 删除指定 Wing

```python
python3 -c "
import chromadb, os

palace_path = os.path.expanduser('~/.mempalace/palace')
client = chromadb.PersistentClient(path=palace_path)
col = client.get_collection('mempalace_drawers')

WING_TO_DELETE = 'autotest-platform'  # ← 改成要删除的 wing 名

results = col.get(where={'wing': WING_TO_DELETE}, include=[])
ids = results['ids']
print(f'找到 {len(ids)} 条 {WING_TO_DELETE} 记录')

for i in range(0, len(ids), 500):
    col.delete(ids=ids[i:i+500])
print('删除完成')
"
```

## 删除指定 Room

```python
python3 -c "
import chromadb, os

palace_path = os.path.expanduser('~/.mempalace/palace')
client = chromadb.PersistentClient(path=palace_path)
col = client.get_collection('mempalace_drawers')

WING = 'autotest-platform'    # ← wing 名
ROOM = 'scene-internal'       # ← 要删除的 room 名

results = col.get(
    where={'\$and': [{'wing': WING}, {'room': ROOM}]},
    include=[]
)
ids = results['ids']
print(f'找到 {len(ids)} 条 {WING}/{ROOM} 记录')

for i in range(0, len(ids), 500):
    col.delete(ids=ids[i:i+500])
print('删除完成')
"
```

## 全部清空

```bash
rm -rf ~/.mempalace/palace
```

---

## 删除后验证

```bash
mempalace status
```

确认目标 wing/room 已不在列表中。
