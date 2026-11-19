#!/bin/bash

# setup-fonts.sh
# 安裝字體 + GTK / fontconfig 字體設定
# Category: 系統設定
# Description: 安裝字體 + GTK / fontconfig 設定

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared library
# shellcheck disable=SC1091  # lint 會連同 lib/*.sh 一齊檢查；單檔跑時係假警報
source "$SCRIPT_DIR/lib/common.sh"

# 預設字體 family — 要同 `fc-list` 嘅 family 名完全一致：
#   MiSans 可變字型係 "MiSans VF"，OPPO Sans 係 "OPPO Sans 4.0"
DEFAULT_FONT_NAME="MiSans VF"
DEFAULT_FONT_SIZE=10

# FONT_NAME / FONT_SIZE 環境變數有設就優先；冇設先用預設（TTY 互動會問）。
# ENV_* 保留「用家真係有冇設過」，FONT_* 係今次實際用嘅值。
ENV_FONT_NAME="${FONT_NAME:-}"
ENV_FONT_SIZE="${FONT_SIZE:-}"
FONT_NAME="${ENV_FONT_NAME:-$DEFAULT_FONT_NAME}"
FONT_SIZE="${ENV_FONT_SIZE:-$DEFAULT_FONT_SIZE}"

# 字體下載連結
MISANS_URL="https://hyperos.mi.com/font-download/MiSans.zip"
OPPOSANS_URL="https://openfs.oppomobile.com/open/oop/202412/05/0f155015fff7700fbbcef7fa2aad78dc.zip"
FONT_DIR="$HOME/.local/share/fonts"
# fontconfig 覆寫：Electron / Chromium 唔讀 GTK 字體設定，只認 generic family
FONTCONFIG_FILE="$HOME/.config/fontconfig/fonts.conf"
# 安裝時快照目錄，lib/common.sh 嘅 snapshot_original 系列據此還原。一個目錄
# 同時存 fonts.conf、gtk-fonts 兩份原狀，以及本腳本複製入去嘅字體檔名清單。
STATE_DIR="$HOME/.local/state/omarchy-custom-scripts/setup-fonts"
# -i 快照同 -u 還原共用同一份 key 清單。每項係 "schema key"，以空白分隔。
GTK_FONT_KEYS=(
    "org.gnome.desktop.interface font-name"
    "org.gnome.desktop.interface document-font-name"
    "org.gnome.desktop.wm.preferences titlebar-font"
)
# 本腳本複製入 $FONT_DIR 嘅檔名。只記本身唔存在嘅檔案，-u 只刪呢啲。
INSTALLED_FONTS_FILE="$STATE_DIR/installed-fonts"

# 檢查字體是否安裝
check_font_installed() {
    fc-list | grep -qi "$1"
}

# 檢查 GTK 字體設定
check_gtk_font() {
    local current_font expected="${1:-${FONT_NAME:-Sans} $FONT_SIZE}"
    current_font=$(gsettings get org.gnome.desktop.interface font-name 2>/dev/null || true)
    current_font=$(printf '%s' "$current_font" | tr -d "'")
    [[ "$current_font" == "$expected" ]]
}

# 記錄一個本腳本新裝入嘅字體檔名。清單只建立一次，重跑唔會重複。
record_installed_font() {
    local name="$1"
    mkdir -p "$STATE_DIR"
    [[ -f "$INSTALLED_FONTS_FILE" ]] || : > "$INSTALLED_FONTS_FILE"
    grep -qxF -- "$name" "$INSTALLED_FONTS_FILE" || printf '%s\n' "$name" >> "$INSTALLED_FONTS_FILE"
}

