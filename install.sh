#!/bin/bash
# ╔════════════════════════════════════════════════════════════════════╗
# ║  OpenClaw Deploy - 终极版一键部署脚本                             ║
# ║  版本: 1.0.0 | 许可: MIT | 作者: KnowHunters (知识猎人)            ║
# ║  功能: 交互式配置 | 多模型预设 | 监控套件 | 自动备份               ║
# ║  GitHub: https://github.com/KnowHunters/openclaw-deploy            ║
# ╚════════════════════════════════════════════════════════════════════╝
#
# 用法:
#   curl -fsSL https://raw.githubusercontent.com/KnowHunters/openclaw-deploy/main/install.sh | sudo bash
#   curl ... | sudo bash -s -- -n              # 非交互模式
#   curl ... | sudo bash -s -- -u              # 仅更新

set -e

# ════════════════════ 全局配置 ════════════════════
VERSION="1.0.0"
OPENCLAW_USER="openclaw"
WORKSPACE_DIR="/home/$OPENCLAW_USER/openclaw-bot"
SCRIPTS_DIR="/home/$OPENCLAW_USER/openclaw-scripts"
CONFIG_FILE="/home/$OPENCLAW_USER/.openclaw/openclaw.json"
NODE_MAJOR=22
MIN_RAM_MB=4096
TZ="Asia/Shanghai"

# 网关默认值 (安全优先: 仅本地访问)
DEFAULT_BIND="127.0.0.1"
DEFAULT_PORT="18789"
GATEWAY_BIND=${GATEWAY_BIND:-$DEFAULT_BIND}
GATEWAY_PORT=${GATEWAY_PORT:-$DEFAULT_PORT}

# 模式标记
NON_INTERACTIVE=false
UPDATE_MODE=false

# ════════════════════ 颜色定义 ════════════════════
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

# ════════════════════ 辅助函数 ════════════════════

print_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                                                                              ║
    ║   ██████╗ ██████╗ ███████╗███╗   ██╗ ██████╗██╗      █████╗ ██╗    ██╗       ║
    ║  ██╔═══██╗██╔══██╗██╔════╝████╗  ██║██╔════╝██║     ██╔══██╗██║    ██║       ║
    ║  ██║   ██║██████╔╝█████╗  ██╔██╗ ██║██║     ██║     ███████║██║ █╗ ██║       ║
    ║  ██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║██║     ██║     ██╔══██║██║███╗██║       ║
    ║  ╚██████╔╝██║     ███████╗██║ ╚████║╚██████╗███████╗██║  ██║╚███╔███╔╝       ║
    ║   ╚═════╝ ╚═╝     ╚══════╝╚╚═╝  ╚═══╝ ╚═════╝╚══════╝╚═╝  ╚═╝ ╚══╝╚══╝        ║
    ║                                                                              ║
    ║                    D E P L O Y   v1.0  by KnowHunters                        ║
    ╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

spinner() {
    local pid=$1
    local delay=0.15
    local chars='|/-\'
    local i=0
    while kill -0 $pid 2>/dev/null; do
        printf "\r${CYAN}[${chars:$i:1}]${NC} "
        i=$(( (i+1) % 4 ))
        sleep $delay
    done
    printf "\r    \r"
}

run_step() {
    local msg="$1"
    local cmd="$2"
    
    echo -ne "${BLUE}[*]${NC} $msg..."
    
    eval "$cmd" > /tmp/openclaw_install.log 2>&1 &
    local pid=$!
    spinner $pid
    wait $pid
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}[✓]${NC}"
    else
        echo -e "${RED}[✗]${NC}"
        echo -e "${RED}错误详情:${NC}"
        tail -n 15 /tmp/openclaw_install.log
        exit 1
    fi
}

log_info()  { echo -e "${CYAN}[i]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# 错误捕获
cleanup_trap() {
    if [ $? -ne 0 ]; then
        echo -e "\n${RED}安装中断！${NC} 详情: /tmp/openclaw_install.log"
    fi
}
trap cleanup_trap EXIT

# ════════════════════ 参数解析 ════════════════════
while getopts "nu" opt; do
  case $opt in
    n) NON_INTERACTIVE=true ;;
    u) UPDATE_MODE=true ;;
    *) echo "用法: $0 [-n 非交互] [-u 仅更新]"; exit 1 ;;
  esac
