#!/bin/bash
# ============================================================================
# OpenClaw Deploy 2.0 - Health Check Module
# ============================================================================
# 系统状态检查、诊断和修复模块
# ============================================================================

# 防止重复加载
[[ -n "$_HEALTH_LOADED" ]] && return 0
_HEALTH_LOADED=1

# ============================================================================
# 健康检查项目
# ============================================================================

# 检查结果存储
declare -A HEALTH_RESULTS=()
declare -a HEALTH_ISSUES=()
declare -a HEALTH_WARNINGS=()

# ============================================================================
# 服务状态检查
# ============================================================================

# 检查 OpenClaw 服务状态
check_service_status() {
    local cli_name="openclaw"
    [[ "$INSTALL_VERSION" == "chinese" ]] && cli_name="openclaw-cn"
    
    # 检查 systemd 服务
    if has_systemd; then
        if service_is_running "openclaw"; then
            HEALTH_RESULTS["service"]="running"
            
            # 获取运行时间
            local uptime=$(systemctl show openclaw --property=ActiveEnterTimestamp 2>/dev/null | cut -d= -f2)
            if [[ -n "$uptime" ]]; then
                HEALTH_RESULTS["service_uptime"]="$uptime"
            fi
            
            # 获取 PID
            local pid=$(systemctl show openclaw --property=MainPID 2>/dev/null | cut -d= -f2)
            if [[ -n "$pid" ]] && [[ "$pid" != "0" ]]; then
                HEALTH_RESULTS["service_pid"]="$pid"
            fi
            
            return 0
        else
            HEALTH_RESULTS["service"]="stopped"
            HEALTH_ISSUES+=("OpenClaw 服务未运行")
            return 1
        fi
    else
        HEALTH_RESULTS["service"]="no_systemd"
        HEALTH_WARNINGS+=("系统不支持 systemd")
        return 0
    fi
}

# 检查 Gateway 状态
check_gateway_status() {
    local port="${CONFIG_GATEWAY_PORT:-18789}"
    local bind="${CONFIG_GATEWAY_BIND:-127.0.0.1}"
    
    # 检查端口是否在监听
    if command_exists ss; then
        if ss -tlnp 2>/dev/null | grep -q ":$port"; then
            HEALTH_RESULTS["gateway"]="listening"
            HEALTH_RESULTS["gateway_port"]="$port"
            return 0
        fi
    elif command_exists netstat; then
        if netstat -tlnp 2>/dev/null | grep -q ":$port"; then
            HEALTH_RESULTS["gateway"]="listening"
            HEALTH_RESULTS["gateway_port"]="$port"
            return 0
        fi
    fi
    
    # 尝试 HTTP 请求
    if curl -s --connect-timeout 3 "http://${bind}:${port}/health" &>/dev/null; then
        HEALTH_RESULTS["gateway"]="responding"
        HEALTH_RESULTS["gateway_port"]="$port"
        return 0
    fi
    
    HEALTH_RESULTS["gateway"]="not_responding"
    HEALTH_ISSUES+=("Gateway 未响应 (端口 $port)")
    return 1
}

# ============================================================================
# 配置检查
# ============================================================================

# 检查配置文件
check_config_status() {
    # 检查配置文件是否存在
    if [[ ! -f "$OPENCLAW_CONFIG" ]]; then
        HEALTH_RESULTS["config"]="missing"
        HEALTH_ISSUES+=("配置文件不存在: $OPENCLAW_CONFIG")
        return 1
    fi
    
    HEALTH_RESULTS["config"]="exists"
    
    # 检查 JSON 格式
    if command_exists jq; then
        if ! jq empty "$OPENCLAW_CONFIG" 2>/dev/null; then
            HEALTH_RESULTS["config_valid"]="invalid"
            HEALTH_ISSUES+=("配置文件 JSON 格式错误")
            return 1
        fi
        HEALTH_RESULTS["config_valid"]="valid"
    fi
    
    # 检查文件权限
    local perms=$(stat -c "%a" "$OPENCLAW_CONFIG" 2>/dev/null || stat -f "%OLp" "$OPENCLAW_CONFIG" 2>/dev/null)
    if [[ "$perms" != "600" ]]; then
        HEALTH_WARNINGS+=("配置文件权限不安全 (当前: $perms, 建议: 600)")
    fi
    
    return 0
}

