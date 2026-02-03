#!/bin/bash
# ╔════════════════════════════════════════════════════════════╗
# ║  OpenClaw 自动备份脚本                                     ║
# ║  功能: 备份配置和数据，支持自动清理旧备份                  ║
# ╚════════════════════════════════════════════════════════════╝

set -e

OPENCLAW_USER="${OPENCLAW_USER:-openclaw}"
WORKSPACE_DIR="${WORKSPACE_DIR:-/home/$OPENCLAW_USER/openclaw-bot}"
BACKUP_DIR="${BACKUP_DIR:-/home/$OPENCLAW_USER/openclaw-backups}"
DATE=$(date '+%Y%m%d-%H%M%S')
BACKUP_FILE="$BACKUP_DIR/openclaw-backup-$DATE.tar.gz"
KEEP_DAYS=${1:-30}  # 默认保留 30 天

echo "═══════════════════════════════════════════════"
echo "  OpenClaw 备份 [$(date '+%Y-%m-%d %H:%M:%S')]"
echo "═══════════════════════════════════════════════"

# 检查工作目录
if [ ! -d "$WORKSPACE_DIR" ]; then
    echo "✗ 工作目录不存在: $WORKSPACE_DIR"
    exit 1
fi

# 创建备份目录
mkdir -p "$BACKUP_DIR"
chown "$OPENCLAW_USER:$OPENCLAW_USER" "$BACKUP_DIR"

echo "→ 源目录: $WORKSPACE_DIR"
echo "→ 备份到: $BACKUP_FILE"

# 执行备份
cd "$WORKSPACE_DIR"
tar -czf "$BACKUP_FILE" \
    --exclude='node_modules' \
    --exclude='*.log' \
    --exclude='.cache' \
    . 2>/dev/null

if [ $? -eq 0 ]; then
    chown "$OPENCLAW_USER:$OPENCLAW_USER" "$BACKUP_FILE"
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "✓ 备份成功 (大小: $SIZE)"
    
    # 清理旧备份
    OLD_COUNT=$(find "$BACKUP_DIR" -name "openclaw-backup-*.tar.gz" -mtime +$KEEP_DAYS | wc -l)
    if [ "$OLD_COUNT" -gt 0 ]; then
        find "$BACKUP_DIR" -name "openclaw-backup-*.tar.gz" -mtime +$KEEP_DAYS -delete
        echo "→ 已清理 $OLD_COUNT 个旧备份 (>${KEEP_DAYS}天)"
    fi
    
    # 列出现有备份
    echo ""
    echo "现有备份:"
    ls -lh "$BACKUP_DIR"/*.tar.gz 2>/dev/null | tail -5
else
    echo "✗ 备份失败"
    exit 1
fi
