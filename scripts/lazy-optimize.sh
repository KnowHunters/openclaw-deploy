#!/bin/bash
# OpenClaw 超级懒人优化脚本
# 一键优化 token 消耗

set -e

# 适配环境变量
OPENCLAW_USER="openclaw"
BOT_DIR="/home/$OPENCLAW_USER/openclaw-bot"

# 检查是否以 root 运行
if [ "$EUID" -ne 0 ]; then
  echo "请使用 sudo 运行此脚本"
  exit 1
fi

echo "🦀 开始优化..."

# 1. 备份
if [ -f "$BOT_DIR/config.json" ]; then
    cp "$BOT_DIR/config.json" "$BOT_DIR/config.json.backup"
    echo "✓ 已备份 config.json"
fi

if [ -f "$BOT_DIR/SOUL.md" ]; then
    cp "$BOT_DIR/SOUL.md" "$BOT_DIR/SOUL.md.backup"
    echo "✓ 已备份 SOUL.md"
fi

# 2. 优化 config.json
cat > "$BOT_DIR/config.json" << 'EOF'
{
  "models": {
    "providers": {
      "minimax": {
        "baseUrl": "https://api.minimax.chat/v1",
        "apiKey": "${MINIMAX_API_KEY}",
        "api": "openai-completions",
        "models": [{"id": "MiniMax-M2.1"}]
      }
    }
  },
  "agents": {
    "main": {
      "model": "minimax/MiniMax-M2.1",
      "maxContextTokens": 50000,
      "compactionThreshold": 0.7,
      "autoReset": true
    }
  }
}
EOF

# 修正权限
chown $OPENCLAW_USER:$OPENCLAW_USER "$BOT_DIR/config.json"
echo "✓ config.json 已优化 (请确保 .env 中设置了 MINIMAX_API_KEY)"

# 3. 精简或创建 SOUL.md
cat > "$BOT_DIR/SOUL.md" << 'EOF'
# SOUL.md - 省 Token 版

## 回复原则
- 简短直接
- 能 1 句说清就不说 2 句
- 追问再展开

## 上下文管理
- 每 20 轮自动总结
- 保留关键信息
- 删除闲聊内容

## 工具使用
- 优先 memory_get
- 少用 memory_search
- web_search 只在必要时用
EOF

# 修正权限
chown $OPENCLAW_USER:$OPENCLAW_USER "$BOT_DIR/SOUL.md"
echo "✓ SOUL.md 已精简"

# 4. 重启服务 (适配 PM2)
echo "正在重启服务..."
su - "$OPENCLAW_USER" -c "pm2 restart openclaw"

echo "
✅ 优化完成！

预期效果：
- Token 消耗减少 60-70%
- 响应更快
- 成本更低
"