# 下載並安裝 MiSans
download_misans() {
    info "下載 MiSans 字體..."
    local temp_dir
    temp_dir=$(mktemp -d)
    local zip_file="$temp_dir/MiSans.zip"
    
    if ! curl -L -o "$zip_file" "$MISANS_URL"; then
        rm -rf "$temp_dir"
        warn "下載 MiSans 失敗"
        return 1
    fi

    info "解壓 MiSans..."
    if ! unzip -q "$zip_file" -d "$temp_dir"; then
        rm -rf "$temp_dir"
        warn "解壓 MiSans 失敗"
        return 1
    fi
    
    # 尋找 MiSansVF.ttf
    local font_file
    font_file=$(find "$temp_dir" -name "MiSansVF.ttf" -o -name "MiSans-VF.ttf" | head -1)
    
    if [[ -z "$font_file" ]]; then
        rm -rf "$temp_dir"
        warn "找不到 MiSansVF.ttf"
        return 1
    fi
    
    local font_base
    font_base="$(basename "$font_file")"
    mkdir -p "$FONT_DIR"
    if [[ -f "$FONT_DIR/$font_base" ]]; then
        detail "字體已存在，保留原檔: $FONT_DIR/$font_base"
    else
        cp "$font_file" "$FONT_DIR/"
        record_installed_font "$font_base"
    fi
    rm -rf "$temp_dir"
    
    detail "已安裝: $FONT_DIR/$font_base"
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
        warn "下載 OPPO Sans 失敗"
        return 1
    fi

    info "解壓 OPPO Sans..."
    if ! unzip -q "$zip_file" -d "$temp_dir"; then
        rm -rf "$temp_dir"
        warn "解壓 OPPO Sans 失敗"
        return 1
    fi
    
    # 尋找 OPPO Sans 4.0.ttf
    local font_file
    font_file=$(find "$temp_dir" -name "OPPO Sans 4.0.ttf" -o -name "OPPOSans40.ttf" | head -1)
    
    if [[ -z "$font_file" ]]; then
        rm -rf "$temp_dir"
        warn "找不到 OPPO Sans 4.0.ttf"
        return 1
    fi
    
    local font_base
    font_base="$(basename "$font_file")"
    mkdir -p "$FONT_DIR"
    if [[ -f "$FONT_DIR/$font_base" ]]; then
        detail "字體已存在，保留原檔: $FONT_DIR/$font_base"
    else
        cp "$font_file" "$FONT_DIR/"
        record_installed_font "$font_base"
    fi
    rm -rf "$temp_dir"
    
    detail "已安裝: $FONT_DIR/$font_base"
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

# 互動選 family。所有 prompt 都有預設，空輸入或 EOF 都唔會 hang。
prompt_font_family() {
    local choice misans_note="" oppo_note=""
    check_font_installed "$DEFAULT_FONT_NAME" || misans_note="（未安裝）"
    check_font_installed "OPPO Sans 4.0" || oppo_note="（未安裝）"
    printf '偵測到嘅字體 family（fc-list）:\n'
    printf '  1) %s（預設）%s\n' "$DEFAULT_FONT_NAME" "$misans_note"
    printf '  2) OPPO Sans 4.0%s\n' "$oppo_note"
    printf '  3) 其他（自行輸入 family 名稱）\n'
    while true; do
        read -rp "請選擇字體 family [1]: " choice || choice=""
        case "$choice" in
            ""|1) printf '%s\n' "$DEFAULT_FONT_NAME"; return 0 ;;
            2) printf '%s\n' "OPPO Sans 4.0"; return 0 ;;
            3)
                read -rp "輸入 family 名稱 [${DEFAULT_FONT_NAME}]: " choice || choice=""
                printf '%s\n' "${choice:-$DEFAULT_FONT_NAME}"
                return 0
                ;;
            *)
                # 直接輸入 family 名都接受；純數字但唔係選項就重問。
                if [[ "$choice" =~ ^[0-9]+$ ]]; then
                    warn "無效選項: $choice"
                    continue
                fi
                printf '%s\n' "$choice"
                return 0
                ;;
        esac
    done
}

# 互動選大小，只接受 6..20 整數，空輸入 = 預設。
prompt_font_size() {
    local input
    while true; do
        read -rp "請輸入字體大小 (6-20) [${DEFAULT_FONT_SIZE}]: " input || input=""
        input="${input:-$DEFAULT_FONT_SIZE}"
        if [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 6 && input <= 20 )); then
            printf '%s\n' "$input"
            return 0
        fi
        warn "字體大小要係 6 至 20 之間嘅整數"
    done
}

# 決定今次用邊個 family / size。環境變數 > TTY 互動 > 非互動預設。
choose_font_config() {
    local interactive=false
    [[ -t 0 ]] && interactive=true

    if [[ -n "$ENV_FONT_NAME" ]]; then
        detail "使用 FONT_NAME 環境變數: $FONT_NAME"
    elif $interactive; then
        FONT_NAME="$(prompt_font_family)"
    else
        FONT_NAME="$DEFAULT_FONT_NAME"
    fi

    if [[ -n "$ENV_FONT_SIZE" ]]; then
        detail "使用 FONT_SIZE 環境變數: $FONT_SIZE"
    elif $interactive; then
        FONT_SIZE="$(prompt_font_size)"
    else
        FONT_SIZE="$DEFAULT_FONT_SIZE"
    fi

    if ! $interactive && [[ -z "$ENV_FONT_NAME" && -z "$ENV_FONT_SIZE" ]]; then
        info "非互動模式，使用預設字體 $DEFAULT_FONT_NAME $DEFAULT_FONT_SIZE"
    fi

    # 所選 family 真係要裝咗先可以用；否則退回 MiSans VF，再冇就 Sans。
    if [[ -n "$FONT_NAME" ]] && ! check_font_installed "$FONT_NAME"; then
        warn "$FONT_NAME 字體未安裝"
        if check_font_installed "$DEFAULT_FONT_NAME"; then
            FONT_NAME="$DEFAULT_FONT_NAME"
            info "已改用 $FONT_NAME"
        else
            warn "MiSans VF 未安裝，改用系統 Sans"
            FONT_NAME=""
        fi
    fi
}

