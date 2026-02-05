#!/bin/bash
# ============================================================================
# OpenClaw Deploy 2.0 - 智能一键部署系统
# ============================================================================
# 
# 使用方法:
#   curl -fsSL https://raw.githubusercontent.com/KnowHunters/openclaw-deploy/main/deploy.sh | bash
#   或
#   bash deploy.sh
#
# 功能:
#   - 智能环境检测，自动判断安装模式
#   - 支持国际版和中文版
#   - 交互式配置向导
#   - 技能管理
#   - 软件安装
#   - 系统状态检查
#   - 脚本自更新
#
# ============================================================================

set -e

# 交互模式默认开启，必要时自动降级
INTERACTIVE=true

# ============================================================================
# 初始化
# ============================================================================

# 检测是否通过管道执行并设置脚本目录
SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
if [[ -p /dev/stdin ]] || [[ ! -f "$SCRIPT_PATH" ]]; then
    # 通过管道执行，创建临时目录
    SCRIPT_DIR=$(mktemp -d)
    IS_PIPED=true
else
    # 本地执行
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" 2>/dev/null && pwd)"
    IS_PIPED=false
fi

# 如果库文件不存在，需要下载
if [[ ! -f "$SCRIPT_DIR/lib/ui.sh" ]]; then
    VERSION="2.1.6"
    echo "正在下载脚本 (v${VERSION})..."
    
    # 下载库文件
    BASE_URL="https://raw.githubusercontent.com/KnowHunters/openclaw-deploy/main"
    mkdir -p "$SCRIPT_DIR/lib"
    
    download_failed=false
    for lib in ui utils detector installer wizard software skills health updater; do
        echo -n "  下载 ${lib}.sh... "
        if curl -fsSL "$BASE_URL/lib/${lib}.sh" -o "$SCRIPT_DIR/lib/${lib}.sh" 2>/dev/null; then
            # 验证文件是否真的下载成功
            if [[ -f "$SCRIPT_DIR/lib/${lib}.sh" ]] && [[ -s "$SCRIPT_DIR/lib/${lib}.sh" ]]; then
                echo "✓"
            else
                echo "✗ (文件为空)"
                download_failed=true
                break
            fi
        else
            echo "✗ (下载失败)"
            download_failed=true
            break
        fi
    done
    
    if [[ "$download_failed" == true ]]; then
        echo ""
        echo "下载失败，请尝试克隆仓库后本地运行："
        echo "  git clone https://github.com/KnowHunters/openclaw-deploy.git"
        echo "  cd openclaw-deploy"
        echo "  bash deploy.sh"
        [[ "$IS_PIPED" == true ]] && rm -rf "$SCRIPT_DIR" 2>/dev/null
        exit 1
    fi
    
    echo ""
    echo "下载完成！"
    echo ""
fi

# 清理函数（仅在管道执行时清理临时目录）
if [[ "$IS_PIPED" == true ]]; then
    cleanup() {
        [[ -n "$SCRIPT_DIR" ]] && [[ -d "$SCRIPT_DIR" ]] && rm -rf "$SCRIPT_DIR" 2>/dev/null
    }
    trap cleanup EXIT
fi

# 加载库文件
source "$SCRIPT_DIR/lib/ui.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/detector.sh"
source "$SCRIPT_DIR/lib/installer.sh"
source "$SCRIPT_DIR/lib/wizard.sh"
source "$SCRIPT_DIR/lib/software.sh"
source "$SCRIPT_DIR/lib/skills.sh"
source "$SCRIPT_DIR/lib/health.sh"
source "$SCRIPT_DIR/lib/updater.sh"

# 如果当前环境没有可用 TTY，自动切换为非交互模式
if [[ "$UI_HAS_TTY" != "true" ]]; then
    INTERACTIVE=false
    AUTO_INSTALL=true
fi

# 显示版本信息，确认脚本已更新
log_info "OpenClaw Deploy v$DEPLOY_VERSION (Build: $(date +%Y-%m-%d))"

# ============================================================================
# 主菜单
# ============================================================================