done

# ════════════════════ 安装确认菜单 ════════════════════
check_existing_installation() {
    if [ -f "$CONFIG_FILE" ] && [ "$NON_INTERACTIVE" = false ] && [ "$UPDATE_MODE" = false ]; then
        echo ""
        log_warn "检测到已有 OpenClaw 安装"
        echo ""
        echo "  1) 更新 OpenClaw (保留配置)"
        echo "  2) 完全重装 (需要确认)"
        echo "  3) 取消"
        echo ""
        read -p "请选择 [1-3]: " INSTALL_CHOICE
        
        case "$INSTALL_CHOICE" in
            1)
                UPDATE_MODE=true
                log_info "切换到更新模式"
                ;;
            2)
                echo ""
                log_warn "⚠ 危险操作：完全重装将删除所有配置！"
                read -p "确认删除？请输入 'DELETE' 确认: " CONFIRM
                if [ "$CONFIRM" != "DELETE" ]; then
                    log_info "已取消"
                    exit 0
                fi
                # 备份后删除
                local BACKUP_DIR="/home/$OPENCLAW_USER/openclaw-backups"
                mkdir -p "$BACKUP_DIR"
                local BACKUP_FILE="$BACKUP_DIR/pre-reinstall-$(date +%Y%m%d_%H%M%S).tar.gz"
                tar -czf "$BACKUP_FILE" -C "/home/$OPENCLAW_USER" .openclaw 2>/dev/null || true
                log_ok "配置已备份至: $BACKUP_FILE"
                rm -rf "/home/$OPENCLAW_USER/.openclaw"
                ;;
            *)
                log_info "已取消"
                exit 0
                ;;
        esac
    fi
}

# ════════════════════ 系统预检 ════════════════════
pre_flight_check() {
    echo ""
    echo -e "${GRAY}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GRAY}  [1/6] 系统环境预检                                       ${NC}"
    echo -e "${GRAY}═══════════════════════════════════════════════════════════${NC}"
    
    [ "$EUID" -ne 0 ] && log_error "必须使用 root 权限运行"
    
    run_step "检测网络连通性" "curl -sI https://github.com >/dev/null && curl -sI https://registry.npmjs.org >/dev/null"
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        log_info "操作系统: $PRETTY_NAME"
        [ "$ID" != "ubuntu" ] && log_warn "本脚本针对 Ubuntu 优化，其他系统可能存在兼容性问题"
    fi
    
    log_info "部署目标: $OPENCLAW_USER @ $GATEWAY_BIND:$GATEWAY_PORT"
}

# ════════════════════ 系统调优 ════════════════════
optimize_system() {
    [ "$UPDATE_MODE" = true ] && return
    
    echo ""
    echo -e "${GRAY}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GRAY}  [2/6] 系统调优                                           ${NC}"
    echo -e "${GRAY}═══════════════════════════════════════════════════════════${NC}"
    
    # Timezone
    CURRENT_TZ=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "")
    if [ "$CURRENT_TZ" != "$TZ" ]; then
        run_step "设置时区 ($TZ)" "timedatectl set-timezone $TZ"
    else
        log_ok "时区已正确 ($CURRENT_TZ)"
    fi
    
    # Swap
    TOTAL_MEM=$(free -m | awk 'NR==2{print $2}')
    if [ "$TOTAL_MEM" -lt "$MIN_RAM_MB" ]; then
        SWAP_EXIST=$(free -m | awk 'NR==3{print $2}')
        if [ "$SWAP_EXIST" -eq 0 ]; then
            run_step "创建 2GB Swap" "
                fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
                chmod 600 /swapfile
                mkswap /swapfile
                swapon /swapfile
                grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
            "
        fi
    fi
}

