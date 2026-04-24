#!/bin/bash

# setup-fonts.sh
# 設定字體同 Chromium scale factor
# Category: 系統設定
# Description: 安裝字體 + Chromium 縮放修復

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared library
source "$SCRIPT_DIR/lib/common.sh"

CHROMIUM_FLAGS="$HOME/.config/chromium-flags.conf"
FONT_NAME="MiSans"
FONT_SIZE=10

# 字體下載連結
MISANS_URL="https://hyperos.mi.com/font-download/MiSans.zip"
OPPOSANS_URL="https://openfs.oppomobile.com/open/oop/202412/05/0f155015fff7700fbbcef7fa2aad78dc.zip"
FONT_DIR="$HOME/.local/share/fonts"

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

# 下載並安裝 MiSans
download_misans() {
    info "下載 MiSans 字體..."
    local temp_dir=$(mktemp -d)
    local zip_file="$temp_dir/MiSans.zip"
    
    if ! curl -L -o "$zip_file" "$MISANS_URL"; then
        error "下載 MiSans 失敗"
        rm -rf "$temp_dir"
        return 1
    fi
    
    info "解壓 MiSans..."
    if ! unzip -q "$zip_file" -d "$temp_dir"; then
        error "解壓 MiSans 失敗"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 尋找 MiSansVF.ttf
    local font_file
    font_file=$(find "$temp_dir" -name "MiSansVF.ttf" -o -name "MiSans-VF.ttf" | head -1)
    
    if [[ -z "$font_file" ]]; then
        error "找不到 MiSansVF.ttf"
        rm -rf "$temp_dir"
        return 1
    fi
    
    mkdir -p "$FONT_DIR"
    cp "$font_file" "$FONT_DIR/"
    rm -rf "$temp_dir"
    
    detail "已安裝: $FONT_DIR/$(basename "$font_file")"
    info "MiSans 安裝完成"
}

# 下載並安裝 OPPO Sans
download_opposans() {
    info "下載 OPPO Sans 字體..."
    local temp_dir=$(mktemp -d)
    local zip_file="$temp_dir/OPPOSans.zip"
    
    if ! curl -L -o "$zip_file" "$OPPOSANS_URL"; then
        error "下載 OPPO Sans 失敗"
        rm -rf "$temp_dir"
        return 1
    fi
    
    info "解壓 OPPO Sans..."
    if ! unzip -q "$zip_file" -d "$temp_dir"; then
        error "解壓 OPPO Sans 失敗"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 尋找 OPPO Sans 4.0.ttf
    local font_file
    font_file=$(find "$temp_dir" -name "OPPO Sans 4.0.ttf" -o -name "OPPOSans40.ttf" | head -1)
    
    if [[ -z "$font_file" ]]; then
        error "找不到 OPPO Sans 4.0.ttf"
        rm -rf "$temp_dir"
        return 1
    fi
    
    mkdir -p "$FONT_DIR"
    cp "$font_file" "$FONT_DIR/"
    rm -rf "$temp_dir"
    
    detail "已安裝: $FONT_DIR/$(basename "$font_file")"
    info "OPPO Sans 安裝完成"
}

# 更新字體快取
update_font_cache() {
    info "更新字體快取..."
    fc-cache -fv "$FONT_DIR" >/dev/null 2>&1
    info "字體快取更新完成"
}

# 自動下載字體
auto_download_fonts() {
    local need_update=false
    
    if ! check_font_installed "MiSans"; then
        download_misans
        need_update=true
    else
        info "MiSans 已安裝，跳過下載"
    fi
    
    if ! check_font_installed "OPPO Sans"; then
        download_opposans
        need_update=true
    else
        info "OPPO Sans 已安裝，跳過下載"
    fi
    
    if $need_update; then
        update_font_cache
    fi
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
        warn "$FONT_NAME 字體未安裝，嘗試自動下載..."
        auto_download_fonts
        
        # 再次檢查
        if ! check_font_installed "$FONT_NAME"; then
            warn "$FONT_NAME 字體下載失敗，嘗試使用系統預設字體大小 $FONT_SIZE"
            FONT_NAME=""
        fi
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

# 顯示狀態
show_status() {
    echo -e "${CYAN}字體設定狀態:${NC}"

    if check_font_installed "MiSans"; then
        echo -e "  ${GREEN}✓${NC} MiSans 字體已安裝"
    else
        echo -e "  ${RED}✗${NC} MiSans 字體未安裝"
    fi

    if check_font_installed "OPPO Sans"; then
        echo -e "  ${GREEN}✓${NC} OPPO Sans 字體已安裝"
    else
        echo -e "  ${RED}✗${NC} OPPO Sans 字體未安裝"
    fi

    local current_font
    current_font=$(gsettings get org.gnome.desktop.interface font-name 2>/dev/null || echo "未設定")
    echo -e "  目前 GTK 字體: $current_font"

    echo ""
    echo -e "${CYAN}Chromium 設定:${NC}"
    if [[ -f "$CHROMIUM_FLAGS" ]]; then
        if grep -q "force-device-scale-factor=1" "$CHROMIUM_FLAGS"; then
            echo -e "  ${GREEN}✓${NC} Scale factor 已設為 1"
        else
            echo -e "  ${YELLOW}!${NC} Scale factor 未設定為 1"
        fi
    else
        echo -e "  ${RED}✗${NC} Chromium flags 檔案不存在"
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
    echo "  -d, --download    只下載字體不安裝"
    echo "  -s, --status      顯示目前狀態"
    echo "  -h, --help        顯示此說明"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME              # 設定字體 (自動下載)"
    echo "  $SCRIPT_NAME -s           # 顯示狀態"
}

# 主程式
main() {
    case "${1:-}" in
        -u|--uninstall)
            uninstall
            ;;
        -d|--download)
            auto_download_fonts
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
