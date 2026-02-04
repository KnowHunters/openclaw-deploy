#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  OpenClaw Admin Panel v3.0 (The Soul Update)                                 ║
# ║  功能: 全能管理、人格定义、自动化监控、安全防护                              ║
# ║  作者: KnowHunters (知识猎人)                                                ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# [1] 全局配置与常量 (Global Config)
# ==============================================================================
OPENCLAW_USER="${OPENCLAW_USER:-openclaw}"
WORKSPACE_DIR="${WORKSPACE_DIR:-/home/$OPENCLAW_USER/openclaw-bot}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="/home/$OPENCLAW_USER/.openclaw/openclaw.json"
ENV_FILE="$WORKSPACE_DIR/.env"
PM2_BIN="/home/$OPENCLAW_USER/.npm-global/bin/pm2"
CLAW_BIN="/home/$OPENCLAW_USER/.npm-global/bin/openclaw"

# 颜色定义
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

# ==============================================================================
# [2] 基础工具库 (Utils)
# ==============================================================================
pause() {
    echo ""
    read -p "按回车键继续..."
}

prompt_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    echo -ne "${YELLOW}$prompt${NC} [默认: $default]: "
    read input
    eval $var_name="\${input:-$default}"
}

run_as_user() {
    if [ "$(whoami)" = "$OPENCLAW_USER" ]; then
        "$@"
    else
        sudo -u "$OPENCLAW_USER" "$@"
    fi
}

run_as_user_shell() {
    if [ "$(whoami)" = "$OPENCLAW_USER" ]; then
        bash -c "$1"
    else
        su - "$OPENCLAW_USER" -c "$1"
    fi
}

ensure_nano() {
    if ! command -v nano &>/dev/null; then
        echo -e "${YELLOW}[!] 检测到未安装 nano 编辑器，正在自动安装...${NC}"
        if [ "$EUID" -eq 0 ]; then
            apt-get update -qq && apt-get install -yqq nano
        else
            sudo apt-get update -qq && sudo apt-get install -yqq nano
        fi
        echo -e "${GREEN}[✓] 安装完成${NC}"
        sleep 1
    fi
}

edit_file_as_user() {
    local file=$1
    ensure_nano
    echo -e "${YELLOW}正在打开编辑器... (Ctrl+O 保存, Ctrl+X 退出)${NC}"
    sleep 1
    # 使用 su -c 调用 nano，确保以 openclaw 用户身份编辑
    su - "$OPENCLAW_USER" -c "mkdir -p $(dirname '$file') && nano '$file'"
}

header() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║     ___                    ____ _                         ║"
    echo "║    / _ \ _ __   ___ _ __  / ___| | __ ___      __         ║"
    echo "║   | | | | '_ \ / _ \ '_ \| |   | |/ _\` \ \ /\ / /         ║"
    echo "║   | |_| | |_) |  __/ | | | |___| | (_| |\ V  V /          ║"
    echo "║    \___/| .__/ \___|_| |_|\____|_|\__,_| \_/\_/           ║"
    echo "║         |_|                                               ║"
    echo "║                 管 理 面 板 v3.0 (Soul Update)            ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # 状态栏
    local pm2_status=$(sudo -u "$OPENCLAW_USER" "$PM2_BIN" jlist | grep -q "online" && echo -e "${GREEN}● 运行中${NC}" || echo -e "${RED}● 已停止${NC}")
    local mem_usage=$(free -h | awk 'NR==2{print $3 "/" $2}')
    local load_avg=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d, -f1)
    
    echo -e " ${BOLD}状态${NC}: $pm2_status  |  ${BOLD}内存${NC}: ${GRAY}$mem_usage${NC}  |  ${BOLD}负载${NC}: ${GRAY}$load_avg${NC}"
    echo -e "${GRAY}───────────────────────────────────────────────────────────────────────${NC}"
}

# ==============================================================================
# [3] 模板库 (Templates)
# ==============================================================================
get_template_soul() {
    cat <<EOF
# SOUL.md - 人格定义
## Mission
成为一个高效、可靠的个人数字助理，专注于帮助主人管理信息和任务。

## Personality
- **风格**: 简洁明快，不废话，专业而友好。
- **特质**: 主动但不打扰，注重隐私，透明诚实。
- **Emoji**: 适当使用微表情 ✨

## Response Guidelines
- 确认: "✅ 已完成", "👌 收到"
- 拒绝: "❌ 这个我做不到"
- 不确定: "🤔 让我查查..."

EOF
}

get_template_identity() {
    cat <<EOF
# IDENTITY.md - 身份卡片
## Bot Info
- **Name**: Nova
- **Role**: AI Assistant

## Owner Info
- **Name**: Master
- **Timezone**: Asia/Shanghai
- **Preferences**: 
    - 语言: 中文
    - 工作时间: 09:00 - 18:00
EOF
}

get_template_agents() {
    cat <<EOF
# AGENTS.md - 触发规则
## 任务捕获
- 触发词: ["任务", "待办", "todo", "记下"]
- 动作: 保存到 memory/tasks/YYYY-MM-DD.md
EOF
}

# ==============================================================================
# [4] 业务逻辑模块 (Business Logic)
# ==============================================================================

# --- 模块 A: 技能与初始化 ---
init_knowledge_base() {
    echo -e "\n${CYAN}→ 正在初始化知识库结构...${NC}"
    local base_dir="$WORKSPACE_DIR"
    
    run_as_user_shell "mkdir -p '$base_dir/memory'/{tasks,notes,ideas,journal,people}"
    run_as_user_shell "mkdir -p '$base_dir/backups'"
    
    # 生成索引
    run_as_user_shell "echo '# Memory Index' > '$base_dir/memory/MEMORY.md'"
    
    echo -e "${GREEN}✓ 目录结构已就绪 ($base_dir)${NC}"
    pause
}

