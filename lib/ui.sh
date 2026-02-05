#!/bin/bash
# ============================================================================
# OpenClaw Deploy 2.0 - UI Framework
# ============================================================================
# 统一的用户界面框架，提供颜色、组件、动画等功能
# ============================================================================

# 防止重复加载
[[ -n "$_UI_LOADED" ]] && return 0
_UI_LOADED=1

# ============================================================================
# 颜色定义
# ============================================================================

# 检测终端是否支持颜色
if [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]]; then
    UI_COLOR_SUPPORT=true
else
    UI_COLOR_SUPPORT=false
fi

# 基础颜色
if [[ "$UI_COLOR_SUPPORT" == true ]]; then
    # 主色调
    C_PRIMARY="\033[38;5;39m"       # 蓝色 - 主要信息
    C_SUCCESS="\033[38;5;82m"       # 绿色 - 成功
    C_WARNING="\033[38;5;220m"      # 黄色 - 警告
    C_ERROR="\033[38;5;196m"        # 红色 - 错误
    C_INFO="\033[38;5;245m"         # 灰色 - 次要信息
    C_ACCENT="\033[38;5;213m"       # 紫色 - 强调
    C_CYAN="\033[38;5;51m"          # 青色 - 标题
    C_WHITE="\033[38;5;255m"        # 白色
    C_ORANGE="\033[38;5;208m"       # 橙色
    
    # 样式
    S_BOLD="\033[1m"
    S_DIM="\033[2m"
    S_ITALIC="\033[3m"
    S_UNDERLINE="\033[4m"
    S_BLINK="\033[5m"
    S_REVERSE="\033[7m"
    
    # 重置
    C_RESET="\033[0m"
    
    # 光标控制
    CURSOR_UP="\033[A"
    CURSOR_DOWN="\033[B"
    CURSOR_RIGHT="\033[C"
    CURSOR_LEFT="\033[D"
    CURSOR_SAVE="\033[s"
    CURSOR_RESTORE="\033[u"
    CURSOR_HIDE="\033[?25l"
    CURSOR_SHOW="\033[?25h"
    CLEAR_LINE="\033[2K"
    CLEAR_SCREEN="\033[2J"
else
    # 无颜色支持时的空值
    C_PRIMARY="" C_SUCCESS="" C_WARNING="" C_ERROR="" C_INFO=""
    C_ACCENT="" C_CYAN="" C_WHITE="" C_ORANGE=""
    S_BOLD="" S_DIM="" S_ITALIC="" S_UNDERLINE="" S_BLINK="" S_REVERSE=""
    C_RESET=""
    CURSOR_UP="" CURSOR_DOWN="" CURSOR_RIGHT="" CURSOR_LEFT=""
    CURSOR_SAVE="" CURSOR_RESTORE="" CURSOR_HIDE="" CURSOR_SHOW=""
    CLEAR_LINE="" CLEAR_SCREEN=""
fi

# ============================================================================
# 图标定义
# ============================================================================

# 状态图标
ICON_SUCCESS="✓"
ICON_ERROR="✗"
ICON_WARNING="!"
ICON_INFO="ℹ"
ICON_PENDING="○"
ICON_RUNNING="◉"
ICON_ARROW="❯"
ICON_CHECK="✓"
ICON_CROSS="✗"
ICON_STAR="★"
ICON_BULLET="•"

# Emoji 图标
EMOJI_ROCKET="🚀"
EMOJI_GEAR="⚙️"
EMOJI_WRENCH="🔧"
EMOJI_PACKAGE="📦"
EMOJI_HOSPITAL="🏥"
EMOJI_REFRESH="🔄"
EMOJI_HELP="❓"
EMOJI_EXIT="🚪"
EMOJI_SEARCH="🔍"
EMOJI_LOCK="🔐"
EMOJI_USER="👤"
EMOJI_NEW="🆕"
EMOJI_WARNING="⚠️"
EMOJI_GLOBE="🌍"
EMOJI_CN="🇨🇳"
EMOJI_CLAW="🦞"
EMOJI_WAVE="👋"
EMOJI_LIGHT="💡"
EMOJI_FOLDER="📁"
EMOJI_FILE="📄"
EMOJI_CLOCK="⏰"