# ════════════════════ 依赖安装 ════════════════════
install_dependencies() {
    echo ""
    echo -e "${GRAY}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GRAY}  [3/6] 依赖安装                                           ${NC}"
    echo -e "${GRAY}═══════════════════════════════════════════════════════════${NC}"
    
    if [ "$UPDATE_MODE" = true ]; then
        run_step "更新 OpenClaw CLI & PM2" "npm install -g @openclaw/cli@latest pm2@latest"
        return
    fi
    
    export DEBIAN_FRONTEND=noninteractive
    
    # 系统库
    run_step "更新软件源" "apt-get update -qq"
    run_step "安装基础组件" "apt-get install -yqq curl wget git build-essential ca-certificates gnupg lsb-release jq unzip"
    run_step "安装开发工具" "apt-get install -yqq ripgrep fd-find bat htop tree"
    run_step "安装媒体处理" "apt-get install -yqq ffmpeg imagemagick graphicsmagick tesseract-ocr poppler-utils"
    run_step "安装 Python 环境" "apt-get install -yqq python3-full python3-pip python3-venv"
    
    # 软链修正
    [ ! -f /usr/bin/fd ] && ln -sf $(which fdfind) /usr/bin/fd 2>/dev/null || true
    [ ! -f /usr/bin/bat ] && ln -sf $(which batcat) /usr/bin/bat 2>/dev/null || true
    
    # Python AI 库
    run_step "安装 Python AI 工具" "pip3 install --upgrade yt-dlp pandas numpy beautifulsoup4 --break-system-packages"
    
    # GitHub CLI
    if ! command -v gh &>/dev/null; then
        local ARCH=$(dpkg --print-architecture)
        run_step "安装 GitHub CLI" "
            curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
            chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
            echo 'deb [arch=${ARCH} signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
            apt-get update -qq && apt-get install -yqq gh
        "
    fi
    
    # Chromium (Ubuntu 24.04 使用 snap 安装)
    if ! command -v chromium-browser &>/dev/null && ! command -v chromium &>/dev/null; then
        run_step "安装 Chromium 浏览器" "
            apt-get install -yqq snapd || true
            snap install chromium
        "
    fi
    
    # Node.js
    if ! command -v node &>/dev/null; then
        run_step "安装 Node.js v$NODE_MAJOR" "curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - && apt-get install -yqq nodejs"
    fi
    
    # OpenClaw CLI & PM2
    run_step "安装 OpenClaw CLI & PM2" "npm install -g openclaw@latest pm2@latest"
    
    # PM2 日志轮转
    pm2 install pm2-logrotate >/dev/null 2>&1 || true
    pm2 set pm2-logrotate:max_size 10M >/dev/null 2>&1 || true

    # Linuxbrew (Homebrew) - 解决 Skill 依赖问题 (camsnap, gog 等)
    if [ ! -d "/home/linuxbrew/.linuxbrew" ]; then
        run_step "准备 Linuxbrew 目录" "
            mkdir -p /home/linuxbrew/.linuxbrew
            chown -R $OPENCLAW_USER:$OPENCLAW_USER /home/linuxbrew
        "
        
        run_step "安装 Linuxbrew (耗时较长)" "
            su - $OPENCLAW_USER -c 'NONINTERACTIVE=1 /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"'
        "
        
        run_step "配置 Linuxbrew 环境" "
            echo 'eval \"\$(\/home/linuxbrew\/.linuxbrew\/bin\/brew shellenv)\"' >> /home/$OPENCLAW_USER/.bashrc
            echo 'eval \"\$(\/home/linuxbrew\/.linuxbrew\/bin\/brew shellenv)\"' >> /home/$OPENCLAW_USER/.profile
        "
    else
        log_ok "Linuxbrew 已安装"
    fi
    
    # 将 brew 加入当前 PATH 供后续步骤使用
    if [ -d "/home/linuxbrew/.linuxbrew/bin" ]; then
        eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\"
    fi
}

