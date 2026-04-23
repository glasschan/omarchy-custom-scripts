#!/bin/bash

# setup-keybindings.sh
# 設定自訂快捷鍵 - 截圖、錄影、剪貼簿管理
# - ALT SHIFT + Q: 區域截圖
# - ALT SHIFT + F: 視窗截圖
# - ALT SHIFT + R: 螢幕錄影
# - ALT SHIFT CTRL + R: 螢幕錄影 (含攝影機)
# - CTRL + `: 開啟 elephant 剪貼簿管理員

set -e

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 顏色輸出
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

# 檢查依賴
check_dependencies() {
    info "檢查依賴..."

    if ! command -v wtype &> /dev/null; then
        error "wtype 未安裝，請先安裝："
        echo "  yay -S wtype"
        exit 1
    fi

    if ! command -v elephant &> /dev/null; then
        error "elephant 未安裝，請先安裝 elephant-clipboard"
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
command = "wl-copy && sleep 0.2 && wtype -M shift -k Insert -m shift"
ignore_symbols = true
image_editor_cmd = ''
max_items = 100
pinned_on_top = false
text_editor_cmd = ''

[Config]
hide_from_providerlist = false
icon = 'user-bookmarks'
min_score = 30
name_pretty = ''
EOF
    else
        info "更新現有 clipboard.toml..."
        if grep -q '^command\s*=' "$CLIPBOARD_CONFIG"; then
            sed -i 's/^command\s*=.*$/command = "wl-copy && sleep 0.2 && wtype -M shift -k Insert -m shift"/' "$CLIPBOARD_CONFIG"
        else
            echo 'command = "wl-copy && sleep 0.2 && wtype -M shift -k Insert -m shift"' >> "$CLIPBOARD_CONFIG"
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

    # 檢查是否已經加入過
    if grep -q "Custom screenshot and screen recording bindings" "$HYPR_BINDINGS"; then
        warn "自訂快捷鍵似乎已經加入，跳過重複新增"
        return
    fi

    # 在檔案末尾加入快捷鍵
    cat >> "$HYPR_BINDINGS" << 'EOF'

# Custom screenshot and screen recording bindings
bindd = ALT SHIFT, Q, Screenshot (region), exec, omarchy-cmd-screenshot region
bindd = ALT SHIFT, E, Screenshot (window), exec, omarchy-cmd-screenshot windows
bindd = ALT SHIFT, F, Screenshot (fullscreen), exec, omarchy-cmd-screenshot fullscreen

# Screen recording
bindd = ALT SHIFT, R, Screen recording, exec, omarchy-cmd-screenrecord
bindd = ALT SHIFT CTRL, R, Screen recording (with camera), exec, omarchy-cmd-screenrecord --with-cam

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

    # 移除我們加入的區塊
    # 從 "# Custom screenshot and screen recording bindings" 到檔案結尾
    if grep -q "Custom screenshot and screen recording bindings" "$HYPR_BINDINGS"; then
        sed -i '/^# Custom screenshot and screen recording bindings/,$d' "$HYPR_BINDINGS"
        info "已從 $HYPR_BINDINGS 移除自訂快捷鍵"
    else
        info "沒有找到已加入的自訂快捷鍵，跳過"
    fi

    # 還原 elephant 設定 - 恢復成預設 command
    CLIPBOARD_CONFIG="$HOME/.config/elephant/clipboard.toml"
    if [ -f "$CLIPBOARD_CONFIG" ]; then
        if grep -q 'wtype' "$CLIPBOARD_CONFIG"; then
            sed -i "s/^command\s*=.*$/command = 'wl-copy'/" "$CLIPBOARD_CONFIG"
            info "已還原 elephant clipboard 預設設定"
        fi
    fi

    echo
    info "還原完成！"
    echo
}

# 使用說明
usage() {
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "Options:"
    echo "  -i, --install     安裝設定 (預設)"
    echo "  -u, --uninstall   還原設定"
    echo "  -h, --help        顯示此說明"
    echo ""
}

# 主程式
main() {
    case "${1:-}" in
        -u|--uninstall)
            uninstall
            ;;
        -h|--help)
            usage
            ;;
        -i|--install|"")
            info "開始設定自訂快捷鍵..."

            check_dependencies
            setup_elephant_clipboard
            setup_hypr_keybindings

            echo
            info "=============================="
            info "設定完成！"
            info "=============================="
            echo
            echo "新增的快捷鍵："
            echo "  ALT SHIFT + Q      → 區域截圖"
            echo "  ALT SHIFT + E      → 視窗選取截圖"
            echo "  ALT SHIFT + F      → 全螢幕截圖"
            echo "  ALT SHIFT + R      → 開始螢幕錄影"
            echo "  ALT SHIFT CTRL + R → 開始螢幕錄影 (含攝影機)"
            echo '  CTRL + `           → 開啟剪貼簿管理員'
            echo
            echo "自動貼上已啟用：選取項目後會自動複製並貼上 (使用 Shift+Insert)"
            echo
            ;;
        *)
            error "未知選項: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"
