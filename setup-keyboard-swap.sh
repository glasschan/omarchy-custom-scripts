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

find_builtin_keyboard() {
    local keyboards
    keyboards=$(hyprctl devices 2>/dev/null | grep "Keyboard at" | grep -oP '(?<=at ).*(?=:)')

    local builtin_kb=""
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        local lname="${name,,}"
        if [[ ! "$lname" =~ (receiver|usb|bluetooth|wireless|logitech|microsoft|apple) ]]; then
            builtin_kb="$name"
            break
        fi
    done <<< "$keyboards"

    echo "$builtin_kb"
}

check_swap_configured() {
    if [[ ! -f "$INPUT_CONF" ]]; then
        return 1
    fi
    grep -q "altwin:swap_alt_win" "$INPUT_CONF"
}

install() {
    info "請確保已移除所有外接鍵盤，只保留內建鍵盤"
    read -p "準備好後按 Enter 繼續..."

    local builtin_kb
    builtin_kb=$(find_builtin_keyboard)

    if [[ -z "$builtin_kb" ]]; then
        error "找不到內建鍵盤，請確認只有一個鍵盤連接"
        return 1
    fi

    info "找到內建鍵盤: $builtin_kb"

    local count
    count=$(echo "$builtin_kb" | grep -c .)
    if [[ $count -gt 1 ]]; then
        error "偵測到多個可能的內建鍵盤，請移除外接鍵盤後重試"
        return 1
    fi

    if check_swap_configured; then
        info "Swap 設定已存在，跳過"
        return 0
    fi

    info "寫入鍵盤 Swap 設定..."

    cat >> "$INPUT_CONF" << EOF

device {
    name = "$builtin_kb"
    kb_options = "altwin:swap_alt_win"
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
    sed -i '/^[[:space:]]*$/d' "$INPUT_CONF"

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