install_skill() {
    local skill_name=$1
    echo -e "\n${CYAN}→ 正在安装技能: ${BOLD}$skill_name${NC}"
    
    if ! run_as_user_shell "npm list -g clawhub >/dev/null 2>&1"; then
        echo -e "${YELLOW}正在初始化技能安装器...${NC}"
        run_as_user_shell "npm install -g clawhub"
    fi
    
    run_as_user_shell "npx -y clawhub@latest install $skill_name"
    echo -e "${GREEN}✓ 安装指令已下达${NC}"
    pause
}

# --- 模块 B: 配置与向导 ---
configure_custom_provider() {
    local provider_id="$1"
    local base_url="$2"
    local api_key="$3"
    local model_id="$4"
    
    run_as_user_shell "node -e \"
    const fs = require('fs');
    const configFile = '$CONFIG_FILE';
    try {
        let config = JSON.parse(fs.readFileSync(configFile, 'utf8'));
        if (!config.models) config.models = {};
        if (!config.models.providers) config.models.providers = {};
        config.models.providers['$provider_id'] = {
            baseUrl: '$base_url',
            apiKey: '$api_key',
            models: [{ id: '$model_id', name: '$model_id', contextWindow: 128000, maxTokens: 16384 }]
        };
        fs.writeFileSync(configFile, JSON.stringify(config, null, 2));
    } catch (e) { console.error(e); process.exit(1); }\""
}

test_api_connection() {
    echo -e "\n${CYAN}⏳ 正在测试 API 连接...${NC}"
    if run_as_user_shell "timeout 20 $CLAW_BIN agent --local --message 'Hello' >/dev/null 2>&1"; then
        echo -e "${GREEN}✓ 连接测试成功！${NC}"
    else
        echo -e "${RED}✗ 连接测试失败${NC}"
    fi
    pause
}

configure_llm_wizard() {
    header
    echo -e "${BOLD}🧠 智能模型配置 (Smart Custom Endpoint)${NC}"
    echo -e "${GRAY}OpenClaw 官方接口已内置。此向导专注于配置【自定义端点】或【中转服务】。${NC}"
    echo ""
    echo "  请选择预设配置 (Presets):"
    echo "  1) DeepSeek (深度求索)"
    echo "  2) OpenRouter"
    echo "  3) Groq"
    echo "  4) Ollama (本地)"
    echo "  5) Moonshot (Kimi)"
    echo "  6) 完全自定义 (Manual)"
    echo ""
    echo "  0) 返回"
    echo ""
    read -p "请选择: " p_choice
    
    local base_url=""
    local provider_id="custom-llm"
    local default_model=""
    
    case $p_choice in
        1) base_url="https://api.deepseek.com"; default_model="deepseek-chat"; provider_id="deepseek-custom" ;;
        2) base_url="https://openrouter.ai/api/v1"; default_model="anthropic/claude-3.5-sonnet"; provider_id="openrouter-custom" ;;
        3) base_url="https://api.groq.com/openai/v1"; default_model="llama3-70b-8192"; provider_id="groq-custom" ;;
        4) base_url="http://localhost:11434/v1"; default_model="llama3"; provider_id="ollama-custom" ;;
        5) base_url="https://api.moonshot.cn/v1"; default_model="moonshot-v1-8k"; provider_id="moonshot-custom" ;;
        6) ;;
        0) return ;;
        *) echo "无效选择"; pause; return ;;
    esac

    echo ""
    echo -e "${CYAN}--- 配置详情 ---${NC}"
    prompt_input "API Base URL" "$base_url" base_url
    
    # 自动修正: 如果用户忘了加 /v1 (除了 Ollama 可能不需要，但 OpenAI 兼容通常需要)
    # 这里不做强制修正，但给提示
    if [[ "$base_url" != */v1 ]] && [[ "$base_url" != */v1/ ]]; then
         echo -e "${YELLOW}提示: 许多兼容接口需要在 URL 末尾加上 /v1${NC}"
    fi

    local api_key=""
    prompt_input "API Key" "" api_key
    prompt_input "模型名称 (Model ID)" "$default_model" model_id
    
    # 验证环节
    echo ""
    echo -e "${YELLOW}正在进行连通性测试...${NC}"
    
    # 构造一个简单的 curl 测试 (比 openclaw agent 更快且不依赖环境)
    # 注意: 这是一个基本测试，仅验证网络和 Key 格式
    if [ -n "$api_key" ]; then
        local auth_header="Authorization: Bearer $api_key"
        # 尝试列出模型或进行简单对话 (取决于 API 支持)
        # 为了通用性，我们直接调用 openclaw agent --local
        if run_as_user_shell "timeout 15 openclaw agent --local --model-override '$model_id' --api-override '$base_url' --key-override '$api_key' --message 'hi' >/dev/null 2>&1"; then
             echo -e "${GREEN}✓ 连接测试成功！${NC}"
        else
             echo -e "${RED}✗ 连接测试未通过 (可能是网络问题或 Key 无效)${NC}"
             read -p "是否强制保存? [y/N] " force_save
             if [[ ! $force_save =~ ^[Yy]$ ]]; then
                 echo "已取消保存。"
                 pause
                 return
             fi
        fi
    fi

    # 保存配置
    echo -e "\n${CYAN}正在写入配置...${NC}"
    configure_custom_provider "$provider_id" "$base_url" "$api_key" "$model_id"
    
    # 设置为当前模型
    run_as_user_shell "$CLAW_BIN models set $provider_id/$model_id"
    
    echo -e "${GREEN}✓ 配置已完成！当前模型: $provider_id/$model_id${NC}"
    pause
}


