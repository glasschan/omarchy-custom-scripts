#!/bin/bash

# setup-keyboard-swap.sh
# 交換 Laptop 內建鍵盤的 Super 和 Alt 鍵
# Category: 鍵盤
# Description: 交換內建鍵盤 Super/Alt 鍵

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared library
source "$SCRIPT_DIR/lib/common.sh"

INPUT_CONF="$HOME/.config/hypr/input.conf"

list_keyboards() {
    hyprctl devices 2>/dev/null | awk '
/Keyboard at/ {
    getline
    gsub(/^[[:space:]]+|[[:space:]]+$/, "")
    name = $0
    lname = tolower(name)

    # POSITIVE filter: only include devices with "key" or "keyboard"
    if (lname !~ /key|keyboard/) {
        next
    }

    # THEN exclude virtual/special devices (wmi-keys = function keys only)
    skip_patterns = "virtual-keyboard|virtual-device|fcitx|ydotool|wmi-keys"
    if (lname ~ skip_patterns) {
        next
    }

    # Detect built-in vs external
    is_builtin = 0
    external_patterns = "receiver|usb|bluetooth|wireless|logitech|microsoft|apple|keychron"
    if (lname !~ external_patterns) {
        is_builtin = 1
    }

    printf "%s|%d\n", name, is_builtin
}'
}

check_swap_configured() {
    if [[ ! -f "$INPUT_CONF" ]]; then
        return 1
    fi
    grep -q "altwin:swap_alt_win" "$INPUT_CONF"
}

get_swap_keyboard_name() {
    if [[ -f "$INPUT_CONF" ]]; then
        grep -A1 "device {" "$INPUT_CONF" | grep "name =" | sed 's/.*name = //;s/"//g'
    fi
}

install() {
    info "建議移除外接鍵盤，只保留內建鍵盤"
    echo ""

    local keyboards
    mapfile -t keyboard_lines < <(list_keyboards)

    if [[ ${#keyboard_lines[@]} -eq 0 ]]; then
        error "找不到任何鍵盤"
        return 1
    fi

    info "偵測到的鍵盤："
    local choices=()
    local builtin_idx=1
    local idx=1
    for line in "${keyboard_lines[@]}"; do
        local name is_builtin
        name="${line%|*}"
        is_builtin="${line##*|}"

        local label="外接鍵盤"
        if [[ "$is_builtin" == "1" ]]; then
            label="內建鍵盤"
            builtin_idx=$idx
        fi

        echo -e "  ${CYAN}$idx${NC}. $name (${label})"
        choices+=("$name")
        ((idx++))
    done
    echo ""

    local default_choice=$builtin_idx
    read -p "選擇鍵盤 [${default_choice}]: " choice
    choice="${choice:-$default_choice}"

    if [[ -z "$choice" || "$choice" -lt 1 || "$choice" -gt ${#choices[@]} ]]; then
        error "無效選擇: $choice"
        return 1
    fi

    local selected_kb="${choices[$((choice-1))]}"

    info "移除舊的 Swap 設定..."
    sed -i '/^device {/,/^}/d' "$INPUT_CONF"
    sed -i '/^$/d' "$INPUT_CONF"

    info "寫入鍵盤 Swap 設定..."

    cat >> "$INPUT_CONF" << EOF

device {
    name = $selected_kb
    kb_options = altwin:swap_alt_win
}
EOF

    detail "已寫入:"
    grep -A2 "altwin:swap_alt_win" "$INPUT_CONF" | tail -3

    if command -v hyprctl &>/dev/null; then
        hyprctl reload 2>/dev/null && info "Hyprland 設定已重新載入" || warn "請手動執行 hyprctl reload"
    fi

    info "完成！"
    info "Swap 之後："
    info "  - Alt 鍵 → 變成 Super 鍵（可拉選單）"
    info "  - Super 鍵 → 變成 Alt 鍵（可打 Ctrl+Alt+T）"
}

uninstall() {
    info "移除鍵盤 Swap 設定..."

    if [[ ! -f "$INPUT_CONF" ]]; then
        warn "input.conf 不存在"
        return 0
    fi

    if ! check_swap_configured; then
        info "Swap 設定不存在，跳過"
        return 0
    fi

    sed -i '/device {/,/^}/{/altwin:swap_alt_win/d}' "$INPUT_CONF"
    sed -i '/^$/d' "$INPUT_CONF"

    if command -v hyprctl &>/dev/null; then
        hyprctl reload 2>/dev/null && info "Hyprland 設定已重新載入" || warn "請手動執行 hyprctl reload"
    fi

    info "已移除 Swap 設定"
}

# 顯示狀態
show_status() {
    echo -e "${CYAN}鍵盤 Swap 設定狀態:${NC}"

    if check_swap_configured; then
        echo -e "  ${GREEN}✓${NC} Super/Alt Swap 已設定"
        local kb_name=$(get_swap_keyboard_name)
        echo -e "  已設定的鍵盤: $kb_name"
    else
        echo -e "  ${YELLOW}!${NC} Super/Alt Swap 未設定"
    fi
}

usage() {
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "Options:"
    echo "  -i, --install     安裝 Swap 設定 (預設)"
    echo "  -u, --uninstall   移除 Swap 設定"
    echo "  -s, --status      顯示目前狀態"
    echo "  -h, --help        顯示此說明"
}

main() {
    case "${1:-}" in
        -u|--uninstall)
            uninstall
            ;;
        -s|--status)
            show_status
            ;;
        -h|--help)
            usage
            ;;
        -i|--install|"")
            install
            ;;
        *)
            error "未知選項: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"