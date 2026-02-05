#!/bin/bash
# ============================================================================
# OpenClaw Deploy 2.0 - Installer Module
# ============================================================================
# 安装管理模块，支持国际版和中文版的安装、升级
# ============================================================================

# 防止重复加载
[[ -n "$_INSTALLER_LOADED" ]] && return 0
_INSTALLER_LOADED=1

# ============================================================================
# 安装配置
# ============================================================================

# 官方安装脚本 URL
INSTALL_URL_INTERNATIONAL="https://raw.githubusercontent.com/openclaw/openclaw/main/install.sh"
INSTALL_URL_CHINESE="https://clawd.org.cn/install.sh"

# npm 包名
NPM_PACKAGE_INTERNATIONAL="openclaw"
NPM_PACKAGE_CHINESE="openclaw-cn"

# 最低 Node.js 版本
MIN_NODE_VERSION=22

# ============================================================================
# 用户管理
# ============================================================================

# 显示 root 用户警告
show_root_warning() {
    ui_section_title "检测到 root 用户" "$EMOJI_WARNING"
    
    echo -e "  ┌─────────────────────────────────────────────────────────┐"
    echo -e "  │ ${C_ERROR}🚫 为什么不能用 root 用户运行 OpenClaw？${C_RESET}               │"
    echo -e "  ├─────────────────────────────────────────────────────────┤"
    echo -e "  │                                                         │"
    echo -e "  │  ${S_BOLD}1. 安全风险${C_RESET}                                            │"
    echo -e "  │     root 用户拥有系统最高权限，如果 OpenClaw 或其       │"
    echo -e "  │     插件存在漏洞，可能导致整个系统被攻击。              │"
    echo -e "  │                                                         │"
    echo -e "  │  ${S_BOLD}2. 权限隔离${C_RESET}                                            │"
    echo -e "  │     使用专用用户可以限制 OpenClaw 的访问范围，          │"
    echo -e "  │     即使出问题也不会影响系统其他部分。                  │"
    echo -e "  │                                                         │"
    echo -e "  │  ${S_BOLD}3. 官方要求${C_RESET}                                            │"
    echo -e "  │     OpenClaw 官方不建议以 root 身份运行。               │"
    echo -e "  │                                                         │"
    echo -e "  └─────────────────────────────────────────────────────────┘"
    echo ""
}

# 创建 OpenClaw 专用用户
create_openclaw_user() {
    local username="${1:-openclaw}"
    
    ui_log_step "创建用户 '$username'"
    
    # 检查用户是否已存在
    if user_exists "$username"; then
        log_warning "用户 '$username' 已存在"
        if ui_confirm "是否使用现有用户 '$username'?" "y"; then
            OPENCLAW_USER="$username"
            return 0
        else
            username=$(ui_input "请输入新用户名" "openclaw2")
        fi
    fi
    
    # 创建用户
    ui_spinner_start "正在创建用户 '$username'..."
    
    if useradd -m -s /bin/bash "$username" 2>/dev/null; then
        ui_spinner_success "用户 '$username' 创建成功"
    else
        ui_spinner_error "创建用户失败"
        return 1
    fi
    
    # 设置密码
    echo ""
    echo -e "  ${S_BOLD}请为用户 '$username' 设置密码${C_RESET}"
    echo -e "  ${S_DIM}(输入时不会显示，这是正常的)${C_RESET}"
    echo ""
    
    if ! passwd "$username"; then
        log_error "设置密码失败"
        return 1
    fi
    
    # 添加到 sudo 组
    if ui_confirm "是否给予 '$username' sudo 权限? (推荐)" "y"; then
        if usermod -aG sudo "$username" 2>/dev/null || usermod -aG wheel "$username" 2>/dev/null; then
            log_success "已添加 sudo 权限"
        else
            log_warning "添加 sudo 权限失败，可能需要手动配置"
        fi
    fi
    
    OPENCLAW_USER="$username"
    return 0
}

