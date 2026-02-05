#!/bin/bash
# ============================================================================
# OpenClaw Deploy 2.0 - Configuration Wizard
# ============================================================================
# 交互式配置向导，引导用户完成 OpenClaw 配置
# ============================================================================

# 防止重复加载
[[ -n "$_WIZARD_LOADED" ]] && return 0
_WIZARD_LOADED=1

# ============================================================================
# 配置变量
# ============================================================================

# Provider 配置
declare -A CONFIG_PROVIDERS=()
declare -a CONFIG_PROVIDER_LIST=()

# 模型配置
CONFIG_PRIMARY_MODEL=""
CONFIG_FALLBACK_MODELS=()

# 频道配置
declare -A CONFIG_CHANNELS=()

# Gateway 配置
CONFIG_GATEWAY_PORT=18789
CONFIG_GATEWAY_BIND="127.0.0.1"
CONFIG_GATEWAY_TOKEN=""

# 优化配置
CONFIG_CONTEXT_TOKENS=50000
CONFIG_HEARTBEAT_INTERVAL="30m"
CONFIG_CACHE_TTL=3600

# ============================================================================
# 主入口: 运行配置向导
# ============================================================================

run_config_wizard() {
    ui_clear
    ui_show_banner "$DEPLOY_VERSION"
    
    # 检查 CLI 是否已安装
    local cli_name="openclaw"
    [[ "$INSTALL_VERSION" == "chinese" ]] && cli_name="openclaw-cn"
    
    if ! command_exists "$cli_name"; then
        if ui_confirm "未检测到 OpenClaw CLI，是否先安装?" "y"; then
            install_openclaw_cli
        else
            return 1
        fi
    fi
    
    # 提示用户
    ui_panel "配置向导说明" \
        "OpenClaw onboard 配置完成后会自动启动 Web 后台。" \
        "当您完成配置并看到 'Web interface started' 提示后，" \
        "${C_WARNING}请按 [Ctrl+C] 停止 onboard${C_RESET}，脚本将自动继续后续步骤。" \
        "(如权限修正、Systemd 服务注册等)"
        
    ui_wait_key "按任意键启动配置..."
    
    # 运行原生 onboard
    echo "启动配置工具..."
    
    # 临时忽略 INT 信号 (在此脚本层面)，让 onboard 接收 Ctrl+C 退出
    # 而 deploy.sh 本身不退出，而是捕获错误码并继续
    trap '' INT
    
    set +e # 临时允许返回非零状态
    $cli_name onboard
    local exit_code=$?
    set -e # 恢复严格模式
    
    # 恢复原来的信号处理
    trap 'handle_interrupt' INT
    
    # 130 是 SIGINT (Ctrl+C)，我们将其视为用户正常完成配置后的退出
    if [[ $exit_code -eq 0 ]] || [[ $exit_code -eq 130 ]]; then
        log_success "配置步骤结束"
    else
        log_warning "onboard 异常退出 (Code: $exit_code)，尝试继续执行..."
    fi
    
    # 配置后增强
    echo ""
    ui_section_title "系统环境优化" "$EMOJI_GEAR"
    
    # 1. 权限修正
    ui_log_step "修正配置文件权限..."
    # 查找可能的配置文件位置
    local config_locations=(
        "$HOME/.openclaw/openclaw.json"
        "$HOME/.config/openclaw/openclaw.json"
        "./openclaw.json"
    )
    
    echo -e "  选择要配置的 AI Provider ${S_DIM}(可多选)${C_RESET}"
    echo ""
    
    ui_multi_select "选择 Provider" "${providers[@]}"
    
    if [[ ${#SELECTED_ITEMS[@]} -eq 0 ]]; then
        log_warning "至少需要配置一个 AI Provider"
        return 1
    fi
    
    # 配置每个选中的 Provider
    for idx in "${SELECTED_ITEMS[@]}"; do
        case $idx in
            0) configure_provider_anthropic ;;
            1) configure_provider_openai ;;
            2) configure_provider_deepseek ;;
            3) configure_provider_google ;;
            4) configure_provider_ollama ;;
        esac
    done
    
    return 0
}