# 检查环境变量
check_env_status() {
    if [[ ! -f "$OPENCLAW_ENV" ]]; then
        HEALTH_RESULTS["env"]="missing"
        HEALTH_WARNINGS+=("环境变量文件不存在")
        return 1
    fi
    
    HEALTH_RESULTS["env"]="exists"
    
    # 检查必需的环境变量
    source "$OPENCLAW_ENV" 2>/dev/null
    
    local has_provider=false
    
    if [[ -n "$ANTHROPIC_API_KEY" ]] || [[ -n "$OPENAI_API_KEY" ]] || \
       [[ -n "$DEEPSEEK_API_KEY" ]] || [[ -n "$GOOGLE_API_KEY" ]]; then
        has_provider=true
    fi
    
    if [[ "$has_provider" != true ]]; then
        HEALTH_WARNINGS+=("未配置任何 AI Provider API Key")
    fi
    
    if [[ -z "$OPENCLAW_GATEWAY_TOKEN" ]]; then
        HEALTH_WARNINGS+=("未配置 Gateway Token")
    fi
    
    return 0
}

# ============================================================================
# 资源检查
# ============================================================================

# 检查系统资源
check_resource_status() {
    # 内存使用
    local mem_total=$(free -m 2>/dev/null | awk 'NR==2{print $2}')
    local mem_used=$(free -m 2>/dev/null | awk 'NR==2{print $3}')
    local mem_percent=0
    
    if [[ -n "$mem_total" ]] && [[ "$mem_total" -gt 0 ]]; then
        mem_percent=$((mem_used * 100 / mem_total))
        HEALTH_RESULTS["memory_used"]="${mem_used}MB"
        HEALTH_RESULTS["memory_total"]="${mem_total}MB"
        HEALTH_RESULTS["memory_percent"]="$mem_percent"
        
        if [[ $mem_percent -gt 90 ]]; then
            HEALTH_ISSUES+=("内存使用率过高: ${mem_percent}%")
        elif [[ $mem_percent -gt 80 ]]; then
            HEALTH_WARNINGS+=("内存使用率较高: ${mem_percent}%")
        fi
    fi
    
    # 磁盘使用
    local disk_info=$(df -h "$HOME" 2>/dev/null | tail -1)
    local disk_used=$(echo "$disk_info" | awk '{print $3}')
    local disk_total=$(echo "$disk_info" | awk '{print $2}')
    local disk_percent=$(echo "$disk_info" | awk '{print $5}' | tr -d '%')
    
    if [[ -n "$disk_percent" ]]; then
        HEALTH_RESULTS["disk_used"]="$disk_used"
        HEALTH_RESULTS["disk_total"]="$disk_total"
        HEALTH_RESULTS["disk_percent"]="$disk_percent"
        
        if [[ $disk_percent -gt 95 ]]; then
            HEALTH_ISSUES+=("磁盘空间不足: ${disk_percent}% 已使用")
        elif [[ $disk_percent -gt 85 ]]; then
            HEALTH_WARNINGS+=("磁盘空间较低: ${disk_percent}% 已使用")
        fi
    fi
    
    # CPU 使用（如果服务在运行）
    if [[ -n "${HEALTH_RESULTS[service_pid]}" ]]; then
        local cpu_percent=$(ps -p "${HEALTH_RESULTS[service_pid]}" -o %cpu= 2>/dev/null | tr -d ' ')
        if [[ -n "$cpu_percent" ]]; then
            HEALTH_RESULTS["cpu_percent"]="$cpu_percent"
        fi
    fi
}

# 检查 Session 大小
check_session_status() {
    local session_dir="$HOME/.openclaw/agents/main/sessions"
    
    if [[ -d "$session_dir" ]]; then
        local session_size=$(du -sm "$session_dir" 2>/dev/null | cut -f1)
        HEALTH_RESULTS["session_size"]="${session_size}MB"
        
        if [[ -n "$session_size" ]] && [[ $session_size -gt 100 ]]; then
            HEALTH_WARNINGS+=("Session 文件较大 (${session_size}MB)，建议压缩")
        fi
    fi
    
    # 检查日志大小
    local log_dir="$OPENCLAW_LOGS"
    if [[ -d "$log_dir" ]]; then
        local log_size=$(du -sm "$log_dir" 2>/dev/null | cut -f1)
        HEALTH_RESULTS["log_size"]="${log_size}MB"
        
        if [[ -n "$log_size" ]] && [[ $log_size -gt 500 ]]; then
            HEALTH_WARNINGS+=("日志文件较大 (${log_size}MB)，建议清理")
        fi
    fi
}

# ============================================================================
# 依赖检查
# ============================================================================

