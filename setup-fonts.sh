#!/bin/bash

# setup-fonts.sh
# 設定字體同 Chromium scale factor
# - 安裝中文字體:MiSans / OPPO Sans (repo fonts/ 內建,免下載)
# - 可選:設定預設中文 GUI 字體 (GTK + Electron fontconfig)
# Category: 系統設定
# Description: 安裝字體 + Chromium 縮放修復 + 預設中文 GUI 字體
# Device: both

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared library
source "$SCRIPT_DIR/lib/common.sh"

CHROMIUM_FLAGS="$HOME/.config/chromium-flags.conf"
FONTCONF="$HOME/.config/fontconfig/fonts.conf"
FC_MARKER_BEGIN="<!-- BEGIN gui-font (setup-fonts.sh) -->"
FC_MARKER_END="<!-- END gui-font (setup-fonts.sh) -->"

# 字體來源: repo 內建 (fonts/) 優先, 缺檔時 fallback 到官方下載
FONT_LOCAL_DIR="$SCRIPT_DIR/fonts"
MISANS_URL="https://hyperos.mi.com/font-download/MiSans.zip"
OPPOSANS_URL="https://openfs.oppomobile.com/open/oop/202412/05/0f155015fff7700fbbcef7fa2aad78dc.zip"
FONT_DIR="$HOME/.local/share/fonts"

# 真實 fontconfig family 名
FONT_FAMILY_MISANS="MiSans VF"
FONT_FAMILY_OPPOSANS="OPPO Sans 4.0"

# 可選字體
FONT_CHOICES=("misans" "opposans")
FONTS=()

# 預設中文 GUI 字體 (misans|opposans|空=唔設定)
GUI_FONT=""

# 檢查字體是否安裝
check_font_installed() {
    fc-list | grep -qi "$1"
}

parse_font_arg() {
    local raw="$1"
    local normalized
    normalized=$(echo "$raw" | tr ',' ' ')
    local id
    for id in $normalized; do
        case "$id" in
            misans|opposans) FONTS+=("$id") ;;
            *) warn "忽略未知字體: $id (可用: misans, opposans)" ;;
        esac
    done
}

parse_gui_font_arg() {
    local val="${1:-}"
    case "$val" in
        misans|opposans) GUI_FONT="$val" ;;
        "") GUI_FONT="" ;;
        *) warn "忽略無效 gui-font 值: $val (可用: misans, opposans)" ;;
    esac
}

font_family() {
    case "$1" in
        misans) echo "$FONT_FAMILY_MISANS" ;;
        opposans) echo "$FONT_FAMILY_OPPOSANS" ;;
    esac
}

# 由 repo fonts/ 或官方 URL 安裝單一字體
# 回傳 0 成功, 1 失敗
install_font() {
    local id="$1" local_file family
    case "$id" in
        misans)
            check_font_installed "MiSans" && { info "MiSans 已安裝, 跳過"; return 0; }
            local_file="$FONT_LOCAL_DIR/MiSansVF.ttf"
            family="MiSans VF"
            if [[ -f "$local_file" ]]; then
                info "安裝內建 MiSans (fonts/)..."
                mkdir -p "$FONT_DIR"
                cp "$local_file" "$FONT_DIR/"
                detail "已安裝: $FONT_DIR/$(basename "$local_file")"
                return 0
            fi
            download_misans
            ;;
        opposans)
            check_font_installed "OPPO Sans" && { info "OPPO Sans 已安裝, 跳過"; return 0; }
            local_file="$FONT_LOCAL_DIR/OPPO Sans 4.0.ttf"
            if [[ -f "$local_file" ]]; then
                info "安裝內建 OPPO Sans (fonts/)..."
                mkdir -p "$FONT_DIR"
                cp "$local_file" "$FONT_DIR/"
                detail "已安裝: $FONT_DIR/OPPO Sans 4.0.ttf"
                return 0
            fi
            download_opposans
            ;;
        *)
            return 1
            ;;
    esac
}

