#!/bin/bash
# ============================================================================
# OpenClaw Deploy 2.0 - Skills Manager
# ============================================================================
# 技能管理模块，搜索、安装、管理 OpenClaw Skills
# ============================================================================

# 防止重复加载
[[ -n "$_SKILLS_LOADED" ]] && return 0
_SKILLS_LOADED=1

# ============================================================================
# 配置
# ============================================================================

# ClawHub API
CLAWHUB_API="https://clawhub.com/api"
CLAWHUB_URL="https://clawhub.com"

# 本地技能目录
SKILLS_DIR="$OPENCLAW_SKILLS"

# 热门技能缓存
POPULAR_SKILLS_CACHE="/tmp/openclaw_popular_skills.json"
CACHE_EXPIRY=3600  # 1 小时

# ============================================================================
# 技能检测
# ============================================================================

# 获取已安装的技能列表
get_installed_skills() {
    local cli_name="openclaw"
    [[ "$INSTALL_VERSION" == "chinese" ]] && cli_name="openclaw-cn"
    
    if command_exists "$cli_name"; then
        $cli_name skills list 2>/dev/null | grep -E '^\s*-' | sed 's/^\s*-\s*//'
    else
        # 直接扫描目录
        if [[ -d "$SKILLS_DIR" ]]; then
            find "$SKILLS_DIR" -name "SKILL.md" -exec dirname {} \; 2>/dev/null | xargs -I {} basename {}
        fi
    fi
}

# 检查技能是否已安装
is_skill_installed() {
    local skill_name="$1"
    local installed=$(get_installed_skills)
    
    echo "$installed" | grep -q "^${skill_name}$"
}

# 获取已安装技能数量
get_installed_skills_count() {
    get_installed_skills | wc -l | tr -d ' '
}

# ============================================================================
# 技能搜索
# ============================================================================

# 搜索技能（从 ClawHub）
search_skills() {
    local query="$1"
    local limit="${2:-10}"
    
    if ! check_network; then
        log_error "网络连接失败，无法搜索技能"
        return 1
    fi
    
    # 调用 ClawHub API
    local result=$(fetch_url "${CLAWHUB_API}/skills/search?q=${query}&limit=${limit}" 2>/dev/null)
    
    if [[ -z "$result" ]]; then
        log_error "搜索失败"
        return 1
    fi
    
    echo "$result"
}

# 获取热门技能
get_popular_skills() {
    local limit="${1:-20}"
    
    # 检查缓存
    if [[ -f "$POPULAR_SKILLS_CACHE" ]]; then
        local cache_age=$(($(date +%s) - $(stat -c %Y "$POPULAR_SKILLS_CACHE" 2>/dev/null || echo 0)))
        if [[ $cache_age -lt $CACHE_EXPIRY ]]; then
            cat "$POPULAR_SKILLS_CACHE"
            return 0
        fi
    fi
    
    # 从 API 获取
    if check_network; then
        local result=$(fetch_url "${CLAWHUB_API}/skills/popular?limit=${limit}" 2>/dev/null)
        if [[ -n "$result" ]]; then
            echo "$result" > "$POPULAR_SKILLS_CACHE"
            echo "$result"
            return 0
        fi
    fi
    
    # 返回内置的热门技能列表
    cat <<'EOF'
[
  {"name": "weather-forecast", "description": "获取天气预报", "downloads": 5000, "rating": 4.8},
  {"name": "web-search", "description": "网络搜索", "downloads": 4500, "rating": 4.7},
  {"name": "reminder", "description": "提醒和日程管理", "downloads": 4000, "rating": 4.6},
  {"name": "translator", "description": "多语言翻译", "downloads": 3500, "rating": 4.5},
  {"name": "calculator", "description": "数学计算", "downloads": 3000, "rating": 4.4},
  {"name": "note-taker", "description": "笔记记录", "downloads": 2800, "rating": 4.5},
  {"name": "image-gen", "description": "AI 图像生成", "downloads": 2500, "rating": 4.3},
  {"name": "code-helper", "description": "代码辅助", "downloads": 2200, "rating": 4.4},
  {"name": "news-reader", "description": "新闻阅读", "downloads": 2000, "rating": 4.2},
  {"name": "file-manager", "description": "文件管理", "downloads": 1800, "rating": 4.1}
]
EOF
}

# ============================================================================
# 技能安装
# ============================================================================

