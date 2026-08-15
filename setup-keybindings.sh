#!/bin/bash

# setup-keybindings.sh
# 設定自訂快捷鍵 - 截圖、錄影、剪貼簿管理 (Omarchy v4 Lua 設定)
# - ALT SHIFT + Q: 區域截圖
# - ALT SHIFT + E: 視窗截圖
# - ALT SHIFT + F: 全螢幕截圖
# - ALT SHIFT + R: 螢幕錄影
# - ALT SHIFT CTRL + R: 螢幕錄影 (含攝影機)
# - ALT SHIFT + A: 顏色選擇器
# - ALT SHIFT + O: OCR 文字辨識
# - CTRL + `: 開啟剪貼簿管理員 (Omarchy v4 內建)
# 以 marker 區塊附加到 ~/.config/hypr/bindings.lua，唔會重寫整個檔案
# Category: 快捷鍵
# Description: 設定截圖/錄影/剪貼簿快捷鍵

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared library
source "$SCRIPT_DIR/lib/common.sh"

BINDINGS_LUA="$HOME/.config/hypr/bindings.lua"

BEGIN_MARKER="-- BEGIN custom keybindings (setup-keybindings.sh)"
END_MARKER="-- END custom keybindings (setup-keybindings.sh)"

# 檢查依賴
check_dependencies() {
    info "檢查依賴..."

    if ! command -v omarchy-capture-screenshot &>/dev/null; then
        error "omarchy-capture-screenshot 未安裝（需要 Omarchy v4）"
        exit 1
    fi

    if ! tesseract --list-langs 2>/dev/null | grep -q "chi_tra"; then
        error "tesseract-data-chi_tra 未安裝，請先安裝以使用 OCR 功能"
        exit 1
    fi

    info "依賴檢查完成"
}

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
-- 截圖（v4 預設 PRINT 已有截圖；以下係 ALT SHIFT 組合鍵）
o.bind("ALT + SHIFT + Q", "Screenshot (region)", "omarchy-capture-screenshot region")
o.bind("ALT + SHIFT + E", "Screenshot (window)", "omarchy-capture-screenshot windows")
o.bind("ALT + SHIFT + F", "Screenshot (fullscreen)", "omarchy-capture-screenshot fullscreen")

-- Color picker
o.bind("ALT + SHIFT + A", "Color picker", "pkill hyprpicker || hyprpicker -a")

-- Screen recording
o.bind("ALT + SHIFT + R", "Screen recording", "omarchy-capture-screenrecording")
o.bind("ALT + SHIFT + CTRL + R", "Screen recording (with camera)", "omarchy-capture-screenrecording --with-webcam")

-- OCR text extraction (中英混合)
o.bind("ALT + SHIFT + O", "Extract text (OCR)", "env OMARCHY_OCR_LANGS=eng+chi_tra omarchy-capture-text")

-- Clipboard manager (Omarchy v4 內建剪貼簿，取代 v3 walker + elephant)
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

    check_dependencies
    setup_hypr_keybindings

    echo
    info "=============================="
    info "設定完成!"
    info "=============================="
    echo
    echo "新增的快捷鍵："
    echo "  ALT SHIFT + Q      → 區域截圖"
    echo "  ALT SHIFT + E      → 視窗選取截圖"
    echo "  ALT SHIFT + F      → 全螢幕截圖"
    echo "  ALT SHIFT + R      → 開始螢幕錄影"
    echo "  ALT SHIFT CTRL + R → 開始螢幕錄影 (含攝影機)"
    echo "  ALT SHIFT + A      → 顏色選擇器"
    echo "  ALT SHIFT + O      → OCR 文字辨識 (中英混合)"
    echo '  CTRL + `           → 開啟剪貼簿管理員 (Omarchy 內建)'
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
