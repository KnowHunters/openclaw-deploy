#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  OpenClaw Admin Panel v1.1                                                   ║
# ║  功能: 管理服务、市场、配置、监控的全能面板                                  ║
# ║  作者: KnowHunters (知识猎人)                                                ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# 全局配置
OPENCLAW_USER="${OPENCLAW_USER:-openclaw}"
WORKSPACE_DIR="${WORKSPACE_DIR:-/home/$OPENCLAW_USER/openclaw-bot}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="/home/$OPENCLAW_USER/.openclaw/openclaw.json"
ENV_FILE="$WORKSPACE_DIR/.env"

# 颜色定义
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

# ════════════════════ 辅助工具 ════════════════════
pause() {
    echo ""
    read -p "按回车键继续..."
}

header() {
    clear
    echo -e "${CYAN}"
    echo "╔═════════════════════════════════════════════════════════════════════╗"
    echo "║   ___                    ____ _                                     ║"
    echo "║  / _ \ _ __   ___ _ __  / ___| | __ ___      __     Admin Panel     ║"
    echo "║ | | | | '_ \ / _ \ '_ \| |   | |/ _\` \ \ /\ / /     v1.1            ║"
    echo "║ | |_| | |_) |  __/ | | | |___| | (_| |\ V  V /                      ║"
    echo "║  \___/| .__/ \___|_| |_|\____|_|\__,_| \_/\_/                       ║"
    echo "║       |_|                                                           ║"
    echo "╚═════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # 状态栏
    local pm2_status=$(sudo -u "$OPENCLAW_USER" pm2 jlist | grep -q "online" && echo -e "${GREEN}● 运行中${NC}" || echo -e "${RED}● 已停止${NC}")
    local mem_usage=$(free -h | awk 'NR==2{print $3 "/" $2}')
    local load_avg=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d, -f1)
    
    echo -e " ${BOLD}状态${NC}: $pm2_status  |  ${BOLD}内存${NC}: ${GRAY}$mem_usage${NC}  |  ${BOLD}负载${NC}: ${GRAY}$load_avg${NC}"
    echo -e "${GRAY}───────────────────────────────────────────────────────────────────────${NC}"
}

ensure_nano() {
    if ! command -v nano &>/dev/null; then
        echo -e "${YELLOW}[!] 检测到未安装 nano 编辑器，正在自动安装...${NC}"
        if [ "$EUID" -eq 0 ]; then
            apt-get update -qq && apt-get install -yqq nano
        else
            sudo apt-get update -qq && sudo apt-get install -yqq nano
        fi
        echo -e "${GREEN}[✓] 安装完成${NC}"
        sleep 1
    fi
}

run_as_user() {
    sudo -u "$OPENCLAW_USER" "$@"
}

run_as_user_shell() {
    su - "$OPENCLAW_USER" -c "$1"
}

# ════════════════════ 1. 服务管理 ════════════════════
menu_service() {
    while true; do
        header
        echo -e "${BOLD}🚀 服务管理${NC}"
        echo ""
        echo "  1) 启动服务 (Start)"
        echo "  2) 停止服务 (Stop)"
        echo "  3) 重启服务 (Restart)"
        echo "  4) 查看详细状态"
        echo "  5) 实时日志 (Logs)"
        echo ""
        echo "  0) 返回主菜单"
        echo ""
        read -p "请选择: " choice
        
        case $choice in
            1) 
                echo -e "\n${CYAN}→ 启动服务...${NC}"
                run_as_user_shell "pm2 start openclaw || (cd $WORKSPACE_DIR && pm2 start npm --name openclaw -- start)"
                pause ;;
            2) 
                echo -e "\n${CYAN}→ 停止服务...${NC}"
                run_as_user pm2 stop openclaw
                pause ;;
            3) 
                echo -e "\n${CYAN}→ 重启服务...${NC}"
                run_as_user pm2 restart openclaw
                pause ;;
            4) 
                run_as_user pm2 status
                pause ;;
            5) 
                echo -e "\n${CYAN}→ 按 Ctrl+C 退出日志${NC}"
                run_as_user pm2 logs openclaw --lines 50
                ;;
            0) return ;;
            *) ;;
        esac
    done
}