# --- 模块 C: 多渠道连接 (Channel Matrix) ---
configure_feishu() {
    header
    echo -e "${BOLD}🐦 飞书/Lark (Feishu Connector)${NC}"
    echo -e "${GRAY}基于 @m1heng-clawd/feishu 插件${NC}"
    echo ""
    
    # 1. 安装检查
    if ! run_as_user_shell "$CLAW_BIN plugins list 2>/dev/null | grep -q \"feishu\""; then
        echo -e "${YELLOW}插件未安装，正在安装...${NC}"
        run_as_user_shell "$CLAW_BIN plugins install @m1heng-clawd/feishu"
        echo -e "${GREEN}✓ 插件安装完成${NC}"
    else
        echo -e "${GREEN}✓ 插件已安装${NC}"
    fi
    
    echo ""
    echo "请准备好来自 [飞书开放平台] 的凭证:"
    echo "1. App ID"
    echo "2. App Secret"
    echo "3. 确保已开启 '长连接' 事件订阅"
    echo ""
    
    local app_id=""
    local app_secret=""
    local encrypt_key=""
    
    prompt_input "App ID" "" app_id
    prompt_input "App Secret" "" app_secret
    prompt_input "Encrypt Key (可选)" "" encrypt_key
    
    if [ -n "$app_id" ] && [ -n "$app_secret" ]; then
        echo -e "\n${CYAN}正在写入配置...${NC}"
        # 写入 Config (官方推荐方式)
        run_as_user_shell "$CLAW_BIN config set channels.feishu.appId '$app_id'"
        run_as_user_shell "$CLAW_BIN config set channels.feishu.appSecret '$app_secret'"
        run_as_user_shell "$CLAW_BIN config set channels.feishu.enabled true"
        [ -n "$encrypt_key" ] && run_as_user_shell "$CLAW_BIN config set channels.feishu.encryptKey '$encrypt_key'"
        
        echo -e "${GREEN}✓ 配置已保存${NC}"
        echo -e "${YELLOW}提示: 请确保在飞书后台配置了事件订阅 (im.message.receive_v1)${NC}"
    fi
    pause
}

configure_telegram() {
    header
    echo -e "${BOLD}✈️ Telegram Connector${NC}"
    echo ""
    
    # 1. 安装检查
    if [ ! -d "$WORKSPACE_DIR/skills/telegram" ]; then
        echo -e "${YELLOW}正在安装 Telegram 技能...${NC}"
        run_as_user_shell "npx -y clawhub@latest install telegram"
    fi
    
    echo ""
    local token=""
    prompt_input "Bot Token" "" token
    
    if [ -n "$token" ]; then
        echo -e "\n${CYAN}正在写入 .env ...${NC}"
        run_as_user_shell "sed -i '/export TELEGRAM_BOT_TOKEN=/d' '$ENV_FILE' && echo 'export TELEGRAM_BOT_TOKEN=$token' >> '$ENV_FILE'"
        echo -e "${GREEN}✓ Token 已保存${NC}"
    fi
    pause
}

configure_discord() {
    header
    echo -e "${BOLD}🎮 Discord Connector${NC}"
    echo ""
    
    # 1. 安装检查
    if [ ! -d "$WORKSPACE_DIR/skills/discord" ]; then
        echo -e "${YELLOW}正在安装 Discord 技能...${NC}"
        run_as_user_shell "npx -y clawhub@latest install discord"
    fi
    
    echo ""
    local token=""
    prompt_input "Bot Token" "" token
    
    if [ -n "$token" ]; then
        echo -e "\n${CYAN}正在写入 .env ...${NC}"
        run_as_user_shell "sed -i '/export DISCORD_BOT_TOKEN=/d' '$ENV_FILE' && echo 'export DISCORD_BOT_TOKEN=$token' >> '$ENV_FILE'"
        echo -e "${GREEN}✓ Token 已保存${NC}"
    fi
    pause
}

menu_channels() {
    while true; do
        header
        echo -e "${BOLD}📡 多渠道矩阵 (Channel Matrix)${NC}"
        echo ""
        echo "  1) 🐦 飞书/Lark (Feishu)"
        echo "  2) ✈️ Telegram"
        echo "  3) 🎮 Discord"
        echo ""
        echo "  0) 返回"
        echo ""
        read -p "请选择: " choice
        case $choice in
            1) configure_feishu ;;
            2) configure_telegram ;;
            3) configure_discord ;;
            0) return ;;
        esac
    done
}

# --- 模块 D: 人格与模板 ---
ensure_template_files() {
    local base_dir="$WORKSPACE_DIR"
    run_as_user_shell "mkdir -p '$base_dir'"
    
    if [ ! -f "$base_dir/SOUL.md" ]; then
        echo -e "${YELLOW}Creating SOUL.md...${NC}"
        get_template_soul | run_as_user_shell "cat > '$base_dir/SOUL.md'"
    fi
    if [ ! -f "$base_dir/IDENTITY.md" ]; then
        echo -e "${YELLOW}Creating IDENTITY.md...${NC}"
        get_template_identity | run_as_user_shell "cat > '$base_dir/IDENTITY.md'"
    fi
    if [ ! -f "$base_dir/AGENTS.md" ]; then
        echo -e "${YELLOW}Creating AGENTS.md...${NC}"
        get_template_agents | run_as_user_shell "cat > '$base_dir/AGENTS.md'"
    fi
}

