#!/bin/bash
# ============================================================================
# OpenClaw Deploy 2.0 - Self Updater Module
# ============================================================================
# 脚本自更新模块
# ============================================================================

# 防止重复加载
[[ -n "$_UPDATER_LOADED" ]] && return 0
_UPDATER_LOADED=1

# ============================================================================
# 配置
# ============================================================================

# 更新源
UPDATE_REPO="https://github.com/KnowHunters/openclaw-deploy"
UPDATE_RAW_URL="https://raw.githubusercontent.com/KnowHunters/openclaw-deploy/main"
UPDATE_API_URL="https://api.github.com/repos/KnowHunters/openclaw-deploy/releases/latest"

# 当前版本
CURRENT_VERSION="$DEPLOY_VERSION"

# ============================================================================
# 版本检查
# ============================================================================

# 获取最新版本
get_latest_version() {
    local latest=""
    
    # 从 GitHub API 获取
    if check_network; then
        latest=$(fetch_url "$UPDATE_API_URL" 2>/dev/null | grep -oP '"tag_name":\s*"v?\K[^"]+' | head -1)
    fi
    
    echo "${latest:-unknown}"
}

# 检查是否有更新
check_for_updates() {
    ui_spinner_start "检查更新..."
    
    local latest=$(get_latest_version)
    
    ui_spinner_stop
    
    if [[ "$latest" == "unknown" ]]; then
        log_warning "无法获取最新版本信息"
        return 1
    fi
    
    if version_gt "$latest" "$CURRENT_VERSION"; then
        return 0  # 有更新
    fi
    
    return 1  # 无更新
}

# ============================================================================
# 更新功能
# ============================================================================

# 下载更新
download_update() {
    local version="$1"
    local tmp_dir="/tmp/openclaw_deploy_update_$$"
    
    mkdir -p "$tmp_dir"
    
    ui_spinner_start "下载更新 v${version}..."
    
    # 下载主脚本
    if ! download_file "${UPDATE_RAW_URL}/deploy.sh" "$tmp_dir/deploy.sh"; then
        ui_spinner_error "下载失败"
        rm -rf "$tmp_dir"
        return 1
    fi
    
    # 下载库文件
    local lib_files=("ui.sh" "utils.sh" "detector.sh" "installer.sh" "wizard.sh" "software.sh" "skills.sh" "health.sh" "updater.sh")
    
    for lib in "${lib_files[@]}"; do
        if ! download_file "${UPDATE_RAW_URL}/lib/${lib}" "$tmp_dir/lib/${lib}" 2>/dev/null; then
            log_debug "下载 $lib 失败，跳过"
        fi
    done
    
    ui_spinner_success "下载完成"
    
    echo "$tmp_dir"
}

# 应用更新
apply_update() {
    local update_dir="$1"
    local script_path="$PROJECT_ROOT"
    
    ui_spinner_start "应用更新..."
    
    # 备份当前版本
    local backup_dir="$script_path/.backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # 备份主脚本
    [[ -f "$script_path/deploy.sh" ]] && cp "$script_path/deploy.sh" "$backup_dir/"
    
    # 备份库文件
    [[ -d "$script_path/lib" ]] && cp -r "$script_path/lib" "$backup_dir/"
    
    # 复制新文件
    cp "$update_dir/deploy.sh" "$script_path/" 2>/dev/null
    
    if [[ -d "$update_dir/lib" ]]; then
        mkdir -p "$script_path/lib"
        cp "$update_dir/lib/"*.sh "$script_path/lib/" 2>/dev/null
    fi
    
    # 设置权限
    chmod +x "$script_path/deploy.sh"
    chmod +x "$script_path/lib/"*.sh 2>/dev/null
    
    # 清理
    rm -rf "$update_dir"
    
    ui_spinner_success "更新完成"
    
    return 0
}

# 回滚更新
rollback_update() {
    local backup_dir="$1"
    local script_path="$PROJECT_ROOT"
    
    if [[ ! -d "$backup_dir" ]]; then
        log_error "备份目录不存在"
        return 1
    fi
    
    ui_spinner_start "回滚更新..."
    
    # 恢复文件
    [[ -f "$backup_dir/deploy.sh" ]] && cp "$backup_dir/deploy.sh" "$script_path/"
    [[ -d "$backup_dir/lib" ]] && cp -r "$backup_dir/lib" "$script_path/"
    
    ui_spinner_success "回滚完成"
    
    return 0
}

# ============================================================================
# 更新界面
# ============================================================================

