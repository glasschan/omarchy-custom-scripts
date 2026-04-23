#!/bin/bash

# setup-gaming.sh
# 設定 Hyprland 遊戲相容性（修復 Unity 遊戲無視窗問題）

set -e

SCRIPT_NAME="$(basename "$0")"
HYPR_CONFIG_DIR="$HOME/.config/hypr"
HYPRLAND_CONF="$HYPR_CONFIG_DIR/hyprland.conf"
ENVS_CONF="$HYPR_CONFIG_DIR/envs.conf"
GAMES_CONF="$HYPR_CONFIG_DIR/games.conf"

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

header() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
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

# 檢查設定檔是否包含特定內容
config_contains() {
    local file="$1"
    local pattern="$2"
    [[ -f "$file" ]] && grep -q "$pattern" "$file"
}

# 安裝 gamescope
setup_gamescope() {
    info "檢查 gamescope..."
    install_package "gamescope"
    info "gamescope 安裝完成！"
    detail "Steam 遊戲啟動選項: gamescope -W 1920 -H 1080 -f -- %command%"
}

# 建立環境變數設定
setup_envs_conf() {
    info "檢查遊戲環境變數設定..."

    if config_contains "$ENVS_CONF" "SDL_VIDEODRIVER"; then
        info "遊戲環境變數已設定，跳過"
        return 0
    fi

    info "建立遊戲環境變數設定..."
    mkdir -p "$HYPR_CONFIG_DIR"

    cat >> "$ENVS_CONF" << 'EOF'

# 遊戲相容性設定
# 強制 SDL 遊戲使用 X11/XWayland（解決 Unity 遊戲無視窗問題）
env = SDL_VIDEODRIVER,x11,wayland

# Unity 遊戲修復
env = UNITY_FORCE_DISPLAY,0
env = UNITY_DISABLE_XRANDR,1

# Proton/Steam 遊戲修復
env = PROTON_USE_WINED3D,0
EOF

    detail "envs.conf 已更新:"
    grep -A 8 "遊戲相容性" "$ENVS_CONF" | sed 's/^/  /'

    info "遊戲環境變數設定完成"
}

# 建立遊戲視窗規則
setup_games_conf() {
    info "檢查遊戲視窗規則..."

    if [[ -f "$GAMES_CONF" ]]; then
        info "遊戲視窗規則已存在，跳過"
        return 0
    fi

    info "建立遊戲視窗規則..."
    mkdir -p "$HYPR_CONFIG_DIR"

    cat > "$GAMES_CONF" << 'EOF'
# 遊戲專用視窗規則

# Skul: The Hero Slayer (Unity)
windowrule = float on, match:class ^Skul$
windowrule = center on, match:class ^Skul$
EOF

    detail "games.conf 內容:"
    cat "$GAMES_CONF" | sed 's/^/  /'

    info "遊戲視窗規則建立完成"
}

# 確保設定檔有正確的 source
setup_hyprland_conf() {
    info "檢查 hyprland.conf 設定..."

    local need_reload=false

    # 加入 envs.conf source
    if ! config_contains "$HYPRLAND_CONF" "source.*envs.conf"; then
        info "加入 envs.conf 到 hyprland.conf..."
        sed -i '/^source.*autostart.conf/a source = ~\/.config\/hypr\/envs.conf' "$HYPRLAND_CONF"
        need_reload=true
    fi

    # 加入 games.conf source
    if ! config_contains "$HYPRLAND_CONF" "source.*games.conf"; then
        info "加入 games.conf 到 hyprland.conf..."
        sed -i '/^source.*envs.conf/a source = ~\/.config\/hypr\/games.conf' "$HYPRLAND_CONF"
        need_reload=true
    fi

    if $need_reload; then
        info "重新載入 Hyprland 設定..."
        hyprctl reload 2>/dev/null || true
        sleep 1
        info "Hyprland 設定已重新載入"
    else
        info "hyprland.conf 設定正確，無需變更"
    fi
}

# 解除安裝模式
uninstall() {
    info "開始還原遊戲設定..."

    info "移除 games.conf..."
    rm -f "$GAMES_CONF"

    info "移除 envs.conf 中的遊戲設定..."
    if [[ -f "$ENVS_CONF" ]]; then
        sed -i '/^# 遊戲相容性設定/,/^env = PROTON_USE_WINED3D,0$/d' "$ENVS_CONF"
        # 如果檔案變空就刪除
        if [[ ! -s "$ENVS_CONF" ]]; then
            rm -f "$ENVS_CONF"
        fi
    fi

    info "移除 hyprland.conf 中的 games.conf source..."
    sed -i '/source.*games.conf/d' "$HYPRLAND_CONF"

    info "重新載入 Hyprland 設定..."
    hyprctl reload 2>/dev/null || true

    info "遊戲設定已還原！"
    info "注意: gamescope 套件未被移除，如需移除請手動執行:"
    info "  sudo pacman -R gamescope"
}

# 使用說明
usage() {
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "Options:"
    echo "  -i, --install     安裝/設定遊戲相容性 (預設)"
    echo "  -u, --uninstall   還原遊戲相容性設定"
    echo "  -h, --help        顯示此說明"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME              # 設定遊戲相容性"
    echo "  $SCRIPT_NAME -u           # 還原遊戲相容性設定"
    echo ""
    echo "安裝後設定:"
    echo "  - Steam 遊戲啟動選項使用: gamescope -W 1920 -H 1080 -f -- %command%"
    echo "  - 此設定可修復 Unity 遊戲（如 Skul）無視窗問題"
}

# 安裝模式
install() {
    info "開始設定 Hyprland 遊戲相容性..."
    echo ""

    setup_gamescope
    echo ""

    setup_envs_conf
    echo ""

    setup_games_conf
    echo ""

    setup_hyprland_conf
    echo ""

    header "遊戲相容性設定完成！"
    echo ""
    info "使用方式:"
    info "  在 Steam 中對遊戲按右鍵 → 內容 → 啟動選項:"
    info "  gamescope -W 1920 -H 1080 -f -- %command%"
    echo ""
    info "  此設定會將遊戲包在 gamescope 微合成器中，解決 Wayland 相容性問題"
    info "  適用於: Skul, Hollow Knight, Celeste, 以及大部分 Unity/SDL 遊戲"
    echo ""

    read -p "要複製啟動選項到剪貼簿嗎？ (y/N): " copy_confirm
    if [[ "$copy_confirm" == "y" || "$copy_confirm" == "Y" ]]; then
        echo -n "gamescope -W 1920 -H 1080 -f -- %command%" | wl-copy
        info "已複製到剪貼簿！"
        info "現在可以在 Steam 中貼上到遊戲的啟動選項"
    fi
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