# 检查依赖状态
check_dependency_status() {
    # Node.js
    if command_exists node; then
        local node_ver=$(node --version 2>/dev/null | sed 's/^v//')
        HEALTH_RESULTS["node_version"]="$node_ver"
        
        if ! check_node_version 22; then
            HEALTH_ISSUES+=("Node.js 版本过低: $node_ver (需要 v22+)")
        fi
    else
        HEALTH_RESULTS["node_version"]="not_installed"
        HEALTH_ISSUES+=("Node.js 未安装")
    fi
    
    # OpenClaw CLI
    local cli_name="openclaw"
    [[ "$INSTALL_VERSION" == "chinese" ]] && cli_name="openclaw-cn"
    
    if command_exists "$cli_name"; then
        local cli_ver=$($cli_name --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        HEALTH_RESULTS["cli_version"]="$cli_ver"
    else
        HEALTH_RESULTS["cli_version"]="not_installed"
        HEALTH_ISSUES+=("OpenClaw CLI 未安装")
    fi
}

# ============================================================================
# 网络检查
# ============================================================================

# 检查网络连接
check_network_status() {
    if check_network; then
        HEALTH_RESULTS["network"]="ok"
    else
        HEALTH_RESULTS["network"]="failed"
        HEALTH_WARNINGS+=("网络连接异常")
    fi
    
    # 检查 API 连通性
    if [[ -n "$ANTHROPIC_API_KEY" ]]; then
        if curl -s --connect-timeout 5 "https://api.anthropic.com" &>/dev/null; then
            HEALTH_RESULTS["api_anthropic"]="ok"
        else
            HEALTH_WARNINGS+=("无法连接 Anthropic API")
        fi
    fi
    
    if [[ -n "$OPENAI_API_KEY" ]]; then
        if curl -s --connect-timeout 5 "https://api.openai.com" &>/dev/null; then
            HEALTH_RESULTS["api_openai"]="ok"
        else
            HEALTH_WARNINGS+=("无法连接 OpenAI API")
        fi
    fi
}

# ============================================================================
# 完整健康检查
# ============================================================================

# 运行完整健康检查
run_health_check() {
    # 清空之前的结果
    HEALTH_RESULTS=()
    HEALTH_ISSUES=()
    HEALTH_WARNINGS=()
    
    ui_section_title "系统状态检查" "$EMOJI_HOSPITAL"
    
    # 运行各项检查
    ui_spinner_start "检查服务状态..."
    check_service_status
    ui_spinner_stop
    
    ui_spinner_start "检查 Gateway..."
    check_gateway_status
    ui_spinner_stop
    
    ui_spinner_start "检查配置文件..."
    check_config_status
    check_env_status
    ui_spinner_stop
    
    ui_spinner_start "检查系统资源..."
    check_resource_status
    check_session_status
    ui_spinner_stop
    
    ui_spinner_start "检查依赖..."
    check_dependency_status
    ui_spinner_stop
    
    ui_spinner_start "检查网络..."
    check_network_status
    ui_spinner_stop
    
    # 显示结果
    show_health_result
}

# 显示健康检查结果
show_health_result() {
    echo ""
    
    # 服务状态
    local service_items=()
    
    case "${HEALTH_RESULTS[service]}" in
        running)
            service_items+=("状态:${C_SUCCESS}● 运行中${C_RESET}")
            [[ -n "${HEALTH_RESULTS[service_pid]}" ]] && service_items+=("PID:${HEALTH_RESULTS[service_pid]}")
            [[ -n "${HEALTH_RESULTS[service_uptime]}" ]] && service_items+=("启动时间:${HEALTH_RESULTS[service_uptime]}")
            ;;
        stopped)
            service_items+=("状态:${C_ERROR}○ 已停止${C_RESET}")
            ;;
        *)
            service_items+=("状态:${S_DIM}未知${C_RESET}")
            ;;
    esac
    
    case "${HEALTH_RESULTS[gateway]}" in
        listening|responding)
            service_items+=("Gateway:${C_SUCCESS}● 监听中${C_RESET} (端口 ${HEALTH_RESULTS[gateway_port]})")
            ;;
        *)
            service_items+=("Gateway:${C_ERROR}○ 未响应${C_RESET}")
            ;;
    esac
    
    ui_kv_panel "服务状态" "${service_items[@]}"
    
    # 配置状态
    local config_items=()
    
    case "${HEALTH_RESULTS[config]}" in
        exists)
            local valid_mark="${C_SUCCESS}✓${C_RESET}"
            [[ "${HEALTH_RESULTS[config_valid]}" == "invalid" ]] && valid_mark="${C_ERROR}✗${C_RESET}"
            config_items+=("配置文件:$valid_mark 存在")
            ;;
        *)
            config_items+=("配置文件:${C_ERROR}✗ 不存在${C_RESET}")
            ;;
    esac
    
    case "${HEALTH_RESULTS[env]}" in
        exists)
            config_items+=("环境变量:${C_SUCCESS}✓${C_RESET} 已配置")
            ;;
        *)
            config_items+=("环境变量:${C_WARNING}! 未配置${C_RESET}")
            ;;
    esac
    
    ui_kv_panel "配置状态" "${config_items[@]}"
    
    # 资源使用
    local resource_items=()
    
    if [[ -n "${HEALTH_RESULTS[memory_percent]}" ]]; then
        local mem_color="$C_SUCCESS"
        [[ ${HEALTH_RESULTS[memory_percent]} -gt 80 ]] && mem_color="$C_WARNING"
        [[ ${HEALTH_RESULTS[memory_percent]} -gt 90 ]] && mem_color="$C_ERROR"
        resource_items+=("内存:${HEALTH_RESULTS[memory_used]} / ${HEALTH_RESULTS[memory_total]} (${mem_color}${HEALTH_RESULTS[memory_percent]}%${C_RESET})")
    fi
    
    if [[ -n "${HEALTH_RESULTS[disk_percent]}" ]]; then
        local disk_color="$C_SUCCESS"
        [[ ${HEALTH_RESULTS[disk_percent]} -gt 85 ]] && disk_color="$C_WARNING"
        [[ ${HEALTH_RESULTS[disk_percent]} -gt 95 ]] && disk_color="$C_ERROR"
        resource_items+=("磁盘:${HEALTH_RESULTS[disk_used]} / ${HEALTH_RESULTS[disk_total]} (${disk_color}${HEALTH_RESULTS[disk_percent]}%${C_RESET})")
    fi
    
    [[ -n "${HEALTH_RESULTS[session_size]}" ]] && resource_items+=("Session:${HEALTH_RESULTS[session_size]}")
    [[ -n "${HEALTH_RESULTS[log_size]}" ]] && resource_items+=("日志:${HEALTH_RESULTS[log_size]}")
    
    ui_kv_panel "资源使用" "${resource_items[@]}"
    
    # 问题和警告
    if [[ ${#HEALTH_ISSUES[@]} -gt 0 ]]; then
        echo -e "  ${C_ERROR}发现 ${#HEALTH_ISSUES[@]} 个问题:${C_RESET}"
        for issue in "${HEALTH_ISSUES[@]}"; do
            echo -e "    ${C_ERROR}✗${C_RESET} $issue"
        done
        echo ""
    fi
    
    if [[ ${#HEALTH_WARNINGS[@]} -gt 0 ]]; then
        echo -e "  ${C_WARNING}${#HEALTH_WARNINGS[@]} 个警告:${C_RESET}"
        for warning in "${HEALTH_WARNINGS[@]}"; do
            echo -e "    ${C_WARNING}!${C_RESET} $warning"
        done
        echo ""
    fi
    
    if [[ ${#HEALTH_ISSUES[@]} -eq 0 ]] && [[ ${#HEALTH_WARNINGS[@]} -eq 0 ]]; then
        echo -e "  ${C_SUCCESS}✓ 系统状态良好${C_RESET}"
        echo ""
    fi
}

# ============================================================================
# 诊断和修复
# ============================================================================

# 运行诊断
run_diagnostics() {
    ui_section_title "运行诊断" "$EMOJI_SEARCH"
    
    local cli_name="openclaw"
    [[ "$INSTALL_VERSION" == "chinese" ]] && cli_name="openclaw-cn"
    
    if ! command_exists "$cli_name"; then
        log_error "OpenClaw CLI 未安装，无法运行诊断"
        return 1
    fi
    
    ui_spinner_start "运行 $cli_name doctor..."
    
    local doctor_output=$($cli_name doctor 2>&1)
    local doctor_exit=$?
    
    ui_spinner_stop
    
    echo ""
    echo "$doctor_output"
    echo ""
    
    if [[ $doctor_exit -ne 0 ]]; then
        if ui_confirm "是否尝试自动修复?" "y"; then
            ui_spinner_start "运行自动修复..."
            $cli_name doctor --fix >> "$LOG_FILE" 2>&1
            ui_spinner_success "修复完成"
        fi
    else
        log_success "诊断通过，未发现问题"
    fi
    
    return $doctor_exit
}

# 自动修复常见问题
auto_fix_issues() {
    if [[ ${#HEALTH_ISSUES[@]} -eq 0 ]]; then
        log_info "没有需要修复的问题"
        return 0
    fi
    
    ui_section_title "自动修复" "$EMOJI_WRENCH"
    
    for issue in "${HEALTH_ISSUES[@]}"; do
        case "$issue" in
            *"服务未运行"*)
                ui_spinner_start "启动服务..."
                if sudo systemctl start openclaw 2>/dev/null; then
                    ui_spinner_success "服务已启动"
                else
                    ui_spinner_error "服务启动失败"
                fi
                ;;
            *"配置文件不存在"*)
                log_warning "配置文件不存在，请运行配置向导"
                ;;
            *"Node.js"*)
                if ui_confirm "是否安装 Node.js?" "y"; then
                    install_nodejs
                fi
                ;;
        esac
    done
    
    # 处理警告
    for warning in "${HEALTH_WARNINGS[@]}"; do
        case "$warning" in
            *"Session 文件较大"*)
                if ui_confirm "是否压缩 Session?" "y"; then
                    compress_session
                fi
                ;;
            *"日志文件较大"*)
                if ui_confirm "是否清理日志?" "y"; then
                    cleanup_logs
                fi
                ;;
            *"权限不安全"*)
                ui_spinner_start "修复文件权限..."
                chmod 600 "$OPENCLAW_CONFIG" 2>/dev/null
                chmod 600 "$OPENCLAW_ENV" 2>/dev/null
                ui_spinner_success "权限已修复"
                ;;
        esac
    done
}

# 压缩 Session
compress_session() {
    local cli_name="openclaw"
    [[ "$INSTALL_VERSION" == "chinese" ]] && cli_name="openclaw-cn"
    
    ui_spinner_start "压缩 Session..."
    
    if command_exists "$cli_name"; then
        $cli_name /compact >> "$LOG_FILE" 2>&1
    fi
    
    ui_spinner_success "Session 已压缩"
}

# 清理日志
cleanup_logs() {
    ui_spinner_start "清理日志..."
    
    # 清理 PM2 日志
    if command_exists pm2; then
        pm2 flush >> "$LOG_FILE" 2>&1
    fi
    
    # 清理旧日志文件
    find "$OPENCLAW_LOGS" -name "*.log" -mtime +7 -delete 2>/dev/null
    
    # 清理 systemd 日志
    if has_systemd; then
        sudo journalctl --vacuum-time=7d >> "$LOG_FILE" 2>&1
    fi
    
    ui_spinner_success "日志已清理"
}

# ============================================================================
# 健康检查界面
# ============================================================================

# 显示健康检查界面
show_health_manager() {
    while true; do
        run_health_check
        
        local options=(
            "${EMOJI_REFRESH} 刷新状态"
            "${EMOJI_SEARCH} 运行诊断"
            "${EMOJI_WRENCH} 自动修复"
            "📋 查看日志"
            "← 返回主菜单"
        )
        
        ui_select "选择操作" "${options[@]}"
        local choice=$?
        
        case $choice in
            0) continue ;;  # 刷新
            1) run_diagnostics; ui_wait_key ;;
            2) auto_fix_issues; ui_wait_key ;;
            3) show_logs ;;
            4|255) return 0 ;;
        esac
    done
}