# 显示更新界面
show_updater() {
    ui_section_title "检查更新" "$EMOJI_REFRESH"
    
    echo -e "  当前版本: ${C_PRIMARY}v${CURRENT_VERSION}${C_RESET}"
    echo ""
    
    # 检查更新
    local latest=$(get_latest_version)
    
    if [[ "$latest" == "unknown" ]]; then
        log_warning "无法获取最新版本信息"
        log_info "请检查网络连接或访问: $UPDATE_REPO"
        ui_wait_key
        return 1
    fi
    
    echo -e "  最新版本: ${C_PRIMARY}v${latest}${C_RESET}"
    echo ""
    
    if version_gt "$latest" "$CURRENT_VERSION"; then
        echo -e "  ${C_SUCCESS}发现新版本！${C_RESET}"
        echo ""
        
        # 获取更新日志
        show_changelog "$latest"
        
        if ui_confirm "是否更新到 v${latest}?" "y"; then
            run_update "$latest"
        fi
    else
        echo -e "  ${C_SUCCESS}✓ 已是最新版本${C_RESET}"
        echo ""
    fi
    
    ui_wait_key
}

# 显示更新日志
show_changelog() {
    local version="$1"
    
    # 尝试获取更新日志
    local changelog=$(fetch_url "${UPDATE_RAW_URL}/CHANGELOG.md" 2>/dev/null | head -50)
    
    if [[ -n "$changelog" ]]; then
        ui_panel "更新日志" "$changelog"
    fi
}

# 运行更新
run_update() {
    local version="$1"
    
    # 下载
    local update_dir=$(download_update "$version")
    
    if [[ -z "$update_dir" ]] || [[ ! -d "$update_dir" ]]; then
        log_error "下载更新失败"
        return 1
    fi
    
    # 应用
    if apply_update "$update_dir"; then
        echo ""
        log_success "更新成功！请重新运行脚本。"
        echo ""
        echo -e "  ${C_CYAN}bash $PROJECT_ROOT/deploy.sh${C_RESET}"
        echo ""
        
        # 退出以便重新加载
        exit 0
    else
        log_error "更新失败"
        return 1
    fi
}

# ============================================================================
# OpenClaw CLI 更新
# ============================================================================

# 更新 OpenClaw CLI
update_openclaw_cli() {
    local cli_name="openclaw"
    local package_name="openclaw"
    
    if [[ "$INSTALL_VERSION" == "chinese" ]] || command_exists openclaw-cn; then
        cli_name="openclaw-cn"
        package_name="openclaw-cn"
    fi
    
    ui_section_title "更新 OpenClaw CLI" "$EMOJI_REFRESH"
    
    # 获取当前版本
    local current=""
    if command_exists "$cli_name"; then
        current=$($cli_name --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    fi
    
    echo -e "  当前版本: ${C_PRIMARY}${current:-未安装}${C_RESET}"
    
    # 获取最新版本
    ui_spinner_start "检查最新版本..."
    local latest=$(npm view "$package_name" version 2>/dev/null)
    ui_spinner_stop
    
    echo -e "  最新版本: ${C_PRIMARY}${latest:-unknown}${C_RESET}"
    echo ""
    
    if [[ -z "$current" ]]; then
        log_warning "OpenClaw CLI 未安装"
        if ui_confirm "是否安装?" "y"; then
            install_openclaw_cli
        fi
        return
    fi
    
    if [[ "$latest" == "unknown" ]]; then
        log_warning "无法获取最新版本"
        return 1
    fi
    
    if version_gt "$latest" "$current"; then
        echo -e "  ${C_SUCCESS}发现新版本！${C_RESET}"
        echo ""
        
        if ui_confirm "是否更新到 v${latest}?" "y"; then
            # 停止服务
            if service_is_running "openclaw"; then
                ui_spinner_start "停止服务..."
                sudo systemctl stop openclaw
                ui_spinner_success "服务已停止"
            fi
            
            # 更新
            ui_spinner_start "更新 $cli_name..."
            if npm update -g "$package_name" >> "$LOG_FILE" 2>&1; then
                ui_spinner_success "更新成功"
                
                # 运行诊断
                ui_spinner_start "运行诊断..."
                $cli_name doctor >> "$LOG_FILE" 2>&1 || $cli_name doctor --fix >> "$LOG_FILE" 2>&1
                ui_spinner_success "诊断完成"
                
                # 重启服务
                if ui_confirm "是否启动服务?" "y"; then
                    sudo systemctl start openclaw
                    log_success "服务已启动"
                fi
            else
                ui_spinner_error "更新失败"
            fi
        fi
    else
        echo -e "  ${C_SUCCESS}✓ 已是最新版本${C_RESET}"
    fi
    
    ui_wait_key
}

# ============================================================================
# 导出
# ============================================================================

export UPDATE_REPO UPDATE_RAW_URL UPDATE_API_URL CURRENT_VERSION

export -f get_latest_version check_for_updates
export -f download_update apply_update rollback_update
export -f show_updater show_changelog run_update
export -f update_openclaw_cli
