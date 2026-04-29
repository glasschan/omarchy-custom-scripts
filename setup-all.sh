#!/bin/bash

# setup-all.sh
# 主程式：設定所有自訂設定 - macOS 風格 + 自訂快捷鍵
# Category: Main
# Description: Main orchestrator - runs all setup scripts

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared library
source "$SCRIPT_DIR/lib/common.sh"

# ========================================
# Script Discovery
# ========================================

# Extract metadata from a script
get_script_metadata() {
    local script="$1"
    local key="$2"
    grep -E "^# $key:" "$SCRIPT_DIR/$script" | sed -E "s/^# $key:[[:space:]]*(.*)$/\1/" | head -1
}

# Get script category
get_script_category() {
    local script="$1"
    local category
    category=$(get_script_metadata "$script" "Category")
    echo "${category:-Other}"
}

# Get script description
get_script_description() {
    local script="$1"
    local desc
    desc=$(get_script_metadata "$script" "Description")
    if [[ -z "$desc" ]]; then
        # Fallback to second line comment
        desc=$(sed -n '2p' "$SCRIPT_DIR/$script" | sed -E 's/^# //')
    fi
    echo "${desc:-$script}"
}

# Discover all setup scripts (exclude setup-all.sh itself and setup-rime-scj.sh)
discover_scripts() {
    local scripts=()
    for script in "$SCRIPT_DIR"/setup-*.sh; do
        local basename=$(basename "$script")
        [[ "$basename" == "setup-all.sh" ]] && continue
        [[ "$basename" == "setup-rime-scj.sh" ]] && continue
        scripts+=("$basename")
    done
    # Add standalone scripts
    for script in "$SCRIPT_DIR"/fix-chrome-keyring.sh "$SCRIPT_DIR"/fix-spotify-scale.sh; do
        [[ -f "$script" ]] && scripts+=("$(basename "$script")")
    done
    echo "${scripts[@]}"
}

# Group scripts by category
group_scripts_by_category() {
    local scripts=($(discover_scripts))
    local categories=()

    # First pass: get all unique categories
    for script in "${scripts[@]}"; do
        local category=$(get_script_category "$script")
        if ! [[ " ${categories[@]} " =~ " $category " ]]; then
            categories+=("$category")
        fi
    done

    # Sort categories by logical order (most frequently used first)
    local sorted=()
    for cat in "系統設定" "輸入法" "鍵盤" "快捷鍵" "遊戲相容" "容器工具" "修復工具" "Other"; do
        if [[ " ${categories[@]} " =~ " $cat " ]]; then
            sorted+=("$cat")
        fi
    done
    # Add any remaining categories
    for cat in "${categories[@]}"; do
        if ! [[ " ${sorted[@]} " =~ " $cat " ]]; then
            sorted+=("$cat")
        fi
    done

    echo "${sorted[@]}"
}

# Get scripts in a category
get_scripts_in_category() {
    local category="$1"
    local scripts=($(discover_scripts))
    local result=()

    for script in "${scripts[@]}"; do
        local script_cat=$(get_script_category "$script")
        if [[ "$script_cat" == "$category" ]]; then
            result+=("$script")
        fi
    done
    echo "${result[@]}"
}

# ========================================
# Menu Generation
# ========================================

# Build a flat list of script options with their numbers
# Returns each option on a separate line: "number|script|mode|category|description"
build_menu_options() {
    local categories=($(group_scripts_by_category))
    local num=1

    # Install options
    for category in "${categories[@]}"; do
        local scripts=($(get_scripts_in_category "$category"))
        for script in "${scripts[@]}"; do
            local desc=$(get_script_description "$script")
            echo "${num}|${script}|install|$category|$desc"
            ((num++))
        done
    done

    # Uninstall options
    for category in "${categories[@]}"; do
        local scripts=($(get_scripts_in_category "$category"))
        for script in "${scripts[@]}"; do
            local desc=$(get_script_description "$script")
            echo "${num}|${script}|uninstall|$category|$desc"
            ((num++))
        done
    done
}

# ========================================
# Menu Display
# ========================================

show_menu() {
    header "Glass Omarchy 自訂工具箱"
    echo ""

    local max_install_num=0

    # Install section - group by category
    local last_category=""
    while IFS='|' read -r num script mode category desc; do
        if [[ "$mode" == "install" ]]; then
            if [[ "$last_category" != "$category" ]]; then
                echo ""
                echo -e "\033[1;34m▼ $category\033[0m"
                last_category="$category"
            fi
            echo -e "  \033[0;32m$num\033[0m. $desc"
            max_install_num=$num
        fi
    done < <(build_menu_options)

    echo ""
    echo -e "\033[1;34m▼ 還原設定\033[0m"
    while IFS='|' read -r num script mode category desc; do
        if [[ "$mode" == "uninstall" ]]; then
            echo -e "  \033[0;32m$num\033[0m. 還原 $desc"
        fi
    done < <(build_menu_options)

    echo ""
    echo -e "\033[1;34m▼ 全域動作\033[0m"
    local global_start=$((max_install_num * 2 + 1))
    echo -e "  \033[0;32m$global_start\033[0m. 安裝所有設定"
    echo -e "  \033[0;32m$((global_start + 1))\033[0m. 還原所有設定"
    echo -e "  \033[0;32m$((global_start + 2))\033[0m. 顯示所有設定狀態"
    echo -e "  \033[0;32m0\033[0m. 離開"
    echo ""
}

