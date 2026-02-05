#!/bin/bash
# ============================================================================
# OpenClaw Deploy 2.0 - Configuration Wizard
# ============================================================================
# 交互式配置向导，引导用户完成 OpenClaw 配置
# v2.1.3: 使用原生 onboard + 自动增强环境
# ============================================================================

# 防止重复加载
[[ -n "$_WIZARD_LOADED" ]] && return 0
_WIZARD_LOADED=1

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
    
    local found_config=false
    for config_file in "${config_locations[@]}"; do
        if [[ -f "$config_file" ]]; then
            chmod 600 "$config_file"
            log_success "权限已修正 (600): $config_file"
            found_config=true
        fi
        
        # 同样检查 .env
        local env_file="${config_file%/*}/.env"
        if [[ -f "$env_file" ]]; then
            chmod 600 "$env_file"
            log_success "权限已修正 (600): $env_file"
        fi
        
        # 检查 keystore
        local keystore_dir="${config_file%/*}/keystore"
        if [[ -d "$keystore_dir" ]]; then
            chmod 700 "$keystore_dir"
            log_success "权限已修正 (700): $keystore_dir"
        fi
    done
    
    if [[ "$found_config" != true ]]; then
        log_warning "未找到生成的配置文件，可能配置未完成或位置非标准"
    fi
    
    # 2. Systemd 服务注册
    echo ""
    ui_log_step "注册系统服务..."
    
    if [[ "$HAS_SYSTEMD" == true ]]; then
        if ui_confirm "是否注册为 Systemd 服务 (开机自启)?" "y"; then
            install_systemd_service
        fi
    else
        log_info "系统不支持 Systemd，跳过服务注册"
    fi
    
    # 3. 最终完成
    echo ""
    ui_panel "配置全部完成!" \
        "您现在可以使用 ${C_GREEN}systemctl start openclaw${C_RESET} 启动服务" \
        "或者直接运行 ${C_GREEN}openclaw start${C_RESET}" \
        " " \
        "查看日志: journalctl -u openclaw -f"
    
    ui_wait_key "按任意键返回主菜单..."
    
    return 0
}

# 导出函数
export -f run_config_wizard
