#!/bin/bash

# setup-fonts.sh
# 設定字體同 Chromium scale factor
# Category: 系統設定
# Description: 安裝字體 + GTK / Electron / Chromium 設定

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared library
source "$SCRIPT_DIR/lib/common.sh"

CHROMIUM_FLAGS="$HOME/.config/chromium-flags.conf"
# 預設 GTK 字體 family — 要同 `fc-list` 嘅 family 名完全一致：
#   MiSans 可變字型係 "MiSans VF"，OPPO Sans 係 "OPPO Sans 4.0"
# 可 override：FONT_NAME="MiSans VF" ./setup-fonts.sh -i
FONT_NAME="${FONT_NAME:-OPPO Sans 4.0}"
FONT_SIZE=9

# 字體下載連結
MISANS_URL="https://hyperos.mi.com/font-download/MiSans.zip"
OPPOSANS_URL="https://openfs.oppomobile.com/open/oop/202412/05/0f155015fff7700fbbcef7fa2aad78dc.zip"
FONT_DIR="$HOME/.local/share/fonts"
# fontconfig 覆寫：Electron / Chromium 唔讀 GTK 字體設定，只認 generic family
FONTCONFIG_FILE="$HOME/.config/fontconfig/fonts.conf"
# 安裝時快照目錄，lib/common.sh 嘅 snapshot_original 系列據此還原。一個目錄
# 同時存 fonts.conf、chromium-flags、gtk-fonts 三份原狀。
STATE_DIR="$HOME/.local/state/omarchy-custom-scripts/setup-fonts"
# -i 快照同 -u 還原共用同一份 key 清單。每項係 "schema key"，以空白分隔。
GTK_FONT_KEYS=(
    "org.gnome.desktop.interface font-name"
    "org.gnome.desktop.interface document-font-name"
    "org.gnome.desktop.wm.preferences titlebar-font"
)

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
    local temp_dir
    temp_dir=$(mktemp -d)
    local zip_file="$temp_dir/MiSans.zip"
    
    if ! curl -L -o "$zip_file" "$MISANS_URL"; then
        rm -rf "$temp_dir"
        error "下載 MiSans 失敗"
    fi

    info "解壓 MiSans..."
    if ! unzip -q "$zip_file" -d "$temp_dir"; then
        rm -rf "$temp_dir"
        error "解壓 MiSans 失敗"
    fi
    
    # 尋找 MiSansVF.ttf
    local font_file
    font_file=$(find "$temp_dir" -name "MiSansVF.ttf" -o -name "MiSans-VF.ttf" | head -1)
    
    if [[ -z "$font_file" ]]; then
        rm -rf "$temp_dir"
        error "找不到 MiSansVF.ttf"
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
    local temp_dir
    temp_dir=$(mktemp -d)
    local zip_file="$temp_dir/OPPOSans.zip"
    
    if ! curl -L -o "$zip_file" "$OPPOSANS_URL"; then
        rm -rf "$temp_dir"
        error "下載 OPPO Sans 失敗"
    fi

    info "解壓 OPPO Sans..."
    if ! unzip -q "$zip_file" -d "$temp_dir"; then
        rm -rf "$temp_dir"
        error "解壓 OPPO Sans 失敗"
    fi
    
    # 尋找 OPPO Sans 4.0.ttf
    local font_file
    font_file=$(find "$temp_dir" -name "OPPO Sans 4.0.ttf" -o -name "OPPOSans40.ttf" | head -1)
    
    if [[ -z "$font_file" ]]; then
        rm -rf "$temp_dir"
        error "找不到 OPPO Sans 4.0.ttf"
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
        grep -qxF -- "--force-device-scale-factor=1" "$CHROMIUM_FLAGS"
    else
        return 1
    fi
}

# 記錄三個 GTK 字體 key 嘅原值。-u 用佢還原，唔用 gsettings reset 跳去 schema 預設。
snapshot_gtk_fonts() {
    local snap="$STATE_DIR/gtk-fonts" pair
    [[ -f "$snap" ]] && return 0
    mkdir -p "$STATE_DIR"
    : > "$snap"
    for pair in "${GTK_FONT_KEYS[@]}"; do
        printf '%s|%s\n' "$pair" "$(gsettings get $pair 2>/dev/null)" >> "$snap"
    done
    detail "已記錄 GTK 字體原狀"
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
    
    snapshot_gtk_fonts
    info "設定 GTK 字體為 $font_setting..."
    gsettings set org.gnome.desktop.interface font-name "$font_setting"
    gsettings set org.gnome.desktop.interface document-font-name "$font_setting"
    gsettings set org.gnome.desktop.wm.preferences titlebar-font "$font_bold"
    
    detail "Interface font: $(gsettings get org.gnome.desktop.interface font-name)"
    detail "Document font: $(gsettings get org.gnome.desktop.interface document-font-name)"
    detail "Titlebar font: $(gsettings get org.gnome.desktop.wm.preferences titlebar-font)"
    
    info "GTK 字體設定完成"
}