# ============================================================================
# Banner 显示
# ============================================================================

# 显示主 Banner
ui_show_banner() {
    local version="${1:-2.0}"
    
    echo ""
    echo -e "${C_CYAN}╔══════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_CYAN}║${C_RESET}                                                              ${C_CYAN}║${C_RESET}"
    echo -e "${C_CYAN}║${C_RESET}     ${C_PRIMARY}██████╗ ██████╗ ███████╗███╗   ██╗ ██████╗██╗      █████╗${C_RESET} ${C_CYAN}║${C_RESET}"
    echo -e "${C_CYAN}║${C_RESET}    ${C_PRIMARY}██╔═══██╗██╔══██╗██╔════╝████╗  ██║██╔════╝██║     ██╔══██╗${C_RESET}${C_CYAN}║${C_RESET}"
    echo -e "${C_CYAN}║${C_RESET}    ${C_PRIMARY}██║   ██║██████╔╝█████╗  ██╔██╗ ██║██║     ██║     ███████║${C_RESET}${C_CYAN}║${C_RESET}"
    echo -e "${C_CYAN}║${C_RESET}    ${C_PRIMARY}██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║██║     ██║     ██╔══██║${C_RESET}${C_CYAN}║${C_RESET}"
    echo -e "${C_CYAN}║${C_RESET}    ${C_PRIMARY}╚██████╔╝██║     ███████╗██║ ╚████║╚██████╗███████╗██║  ██║${C_RESET}${C_CYAN}║${C_RESET}"
    echo -e "${C_CYAN}║${C_RESET}     ${C_PRIMARY}╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝ ╚═════╝╚══════╝╚═╝  ╚═╝${C_RESET}${C_CYAN}║${C_RESET}"
    echo -e "${C_CYAN}║${C_RESET}                                                              ${C_CYAN}║${C_RESET}"
    echo -e "${C_CYAN}║${C_RESET}              ${EMOJI_CLAW} ${S_BOLD}智能一键部署系统${C_RESET} v${version}                       ${C_CYAN}║${C_RESET}"
    echo -e "${C_CYAN}║${C_RESET}                                                              ${C_CYAN}║${C_RESET}"
    echo -e "${C_CYAN}╚══════════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""
}

# 显示小型 Banner
ui_show_mini_banner() {
    echo ""
    echo -e "  ${C_CYAN}${S_BOLD}${EMOJI_CLAW} OpenClaw Deploy${C_RESET} ${S_DIM}v2.0${C_RESET}"
    echo ""
}

# ============================================================================
# 日志输出
# ============================================================================

# 成功日志
ui_log_success() {
    echo -e "  ${C_SUCCESS}${ICON_SUCCESS}${C_RESET} $1"
}

# 错误日志
ui_log_error() {
    echo -e "  ${C_ERROR}${ICON_ERROR}${C_RESET} $1" >&2
}

# 警告日志
ui_log_warning() {
    echo -e "  ${C_WARNING}${ICON_WARNING}${C_RESET} $1"
}

# 信息日志
ui_log_info() {
    echo -e "  ${C_INFO}${ICON_INFO}${C_RESET} $1"
}

# 步骤日志
ui_log_step() {
    echo -e "  ${C_CYAN}${ICON_ARROW}${C_RESET} ${S_BOLD}$1${C_RESET}"
}

# 调试日志（仅在 DEBUG 模式下显示）
ui_log_debug() {
    [[ "${DEBUG:-}" == "true" ]] && echo -e "  ${S_DIM}[DEBUG] $1${C_RESET}"
}

# ============================================================================
# 进度条
# ============================================================================

# 显示进度条
# 用法: ui_progress_bar <current> <total> [width]
ui_progress_bar() {
    local current=$1
    local total=$2
    local width=${3:-50}
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r  ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %3d%%" "$percent"
}

# 完成进度条（换行）
ui_progress_done() {
    echo ""
}

# ============================================================================
# 旋转加载动画
# ============================================================================

# 全局变量存储 spinner 进程 ID
_SPINNER_PID=""