# 显示主菜单
show_main_menu() {
    while true; do
        ui_clear
        ui_show_banner "$DEPLOY_VERSION"
        
        # 显示当前状态
        local status_text=""
        
        if [[ "$HAS_OPENCLAW" == true ]] || [[ "$HAS_OPENCLAW_CN" == true ]]; then
            local version_type="国际版"
            [[ "$HAS_OPENCLAW_CN" == true ]] && [[ "$HAS_OPENCLAW" != true ]] && version_type="中文版"
            
            if [[ "$OPENCLAW_SERVICE_RUNNING" == true ]]; then
                status_text="OpenClaw ${OPENCLAW_VERSION} (${version_type}) ${C_SUCCESS}● 运行中${C_RESET}"
            else
                status_text="OpenClaw ${OPENCLAW_VERSION} (${version_type}) ${S_DIM}○ 未运行${C_RESET}"
            fi
        else
            status_text="${S_DIM}OpenClaw 未安装${C_RESET}"
        fi
        
        echo -e "  当前状态: $status_text"
        echo ""
        
        # 菜单选项
        local options=()
        
        if [[ "$HAS_OPENCLAW" != true ]] && [[ "$HAS_OPENCLAW_CN" != true ]]; then
            options+=("${EMOJI_ROCKET} 安装 OpenClaw - 开始安装向导")
        else
            case "$SUGGESTED_MODE" in
                upgrade)
                    options+=("${EMOJI_ROCKET} 升级 OpenClaw - 有新版本可用")
                    ;;
                *)
                    options+=("${EMOJI_ROCKET} 重新安装 OpenClaw - 修复或重新配置")
                    ;;
            esac
        fi
        
        options+=("${EMOJI_GEAR} 系统配置向导 - 配置 AI Provider、频道等")
        options+=("${EMOJI_WRENCH} 技能管理 - 搜索、安装、管理技能")
        options+=("${EMOJI_PACKAGE} 软件安装 - 安装系统依赖软件")
        options+=("${EMOJI_HOSPITAL} 系统状态检查 - 健康检查和诊断")
        options+=("${EMOJI_REFRESH} 检查更新 - 更新脚本和 CLI")
        options+=("${EMOJI_HELP} 帮助")
        options+=("${EMOJI_EXIT} 退出")
        
        ui_select "选择操作" "${options[@]}"
        local choice=$?
        
        case $choice in
            0)  # 安装/升级
                if [[ "$HAS_OPENCLAW" != true ]] && [[ "$HAS_OPENCLAW_CN" != true ]]; then
                    run_install_flow
                elif [[ "$SUGGESTED_MODE" == "upgrade" ]]; then
                    run_upgrade
                    ui_wait_key
                else
                    run_reinstall_flow
                fi
                ;;
            1)  # 配置向导
                run_config_wizard
                ui_wait_key
                ;;
            2)  # 技能管理
                show_skills_manager
                ;;
            3)  # 软件安装
                show_software_manager
                ui_wait_key
                ;;
            4)  # 状态检查
                show_health_manager
                ;;
            5)  # 检查更新
                show_update_menu
                ;;
            6)  # 帮助
                show_help
                ;;
            7|255)  # 退出
                echo ""
                log_info "感谢使用 OpenClaw Deploy！"
                echo ""
                exit 0
                ;;
        esac
    done
}

# ============================================================================
# 安装流程
# ============================================================================

# 完整安装流程
run_install_flow() {
    ui_clear
    ui_show_banner "$DEPLOY_VERSION"
    
    # 1. 选择版本
    if ! select_install_version; then
        return 1
    fi
    
    # 2. 选择安装方式
    select_install_method
    local method=$?
    
    case $method in
        0)  # 快速安装
            # 安装必需软件
            install_required_software
            
            # 运行安装
            run_installation "fresh"
            ;;
        1)  # 手动安装
            # 仅安装 CLI
            if ! check_node_version 22; then
                if ui_confirm "需要安装 Node.js，是否继续?" "y"; then
                    install_nodejs
                else
                    return 1
                fi
            fi
            install_openclaw_cli
            setup_openclaw_directories
            ;;
        2)  # 自定义安装
            # 软件选择
            show_software_manager
            
            # 安装 CLI
            install_openclaw_cli
            setup_openclaw_directories
            
            # 配置向导
            if ui_confirm "是否运行配置向导?" "y"; then
                run_config_wizard
            fi
            
            # 服务配置
            if ui_confirm "是否配置 systemd 服务?" "y"; then
                install_systemd_service
            fi
            ;;
        *)
            return 1
            ;;
    esac
    
    ui_wait_key
}

