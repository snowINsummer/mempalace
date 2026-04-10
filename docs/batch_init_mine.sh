#!/bin/bash
# batch_init_mine.sh — 批量生成带服务前缀的 mempalace.yaml 并统一 mine
#
# 用法：bash docs/batch_init_mine.sh
#
# 功能：
#   1. 扫描所有服务目录
#   2. 为每个服务生成 room 名带服务前缀的 mempalace.yaml
#   3. 统一 mine 到同一个 wing（autotest-platform）
#   4. 跳过空目录（如只有 README 的）

set -e

SERVICES_ROOT="$HOME/Documents/yostar/git/microservices"
WING="autotest-platform"

# go-zero 项目常见目录 → room 映射
declare -A DIR_TO_ROOM=(
    ["etc"]="etc"
    ["internal"]="internal"
    ["utils"]="scripts"
    ["common"]="common"
    ["model"]="model"
    ["client"]="frontend"
    ["config"]="configuration"
    ["docs"]="documentation"
    ["logs"]="logs"
    ["log"]="log"
    ["src"]="src"
    ["team"]="team"
    ["proto"]="proto"
    ["tests"]="tests"
)

echo "=========================================="
echo "  批量 init + mine"
echo "  服务根目录: $SERVICES_ROOT"
echo "  统一 wing:  $WING"
echo "=========================================="
echo ""

for svc_dir in "$SERVICES_ROOT"/*/; do
    svc_name=$(basename "$svc_dir")

    # 跳过空目录（只有 README 等，没有实际代码）
    file_count=$(find "$svc_dir" -type f \( -name "*.go" -o -name "*.py" -o -name "*.yaml" -o -name "*.json" \) 2>/dev/null | head -5 | wc -l)
    if [ "$file_count" -eq 0 ]; then
        echo "[$svc_name] 跳过（无代码文件）"
        echo ""
        continue
    fi

    echo "[$svc_name] 生成 mempalace.yaml..."

    # 扫描实际存在的子目录，生成 rooms
    ROOMS_YAML=""
    for subdir in "$svc_dir"*/; do
        [ -d "$subdir" ] || continue
        dir_name=$(basename "$subdir")

        # 跳过隐藏目录和非代码目录
        [[ "$dir_name" == .* ]] && continue
        [[ "$dir_name" == "node_modules" ]] && continue
        [[ "$dir_name" == "__pycache__" ]] && continue

        # 确定 room 基础名
        room_base="${DIR_TO_ROOM[$dir_name]:-$dir_name}"
        room_name="${svc_name}-${room_base}"

        ROOMS_YAML="$ROOMS_YAML
- name: ${room_name}
  description: \"Files from ${svc_name}/${dir_name}/\"
  keywords:
  - ${svc_name}
  - ${dir_name}"
    done

    # 加 general room
    ROOMS_YAML="$ROOMS_YAML
- name: ${svc_name}-general
  description: \"${svc_name} files that don't fit other rooms\"
  keywords: []"

    # 写入 mempalace.yaml
    cat > "$svc_dir/mempalace.yaml" << YAMLEOF
wing: ${WING}
rooms:${ROOMS_YAML}
YAMLEOF

    echo "[$svc_name] mempalace.yaml 已生成"

    # mine
    echo "[$svc_name] mining..."
    mempalace mine "$svc_dir" --wing "$WING" 2>&1 | tail -3
    echo ""
done

echo "=========================================="
echo "  全部完成！"
echo "  搜索示例："
echo "  mempalace search \"登录逻辑\" --wing $WING"
echo "  mempalace search \"登录逻辑\" --wing $WING --room scene-internal"
echo "=========================================="
