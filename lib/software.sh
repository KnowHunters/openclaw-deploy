#!/bin/bash
# ============================================================================
# OpenClaw Deploy 2.0 - Software Manager
# ============================================================================
# 软件管理模块，提供可选依赖软件的安装
# ============================================================================

# 防止重复加载
[[ -n "$_SOFTWARE_LOADED" ]] && return 0
_SOFTWARE_LOADED=1

# ============================================================================
# 软件清单定义
# ============================================================================

# 软件分类
declare -A SOFTWARE_CATEGORIES=(
    ["required"]="必需组件"
    ["recommended"]="推荐组件"
    ["media"]="媒体工具"
    ["dev"]="开发工具"
)

# 软件信息: name|description|check_cmd|install_apt|install_dnf|install_brew
declare -A SOFTWARE_LIST=(
    # 必需组件
    ["nodejs"]="Node.js v22|OpenClaw 运行环境|node --version|nodejs|nodejs|node"
    ["git"]="Git|版本控制|git --version|git|git|git"
    ["curl"]="curl|网络请求工具|curl --version|curl|curl|curl"
    
    # 推荐组件
    ["jq"]="jq|JSON 处理工具|jq --version|jq|jq|jq"
    ["ripgrep"]="ripgrep|快速搜索工具|rg --version|ripgrep|ripgrep|ripgrep"
    ["fd"]="fd-find|快速文件查找|fd --version|fd-find|fd-find|fd"
    ["htop"]="htop|系统监控|htop --version|htop|htop|htop"
    ["tree"]="tree|目录树显示|tree --version|tree|tree|tree"
    
    # 媒体工具
    ["ffmpeg"]="ffmpeg|音视频处理|ffmpeg -version|ffmpeg|ffmpeg|ffmpeg"
    ["imagemagick"]="ImageMagick|图像处理|convert --version|imagemagick|ImageMagick|imagemagick"
    ["tesseract"]="Tesseract OCR|文字识别|tesseract --version|tesseract-ocr|tesseract|tesseract"
    
    # 开发工具
    ["python3"]="Python 3|Python 环境|python3 --version|python3|python3|python3"
    ["docker"]="Docker|容器运行时|docker --version|docker.io|docker|docker"
    ["chromium"]="Chromium|无头浏览器|chromium --version|chromium-browser|chromium|chromium"
)

# 软件分类映射
declare -A SOFTWARE_CATEGORY_MAP=(
    ["nodejs"]="required"
    ["git"]="required"
    ["curl"]="required"
    ["jq"]="recommended"
    ["ripgrep"]="recommended"
    ["fd"]="recommended"
    ["htop"]="recommended"
    ["tree"]="recommended"
    ["ffmpeg"]="media"
    ["imagemagick"]="media"
    ["tesseract"]="media"
    ["python3"]="dev"
    ["docker"]="dev"
    ["chromium"]="dev"
)

# ============================================================================
# 软件检测
# ============================================================================

# 检测单个软件是否已安装
check_software_installed() {
    local software="$1"
    local info="${SOFTWARE_LIST[$software]}"
    
    if [[ -z "$info" ]]; then
        return 1
    fi
    
    IFS='|' read -r name desc check_cmd _ _ _ <<< "$info"
    
    # 执行检查命令
    if eval "$check_cmd" &>/dev/null; then
        return 0
    fi
    
    return 1
}

