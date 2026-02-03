#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  OpenClaw Admin Panel v1.1                                                   ║
# ║  功能: 管理服务、市场、配置、监控的全能面板                                  ║
# ║  作者: KnowHunters (知识猎人)                                                ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# 全局配置
OPENCLAW_USER="${OPENCLAW_USER:-openclaw}"
WORKSPACE_DIR="${WORKSPACE_DIR:-/home/$OPENCLAW_USER/openclaw-bot}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="/home/$OPENCLAW_USER/.openclaw/openclaw.json"
ENV_FILE="$WORKSPACE_DIR/.env"

# 颜色定义
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

# ════════════════════ 辅助工具 ════════════════════
pause() {
    echo ""
    read -p "按回车键继续..."
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
    echo "║                    管 理 面 板                            ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # 状态栏
    local pm2_status=$(sudo -u "$OPENCLAW_USER" pm2 jlist | grep -q "online" && echo -e "${GREEN}● 运行中${NC}" || echo -e "${RED}● 已停止${NC}")
    local mem_usage=$(free -h | awk 'NR==2{print $3 "/" $2}')
    local load_avg=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d, -f1)
    
    echo -e " ${BOLD}状态${NC}: $pm2_status  |  ${BOLD}内存${NC}: ${GRAY}$mem_usage${NC}  |  ${BOLD}负载${NC}: ${GRAY}$load_avg${NC}"
    echo -e "${GRAY}───────────────────────────────────────────────────────────────────────${NC}"
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

run_as_user() {
    sudo -u "$OPENCLAW_USER" "$@"
}

run_as_user_shell() {
    su - "$OPENCLAW_USER" -c "$1"
}

# ════════════════════ 1. 服务管理 ════════════════════
menu_service() {
    while true; do
        header
        echo -e "${BOLD}🚀 服务管理${NC}"
        echo ""
        echo "  1) 启动服务 (Start)"
        echo "  2) 停止服务 (Stop)"
        echo "  3) 重启服务 (Restart)"
        echo "  4) 查看详细状态"
        echo "  5) 实时日志 (Logs)"
        echo ""
        echo "  0) 返回主菜单"
        echo ""
        read -p "请选择: " choice
        
        case $choice in
            1) 
                echo -e "\n${CYAN}→ 启动服务...${NC}"
                run_as_user_shell "pm2 start openclaw || (cd $WORKSPACE_DIR && pm2 start npm --name openclaw -- start)"
                pause ;;
            2) 
                echo -e "\n${CYAN}→ 停止服务...${NC}"
                run_as_user pm2 stop openclaw
                pause ;;
            3) 
                echo -e "\n${CYAN}→ 重启服务...${NC}"
                run_as_user pm2 restart openclaw
                pause ;;
            4) 
                run_as_user pm2 status
                pause ;;
            5) 
                echo -e "\n${CYAN}→ 按 Ctrl+C 退出日志${NC}"
                run_as_user pm2 logs openclaw --lines 50
                ;;
            0) return ;;
            *) ;;
        esac
    done
}

# ════════════════════ 2. 技能市场 ════════════════════
install_skill() {
    local skill_name=$1
    echo -e "\n${CYAN}→ 正在安装技能: ${BOLD}$skill_name${NC}"
    
    # 检查 clawhub 是否可用，不可用则先安装
    if ! run_as_user_shell "npm list -g clawhub >/dev/null 2>&1"; then
        echo -e "${YELLOW}正在初始化技能安装器...${NC}"
        run_as_user_shell "npm install -g clawhub"
    fi
    
    run_as_user_shell "npx -y clawhub@latest install $skill_name"
    
    echo -e "${GREEN}✓ 安装指令已下达${NC}"
    echo -e "${YELLOW}注意: 安装后建议重启 OpenClaw 服务以生效${NC}"
    pause
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
            m) 
                read -p "请输入技能名称 (如 weather): " manual_name
                [ ! -z "$manual_name" ] && install_skill "$manual_name"
                ;;
            0) return ;;
        esac
    done
}

