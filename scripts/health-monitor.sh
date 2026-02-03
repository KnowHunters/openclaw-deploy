#!/bin/bash
# ╔════════════════════════════════════════════════════════════╗
# ║  OpenClaw 健康监控脚本 (PM2 适配版)                        ║
# ║  功能: 检查服务状态、资源使用、自动恢复                    ║
# ╚════════════════════════════════════════════════════════════╝

set -e

# ═══════════════ 配置区 ═══════════════
OPENCLAW_USER="${OPENCLAW_USER:-openclaw}"
WORKSPACE_DIR="${WORKSPACE_DIR:-/home/$OPENCLAW_USER/openclaw-bot}"
PM2_APP_NAME="openclaw"
LOG_FILE="/var/log/openclaw-health.log"
ALERT_EMAIL=""  # 可选: 填写邮箱接收告警

# 阈值
MAX_CPU_PERCENT=80
MAX_MEM_PERCENT=80
MAX_RESTARTS=5

# ═══════════════ 颜色定义 ═══════════════
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ═══════════════ 日志函数 ═══════════════
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_ok()    { echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"; }
log_warn()  { echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"; }

# ═══════════════ 告警函数 ═══════════════
send_alert() {
    local subject="$1"
    local message="$2"
    
    if [ -n "$ALERT_EMAIL" ] && command -v mail &>/dev/null; then
        echo "$message" | mail -s "[OpenClaw] $subject" "$ALERT_EMAIL"
    fi
}

# ═══════════════ 核心检查 ═══════════════

# 检查 PM2 进程状态
check_pm2_status() {
    local status
    status=$(sudo -u "$OPENCLAW_USER" pm2 jlist 2>/dev/null | jq -r ".[] | select(.name==\"$PM2_APP_NAME\") | .pm2_env.status" 2>/dev/null || echo "not_found")
    
    case "$status" in
        "online")
            log_ok "PM2 进程状态: 运行中"
            return 0
            ;;
        "stopped"|"errored")
            log_error "PM2 进程状态: $status"
            return 1
            ;;
        "not_found")
            log_warn "PM2 进程未找到 (可能未启动)"
            return 2
            ;;
        *)
            log_warn "PM2 进程状态未知: $status"
            return 1
            ;;
    esac
}

# 检查资源使用
check_resources() {
    local pid
    pid=$(sudo -u "$OPENCLAW_USER" pm2 jlist 2>/dev/null | jq -r ".[] | select(.name==\"$PM2_APP_NAME\") | .pid" 2>/dev/null)
    
    if [ -z "$pid" ] || [ "$pid" = "0" ]; then
        log_warn "无法获取进程 PID"
        return
    fi
    
    # CPU
    local cpu
    cpu=$(ps -p "$pid" -o %cpu --no-headers 2>/dev/null | tr -d ' ' || echo "0")
    cpu=${cpu%.*}
    
    if [ "$cpu" -gt "$MAX_CPU_PERCENT" ]; then
        log_warn "CPU 使用率过高: ${cpu}%"
        send_alert "CPU 告警" "CPU 使用率: ${cpu}%"
    else
        log "CPU: ${cpu}%"
    fi
    
    # Memory
    local mem
    mem=$(ps -p "$pid" -o %mem --no-headers 2>/dev/null | tr -d ' ' || echo "0")
    mem=${mem%.*}
    
    if [ "$mem" -gt "$MAX_MEM_PERCENT" ]; then
        log_warn "内存使用率过高: ${mem}%"
        send_alert "内存告警" "内存使用率: ${mem}%"
    else
        log "内存: ${mem}%"
    fi
}

# 检查磁盘空间
check_disk() {
    local usage
    usage=$(df -h / | awk 'NR==2{print $5}' | sed 's/%//')
    
    if [ "$usage" -gt 90 ]; then
        log_error "磁盘空间不足: ${usage}%"
        send_alert "磁盘告警" "磁盘使用率: ${usage}%"
    elif [ "$usage" -gt 80 ]; then
        log_warn "磁盘空间较低: ${usage}%"
    else
        log "磁盘: ${usage}%"
    fi
}

# 检查重启次数
check_restarts() {
    local restarts
    restarts=$(sudo -u "$OPENCLAW_USER" pm2 jlist 2>/dev/null | jq -r ".[] | select(.name==\"$PM2_APP_NAME\") | .pm2_env.restart_time" 2>/dev/null || echo "0")
    
    if [ "$restarts" -gt "$MAX_RESTARTS" ]; then
        log_warn "PM2 重启次数过多: $restarts (可能存在崩溃循环)"
        send_alert "重启告警" "PM2 重启次数: $restarts"
    else
        log "PM2 重启次数: $restarts"
    fi
}

# 自动恢复
auto_recover() {
    log "尝试自动恢复..."
    
    sudo -u "$OPENCLAW_USER" pm2 restart "$PM2_APP_NAME" 2>/dev/null || \
    sudo -u "$OPENCLAW_USER" pm2 start "$WORKSPACE_DIR/ecosystem.config.js" --name "$PM2_APP_NAME" 2>/dev/null || \
    sudo -u "$OPENCLAW_USER" bash -c "cd $WORKSPACE_DIR && pm2 start npm --name $PM2_APP_NAME -- start" 2>/dev/null
    
    sleep 5
    
    if check_pm2_status; then
        log_ok "服务恢复成功"
        send_alert "自动恢复成功" "OpenClaw 服务已自动重启"
        return 0
    else
        log_error "服务恢复失败，需要人工介入"
        send_alert "恢复失败" "OpenClaw 服务恢复失败，请检查"
        return 1
    fi
}

# ═══════════════ 主流程 ═══════════════
main() {
    echo -e "\n${CYAN}══════════ OpenClaw 健康检查 [$(date '+%H:%M:%S')] ══════════${NC}"
    
    # 1. 检查 PM2 状态
    if ! check_pm2_status; then
        auto_recover
        return
    fi
    
    # 2. 检查资源
    check_resources
    
    # 3. 检查重启次数
    check_restarts
    
    # 4. 检查磁盘
    check_disk
    
    echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}\n"
}

main "$@"
