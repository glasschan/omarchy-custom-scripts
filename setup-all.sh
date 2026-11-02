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
# Script Registry
# ========================================
# Structured data, built exactly once per run in init_script_registry():
#   ALL_SCRIPTS   — discovered scripts, discovery order (install/uninstall-all,
#                   status, usage iterate this)
#   CATEGORY_ORDER — unique categories in display order (menu grouping)
#   MENU_NUMS / MENU_SCRIPTS / MENU_MODES / MENU_CATEGORIES / MENU_DESCS —
#                   parallel arrays, one entry per menu option: all install
#                   entries first, then all uninstall entries
#   MENU_INSTALL_COUNT — highest install option number
# No function re-derives the menu; they all read these arrays.
ALL_SCRIPTS=()
CATEGORY_ORDER=()
MENU_NUMS=()
MENU_SCRIPTS=()
MENU_MODES=()
MENU_CATEGORIES=()
MENU_DESCS=()
MENU_INSTALL_COUNT=0

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

# Discover all scripts by their declared metadata: any setup-*.sh / fix-*.sh
# in the repo root that carries BOTH "# Category:" and "# Description:"
# headers is discoverable. Scripts opt out of the menu with a "# Hidden: yes"
# header. Adding a new script with the headers is enough to appear in the menu,
# status list, and install/uninstall-all — no registration needed.

# A script is hidden from the menu when its "# Hidden:" header is yes/true/1
is_script_hidden() {
    local script="$1" hidden
    hidden=$(get_script_metadata "$script" "Hidden")
    [[ "$hidden" =~ ^[Yy]es$|^[Tt]rue$|^1$ ]]
}

# Fill ALL_SCRIPTS with every discoverable script, in discovery order
discover_scripts() {
    ALL_SCRIPTS=()
    local script script_base
    for script in "$SCRIPT_DIR"/setup-*.sh "$SCRIPT_DIR"/fix-*.sh; do
        [[ -f "$script" ]] || continue
        script_base=$(basename "$script")
        # Never discover the orchestrator itself
        [[ "$script_base" == "$SCRIPT_NAME" ]] && continue
        # Metadata headers are mandatory: no headers, no menu entry
        [[ -n "$(get_script_metadata "$script_base" "Category")" ]] || continue
        [[ -n "$(get_script_metadata "$script_base" "Description")" ]] || continue
        # "# Hidden: yes" keeps a script out of the menu/status
        is_script_hidden "$script_base" && continue
        ALL_SCRIPTS+=("$script_base")
    done
}

# Fill CATEGORY_ORDER with the unique categories of ALL_SCRIPTS, sorted by
# logical order (most frequently used first), unknown categories appended
group_scripts_by_category() {
    local seen=() script category cat
    for script in "${ALL_SCRIPTS[@]}"; do
        category=$(get_script_category "$script")
        if [[ " ${seen[*]} " != *" $category "* ]]; then
            seen+=("$category")
        fi
    done

    CATEGORY_ORDER=()
    for cat in "系統設定" "輸入法" "鍵盤" "快捷鍵" "遊戲相容" "容器工具" "修復工具" "Other"; do
        if [[ " ${seen[*]} " == *" $cat "* ]]; then
            CATEGORY_ORDER+=("$cat")
        fi
    done
    # Add any remaining categories
    for cat in "${seen[@]}"; do
        if [[ " ${CATEGORY_ORDER[*]} " != *" $cat "* ]]; then
            CATEGORY_ORDER+=("$cat")
        fi
    done
}

# Fill the MENU_* parallel arrays with the numbered menu options.
# Install entries first (category order, discovery order within a category),
# then uninstall entries in the same order.
build_menu_options() {
    MENU_NUMS=()
    MENU_SCRIPTS=()
    MENU_MODES=()
    MENU_CATEGORIES=()
    MENU_DESCS=()

    group_scripts_by_category

    local num=1 category script desc

    # Install options
    for category in "${CATEGORY_ORDER[@]}"; do
        for script in "${ALL_SCRIPTS[@]}"; do
            [[ "$(get_script_category "$script")" == "$category" ]] || continue
            desc=$(get_script_description "$script")
            MENU_NUMS+=("$num")
            MENU_SCRIPTS+=("$script")
            MENU_MODES+=("install")
            MENU_CATEGORIES+=("$category")
            MENU_DESCS+=("$desc")
            ((num++))
        done
    done
    MENU_INSTALL_COUNT=$((num - 1))

    # Uninstall options
    for category in "${CATEGORY_ORDER[@]}"; do
        for script in "${ALL_SCRIPTS[@]}"; do
            [[ "$(get_script_category "$script")" == "$category" ]] || continue
            desc=$(get_script_description "$script")
            MENU_NUMS+=("$num")
            MENU_SCRIPTS+=("$script")
            MENU_MODES+=("uninstall")
            MENU_CATEGORIES+=("$category")
            MENU_DESCS+=("$desc")
            ((num++))
        done
    done
}