# 处理 root 用户
handle_root_user() {
    show_root_warning
    
    local options=(
        "${EMOJI_NEW} 创建新用户 (推荐) - 自动创建 'openclaw' 用户并配置权限"
        "${EMOJI_USER} 切换到已有用户 - 选择一个已存在的普通用户"
        "${EMOJI_WARNING} 强制以 root 继续 (不推荐) - 了解风险后继续"
    )
    
    ui_select "请选择操作" "${options[@]}"
    local choice=$?
    
    case $choice in
        0)  # 创建新用户
            local username=$(ui_input "请输入新用户名" "openclaw")
            if create_openclaw_user "$username"; then
                prompt_switch_user "$username"
                return 0
            fi
            return 1
            ;;
        1)  # 切换到已有用户
            local users=($(get_normal_users))
            if [[ ${#users[@]} -eq 0 ]]; then
                log_error "没有找到普通用户，请先创建用户"
                return 1
            fi
            
            ui_select "选择用户" "${users[@]}"
            local user_choice=$?
            
            if [[ $user_choice -lt ${#users[@]} ]]; then
                OPENCLAW_USER="${users[$user_choice]}"
                prompt_switch_user "$OPENCLAW_USER"
                return 0
            fi
            return 1
            ;;
        2)  # 强制继续
            if ui_confirm_dangerous "以 root 用户运行 OpenClaw" "这可能带来安全风险，某些功能可能受限"; then
                log_warning "以 root 用户继续，某些功能可能受限"
                OPENCLAW_USER="root"
                return 0
            fi
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

# 提示切换用户
prompt_switch_user() {
    local target_user="$1"
    
    echo ""
    echo -e "  ┌─────────────────────────────────────────────────────────┐"
    echo -e "  │ ${S_BOLD}📋 请切换到用户 '$target_user' 后重新运行脚本${C_RESET}           │"
    echo -e "  ├─────────────────────────────────────────────────────────┤"
    echo -e "  │                                                         │"
    echo -e "  │  ${S_BOLD}方法 1: 使用 su 命令${C_RESET}                                   │"
    echo -e "  │  ${C_CYAN}su - $target_user${C_RESET}"
    echo -e "  │  然后重新运行安装脚本                                   │"
    echo -e "  │                                                         │"
    echo -e "  │  ${S_BOLD}方法 2: 使用 SSH 重新登录${C_RESET}                              │"
    echo -e "  │  ${C_CYAN}ssh $target_user@服务器IP${C_RESET}"
    echo -e "  │                                                         │"
    echo -e "  │  ${S_BOLD}方法 3: 退出当前会话${C_RESET}                                   │"
    echo -e "  │  ${C_CYAN}exit${C_RESET}"
    echo -e "  │  然后用 '$target_user' 用户重新登录                     │"
    echo -e "  │                                                         │"
    echo -e "  └─────────────────────────────────────────────────────────┘"
    echo ""
    echo -e "  切换用户后，运行以下命令继续安装："
    echo -e "  ${C_CYAN}curl -fsSL https://raw.githubusercontent.com/KnowHunters/openclaw-deploy/main/deploy.sh | bash${C_RESET}"
    echo ""
    
    ui_wait_key
    
    # 提示用户切换后，直接退出脚本
    echo ""
    log_info "请切换用户后重新运行脚本"
    exit 0
}

# ============================================================================
# 版本选择
# ============================================================================

# 选择安装版本
select_install_version() {
    ui_section_title "选择 OpenClaw 版本" "$EMOJI_GLOBE"
    
    local options=(
        "${EMOJI_GLOBE} 国际版 (openclaw) - 官方原版，英文界面"
        "${EMOJI_CN} 中文版 (openclaw-cn) - 中文本地化，支持国产模型"
    )
    
    # 显示版本说明
    echo -e "  ${S_DIM}国际版: 命令 openclaw, 源 npm install -g openclaw@latest${C_RESET}"
    echo -e "  ${S_DIM}中文版: 命令 openclaw-cn, 源 npm install -g openclaw-cn@latest${C_RESET}"
    echo ""
    
    ui_select "选择版本" "${options[@]}"
    local choice=$?
    
    case $choice in
        0)
            INSTALL_VERSION="international"
            log_info "已选择: 国际版 (openclaw)"
            ;;
        1)
            INSTALL_VERSION="chinese"
            log_info "已选择: 中文版 (openclaw-cn)"
            ;;
        *)
            return 1
            ;;
    esac
    
    return 0
}

# ============================================================================
# 安装方式选择
# ============================================================================

# 选择安装方式
select_install_method() {
    ui_section_title "选择安装方式" "$EMOJI_PACKAGE"
    
    local options=(
        "${EMOJI_ROCKET} 快速安装 (推荐) - 使用官方安装脚本，自动配置"
        "${EMOJI_PACKAGE} 手动安装 - 仅安装 CLI，手动配置"
        "${EMOJI_GEAR} 自定义安装 - 选择要安装的组件"
    )
    
    ui_select "选择安装方式" "${options[@]}"
    local choice=$?
    
    return $choice
}

# ============================================================================
# Node.js 安装
# ============================================================================

# 安装 Node.js
install_nodejs() {
    ui_log_step "安装 Node.js v${MIN_NODE_VERSION}..."
    
    local os_type=$(detect_os)
    
    case "$os_type" in
        linux|wsl)
            install_nodejs_linux
            ;;
        macos)
            install_nodejs_macos
            ;;
        *)
            log_error "不支持的操作系统: $os_type"
            return 1
            ;;
    esac
}