# 获取软件版本
get_software_version() {
    local software="$1"
    local info="${SOFTWARE_LIST[$software]}"
    
    if [[ -z "$info" ]]; then
        echo "unknown"
        return
    fi
    
    IFS='|' read -r name desc check_cmd _ _ _ <<< "$info"
    
    # 执行检查命令并获取版本
    local version=$(eval "$check_cmd" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
    echo "${version:-unknown}"
}

# 检测所有软件状态
detect_all_software() {
    declare -gA SOFTWARE_STATUS=()
    declare -gA SOFTWARE_VERSIONS=()
    
    for software in "${!SOFTWARE_LIST[@]}"; do
        if check_software_installed "$software"; then
            SOFTWARE_STATUS[$software]="installed"
            SOFTWARE_VERSIONS[$software]=$(get_software_version "$software")
        else
            SOFTWARE_STATUS[$software]="not_installed"
            SOFTWARE_VERSIONS[$software]=""
        fi
    done
}

# ============================================================================
# 软件安装
# ============================================================================

# 获取包管理器
get_package_manager() {
    if command_exists apt-get; then
        echo "apt"
    elif command_exists dnf; then
        echo "dnf"
    elif command_exists yum; then
        echo "yum"
    elif command_exists pacman; then
        echo "pacman"
    elif command_exists brew; then
        echo "brew"
    else
        echo "unknown"
    fi
}

# 安装单个软件
install_software() {
    local software="$1"
    local info="${SOFTWARE_LIST[$software]}"
    
    if [[ -z "$info" ]]; then
        log_error "未知软件: $software"
        return 1
    fi
    
    IFS='|' read -r name desc check_cmd install_apt install_dnf install_brew <<< "$info"
    
    local pkg_manager=$(get_package_manager)
    local package=""
    
    case "$pkg_manager" in
        apt)
            package="$install_apt"
            ;;
        dnf|yum)
            package="$install_dnf"
            ;;
        brew)
            package="$install_brew"
            ;;
        pacman)
            package="$install_apt"  # 通常与 apt 包名相同
            ;;
        *)
            log_error "不支持的包管理器"
            return 1
            ;;
    esac
    
    # 特殊处理 Node.js
    if [[ "$software" == "nodejs" ]]; then
        install_nodejs
        return $?
    fi
    
    # 安装
    ui_spinner_start "正在安装 $name..."
    
    case "$pkg_manager" in
        apt)
            sudo apt-get install -y "$package" >> "$LOG_FILE" 2>&1
            ;;
        dnf)
            sudo dnf install -y "$package" >> "$LOG_FILE" 2>&1
            ;;
        yum)
            sudo yum install -y "$package" >> "$LOG_FILE" 2>&1
            ;;
        pacman)
            sudo pacman -Sy --noconfirm "$package" >> "$LOG_FILE" 2>&1
            ;;
        brew)
            brew install "$package" >> "$LOG_FILE" 2>&1
            ;;
    esac
    
    if check_software_installed "$software"; then
        ui_spinner_success "$name 安装成功"
        return 0
    else
        ui_spinner_error "$name 安装失败"
        return 1
    fi
}

