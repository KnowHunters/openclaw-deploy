#!/bin/bash
# ============================================================================
# OpenClaw Deploy 2.0 - Environment Detector
# ============================================================================
# 环境检测模块，检测系统环境、依赖、OpenClaw 状态
# ============================================================================

# 防止重复加载
[[ -n "$_DETECTOR_LOADED" ]] && return 0
_DETECTOR_LOADED=1

# ============================================================================
# 检测结果变量
# ============================================================================

# 系统信息
DETECTED_OS=""
DETECTED_DISTRO=""
DETECTED_VERSION=""
DETECTED_ARCH=""
DETECTED_MEMORY_MB=0
DETECTED_DISK_MB=0
DETECTED_CPU_CORES=0

# 依赖状态
HAS_NODE=false
HAS_NPM=false
HAS_GIT=false
HAS_CURL=false
HAS_JQ=false

NODE_VERSION=""
NPM_VERSION=""
GIT_VERSION=""

# OpenClaw 状态
HAS_OPENCLAW=false
HAS_OPENCLAW_CN=false
OPENCLAW_VERSION=""
OPENCLAW_CLI_PATH=""
OPENCLAW_CONFIG_EXISTS=false
OPENCLAW_SERVICE_RUNNING=false
OPENCLAW_WORKSPACE_EXISTS=false

# 网络状态
NETWORK_OK=false

# 安装模式建议
SUGGESTED_MODE=""  # fresh / upgrade / reinstall

# ============================================================================
# 系统检测
# ============================================================================

# 检测所有系统信息
detect_system() {
    log_step "检测系统环境..."
    
    # 操作系统
    DETECTED_OS=$(detect_os)
    DETECTED_DISTRO="$OS_DISTRO"
    DETECTED_VERSION="$OS_VERSION"
    
    # 架构
    DETECTED_ARCH=$(detect_arch)
    
    # 资源
    DETECTED_MEMORY_MB=$(detect_memory)
    DETECTED_DISK_MB=$(detect_disk "$HOME")
    DETECTED_CPU_CORES=$(detect_cpu_cores)
    
    log_debug "OS: $DETECTED_OS, Distro: $DETECTED_DISTRO, Version: $DETECTED_VERSION"
    log_debug "Arch: $DETECTED_ARCH, Memory: ${DETECTED_MEMORY_MB}MB, Disk: ${DETECTED_DISK_MB}MB"
}

# 检测系统是否支持
check_system_support() {
    local supported=true
    local issues=()
    
    # 检查操作系统
    case "$DETECTED_OS" in
        linux|wsl|macos)
            ;;
        *)
            supported=false
            issues+=("不支持的操作系统: $DETECTED_OS")
            ;;
    esac
    
    # 检查内存（最低 1GB）
    if [[ $DETECTED_MEMORY_MB -lt 1024 ]]; then
        issues+=("内存不足: ${DETECTED_MEMORY_MB}MB (建议至少 2GB)")
    fi
    
    # 检查磁盘空间（最低 2GB）
    if [[ $DETECTED_DISK_MB -lt 2048 ]]; then
        supported=false
        issues+=("磁盘空间不足: ${DETECTED_DISK_MB}MB (需要至少 2GB)")
    fi
    
    # 返回结果
    if [[ "$supported" == false ]]; then
        for issue in "${issues[@]}"; do
            log_error "$issue"
        done
        return 1
    fi
    
    # 显示警告
    for issue in "${issues[@]}"; do
        log_warning "$issue"
    done
    
    return 0
}

# ============================================================================
# 依赖检测
# ============================================================================

