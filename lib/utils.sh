#!/bin/bash
# ============================================================================
# OpenClaw Deploy 2.0 - Utility Functions
# ============================================================================
# 工具函数库，提供日志、配置、网络、备份等通用功能
# ============================================================================

# 防止重复加载
[[ -n "$_UTILS_LOADED" ]] && return 0
_UTILS_LOADED=1

# ============================================================================
# 全局变量
# ============================================================================

# 版本信息
DEPLOY_VERSION="2.1.4"
DEPLOY_NAME="OpenClaw Deploy"

# 目录路径 (只在未设置时才设置，避免覆盖 deploy.sh 中的值)
if [[ -z "$SCRIPT_DIR" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [[ -z "$PROJECT_ROOT" ]]; then
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
fi

# 用户相关
CURRENT_USER="$(whoami)"
CURRENT_UID="$(id -u)"
HOME_DIR="${HOME:-/home/$CURRENT_USER}"

# OpenClaw 相关目录
OPENCLAW_DIR="${HOME_DIR}/.openclaw"
OPENCLAW_CONFIG="${OPENCLAW_DIR}/openclaw.json"
OPENCLAW_ENV="${OPENCLAW_DIR}/.env"
OPENCLAW_WORKSPACE="${OPENCLAW_DIR}/workspace"
OPENCLAW_SKILLS="${OPENCLAW_DIR}/skills"
OPENCLAW_LOGS="${OPENCLAW_DIR}/logs"
OPENCLAW_BACKUPS="${OPENCLAW_DIR}/backups"
OPENCLAW_CREDENTIALS="${OPENCLAW_DIR}/credentials"

# npm 全局目录
NPM_GLOBAL="${HOME_DIR}/.npm-global"
NPM_BIN="${NPM_GLOBAL}/bin"

# 日志文件
LOG_FILE="/tmp/openclaw_deploy_$(date +%Y%m%d_%H%M%S).log"
PROGRESS_FILE="/tmp/openclaw_install_progress"

# 默认配置
DEFAULT_GATEWAY_PORT=18789
DEFAULT_GATEWAY_BIND="127.0.0.1"

# 安装模式
INSTALL_MODE=""  # fresh / upgrade / reinstall
INSTALL_VERSION=""  # international / chinese
OPENCLAW_USER=""
BEGINNER_MODE=true

# ============================================================================
# 日志系统
# ============================================================================

# 初始化日志
log_init() {
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "========================================" >> "$LOG_FILE"
    echo "OpenClaw Deploy Log - $(date)" >> "$LOG_FILE"
    echo "========================================" >> "$LOG_FILE"
}

# 写入日志文件
log_write() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

# 日志函数（同时输出到屏幕和文件）
log_info() {
    log_write "INFO" "$1"
    ui_log_info "$1"
}

log_success() {
    log_write "SUCCESS" "$1"
    ui_log_success "$1"
}

log_warning() {
    log_write "WARNING" "$1"
    ui_log_warning "$1"
}

log_error() {
    log_write "ERROR" "$1"
    ui_log_error "$1"
}

log_step() {
    log_write "STEP" "$1"
    ui_log_step "$1"
}

log_debug() {
    log_write "DEBUG" "$1"
    ui_log_debug "$1"
}

# ============================================================================
# 错误处理
# ============================================================================

# 错误代码定义
declare -A ERROR_CODES=(
    [0]="SUCCESS"
    [1]="GENERAL_ERROR"
    [2]="NETWORK_ERROR"
    [3]="PERMISSION_DENIED"
    [4]="NODE_NOT_FOUND"
    [5]="CONFIG_INVALID"
    [6]="SERVICE_FAILED"
    [7]="USER_CANCELLED"
    [8]="DEPENDENCY_MISSING"
    [9]="DISK_FULL"
    [10]="TIMEOUT"
)

# 设置错误处理
setup_error_handling() {
    set -o pipefail
    trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR
    trap 'handle_exit' EXIT
    trap 'handle_interrupt' INT TERM
}

# 错误处理函数
handle_error() {
    local exit_code=$1
    local line_no=$2
    local command="$3"
    
    log_write "ERROR" "Error at line $line_no: $command (exit code: $exit_code)"
    
    # 停止可能运行的 spinner
    ui_spinner_stop 2>/dev/null
    
    # 显示光标
    echo -ne "\033[?25h"
}

# 退出处理
handle_exit() {
    # 清理临时文件
    # rm -f /tmp/openclaw_*.tmp 2>/dev/null
    
    # 显示光标
    echo -ne "\033[?25h"
}

# 中断处理
handle_interrupt() {
    echo ""
    log_warning "操作被用户中断"
    
    # 保存进度
    save_progress "interrupted"
    
    # 停止 spinner
    ui_spinner_stop 2>/dev/null
    
    # 显示光标
    echo -ne "\033[?25h"
    
    exit 130
}

# ============================================================================
# 进度保存和恢复
# ============================================================================

# 保存安装进度
save_progress() {
    local step="$1"
    
    cat > "$PROGRESS_FILE" <<EOF
INSTALL_STEP="$step"
INSTALL_USER="$OPENCLAW_USER"
INSTALL_VERSION="$INSTALL_VERSION"
INSTALL_MODE="$INSTALL_MODE"
INSTALL_TIME=$(date +%s)
EOF
    
    log_debug "进度已保存: $step"
}

# 加载安装进度
load_progress() {
    if [[ -f "$PROGRESS_FILE" ]]; then
        source "$PROGRESS_FILE"
        return 0
    fi
    return 1
}

# 检查是否有未完成的安装
check_incomplete_install() {
    if [[ -f "$PROGRESS_FILE" ]]; then
        source "$PROGRESS_FILE"
        
        local elapsed=$(($(date +%s) - ${INSTALL_TIME:-0}))
        
        # 如果进度文件不超过 1 小时
        if [[ $elapsed -lt 3600 ]]; then
            return 0  # 有未完成的安装
        fi
        
        # 过期的进度文件，删除
        rm -f "$PROGRESS_FILE"
    fi
    return 1  # 没有未完成的安装
}

# 清除进度
clear_progress() {
    rm -f "$PROGRESS_FILE"
}

# ============================================================================
# 系统检测
# ============================================================================

# 检测操作系统
detect_os() {
    local os=""
    local distro=""
    local version=""
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        os="linux"
        
        # 检测发行版
        if [[ -f /etc/os-release ]]; then
            source /etc/os-release
            distro="$ID"
            version="$VERSION_ID"
        elif [[ -f /etc/lsb-release ]]; then
            source /etc/lsb-release
            distro="$DISTRIB_ID"
            version="$DISTRIB_RELEASE"
        fi
        
        # 检测 WSL
        if grep -qi microsoft /proc/version 2>/dev/null; then
            os="wsl"
        fi
        
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        os="macos"
        distro="macos"
        version=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
    else
        os="unknown"
    fi
    
    # 设置全局变量
    OS_TYPE="$os"
    OS_DISTRO="$distro"
    OS_VERSION="$version"
    
    echo "$os"
}

# 检测系统架构
detect_arch() {
    local arch=$(uname -m)
    
    case "$arch" in
        x86_64|amd64)
            ARCH="x86_64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        *)
            ARCH="$arch"
            ;;
    esac
    
    echo "$ARCH"
}

# 检测内存
detect_memory() {
    local mem_kb=0
    
    if [[ -f /proc/meminfo ]]; then
        # 使用 || true 防止 grep 失败导致脚本退出
        mem_kb=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 0)
    elif command -v sysctl &>/dev/null; then
        mem_kb=$(($(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1024))
    fi
    
    MEMORY_MB=$((mem_kb / 1024))
    # 确保是有效的数字
    if [[ ! "$MEMORY_MB" =~ ^[0-9]+$ ]]; then
        MEMORY_MB=0
    fi
    echo "$MEMORY_MB"
}

# 检测磁盘空间
detect_disk() {
    local path="${1:-$HOME}"
    local available_kb=0
    
    if command -v df &>/dev/null; then
        # 使用 || true 防止命令链失败
        available_kb=$(df -k "$path" 2>/dev/null | tail -1 | awk '{print $4}' || echo 0)
    fi
    
    DISK_AVAILABLE_MB=$((available_kb / 1024))
    # 确保是有效的数字
    if [[ ! "$DISK_AVAILABLE_MB" =~ ^[0-9]+$ ]]; then
        DISK_AVAILABLE_MB=0
    fi
    echo "$DISK_AVAILABLE_MB"
}

# 检测 CPU 核心数
detect_cpu_cores() {
    local cores=1
    
    if [[ -f /proc/cpuinfo ]]; then
        # grep -c 如果没有匹配到会返回 exit code 1，这将导致脚本在 set -e 模式下退出
        # 所以必须加上 || echo 0 或 || true
        cores=$(grep -c ^processor /proc/cpuinfo || echo 1)
        # 如果 grep 返回 0 (没有找到 processor)，我们默认至少有 1 个核心
        [[ "$cores" == "0" ]] && cores=1
    elif command -v sysctl &>/dev/null; then
        cores=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
    elif command -v nproc &>/dev/null; then
        cores=$(nproc || echo 1)
    fi
    
    CPU_CORES=$cores
    # 确保是有效的数字
    if [[ ! "$CPU_CORES" =~ ^[0-9]+$ ]]; then
        CPU_CORES=1
    fi
    echo "$cores"
}

# ============================================================================
# 命令检测
# ============================================================================

# 检查命令是否存在
command_exists() {
    command -v "$1" &>/dev/null
}

# 检查多个命令
commands_exist() {
    for cmd in "$@"; do
        if ! command_exists "$cmd"; then
            return 1
        fi
    done
    return 0
}

# 获取命令路径
get_command_path() {
    command -v "$1" 2>/dev/null
}

# ============================================================================
# 版本比较
# ============================================================================

# 比较版本号
# 返回: 0 = 相等, 1 = v1 > v2, 2 = v1 < v2
version_compare() {
    local v1="$1"
    local v2="$2"
    
    if [[ "$v1" == "$v2" ]]; then
        return 0
    fi
    
    local IFS=.
    local i v1_arr=($v1) v2_arr=($v2)
    
    # 填充短的版本号
    for ((i=${#v1_arr[@]}; i<${#v2_arr[@]}; i++)); do
        v1_arr[i]=0
    done
    for ((i=${#v2_arr[@]}; i<${#v1_arr[@]}; i++)); do
        v2_arr[i]=0
    done
    
    for ((i=0; i<${#v1_arr[@]}; i++)); do
        # 移除非数字字符
        local n1="${v1_arr[i]//[^0-9]/}"
        local n2="${v2_arr[i]//[^0-9]/}"
        
        n1=${n1:-0}
        n2=${n2:-0}
        
        if ((n1 > n2)); then
            return 1
        fi
        if ((n1 < n2)); then
            return 2
        fi
    done
    
    return 0
}

# v1 < v2
version_lt() {
    version_compare "$1" "$2"
    [[ $? -eq 2 ]]
}

# v1 <= v2
version_le() {
    version_compare "$1" "$2"
    [[ $? -ne 1 ]]
}

# v1 > v2
version_gt() {
    version_compare "$1" "$2"
    [[ $? -eq 1 ]]
}

# v1 >= v2
version_ge() {
    version_compare "$1" "$2"
    [[ $? -ne 2 ]]
}

# ============================================================================
# 网络功能
# ============================================================================

# 检查网络连接
check_network() {
    local test_hosts=("google.com" "github.com" "baidu.com")
    
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 3 "$host" &>/dev/null; then
            return 0
        fi
    done
    
    # 尝试 curl
    if curl -s --connect-timeout 5 "https://www.baidu.com" &>/dev/null; then
        return 0
    fi
    
    return 1
}

# 下载文件
# 用法: download_file "url" "output_path"
download_file() {
    local url="$1"
    local output="$2"
    
    if command_exists curl; then
        curl -fsSL -o "$output" "$url"
    elif command_exists wget; then
        wget -q -O "$output" "$url"
    else
        return 1
    fi
}

# 获取 URL 内容
# 用法: content=$(fetch_url "url")
fetch_url() {
    local url="$1"
    
    if command_exists curl; then
        curl -fsSL "$url"
    elif command_exists wget; then
        wget -q -O - "$url"
    else
        return 1
    fi
}

# ============================================================================
# 文件和目录操作
# ============================================================================

# 确保目录存在
ensure_dir() {
    local dir="$1"
    local owner="${2:-}"
    local mode="${3:-755}"
    
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
    fi
    
    chmod "$mode" "$dir"
    
    if [[ -n "$owner" ]]; then
        chown "$owner:$owner" "$dir" 2>/dev/null || true
    fi
}

# 安全写入文件
safe_write_file() {
    local file="$1"
    local content="$2"
    local mode="${3:-644}"
    local owner="${4:-}"
    
    # 确保目录存在
    ensure_dir "$(dirname "$file")"
    
    # 写入临时文件
    local tmp_file="${file}.tmp.$$"
    echo "$content" > "$tmp_file"
    
    # 移动到目标位置
    mv "$tmp_file" "$file"
    
    # 设置权限
    chmod "$mode" "$file"
    
    if [[ -n "$owner" ]]; then
        chown "$owner:$owner" "$file" 2>/dev/null || true
    fi
}

# 备份文件
backup_file() {
    local file="$1"
    local backup_dir="${2:-$OPENCLAW_BACKUPS}"
    
    if [[ -f "$file" ]]; then
        ensure_dir "$backup_dir"
        local filename=$(basename "$file")
        local timestamp=$(date +%Y%m%d_%H%M%S)
        cp "$file" "${backup_dir}/${filename}.${timestamp}.bak"
        return 0
    fi
    return 1
}

# ============================================================================
# JSON 处理
# ============================================================================

# 检查 jq 是否可用
jq_available() {
    command_exists jq
}

# 读取 JSON 值
# 用法: value=$(json_get "file.json" ".key.subkey")
json_get() {
    local file="$1"
    local path="$2"
    
    if jq_available; then
        jq -r "$path // empty" "$file" 2>/dev/null
    else
        # 简单的 grep 方式（仅支持简单键）
        local key="${path#.}"
        grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$file" 2>/dev/null | \
            sed 's/.*:[[:space:]]*"\([^"]*\)"/\1/'
    fi
}

# 设置 JSON 值
# 用法: json_set "file.json" ".key" "value"
json_set() {
    local file="$1"
    local path="$2"
    local value="$3"
    
    if jq_available && [[ -f "$file" ]]; then
        local tmp_file="${file}.tmp.$$"
        jq "$path = \"$value\"" "$file" > "$tmp_file" && mv "$tmp_file" "$file"
    fi
}

# ============================================================================
# 用户管理
# ============================================================================

# 检查是否为 root 用户
is_root() {
    [[ "$CURRENT_UID" -eq 0 ]]
}

# 检查是否有 sudo 权限
has_sudo() {
    sudo -n true 2>/dev/null
}

# 检查当前用户是否在 sudo 组
user_in_sudo_group() {
    local groups=$(groups "$CURRENT_USER" 2>/dev/null)
    if [[ "$groups" == *"sudo"* ]] || [[ "$groups" == *"wheel"* ]] || [[ "$groups" == *"root"* ]]; then
        return 0
    fi
    return 1
}

# 获取普通用户列表
get_normal_users() {
    local min_uid=1000
    local max_uid=60000
    
    if [[ -f /etc/login.defs ]]; then
        min_uid=$(grep "^UID_MIN" /etc/login.defs 2>/dev/null | awk '{print $2}')
        max_uid=$(grep "^UID_MAX" /etc/login.defs 2>/dev/null | awk '{print $2}')
    fi
    
    min_uid=${min_uid:-1000}
    max_uid=${max_uid:-60000}
    
    awk -F: -v min="$min_uid" -v max="$max_uid" \
        '$3 >= min && $3 <= max && $7 !~ /nologin|false/ {print $1}' /etc/passwd
}

# 检查用户是否存在
user_exists() {
    local username="$1"
    id "$username" &>/dev/null
}

# 获取用户 home 目录
get_user_home() {
    local username="$1"
    eval echo "~$username"
}

# ============================================================================
# 服务管理
# ============================================================================

# 检查 systemd 是否可用
has_systemd() {
    command_exists systemctl && [[ -d /run/systemd/system ]]
}

# 检查服务状态
service_status() {
    local service="$1"
    
    if has_systemd; then
        systemctl is-active "$service" 2>/dev/null
    else
        echo "unknown"
    fi
}

# 检查服务是否运行
service_is_running() {
    local service="$1"
    [[ "$(service_status "$service")" == "active" ]]
}

# ============================================================================
# 字符串处理
# ============================================================================

# 去除首尾空白
trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}

# 字符串转小写
to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# 字符串转大写
to_upper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

# 生成随机字符串
random_string() {
    local length="${1:-32}"
    
    if [[ -f /dev/urandom ]]; then
        head -c "$length" /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c "$length"
    elif command_exists openssl; then
        openssl rand -hex "$((length / 2))"
    else
        date +%s%N | sha256sum | head -c "$length"
    fi
}

# 生成安全 Token
generate_token() {
    local length="${1:-48}"
    
    if command_exists openssl; then
        openssl rand -hex "$((length / 2))"
    else
        random_string "$length"
    fi
}

# ============================================================================
# 术语解释系统
# ============================================================================

# 术语解释字典
declare -A TERM_EXPLANATIONS=(
    ["API Key"]="API Key 是访问 AI 服务的密钥，类似于密码。
你需要在 AI 服务商的网站上注册并获取。"
    
    ["Gateway"]="Gateway 是 OpenClaw 的核心服务，负责接收和处理消息。
它就像一个翻译官，把你的消息翻译给 AI。"
    
    ["Token"]="Token 是一种安全凭证，用于验证身份。
类似于门禁卡，只有持有正确 Token 才能访问服务。"
    
    ["端口"]="端口是网络通信的入口，就像房间的门牌号。
不同的服务使用不同的端口，避免冲突。
常见端口：80(HTTP), 443(HTTPS), 18789(OpenClaw)"
    
    ["sudo"]="sudo 是一个命令，让普通用户临时获得管理员权限。
使用时需要输入你的密码。
例如：sudo apt install nodejs"
    
    ["systemd"]="systemd 是 Linux 的服务管理器。
它负责启动、停止和监控各种服务。
常用命令：systemctl start/stop/status 服务名"
    
    ["SSH"]="SSH 是一种安全的远程登录方式。
你可以通过 SSH 从自己的电脑连接到服务器。
例如：ssh username@server_ip"
    
    ["环境变量"]="环境变量是系统中的全局设置。
程序可以读取这些设置来获取配置信息。
例如：PATH, HOME, OPENAI_API_KEY"
    
    ["Node.js"]="Node.js 是一个 JavaScript 运行环境。
OpenClaw 需要 Node.js 22 或更高版本才能运行。"
    
    ["npm"]="npm 是 Node.js 的包管理器。
用于安装和管理 JavaScript 软件包。
例如：npm install -g openclaw"
    
    ["Workspace"]="Workspace（工作区）是 OpenClaw 存储配置和数据的目录。
默认位置：~/.openclaw/workspace"
    
    ["Skills"]="Skills（技能）是 OpenClaw 的扩展功能。
你可以安装各种技能来增强 AI 助手的能力。"
)

# 获取术语解释
get_term_explanation() {
    local term="$1"
    echo "${TERM_EXPLANATIONS[$term]:-}"
}

# 显示术语解释
show_term_explanation() {
    local term="$1"
    local explanation="${TERM_EXPLANATIONS[$term]:-}"
    
    if [[ -n "$explanation" ]]; then
        ui_panel "💡 什么是 $term？" "$explanation"
    fi
}

# ============================================================================
# 导出
# ============================================================================

export DEPLOY_VERSION DEPLOY_NAME
export SCRIPT_DIR PROJECT_ROOT
export CURRENT_USER CURRENT_UID HOME_DIR
export OPENCLAW_DIR OPENCLAW_CONFIG OPENCLAW_ENV OPENCLAW_WORKSPACE
export OPENCLAW_SKILLS OPENCLAW_LOGS OPENCLAW_BACKUPS OPENCLAW_CREDENTIALS
export NPM_GLOBAL NPM_BIN
export LOG_FILE PROGRESS_FILE
export DEFAULT_GATEWAY_PORT DEFAULT_GATEWAY_BIND
export INSTALL_MODE INSTALL_VERSION OPENCLAW_USER BEGINNER_MODE

export -f log_init log_write log_info log_success log_warning log_error log_step log_debug
export -f setup_error_handling handle_error handle_exit handle_interrupt
export -f save_progress load_progress check_incomplete_install clear_progress
export -f detect_os detect_arch detect_memory detect_disk detect_cpu_cores
export -f command_exists commands_exist get_command_path
export -f version_compare version_lt version_le version_gt version_ge
export -f check_network download_file fetch_url
export -f ensure_dir safe_write_file backup_file
export -f jq_available json_get json_set
export -f is_root has_sudo user_in_sudo_group get_normal_users user_exists get_user_home
export -f has_systemd service_status service_is_running
export -f trim to_lower to_upper random_string generate_token
export -f get_term_explanation show_term_explanation
