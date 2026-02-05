# OpenClaw 环境变量配置
# 生成时间: {{TIMESTAMP}}
# 警告: 此文件包含敏感信息，请勿分享！

# ============================================================================
# AI Providers
# ============================================================================

{{#ANTHROPIC}}
# Anthropic (Claude)
# 获取地址: https://console.anthropic.com/
ANTHROPIC_API_KEY={{ANTHROPIC_API_KEY}}
{{/ANTHROPIC}}

{{#OPENAI}}
# OpenAI (GPT)
# 获取地址: https://platform.openai.com/
OPENAI_API_KEY={{OPENAI_API_KEY}}
{{/OPENAI}}

{{#DEEPSEEK}}
# DeepSeek
# 获取地址: https://platform.deepseek.com/
DEEPSEEK_API_KEY={{DEEPSEEK_API_KEY}}
{{/DEEPSEEK}}

{{#GOOGLE}}
# Google (Gemini)
# 获取地址: https://makersuite.google.com/app/apikey
GOOGLE_API_KEY={{GOOGLE_API_KEY}}
{{/GOOGLE}}

# ============================================================================
# Channels
# ============================================================================

{{#TELEGRAM}}
# Telegram Bot
# 创建方法: 在 Telegram 中找 @BotFather
TELEGRAM_BOT_TOKEN={{TELEGRAM_BOT_TOKEN}}
{{/TELEGRAM}}

{{#DISCORD}}
# Discord Bot
# 创建方法: https://discord.com/developers/applications
DISCORD_BOT_TOKEN={{DISCORD_BOT_TOKEN}}
{{/DISCORD}}

# ============================================================================
# Gateway
# ============================================================================

# Gateway 访问令牌
OPENCLAW_GATEWAY_TOKEN={{GATEWAY_TOKEN}}

# ============================================================================
# 其他配置
# ============================================================================

# 日志级别 (debug, info, warn, error)
# OPENCLAW_LOG_LEVEL=info

# 代理设置 (如需要)
# HTTP_PROXY=http://proxy:port
# HTTPS_PROXY=http://proxy:port