# 重新安装流程
run_reinstall_flow() {
    ui_clear
    ui_section_title "重新安装 OpenClaw" "$EMOJI_REFRESH"
    
    local options=(
        "重新配置 - 保留数据，重新运行配置向导"
        "完全重装 - 删除所有数据，重新安装"
        "修复安装 - 运行诊断并修复问题"
        "← 返回"
    )
    
    ui_select "选择操作" "${options[@]}"
    local choice=$?
    
    case $choice in
        0)  # 重新配置
            run_config_wizard
            ;;
        1)  # 完全重装
            if ui_confirm_dangerous "完全重装 OpenClaw" "这将删除所有配置和数据"; then
                # 备份
                backup_file "$OPENCLAW_CONFIG"
                backup_file "$OPENCLAW_ENV"
                
                # 停止服务
                if service_is_running "openclaw"; then
                    sudo systemctl stop openclaw
                fi
                
                # 删除配置
                rm -rf "$OPENCLAW_DIR"
                
                # 重新安装
                run_install_flow
            fi
            ;;
        2)  # 修复
            run_diagnostics
            ;;
    esac
    
    ui_wait_key
}

# ============================================================================
# 更新菜单
# ============================================================================

show_update_menu() {
    ui_clear
    ui_section_title "检查更新" "$EMOJI_REFRESH"
    
    local options=(
        "更新部署脚本 - 更新此安装脚本"
        "更新 OpenClaw CLI - 更新 OpenClaw 命令行工具"
        "更新所有技能 - 更新已安装的技能"
        "← 返回"
    )
    
    ui_select "选择操作" "${options[@]}"
    local choice=$?
    
    case $choice in
        0) show_updater ;;
        1) update_openclaw_cli ;;
        2) update_all_skills; ui_wait_key ;;
    esac
}

# ============================================================================
# 帮助
# ============================================================================

show_help() {
    ui_clear
    ui_section_title "帮助" "$EMOJI_HELP"
    
    cat <<'EOF'

  OpenClaw Deploy 是一个智能一键部署系统，帮助你快速安装和配置 OpenClaw。

  功能说明:

    🚀 安装 OpenClaw
       安装 OpenClaw CLI 和相关依赖，支持国际版和中文版。

    ⚙️  系统配置向导
       交互式配置 AI Provider、模型、频道、Gateway 等。

    🔧 技能管理
       搜索、安装、管理 OpenClaw 技能。

    📦 软件安装
       安装系统依赖软件，如 Node.js、ffmpeg 等。

    🏥 系统状态检查
       检查服务状态、配置、资源使用，诊断和修复问题。

    🔄 检查更新
       更新部署脚本、OpenClaw CLI 和技能。

  快捷键:

    ↑/↓     选择菜单项
    Enter   确认选择
    Space   多选时切换选中状态
    q       退出/返回
    ?       查看帮助（在输入框中）

  常用命令:

    openclaw status       查看状态
    openclaw doctor       运行诊断
    openclaw gateway      启动 Gateway
    openclaw onboard      运行配置向导

  更多信息:

    官方文档: https://docs.openclaw.ai/
    中文文档: https://clawd.org.cn/
    GitHub:   https://github.com/openclaw/openclaw

EOF

    ui_wait_key
}

# ============================================================================
# 首次运行欢迎
# ============================================================================

show_first_run_welcome() {
    ui_clear
    ui_show_banner "$DEPLOY_VERSION"
    
    echo -e "  ${EMOJI_WAVE} ${S_BOLD}欢迎使用 OpenClaw 智能部署系统！${C_RESET}"
    echo ""
    echo -e "  这是一个交互式安装向导，会一步步引导您完成安装。"
    echo ""
    echo -e "  ${S_BOLD}使用提示:${C_RESET}"
    echo -e "    • 使用 ${C_CYAN}↑↓${C_RESET} 键选择选项"
    echo -e "    • 按 ${C_CYAN}Enter${C_RESET} 确认选择"
    echo -e "    • 输入 ${C_CYAN}?${C_RESET} 可以查看帮助说明"
    echo -e "    • 按 ${C_CYAN}Ctrl+C${C_RESET} 可以随时退出"
    echo ""
    echo -e "  如果遇到问题，系统会提供详细的解决方案。"
    echo ""
    
    if ui_confirm "是否开启新手引导模式? (会显示更多说明)" "y"; then
        BEGINNER_MODE=true
    else
        BEGINNER_MODE=false
    fi
}

# ============================================================================
# 主函数
# ============================================================================

