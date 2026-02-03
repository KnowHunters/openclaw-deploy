#!/bin/bash
# ╔════════════════════════════════════════════════════════════╗
# ║  OpenClaw 日志清理脚本                                     ║
# ║  功能: 清理过期日志，节省磁盘空间                          ║
# ╚════════════════════════════════════════════════════════════╝

OPENCLAW_USER="${OPENCLAW_USER:-openclaw}"
DAYS_TO_KEEP=${1:-7}  # 默认保留 7 天，可通过参数覆盖

echo "═══════════════════════════════════════════════"
echo "  OpenClaw 日志清理 (保留 ${DAYS_TO_KEEP} 天)"
echo "═══════════════════════════════════════════════"

# 1. 清理 PM2 日志
echo -n "→ 清理 PM2 日志..."
sudo -u "$OPENCLAW_USER" pm2 flush >/dev/null 2>&1 && echo " ✓" || echo " (跳过)"

# 2. 清理自定义日志
echo -n "→ 清理 /var/log/openclaw-*.log..."
find /var/log -name "openclaw-*.log" -mtime +$DAYS_TO_KEEP -delete 2>/dev/null && echo " ✓" || echo " (无匹配)"

# 3. 清理 journalctl (如果存在)
if command -v journalctl &>/dev/null; then
    echo -n "→ 清理 systemd 日志..."
    sudo journalctl --vacuum-time=${DAYS_TO_KEEP}d >/dev/null 2>&1 && echo " ✓" || echo " (跳过)"
fi

# 统计磁盘使用
echo ""
echo "当前磁盘使用:"
df -h / | awk 'NR==1 || NR==2'

echo ""
echo "✓ 日志清理完成"
