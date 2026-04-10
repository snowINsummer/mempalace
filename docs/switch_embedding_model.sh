#!/bin/bash
# switch_embedding_model.sh — 切换 Embedding 模型后的重建脚本
#
# 用法：
#   1. 先修改 mempalace/config.py 中的 DEFAULT_EMBEDDING_MODEL
#   2. 然后运行此脚本：
#      bash docs/switch_embedding_model.sh <mine目标目录> [--wing 翼名]
#
# 示例：
#   bash docs/switch_embedding_model.sh ~/projects/myapp
#   bash docs/switch_embedding_model.sh ~/projects/myapp --wing myapp

set -e

PALACE_PATH="${HOME}/.mempalace/palace"
MINE_DIR="$1"
WING_ARG=""

if [ -z "$MINE_DIR" ]; then
    echo "用法: bash $0 <mine目标目录> [--wing 翼名]"
    echo "示例: bash $0 ~/projects/myapp --wing myapp"
    exit 1
fi

if [ "$2" = "--wing" ] && [ -n "$3" ]; then
    WING_ARG="--wing $3"
fi

echo "=========================================="
echo "  MemPalace 模型切换重建脚本"
echo "=========================================="
echo ""

# 1. 显示当前配置的模型
echo "[1/4] 当前模型配置："
grep "DEFAULT_EMBEDDING_MODEL" mempalace/config.py
echo ""

# 2. 删除旧的 palace 缓存
echo "[2/4] 删除旧缓存: ${PALACE_PATH}"
rm -rf "${PALACE_PATH}"
echo "  已删除"
echo ""

# 3. 重新 init
echo "[3/4] 重新 init: ${MINE_DIR}"
mempalace init "${MINE_DIR}"
echo ""

# 4. 重新 mine
echo "[4/4] 重新 mine: ${MINE_DIR} ${WING_ARG}"
mempalace mine "${MINE_DIR}" ${WING_ARG}
echo ""

echo "=========================================="
echo "  完成！可以测试搜索了："
echo "  mempalace search \"你的关键词\""
echo "=========================================="
