#!/bin/bash
# ╔════════════════════════════════════════════════════════════╗
# ║  OpenClaw 恢复脚本                                         ║
# ║  功能: 交互式选择备份并恢复                                ║
# ╚════════════════════════════════════════════════════════════╝

OPENCLAW_USER="${OPENCLAW_USER:-openclaw}"
WORKSPACE_DIR="${WORKSPACE_DIR:-/home/$OPENCLAW_USER/openclaw-bot}"
BACKUP_DIR="${BACKUP_DIR:-/home/$OPENCLAW_USER/openclaw-backups}"

echo "═══════════════════════════════════════════════"
echo "  OpenClaw 恢复向导"
echo "═══════════════════════════════════════════════"

# 列出可用备份
BACKUPS=($(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null))

if [ ${#BACKUPS[@]} -eq 0 ]; then
    echo "✗ 未找到任何备份文件"
    exit 1
fi

echo ""
echo "可用备份:"
for i in "${!BACKUPS[@]}"; do
    FILE="${BACKUPS[$i]}"
    SIZE=$(du -h "$FILE" | cut -f1)
    DATE=$(basename "$FILE" | sed 's/openclaw-backup-//' | sed 's/.tar.gz//')
    echo "  $((i+1))) $DATE ($SIZE)"
done

echo ""
read -p "选择要恢复的备份 [1-${#BACKUPS[@]}]: " choice

# 验证选择
if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#BACKUPS[@]} ]; then
    echo "✗ 无效选择"
    exit 1
fi

SELECTED="${BACKUPS[$((choice-1))]}"
echo ""
echo "已选择: $SELECTED"

# 确认
read -p "⚠ 这将覆盖当前配置，是否继续? [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "已取消"
    exit 0
fi

# 备份当前配置
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
CURRENT_BACKUP="$WORKSPACE_DIR.before-restore-$TIMESTAMP"
echo ""
echo "→ 备份当前配置到: $CURRENT_BACKUP"
cp -r "$WORKSPACE_DIR" "$CURRENT_BACKUP"

# 停止服务
echo "→ 停止 PM2 服务..."
sudo -u "$OPENCLAW_USER" pm2 stop openclaw 2>/dev/null || true

# 清空并恢复
echo "→ 恢复备份..."
rm -rf "$WORKSPACE_DIR"/*
tar -xzf "$SELECTED" -C "$WORKSPACE_DIR"
chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "$WORKSPACE_DIR"

# 重新安装依赖
echo "→ 重新安装依赖..."
cd "$WORKSPACE_DIR"
sudo -u "$OPENCLAW_USER" npm install --silent 2>/dev/null || true

# 启动服务
echo "→ 启动服务..."
sudo -u "$OPENCLAW_USER" pm2 start openclaw 2>/dev/null || \
sudo -u "$OPENCLAW_USER" bash -c "cd $WORKSPACE_DIR && pm2 start npm --name openclaw -- start" 2>/dev/null

echo ""
echo "✓ 恢复完成"
echo "  当前配置已备份至: $CURRENT_BACKUP"
echo "  使用 'pm2 status' 查看服务状态"
