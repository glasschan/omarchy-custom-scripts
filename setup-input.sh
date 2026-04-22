#!/bin/bash

# setup-input.sh
# 設定 fcitx5-rime + 快速倉頡輸入法

set -e

SCRIPT_NAME="$(basename "$0")"
RIME_DIR="$HOME/.local/share/fcitx5/rime"

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
    
    local temp_dir=$(mktemp -d)
    git clone --depth 1 https://github.com/rime/rime-scj.git "$temp_dir"
    
    cp "$temp_dir"/*.yaml "$RIME_DIR/"
    rm -rf "$temp_dir"
    
    detail "已安裝檔案:"
    ls -la "$RIME_DIR"/scj6.* | sed 's/^/  /'
    
    info "rime-scj 安裝完成"
}

# 移除 rime-scj
remove_rime_scj() {
    info "移除 rime-scj..."
    rm -f "$RIME_DIR"/scj6.*
    info "rime-scj 已移除"
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
    
    detail "scj6.custom.yaml 內容:"
    cat "$RIME_DIR/scj6.custom.yaml" | sed 's/^/  /'
    
    info "scj6.custom.yaml 建立完成"
}

# 移除 scj6.custom.yaml
remove_scj6_custom() {
    info "移除 scj6.custom.yaml..."
    rm -f "$RIME_DIR/scj6.custom.yaml"
    info "scj6.custom.yaml 已移除"
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
    
    detail "default.custom.yaml 內容:"
    cat "$RIME_DIR/default.custom.yaml" | sed 's/^/  /'
    
    info "default.custom.yaml 建立完成"
}

# 移除 default.custom.yaml
remove_default_custom() {
    info "移除 default.custom.yaml..."
    rm -f "$RIME_DIR/default.custom.yaml"
    info "default.custom.yaml 已移除"
}

# 重新部署 Rime
redeploy_rime() {
    info "重新部署 Rime..."

    rm -rf "$RIME_DIR/build"

    if pgrep -x "fcitx5" > /dev/null; then
        info "停止 fcitx5..."
        killall fcitx5 2>/dev/null || true
        sleep 1
    fi

    info "啟動 fcitx5 並等待部署完成..."
    fcitx5 -d &
    sleep 1

    local count=0
    while [[ $count -lt 10 ]]; do
        if [[ -d "$RIME_DIR/build" ]] && [[ -f "$RIME_DIR/build/scj6.schema.yaml" ]]; then
            info "Rime 部署完成"
            return 0
        fi
        sleep 1
        ((count++))
    done

    warn "等待 Rime 部署超時，請手動重啟 fcitx5"
}

# 安裝模式
install() {
    info "開始設定 fcitx5-rime + 快速倉頡..."
    
    local need_redeploy=false
    
    if ! check_package "fcitx5-rime"; then
        setup_fcitx5_rime
        need_redeploy=true
    fi
    
    if ! check_package "fcitx5-config-qt"; then
        setup_fcitx5_config
    fi
    
    if ! check_rime_scj; then
        setup_rime_scj
        need_redeploy=true
    fi
    
    if ! check_scj6_custom; then
        setup_scj6_custom
        need_redeploy=true
    fi
    
    if ! check_default_custom; then
        setup_default_custom
        need_redeploy=true
    fi
    
    if $need_redeploy; then
        redeploy_rime
    else
        info "所有設定已完成，無需重新部署"
    fi
    
    info ""
    info "設定完成！"
    info "快捷鍵："
    info "  - F4: 切換輸入法方案"
    info "  - 右 Shift: 切換中英文"
    info "  - 快速倉頡 (scj6): 已設定為預設，啟動時為英文模式"
    info "  - 倉頡五代 (cangjie5): 已加入方案列表"
}

# 解除安裝模式
uninstall() {
    info "開始還原 fcitx5-rime 設定..."
    
    remove_scj6_custom
    remove_default_custom
    remove_rime_scj
    
    info "fcitx5-rime 設定已還原！"
    info "注意: fcitx5-rime 套件未被移除，如需移除請手動執行:"
    info "  sudo pacman -R fcitx5-rime fcitx5-config-qt"
}

# 使用說明
usage() {
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "Options:"
    echo "  -i, --install     安裝/設定輸入法 (預設)"
    echo "  -u, --uninstall   還原輸入法設定"
    echo "  -h, --help        顯示此說明"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME              # 設定輸入法"
    echo "  $SCRIPT_NAME -u           # 還原輸入法"
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