# fontconfig 覆寫內容：sans-serif / system-ui / -apple-system 等全部指向
# $FONT_NAME，令 Electron / Chromium / 網頁都用同一個 UI 字體。
# 注意：50-omarchy.conf 會先將 sans-serif 改寫成 Liberation Sans，所以真正
# 生效嘅係 "Liberation Sans" 嗰條規則。
fontconfig_config() {
    cat <<XML
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <description>Generic sans / system-ui families point at $FONT_NAME (Electron, Chromium, web pages)</description>

  <!-- GTK 有 gsettings 管字體，Electron / Chromium 只問 fontconfig 嘅
       generic family。50-omarchy.conf 將 sans-serif 指派去 Liberation Sans
       （binding=strong），而本檔經 50-user.conf 喺佢之後載入，所以可以蓋過。 -->

  <match target="pattern">
    <test name="family" qual="any">
      <string>sans-serif</string>
    </test>
    <edit name="family" mode="assign" binding="strong">
      <string>$FONT_NAME</string>
    </edit>
  </match>

  <match target="pattern">
    <test name="family" qual="any">
      <string>sans</string>
    </test>
    <edit name="family" mode="assign" binding="strong">
      <string>$FONT_NAME</string>
    </edit>
  </match>

  <!-- 真正命中嘅一條：sans-serif 已經被改寫成 Liberation Sans。 -->
  <match target="pattern">
    <test name="family" qual="any">
      <string>Liberation Sans</string>
    </test>
    <edit name="family" mode="assign" binding="strong">
      <string>$FONT_NAME</string>
    </edit>
  </match>

  <match target="pattern">
    <test name="family" qual="any">
      <string>system-ui</string>
    </test>
    <edit name="family" mode="assign" binding="strong">
      <string>$FONT_NAME</string>
    </edit>
  </match>

  <match target="pattern">
    <test name="family" qual="any">
      <string>ui-sans-serif</string>
    </test>
    <edit name="family" mode="assign" binding="strong">
      <string>$FONT_NAME</string>
    </edit>
  </match>

  <match target="pattern">
    <test name="family" qual="any">
      <string>-apple-system</string>
    </test>
    <edit name="family" mode="assign" binding="strong">
      <string>$FONT_NAME</string>
    </edit>
  </match>

  <match target="pattern">
    <test name="family" qual="any">
      <string>BlinkMacSystemFont</string>
    </test>
    <edit name="family" mode="assign" binding="strong">
      <string>$FONT_NAME</string>
    </edit>
  </match>

  <!-- OPPO Sans / MiSans 都冇全套 CJK、Nerd Font 圖示同 emoji，補返 fallback。
       monospace 唔郁，terminal 繼續用 JetBrainsMono Nerd Font。 -->
  <alias binding="same">
    <family>$FONT_NAME</family>
    <accept>
      <family>Noto Sans CJK HK</family>
      <family>Noto Sans CJK TC</family>
      <family>Noto Sans CJK SC</family>
      <family>Noto Sans CJK JP</family>
      <family>JetBrainsMono Nerd Font</family>
      <family>Noto Color Emoji</family>
    </accept>
  </alias>
</fontconfig>
XML
}

# 設定 Electron / Chromium（fontconfig）
setup_fontconfig() {
    info "檢查 Electron / Chromium 字體設定..."

    local tmp
    tmp=$(mktemp)
    fontconfig_config > "$tmp"

    if [[ -f "$FONTCONFIG_FILE" ]] && cmp -s "$tmp" "$FONTCONFIG_FILE"; then
        rm -f "$tmp"
        info "fontconfig 已指向 $FONT_NAME，跳過"
        return 0
    fi

    mkdir -p "$(dirname "$FONTCONFIG_FILE")"
    snapshot_original "$STATE_DIR" "$FONTCONFIG_FILE" fonts.conf
    cp "$tmp" "$FONTCONFIG_FILE"
    rm -f "$tmp"

    fc-cache -f >/dev/null 2>&1
    detail "已寫入: $FONTCONFIG_FILE"
    detail "sans-serif → $(fc-match --format='%{family}' sans-serif 2>/dev/null)"
    info "fontconfig 設定完成（重開 app 先見到效果）"
}