# 配置 Anthropic
configure_provider_anthropic() {
    echo ""
    ui_divider
    echo -e "  ${S_BOLD}配置 Anthropic (Claude)${C_RESET}"
    echo ""
    
    ui_beginner_tip "获取 Anthropic API Key:
1. 访问 https://console.anthropic.com/
2. 注册或登录账号
3. 在 API Keys 页面创建新的 Key
4. 复制 Key (以 sk-ant- 开头)"
    
    local api_key=$(ui_input_secret "Anthropic API Key")
    
    if [[ -n "$api_key" ]]; then
        # 简单验证格式
        if [[ "$api_key" == sk-ant-* ]]; then
            CONFIG_PROVIDERS["anthropic"]="$api_key"
            CONFIG_PROVIDER_LIST+=("anthropic")
            log_success "Anthropic 配置成功"
        else
            log_warning "API Key 格式可能不正确，但已保存"
            CONFIG_PROVIDERS["anthropic"]="$api_key"
            CONFIG_PROVIDER_LIST+=("anthropic")
        fi
    fi
}

# 配置 OpenAI
configure_provider_openai() {
    echo ""
    ui_divider
    echo -e "  ${S_BOLD}配置 OpenAI (GPT)${C_RESET}"
    echo ""
    
    ui_beginner_tip "获取 OpenAI API Key:
1. 访问 https://platform.openai.com/
2. 注册或登录账号
3. 在 API Keys 页面创建新的 Key
4. 复制 Key (以 sk- 开头)"
    
    local api_key=$(ui_input_secret "OpenAI API Key")
    
    if [[ -n "$api_key" ]]; then
        CONFIG_PROVIDERS["openai"]="$api_key"
        CONFIG_PROVIDER_LIST+=("openai")
        log_success "OpenAI 配置成功"
    fi
}

# 配置 DeepSeek
configure_provider_deepseek() {
    echo ""
    ui_divider
    echo -e "  ${S_BOLD}配置 DeepSeek${C_RESET}"
    echo ""
    
    ui_beginner_tip "获取 DeepSeek API Key:
1. 访问 https://platform.deepseek.com/
2. 注册或登录账号
3. 在 API Keys 页面创建新的 Key
4. 复制 Key"
    
    local api_key=$(ui_input_secret "DeepSeek API Key")
    
    if [[ -n "$api_key" ]]; then
        CONFIG_PROVIDERS["deepseek"]="$api_key"
        CONFIG_PROVIDER_LIST+=("deepseek")
        log_success "DeepSeek 配置成功"
    fi
}

# 配置 Google
configure_provider_google() {
    echo ""
    ui_divider
    echo -e "  ${S_BOLD}配置 Google (Gemini)${C_RESET}"
    echo ""
    
    ui_beginner_tip "获取 Google API Key:
1. 访问 https://makersuite.google.com/app/apikey
2. 登录 Google 账号
3. 创建新的 API Key
4. 复制 Key"
    
    local api_key=$(ui_input_secret "Google API Key")
    
    if [[ -n "$api_key" ]]; then
        CONFIG_PROVIDERS["google"]="$api_key"
        CONFIG_PROVIDER_LIST+=("google")
        log_success "Google 配置成功"
    fi
}

# 配置 Ollama
configure_provider_ollama() {
    echo ""
    ui_divider
    echo -e "  ${S_BOLD}配置本地模型 (Ollama)${C_RESET}"
    echo ""
    
    ui_beginner_tip "Ollama 是本地运行的 AI 模型服务:
1. 访问 https://ollama.ai/ 下载安装
2. 运行 'ollama pull llama3.3' 下载模型
3. 确保 Ollama 服务在运行"
    
    local base_url=$(ui_input "Ollama 地址" "http://localhost:11434")
    
    CONFIG_PROVIDERS["ollama"]="$base_url"
    CONFIG_PROVIDER_LIST+=("ollama")
    log_success "Ollama 配置成功"
}