# 安装技能
install_skill() {
    local skill_name="$1"
    
    if is_skill_installed "$skill_name"; then
        log_warning "技能 '$skill_name' 已安装"
        return 0
    fi
    
    ui_spinner_start "正在安装技能 '$skill_name'..."
    
    # 使用 clawhub CLI 安装
    if command_exists clawhub; then
        if clawhub install "$skill_name" >> "$LOG_FILE" 2>&1; then
            ui_spinner_success "技能 '$skill_name' 安装成功"
            return 0
        fi
    fi
    
    # 使用 openclaw CLI 安装
    local cli_name="openclaw"
    [[ "$INSTALL_VERSION" == "chinese" ]] && cli_name="openclaw-cn"
    
    if command_exists "$cli_name"; then
        if $cli_name skills install "$skill_name" >> "$LOG_FILE" 2>&1; then
            ui_spinner_success "技能 '$skill_name' 安装成功"
            return 0
        fi
    fi
    
    ui_spinner_error "技能 '$skill_name' 安装失败"
    return 1
}

# 卸载技能
uninstall_skill() {
    local skill_name="$1"
    
    if ! is_skill_installed "$skill_name"; then
        log_warning "技能 '$skill_name' 未安装"
        return 0
    fi
    
    ui_spinner_start "正在卸载技能 '$skill_name'..."
    
    # 删除技能目录
    local skill_dir="$SKILLS_DIR/$skill_name"
    if [[ -d "$skill_dir" ]]; then
        rm -rf "$skill_dir"
        ui_spinner_success "技能 '$skill_name' 已卸载"
        return 0
    fi
    
    ui_spinner_error "技能 '$skill_name' 卸载失败"
    return 1
}

# 更新所有技能
update_all_skills() {
    ui_spinner_start "正在更新所有技能..."
    
    if command_exists clawhub; then
        if clawhub update --all >> "$LOG_FILE" 2>&1; then
            ui_spinner_success "所有技能已更新"
            return 0
        fi
    fi
    
    local cli_name="openclaw"
    [[ "$INSTALL_VERSION" == "chinese" ]] && cli_name="openclaw-cn"
    
    if command_exists "$cli_name"; then
        if $cli_name skills update >> "$LOG_FILE" 2>&1; then
            ui_spinner_success "所有技能已更新"
            return 0
        fi
    fi
    
    ui_spinner_error "技能更新失败"
    return 1
}

# ============================================================================
# 技能管理界面
# ============================================================================

# 显示技能管理主界面
show_skills_manager() {
    while true; do
        ui_section_title "技能管理" "$EMOJI_WRENCH"
        
        local installed_count=$(get_installed_skills_count)
        echo -e "  已安装技能: ${C_PRIMARY}${installed_count}${C_RESET} 个"
        echo ""
        
        local options=(
            "${EMOJI_SEARCH} 搜索技能 - 从 ClawHub 搜索并安装"
            "${EMOJI_PACKAGE} 已安装技能 - 查看和管理已安装的技能"
            "${EMOJI_STAR} 热门技能 - 浏览热门技能推荐"
            "${EMOJI_REFRESH} 更新所有技能 - 更新到最新版本"
            "← 返回主菜单"
        )
        
        ui_select "选择操作" "${options[@]}"
        local choice=$?
        
        case $choice in
            0) show_skill_search ;;
            1) show_installed_skills ;;
            2) show_popular_skills ;;
            3) update_all_skills ;;
            4|255) return 0 ;;
        esac
    done
}

# 显示技能搜索界面
show_skill_search() {
    echo ""
    local query=$(ui_input "搜索关键词" "")
    
    if [[ -z "$query" ]]; then
        return 0
    fi
    
    ui_spinner_start "正在搜索..."
    local results=$(search_skills "$query")
    ui_spinner_stop
    
    if [[ -z "$results" ]] || [[ "$results" == "[]" ]]; then
        log_info "未找到相关技能"
        ui_wait_key
        return 0
    fi
    
    # 解析结果并显示
    display_skill_results "$results"
}