# ════════════════════ 2. 技能市场 ════════════════════
install_skill() {
    local skill_name=$1
    echo -e "\n${CYAN}→ 正在安装技能: ${BOLD}$skill_name${NC}"
    
    # 检查 clawhub 是否可用，不可用则先安装
    if ! run_as_user_shell "npm list -g clawhub >/dev/null 2>&1"; then
        echo -e "${YELLOW}正在初始化技能安装器...${NC}"
        run_as_user_shell "npm install -g clawhub"
    fi
    
    run_as_user_shell "npx -y clawhub@latest install $skill_name"
    
    echo -e "${GREEN}✓ 安装指令已下达${NC}"
    echo -e "${YELLOW}注意: 安装后建议重启 OpenClaw 服务以生效${NC}"
    pause
}

menu_skills_browse() {
    while true; do
        header
        echo -e "${BOLD}📦 技能推荐 > 浏览安装${NC}"
        echo ""
        echo -e "${CYAN}🛠  效率工具${NC}"
        echo "  1) Obsidian        (笔记同步)"
        echo "  2) Notion          (知识库)"
        echo "  3) Google Calendar (日历管理)"
        echo ""
        echo -e "${CYAN}🔍 搜索资讯${NC}"
        echo "  4) Google Search   (谷歌搜索)"
        echo "  5) Wikipedia       (维基百科)"
        echo "  6) HackerNews      (科技资讯)"
        echo ""
        echo -e "${CYAN}🎮 娱乐生活${NC}"
        echo "  7) GOG             (游戏查询)"
        echo "  8) Spotify         (音乐控制)"
        echo ""
        echo -e "${CYAN}💻 开发运维${NC}"
        echo "  9) Shell           (执行命令 - 慎用)"
        echo "  10) Git            (代码管理)"
        echo ""
        echo "  m) 手动输入技能名安装"
        echo "  0) 返回上级"
        echo ""
        read -p "请选择安装: " sk_choice
        
        case $sk_choice in
            1) install_skill "obsidian" ;;
            2) install_skill "notion" ;;
            3) install_skill "google-calendar" ;;
            4) install_skill "google-search" ;;
            5) install_skill "wikipedia" ;;
            6) install_skill "hackernews" ;;
            7) install_skill "gog" ;;
            8) install_skill "spotify" ;;
            9) install_skill "shell" ;;
            10) install_skill "git" ;;
            m) 
                read -p "请输入技能名称 (如 weather): " manual_name
                [ ! -z "$manual_name" ] && install_skill "$manual_name"
                ;;
            0) return ;;
        esac
    done
}

menu_skills() {
    while true; do
        header
        echo -e "${BOLD}📦 技能市场 (Skill Market)${NC}"
        echo ""
        echo "  1) 浏览热门推荐 (Browse Popular)"
        echo "  2) 手动安装技能 (Install Manually)"
        echo "  3) 查看已安装技能 (List Installed)"
        echo ""
        echo "  0) 返回主菜单"
        echo ""
        read -p "请选择: " choice
        
        case $choice in
            1) menu_skills_browse ;;
            2) 
                read -p "请输入技能名称: " sname
                [ ! -z "$sname" ] && install_skill "$sname"
                ;;
            3)
                echo -e "\n${CYAN}已安装技能目录 (${WORKSPACE_DIR}/skills):${NC}"
                ls -1 "$WORKSPACE_DIR/skills" 2>/dev/null || echo "暂无已安装技能"
                pause
                ;;
            0) return ;;
        esac
    done
}

# ════════════════════ 3. 配置中心 ════════════════════
edit_file_as_user() {
    local file=$1
    ensure_nano
    echo -e "${YELLOW}正在打开编辑器... (Ctrl+O 保存, Ctrl+X 退出)${NC}"
    sleep 1
    # 使用 su -c 调用 nano，确保以 openclaw 用户身份编辑，避免权限问题
    su - "$OPENCLAW_USER" -c "nano '$file'"
}