# 检测所有依赖
detect_dependencies() {
    log_step "检测依赖环境..."
    
    # Node.js
    if command_exists node; then
        HAS_NODE=true
        NODE_VERSION=$(node --version 2>/dev/null | sed 's/^v//')
        log_debug "Node.js: $NODE_VERSION"
    fi
    
    # npm
    if command_exists npm; then
        HAS_NPM=true
        NPM_VERSION=$(npm --version 2>/dev/null)
        log_debug "npm: $NPM_VERSION"
    fi
    
    # Git
    if command_exists git; then
        HAS_GIT=true
        GIT_VERSION=$(git --version 2>/dev/null | awk '{print $3}')
        log_debug "Git: $GIT_VERSION"
    fi
    
    # curl
    if command_exists curl; then
        HAS_CURL=true
    fi
    
    # jq
    if command_exists jq; then
        HAS_JQ=true
    fi
}

# 检查 Node.js 版本是否满足要求
check_node_version() {
    local required_version="${1:-22}"
    
    if [[ "$HAS_NODE" != true ]]; then
        return 1
    fi
    
    local major_version="${NODE_VERSION%%.*}"
    
    if [[ $major_version -ge $required_version ]]; then
        return 0
    fi
    
    return 1
}

# 获取缺失的必需依赖
get_missing_dependencies() {
    local missing=()
    
    if [[ "$HAS_CURL" != true ]] && ! command_exists wget; then
        missing+=("curl 或 wget")
    fi
    
    if [[ "$HAS_GIT" != true ]]; then
        missing+=("git")
    fi
    
    echo "${missing[@]}"
}

# ============================================================================
# OpenClaw 检测
# ============================================================================