# ════════════════════ 部署工作区 ════════════════════
prepare_workspace() {
    echo ""
    echo -e "${GRAY}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GRAY}  [4/6] 准备工作区                                         ${NC}"
    echo -e "${GRAY}═══════════════════════════════════════════════════════════${NC}"
    
    # 创建用户
    if id "$OPENCLAW_USER" &>/dev/null; then
        log_info "用户 $OPENCLAW_USER 已存在"
    else
        run_step "创建运行用户 ($OPENCLAW_USER)" "useradd -m -s /bin/bash $OPENCLAW_USER"
    fi
    
    run_step "初始化目录结构" "
        mkdir -p $WORKSPACE_DIR
        mkdir -p $SCRIPTS_DIR
        mkdir -p /home/$OPENCLAW_USER/.openclaw
        chown -R $OPENCLAW_USER:$OPENCLAW_USER /home/$OPENCLAW_USER
    "
    
    # 可选备份
    if [ -f "$WORKSPACE_DIR/package.json" ] && [ "$UPDATE_MODE" = false ]; then
        if [ "$NON_INTERACTIVE" = false ]; then
            echo ""
            log_warn "检测到现有安装"
            read -p "是否创建备份? [Y/n] " BACKUP_REPLY
            if [[ ! $BACKUP_REPLY =~ ^[Nn]$ ]]; then
                local BACKUP_NAME="backup_$(date +%Y%m%d_%H%M%S)"
                log_info "备份至 ${WORKSPACE_DIR}_$BACKUP_NAME..."
                cp -r "$WORKSPACE_DIR" "${WORKSPACE_DIR}_$BACKUP_NAME"
            fi
    fi
    fi

    # 配置 NPM 本地环境 (解决权限问题)
    run_step "配置 NPM 本地环境" "
        mkdir -p /home/$OPENCLAW_USER/.npm-global
        chown $OPENCLAW_USER:$OPENCLAW_USER /home/$OPENCLAW_USER/.npm-global
        sudo -u $OPENCLAW_USER npm config set prefix '/home/$OPENCLAW_USER/.npm-global'
        
        # 添加到 .bashrc
        if ! grep -q 'npm-global/bin' /home/$OPENCLAW_USER/.bashrc; then
            echo 'export PATH=/home/$OPENCLAW_USER/.npm-global/bin:\$PATH' >> /home/$OPENCLAW_USER/.bashrc
        fi
    "
}

# ════════════════════ 完成配置并启动 ════════════════════
# ════════════════════ 监控脚本 ════════════════════
install_monitoring_scripts() {
    echo ""
    echo -e "${GRAY}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GRAY}  [5/6] 安装监控套件                                       ${NC}"
    echo -e "${GRAY}═══════════════════════════════════════════════════════════${NC}"
    
    local scripts=("health-monitor.sh" "log-cleanup.sh" "backup.sh" "restore.sh" "manager.sh" "lazy-optimize.sh")
    for script in "${scripts[@]}"; do
        run_step "下载 $script" "curl -fsSL https://raw.githubusercontent.com/KnowHunters/openclaw-deploy/main/scripts/$script -o $SCRIPTS_DIR/$script"
        chmod +x "$SCRIPTS_DIR/$script"
        chown "$OPENCLAW_USER:$OPENCLAW_USER" "$SCRIPTS_DIR/$script"
    done
    
    # 配置 Cron 任务 (日志清理)
    run_step "配置日志自动清理" "(crontab -l 2>/dev/null | grep -v 'log-cleanup.sh'; echo '0 2 * * * $SCRIPTS_DIR/log-cleanup.sh >> $WORKSPACE_DIR/logs/cleanup.log 2>&1') | crontab -"
}

# ════════════════════ 基础设施配置 (不启动服务) ════════════════════
setup_infrastructure() {
    echo ""
    echo -e "${GRAY}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GRAY}  [6/6] 基础设施配置                                       ${NC}"
    echo -e "${GRAY}═══════════════════════════════════════════════════════════${NC}"

    # 创建空的 .env 文件 (仅当不存在时)
    if [ ! -f "$WORKSPACE_DIR/.env" ]; then
        touch "$WORKSPACE_DIR/.env"
        chown "$OPENCLAW_USER:$OPENCLAW_USER" "$WORKSPACE_DIR/.env"
        chmod 600 "$WORKSPACE_DIR/.env"
    fi

    # 创建 PM2 启动脚本
    # 修复 Here-Doc 缩进问题：EOF 必须在行首
    run_step "创建启动脚本" "
cat > $WORKSPACE_DIR/start.sh << 'SCRIPT'
#!/bin/bash
cd /home/openclaw/openclaw-bot
# 加载环境变量
set -a
export PATH=/home/openclaw/.npm-global/bin:$PATH
# 如果 .env 存在则加载
[ -f .env ] && source .env
set +a
# 启动 openclaw gateway
exec openclaw gateway
SCRIPT
chmod +x $WORKSPACE_DIR/start.sh
chown $OPENCLAW_USER:$OPENCLAW_USER $WORKSPACE_DIR/start.sh
"
    
    # 配置 PM2 开机自启 (仅注册 PM2 本身)
    run_step "配置 PM2 开机自启" "env PATH=\$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u $OPENCLAW_USER --hp /home/$OPENCLAW_USER"
    
    # 安装 CLI 自动补全
    sudo -u "$OPENCLAW_USER" openclaw completion install 2>/dev/null || true
    
    # 防火墙
    if command -v ufw &>/dev/null && [ "$GATEWAY_BIND" != "127.0.0.1" ]; then
        run_step "配置防火墙" "ufw allow ssh && ufw allow $GATEWAY_PORT/tcp"
    fi
    
    log_ok "基础设施配置完成"
}

