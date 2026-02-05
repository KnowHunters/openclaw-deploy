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
        "当您看到 ${C_GREEN}'Onboarding complete'${C_RESET} 提示后，" \
        "${C_WARNING}请按 [Ctrl+C] 停止 onboard${C_RESET}，脚本将自动继续后续步骤。" \
        "(如权限修正、Systemd 服务注册等)"
        
    ui_wait_key "按任意键启动配置..."
    
    # 运行原生 onboard
    echo "启动配置工具..."
    
    # 临时忽略 INT 信号 (在此脚本层面)，让 onboard 接收 Ctrl+C 退出
    # 而 deploy.sh 本身不退出，而是捕获错误码并继续
    trap '' INT
    
    set +e # 临时允许返回非零状态
    $cli_name onboard < /dev/tty
    local exit_code=$?
    set -e # 恢复严格模式
    
    # 恢复原来的信号处理
    trap 'handle_interrupt' INT
    
    # 130 是 SIGINT (Ctrl+C)，1 是可能的通用错误退出（也可能是手动中断）
    if [[ $exit_code -eq 0 ]] || [[ $exit_code -eq 130 ]] || [[ $exit_code -eq 1 ]]; then
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
        local os_type=$(detect_os)
        if [[ "$os_type" == "wsl" ]]; then
            log_warning "检测到 WSL 环境，但 Systemd 未启用"
            ui_tip "在 WSL 中启用 Systemd 的方法:
1. 编辑配置文件: sudo nano /etc/wsl.conf
2. 添加以下内容:
   [boot]
   systemd=true
3. 在 Windows CMD 中重启 WSL: wsl --shutdown
4. 重新进入 WSL 即可生效"
        else
            log_warning "未检测到活跃的 Systemd 环境"
            if ui_confirm "如果您确定系统支持 Systemd，是否强制注册服务?" "n"; then
                install_systemd_service
                HAS_SYSTEMD=true # 标记为 true 以便后续提示正确
            else
                log_info "跳过服务注册"
            fi
        fi
    fi
    
    # 3. 初始化工作区 (人格与记忆)
    echo ""
    ui_log_step "初始化工作区 (人格/记忆)..."
    generate_workspace_templates
    
    # 4. 最终完成
    echo ""
    
    if [[ "$HAS_SYSTEMD" == true ]]; then
        ui_panel "配置全部完成!" \
            "您现在可以使用 ${C_GREEN}systemctl start openclaw${C_RESET} 启动服务" \
            "或者直接运行 ${C_GREEN}openclaw start${C_RESET}" \
            " " \
            "查看日志: journalctl -u openclaw -f"
    else
        local start_tip="由于系统不支持 Systemd (或未启用)，请手动启动："
        [[ "$(detect_os)" == "wsl" ]] && start_tip="WSL 未启用 Systemd，建议手动启动："
        
        ui_panel "配置全部完成!" \
            "$start_tip" \
            "${C_GREEN}nohup openclaw gateway > openclaw.log 2>&1 &${C_RESET}" \
            " " \
            "或者前台运行: ${C_GREEN}openclaw start${C_RESET}"
    fi
    
    ui_wait_key "按任意键返回主菜单..."
    
    return 0
}


# ============================================================================
# 辅助函数
# ============================================================================

# 生成工作区模板 (人格、记忆结构)
generate_workspace_templates() {
    local workspace="$OPENCLAW_WORKSPACE"
    
    # 确保目录存在
    ensure_dir "$workspace"
    ensure_dir "$workspace/memory"
    ensure_dir "$workspace/memory/notes"
    ensure_dir "$workspace/memory/tasks"
    ensure_dir "$workspace/memory/ideas"
    
    ui_log_step "创建基础目录结构: $workspace"
    
    # SOUL.md - 如果不存在才创建
    if [[ ! -f "$workspace/SOUL.md" ]]; then
        cat > "$workspace/SOUL.md" <<'EOF'
# SOUL.md - Bot 人格定义

## Mission（使命）
成为最有用的个人助理，帮助主人管理任务、记录灵感、提供信息支持。

## Personality（个性）
- **高效务实**：不废话，直击要点
- **友好但不油腻**：专业但有温度
- **主动但不打扰**：该提醒时提醒，不该说话时闭嘴
- **可靠靠谱**：说到做到，不丢球
- **幽默感**：适当时候展示一点幽默，但不强行搞笑

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
        log_success "已创建 SOUL.md (人格定义)"
    else
        log_info "SOUL.md 已存在，跳过"
    fi

    # IDENTITY.md
    if [[ ! -f "$workspace/IDENTITY.md" ]]; then
        cat > "$workspace/IDENTITY.md" <<'EOF'
# IDENTITY.md - Bot 身份信息

- **Name:** OpenClaw Assistant
- **Emoji:** 🦞
- **Role:** 个人助理 / 生活管家
- **Version:** 2.0

## Owner（主人信息）
- Timezone: Asia/Shanghai
- Preferred Language: 中文

## Capabilities（能力清单）
### ✅ 我能做的
- 记录和查询信息
- 提醒和日程管理
- 信息搜索和整理
- 简单任务自动化
- 代码辅助与 Code Review

### ❌ 我不能做的
- 写长篇小说
- 涉及违规或有害内容
- 替你做人生重大决策
EOF
        log_success "已创建 IDENTITY.md (身份信息)"
    else
        log_info "IDENTITY.md 已存在，跳过"
    fi
    
    # MEMORY.md
    if [[ ! -f "$workspace/memory/MEMORY.md" ]]; then
        cat > "$workspace/memory/MEMORY.md" <<'EOF'
# 我的记忆库

这里存储我的所有记忆和知识。我是一个善于学习和总结的 AI 助手。

## 索引结构
- 📝 **笔记 (notes/)**: 临时想法、会议记录、读书笔记
- ✅ **任务 (tasks/)**: 待办事项、项目进度
- 💡 **创意 (ideas/)**: 灵感碎片、Brainstorming
- 📚 **知识 (knowledge/)**: 长期沉淀的知识库

## 使用说明
- **记录时**: 使用触发词：记下、待办、想法等
- **查询时**: 使用：查、找、搜等关键词
- **自动整理**: 我会定期整理这里的 Markdown 文件
EOF
        log_success "已创建 MEMORY.md (记忆索引)"
    fi
}

# 导出函数
export -f run_config_wizard
