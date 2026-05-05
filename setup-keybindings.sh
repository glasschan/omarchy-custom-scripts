#!/bin/bash

# setup-keybindings.sh
# 設定自訂快捷鍵 - 截圖、錄影、剪貼簿管理
# - ALT SHIFT + Q: 區域截圖
# - ALT SHIFT + E: 視窗截圖
# - ALT SHIFT + F: 全螢幕截圖
# - ALT SHIFT + R: 螢幕錄影
# - ALT SHIFT CTRL + R: 螢幕錄影 (含攝影機)
# - ALT SHIFT + A: 顏色選擇器
# - ALT SHIFT + O: OCR 文字辨識
# - CTRL + `: 開啟 elephant 剪貼簿管理員
# Category: 快捷鍵
# Description: 設定截圖/錄影/剪貼簿快捷鍵

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared library
source "$SCRIPT_DIR/lib/common.sh"

# 檢查依賴
check_dependencies() {
    info "檢查依賴..."

    if ! command -v elephant &> /dev/null; then
        error "elephant 未安裝，請先安裝 elephant-clipboard"
        exit 1
    fi

    if ! tesseract --list-langs 2>/dev/null | grep -q "chi_tra"; then
        error "tesseract-data-chi_tra 未安裝，請先安裝以使用 OCR 功能"
        exit 1
    fi

    info "依賴檢查完成"
}

# 設定 elephant 剪貼簿自動貼上
setup_elephant_clipboard() {
    info "設定 elephant 剪貼簿自動貼上..."

    ELEPHANT_CONFIG_DIR="$HOME/.config/elephant"
    CLIPBOARD_CONFIG="$ELEPHANT_CONFIG_DIR/clipboard.toml"

    mkdir -p "$ELEPHANT_CONFIG_DIR"

    if [ ! -f "$CLIPBOARD_CONFIG" ]; then
        info "建立新的 clipboard.toml..."
cat > "$CLIPBOARD_CONFIG" << 'EOF'
auto_cleanup = 0
command = 'wl-copy && hyprctl dispatch sendshortcut "SHIFT, Insert,"'
ignore_symbols = true
image_editor_cmd = ''
max_items = 100
pinned_on_top = true
text_editor_cmd = ''
EOF
    else
        info "更新現有 clipboard.toml..."
        if grep -Eq '^command\s*=' "$CLIPBOARD_CONFIG"; then
            sed -i 's/^command\s*=.*$/command = '"'"'wl-copy \&\& hyprctl dispatch sendshortcut "SHIFT, Insert,"'"'"'/' "$CLIPBOARD_CONFIG"
        else
            echo 'command = '"'"'wl-copy && hyprctl dispatch sendshortcut "SHIFT, Insert,"'"'"'' >> "$CLIPBOARD_CONFIG"
        fi
        if grep -Eq '^pinned_on_top\s*=' "$CLIPBOARD_CONFIG"; then
            sed -i 's/^pinned_on_top\s*=.*$/pinned_on_top = true/' "$CLIPBOARD_CONFIG"
        else
            echo 'pinned_on_top = true' >> "$CLIPBOARD_CONFIG"
        fi
    fi

    info "elephant 剪貼簿設定完成"
}

# 新增自訂快捷鍵到 hyprland
setup_hypr_keybindings() {
    info "新增自訂快捷鍵到 ~/.config/hypr/bindings.conf..."

    HYPR_BINDINGS="$HOME/.config/hypr/bindings.conf"

    if [ ! -f "$HYPR_BINDINGS" ]; then
        error "找不到 $HYPR_BINDINGS"
        exit 1
    fi

    # 檢查是否已經加入過 (兼容新舊版本的標記)
    if grep -q "Custom keybindings added by setup-keybindings.sh" "$HYPR_BINDINGS" || grep -q "Custom screenshot and screen recording bindings" "$HYPR_BINDINGS"; then
        warn "自訂快捷鍵似乎已經加入，跳過重複新增"
        return
    fi

    # 在檔案末尾加入快捷鍵
cat >> "$HYPR_BINDINGS" << 'EOF'

# Custom keybindings added by setup-keybindings.sh
bindd = ALT SHIFT, Q, Screenshot (region), exec, omarchy-capture-screenshot region
bindd = ALT SHIFT, E, Screenshot (window), exec, omarchy-capture-screenshot windows
bindd = ALT SHIFT, F, Screenshot (fullscreen), exec, omarchy-capture-screenshot fullscreen

# Color picker
bindd = ALT SHIFT, A, Color picker, exec, hyprpicker

# Screen recording
bindd = ALT SHIFT, R, Screen recording, exec, omarchy-capture-screenrecording
bindd = ALT SHIFT CTRL, R, Screen recording (with camera), exec, omarchy-capture-screenrecording --with-webcam

# OCR text extraction
bindd = ALT SHIFT, O, Extract text (OCR), exec, omarchy-capture-text-extraction-zh

# Clipboard manager (elephant)
bindd = CONTROL, GRAVE, Clipboard, exec, omarchy-launch-walker -m clipboard
EOF

    info "快捷鍵已加入到 $HYPR_BINDINGS"
    info "Hyprland 會自動重新載入設定"
}