# 還原 fontconfig。冇快照即 -i 冇改過，restore_original 自行跳過。
reset_fontconfig() {
    info "還原 Electron / Chromium 字體設定..."

    restore_original "$STATE_DIR" "$FONTCONFIG_FILE" fonts.conf
    fc-cache -f >/dev/null 2>&1
    info "fontconfig 已還原"
}

# 還原 GTK 字體。由快照還原原值，唔用 gsettings reset 跳去 schema 預設。
reset_fonts() {
    local snap="$STATE_DIR/gtk-fonts" pair value

    if [[ ! -f "$snap" ]]; then
        info "無安裝時 GTK 字體快照，-i 冇改過，跳過還原"
        return 0
    fi

    info "還原 GTK 字體設定..."
    while IFS='|' read -r pair value; do
        [[ -n "$value" ]] && gsettings set $pair "$value"
    done < "$snap"
    info "GTK 字體已還原"
}

# 設定 Chromium
setup_chromium() {
    info "檢查 Chromium 設定..."
    
    if check_chromium_scale; then
        info "Chromium scale factor 已設定為 1，跳過"
        return 0
    fi
    
    info "設定 Chromium scale factor 為 1..."
    
    # 只在真係有改動時快照。-i/-u 嚴格成對，見 AGENTS.md。
    snapshot_original "$STATE_DIR" "$CHROMIUM_FLAGS" chromium-flags

    if [[ -f "$CHROMIUM_FLAGS" ]]; then
        if grep -q -- "force-device-scale-factor=" "$CHROMIUM_FLAGS"; then
            # 有舊值，例如 1.25：就地改成 1，其他 flags 逐字保留
            sed -i 's/^--force-device-scale-factor=.*/--force-device-scale-factor=1/' "$CHROMIUM_FLAGS"
        else
            # 只 append 一行。先補回結尾換行，免得黏住上一個 flag。
            [[ -n "$(tail -c 1 "$CHROMIUM_FLAGS")" ]] && echo "" >> "$CHROMIUM_FLAGS"
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

# 還原 Chromium。由快照還原原狀，原本冇檔就刪走。
reset_chromium() {
    info "還原 Chromium 設定..."
    restore_original "$STATE_DIR" "$CHROMIUM_FLAGS" chromium-flags
}

# 顯示狀態
show_status() {
    echo -e "${CYAN}字體設定狀態:${NC}"

    if check_font_installed "MiSans"; then
        echo -e "  ${GREEN}✓${NC} MiSans VF 字體已安裝"
    else
        echo -e "  ${RED}✗${NC} MiSans VF 字體未安裝"
    fi

    if check_font_installed "OPPO Sans"; then
        echo -e "  ${GREEN}✓${NC} OPPO Sans 4.0 字體已安裝"
    else
        echo -e "  ${RED}✗${NC} OPPO Sans 4.0 字體未安裝"
    fi

    local current_font
    current_font=$(gsettings get org.gnome.desktop.interface font-name 2>/dev/null || echo "未設定")
    echo -e "  目前 GTK 字體: $current_font"
    echo -e "  Electron/Chromium (sans-serif): $(fc-match --format='%{family}' sans-serif 2>/dev/null)"

    if [[ -f "$FONTCONFIG_FILE" ]] && cmp -s <(fontconfig_config) "$FONTCONFIG_FILE"; then
        echo -e "  ${GREEN}✓${NC} fonts.conf 已指向 $FONT_NAME"
    else
        echo -e "  ${YELLOW}!${NC} fonts.conf 未設定，或者 $FONT_NAME 已經改咗，重跑 -i 套用"
    fi

    echo ""
    echo -e "${CYAN}Chromium 設定:${NC}"
    if [[ -f "$CHROMIUM_FLAGS" ]]; then
        if check_chromium_scale; then
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
    setup_fontconfig
    setup_chromium
    info "字體設定完成！"
}

# 解除安裝模式
uninstall() {
    info "開始還原字體設定..."
    reset_fonts
    reset_fontconfig
    reset_chromium
    cleanup_state_dir "$STATE_DIR"
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
            ;;
    esac
}

main "$@"