# 检测 OpenClaw 安装状态
detect_openclaw() {
    log_step "检测 OpenClaw 状态..."
    
    # 检测国际版
    if command_exists openclaw; then
        HAS_OPENCLAW=true
        OPENCLAW_CLI_PATH=$(get_command_path openclaw)
        OPENCLAW_VERSION=$(openclaw --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_debug "OpenClaw (国际版): $OPENCLAW_VERSION at $OPENCLAW_CLI_PATH"
    fi
    
    # 检测中文版
    if command_exists openclaw-cn; then
        HAS_OPENCLAW_CN=true
        if [[ "$HAS_OPENCLAW" != true ]]; then
            OPENCLAW_CLI_PATH=$(get_command_path openclaw-cn)
            OPENCLAW_VERSION=$(openclaw-cn --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
            log_debug "OpenClaw (中文版): $OPENCLAW_VERSION at $OPENCLAW_CLI_PATH"
        fi
    fi
    
    # 检测配置文件
    if [[ -f "$OPENCLAW_CONFIG" ]]; then
        OPENCLAW_CONFIG_EXISTS=true
        log_debug "配置文件存在: $OPENCLAW_CONFIG"
    fi
    
    # 检测工作区
    if [[ -d "$OPENCLAW_WORKSPACE" ]]; then
        OPENCLAW_WORKSPACE_EXISTS=true
        log_debug "工作区存在: $OPENCLAW_WORKSPACE"
    fi
    
    # 检测服务状态
    if has_systemd; then
        if service_is_running "openclaw"; then
            OPENCLAW_SERVICE_RUNNING=true
            log_debug "OpenClaw 服务运行中"
        fi
    fi
}

# 获取 OpenClaw 最新版本
get_openclaw_latest_version() {
    local version_type="${1:-international}"  # international / chinese
    local latest=""
    
    # 尝试从 npm 获取
    if command_exists npm; then
        if [[ "$version_type" == "chinese" ]]; then
            latest=$(npm view openclaw-cn version 2>/dev/null)
        else
            latest=$(npm view openclaw version 2>/dev/null)
        fi
    fi
    
    echo "${latest:-unknown}"
}

# ============================================================================
# 网络检测
# ============================================================================

# 检测网络连接
detect_network() {
    log_step "检测网络连接..."
    
    if check_network; then
        NETWORK_OK=true
        log_debug "网络连接正常"
    else
        NETWORK_OK=false
        log_warning "网络连接异常"
    fi
}

# ============================================================================
# 用户检测
# ============================================================================

# 检测当前用户状态
detect_user() {
    log_step "检测用户环境..."
    
    # 检查是否为 root
    if is_root; then
        log_warning "当前以 root 用户运行"
        return 1
    fi
    
    # 检查 sudo 权限
    if ! has_sudo; then
        log_warning "当前用户没有 sudo 权限"
    fi
    
    # 检查 home 目录
    if [[ ! -d "$HOME_DIR" ]]; then
        log_error "Home 目录不存在: $HOME_DIR"
        return 1
    fi
    
    if [[ ! -w "$HOME_DIR" ]]; then
        log_error "Home 目录不可写: $HOME_DIR"
        return 1
    fi
    
    log_debug "用户: $CURRENT_USER, Home: $HOME_DIR"
    return 0
}

# ============================================================================
# 安装模式判断
# ============================================================================

# 判断建议的安装模式
determine_install_mode() {
    log_step "分析安装模式..."
    
    # 如果没有安装 OpenClaw
    if [[ "$HAS_OPENCLAW" != true ]] && [[ "$HAS_OPENCLAW_CN" != true ]]; then
        SUGGESTED_MODE="fresh"
        log_debug "建议模式: 全新安装"
        return
    fi
    
    # 如果已安装，检查是否需要升级
    local latest_version
    if [[ "$HAS_OPENCLAW_CN" == true ]]; then
        latest_version=$(get_openclaw_latest_version "chinese")
    else
        latest_version=$(get_openclaw_latest_version "international")
    fi
    
    if [[ "$latest_version" != "unknown" ]] && [[ "$OPENCLAW_VERSION" != "unknown" ]]; then
        if version_lt "$OPENCLAW_VERSION" "$latest_version"; then
            SUGGESTED_MODE="upgrade"
            log_debug "建议模式: 升级安装 ($OPENCLAW_VERSION -> $latest_version)"
            return
        fi
    fi
    
    # 已是最新版本
    SUGGESTED_MODE="reinstall"
    log_debug "建议模式: 重新安装/修复"
}

# ============================================================================
# 完整检测流程
# ============================================================================

# 运行完整检测
run_full_detection() {
    echo ""
    ui_section_title "系统环境检测" "$EMOJI_SEARCH"
    
    detect_system
    detect_dependencies
    detect_openclaw
    detect_network
    
    # 判断安装模式
    determine_install_mode
    
    return 0
}

# ============================================================================
# 检测结果显示
# ============================================================================

# 显示检测结果
show_detection_result() {
    local items=()
    
    # 操作系统
    local os_display="$DETECTED_DISTRO"
    [[ -n "$DETECTED_VERSION" ]] && os_display="$os_display $DETECTED_VERSION"
    [[ "$DETECTED_OS" == "wsl" ]] && os_display="$os_display (WSL)"
    items+=("操作系统:$os_display ($DETECTED_ARCH)")
    
    # 内存
    local mem_status="${C_SUCCESS}✓${C_RESET}"
    [[ $DETECTED_MEMORY_MB -lt 2048 ]] && mem_status="${C_WARNING}!${C_RESET}"
    [[ $DETECTED_MEMORY_MB -lt 1024 ]] && mem_status="${C_ERROR}✗${C_RESET}"
    items+=("内存:${DETECTED_MEMORY_MB} MB $mem_status")
    
    # 磁盘
    local disk_status="${C_SUCCESS}✓${C_RESET}"
    [[ $DETECTED_DISK_MB -lt 5120 ]] && disk_status="${C_WARNING}!${C_RESET}"
    [[ $DETECTED_DISK_MB -lt 2048 ]] && disk_status="${C_ERROR}✗${C_RESET}"
    items+=("磁盘可用:${DETECTED_DISK_MB} MB $disk_status")
    
    # Node.js
    if [[ "$HAS_NODE" == true ]]; then
        local node_status="${C_SUCCESS}✓${C_RESET}"
        check_node_version 22 || node_status="${C_WARNING}需升级${C_RESET}"
        items+=("Node.js:v${NODE_VERSION} $node_status")
    else
        items+=("Node.js:${C_ERROR}未安装${C_RESET}")
    fi
    
    # Git
    if [[ "$HAS_GIT" == true ]]; then
        items+=("Git:${GIT_VERSION} ${C_SUCCESS}✓${C_RESET}")
    else
        items+=("Git:${C_ERROR}未安装${C_RESET}")
    fi
    
    # 网络
    if [[ "$NETWORK_OK" == true ]]; then
        items+=("网络:${C_SUCCESS}正常${C_RESET}")
    else
        items+=("网络:${C_ERROR}异常${C_RESET}")
    fi
    
    ui_kv_panel "${EMOJI_SEARCH} 系统环境检测结果" "${items[@]}"
    
    # OpenClaw 状态
    local oc_items=()
    
    if [[ "$HAS_OPENCLAW" == true ]] || [[ "$HAS_OPENCLAW_CN" == true ]]; then
        local version_type="国际版"
        [[ "$HAS_OPENCLAW_CN" == true ]] && [[ "$HAS_OPENCLAW" != true ]] && version_type="中文版"
        
        local latest=$(get_openclaw_latest_version)
        local version_display="$OPENCLAW_VERSION"
        
        if [[ "$latest" != "unknown" ]] && version_lt "$OPENCLAW_VERSION" "$latest"; then
            version_display="$OPENCLAW_VERSION → $latest ${C_WARNING}(可升级)${C_RESET}"
        fi
        
        oc_items+=("CLI 版本:$version_display ($version_type)")
        
        if [[ "$OPENCLAW_CONFIG_EXISTS" == true ]]; then
            oc_items+=("配置文件:${C_SUCCESS}已存在${C_RESET}")
        else
            oc_items+=("配置文件:${S_DIM}未配置${C_RESET}")
        fi
        
        if [[ "$OPENCLAW_SERVICE_RUNNING" == true ]]; then
            oc_items+=("服务状态:${C_SUCCESS}运行中${C_RESET}")
        else
            oc_items+=("服务状态:${S_DIM}未运行${C_RESET}")
        fi
        
        if [[ "$OPENCLAW_WORKSPACE_EXISTS" == true ]]; then
            oc_items+=("工作区:${C_SUCCESS}已创建${C_RESET}")
        else
            oc_items+=("工作区:${S_DIM}未创建${C_RESET}")
        fi
    else
        oc_items+=("状态:${S_DIM}未安装${C_RESET}")
    fi
    
    ui_kv_panel "${EMOJI_CLAW} OpenClaw 状态" "${oc_items[@]}"
    
    # 建议操作
    local suggestion=""
    case "$SUGGESTED_MODE" in
        fresh)
            suggestion="${C_PRIMARY}全新安装${C_RESET} - OpenClaw 尚未安装"
            ;;
        upgrade)
            suggestion="${C_WARNING}升级安装${C_RESET} - 有新版本可用"
            ;;
        reinstall)
            suggestion="${C_INFO}重新安装/修复${C_RESET} - 已是最新版本"
            ;;
    esac
    
    echo -e "  ${S_BOLD}建议操作:${C_RESET} $suggestion"
    echo ""
}

# ============================================================================
# 导出
# ============================================================================

export DETECTED_OS DETECTED_DISTRO DETECTED_VERSION DETECTED_ARCH
export DETECTED_MEMORY_MB DETECTED_DISK_MB DETECTED_CPU_CORES
export HAS_NODE HAS_NPM HAS_GIT HAS_CURL HAS_JQ
export NODE_VERSION NPM_VERSION GIT_VERSION
export HAS_OPENCLAW HAS_OPENCLAW_CN OPENCLAW_VERSION OPENCLAW_CLI_PATH
export OPENCLAW_CONFIG_EXISTS OPENCLAW_SERVICE_RUNNING OPENCLAW_WORKSPACE_EXISTS
export NETWORK_OK SUGGESTED_MODE

export -f detect_system check_system_support
export -f detect_dependencies check_node_version get_missing_dependencies
export -f detect_openclaw get_openclaw_latest_version
export -f detect_network
export -f detect_user
export -f determine_install_mode
export -f run_full_detection show_detection_result