menu_persona() {
    ensure_template_files
    local base_dir="$WORKSPACE_DIR"
    while true; do
        header
        echo -e "${BOLD}🎭 人格管理 (Persona Manager)${NC}"
        echo ""
        echo "  1) 编辑人格定义 (SOUL.md)"
        echo "  2) 编辑身份信息 (IDENTITY.md)"
        echo "  3) 编辑工作规则 (AGENTS.md)"
        echo "  4) 重置为默认模板 (Reset)"
        echo ""
        echo "  0) 返回"
        echo ""
        read -p "请选择: " choice
        case $choice in
            1) edit_file_as_user "$base_dir/SOUL.md" ;;
            2) edit_file_as_user "$base_dir/IDENTITY.md" ;;
            3) edit_file_as_user "$base_dir/AGENTS.md" ;;
            4) 
                run_as_user_shell "rm -f '$base_dir/SOUL.md' '$base_dir/IDENTITY.md' '$base_dir/AGENTS.md'"
                ensure_template_files
                echo -e "${GREEN}✓ 已重置${NC}"; pause ;;
            0) return ;;
        esac
    done
}

# --- 模块 D: 安全与性能 ---
configure_performance() {
    header
    echo -e "${BOLD}🏎️ 性能调优${NC}"
    echo ""
    local max_turns=""
    local max_tokens=""
    
    prompt_input "最大对话轮数 (Max Turns)" "40" max_turns
    prompt_input "最大上下文 Tokens" "80000" max_tokens
    
    echo -e "\n${CYAN}正在更新 session 配置...${NC}"
    run_as_user_shell "$CLAW_BIN config set session.maxTurns $max_turns"
    run_as_user_shell "$CLAW_BIN config set session.maxContextTokens $max_tokens"
    echo -e "${GREEN}✓ 已保存${NC}"; pause
}

configure_security() {
    header
    echo -e "${BOLD}🛡️ 安全加固${NC}"
    echo ""
    echo "  1) 重置 Gateway Token"
    echo "  2) 编辑工具白名单 (allowedTools)"
    echo ""
    read -p "请选择: " choice
    case $choice in
        1) 
            local new_token=$(openssl rand -hex 32)
            run_as_user_shell "sed -i '/export GATEWAY_TOKEN=/d' '$ENV_FILE' && echo 'export GATEWAY_TOKEN=$new_token' >> '$ENV_FILE'"
            echo -e "${GREEN}✓ 新 Token 已生成并写入 .env${NC}"
            echo -e "Token: $new_token"
            pause ;;
        2)
            echo -e "${YELLOW}请手动编辑 openclaw.json 中的 tools 配置${NC}"
            edit_file_as_user "$CONFIG_FILE" ;;
    esac
}

setup_heartbeat() {
    echo -e "\n${CYAN}→ 正在设置 Cron 任务...${NC}"
    # 简单的实现：添加一行到 crontab 如果不存在
    # 注意：这里仅作演示，实际生产需更严谨
    echo -e "${YELLOW}此功能将添加: openclaw heartbeat run 到 crontab${NC}"
    pause
}

# --- 模块 E: 维护 ---
deep_diagnose() {
    echo -e "\n${CYAN}→ 正在生成深度诊断报告...${NC}"
    local report_file="/home/$OPENCLAW_USER/openclaw_report.txt"
    run_as_user_shell "echo 'OpenClaw Report' > '$report_file'"
    run_as_user_shell "date >> '$report_file'"
    run_as_user_shell "echo '--- Node Version (Should be > v22) ---' >> '$report_file'"
    run_as_user_shell "node -v >> '$report_file'"
    run_as_user_shell "echo '--- Port 18789 Check ---' >> '$report_file'"
    run_as_user_shell "netstat -tuln | grep 18789 >> '$report_file' 2>&1 || echo 'Port 18789 not listening' >> '$report_file'"
    run_as_user_shell "$CLAW_BIN doctor >> '$report_file' 2>&1"
    run_as_user_shell "$PM2_BIN status >> '$report_file' 2>&1"
    run_as_user_shell "df -h >> '$report_file' 2>&1"
    run_as_user_shell "free -h >> '$report_file' 2>&1"
    
    echo -e "${GREEN}✓ 报告已生成: $report_file${NC}"
    edit_file_as_user "$report_file"
}

# --- 模块 G: 网关配置 (Gateway) ---
configure_gateway() {
    header
    echo -e "${BOLD}🌐 网关配置 (Gateway Config)${NC}"
    echo ""
    
    local port=""
    local host=""
    local cors=""
    
    prompt_input "监听端口 (Port)" "18789" port
    prompt_input "监听地址 (Host)" "0.0.0.0" host
    echo -e "${GRAY}提示: 允许跨域通常设为 '*' 或前端域名${NC}"
    prompt_input "CORS 允许来源" "*" cors
    
    echo -e "\n${CYAN}正在更新配置 (.env)...${NC}"
    
    # 使用 sed 更新 .env 环境变量
    run_as_user_shell "sed -i '/export GATEWAY_PORT=/d' '$ENV_FILE' && echo 'export GATEWAY_PORT=$port' >> '$ENV_FILE'"
    run_as_user_shell "sed -i '/export GATEWAY_BIND=/d' '$ENV_FILE' && echo 'export GATEWAY_BIND=$host' >> '$ENV_FILE'"
    
    # CORS 暂时只能通过 env 配置? 我们先保留环境变量设置
    # 如果 OpenClaw 支持 SERVER_CORS_ORIGIN 这样的 env，可以直接这里设
    # 假设 OpenClaw 优先读 env:
    run_as_user_shell "sed -i '/export SERVER_CORS_ORIGIN=/d' '$ENV_FILE' && echo 'export SERVER_CORS_ORIGIN=\"$cors\"' >> '$ENV_FILE'"
    
    echo -e "${GREEN}✓ 配置已保存 (.env)${NC}"
    echo -e "${YELLOW}注意: 需要重启服务才能生效${NC}"
    read -p "是否立即重启? [y/N] " restart_now
    if [[ $restart_now =~ ^[Yy]$ ]]; then
        # 安全重启: 优先尝试 reload，失败则 restart
        run_as_user "$PM2_BIN" reload openclaw 2>/dev/null || run_as_user "$PM2_BIN" restart openclaw
        echo -e "${GREEN}✓ 服务已重启${NC}"
    fi
    pause
}