# 启动 spinner
# 用法: ui_spinner_start "正在处理..."
ui_spinner_start() {
    local message="$1"
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    # 隐藏光标
    echo -ne "${CURSOR_HIDE}"
    
    (
        local i=0
        while true; do
            local char="${spinstr:$i:1}"
            printf "\r  ${C_CYAN}%s${C_RESET} %s" "$char" "$message"
            i=$(( (i + 1) % 10 ))
            sleep 0.1
        done
    ) &
    _SPINNER_PID=$!
}

# 停止 spinner 并显示成功
ui_spinner_success() {
    local message="$1"
    
    if [[ -n "$_SPINNER_PID" ]]; then
        kill "$_SPINNER_PID" 2>/dev/null
        wait "$_SPINNER_PID" 2>/dev/null
        _SPINNER_PID=""
    fi
    
    printf "\r${CLEAR_LINE}"
    echo -e "  ${C_SUCCESS}${ICON_SUCCESS}${C_RESET} $message"
    echo -ne "${CURSOR_SHOW}"
}

# 停止 spinner 并显示失败
ui_spinner_error() {
    local message="$1"
    
    if [[ -n "$_SPINNER_PID" ]]; then
        kill "$_SPINNER_PID" 2>/dev/null
        wait "$_SPINNER_PID" 2>/dev/null
        _SPINNER_PID=""
    fi
    
    printf "\r${CLEAR_LINE}"
    echo -e "  ${C_ERROR}${ICON_ERROR}${C_RESET} $message"
    echo -ne "${CURSOR_SHOW}"
}

# 停止 spinner（不显示消息）
ui_spinner_stop() {
    if [[ -n "$_SPINNER_PID" ]]; then
        kill "$_SPINNER_PID" 2>/dev/null
        wait "$_SPINNER_PID" 2>/dev/null
        _SPINNER_PID=""
    fi
    printf "\r${CLEAR_LINE}"
    echo -ne "${CURSOR_SHOW}"
}

# ============================================================================
# 输入组件
# ============================================================================

# 普通输入框
# 用法: result=$(ui_input "提示" "默认值")
ui_input() {
    local prompt="$1"
    local default="$2"
    local result
    
    # 提示输出到 stderr，避免被 $() 捕获
    echo -ne "  ${S_BOLD}${prompt}${C_RESET}" >&2
    [[ -n "$default" ]] && echo -ne " ${S_DIM}[$default]${C_RESET}" >&2
    echo -ne ": " >&2
    
    # 从 /dev/tty 读取，确保在管道执行时也能获取用户输入
    read -r result </dev/tty
    echo "${result:-$default}"
}

# 密码输入框（不显示输入）
# 用法: result=$(ui_input_secret "提示")
ui_input_secret() {
    local prompt="$1"
    local result
    
    echo -ne "  ${S_BOLD}${prompt}${C_RESET}: " >&2
    read -rs result </dev/tty
    echo "" >&2
    echo "$result"
}

# 带帮助的输入框
# 用法: result=$(ui_input_with_help "提示" "默认值" "帮助信息")
ui_input_with_help() {
    local prompt="$1"
    local default="$2"
    local help_text="$3"
    local result
    
    while true; do
        # 提示输出到 stderr，避免被 $() 捕获
        echo -ne "  ${S_BOLD}${prompt}${C_RESET}" >&2
        [[ -n "$default" ]] && echo -ne " ${S_DIM}[$default]${C_RESET}" >&2
        echo -ne " ${S_DIM}(? 查看帮助)${C_RESET}: " >&2
        
        read -r result </dev/tty
        
        if [[ "$result" == "?" ]]; then
            echo "" >&2
            echo -e "  ${C_INFO}┌─────────────────────────────────────────────────────────┐${C_RESET}" >&2
            echo -e "  ${C_INFO}│${C_RESET} ${EMOJI_LIGHT} ${S_BOLD}帮助${C_RESET}" >&2
            echo -e "  ${C_INFO}├─────────────────────────────────────────────────────────┤${C_RESET}" >&2
            echo "$help_text" | while IFS= read -r line; do
                echo -e "  ${C_INFO}│${C_RESET}   $line" >&2
            done
            echo -e "  ${C_INFO}└─────────────────────────────────────────────────────────┘${C_RESET}" >&2
            echo "" >&2
        else
            break
        fi
    done
    
    echo "${result:-$default}"
}