# 記錄三個 GTK 字體 key 嘅原值。-u 用佢還原，唔用 gsettings reset 跳去 schema 預設。
snapshot_gtk_fonts() {
    local snap="$STATE_DIR/gtk-fonts" pair
    [[ -f "$snap" ]] && return 0
    mkdir -p "$STATE_DIR"
    : > "$snap"
    for pair in "${GTK_FONT_KEYS[@]}"; do
        # shellcheck disable=SC2086  # $pair 刻意分開 schema 同 key 兩個參數
        printf '%s|%s\n' "$pair" "$(gsettings get $pair 2>/dev/null)" >> "$snap"
    done
    detail "已記錄 GTK 字體原狀"
}

# 設定 GTK 字體
setup_fonts() {
    info "檢查字體設定..."

    # 先確保字體裝好，再決定用邊個 family / size。
    auto_download_fonts
    choose_font_config

    local font_setting="${FONT_NAME:-Sans} $FONT_SIZE"
    local font_bold="${FONT_NAME:-Sans} Bold $FONT_SIZE"

    if check_gtk_font "$font_setting"; then
        info "GTK 字體已設定為 $font_setting，跳過"
        return 0
    fi

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

    # 字體下載失敗時 FONT_NAME 係空，冇 family 可指向，唔好寫一份空殼 fonts.conf
    if [[ -z "$FONT_NAME" ]]; then
        warn "字體未安裝，跳過 Electron / Chromium 字體設定"
        return 0
    fi

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
        # shellcheck disable=SC2086  # $pair 刻意分開 schema 同 key 兩個參數
        [[ -n "$value" ]] && gsettings set $pair "$value"
    done < "$snap"
    info "GTK 字體已還原"
}

# 移除 -i 時本腳本新複製入 $FONT_DIR 嘅字體檔（清單有記錄先會刪）。
reset_font_files() {
    local name

    if [[ ! -f "$INSTALLED_FONTS_FILE" ]]; then
        info "無本腳本安裝嘅字體檔記錄，跳過移除"
        return 0
    fi

    info "移除本腳本安裝嘅字體檔..."
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        # 只認 basename，避免清單被改動時刪到路徑以外嘅檔案。
        name="${name##*/}"
        if [[ -f "$FONT_DIR/$name" ]]; then
            rm -f "$FONT_DIR/$name"
            detail "已移除: $FONT_DIR/$name"
        fi
    done < "$INSTALLED_FONTS_FILE"
    fc-cache -f "$FONT_DIR" >/dev/null 2>&1
    info "字體檔已移除（字體資料夾保留）"
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

    local current_font expected
    current_font=$(gsettings get org.gnome.desktop.interface font-name 2>/dev/null || true)
    current_font=$(printf '%s' "$current_font" | tr -d "'")
    expected="${FONT_NAME:-Sans} $FONT_SIZE"
    echo -e "  目前 GTK 字體: ${current_font:-未設定}"
    echo -e "  Electron/Chromium (sans-serif): $(fc-match --format='%{family}' sans-serif 2>/dev/null || true)"

    if [[ "$current_font" == "$expected" ]]; then
        echo -e "  ${GREEN}✓${NC} GTK 字體已設定為 $expected"
    else
        echo -e "  ${YELLOW}!${NC} GTK 字體未設定為 $expected，重跑 -i 套用"
    fi

    if [[ -f "$FONTCONFIG_FILE" ]] && cmp -s <(fontconfig_config) "$FONTCONFIG_FILE"; then
        echo -e "  ${GREEN}✓${NC} fonts.conf 已指向 $FONT_NAME"
    else
        echo -e "  ${YELLOW}!${NC} fonts.conf 未設定，或者 $FONT_NAME 已經改咗，重跑 -i 套用"
    fi
}

# 安裝模式
install() {
    info "開始設定字體..."
    setup_fonts
    setup_fontconfig
    info "字體設定完成！"
    detail "Chromium scale factor 設定已搬到 setup-chromium-scale.sh"
}

# 解除安裝模式
uninstall() {
    info "開始還原字體設定..."
    reset_fonts
    reset_fontconfig
    reset_font_files
    cleanup_state_dir "$STATE_DIR"
    info "字體設定已還原！"
}

# 使用說明
usage() {
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "Options:"
    echo "  -i, --install     安裝/設定字體 (預設)"
    echo "  -u, --uninstall   還原字體設定同移除本腳本裝嘅字體檔"
    echo "  -d, --download    只下載字體不安裝"
    echo "  -s, --status      顯示目前狀態"
    echo "  -h, --help        顯示此說明"
    echo ""
    echo "預設字體: $DEFAULT_FONT_NAME，大小 $DEFAULT_FONT_SIZE。"
    echo "FONT_NAME / FONT_SIZE 環境變數可覆寫；TTY 互動模式會逐項詢問。"
    echo "非互動（-i 經 pipe / CI）一律用預設，唔會停低問。"
    echo "Chromium scale 設定已獨立為 setup-chromium-scale.sh。"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME              # 設定字體 (自動下載)"
    echo "  $SCRIPT_NAME -s           # 顯示狀態"
    echo "  FONT_NAME=\"OPPO Sans 4.0\" FONT_SIZE=11 $SCRIPT_NAME -i"
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
