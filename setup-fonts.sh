#!/bin/bash

# setup-fonts.sh
# 設定字體同 Chromium scale factor

set -e

SCRIPT_NAME="$(basename "$0")"
RIME_DIR="$HOME/.local/share/fcitx5/rime"
CHROMIUM_FLAGS="$HOME/.config/chromium-flags.conf"
FONT_NAME="MiSans"
FONT_SIZE=10

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

detail() {
    echo -e "${BLUE}[DETAIL]${NC} $1"
}

# 檢查字體是否安裝
check_font_installed() {
    fc-list | grep -qi "$1"
}

# 檢查 GTK 字體設定
check_gtk_font() {
    local current_font
    current_font=$(gsettings get org.gnome.desktop.interface font-name 2>/dev/null || echo "")
    [[ "$current_font" == *"$FONT_NAME"* ]]
}

# 檢查 Chromium flags
check_chromium_scale() {
    if [[ -f "$CHROMIUM_FLAGS" ]]; then
        grep -q "force-device-scale-factor=1" "$CHROMIUM_FLAGS"
    else
        return 1
    fi
}

# 設定 GTK 字體
setup_fonts() {
    info "檢查字體設定..."
    
    if check_gtk_font; then
        info "GTK 字體已設定為 $FONT_NAME，跳過"
        return 0
    fi
    
    if ! check_font_installed "$FONT_NAME"; then
        warn "$FONT_NAME 字體未安裝，嘗試使用系統預設字體大小 $FONT_SIZE"
        FONT_NAME=""
    fi
    
    local font_setting="${FONT_NAME:-Sans} $FONT_SIZE"
    local font_bold="${FONT_NAME:-Sans} Bold $FONT_SIZE"
    
    info "設定 GTK 字體為 $font_setting..."
    gsettings set org.gnome.desktop.interface font-name "$font_setting"
    gsettings set org.gnome.desktop.interface document-font-name "$font_setting"
    gsettings set org.gnome.desktop.wm.preferences titlebar-font "$font_bold"
    
    detail "Interface font: $(gsettings get org.gnome.desktop.interface font-name)"
    detail "Document font: $(gsettings get org.gnome.desktop.interface document-font-name)"
    detail "Titlebar font: $(gsettings get org.gnome.desktop.wm.preferences titlebar-font)"
    
    info "GTK 字體設定完成"
}

# 還原 GTK 字體
reset_fonts() {
    info "還原 GTK 字體設定..."
    gsettings reset org.gnome.desktop.interface font-name
    gsettings reset org.gnome.desktop.interface document-font-name
    gsettings reset org.gnome.desktop.wm.preferences titlebar-font
    info "GTK 字體已還原為系統預設"
}

# 設定 Chromium
setup_chromium() {
    info "檢查 Chromium 設定..."
    
    if check_chromium_scale; then
        info "Chromium scale factor 已設定為 1，跳過"
        return 0
    fi
    
    info "設定 Chromium scale factor 為 1..."
    
    if [[ -f "$CHROMIUM_FLAGS" ]]; then
        # 備份
        cp "$CHROMIUM_FLAGS" "$CHROMIUM_FLAGS.bak.$(date +%s)"
        
        if grep -q "force-device-scale-factor" "$CHROMIUM_FLAGS"; then
            sed -i 's/force-device-scale-factor=.*/force-device-scale-factor=1/' "$CHROMIUM_FLAGS"
        else
            echo "--force-device-scale-factor=1" >> "$CHROMIUM_FLAGS"
        fi
    else
        mkdir -p "$(dirname "$CHROMIUM_FLAGS")"
        cat > "$CHROMIUM_FLAGS" << 'EOF'
--ozone-platform=wayland
--force-device-scale-factor=1
--ozone-platform-hint=wayland
--enable-features=TouchpadOverscrollHistoryNavigation
EOF
    fi
    
    detail "Chromium flags 檔案: $CHROMIUM_FLAGS"
    detail "內容:"
    cat "$CHROMIUM_FLAGS" | sed 's/^/  /'
    
    info "Chromium 設定完成"
}

# 還原 Chromium
reset_chromium() {
    info "還原 Chromium 設定..."
    if [[ -f "$CHROMIUM_FLAGS" ]]; then
        # 移除 scale factor 行
        sed -i '/force-device-scale-factor/d' "$CHROMIUM_FLAGS"
        info "已移除 Chromium scale factor 設定"
    fi
}

# 安裝模式
install() {
    info "開始設定字體..."
    setup_fonts
    setup_chromium
    info "字體設定完成！"
}

# 解除安裝模式
uninstall() {
    info "開始還原字體設定..."
    reset_fonts
    reset_chromium
    info "字體設定已還原！"
}

# 使用說明
usage() {
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "Options:"
    echo "  -i, --install     安裝/設定字體 (預設)"
    echo "  -u, --uninstall   還原字體設定"
    echo "  -h, --help        顯示此說明"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME              # 設定字體"
    echo "  $SCRIPT_NAME -u           # 還原字體"
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