menu_skills() {
    while true; do
        header
        echo -e "${BOLD}📦 技能市场 (Skill Market)${NC}"
        echo ""
        echo "  1) 浏览热门推荐 (Browse Popular)"
        echo "  2) 手动安装技能 (Install Manually)"
        echo "  3) 查看已安装技能 (List Installed)"
        echo ""
        echo "  0) 返回主菜单"
        echo ""
        read -p "请选择: " choice
        
        case $choice in
            1) menu_skills_browse ;;
            2) 
                read -p "请输入技能名称: " sname
                [ ! -z "$sname" ] && install_skill "$sname"
                ;;
            3)
                echo -e "\n${CYAN}已安装技能目录 (${WORKSPACE_DIR}/skills):${NC}"
                ls -1 "$WORKSPACE_DIR/skills" 2>/dev/null || echo "暂无已安装技能"
                pause
                ;;
            0) return ;;
        esac
    done
}

# ════════════════════ 3. 配置中心 ════════════════════
edit_file_as_user() {
    local file=$1
    ensure_nano
    echo -e "${YELLOW}正在打开编辑器... (Ctrl+O 保存, Ctrl+X 退出)${NC}"
    sleep 1
    # 使用 su -c 调用 nano，确保以 openclaw 用户身份编辑，避免权限问题
    su - "$OPENCLAW_USER" -c "nano '$file'"
}

prompt_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    echo -ne "${YELLOW}$prompt${NC} [默认: $default]: "
    read input
    eval $var_name="\${input:-$default}"
}

configure_custom_provider() {
    local provider_id="$1"
    local base_url="$2"
    local api_key="$3"
    local model_id="$4"
    
    echo -e "\n${CYAN}正在配置自定义提供商: $provider_id...${NC}"
    
    # 使用 Node.js 脚本修改 openclaw.json，避免 sed 复杂操作
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
            models: [{ 
                id: '$model_id',
                name: '$model_id',
                contextWindow: 128000,
                maxTokens: 16384
            }]
        };
        fs.writeFileSync(configFile, JSON.stringify(config, null, 2));
        console.log('配置已更新');
    } catch (e) { console.error('配置失败:', e); process.exit(1); }
    \""
}

test_api_connection() {
    echo -e "\n${CYAN}⏳ 正在测试 API 连接 (发送 'Hello')...${NC}"
    if run_as_user_shell "timeout 20 openclaw agent --local --message 'Hello' >/dev/null 2>&1"; then
        echo -e "${GREEN}✓ 连接测试成功！API 配置有效。${NC}"
    else
        echo -e "${RED}✗ 连接测试失败。请检查 API Key 或 BaseURL 是否正确。${NC}"
        echo -e "${GRAY}提示: 您可以稍后使用 'openclaw doctor' 进行深度诊断。${NC}"
    fi
    pause
}

