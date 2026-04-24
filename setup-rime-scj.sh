#!/bin/bash

# setup-rime-scj.sh - 相容性包裝指令碼
# 這個指令碼已被重構為 setup-fonts.sh + setup-input.sh 的包裝
# 保留向後相容性

# Category: Legacy
# Description: [Deprecated] Combined fonts + rime-scj setup

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared library
source "$SCRIPT_DIR/lib/common.sh"

warn "注意: setup-rime-scj.sh 已被重構為相容性包裝"
warn "請直接使用 setup-fonts.sh 和 setup-input.sh"
echo ""

install() {
    info "透過子指令碼安裝字型與輸入法..."
    "$SCRIPT_DIR/setup-fonts.sh" -i
    "$SCRIPT_DIR/setup-input.sh" -i
}

uninstall() {
    info "透過子指令碼還原設定..."
    "$SCRIPT_DIR/setup-input.sh" -u
    "$SCRIPT_DIR/setup-fonts.sh" -u
}

show_status() {
    echo -e "${CYAN}setup-rime-scj 狀態 (透過子指令碼):${NC}"
    echo ""
    "$SCRIPT_DIR/setup-fonts.sh" -s
    echo ""
    "$SCRIPT_DIR/setup-input.sh" -s
}

usage() {
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "注意: 此為相容性包裝指令碼，已被重構為個別指令碼"
    echo ""
    echo "Options:"
    echo "  -i, --install     安裝字型與輸入法 (預設)"
    echo "  -u, --uninstall   還原字型與輸入法設定"
    echo "  -s, --status      顯示目前狀態"
    echo "  -h, --help        顯示此說明"
    echo ""
    echo "建議使用:"
    echo "  ./setup-fonts.sh   # 單獨設定字型"
    echo "  ./setup-input.sh   # 單獨設定輸入法"
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