main() {
    # 初始化日志
    log_init
    
    # 设置错误处理
    setup_error_handling
    
    # 检查是否有未完成的安装
    if check_incomplete_install; then
        ui_clear
        ui_show_banner "$DEPLOY_VERSION"
        
        ui_panel "检测到未完成的安装" \
            "上次步骤: $INSTALL_STEP" \
            "安装用户: $INSTALL_USER" \
            "安装版本: $INSTALL_VERSION"
        
        if ui_confirm "是否从上次中断处继续?" "y"; then
            # 恢复安装
            OPENCLAW_USER="$INSTALL_USER"
            run_installation "$INSTALL_MODE"
            ui_wait_key
        else
            clear_progress
        fi
    fi
    
    # 检测当前用户
    if is_root; then
        ui_clear
        ui_show_banner "$DEPLOY_VERSION"
        
        if ! handle_root_user; then
            exit 1
        fi
        
        # 如果创建了新用户或选择切换，脚本会退出
        # 如果选择强制继续，则继续执行
    fi
    
    # 检查用户权限
    if ! detect_user; then
        log_error "用户环境检测失败"
        exit 1
    fi
    
    # 运行环境检测
    run_full_detection
    
    # 非交互模式下自动执行默认流程
    if [[ "$INTERACTIVE" != "true" ]]; then
        show_detection_result
        run_non_interactive_flow
        exit $?
    fi
    
    # 首次运行欢迎
    local first_run=false
    if [[ "$HAS_OPENCLAW" != true ]] && [[ "$HAS_OPENCLAW_CN" != true ]]; then
        first_run=true
    fi
    
    if [[ "$first_run" == true ]]; then
        show_first_run_welcome
        
        # 显示检测结果
        show_detection_result
        
        if ui_confirm "检测到 OpenClaw 未安装，是否开始安装向导?" "y"; then
            run_install_flow
            
            # 重新检测
            run_full_detection
        fi
    fi
    
    # 进入主菜单
    show_main_menu
}

# ============================================================================
# 非交互流程
# ============================================================================

run_non_interactive_flow() {
    log_info "非交互模式：自动执行默认流程"
    
    # 选择版本默认值
    if [[ -z "$INSTALL_VERSION" ]]; then
        if [[ "$HAS_OPENCLAW_CN" == "true" ]] && [[ "$HAS_OPENCLAW" != "true" ]]; then
            INSTALL_VERSION="chinese"
        else
            INSTALL_VERSION="international"
        fi
    fi
    
    case "$SUGGESTED_MODE" in
        fresh)
            INSTALL_MODE="fresh"
            log_info "自动安装版本: $INSTALL_VERSION"
            run_installation "fresh"
            ;;
        upgrade)
            log_info "检测到可升级版本，开始升级"
            run_upgrade
            ;;
        reinstall)
            log_info "已是最新版本，运行诊断与修复"
            run_diagnostics
            ;;
        *)
            log_warning "无法确定安装模式，跳过自动流程"
            return 1
            ;;
    esac
}

# ============================================================================
# 命令行参数处理
# ============================================================================

# 显示版本
show_version() {
    echo "OpenClaw Deploy v$DEPLOY_VERSION"
}

# 显示使用帮助
show_usage() {
    cat <<EOF
OpenClaw Deploy v$DEPLOY_VERSION - 智能一键部署系统

使用方法:
  bash deploy.sh [选项]

选项:
  -h, --help        显示此帮助信息
  -v, --version     显示版本号
  --install         直接开始安装
  --chinese         安装中文版
  --international   安装国际版
  --no-interactive  非交互模式
  --debug           调试模式

示例:
  bash deploy.sh                    # 交互式安装
  bash deploy.sh --install          # 直接开始安装
  bash deploy.sh --chinese          # 安装中文版

更多信息请访问: https://github.com/KnowHunters/openclaw-deploy
EOF
}

# 解析参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            --install)
                AUTO_INSTALL=true
                ;;
            --chinese)
                INSTALL_VERSION="chinese"
                ;;
            --international)
                INSTALL_VERSION="international"
                ;;
            --no-interactive)
                INTERACTIVE=false
                ;;
            --debug)
                DEBUG=true
                ;;
            *)
                echo "未知选项: $1"
                show_usage
                exit 1
                ;;
        esac
        shift
    done
}

# ============================================================================
# 入口点
# ============================================================================

# 解析命令行参数
parse_args "$@"

# 运行主函数
main