# Linux 安装 Node.js
install_nodejs_linux() {
    ui_spinner_start "正在安装 Node.js..."
    
    # 检测包管理器
    if command_exists apt-get; then
        # Debian/Ubuntu
        curl -fsSL "https://deb.nodesource.com/setup_${MIN_NODE_VERSION}.x" | sudo -E bash - >> "$LOG_FILE" 2>&1
        sudo apt-get install -y nodejs >> "$LOG_FILE" 2>&1
    elif command_exists dnf; then
        # Fedora/RHEL 8+
        curl -fsSL "https://rpm.nodesource.com/setup_${MIN_NODE_VERSION}.x" | sudo bash - >> "$LOG_FILE" 2>&1
        sudo dnf install -y nodejs >> "$LOG_FILE" 2>&1
    elif command_exists yum; then
        # CentOS/RHEL 7
        curl -fsSL "https://rpm.nodesource.com/setup_${MIN_NODE_VERSION}.x" | sudo bash - >> "$LOG_FILE" 2>&1
        sudo yum install -y nodejs >> "$LOG_FILE" 2>&1
    elif command_exists pacman; then
        # Arch Linux
        sudo pacman -Sy --noconfirm nodejs npm >> "$LOG_FILE" 2>&1
    else
        ui_spinner_error "未找到支持的包管理器"
        return 1
    fi
    
    # 验证安装
    if command_exists node && check_node_version $MIN_NODE_VERSION; then
        ui_spinner_success "Node.js $(node --version) 安装成功"
        return 0
    else
        ui_spinner_error "Node.js 安装失败"
        return 1
    fi
}

# macOS 安装 Node.js
install_nodejs_macos() {
    ui_spinner_start "正在安装 Node.js..."
    
    if command_exists brew; then
        brew install node@${MIN_NODE_VERSION} >> "$LOG_FILE" 2>&1
    else
        # 使用官方安装包
        local pkg_url="https://nodejs.org/dist/latest-v${MIN_NODE_VERSION}.x/node-v${MIN_NODE_VERSION}.0.pkg"
        local tmp_pkg="/tmp/node.pkg"
        
        curl -fsSL -o "$tmp_pkg" "$pkg_url" >> "$LOG_FILE" 2>&1
        sudo installer -pkg "$tmp_pkg" -target / >> "$LOG_FILE" 2>&1
        rm -f "$tmp_pkg"
    fi
    
    if command_exists node && check_node_version $MIN_NODE_VERSION; then
        ui_spinner_success "Node.js $(node --version) 安装成功"
        return 0
    else
        ui_spinner_error "Node.js 安装失败"
        return 1
    fi
}

# ============================================================================
# OpenClaw 安装
# ============================================================================

# 安装 OpenClaw CLI
install_openclaw_cli() {
    local version_type="${1:-$INSTALL_VERSION}"
    local package_name
    local cli_name
    
    if [[ "$version_type" == "chinese" ]]; then
        package_name="$NPM_PACKAGE_CHINESE"
        cli_name="openclaw-cn"
    else
        package_name="$NPM_PACKAGE_INTERNATIONAL"
        cli_name="openclaw"
    fi
    
    ui_log_step "安装 $cli_name CLI..."
    
    # 配置 npm 全局目录（避免权限问题）
    setup_npm_global_dir
    
    ui_spinner_start "正在安装 $package_name..."
    
    # 安装
    if npm install -g "${package_name}@latest" >> "$LOG_FILE" 2>&1; then
        ui_spinner_success "$cli_name 安装成功"
        
        # 验证
        if command_exists "$cli_name"; then
            local version=$($cli_name --version 2>/dev/null | head -1)
            log_info "版本: $version"
            return 0
        fi
    fi
    
    ui_spinner_error "$cli_name 安装失败"
    return 1
}