menu_config() {
    while true; do
        header
        echo -e "${BOLD}⚙️ 配置中心${NC}"
        echo ""
        echo "  1) 编辑主配置 (openclaw.json)"
        echo "  2) 编辑环境变量 (.env)"
        echo "  3) 切换 LLM 模型 (简易向导)"
        echo ""
        echo "  0) 返回主菜单"
        echo ""
        read -p "请选择: " choice
        
        case $choice in
            1) edit_file_as_user "$CONFIG_FILE" ;;
            2) edit_file_as_user "$ENV_FILE" ;;
            3) 
                echo -e "\n${YELLOW}暂未实现自动切换，请手动编辑 openclaw.json${NC}"
                pause 
                ;;
            0) return ;;
        esac
    done
}

# ════════════════════ 4. 维护工具 ════════════════════
fix_permissions() {
    echo -e "\n${CYAN}→ 正在修复文件权限...${NC}"
    chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "/home/$OPENCLAW_USER"
    chmod 755 "/home/$OPENCLAW_USER"
    echo -e "${GREEN}✓ 权限修复完成${NC}"
    pause
}

menu_maintenance() {
    while true; do
        header
        echo -e "${BOLD}🧹 维护与诊断${NC}"
        echo ""
        echo "  1) 一键修复权限 (Fix Permissions)"
        echo "  2) 清理日志文件 (Clean Logs)"
        echo "  3) 运行系统诊断 (Doctor)"
        echo "  4) 一键懒人优化 (Lazy Optimize)"
        echo "  5) 备份与恢复 (Backup/Restore)"
        echo "  6) 更新 OpenClaw (Update)"
        echo ""
        echo "  0) 返回主菜单"
        echo ""
        read -p "请选择: " choice
        
        case $choice in
            1) fix_permissions ;;
            2) 
                [ -f "$SCRIPT_DIR/log-cleanup.sh" ] && bash "$SCRIPT_DIR/log-cleanup.sh" || echo "脚本丢失"
                pause ;;
            3) 
                echo -e "\n${CYAN}→ 运行 Doctor...${NC}"
                run_as_user_shell "openclaw doctor"
                pause ;;
            4) 
                [ -f "$SCRIPT_DIR/lazy-optimize.sh" ] && sudo bash "$SCRIPT_DIR/lazy-optimize.sh" || echo "脚本丢失"
                pause ;;
            5) 
                echo -e "\n${YELLOW}请使用子菜单脚本: backup.sh / restore.sh${NC}"
                ls -l "$SCRIPT_DIR" | grep "restore\|backup"
                pause ;;
            6)
                echo -e "\n${CYAN}→ 更新 OpenClaw...${NC}"
                npm install -g @openclaw/cli@latest
                run_as_user_shell "cd $WORKSPACE_DIR && npm update"
                run_as_user pm2 restart openclaw
                echo -e "${GREEN}✓ 更新完成${NC}"
                pause ;;
            0) return ;;
        esac
    done
}

# ════════════════════ 主入口 ════════════════════
while true; do
    header
    echo -e " ${GREEN}[1] 🚀 服务管理${NC}      (Start, Stop, Logs)"
    echo -e " ${GREEN}[2] 📦 技能市场${NC}      (Install Skills)"
    echo -e " ${GREEN}[3] ⚙️ 配置中心${NC}      (Edit Config)"
    echo -e " ${GREEN}[4] 🧹 维护与诊断${NC}    (Fix, Doctor, Update)"
    echo ""
    echo -e " [0] 退出"
    echo ""
    read -p "请选择操作 [0-4]: " main_choice

    case $main_choice in
        1) menu_service ;;
        2) menu_skills ;;
        3) menu_config ;;
        4) menu_maintenance ;;
        0) echo "再见!"; exit 0 ;;
        *) ;;
    esac
done