# ============================================================================
# 确认框
# ============================================================================

# 确认框
# 用法: if ui_confirm "确认操作?"; then ... fi
# 用法: if ui_confirm "确认操作?" "y"; then ... fi  # 默认 yes
ui_confirm() {
    local message="$1"
    local default="${2:-n}"
    local hint="y/N"
    local answer
    
    [[ "$default" == "y" ]] && hint="Y/n"
    
    echo -ne "  ${C_WARNING}?${C_RESET} ${message} ${S_DIM}[$hint]${C_RESET}: "
    read -r answer </dev/tty
    answer="${answer:-$default}"
    
    [[ "$answer" =~ ^[Yy]$ ]]
}

# 危险操作确认（需要输入确认文字）
# 用法: if ui_confirm_dangerous "删除所有数据" "此操作不可恢复"; then ... fi
ui_confirm_dangerous() {
    local action="$1"
    local description="$2"
    
    echo ""
    echo -e "  ${C_ERROR}╔═══════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "  ${C_ERROR}║${C_RESET}  ${EMOJI_WARNING} ${S_BOLD}警告：即将执行敏感操作${C_RESET}                              ${C_ERROR}║${C_RESET}"
    echo -e "  ${C_ERROR}╚═══════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""
    echo -e "  ${S_BOLD}操作：${C_RESET}$action"
    echo -e "  ${S_BOLD}说明：${C_RESET}$description"
    echo ""
    echo -e "  ${C_WARNING}此操作可能会造成数据丢失，请谨慎操作！${C_RESET}"
    echo ""
    echo -e "  请输入 ${S_BOLD}确认${C_RESET} 继续，或按 Enter 取消："
    
    local confirm_text
    read -r confirm_text </dev/tty
    
    [[ "$confirm_text" == "确认" || "$confirm_text" == "confirm" ]]
}

# ============================================================================
# 选择菜单
# ============================================================================