# 配置 npm 全局目录
setup_npm_global_dir() {
    # 创建目录
    ensure_dir "$NPM_GLOBAL" "$CURRENT_USER" "755"
    ensure_dir "$NPM_BIN" "$CURRENT_USER" "755"
    
    # 配置 npm
    npm config set prefix "$NPM_GLOBAL" 2>/dev/null || true
    
    # 添加到 PATH
    if [[ ":$PATH:" != *":$NPM_BIN:"* ]]; then
        export PATH="$NPM_BIN:$PATH"
    fi
    
    # 更新 .bashrc
    local bashrc="$HOME_DIR/.bashrc"
    if [[ -f "$bashrc" ]] && ! grep -q "npm-global" "$bashrc"; then
        cat >> "$bashrc" <<'EOF'

# npm global path (added by OpenClaw Deploy)
export PATH="$HOME/.npm-global/bin:$PATH"
EOF
    fi
}

# ============================================================================
# 目录和权限设置
# ============================================================================

# 设置 OpenClaw 目录结构
setup_openclaw_directories() {
    ui_log_step "创建目录结构..."
    
    # 创建主目录
    ensure_dir "$OPENCLAW_DIR" "$CURRENT_USER" "700"
    
    # 创建子目录
    ensure_dir "$OPENCLAW_CREDENTIALS" "$CURRENT_USER" "700"
    ensure_dir "$OPENCLAW_WORKSPACE" "$CURRENT_USER" "755"
    ensure_dir "$OPENCLAW_WORKSPACE/memory" "$CURRENT_USER" "755"
    ensure_dir "$OPENCLAW_SKILLS" "$CURRENT_USER" "755"
    ensure_dir "$OPENCLAW_LOGS" "$CURRENT_USER" "755"
    ensure_dir "$OPENCLAW_BACKUPS" "$CURRENT_USER" "755"
    ensure_dir "${OPENCLAW_DIR}/agents" "$CURRENT_USER" "755"
    
    log_success "目录结构创建完成"
}

# 设置文件权限
setup_file_permissions() {
    ui_log_step "设置文件权限..."
    
    # 敏感文件权限
    [[ -f "$OPENCLAW_CONFIG" ]] && chmod 600 "$OPENCLAW_CONFIG"
    [[ -f "$OPENCLAW_ENV" ]] && chmod 600 "$OPENCLAW_ENV"
    
    # 目录所有者
    chown -R "$CURRENT_USER:$CURRENT_USER" "$OPENCLAW_DIR" 2>/dev/null || true
    
    log_success "文件权限设置完成"
}

# ============================================================================
# Systemd 服务配置
# ============================================================================

# 安装 systemd 服务
install_systemd_service() {
    if ! has_systemd; then
        log_warning "系统不支持 systemd，跳过服务配置"
        return 0
    fi
    
    ui_log_step "配置 systemd 服务..."
    
    local cli_name="openclaw"
    [[ "$INSTALL_VERSION" == "chinese" ]] && cli_name="openclaw-cn"
    
    local cli_path=$(get_command_path "$cli_name")
    
    if [[ -z "$cli_path" ]]; then
        log_error "找不到 $cli_name 命令"
        return 1
    fi
    
    # 生成服务文件
    local service_content="[Unit]
Description=OpenClaw AI Gateway
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_USER
WorkingDirectory=$HOME_DIR
Environment=PATH=$NPM_BIN:/usr/local/bin:/usr/bin:/bin
Environment=NODE_ENV=production
EnvironmentFile=-$OPENCLAW_ENV
ExecStart=$cli_path gateway
Restart=always
RestartSec=10

# 安全设置
NoNewPrivileges=true
PrivateTmp=true

# 资源限制
MemoryLimit=2G
CPUQuota=150%

[Install]
WantedBy=multi-user.target
"
    
    # 写入服务文件
    echo "$service_content" | sudo tee /etc/systemd/system/openclaw.service > /dev/null
    
    # 重载 systemd
    sudo systemctl daemon-reload
    
    # 启用服务
    sudo systemctl enable openclaw
    
    log_success "systemd 服务配置完成"
}

# ============================================================================
# 完整安装流程
# ============================================================================

# 运行安装
run_installation() {
    local mode="${1:-$INSTALL_MODE}"
    
    save_progress "installation_started"
    
    # 1. 检查 Node.js
    if ! check_node_version $MIN_NODE_VERSION; then
        if [[ "$HAS_NODE" == true ]]; then
            log_warning "Node.js 版本过低 ($NODE_VERSION)，需要升级到 v${MIN_NODE_VERSION}+"
        fi
        
        if ui_confirm "是否安装 Node.js v${MIN_NODE_VERSION}?" "y"; then
            if ! install_nodejs; then
                log_error "Node.js 安装失败"
                return 1
            fi
        else
            log_error "OpenClaw 需要 Node.js v${MIN_NODE_VERSION}+"
            return 1
        fi
    fi
    
    save_progress "nodejs_ready"
    
    # 2. 安装 OpenClaw CLI
    if ! install_openclaw_cli; then
        log_error "OpenClaw CLI 安装失败"
        return 1
    fi
    
    save_progress "cli_installed"
    
    # 3. 创建目录结构
    setup_openclaw_directories
    
    save_progress "directories_created"
    
    # 4. 设置权限
    setup_file_permissions
    
    save_progress "permissions_set"
    
    # 5. 配置 systemd 服务
    if ui_confirm "是否配置 systemd 服务? (推荐)" "y"; then
        install_systemd_service
    fi
    
    save_progress "service_configured"
    
    # 6. 运行配置向导
    if ui_confirm "是否运行配置向导?" "y"; then
        run_config_wizard
    fi
    
    save_progress "installation_completed"
    clear_progress
    
    # 显示完成信息
    show_installation_complete
    
    return 0
}