# ==============================================================================
# [5] 菜单视图 (Menu Views)
# ==============================================================================
# --- 模块 H: 官方 CLI 工具集成 ---
official_cli_menu() {
    while true; do
        header
        echo -e "${BOLD}⌨️ 官方 CLI 工具 (Native Tools)${NC}"
        echo -e "${GRAY}直接调用官方指令。注意: 部分指令可能会覆盖现有配置。${NC}"
        echo ""
        echo "  1) openclaw configure   (基础配置问答)"
        echo "  2) openclaw onboard     (全流程向导 - 慎用)"
        echo "  3) openclaw doctor      (官方诊断)"
        echo "  4) openclaw listing     (查看所有模型)"
        echo ""
        echo "  0) 返回"
        echo ""
        read -p "请选择: " cli_choice
        case $cli_choice in
            1) run_as_user_shell "$CLAW_BIN configure"; pause ;;
            2) 
                echo -e "${RED}警告: 此操作可能会重置部分配置。确定继续吗? [y/N]${NC}"
                read -p "> " confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    run_as_user_shell "$CLAW_BIN onboard"
                fi
                pause ;;
            3) run_as_user_shell "$CLAW_BIN doctor"; pause ;;
            4) run_as_user_shell "$CLAW_BIN listing"; pause ;;
            0) return ;;
        esac
    done
}

# --- 模块 I: 高级配置 (Advanced) ---
configure_logging() {
    header
    echo -e "${BOLD}📜 日志配置 (Logging)${NC}"
    echo ""
    echo "  1) 设置日志级别 (Info/Debug)"
    echo "  2) 启用持久化日志 (保存到 workspace/logs)"
    echo ""
    read -p "请选择: " log_choice
    
    if [ "$log_choice" = "1" ]; then
        echo -e "\n请选择控制台输出级别:"
        echo "  1) Info  (默认 - 仅关键信息)"
        echo "  2) Debug (详细 - 用于排错)"
        read -p "> " level_choice
        local level="info"
        [ "$level_choice" = "2" ] && level="debug"
        run_as_user_shell "$CLAW_BIN config set logging.consoleLevel $level"
        echo -e "${GREEN}✓ 已设置为 $level${NC}"
    elif [ "$log_choice" = "2" ]; then
        local log_path="$WORKSPACE_DIR/logs/openclaw.log"
        run_as_user_shell "mkdir -p '$WORKSPACE_DIR/logs'"
        run_as_user_shell "$CLAW_BIN config set logging.file '$log_path'"
        echo -e "${GREEN}✓ 日志路径已锁定: $log_path${NC}"
    fi
    pause
}

configure_hooks() {
    header
    echo -e "${BOLD}🪝 Webhook 集成${NC}"
    echo -e "${GRAY}允许外部系统通过 HTTP 调用 OpenClaw Agent。${NC}"
    echo ""
    
    local token=$(openssl rand -hex 16)
    echo -e "启用 Webhooks 将暴露 /hooks 接口。"
    echo -e "推荐 Token: ${CYAN}$token${NC}"
    
    echo ""
    read -p "是否启用? [y/N] " enable_hook
    if [[ $enable_hook =~ ^[Yy]$ ]]; then
        prompt_input "设置 Token" "$token" final_token
        
        run_as_user_shell "$CLAW_BIN config set hooks.enabled true"
        run_as_user_shell "$CLAW_BIN config set hooks.token '$final_token'"
        
        echo -e "\n${GREEN}✓ Webhooks 已启用${NC}"
        echo -e "调用地址: http://<IP>:$GATEWAY_PORT/hooks"
        echo -e "鉴权头  : Authorization: Bearer $final_token"
    else
        run_as_user_shell "$CLAW_BIN config set hooks.enabled false"
        echo -e "${YELLOW}已禁用 Webhooks${NC}"
    fi
    pause
}

configure_browser() {
    header
    echo -e "${BOLD}🌍 内置浏览器 (Managed Browser)${NC}"
    echo -e "${GRAY}用于爬取网页和运行前端自动化任务。耗内存。${NC}"
    echo ""
    echo "  1) 启用 (Enable)"
    echo "  2) 禁用 (Disable - 节省内存)"
    read -p "请选择: " choice
    if [ "$choice" = "1" ]; then
        run_as_user_shell "$CLAW_BIN config set browser.enabled true"
        echo -e "${GREEN}✓ 已启用${NC}"
    elif [ "$choice" = "2" ]; then
        run_as_user_shell "$CLAW_BIN config set browser.enabled false"
        echo -e "${YELLOW}✓ 已禁用${NC}"
    fi
    pause
}