# 显示日志
show_logs() {
    local cli_name="openclaw"
    [[ "$INSTALL_VERSION" == "chinese" ]] && cli_name="openclaw-cn"
    
    local options=(
        "OpenClaw 日志"
        "Systemd 日志"
        "安装日志"
        "← 返回"
    )
    
    ui_select "选择日志" "${options[@]}"
    local choice=$?
    
    case $choice in
        0)
            if command_exists "$cli_name"; then
                $cli_name logs 2>/dev/null | tail -100 | less
            else
                log_error "OpenClaw CLI 未安装"
            fi
            ;;
        1)
            if has_systemd; then
                sudo journalctl -u openclaw -n 100 --no-pager | less
            else
                log_error "系统不支持 systemd"
            fi
            ;;
        2)
            if [[ -f "$LOG_FILE" ]]; then
                less "$LOG_FILE"
            else
                log_error "安装日志不存在"
            fi
            ;;
    esac
}

# ============================================================================
# 导出
# ============================================================================

export -f check_service_status check_gateway_status
export -f check_config_status check_env_status
export -f check_resource_status check_session_status
export -f check_dependency_status check_network_status
export -f run_health_check show_health_result
export -f run_diagnostics auto_fix_issues
export -f compress_session cleanup_logs
export -f show_health_manager show_logs