configure_llm_wizard() {
    header
    echo -e "${BOLD}🧠 智能模型配置向导 (Smart LLM Wizard)${NC}"
    echo ""
    echo "  1) 🟣 Anthropic (Claude)"
    echo "  2) 🟢 OpenAI (GPT)"
    echo "  3) 🔵 DeepSeek (深度求索)"
    echo "  4) 🌙 Kimi (Moonshot)"
    echo "  5) 🔴 Google (Gemini)"
    echo "  6) 🔄 OpenRouter"
    echo "  7) ⚡ Groq"
    echo "  8) 🟠 Ollama (本地)"
    echo "  9) 🛠  自定义 (Custom - 任意兼容 API)"
    echo ""
    echo "  0) 返回"
    echo ""
    read -p "请选择提供商: " p_choice
    
    local provider=""
    local provider_id=""
    local default_url=""
    local default_model=""
    local env_prefix=""
    
    case $p_choice in
        1) provider="anthropic"; env_prefix="ANTHROPIC"; default_model="claude-3-5-sonnet-20240620" ;;
        2) provider="openai"; env_prefix="OPENAI"; default_model="gpt-4o" ;;
        3) provider="deepseek"; env_prefix="DEEPSEEK"; default_url="https://api.deepseek.com"; default_model="deepseek-chat" ;;
        4) provider="kimi"; env_prefix="MOONSHOT"; default_url="https://api.moonshot.cn/v1"; default_model="moonshot-v1-8k" ;;
        5) provider="google"; env_prefix="GOOGLE"; default_model="gemini-1.5-pro" ;;
        6) provider="openrouter"; env_prefix="OPENAI"; default_url="https://openrouter.ai/api/v1"; default_model="anthropic/claude-3-5-sonnet" ;;
        7) provider="groq"; env_prefix="OPENAI"; default_url="https://api.groq.com/openai/v1"; default_model="llama3-70b-8192" ;;
        8) provider="ollama"; env_prefix="OLLAMA"; default_url="http://localhost:11434"; default_model="llama3" ;;
        9) provider="custom";;
        0) return ;;
        *) echo "无效选择"; pause; return ;;
    esac

    echo ""
    local api_key=""
    local base_url=""
    local model_id=""
    
    # 1. Base URL
    if [ "$provider" == "custom" ]; then
        prompt_input "API Base URL" "https://api.openai.com/v1" base_url
        prompt_input "API Key" "" api_key
        prompt_input "模型名称 (Model ID)" "gpt-4" model_id
        # 自定义模式下，我们将创建一个名为 'custom-llm' 的 provider
        configure_custom_provider "custom-llm" "$base_url" "$api_key" "$model_id"
        
        # 设置默认模型
        run_as_user_shell "openclaw models set custom-llm/$model_id"
        
    elif [ "$provider" == "ollama" ]; then
         prompt_input "Ollama URL" "$default_url" base_url
         prompt_input "模型名称" "$default_model" model_id
         
         # 写入 .env
         run_as_user_shell "sed -i '/export OLLAMA_HOST=/d' '$ENV_FILE' && echo 'export OLLAMA_HOST=$base_url' >> '$ENV_FILE'"
         run_as_user_shell "openclaw models set ollama/$model_id"
         
    else
        # 标准提供商
        if [ -n "$default_url" ]; then
             prompt_input "API Base URL (留空用默认)" "$default_url" base_url
        fi
        prompt_input "API Key" "" api_key
        prompt_input "模型名称" "$default_model" model_id
        
        # 写入 .env
        local key_var="${env_prefix}_API_KEY"
        local url_var="${env_prefix}_BASE_URL"
        
        # 删除旧变量并追加新变量
        run_as_user_shell "sed -i '/export $key_var=/d' '$ENV_FILE' && echo 'export $key_var=$api_key' >> '$ENV_FILE'"
        if [ -n "$base_url" ]; then
            run_as_user_shell "sed -i '/export $url_var=/d' '$ENV_FILE' && echo 'export $url_var=$base_url' >> '$ENV_FILE'"
        fi
        
        # 设置默认模型
        run_as_user_shell "openclaw models set $provider/$model_id"
    fi
    
    echo -e "${GREEN}✓ 配置已保存${NC}"
    
    # 询问是否测试
    echo ""
    read -p "是否立即测试连接? [Y/n] " t_choice
    case $t_choice in 
        [yY]*) test_api_connection ;;
    esac
}

configure_identity() {
    header
    echo -e "${BOLD}🆔 身份与个性化设置${NC}"
    echo ""
    
    local bot_name=""
    local user_name=""
    local timezone=""
    
    prompt_input "机器人名字 (Bot Name)" "Clawd" bot_name
    prompt_input "你的称呼 (User Name)" "Master" user_name
    prompt_input "系统时区" "Asia/Shanghai" timezone
    
    # 更新配置 (使用 openclaw config set)
    echo -e "\n${CYAN}正在更新配置...${NC}"
    run_as_user_shell "openclaw config set agent.name '$bot_name'"
    run_as_user_shell "openclaw config set user.name '$user_name'"
    
    # 更改时区需要 root 权限
    if [ -n "$timezone" ]; then
        if sudo timedatectl set-timezone "$timezone" 2>/dev/null; then
            echo -e "${GREEN}✓ 时区已设置为 $timezone${NC}"
        else
            echo -e "${RED}✗ 时区设置失败${NC}"
        fi
    fi
    
    echo -e "${GREEN}✓ 身份信息更新完成${NC}"
    pause
}

menu_config() {
    while true; do
        header
        echo -e "${BOLD}⚙️ 配置中心${NC}"
        echo ""
        echo "  1) 智能模型配置向导 (Smart LLM Wizard)"
        echo "  2) 身份与个性化设置 (Identity)"
        echo "  3) --------------------------------"
        echo "  4) 手动编辑主配置 (Nano)"
        echo "  5) 手动编辑环境变量 (Nano)"
        echo "  6) 测试 API 连接"
        echo ""
        echo "  0) 返回主菜单"
        echo ""
        read -p "请选择: " choice
        
        case $choice in
            1) configure_llm_wizard ;;
            2) configure_identity ;;
            4) edit_file_as_user "$CONFIG_FILE" ;;
            5) edit_file_as_user "$ENV_FILE" ;;
            6) test_api_connection ;;
            0) return ;;
            *) ;;
        esac
    done
}