# 单选菜单
# 用法: ui_select "标题" "选项1" "选项2" "选项3"
# 返回: 选中的索引 (0-based)，255 表示取消
ui_select() {
    local title="$1"
    shift
    local options=("$@")
    local selected=0
    local key
    
    # 隐藏光标
    echo -ne "${CURSOR_HIDE}"
    
    # 保存光标位置
    local menu_start_line
    
    while true; do
        # 清除菜单区域并重绘
        echo -e "\n  ${S_BOLD}${title}${C_RESET}\n"
        
        for i in "${!options[@]}"; do
            if [[ $i -eq $selected ]]; then
                echo -e "  ${C_PRIMARY}${ICON_ARROW} ${options[$i]}${C_RESET}"
            else
                echo -e "    ${S_DIM}${options[$i]}${C_RESET}"
            fi
        done
        
        echo -e "\n  ${S_DIM}↑/↓ 选择  Enter 确认  q 退出${C_RESET}"
        
        # 读取按键
        read -rsn1 key </dev/tty
        
        case "$key" in
            A|k) # 上
                ((selected > 0)) && ((selected--))
                ;;
            B|j) # 下
                ((selected < ${#options[@]}-1)) && ((selected++))
                ;;
            '') # Enter
                echo -ne "${CURSOR_SHOW}"
                return $selected
                ;;
            q|Q) # 退出
                echo -ne "${CURSOR_SHOW}"
                return 255
                ;;
        esac
        
        # 移动光标回到菜单开始位置
        local lines=$((${#options[@]} + 5))
        for ((i=0; i<lines; i++)); do
            echo -ne "${CURSOR_UP}${CLEAR_LINE}"
        done
    done
}

# 多选菜单
# 用法: ui_multi_select "标题" "选项1" "选项2" "选项3"
# 返回: 通过 SELECTED_ITEMS 数组返回选中的索引
ui_multi_select() {
    local title="$1"
    shift
    local options=("$@")
    local current=0
    local key
    
    # 初始化选中状态数组
    local selected=()
    for i in "${!options[@]}"; do
        selected[$i]=0
    done
    
    # 隐藏光标
    echo -ne "${CURSOR_HIDE}"
    
    while true; do
        echo -e "\n  ${S_BOLD}${title}${C_RESET}\n"
        
        for i in "${!options[@]}"; do
            local checkbox="[ ]"
            [[ ${selected[$i]} -eq 1 ]] && checkbox="[${C_SUCCESS}✓${C_RESET}]"
            
            if [[ $i -eq $current ]]; then
                echo -e "  ${C_PRIMARY}${ICON_ARROW}${C_RESET} $checkbox ${options[$i]}"
            else
                echo -e "    $checkbox ${S_DIM}${options[$i]}${C_RESET}"
            fi
        done
        
        echo -e "\n  ${S_DIM}↑/↓ 移动  Space 选择  Enter 确认  a 全选  n 全不选${C_RESET}"
        
        # 读取按键
        read -rsn1 key </dev/tty
        
        case "$key" in
            A|k) # 上
                ((current > 0)) && ((current--))
                ;;
            B|j) # 下
                ((current < ${#options[@]}-1)) && ((current++))
                ;;
            ' ') # 空格 - 切换选中
                selected[$current]=$((1 - ${selected[$current]}))
                ;;
            a|A) # 全选
                for i in "${!options[@]}"; do
                    selected[$i]=1
                done
                ;;
            n|N) # 全不选
                for i in "${!options[@]}"; do
                    selected[$i]=0
                done
                ;;
            '') # Enter
                echo -ne "${CURSOR_SHOW}"
                # 返回选中的索引
                SELECTED_ITEMS=()
                for i in "${!selected[@]}"; do
                    [[ ${selected[$i]} -eq 1 ]] && SELECTED_ITEMS+=($i)
                done
                return 0
                ;;
            q|Q) # 退出
                echo -ne "${CURSOR_SHOW}"
                SELECTED_ITEMS=()
                return 255
                ;;
        esac
        
        # 移动光标回到菜单开始位置
        local lines=$((${#options[@]} + 5))
        for ((i=0; i<lines; i++)); do
            echo -ne "${CURSOR_UP}${CLEAR_LINE}"
        done
    done
}

# ============================================================================
# 信息面板
# ============================================================================

# 显示信息面板
# 用法: ui_panel "标题" "行1" "行2" "行3"
ui_panel() {
    local title="$1"
    shift
    local items=("$@")
    
    echo ""
    echo -e "  ┌─────────────────────────────────────────────────────────┐"
    echo -e "  │ ${S_BOLD}${title}${C_RESET}"
    echo -e "  ├─────────────────────────────────────────────────────────┤"
    
    for item in "${items[@]}"; do
        echo -e "  │   $item"
    done
    
    echo -e "  └─────────────────────────────────────────────────────────┘"
    echo ""
}

# 显示键值对面板
# 用法: ui_kv_panel "标题" "键1:值1" "键2:值2"
ui_kv_panel() {
    local title="$1"
    shift
    local items=("$@")
    
    echo ""
    echo -e "  ┌─────────────────────────────────────────────────────────┐"
    echo -e "  │ ${S_BOLD}${title}${C_RESET}"
    echo -e "  ├─────────────────────────────────────────────────────────┤"
    
    for item in "${items[@]}"; do
        local key="${item%%:*}"
        local value="${item#*:}"
        printf "  │   %-16s %s\n" "$key" "$value"
    done
    
    echo -e "  └─────────────────────────────────────────────────────────┘"
    echo ""
}

# ============================================================================
# 分隔线和标题
# ============================================================================

# 显示分隔线
ui_divider() {
    echo -e "  ${S_DIM}─────────────────────────────────────────────────────────────${C_RESET}"
}

# 显示步骤标题
# 用法: ui_step_title 1 6 "配置 AI Provider"
ui_step_title() {
    local current=$1
    local total=$2
    local title=$3
    
    echo ""
    echo -e "  ${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "  ${S_BOLD}步骤 ${current}/${total}: ${title}${C_RESET}"
    echo -e "  ${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo ""
}

# 显示章节标题
ui_section_title() {
    local title=$1
    local icon=${2:-""}
    
    echo ""
    echo -e "  ${C_CYAN}╔═══════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "  ${C_CYAN}║${C_RESET}  ${icon} ${S_BOLD}${title}${C_RESET}"
    echo -e "  ${C_CYAN}╚═══════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""
}

# ============================================================================
# 提示框
# ============================================================================

# 显示提示
ui_tip() {
    local message="$1"
    echo -e "  ${EMOJI_LIGHT} ${S_DIM}提示：${message}${C_RESET}"
}

# 显示注意
ui_notice() {
    local message="$1"
    echo -e "  ${C_WARNING}${EMOJI_WARNING} 注意：${message}${C_RESET}"
}

# 显示新手提示（仅在新手模式下显示）
ui_beginner_tip() {
    local message="$1"
    if [[ "${BEGINNER_MODE:-true}" == "true" ]]; then
        echo ""
        echo -e "  ${C_INFO}┌─────────────────────────────────────────────────────────┐${C_RESET}"
        echo -e "  ${C_INFO}│${C_RESET} ${EMOJI_LIGHT} ${S_BOLD}新手提示${C_RESET}"
        echo -e "  ${C_INFO}├─────────────────────────────────────────────────────────┤${C_RESET}"
        echo "$message" | while IFS= read -r line; do
            echo -e "  ${C_INFO}│${C_RESET}   $line"
        done
        echo -e "  ${C_INFO}└─────────────────────────────────────────────────────────┘${C_RESET}"
        echo ""
    fi
}

# ============================================================================
# 清屏和等待
# ============================================================================

# 清屏
ui_clear() {
    clear
}

# 等待按键继续
ui_wait_key() {
    local message="${1:-按任意键继续...}"
    echo ""
    echo -ne "  ${S_DIM}${message}${C_RESET}"
    read -rsn1 </dev/tty
    echo ""
}

# 倒计时
# 用法: ui_countdown 5 "操作将在 %d 秒后执行..."
ui_countdown() {
    local seconds=$1
    local message="${2:-等待 %d 秒...}"
    
    for ((i=seconds; i>0; i--)); do
        printf "\r  ${S_DIM}$(printf "$message" $i)${C_RESET}"
        sleep 1
    done
    printf "\r${CLEAR_LINE}"
}

# ============================================================================
# 表格显示
# ============================================================================

# 简单表格
# 用法: ui_table "列1,列2,列3" "值1,值2,值3" "值4,值5,值6"
ui_table() {
    local header="$1"
    shift
    local rows=("$@")
    
    # 解析表头
    IFS=',' read -ra headers <<< "$header"
    local col_count=${#headers[@]}
    
    # 计算列宽
    local col_widths=()
    for i in "${!headers[@]}"; do
        col_widths[$i]=${#headers[$i]}
    done
    
    for row in "${rows[@]}"; do
        IFS=',' read -ra cols <<< "$row"
        for i in "${!cols[@]}"; do
            local len=${#cols[$i]}
            ((len > col_widths[$i])) && col_widths[$i]=$len
        done
    done
    
    # 打印表头
    echo -ne "  "
    for i in "${!headers[@]}"; do
        printf "${S_BOLD}%-$((col_widths[$i] + 2))s${C_RESET}" "${headers[$i]}"
    done
    echo ""
    
    # 打印分隔线
    echo -ne "  "
    for i in "${!headers[@]}"; do
        printf "%$((col_widths[$i] + 2))s" | tr ' ' '-'
    done
    echo ""
    
    # 打印数据行
    for row in "${rows[@]}"; do
        IFS=',' read -ra cols <<< "$row"
        echo -ne "  "
        for i in "${!cols[@]}"; do
            printf "%-$((col_widths[$i] + 2))s" "${cols[$i]}"
        done
        echo ""
    done
}

# ============================================================================
# 导出
# ============================================================================

# 导出所有函数供其他脚本使用
export -f ui_show_banner ui_show_mini_banner
export -f ui_log_success ui_log_error ui_log_warning ui_log_info ui_log_step ui_log_debug
export -f ui_progress_bar ui_progress_done
export -f ui_spinner_start ui_spinner_success ui_spinner_error ui_spinner_stop
export -f ui_input ui_input_secret ui_input_with_help
export -f ui_confirm ui_confirm_dangerous
export -f ui_select ui_multi_select
export -f ui_panel ui_kv_panel
export -f ui_divider ui_step_title ui_section_title
export -f ui_tip ui_notice ui_beginner_tip
export -f ui_clear ui_wait_key ui_countdown
export -f ui_table
