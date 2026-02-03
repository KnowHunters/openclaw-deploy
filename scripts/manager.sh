#!/bin/bash
# ╔════════════════════════════════════════════════════════════╗
# ║  OpenClaw 管理面板                                         ║
# ║  功能: 一键管理服务、日志、备份、监控                      ║
# ╚════════════════════════════════════════════════════════════╝

OPENCLAW_USER="${OPENCLAW_USER:-openclaw}"
WORKSPACE_DIR="${WORKSPACE_DIR:-/home/$OPENCLAW_USER/openclaw-bot}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║     ___                    ____ _                         ║"
    echo "║    / _ \ _ __   ___ _ __  / ___| | __ ___      __         ║"
    echo "║   | | | | '_ \ / _ \ '_ \| |   | |/ _\` \ \ /\ / /         ║"
    echo "║   | |_| | |_) |  __/ | | | |___| | (_| |\ V  V /          ║"
    echo "║    \___/| .__/ \___|_| |_|\____|_|\__,_| \_/\_/           ║"
    echo "║         |_|                                               ║"
    echo "║                    管 理 面 板                            ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

show_menu() {
    echo -e "${GREEN}服务管理${NC}"
    echo "  1) 启动服务"
    echo "  2) 停止服务"
    echo "  3) 重启服务"
    echo "  4) 查看状态"
    echo ""
    echo -e "${GREEN}监控与日志${NC}"
    echo "  5) 查看实时日志"
    echo "  6) 运行健康检查"
    echo "  7) 查看性能统计"
    echo ""
    echo -e "${GREEN}备份与恢复${NC}"
    echo "  8) 创建备份"
    echo "  9) 恢复备份"
    echo ""
    echo -e "${GREEN}维护${NC}"
    echo "  10) 清理日志"
    echo "  11) 更新 OpenClaw"
    echo ""
    echo "  0) 退出"
    echo ""
}

start_service() {
    echo -e "\n${CYAN}→ 启动服务...${NC}"
    sudo -u "$OPENCLAW_USER" pm2 start openclaw 2>/dev/null || \
    sudo -u "$OPENCLAW_USER" bash -c "cd $WORKSPACE_DIR && pm2 start npm --name openclaw -- start"
    sudo -u "$OPENCLAW_USER" pm2 status
}

stop_service() {
    echo -e "\n${CYAN}→ 停止服务...${NC}"
    sudo -u "$OPENCLAW_USER" pm2 stop openclaw
}

restart_service() {
    echo -e "\n${CYAN}→ 重启服务...${NC}"
    sudo -u "$OPENCLAW_USER" pm2 restart openclaw
    sudo -u "$OPENCLAW_USER" pm2 status
}

view_status() {
    echo -e "\n${CYAN}═══════════ 服务状态 ═══════════${NC}"
    sudo -u "$OPENCLAW_USER" pm2 status
    echo ""
    sudo -u "$OPENCLAW_USER" pm2 show openclaw 2>/dev/null | head -20
}

view_logs() {
    echo -e "\n${CYAN}→ 查看日志 (Ctrl+C 退出)...${NC}"
    sudo -u "$OPENCLAW_USER" pm2 logs openclaw --lines 50
}

run_health_check() {
    if [ -f "$SCRIPT_DIR/health-monitor.sh" ]; then
        bash "$SCRIPT_DIR/health-monitor.sh"
    else
        echo -e "${RED}✗ health-monitor.sh 未找到${NC}"
    fi
}

view_performance() {
    echo -e "\n${CYAN}═══════════ PM2 实时监控 ═══════════${NC}"
    echo ""
    echo "  按 Ctrl+C 退出监控界面"
    echo ""
    sleep 1
    sudo -u "$OPENCLAW_USER" pm2 monit
}

create_backup() {
    if [ -f "$SCRIPT_DIR/backup.sh" ]; then
        bash "$SCRIPT_DIR/backup.sh"
    else
        echo -e "${RED}✗ backup.sh 未找到${NC}"
    fi
}

restore_backup() {
    if [ -f "$SCRIPT_DIR/restore.sh" ]; then
        bash "$SCRIPT_DIR/restore.sh"
    else
        echo -e "${RED}✗ restore.sh 未找到${NC}"
    fi
}

cleanup_logs() {
    if [ -f "$SCRIPT_DIR/log-cleanup.sh" ]; then
        bash "$SCRIPT_DIR/log-cleanup.sh"
    else
        echo -e "${RED}✗ log-cleanup.sh 未找到${NC}"
    fi
}

update_openclaw() {
    echo -e "\n${CYAN}→ 更新 OpenClaw...${NC}"
    npm install -g @openclaw/cli@latest
    sudo -u "$OPENCLAW_USER" bash -c "cd $WORKSPACE_DIR && npm update"
    sudo -u "$OPENCLAW_USER" pm2 restart openclaw
    echo -e "${GREEN}✓ 更新完成${NC}"
}

# 主循环
while true; do
    show_banner
    show_menu
    read -p "请选择操作 [0-11]: " choice
    
    case $choice in
        1) start_service ;;
        2) stop_service ;;
        3) restart_service ;;
        4) view_status ;;
        5) view_logs ;;
        6) run_health_check ;;
        7) view_performance ;;
        8) create_backup ;;
        9) restore_backup ;;
        10) cleanup_logs ;;
        11) update_openclaw ;;
        0) echo "再见!"; exit 0 ;;
        *) echo -e "${RED}无效选择${NC}" ;;
    esac
    
    echo ""
    read -p "按回车继续..."
done