# ════════════════════ 4. 维护工具 ════════════════════
fix_permissions() {
    echo -e "\n${CYAN}→ 正在修复文件权限...${NC}"
    chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "/home/$OPENCLAW_USER"
    chmod 755 "/home/$OPENCLAW_USER"
    echo -e "${GREEN}✓ 权限修复完成${NC}"
    pause
}

update_scripts() {
    echo -e "\n${CYAN}→ 正在更新管理脚本套件...${NC}"
    local scripts=("health-monitor.sh" "log-cleanup.sh" "backup.sh" "restore.sh" "manager.sh" "lazy-optimize.sh")
    local base_url="https://raw.githubusercontent.com/KnowHunters/openclaw-deploy/main/scripts"
    
    for script in "${scripts[@]}"; do
        echo -ne "  下载 $script ... "
        if run_as_user_shell "curl -fsSL '$base_url/$script' -o '$SCRIPT_DIR/$script'"; then
            chmod +x "$SCRIPT_DIR/$script"
            chown "$OPENCLAW_USER:$OPENCLAW_USER" "$SCRIPT_DIR/$script"
            echo -e "${GREEN}[OK]${NC}"
        else
            echo -e "${RED}[Failed]${NC}"
        fi
    done
    
    echo -e "${GREEN}✓ 所有脚本已更新至最新版本${NC}"
    echo -e "${YELLOW}即将重启管理面板...${NC}"
    sleep 2
    exec "$SCRIPT_DIR/manager.sh"
}

menu_maintenance() {
    while true; do
        header
        echo -e "${BOLD}🧹 维护与诊断${NC}"
        echo ""
        echo "  1) 一键修复权限 (Fix Permissions)"
        echo "  2) 清理日志文件 (Clean Logs)"
        echo "  3) 运行系统诊断 (Doctor)"
        echo "  4) 一键懒人优化 (Lazy Optimize)"
        echo "  5) 备份与恢复 (Backup/Restore)"
        echo "  6) 更新 OpenClaw (App Update)"
        echo "  7) 更新管理脚本 (Self Update)"
        echo ""
        echo "  0) 返回主菜单"
        echo ""
        read -p "请选择: " choice
        
        case $choice in
            1) fix_permissions ;;
            2) 
                [ -f "$SCRIPT_DIR/log-cleanup.sh" ] && bash "$SCRIPT_DIR/log-cleanup.sh" || echo "脚本丢失"
                pause ;;
            3) 
                echo -e "\n${CYAN}→ 运行 Doctor...${NC}"
                run_as_user_shell "openclaw doctor"
                pause ;;
            4) 
                [ -f "$SCRIPT_DIR/lazy-optimize.sh" ] && sudo bash "$SCRIPT_DIR/lazy-optimize.sh" || echo "脚本丢失"
                pause ;;
            5) 
                echo -e "\n${YELLOW}请使用子菜单脚本: backup.sh / restore.sh${NC}"
                ls -l "$SCRIPT_DIR" | grep "restore\|backup"
                pause ;;
            6)
                echo -e "\n${CYAN}→ 更新 OpenClaw...${NC}"
                npm install -g @openclaw/cli@latest
                run_as_user_shell "cd $WORKSPACE_DIR && npm update"
                run_as_user pm2 restart openclaw
                echo -e "${GREEN}✓ 更新完成${NC}"
                pause ;;
            7) update_scripts ;;
            0) return ;;
        esac
    done
}

# ════════════════════ 主入口 ════════════════════
while true; do
    header
    echo -e " ${GREEN}[1] 🚀 服务管理${NC}      (Start, Stop, Logs)"
    echo -e " ${GREEN}[2] 📦 技能市场${NC}      (Install Skills)"
    echo -e " ${GREEN}[3] ⚙️ 配置中心${NC}      (Edit Config)"
    echo -e " ${GREEN}[4] 🧹 维护与诊断${NC}    (Fix, Doctor, Update)"
    echo ""
    echo -e " [0] 退出"
    echo ""
    read -p "请选择操作 [0-4]: " main_choice

    case $main_choice in
        1) menu_service ;;
        2) menu_skills ;;
        3) menu_config ;;
        4) menu_maintenance ;;
        0) echo "再见!"; exit 0 ;;
        *) ;;
    esac
done
