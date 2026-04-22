#!/bin/bash

# setup-keyboard-swap.sh
# 交換 Laptop 內建鍵盤的 Super 和 Alt 鍵

set -e

SCRIPT_NAME="$(basename "$0")"
INPUT_CONF="$HOME/.config/hypr/input.conf"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

detail() {
    echo -e "${BLUE}[DETAIL]${NC} $1"
}

list_keyboards() {
    hyprctl devices 2>/dev/null | awk '
/^[[:space:]]*Keyboard at/ {
    device_line = $0
    getline
    gsub(/^[[:space:]]+|[[:space:]]+$/, "")
    name = $0
    is_builtin = 0
    lname = tolower(name)
    if (lname ~ /video-bus|power-button|hotkeys|virtual-keyboard/) {
        skip = 1
    }
    if (lname !~ /receiver|usb|bluetooth|wireless|logitech|microsoft|apple/) {
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

usage() {
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "Options:"
    echo "  -i, --install     安裝 Swap 設定 (預設)"
    echo "  -u, --uninstall   移除 Swap 設定"
    echo "  -h, --help        顯示此說明"
}

main() {
    case "${1:-}" in
        -u|--uninstall)
            uninstall
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