# ============================================================================
# 步骤 2: 模型选择
# ============================================================================

wizard_step_models() {
    ui_step_title 2 6 "选择 AI 模型"
    
    ui_beginner_tip "不同的模型有不同的能力和价格:
- Sonnet: 平衡性能和成本，推荐日常使用
- Haiku: 经济型，适合简单任务
- Opus: 最强性能，适合复杂任务
- GPT-5 Mini: OpenAI 经济型模型"
    
    # 根据配置的 Provider 生成可选模型
    local models=()
    local model_ids=()
    
    if [[ -n "${CONFIG_PROVIDERS[anthropic]}" ]]; then
        models+=("Claude Sonnet 4.5 (推荐，平衡性能和成本)")
        model_ids+=("anthropic/claude-sonnet-4-5")
        models+=("Claude Haiku 4 (经济型)")
        model_ids+=("anthropic/claude-haiku-4")
        models+=("Claude Opus 4.5 (最强性能)")
        model_ids+=("anthropic/claude-opus-4-5")
    fi
    
    if [[ -n "${CONFIG_PROVIDERS[openai]}" ]]; then
        models+=("GPT-5 Mini (OpenAI 经济型)")
        model_ids+=("openai/gpt-5-mini")
        models+=("GPT-5.2 (OpenAI 高性能)")
        model_ids+=("openai/gpt-5.2")
    fi
    
    if [[ -n "${CONFIG_PROVIDERS[deepseek]}" ]]; then
        models+=("DeepSeek Chat (性价比高)")
        model_ids+=("deepseek/deepseek-chat")
    fi
    
    if [[ -n "${CONFIG_PROVIDERS[google]}" ]]; then
        models+=("Gemini 3 Pro (Google)")
        model_ids+=("google/gemini-3-pro")
        models+=("Gemini 3 Flash (Google 快速)")
        model_ids+=("google/gemini-3-flash")
    fi
    
    if [[ -n "${CONFIG_PROVIDERS[ollama]}" ]]; then
        models+=("Llama 3.3 (本地)")
        model_ids+=("ollama/llama3.3")
    fi
    
    if [[ ${#models[@]} -eq 0 ]]; then
        log_error "没有可用的模型，请先配置 AI Provider"
        return 1
    fi
    
    # 选择主模型
    echo -e "  ${S_BOLD}选择主模型${C_RESET}"
    echo ""
    
    ui_select "主模型" "${models[@]}"
    local primary_choice=$?
    
    if [[ $primary_choice -lt ${#model_ids[@]} ]]; then
        CONFIG_PRIMARY_MODEL="${model_ids[$primary_choice]}"
        log_info "主模型: ${models[$primary_choice]}"
    fi
    
    # 选择备用模型
    echo ""
    echo -e "  ${S_BOLD}选择备用模型${C_RESET} ${S_DIM}(可选，当主模型不可用时使用)${C_RESET}"
    echo ""
    
    ui_multi_select "备用模型" "${models[@]}"
    
    for idx in "${SELECTED_ITEMS[@]}"; do
        if [[ $idx -ne $primary_choice ]]; then
            CONFIG_FALLBACK_MODELS+=("${model_ids[$idx]}")
        fi
    done
    
    if [[ ${#CONFIG_FALLBACK_MODELS[@]} -gt 0 ]]; then
        log_info "备用模型: ${#CONFIG_FALLBACK_MODELS[@]} 个"
    fi
    
    return 0
}

# ============================================================================
# 步骤 3: 频道配置
# ============================================================================

wizard_step_channels() {
    ui_step_title 3 6 "配置消息频道"
    
    ui_beginner_tip "频道是你与 AI 助手交流的方式:
- Telegram: 推荐，功能完整，需要创建 Bot
- WhatsApp: 需要扫码登录
- Discord: 适合团队使用
- 仅 Gateway: 通过本地 API 访问，适合开发"
    
    local channels=(
        "Telegram (推荐) - 需要 Bot Token"
        "WhatsApp - 需要扫码登录"
        "Discord - 需要 Bot Token"
        "仅 Gateway (本地 API) - 无需额外配置"
    )
    
    ui_multi_select "选择频道" "${channels[@]}"
    
    # 默认启用 Gateway
    CONFIG_CHANNELS["gateway"]="enabled"
    
    for idx in "${SELECTED_ITEMS[@]}"; do
        case $idx in
            0) configure_channel_telegram ;;
            1) configure_channel_whatsapp ;;
            2) configure_channel_discord ;;
            3) ;; # 仅 Gateway，无需配置
        esac
    done
    
    return 0
}

# 配置 Telegram
configure_channel_telegram() {
    echo ""
    ui_divider
    echo -e "  ${S_BOLD}配置 Telegram Bot${C_RESET}"
    echo ""
    
    ui_beginner_tip "创建 Telegram Bot:
1. 在 Telegram 中搜索 @BotFather
2. 发送 /newbot 创建新 Bot
3. 按提示设置 Bot 名称
4. 复制获得的 Token"
    
    local bot_token=$(ui_input_secret "Telegram Bot Token")
    
    if [[ -n "$bot_token" ]]; then
        CONFIG_CHANNELS["telegram"]="$bot_token"
        
        # 群组设置
        if ui_confirm "是否启用群组消息?" "n"; then
            CONFIG_CHANNELS["telegram_groups"]="enabled"
            
            if ui_confirm "群组中需要 @提及 才响应?" "y"; then
                CONFIG_CHANNELS["telegram_mention"]="required"
            fi
        fi
        
        log_success "Telegram 配置成功"
    fi
}

# 配置 WhatsApp
configure_channel_whatsapp() {
    echo ""
    ui_divider
    echo -e "  ${S_BOLD}配置 WhatsApp${C_RESET}"
    echo ""
    
    ui_beginner_tip "WhatsApp 配置:
启动 Gateway 后，运行 'openclaw channels login' 扫码登录"
    
    CONFIG_CHANNELS["whatsapp"]="enabled"
    
    local phone=$(ui_input "你的手机号 (用于白名单)" "")
    if [[ -n "$phone" ]]; then
        CONFIG_CHANNELS["whatsapp_allowfrom"]="$phone"
    fi
    
    log_success "WhatsApp 配置成功 (启动后需扫码)"
}

# 配置 Discord
configure_channel_discord() {
    echo ""
    ui_divider
    echo -e "  ${S_BOLD}配置 Discord Bot${C_RESET}"
    echo ""
    
    ui_beginner_tip "创建 Discord Bot:
1. 访问 https://discord.com/developers/applications
2. 创建新应用
3. 在 Bot 页面创建 Bot 并复制 Token
4. 在 OAuth2 页面生成邀请链接"
    
    local bot_token=$(ui_input_secret "Discord Bot Token")
    
    if [[ -n "$bot_token" ]]; then
        CONFIG_CHANNELS["discord"]="$bot_token"
        log_success "Discord 配置成功"
    fi
}

# ============================================================================
# 步骤 4: Gateway 配置
# ============================================================================

wizard_step_gateway() {
    ui_step_title 4 6 "配置 Gateway"
    
    ui_beginner_tip "Gateway 是 OpenClaw 的核心服务:
- 端口: 服务监听的端口号，默认 18789
- 绑定地址: 127.0.0.1 表示仅本地访问，更安全
- Token: 访问 Gateway 的密钥，自动生成"
    
    # 端口
    CONFIG_GATEWAY_PORT=$(ui_input_with_help "Gateway 端口" "18789" \
        "端口是网络通信的入口
默认 18789，如果被占用可以改为其他端口
有效范围: 1024-65535")
    
    # 绑定地址
    echo ""
    echo -e "  ${S_BOLD}绑定地址${C_RESET}"
    echo ""
    
    local bind_options=(
        "127.0.0.1 (仅本地访问，推荐)"
        "0.0.0.0 (允许外部访问，需要防火墙)"
    )
    
    ui_select "选择绑定地址" "${bind_options[@]}"
    local bind_choice=$?
    
    case $bind_choice in
        0) CONFIG_GATEWAY_BIND="127.0.0.1" ;;
        1)
            CONFIG_GATEWAY_BIND="0.0.0.0"
            ui_notice "绑定 0.0.0.0 会暴露到公网，请确保配置防火墙！"
            ;;
    esac
    
    # Token
    echo ""
    if ui_confirm "自动生成 Gateway Token?" "y"; then
        CONFIG_GATEWAY_TOKEN=$(generate_token 48)
        log_info "Token 已生成: ${CONFIG_GATEWAY_TOKEN:0:8}..."
    else
        CONFIG_GATEWAY_TOKEN=$(ui_input_secret "Gateway Token")
    fi
    
    return 0
}

# ============================================================================
# 步骤 5: 性能优化
# ============================================================================

wizard_step_optimization() {
    ui_step_title 5 6 "性能优化配置"
    
    ui_beginner_tip "这些设置可以帮助你节省 API 费用:
- 限制上下文: 减少每次请求的 Token 数量
- 缓存优化: 提高缓存命中率
- Heartbeat: AI 定时检查任务的频率"
    
    # Token 优化
    echo -e "  ${S_BOLD}Token 优化配置${C_RESET} ${S_DIM}(可节省 40-80% 成本)${C_RESET}"
    echo ""
    
    local opt_options=(
        "限制上下文窗口 (50K tokens) - 推荐"
        "启用积极压缩"
        "启用缓存优化"
    )
    
    ui_multi_select "选择优化选项" "${opt_options[@]}"
    
    for idx in "${SELECTED_ITEMS[@]}"; do
        case $idx in
            0) CONFIG_CONTEXT_TOKENS=50000 ;;
            1) ;; # 压缩由 OpenClaw 自动处理
            2) CONFIG_CACHE_TTL=3600 ;;
        esac
    done
    
    # Heartbeat 配置
    echo ""
    echo -e "  ${S_BOLD}Heartbeat 配置${C_RESET}"
    echo ""
    
    local hb_options=(
        "30 分钟 (推荐)"
        "15 分钟 (高频)"
        "60 分钟 (低频)"
        "禁用"
    )
    
    ui_select "Heartbeat 间隔" "${hb_options[@]}"
    local hb_choice=$?
    
    case $hb_choice in
        0) CONFIG_HEARTBEAT_INTERVAL="30m" ;;
        1) CONFIG_HEARTBEAT_INTERVAL="15m" ;;
        2) CONFIG_HEARTBEAT_INTERVAL="60m" ;;
        3) CONFIG_HEARTBEAT_INTERVAL="" ;;
    esac
    
    return 0
}

