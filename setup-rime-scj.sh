#!/bin/bash

# setup-rime-scj.sh
# 自動設定 MiSans 字體、Chromium scale、fcitx5-rime + scj6/cangjie5

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RIME_DIR="$HOME/.local/share/fcitx5/rime"
CHROMIUM_FLAGS="$HOME/.config/chromium-flags.conf"
FONT_NAME="MiSans"
FONT_SIZE=10

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
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

# 檢查套件是否安裝
check_package() {
    pacman -Q "$1" &>/dev/null
}

# 檢查 rime-scj 是否安裝
check_rime_scj() {
    [[ -f "$RIME_DIR/scj6.schema.yaml" ]]
}

# 檢查 scj6.custom.yaml
check_scj6_custom() {
    if [[ -f "$RIME_DIR/scj6.custom.yaml" ]]; then
        grep -q "ascii_mode" "$RIME_DIR/scj6.custom.yaml" && \
        grep -q "reset: 1" "$RIME_DIR/scj6.custom.yaml"
    else
        return 1
    fi
}

# 檢查 default.custom.yaml
check_default_custom() {
    if [[ -f "$RIME_DIR/default.custom.yaml" ]]; then
        grep -q "schema: scj6" "$RIME_DIR/default.custom.yaml" && \
        grep -q "schema: cangjie5" "$RIME_DIR/default.custom.yaml"
    else
        return 1
    fi
}

# 安裝套件（如果需要）
install_package() {
    local pkg="$1"
    if check_package "$pkg"; then
        info "$pkg 已安裝，跳過"
        return 0
    fi
    
    info "正在安裝 $pkg..."
    if command -v paru &>/dev/null; then
        paru -S --noconfirm "$pkg"
    elif command -v yay &>/dev/null; then
        yay -S --noconfirm "$pkg"
    else
        sudo pacman -S --noconfirm "$pkg"
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
    
    info "GTK 字體設定完成"
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
        # 更新現有設定
        if grep -q "force-device-scale-factor" "$CHROMIUM_FLAGS"; then
            sed -i 's/force-device-scale-factor=.*/force-device-scale-factor=1/' "$CHROMIUM_FLAGS"
        else
            echo "--force-device-scale-factor=1" >> "$CHROMIUM_FLAGS"
        fi
    else
        # 建立新檔案
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

# 安裝 fcitx5-rime
setup_fcitx5_rime() {
    info "檢查 fcitx5-rime..."
    install_package "fcitx5-rime"
}

# 安裝 fcitx5-config-qt
setup_fcitx5_config() {
    info "檢查 fcitx5-config-qt..."
    install_package "fcitx5-config-qt"
}

# 安裝 rime-scj
setup_rime_scj() {
    info "檢查 rime-scj..."
    
    if check_rime_scj; then
        info "rime-scj 已安裝，跳過"
        return 0
    fi
    
    info "下載並安裝 rime-scj..."
    mkdir -p "$RIME_DIR"
    cd "$RIME_DIR"
    
    # 下載 rime-scj
    local temp_dir=$(mktemp -d)
    git clone --depth 1 https://github.com/rime/rime-scj.git "$temp_dir"
    
    # 複製檔案
    cp "$temp_dir"/*.yaml "$RIME_DIR/"
    
    # 清理
    rm -rf "$temp_dir"
    
    info "rime-scj 安裝完成"
}

# 設定 scj6.custom.yaml
setup_scj6_custom() {
    info "檢查 scj6.custom.yaml..."
    
    if check_scj6_custom; then
        info "scj6.custom.yaml 已設定，跳過"
        return 0
    fi
    
    info "建立 scj6.custom.yaml..."
    mkdir -p "$RIME_DIR"
    
    cat > "$RIME_DIR/scj6.custom.yaml" << 'EOF'
patch:
  switches:
    - name: ascii_mode
      reset: 1
      states: [ 中文, 西文 ]
EOF
    
    info "scj6.custom.yaml 建立完成"
}

# 設定 default.custom.yaml
setup_default_custom() {
    info "檢查 default.custom.yaml..."
    
    if check_default_custom; then
        info "default.custom.yaml 已設定，跳過"
        return 0
    fi
    
    info "建立 default.custom.yaml..."
    mkdir -p "$RIME_DIR"
    
    cat > "$RIME_DIR/default.custom.yaml" << 'EOF'
patch:
  schema_list:
    - schema: scj6
    - schema: cangjie5
  menu:
    page_size: 5
  switcher:
    hotkeys:
      - F4
  ascii_composer:
    switch_key:
      Shift_L: noop
      Shift_R: commit_code
      Control_L: noop
      Control_R: noop
      Caps_Lock: noop
      Eisu_toggle: noop
EOF
    
    info "default.custom.yaml 建立完成"
}

# 重新部署 Rime
redeploy_rime() {
    info "重新部署 Rime..."
    
    # 清除 build 目錄
    rm -rf "$RIME_DIR/build"
    
    # 重新啟動 fcitx5
    if pgrep -x "fcitx5" > /dev/null; then
        killall fcitx5 2>/dev/null || true
        sleep 1
    fi
    
    # 啟動 fcitx5
    fcitx5 -d &
    
    # 等待 build 完成
    local count=0
    while [[ $count -lt 30 ]]; do
        if [[ -d "$RIME_DIR/build" ]] && [[ -f "$RIME_DIR/build/scj6.schema.yaml" ]]; then
            info "Rime 重新部署完成"
            return 0
        fi
        sleep 1
        ((count++))
    done
    
    warn "等待 Rime 部署超時，可能需要手動重啟"
}

# 主程式
main() {
    info "開始設定 Rime + 快速倉頡..."
    
    local need_redeploy=false
    
    # 1. 設定字體
    if ! check_gtk_font; then
        setup_fonts
        need_redeploy=true
    fi
    
    # 2. 設定 Chromium
    if ! check_chromium_scale; then
        setup_chromium
    fi
    
    # 3. 安裝 fcitx5-rime
    if ! check_package "fcitx5-rime"; then
        setup_fcitx5_rime
        need_redeploy=true
    fi
    
    # 4. 安裝 fcitx5-config-qt
    if ! check_package "fcitx5-config-qt"; then
        setup_fcitx5_config
    fi
    
    # 5. 安裝 rime-scj
    if ! check_rime_scj; then
        setup_rime_scj
        need_redeploy=true
    fi
    
    # 6. 設定 scj6.custom.yaml
    if ! check_scj6_custom; then
        setup_scj6_custom
        need_redeploy=true
    fi
    
    # 7. 設定 default.custom.yaml
    if ! check_default_custom; then
        setup_default_custom
        need_redeploy=true
    fi
    
    # 7. 重新部署（如果需要）
    if $need_redeploy; then
        redeploy_rime
    else
        info "所有設定已完成，無需重新部署"
    fi
    
    info "設定完成！"
    info ""
    info "快捷鍵："
    info "  - F4: 切換輸入法方案"
    info "  - 右 Shift: 切換中英文"
    info "  - 快速倉頡 (scj6): 已設定為預設，啟動時為英文模式"
    info "  - 倉頡五代 (cangjie5): 已加入方案列表"
}

# 執行主程式
main "$@"