# ========================================
# Actions
# ========================================

# Execute a single script
run_script() {
    local script="$1"
    local mode="${2:-}"

    if [[ ! -f "$SCRIPT_DIR/$script" ]]; then
        error "找不到 script: $script"
        return 1
    fi

    info "執行 $script..."
    bash "$SCRIPT_DIR/$script" $mode
}

# Install all scripts
install_all() {
    header "安裝所有設定"

    local scripts=($(discover_scripts))
    local first=true

    for script in "${scripts[@]}"; do
        $first || echo ""
        first=false
        run_script "$script" "-i"
    done

    echo ""
    header "所有設定安裝完成！"
    echo ""
    echo "請重新登入以確保所有設定生效。"
}

# Uninstall all scripts
uninstall_all() {
    header "還原所有設定"

    read -p "確定要還原所有設定嗎？ (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "取消還原"
        return 0
    fi

    local scripts=($(discover_scripts))
    local first=true

    for script in "${scripts[@]}"; do
        $first || echo ""
        first=false
        run_script "$script" "-u"
    done

    echo ""
    header "所有設定已還原！"
}

# Show status for all scripts
show_status() {
    header "設定狀態"
    echo ""

    local scripts=($(discover_scripts))
    for script in "${scripts[@]}"; do
        # Check if script supports -s
        if grep -q "\-\-status" "$SCRIPT_DIR/$script" || grep -q "-s\|--status" "$SCRIPT_DIR/$script" | head -1 | grep -q status; then
            "$SCRIPT_DIR/$script" -s
            echo ""
        fi
    done
}

# ========================================
# Interactive Mode
# ========================================

# Get max install number
get_max_install_num() {
    local max=0
    while IFS='|' read -r num script mode category desc; do
        [[ "$mode" == "install" ]] && max=$num
    done < <(build_menu_options)
    echo $max
}

# Get script info by choice number
get_script_by_choice() {
    local choice="$1"
    while IFS='|' read -r num script mode category desc; do
        if [[ "$num" == "$choice" ]]; then
            echo "$script|$mode"
            return 0
        fi
    done < <(build_menu_options)
    return 1
}

interactive_mode() {
    while true; do
        show_menu
        local max_install_num=$(get_max_install_num)
        local global_start=$((max_install_num * 2 + 1))
        read -p "請選擇 [0-$((global_start + 2))]: " choice

        case "$choice" in
            0)
                info "再見！"
                exit 0
                ;;
            $global_start)
                install_all
                read -p "按 Enter 繼續..."
                ;;
            $((global_start + 1)))
                uninstall_all
                read -p "按 Enter 繼續..."
                ;;
            $((global_start + 2)))
                show_status
                read -p "按 Enter 繼續..."
                ;;
            *)
                # Find the matching option
                local result=$(get_script_by_choice "$choice")
                if [[ -n "$result" ]]; then
                    local script mode
                    IFS='|' read -r script mode <<< "$result"
                    local mode_flag="-i"
                    [[ "$mode" == "uninstall" ]] && mode_flag="-u"
                    run_script "$script" "$mode_flag"
                    read -p "按 Enter 繼續..."
                else
                    error "無效選項: $choice"
                    sleep 1
                fi
                ;;
        esac
        echo ""
    done
}

# ========================================
# Usage
# ========================================

usage() {
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "Options:"
    echo "  -i, --install     安裝所有設定"
    echo "  -u, --uninstall   還原所有設定"
    echo "  -s, --status      顯示設定狀態"
    echo "  -m, --menu        互動選單模式 (預設)"
    echo "  -h, --help        顯示此說明"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME              # 進入互動選單"
    echo "  $SCRIPT_NAME -i           # 安裝所有設定"
    echo "  $SCRIPT_NAME -u           # 還原所有設定"
    echo ""
    echo "可用的獨立指令碼:"
    local scripts=($(discover_scripts))
    for script in "${scripts[@]}"; do
        local desc=$(get_script_description "$script")
        echo "  ./$script - $desc"
    done
}

# ========================================
# Main
# ========================================

main() {
    case "${1:-}" in
        -u|--uninstall)
            uninstall_all
            ;;
        -s|--status)
            show_status
            ;;
        -m|--menu|"")
            interactive_mode
            ;;
        -h|--help)
            usage
            ;;
        -i|--install)
            install_all
            ;;
        *)
            error "未知選項: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"