# ============================================================================
# 步骤 6: 确认并生成
# ============================================================================

wizard_step_confirm() {
    ui_step_title 6 6 "确认配置"
    
    # 显示配置摘要
    local summary_items=()
    
    # 版本
    local version_name="国际版"
    [[ "$INSTALL_VERSION" == "chinese" ]] && version_name="中文版"
    summary_items+=("版本:$version_name")
    
    # Provider
    summary_items+=("AI Provider:${#CONFIG_PROVIDER_LIST[@]} 个")
    
    # 模型
    local model_display="${CONFIG_PRIMARY_MODEL##*/}"
    summary_items+=("主模型:$model_display")
    
    if [[ ${#CONFIG_FALLBACK_MODELS[@]} -gt 0 ]]; then
        summary_items+=("备用模型:${#CONFIG_FALLBACK_MODELS[@]} 个")
    fi
    
    # 频道
    local channel_count=0
    [[ -n "${CONFIG_CHANNELS[telegram]}" ]] && ((channel_count++))
    [[ -n "${CONFIG_CHANNELS[whatsapp]}" ]] && ((channel_count++))
    [[ -n "${CONFIG_CHANNELS[discord]}" ]] && ((channel_count++))
    summary_items+=("频道:${channel_count} 个 + Gateway")
    
    # Gateway
    summary_items+=("Gateway:${CONFIG_GATEWAY_BIND}:${CONFIG_GATEWAY_PORT}")
    
    # 优化
    summary_items+=("上下文限制:${CONFIG_CONTEXT_TOKENS} tokens")
    summary_items+=("Heartbeat:${CONFIG_HEARTBEAT_INTERVAL:-禁用}")
    
    ui_kv_panel "配置摘要" "${summary_items[@]}"
    
    if ! ui_confirm "确认生成配置文件?" "y"; then
        return 1
    fi
    
    # 生成配置文件
    ui_spinner_start "正在生成配置文件..."
    
    if generate_config_files; then
        ui_spinner_success "配置文件生成完成"
    else
        ui_spinner_error "配置文件生成失败"
        return 1
    fi
    
    # 验证配置
    ui_spinner_start "正在验证配置..."
    
    local cli_name="openclaw"
    [[ "$INSTALL_VERSION" == "chinese" ]] && cli_name="openclaw-cn"
    
    if command_exists "$cli_name" && $cli_name doctor >> "$LOG_FILE" 2>&1; then
        ui_spinner_success "配置验证通过"
    else
        ui_spinner_error "配置验证失败，可能需要手动调整"
    fi
    
    return 0
}

# ============================================================================
# 配置文件生成
# ============================================================================

# 生成所有配置文件
generate_config_files() {
    # 生成主配置文件
    generate_openclaw_json
    
    # 生成环境变量文件
    generate_env_file
    
    # 生成工作区模板
    generate_workspace_templates
    
    return 0
}

# 生成 openclaw.json
generate_openclaw_json() {
    local config_file="$OPENCLAW_CONFIG"
    
    # 构建 JSON
    local json='{'
    
    # agents 配置
    json+='"agents":{"defaults":{'
    json+='"workspace":"~/.openclaw/workspace",'
    json+='"contextTokens":'$CONFIG_CONTEXT_TOKENS','
    json+='"maxConcurrent":4,'
    
    # 模型配置
    json+='"model":{"primary":"'$CONFIG_PRIMARY_MODEL'"'
    if [[ ${#CONFIG_FALLBACK_MODELS[@]} -gt 0 ]]; then
        json+=',"fallbacks":['
        local first=true
        for model in "${CONFIG_FALLBACK_MODELS[@]}"; do
            [[ "$first" != true ]] && json+=','
            json+='"'$model'"'
            first=false
        done
        json+=']'
    fi
    json+='}'
    
    # Heartbeat
    if [[ -n "$CONFIG_HEARTBEAT_INTERVAL" ]]; then
        json+=',"heartbeat":{"every":"'$CONFIG_HEARTBEAT_INTERVAL'","target":"last"}'
    fi
    
    json+='}},'
    
    # models.providers 配置
    json+='"models":{"providers":{'
    local first_provider=true
    
    for provider in "${CONFIG_PROVIDER_LIST[@]}"; do
        [[ "$first_provider" != true ]] && json+=','
        first_provider=false
        
        case "$provider" in
            anthropic)
                json+='"anthropic":{"apiKey":"${ANTHROPIC_API_KEY}"}'
                ;;
            openai)
                json+='"openai":{"apiKey":"${OPENAI_API_KEY}"}'
                ;;
            deepseek)
                json+='"deepseek":{"apiKey":"${DEEPSEEK_API_KEY}","baseURL":"https://api.deepseek.com/v1"}'
                ;;
            google)
                json+='"google":{"apiKey":"${GOOGLE_API_KEY}"}'
                ;;
            ollama)
                json+='"ollama":{"baseUrl":"'${CONFIG_PROVIDERS[ollama]}'"}'
                ;;
        esac
    done
    
    json+='}},'
    
    # channels 配置
    json+='"channels":{'
    local first_channel=true
    
    if [[ -n "${CONFIG_CHANNELS[telegram]}" ]]; then
        json+='"telegram":{"token":"${TELEGRAM_BOT_TOKEN}","dmPolicy":"open"'
        if [[ "${CONFIG_CHANNELS[telegram_groups]}" == "enabled" ]]; then
            json+=',"groups":{"*":{"requireMention":'
            [[ "${CONFIG_CHANNELS[telegram_mention]}" == "required" ]] && json+='true' || json+='false'
            json+='}}'
        fi
        json+='}'
        first_channel=false
    fi
    
    if [[ -n "${CONFIG_CHANNELS[whatsapp]}" ]]; then
        [[ "$first_channel" != true ]] && json+=','
        json+='"whatsapp":{"dmPolicy":"pairing"'
        if [[ -n "${CONFIG_CHANNELS[whatsapp_allowfrom]}" ]]; then
            json+=',"allowFrom":["'${CONFIG_CHANNELS[whatsapp_allowfrom]}'"]'
        fi
        json+='}'
        first_channel=false
    fi
    
    if [[ -n "${CONFIG_CHANNELS[discord]}" ]]; then
        [[ "$first_channel" != true ]] && json+=','
        json+='"discord":{"token":"${DISCORD_BOT_TOKEN}","activation":"mention"}'
    fi
    
    json+='},'
    
    # gateway 配置
    json+='"gateway":{'
    json+='"port":'$CONFIG_GATEWAY_PORT','
    json+='"bind":"'$CONFIG_GATEWAY_BIND'",'
    json+='"auth":{"mode":"token","token":"${OPENCLAW_GATEWAY_TOKEN}"}'
    json+='}'
    
    json+='}'
    
    # 写入文件
    ensure_dir "$(dirname "$config_file")"
    
    if command_exists jq; then
        echo "$json" | jq '.' > "$config_file"
    else
        echo "$json" > "$config_file"
    fi
    
    chmod 600 "$config_file"
}

# 生成环境变量文件
generate_env_file() {
    local env_file="$OPENCLAW_ENV"
    
    local content="# OpenClaw 环境变量
# 生成时间: $(date)
# 警告: 此文件包含敏感信息，请勿分享！

"
    
    # AI Provider Keys
    content+="# AI Providers\n"
    
    if [[ -n "${CONFIG_PROVIDERS[anthropic]}" ]]; then
        content+="ANTHROPIC_API_KEY=${CONFIG_PROVIDERS[anthropic]}\n"
    fi
    
    if [[ -n "${CONFIG_PROVIDERS[openai]}" ]]; then
        content+="OPENAI_API_KEY=${CONFIG_PROVIDERS[openai]}\n"
    fi
    
    if [[ -n "${CONFIG_PROVIDERS[deepseek]}" ]]; then
        content+="DEEPSEEK_API_KEY=${CONFIG_PROVIDERS[deepseek]}\n"
    fi
    
    if [[ -n "${CONFIG_PROVIDERS[google]}" ]]; then
        content+="GOOGLE_API_KEY=${CONFIG_PROVIDERS[google]}\n"
    fi
    
    # Channel Tokens
    content+="\n# Channels\n"
    
    if [[ -n "${CONFIG_CHANNELS[telegram]}" ]] && [[ "${CONFIG_CHANNELS[telegram]}" != "enabled" ]]; then
        content+="TELEGRAM_BOT_TOKEN=${CONFIG_CHANNELS[telegram]}\n"
    fi
    
    if [[ -n "${CONFIG_CHANNELS[discord]}" ]] && [[ "${CONFIG_CHANNELS[discord]}" != "enabled" ]]; then
        content+="DISCORD_BOT_TOKEN=${CONFIG_CHANNELS[discord]}\n"
    fi
    
    # Gateway Token
    content+="\n# Gateway\n"
    content+="OPENCLAW_GATEWAY_TOKEN=$CONFIG_GATEWAY_TOKEN\n"
    
    # 写入文件
    echo -e "$content" > "$env_file"
    chmod 600 "$env_file"
}

# 生成工作区模板
generate_workspace_templates() {
    local workspace="$OPENCLAW_WORKSPACE"
    
    ensure_dir "$workspace"
    ensure_dir "$workspace/memory"
    ensure_dir "$workspace/memory/notes"
    ensure_dir "$workspace/memory/tasks"
    ensure_dir "$workspace/memory/ideas"
    
    # SOUL.md
    cat > "$workspace/SOUL.md" <<'EOF'
# SOUL.md - Bot 人格定义

## Mission（使命）
成为最有用的个人助理，帮助主人管理任务、记录灵感、提供信息支持。

## Personality（个性）
- **高效务实**：不废话，直击要点
- **友好但不油腻**：专业但有温度
- **主动但不打扰**：该提醒时提醒，不该说话时闭嘴
- **可靠靠谱**：说到做到，不丢球

## 语言风格
- 简洁明了，一次说清楚
- 避免机器人官腔
- 适当使用 emoji 增加亲和力 ✨
- 中英文混合自然切换

## 核心原则
1. **服务优先**: 主人的需求 > 完美主义
2. **隐私保护**: 不主动分享主人的私人信息
3. **边界清晰**: 我是助手，不是决策者
4. **透明诚实**: 不确定时承认不确定
EOF

    # IDENTITY.md
    cat > "$workspace/IDENTITY.md" <<'EOF'
# IDENTITY.md - Bot 身份信息

- **Name:** OpenClaw Assistant
- **Emoji:** 🦞
- **Role:** 个人助理 / 生活管家

## Owner（主人信息）
- Timezone: Asia/Shanghai
- Preferred Language: 中文

## Capabilities（能力清单）
### ✅ 我能做的
- 记录和查询信息
- 提醒和日程管理
- 信息搜索和整理
- 简单任务自动化

### ❌ 我不能做的
- 写长篇代码（> 50 行）
- 创作文章/剧本
- 修改系统核心配置
- 替你做决策
EOF

    # MEMORY.md
    cat > "$workspace/memory/MEMORY.md" <<'EOF'
# 我的记忆库

这里存储我的所有记忆和知识。

## 索引
- 📝 笔记：memory/notes/
- ✅ 任务：memory/tasks/
- 💡 想法：memory/ideas/

## 使用说明
- 记录时使用触发词：记下、待办、想法等
- 查询时使用：查、找、搜等关键词
- Bot 会自动分类和整理
EOF
}

# ============================================================================
# 完整向导流程
# ============================================================================

# 运行配置向导
run_config_wizard() {
    ui_section_title "配置向导" "$EMOJI_GEAR"
    
    echo -e "  欢迎使用 OpenClaw 配置向导！"
    echo -e "  接下来将引导您完成 6 个步骤的配置。"
    echo ""
    
    if ! ui_confirm "开始配置?" "y"; then
        return 1
    fi
    
    # 步骤 1: Provider
    if ! wizard_step_providers; then
        return 1
    fi
    
    # 步骤 2: 模型
    if ! wizard_step_models; then
        return 1
    fi
    
    # 步骤 3: 频道
    if ! wizard_step_channels; then
        return 1
    fi
    
    # 步骤 4: Gateway
    if ! wizard_step_gateway; then
        return 1
    fi
    
    # 步骤 5: 优化
    if ! wizard_step_optimization; then
        return 1
    fi
    
    # 步骤 6: 确认
    if ! wizard_step_confirm; then
        return 1
    fi
    
    echo ""
    log_success "配置向导完成！"
    
    return 0
}

# ============================================================================
# 导出
# ============================================================================

export -f run_config_wizard