# 显示已安装技能
show_installed_skills() {
    echo ""
    log_step "已安装的技能"
    echo ""
    
    local skills=$(get_installed_skills)
    
    if [[ -z "$skills" ]]; then
        log_info "尚未安装任何技能"
        ui_wait_key
        return 0
    fi
    
    local skill_array=()
    while IFS= read -r skill; do
        [[ -n "$skill" ]] && skill_array+=("$skill")
    done <<< "$skills"
    
    if [[ ${#skill_array[@]} -eq 0 ]]; then
        log_info "尚未安装任何技能"
        ui_wait_key
        return 0
    fi
    
    # 添加返回选项
    skill_array+=("← 返回")
    
    ui_select "选择技能查看详情或卸载" "${skill_array[@]}"
    local choice=$?
    
    if [[ $choice -eq $((${#skill_array[@]} - 1)) ]] || [[ $choice -eq 255 ]]; then
        return 0
    fi
    
    local selected_skill="${skill_array[$choice]}"
    show_skill_detail "$selected_skill" "installed"
}

# 显示热门技能
show_popular_skills() {
    ui_spinner_start "获取热门技能..."
    local popular=$(get_popular_skills)
    ui_spinner_stop
    
    display_skill_results "$popular"
}

# 显示技能搜索结果
display_skill_results() {
    local json_data="$1"
    
    # 解析 JSON（简单解析）
    local names=()
    local descriptions=()
    local ratings=()
    local downloads=()
    
    if command_exists jq; then
        while IFS= read -r line; do
            names+=("$line")
        done < <(echo "$json_data" | jq -r '.[].name' 2>/dev/null)
        
        while IFS= read -r line; do
            descriptions+=("$line")
        done < <(echo "$json_data" | jq -r '.[].description' 2>/dev/null)
        
        while IFS= read -r line; do
            ratings+=("$line")
        done < <(echo "$json_data" | jq -r '.[].rating' 2>/dev/null)
        
        while IFS= read -r line; do
            downloads+=("$line")
        done < <(echo "$json_data" | jq -r '.[].downloads' 2>/dev/null)
    else
        # 简单的 grep 解析
        while IFS= read -r line; do
            names+=("$line")
        done < <(echo "$json_data" | grep -oP '"name":\s*"\K[^"]+')
        
        while IFS= read -r line; do
            descriptions+=("$line")
        done < <(echo "$json_data" | grep -oP '"description":\s*"\K[^"]+')
    fi
    
    if [[ ${#names[@]} -eq 0 ]]; then
        log_info "没有找到技能"
        ui_wait_key
        return 0
    fi
    
    # 构建选项
    local options=()
    for i in "${!names[@]}"; do
        local name="${names[$i]}"
        local desc="${descriptions[$i]:-}"
        local rating="${ratings[$i]:-}"
        local dl="${downloads[$i]:-}"
        
        local installed_mark=""
        is_skill_installed "$name" && installed_mark=" ${C_SUCCESS}[已安装]${C_RESET}"
        
        local option="$name - $desc"
        [[ -n "$rating" ]] && option+=" ⭐$rating"
        [[ -n "$dl" ]] && option+=" 📥$dl"
        option+="$installed_mark"
        
        options+=("$option")
    done
    
    options+=("← 返回")
    
    echo ""
    ui_select "选择技能" "${options[@]}"
    local choice=$?
    
    if [[ $choice -eq $((${#options[@]} - 1)) ]] || [[ $choice -eq 255 ]]; then
        return 0
    fi
    
    local selected_skill="${names[$choice]}"
    show_skill_detail "$selected_skill" "search"
}

# 显示技能详情
show_skill_detail() {
    local skill_name="$1"
    local source="$2"  # installed / search
    
    echo ""
    ui_panel "技能详情: $skill_name" \
        "名称: $skill_name" \
        "来源: ClawHub" \
        "状态: $(is_skill_installed "$skill_name" && echo "已安装" || echo "未安装")"
    
    local options=()
    
    if is_skill_installed "$skill_name"; then
        options+=("卸载技能")
        options+=("查看源码")
    else
        options+=("安装技能")
        options+=("查看详情 (ClawHub)")
    fi
    
    options+=("← 返回")
    
    ui_select "操作" "${options[@]}"
    local choice=$?
    
    case $choice in
        0)
            if is_skill_installed "$skill_name"; then
                if ui_confirm "确认卸载技能 '$skill_name'?" "n"; then
                    uninstall_skill "$skill_name"
                fi
            else
                install_skill "$skill_name"
            fi
            ;;
        1)
            if is_skill_installed "$skill_name"; then
                # 查看源码
                local skill_file="$SKILLS_DIR/$skill_name/SKILL.md"
                if [[ -f "$skill_file" ]]; then
                    less "$skill_file" 2>/dev/null || cat "$skill_file"
                else
                    log_error "找不到技能文件"
                fi
            else
                # 打开 ClawHub 页面
                log_info "请访问: ${CLAWHUB_URL}/skills/$skill_name"
            fi
            ;;
    esac
    
    ui_wait_key
}

# ============================================================================
# 导出
# ============================================================================

export CLAWHUB_API CLAWHUB_URL SKILLS_DIR

export -f get_installed_skills is_skill_installed get_installed_skills_count
export -f search_skills get_popular_skills
export -f install_skill uninstall_skill update_all_skills
export -f show_skills_manager show_skill_search show_installed_skills show_popular_skills
export -f display_skill_results show_skill_detail