# ════════════════════ 完成配置 (自动向导) ════════════════════
show_completion() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}║     🎉  OpenClaw 环境部署完成 !                               ║${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BOLD}📋 部署信息${NC}"
    echo -e "   ├─ 工作目录  : $WORKSPACE_DIR"
    echo -e "   ├─ 运行用户  : $OPENCLAW_USER"
    echo -e "   └─ 网关地址  : http://$GATEWAY_BIND:$GATEWAY_PORT"
    echo ""
    
    # 倒计时运行 onboard
    echo -e "${YELLOW}准备运行配置向导 (openclaw onboard)...${NC}"
    for i in {5..1}; do
        echo -ne "\r${CYAN}将在 $i 秒后开始... (按 Ctrl+C 取消)${NC}"
        sleep 1
    done
    echo ""
    echo ""
    
    # 1. 运行配置向导
    log_info "启动配置向导..."
    sudo -u "$OPENCLAW_USER" openclaw onboard
    
    # 2. 确保服务运行并保存
    echo ""
    log_info "正在完成部署..."
    
    # 强制接管：清理旧进程
    log_info "清理旧进程..."
    # 彻底杀掉该用户的所有 PM2 进程，防止僵尸守护进程导致的 EACCES
    pkill -u "$OPENCLAW_USER" -f pm2 >/dev/null 2>&1 || true
    su - "$OPENCLAW_USER" -c "pm2 kill" >/dev/null 2>&1 || true
    
    # [关键修复] 强制修正权限，确保 .pm2 和 .npm-global 属于正确用户
    log_info "正在修正文件权限..."
    chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "/home/$OPENCLAW_USER"

    log_info "启动 OpenClaw 服务..."
    # 确保 node 权限正常 (防止 extreme case)
    if [ -f /usr/bin/node ]; then chmod 755 /usr/bin/node; fi
    
    su - "$OPENCLAW_USER" -c "pm2 start \"$WORKSPACE_DIR/start.sh\" --name openclaw"
    su - "$OPENCLAW_USER" -c "pm2 save"
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  🎉  部署成功！服务已后台运行${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "   • 访问地址 : http://$(curl -s ifconfig.me):$GATEWAY_PORT (或 http://$GATEWAY_BIND:$GATEWAY_PORT)"
    echo -e "   • 查看日志 : su - $OPENCLAW_USER -c 'pm2 logs openclaw'"
    echo -e "   • 管理菜单 : ~/openclaw-scripts/manager.sh"
    echo ""
}

# ════════════════════ 主流程 ════════════════════
main() {
    print_banner
    
    check_existing_installation
    
    # 1. 系统检查与优化
    pre_flight_check
    optimize_system
    
    # 2. 安装基础依赖和 CLI
    install_dependencies
    
    # 3. 准备工作目录
    prepare_workspace
    
    # 4. 安装监控脚本
    install_monitoring_scripts
    
    # 5. 基础设施配置 (不启动)
    if [ "$UPDATE_MODE" = false ]; then
        setup_infrastructure
    else
        # 更新模式下，仅重启服务
        run_step "重启服务" "sudo -u $OPENCLAW_USER pm2 restart all"
    fi
    
    # 6. 进入配置向导
    if [ "$UPDATE_MODE" = false ] && [ "$NON_INTERACTIVE" = false ]; then
        show_completion
    else
        log_ok "更新完成 / 非交互安装完成"
    fi
}

main "$@"