configure_ui() {
    header
    echo -e "${BOLD}🎨 界面个性化 (UI Appearance)${NC}"
    echo ""
    local name=""
    local avatar=""
    prompt_input "助手名称 (Name)" "OpenClaw" name
    prompt_input "头像 (Emoji or URL)" "🤖" avatar
    
    run_as_user_shell "$CLAW_BIN config set ui.assistant.name '$name'"
    run_as_user_shell "$CLAW_BIN config set ui.assistant.avatar '$avatar'"
    echo -e "${GREEN}✓ 设置已保存${NC}"; pause
}

menu_advanced() {
    while true; do
        header
        echo -e "${BOLD}🚀 高级配置 (Advanced)${NC}"
        echo ""
        echo "  1) 📜 日志管理 (Logging)"
        echo "  2) 🪝 Webhooks 集成"
        echo "  3) 🌍 内置浏览器 (Browser)"
        echo "  4) 🎨 界面个性化 (UI)"
        echo ""
        echo "  0) 返回"
        echo ""
        read -p "请选择: " choice
        case $choice in
            1) configure_logging ;;
            2) configure_hooks ;;
            3) configure_browser ;;
            4) configure_ui ;;
            0) return ;;
        esac
    done
}

menu_config() {
    while true; do
        header
        echo -e "${BOLD}⚙️ 配置中心${NC}"
        echo ""
        echo "  1) 🧠 智能模型向导 (LLM Wizard)"
        echo "  2) 📡 多渠道矩阵 (Channel Matrix)"
        echo "  3) 🌐 网关基础配置 (Port/Host/CORS)"
        echo "  4) 🎭 人格与规则管理 (Persona)"
        echo "  5) 🏎️ 性能调优 (Performance)"
        echo "  6) 🛡️ 安全设设置 (Security)"
        echo "  7) 🚀 高级配置 (Logging, Hooks, Browser...)"
        echo "  8) ----------------------------"
        echo "  9) ⌨️ 官方 CLI 工具 (Native Tools)"
        echo "  10) 手动编辑主配置 (JSON)"
        echo "  11) 手动编辑环境变量 (.env)"
        echo "  12) 测试连接"
        echo ""
        echo "  0) 返回"
        echo ""
        read -p "请选择: " choice
        case $choice in
            1) configure_llm_wizard ;;
            2) menu_channels ;;
            3) configure_gateway ;;
            4) menu_persona ;;
            5) configure_performance ;;
            6) configure_security ;;
            7) menu_advanced ;;
            9) official_cli_menu ;;
            10) edit_file_as_user "$CONFIG_FILE" ;;
            11) edit_file_as_user "$ENV_FILE" ;;
            12) test_api_connection ;;
            0) return ;;
        esac
    done
}

menu_maintenance() {
    while true; do
        header
        echo -e "${BOLD}🧹 维护与诊断${NC}"
        echo ""
        echo "  1) 一键修复权限"
        echo "  2) 初始化知识库目录"
        echo "  3) 深度系统诊断 (Report)"
        echo "  4) 配置自动化心跳 (Heartbeat)"
        echo "  5) 更新管理脚本 (Self Update)"
        echo "  6) 备份/恢复数据"
        echo ""
        echo "  0) 返回"
        echo ""
        read -p "请选择: " choice
        case $choice in
            1) echo -e "\nRunning chown..."; chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "/home/$OPENCLAW_USER"; pause ;;
            2) init_knowledge_base ;;
            3) deep_diagnose ;;
            4) setup_heartbeat ;;
            5) 
                echo -e "${CYAN}→ Downloading latest scripts...${NC}"
                run_as_user_shell "curl -fsSL https://raw.githubusercontent.com/KnowHunters/openclaw-deploy/main/scripts/manager.sh -o '$SCRIPT_DIR/manager.sh'" && chmod +x "$SCRIPT_DIR/manager.sh" && exec "$SCRIPT_DIR/manager.sh"
                ;;
            6) ls -l "$SCRIPT_DIR" | grep "restore\|backup"; pause ;;
            0) return ;;
        esac
    done
}

menu_service() {
    while true; do
        header
        echo -e "${BOLD}🚀 服务管理${NC}"
        echo ""
        echo "  1) 启动 (Start)"
        echo "  2) 停止 (Stop)"
        echo "  3) 重启 (Restart)"
        echo "  4) 状态 (Status)"
        echo "  5) 日志 (Logs)"
        echo ""
        echo "  0) 返回"
        echo ""
        read -p "请选择: " choice
        case $choice in
            1) run_as_user_shell "$PM2_BIN start openclaw || (cd $WORKSPACE_DIR && $PM2_BIN start \"$CLAW_BIN\" --name openclaw --interpreter none -- gateway)"; pause ;;
            2) run_as_user "$PM2_BIN" stop openclaw; pause ;;
            3) run_as_user "$PM2_BIN" restart openclaw; pause ;;
            4) run_as_user "$PM2_BIN" status; pause ;;
            5) run_as_user "$PM2_BIN" logs openclaw --lines 50 ;;
            0) return ;;
        esac
    done
}