# 批量安装软件
install_software_batch() {
    local software_list=("$@")
    local total=${#software_list[@]}
    local current=0
    local failed=()
    
    echo ""
    log_step "开始安装 $total 个软件..."
    echo ""
    
    # 更新包管理器缓存
    local pkg_manager=$(get_package_manager)
    
    ui_spinner_start "更新软件源..."
    case "$pkg_manager" in
        apt)
            sudo apt-get update >> "$LOG_FILE" 2>&1
            ;;
        dnf)
            sudo dnf check-update >> "$LOG_FILE" 2>&1 || true
            ;;
        brew)
            brew update >> "$LOG_FILE" 2>&1
            ;;
    esac
    ui_spinner_success "软件源已更新"
    
    # 安装每个软件
    for software in "${software_list[@]}"; do
        ((current++))
        
        # 跳过已安装的
        if check_software_installed "$software"; then
            local info="${SOFTWARE_LIST[$software]}"
            IFS='|' read -r name _ _ _ _ _ <<< "$info"
            echo -e "  [${current}/${total}] $name ${S_DIM}(已安装，跳过)${C_RESET}"
            continue
        fi
        
        if ! install_software "$software"; then
            failed+=("$software")
        fi
    done
    
    echo ""
    
    if [[ ${#failed[@]} -eq 0 ]]; then
        log_success "所有软件安装完成"
    else
        log_warning "部分软件安装失败: ${failed[*]}"
    fi
    
    return ${#failed[@]}
}

# ============================================================================
# 软件管理界面
# ============================================================================

# 显示软件管理界面
show_software_manager() {
    ui_section_title "软件安装" "$EMOJI_PACKAGE"
    
    # 检测所有软件
    detect_all_software
    
    local pkg_manager=$(get_package_manager)
    echo -e "  ${S_DIM}检测到包管理器: $pkg_manager${C_RESET}"
    echo ""
    
    # 按分类显示软件
    local all_options=()
    local all_software=()
    local preselected=()
    local idx=0
    
    for category in "required" "recommended" "media" "dev"; do
        local category_name="${SOFTWARE_CATEGORIES[$category]}"
        echo -e "  ${S_BOLD}┌─ $category_name ─────────────────────────────────┐${C_RESET}"
        
        for software in "${!SOFTWARE_CATEGORY_MAP[@]}"; do
            if [[ "${SOFTWARE_CATEGORY_MAP[$software]}" == "$category" ]]; then
                local info="${SOFTWARE_LIST[$software]}"
                IFS='|' read -r name desc _ _ _ _ <<< "$info"
                
                local status_icon=""
                local status_text=""
                
                if [[ "${SOFTWARE_STATUS[$software]}" == "installed" ]]; then
                    status_icon="${C_SUCCESS}✓${C_RESET}"
                    status_text="${S_DIM}已安装${C_RESET}"
                else
                    status_icon="${S_DIM}○${C_RESET}"
                    status_text=""
                    
                    # 预选必需和推荐组件
                    if [[ "$category" == "required" ]] || [[ "$category" == "recommended" ]]; then
                        preselected+=($idx)
                    fi
                fi
                
                printf "  │ $status_icon %-20s %s\n" "$name" "$status_text"
                
                all_options+=("$name - $desc")
                all_software+=("$software")
                ((idx++))
            fi
        done
        
        echo -e "  ${S_BOLD}└─────────────────────────────────────────────────┘${C_RESET}"
        echo ""
    done
    
    # 选择要安装的软件
    echo -e "  ${S_BOLD}选择要安装的软件${C_RESET}"
    echo ""
    
    ui_multi_select "选择软件" "${all_options[@]}"
    
    if [[ ${#SELECTED_ITEMS[@]} -eq 0 ]]; then
        log_info "未选择任何软件"
        return 0
    fi
    
    # 获取选中的软件列表
    local to_install=()
    for idx in "${SELECTED_ITEMS[@]}"; do
        to_install+=("${all_software[$idx]}")
    done
    
    # 确认安装
    echo ""
    echo -e "  将安装 ${#to_install[@]} 个软件"
    
    if ! ui_confirm "开始安装?" "y"; then
        return 0
    fi
    
    # 执行安装
    install_software_batch "${to_install[@]}"
}

# 快速安装必需组件
install_required_software() {
    log_step "安装必需组件..."
    
    local required=()
    
    for software in "${!SOFTWARE_CATEGORY_MAP[@]}"; do
        if [[ "${SOFTWARE_CATEGORY_MAP[$software]}" == "required" ]]; then
            if ! check_software_installed "$software"; then
                required+=("$software")
            fi
        fi
    done
    
    if [[ ${#required[@]} -eq 0 ]]; then
        log_success "所有必需组件已安装"
        return 0
    fi
    
    install_software_batch "${required[@]}"
}

# 快速安装推荐组件
install_recommended_software() {
    log_step "安装推荐组件..."
    
    local recommended=()
    
    for software in "${!SOFTWARE_CATEGORY_MAP[@]}"; do
        local cat="${SOFTWARE_CATEGORY_MAP[$software]}"
        if [[ "$cat" == "required" ]] || [[ "$cat" == "recommended" ]]; then
            if ! check_software_installed "$software"; then
                recommended+=("$software")
            fi
        fi
    done
    
    if [[ ${#recommended[@]} -eq 0 ]]; then
        log_success "所有推荐组件已安装"
        return 0
    fi
    
    install_software_batch "${recommended[@]}"
}

# ============================================================================
# 导出
# ============================================================================

export -f check_software_installed get_software_version detect_all_software
export -f get_package_manager install_software install_software_batch
export -f show_software_manager install_required_software install_recommended_software
