#!/bin/bash

# 模拟通过 curl 管道执行的情况
echo "=== 测试脚本下载逻辑 ==="

# 检测是否通过管道执行
if [[ -t 0 ]]; then
    echo "检测到: 本地执行"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
else
    echo "检测到: 管道执行"
    SCRIPT_DIR=$(mktemp -d)
fi

echo "SCRIPT_DIR: $SCRIPT_DIR"

# 检查库文件
if [[ ! -f "$SCRIPT_DIR/lib/ui.sh" ]]; then
    echo "库文件不存在，需要下载"
    
    # 确保使用临时目录
    if [[ -t 0 ]]; then
        TEMP_DIR=$(mktemp -d)
        SCRIPT_DIR="$TEMP_DIR"
        echo "创建临时目录: $SCRIPT_DIR"
    fi
    
    mkdir -p "$SCRIPT_DIR/lib"
    echo "创建目录: $SCRIPT_DIR/lib"
    
    # 测试文件路径
    echo "测试文件路径: $SCRIPT_DIR/lib/ui.sh"
    
    # 模拟下载
    echo "# test" > "$SCRIPT_DIR/lib/ui.sh"
    echo "创建测试文件成功"
fi

# 测试 source 路径
echo ""
echo "=== 测试 source 路径 ==="
echo "source \"$SCRIPT_DIR/lib/ui.sh\""

if [[ -f "$SCRIPT_DIR/lib/ui.sh" ]]; then
    echo "✓ 文件存在"
else
    echo "✗ 文件不存在"
fi

# 清理
if [[ ! -t 0 ]]; then
    rm -rf "$SCRIPT_DIR"
    echo "清理临时目录"
fi