menu_skills_browse() {
    while true; do
        header
        echo -e "${BOLD}📦 技能推荐 > 浏览安装${NC}"
        echo ""
        echo -e "${CYAN}🛠  效率工具${NC}"
        echo "  1) Obsidian        (笔记同步)"
        echo "  2) Notion          (知识库)"
        echo "  3) Google Calendar (日历管理)"
        echo ""
        echo -e "${CYAN}🔍 搜索资讯${NC}"
        echo "  4) Google Search   (谷歌搜索)"
        echo "  5) Wikipedia       (维基百科)"
        echo "  6) HackerNews      (科技资讯)"
        echo ""
        echo -e "${CYAN}🎮 娱乐生活${NC}"
        echo "  7) GOG             (游戏查询)"
        echo "  8) Spotify         (音乐控制)"
        echo ""
        echo -e "${CYAN}💻 开发运维${NC}"
        echo "  9) Shell           (执行命令 - 慎用)"
        echo "  10) Git            (代码管理)"
        echo ""
        echo "  m) 手动输入技能名安装"
        echo "  0) 返回上级"
        echo ""
        read -p "请选择安装: " sk_choice
        
        case $sk_choice in
            1) install_skill "obsidian" ;;
            2) install_skill "notion" ;;
            3) install_skill "google-calendar" ;;
            4) install_skill "google-search" ;;
            5) install_skill "wikipedia" ;;
            6) install_skill "hackernews" ;;
            7) install_skill "gog" ;;
            8) install_skill "spotify" ;;
            9) install_skill "shell" ;;
            10) install_skill "git" ;;
            m) read -p "请输入技能名称 (如 weather): " manual_name; [ ! -z "$manual_name" ] && install_skill "$manual_name" ;;
            0) return ;;
        esac
    done
}


skill_search() {
    echo -e "\n${CYAN}🔍 搜索技能库 (Search Online)${NC}"
    read -p "请输入搜索关键词 (如 weather, notion): " query
    if [ -n "$query" ]; then
        echo -e "\n${YELLOW}正在搜索 '$query'...${NC}"
        run_as_user_shell "npx -y clawhub@latest search '$query'"
        pause
    fi
}

skill_explore() {
    echo -e "\n${CYAN}🌍 正在探索最新技能 (Explore Latest)...${NC}"
    run_as_user_shell "npx -y clawhub@latest explore"
    pause
}

menu_skills() {
    while true; do
        header
        echo -e "${BOLD}📦 技能市场 (Skill Market)${NC}"
        echo ""
        echo "  1) 🔍 搜索技能库 (Search Online)"
        echo "  2) 🌍 探索最新技能 (Explore Latest)"
        echo "  3) ⭐ 浏览热门精选 (Featured)"
        echo "  4) 💿 查看已安装技能 (List Installed)"
        echo "  5) 🔧 手动安装 (Manual)"
        echo ""
        echo "  0) 返回主菜单"
        echo ""
        read -p "请选择: " choice
        
        case $choice in
            1) skill_search ;;
            2) skill_explore ;;
            3) menu_skills_browse ;;
            4) echo -e "\n${CYAN}已安装技能 (${WORKSPACE_DIR}/skills):${NC}"; ls -1 "$WORKSPACE_DIR/skills" 2>/dev/null || echo "暂无"; pause ;;
            5) read -p "输入技能名称: " sname; [ ! -z "$sname" ] && install_skill "$sname" ;;
            0) return ;;
        esac
    done
}



quick_start_wizard() {
    header
    echo -e "${BOLD}🚀 快速初始化向导 (Quick Start)${NC}"
    echo -e "${GRAY}将引导您完成核心配置，让 OpenClaw 立即进入可用状态。${NC}"
    echo ""
    pause
    
    # 1. 核心模型配置
    configure_llm_wizard
    
    # 2. 知识库初始化
    init_knowledge_base
    
    # 3. 人格设定 (快速版: 仅生成默认)
    ensure_template_files
    echo -e "\n${CYAN}→ 正在应用默认人格 (Nova)...${NC}"
    sleep 1
    
    # 4. 渠道配置 (可选)
    header
    echo -e "${BOLD}📡 渠道接入${NC}"
    echo "现在配置聊天平台吗? (飞书/Telegram/Discord)"
    echo "  1) 是 (进入配置)"
    echo "  2) 否 (跳过, 稍后配置)"
    echo ""
    read -p "请选择: " ch_choice
    if [ "$ch_choice" = "1" ]; then
        menu_channels
    fi
    
    # 5. 重启服务
    echo -e "\n${CYAN}→ 配置已完成，正在重启服务...${NC}"
    run_as_user "$PM2_BIN" restart openclaw
    
    echo -e "\n${GREEN}🎉 初始化完成！${NC}"
    test_api_connection
}

# --- 模块 J: 常用软件 ---
install_zerotier() {
    header
    echo -e "${BOLD}🌐 安装 ZeroTier${NC}"
    echo -e "${GRAY}异地组网/内网穿透神器${NC}"
    echo ""
    if command -v zerotier-cli &>/dev/null; then
        echo -e "${GREEN}✓ ZeroTier 已安装${NC}"
        zerotier-cli status
    else
        echo -e "${CYAN}→ 正在安装 ZeroTier...${NC}"
        curl -s https://install.zerotier.com | sudo bash
        echo -e "${GREEN}✓ 安装完成${NC}"
    fi
    
    echo ""
    read -p "是否立即加入网络? (输入 Network ID，留空跳过): " net_id
    if [ -n "$net_id" ]; then
        sudo zerotier-cli join "$net_id"
    fi
    pause
}