# 還原設定
uninstall() {
    info "還原自訂快捷鍵設定..."

    HYPR_BINDINGS="$HOME/.config/hypr/bindings.conf"

    if [ ! -f "$HYPR_BINDINGS" ]; then
        warn "找不到 $HYPR_BINDINGS"
        return 0
    fi

    # 移除我們加入的區塊 (兼容新舊版本的標記)
    if grep -q "Custom keybindings added by setup-keybindings.sh" "$HYPR_BINDINGS"; then
        sed -i '/^# Custom keybindings added by setup-keybindings.sh/,$d' "$HYPR_BINDINGS"
    elif grep -q "Custom screenshot and screen recording bindings" "$HYPR_BINDINGS"; then
        sed -i '/^# Custom screenshot and screen recording bindings/,$d' "$HYPR_BINDINGS"
        info "已從 $HYPR_BINDINGS 移除自訂快捷鍵"
    else
        info "沒有找到已加入的自訂快捷鍵，跳過"
    fi

    # 還原 elephant 設定 - 恢復成預設 command
    CLIPBOARD_CONFIG="$HOME/.config/elephant/clipboard.toml"
    if [ -f "$CLIPBOARD_CONFIG" ]; then
        if grep -q 'hyprctl' "$CLIPBOARD_CONFIG"; then
            sed -i "s/^command\s*=.*$/command = 'wl-copy'/" "$CLIPBOARD_CONFIG"
            info "已還原 elephant clipboard 預設設定"
        fi
    fi

    echo
    info "還原完成！"
    echo
}

# 顯示狀態
show_status() {
    local HYPR_BINDINGS="$HOME/.config/hypr/bindings.conf"
    local CLIPBOARD_CONFIG="$HOME/.config/elephant/clipboard.toml"

    echo -e "${CYAN}自訂快捷鍵設定狀態:${NC}"

    if [[ -f "$HYPR_BINDINGS" ]]; then
        if grep -q "Custom keybindings added by setup-keybindings.sh" "$HYPR_BINDINGS" || grep -q "Custom screenshot and screen recording bindings" "$HYPR_BINDINGS"; then
            echo -e "  ${GREEN}✓${NC} 自訂快捷鍵已安裝"
        else
            echo -e "  ${RED}✗${NC} 自訂快捷鍵未安裝"
        fi
    else
        echo -e "  ${YELLOW}!${NC} bindings.conf 不存在"
    fi

    if [[ -f "$CLIPBOARD_CONFIG" ]]; then
        if grep -q 'hyprctl' "$CLIPBOARD_CONFIG"; then
            echo -e "  ${GREEN}✓${NC} Elephant 自動貼上已設定"
        else
            echo -e "  ${YELLOW}!${NC} Elephant 已安裝但自動貼上未設定"
        fi
        if grep -q 'pinned_on_top\s*=\s*true' "$CLIPBOARD_CONFIG"; then
            echo -e "  ${GREEN}✓${NC} Pin 功能已開啟"
        fi
    else
        echo -e "  ${YELLOW}!${NC} clipboard.toml 不存在"
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
    setup_elephant_clipboard
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
    echo '  CTRL + `           → 開啟剪貼簿管理員'
    echo
    echo "自動貼上已啟用：選取項目後會自動複製並貼上 (透過 hyprctl)"
    echo "Pin 功能已開啟：釘選項目會固定在列表頂部"
    echo
}

# 主程式
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
