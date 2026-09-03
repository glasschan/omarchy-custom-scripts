#!/bin/bash

# setup-keybindings.sh
# 設定自訂快捷鍵 - 剪貼簿管理 (Omarchy v4 Lua 設定)
# - CTRL + `: 開啟剪貼簿管理員 (Omarchy v4 內建)
# 截圖/錄影/OCR/取色快捷鍵已由 OmaSwiss plugin 嘅 Quick capture 取代 (2026-09 移除)
# 以 marker 區塊附加到 ~/.config/hypr/bindings.lua，唔會重寫整個檔案
# Category: 快捷鍵
# Description: 設定剪貼簿管理員快捷鍵
# Device: both

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared library
source "$SCRIPT_DIR/lib/common.sh"

BINDINGS_LUA="$HOME/.config/hypr/bindings.lua"

BEGIN_MARKER="-- BEGIN custom keybindings (setup-keybindings.sh)"
END_MARKER="-- END custom keybindings (setup-keybindings.sh)"

# 檢查是否已安裝
is_installed() {
    [[ -f "$BINDINGS_LUA" ]] && grep -qF -- "$BEGIN_MARKER" "$BINDINGS_LUA"
}

# 移除區塊（區塊永遠附加在檔尾：由 BEGIN 行起刪到 EOF）
strip_block() {
    local first_line
    first_line=$(grep -n -F -- "$BEGIN_MARKER" "$BINDINGS_LUA" | cut -d: -f1 | head -1)
    [[ -z "$first_line" ]] && return 0

    local cut_line=$first_line
    if (( cut_line > 1 )) && [[ -z "$(sed -n "$((cut_line - 1))p" "$BINDINGS_LUA")" ]]; then
        cut_line=$((cut_line - 1))
    fi
    sed -i "${cut_line},\$d" "$BINDINGS_LUA"
}

# 新增自訂快捷鍵到 hyprland (v4 Lua)
setup_hypr_keybindings() {
    info "附加自訂快捷鍵到 ~/.config/hypr/bindings.lua..."

    if is_installed; then
        info "自訂快捷鍵已存在，無需重複新增"
        return
    fi

    mkdir -p "$(dirname "$BINDINGS_LUA")"
    create_backup "$BINDINGS_LUA"

    cat >>"$BINDINGS_LUA" <<'EOF'

-- BEGIN custom keybindings (setup-keybindings.sh)
-- Clipboard manager (Omarchy v4 內建剪貼簿，取代 v3 walker + elephant；
-- 另有 Omarchy 預設 SUPER+CTRL+V)
o.bind("CTRL + grave", "Clipboard manager", "omarchy-shell shell toggle omarchy.clipboard")
-- END custom keybindings (setup-keybindings.sh)
EOF

    info "快捷鍵已附加至 $BINDINGS_LUA"
    info "Hyprland 會自動重新載入設定"
}

# 還原設定
uninstall() {
    info "還原自訂快捷鍵設定..."

    if [ ! -f "$BINDINGS_LUA" ]; then
        warn "找不到 $BINDINGS_LUA"
        return 0
    fi

    if is_installed; then
        strip_block
        info "已從 $BINDINGS_LUA 移除自訂快捷鍵"
    else
        info "沒有找到已加入的自訂快捷鍵，跳過"
    fi

    echo
    info "還原完成！"
    echo
}

# 顯示狀態
show_status() {
    echo -e "${CYAN}自訂快捷鍵設定狀態:${NC}"

    if [[ -f "$BINDINGS_LUA" ]]; then
        if is_installed; then
            echo -e "  ${GREEN}✓${NC} 自訂快捷鍵已安裝"
        else
            echo -e "  ${RED}✗${NC} 自訂快捷鍵未安裝"
        fi
    else
        echo -e "  ${YELLOW}!${NC} bindings.lua 不存在"
    fi
}

# 使用說明
usage() {
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "Options:"
    echo "  -i, --install     安裝設定 (預設)"
    echo "  -u, --uninstall   還原設定"
    echo "  -s, --status      顯示目前狀態"
    echo "  -h, --help        顯示此說明"
    echo ""
}

# 安裝模式
install() {
    info "開始設定自訂快捷鍵..."

    setup_hypr_keybindings

    echo
    info "=============================="
    info "設定完成!"
    info "=============================="
    echo
    echo "新增的快捷鍵："
    echo '  CTRL + `           → 開啟剪貼簿管理員 (Omarchy v4 內建)'
    echo
    echo "剪貼簿管理員亦可用預設快捷鍵 SUPER+CTRL+V 開啟"
    echo
}

# 主程式
main() {
    case "${1:-}" in
        -u | --uninstall)
            uninstall
            ;;
        -s | --status)
            show_status
            ;;
        -h | --help)
            usage
            ;;
        -i | --install | "")
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