install_selected_fonts() {
    [[ ${#FONTS[@]} -eq 0 ]] && FONTS=("${FONT_CHOICES[@]}")
    local id need_update=false
    for id in "${FONTS[@]}"; do
        install_font "$id" && need_update=true
    done
    if $need_update; then
        update_font_cache
    fi
}

# 下載並安裝 MiSans (fallback 路徑: repo 冇內建字體時)
download_misans() {
    info "下載 MiSans 字體 (fallback)..."
    local temp_dir=$(mktemp -d)
    local zip_file="$temp_dir/MiSans.zip"

    if ! curl -L -o "$zip_file" "$MISANS_URL"; then
        error "下載 MiSans 失敗"
        rm -rf "$temp_dir"
        return 1
    fi

    unzip -q "$zip_file" -d "$temp_dir" 2>/dev/null
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
}

# 下載並安裝 OPPO Sans (fallback)
download_opposans() {
    info "下載 OPPO Sans 字體 (fallback)..."
    local temp_dir=$(mktemp -d)
    local zip_file="$temp_dir/OPPOSans.zip"

    if ! curl -L -o "$zip_file" "$OPPOSANS_URL"; then
        error "下載 OPPO Sans 失敗"
        rm -rf "$temp_dir"
        return 1
    fi

    unzip -q "$zip_file" -d "$temp_dir" 2>/dev/null
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
}

# 更新字體快取
update_font_cache() {
    info "更新字體快取..."
    fc-cache -fv "$FONT_DIR" >/dev/null 2>&1
    info "字體快取更新完成"
}

# 檢查 Chromium flags
check_chromium_scale() {
    [[ -f "$CHROMIUM_FLAGS" ]] && grep -q "force-device-scale-factor=1" "$CHROMIUM_FLAGS"
}

# ========================================
# 預設中文 GUI 字體 (GTK 三 + Electron fontconfig)
# ========================================

# 移除 fontconfig marker 區塊 (若存在)
remove_fontconfig_block() {
    if [[ -f "$FONTCONF" ]] && grep -qF -- "$FC_MARKER_BEGIN" "$FONTCONF"; then
        local begin_line end_line
        begin_line=$(grep -n -F -- "$FC_MARKER_BEGIN" "$FONTCONF" | cut -d: -f1 | head -1)
        end_line=$(grep -n -F -- "$FC_MARKER_END" "$FONTCONF" | cut -d: -f1 | head -1)
        [[ -n "$begin_line" && -n "$end_line" ]] && sed -i "${begin_line},${end_line}d" "$FONTCONF"
    fi
}

# 寫入 fontconfig sans-serif 覆蓋 (prepend_first 蓋過 Omarchy assign)
# 每次成個 marker 區塊刪除再重插 — 唔可以 sed 逐字串替換,
# 否則區塊內嘅 <string>sans-serif</string> (test target) 都會被換走,規則會壞
setup_fontconfig_sans() {
    local family="$1"

    mkdir -p "$(dirname "$FONTCONF")"

    if [[ ! -f "$FONTCONF" ]]; then
        cat > "$FONTCONF" << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
</fontconfig>
EOF
    else
        create_backup "$FONTCONF"
    fi

    remove_fontconfig_block

    sed -i "s|</fontconfig>|$FC_MARKER_BEGIN\n  <match target=\"pattern\">\n    <test name=\"family\" qual=\"any\">\n      <string>sans-serif</string>\n    </test>\n    <edit name=\"family\" mode=\"prepend_first\" binding=\"strong\">\n      <string>$family</string>\n    </edit>\n  </match>\n$FC_MARKER_END\n</fontconfig>|" "$FONTCONF"
    info "fontconfig: sans-serif → $family (覆蓋 Omarchy assign)"
}

# 設定預設中文 GUI 字體: GTK gsettings + Electron fontconfig
setup_gui_font() {
    [[ -z "$GUI_FONT" ]] && return 0
    local family
    family=$(font_family "$GUI_FONT")
    [[ -z "$family" ]] && return 0

    # 確保字體已裝
    install_font "$GUI_FONT" || return 1

    info "設定預設中文 GUI 字體: $family (9pt)..."

    # GTK (Nautilus 等)
    gsettings set org.gnome.desktop.interface font-name "$family 9"
    gsettings set org.gnome.desktop.interface document-font-name "$family 9"
    gsettings set org.gnome.desktop.wm.preferences titlebar-font "$family Bold 9"

    # Electron/Chromium 唔睇 gsettings → fontconfig sans-serif
    setup_fontconfig_sans "$family"

    info "GUI 字體已設定: $family 9 / Bold 9 (+ fontconfig)"
    info "monospace 保持不變（終端機字體唔郁）"
}

# 還原 GTK 字體 + fontconfig sans 設定
reset_fonts() {
    info "還原 GTK 字體設定..."
    gsettings reset org.gnome.desktop.interface font-name
    gsettings reset org.gnome.desktop.interface document-font-name
    gsettings reset org.gnome.desktop.wm.preferences titlebar-font
    info "GTK 字體已還原為系統預設"

    if [[ -f "$FONTCONF" ]] && grep -qF -- "$FC_MARKER_BEGIN" "$FONTCONF"; then
        create_backup "$FONTCONF"
        remove_fontconfig_block
        info "已移除 fontconfig sans-serif 設定"
    fi
}

# 設定 Chromium
setup_chromium() {
    info "檢查 Chromium 設定..."
    if check_chromium_scale; then
        info "Chromium scale factor 已設定為 1, 跳過"
        return 0
    fi

    info "設定 Chromium scale factor 為 1..."
    if [[ -f "$CHROMIUM_FLAGS" ]]; then
        create_backup "$CHROMIUM_FLAGS"
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
    info "Chromium 設定完成"
}

# 還原 Chromium
reset_chromium() {
    info "還原 Chromium 設定..."
    if [[ -f "$CHROMIUM_FLAGS" ]]; then
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

    if [[ -f "$FONTCONF" ]] && grep -qF -- "$FC_MARKER_BEGIN" "$FONTCONF"; then
        echo -e "  ${GREEN}✓${NC} fontconfig sans-serif 設定已套用"
    else
        echo -e "  ${YELLOW}!${NC} fontconfig sans-serif 未設定"
    fi

    echo ""
    echo -e "${CYAN}Chromium 設定:${NC}"
    if [[ -f "$CHROMIUM_FLAGS" ]] && grep -q "force-device-scale-factor=1" "$CHROMIUM_FLAGS"; then
        echo -e "  ${GREEN}✓${NC} Scale factor 已設為 1"
    else
        echo -e "  ${RED}✗${NC} Chromium flags 未設定"
    fi
}

# 安裝模式
install() {
    info "開始設定字體..."
    install_selected_fonts
    setup_gui_font
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
    echo "  --fonts <list>    指定要安裝嘅字體, 逗號分隔 (misans, opposans)"
    echo "  --gui-font <id>   設定預設中文 GUI 字體 (misans|opposans, 推薦 opposans)"
    echo ""
    echo "可用字體:"
    echo "  misans      MiSans 黑體 (family: MiSans VF)"
    echo "  opposans    OPPO Sans 黑體 (family: OPPO Sans 4.0)"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME                        # 安裝內建字體, 唔改系統字體"
    echo "  $SCRIPT_NAME --gui-font opposans    # 裝字體 + OPPO 做預設中文 GUI 字體"
    echo "  $SCRIPT_NAME --fonts misans --gui-font misans"
    echo "  $SCRIPT_NAME -s                     # 顯示狀態"
}

# 主程式
# 參數可組合 (例: --fonts misans --gui-font opposans),逐個解析後一次過 install
main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -u|--uninstall) uninstall; return 0 ;;
            -d|--download) install_selected_fonts; return 0 ;;
            -s|--status) show_status; return 0 ;;
            -h|--help) usage; return 0 ;;
            --fonts)
                if [[ -z "${2:-}" ]]; then
                    error "--fonts 需要參數 (misans, opposans)"
                fi
                parse_font_arg "$2"; shift 2
                ;;
            --gui-font)
                if [[ -z "${2:-}" ]]; then
                    error "--gui-font 需要參數 (misans|opposans)"
                fi
                parse_gui_font_arg "$2"
                [[ -n "$GUI_FONT" ]] && FONTS+=("$GUI_FONT")
                shift 2
                ;;
            -i|--install|"") shift ;;
            *) usage; exit 1 ;;
        esac
    done
    install
}

main "$@"