# Build the whole registry once per run; every mode reads from these arrays
init_script_registry() {
    discover_scripts
    build_menu_options
}

# ========================================
# Menu Display
# ========================================

show_menu() {
    header "Glass Omarchy 自訂工具箱"
    echo ""

    local i last_category=""
    for i in "${!MENU_MODES[@]}"; do
        [[ "${MENU_MODES[i]}" == "install" ]] || continue
        if [[ "$last_category" != "${MENU_CATEGORIES[i]}" ]]; then
            echo ""
            echo -e "\033[1;34m▼ ${MENU_CATEGORIES[i]}\033[0m"
            last_category="${MENU_CATEGORIES[i]}"
        fi
        echo -e "  \033[0;32m${MENU_NUMS[i]}\033[0m. ${MENU_DESCS[i]}"
    done

    echo ""
    echo -e "\033[1;34m▼ 還原設定\033[0m"
    for i in "${!MENU_MODES[@]}"; do
        [[ "${MENU_MODES[i]}" == "uninstall" ]] || continue
        echo -e "  \033[0;32m${MENU_NUMS[i]}\033[0m. 還原 ${MENU_DESCS[i]}"
    done

    echo ""
    echo -e "\033[1;34m▼ 全域動作\033[0m"
    local global_start=$((MENU_INSTALL_COUNT * 2 + 1))
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
    fi

    info "執行 $script..."
    bash "$SCRIPT_DIR/$script" $mode
}

# Install all scripts
install_all() {
    header "安裝所有設定"

    local script first=true

    for script in "${ALL_SCRIPTS[@]}"; do
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

    if ! confirm "確定要還原所有設定嗎？"; then
        info "取消還原"
        return 0
    fi

    local script first=true

    for script in "${ALL_SCRIPTS[@]}"; do
        $first || echo ""
        first=false
        run_script "$script" "-u"
    done

    echo ""
    header "所有設定已還原！"
}

# Probe whether a script actually supports a status mode: run its usage
# output and look for an -s/--status option line. Never grep the script's
# source text — literals like "-s" in echo strings would false-positive.
script_supports_status() {
    local script="$1"
    bash "$SCRIPT_DIR/$script" -h 2>/dev/null | grep -Eq -- '^[[:space:]]*-s([,|[:space:]]|--status)'
}

# Show status for all scripts
show_status() {
    header "設定狀態"
    echo ""

    local script
    for script in "${ALL_SCRIPTS[@]}"; do
        if script_supports_status "$script"; then
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
    echo "$MENU_INSTALL_COUNT"
}

# Resolve a menu choice number against the registry. On match, sets
# CHOICE_SCRIPT and CHOICE_MODE and returns 0; returns 1 when unknown.
get_script_by_choice() {
    local choice="$1"
    local i
    for i in "${!MENU_NUMS[@]}"; do
        if [[ "${MENU_NUMS[i]}" == "$choice" ]]; then
            CHOICE_SCRIPT="${MENU_SCRIPTS[i]}"
            CHOICE_MODE="${MENU_MODES[i]}"
            return 0
        fi
    done
    return 1
}

interactive_mode() {
    while true; do
        show_menu
        local max_install_num
        max_install_num=$(get_max_install_num)
        local global_start=$((max_install_num * 2 + 1))
        local choice
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
                if get_script_by_choice "$choice"; then
                    local mode_flag="-i"
                    [[ "$CHOICE_MODE" == "uninstall" ]] && mode_flag="-u"
                    run_script "$CHOICE_SCRIPT" "$mode_flag"
                    read -p "按 Enter 繼續..."
                else
                    error "無效選項: $choice"
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
    local script desc
    for script in "${ALL_SCRIPTS[@]}"; do
        desc=$(get_script_description "$script")
        echo "  ./$script - $desc"
    done
}

# ========================================
# Main
# ========================================

main() {
    init_script_registry
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
            ;;
    esac
}

main "$@"