# 显示安装完成信息
show_installation_complete() {
    local cli_name="openclaw"
    [[ "$INSTALL_VERSION" == "chinese" ]] && cli_name="openclaw-cn"
    
    echo ""
    ui_section_title "安装完成" "$EMOJI_ROCKET"
    
    echo -e "  ${C_SUCCESS}恭喜！OpenClaw 安装成功！${C_RESET}"
    echo ""
    
    ui_panel "快速开始" \
        "启动服务: ${C_CYAN}sudo systemctl start openclaw${C_RESET}" \
        "查看状态: ${C_CYAN}$cli_name status${C_RESET}" \
        "运行诊断: ${C_CYAN}$cli_name doctor${C_RESET}" \
        "配置向导: ${C_CYAN}$cli_name onboard${C_RESET}"
    
    if [[ -f "$OPENCLAW_CONFIG" ]]; then
        local port=$(json_get "$OPENCLAW_CONFIG" ".gateway.port")
        port=${port:-18789}
        echo -e "  Dashboard: ${C_CYAN}http://127.0.0.1:${port}/${C_RESET}"
        echo ""
    fi
    
    ui_tip "如果需要帮助，运行 '$cli_name help' 或查看文档"
}

# ============================================================================
# 升级流程
# ============================================================================

# 运行升级
run_upgrade() {
    ui_section_title "升级 OpenClaw" "$EMOJI_REFRESH"
    
    local cli_name="openclaw"
    local package_name="$NPM_PACKAGE_INTERNATIONAL"
    
    if [[ "$HAS_OPENCLAW_CN" == true ]] && [[ "$HAS_OPENCLAW" != true ]]; then
        cli_name="openclaw-cn"
        package_name="$NPM_PACKAGE_CHINESE"
    fi
    
    # 备份配置
    if [[ -f "$OPENCLAW_CONFIG" ]]; then
        backup_file "$OPENCLAW_CONFIG"
        log_info "已备份配置文件"
    fi
    
    # 停止服务
    if service_is_running "openclaw"; then
        ui_spinner_start "停止服务..."
        sudo systemctl stop openclaw
        ui_spinner_success "服务已停止"
    fi
    
    # 升级
    ui_spinner_start "正在升级 $cli_name..."
    
    if npm update -g "$package_name" >> "$LOG_FILE" 2>&1; then
        ui_spinner_success "升级成功"
    else
        ui_spinner_error "升级失败"
        return 1
    fi
    
    # 显示新版本
    local new_version=$($cli_name --version 2>/dev/null | head -1)
    log_info "新版本: $new_version"
    
    # 运行诊断
    ui_spinner_start "运行诊断..."
    if $cli_name doctor >> "$LOG_FILE" 2>&1; then
        ui_spinner_success "诊断通过"
    else
        ui_spinner_error "诊断发现问题，尝试修复..."
        $cli_name doctor --fix >> "$LOG_FILE" 2>&1
    fi
    
    # 重启服务
    if ui_confirm "是否启动服务?" "y"; then
        sudo systemctl start openclaw
        log_success "服务已启动"
    fi
    
    return 0
}

# ============================================================================
# 导出
# ============================================================================

export INSTALL_URL_INTERNATIONAL INSTALL_URL_CHINESE
export NPM_PACKAGE_INTERNATIONAL NPM_PACKAGE_CHINESE
export MIN_NODE_VERSION

export -f show_root_warning create_openclaw_user handle_root_user prompt_switch_user
export -f select_install_version select_install_method
export -f install_nodejs install_nodejs_linux install_nodejs_macos
export -f install_openclaw_cli setup_npm_global_dir
export -f setup_openclaw_directories setup_file_permissions
export -f install_systemd_service
export -f run_installation show_installation_complete
export -f run_upgrade