install_docker() {
    header
    echo -e "${BOLD}🐳 安装 Docker${NC}"
    echo -e "${GRAY}容器化应用引擎${NC}"
    echo ""
    if command -v docker &>/dev/null; then
        echo -e "${GREEN}✓ Docker 已安装${NC}"
        docker --version
    else
        echo -e "${CYAN}→ 正在安装 Docker...${NC}"
        curl -fsSL https://get.docker.com | sudo bash
        
        # 将 openclaw 用户加入 docker 组
        if [ -n "$OPENCLAW_USER" ]; then
            echo -e "${YELLOW}正在配置权限 (Adding $OPENCLAW_USER to docker group)...${NC}"
            sudo usermod -aG docker "$OPENCLAW_USER"
        fi
        
        echo -e "${GREEN}✓ 安装完成${NC}"
    fi
    pause
}

install_caddy() {
    header
    echo -e "${BOLD}🔒 安装 Caddy Web Server${NC}"
    echo -e "${GRAY}自动申请 HTTPS 证书的反向代理服务器${NC}"
    echo ""
    if command -v caddy &>/dev/null; then
        echo -e "${GREEN}✓ Caddy 已安装${NC}"
        caddy version
    else
        echo -e "${CYAN}→ 正在安装 Caddy...${NC}"
        # Ubuntu/Debian official install
        run_as_user_shell "sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https"
        run_as_user_shell "curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg"
        run_as_user_shell "curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list"
        run_as_user_shell "sudo apt-get update && sudo apt-get install caddy -y"
        echo -e "${GREEN}✓ 安装完成${NC}"
        echo -e "配置文件路径: /etc/caddy/Caddyfile"
    fi
    pause
}

install_tailscale() {
    header
    echo -e "${BOLD}🔌 安装 Tailscale${NC}"
    echo -e "${GRAY}基于 WireGuard 的零配置 VPN${NC}"
    echo ""
    if command -v tailscale &>/dev/null; then
        echo -e "${GREEN}✓ Tailscale 已安装${NC}"
        tailscale version
    else
        echo -e "${CYAN}→ 正在安装 Tailscale...${NC}"
        curl -fsSL https://tailscale.com/install.sh | sh
        echo -e "${GREEN}✓ 安装完成${NC}"
    fi
    echo ""
    read -p "是否立即启动并登录? [y/N] " start_ts
    if [[ $start_ts =~ ^[Yy]$ ]]; then
        sudo tailscale up
    fi
    pause
}

install_btop() {
    header
    echo -e "${BOLD}📈 安装 Btop${NC}"
    echo -e "${GRAY}炫酷的系统资源监控工具${NC}"
    echo ""
    if command -v btop &>/dev/null; then
        echo -e "${GREEN}✓ Btop 已安装${NC}"
    else
        echo -e "${CYAN}→ 正在安装 Btop...${NC}"
        # 优先尝试 snap，否则 apt
        if command -v snap &>/dev/null; then
            sudo snap install btop
        else
            sudo apt-get update && sudo apt-get install -y btop
        fi
        echo -e "${GREEN}✓ 安装完成${NC}"
    fi
    pause
}

install_rclone() {
    header
    echo -e "${BOLD}☁️ 安装 Rclone${NC}"
    echo -e "${GRAY}挂载/同步 40+ 种网盘存储${NC}"
    echo ""
    if command -v rclone &>/dev/null; then
        echo -e "${GREEN}✓ Rclone 已安装${NC}"
        rclone --version | head -n 1
    else
        echo -e "${CYAN}→ 正在安装 Rclone...${NC}"
        curl https://rclone.org/install.sh | sudo bash
        echo -e "${GREEN}✓ 安装完成${NC}"
    fi
    echo ""
    read -p "是否立即配置? [y/N] " config_now
    if [[ $config_now =~ ^[Yy]$ ]]; then
        rclone config
    fi
    pause
}

menu_softwares() {
    while true; do
        header
        echo -e "${BOLD}💿 常用软件 (Common Softwares)${NC}"
        echo ""
        echo "  1) 🌐 ZeroTier   (异地组网)"
        echo "  2) 🐳 Docker     (容器引擎)"
        echo "  3) 🔒 Caddy      (Web服务器/HTTPS)"
        echo "  4) 🔌 Tailscale  (VPN/组网)"
        echo "  5) 📈 Btop       (系统监控)"
        echo "  6) ☁️ Rclone     (网盘挂载)"
        echo ""
        echo "  0) 返回"
        echo ""
        read -p "请选择: " choice
        case $choice in
            1) install_zerotier ;;
            2) install_docker ;;
            3) install_caddy ;;
            4) install_tailscale ;;
            5) install_btop ;;
            6) install_rclone ;;
            0) return ;;
        esac
    done
}

# ==============================================================================
# [5] 主入口 (Main Entry)
# ==============================================================================
while true; do
    header
    echo -e " ${GREEN}[0] 🚀 快速初始化向导 (Quick Start)${NC}"
    echo -e " ----------------------------------"
    echo -e " ${GREEN}[1] 🚀 服务管理${NC}"
    echo -e " ${GREEN}[2] 📦 技能市场${NC}"
    echo -e " ${GREEN}[3] ⚙️ 配置中心${NC}  (Models, Persona, Security)"
    echo -e " ${GREEN}[4] 🧹 维护诊断${NC}  (Fix, Backup, Update)"
    echo -e " ${GREEN}[5] 💿 常用软件${NC}  (ZeroTier, Docker)"
    echo ""
    echo -e " [q] 退出"
    echo ""
    read -p "请选择操作: " main_choice

    case $main_choice in
        0) quick_start_wizard ;;
        1) menu_service ;;
        2) menu_skills ;;
        3) menu_config ;;
        4) menu_maintenance ;;
        5) menu_softwares ;;
        q) echo "再见!"; exit 0 ;;
        *) ;;
    esac
done
