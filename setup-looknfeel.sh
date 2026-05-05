#!/bin/bash

# setup-looknfeel.sh
# Hyprland 視覺與動畫設定
# - macOS 風格白色透明邊框
# - 圓角視窗 (10px)
# - 大範圍柔和陰影 (macOS 風格)
# - 明亮毛玻璃效果 (vibrancy)
# - 快速彈簧動畫 (macSpring)
# Category: 系統設定
# Description: Hyprland Look & Feel (macOS 風格佈景)

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 載入共用函式庫
source "$SCRIPT_DIR/lib/common.sh"

# 設定檔路徑
HYPR_LOOKNFEEL="$HOME/.config/hypr/looknfeel.conf"

# 檢查設定檔是否存在
check_config_exists() {
    if [ ! -f "$HYPR_LOOKNFEEL" ]; then
        error "找不到 $HYPR_LOOKNFEEL"
        exit 1
    fi
}

# 檢查是否已安裝
is_installed() {
    grep -q "Custom looknfeel settings by setup-looknfeel.sh" "$HYPR_LOOKNFEEL"
}

# 安裝設定
install() {
    info "開始設定 Hyprland Look & Feel..."

    check_config_exists

    if is_installed; then
        warn "Look & Feel 設定似乎已經套用，跳過重複設定"
        return
    fi

    # 備份原始設定
    create_backup "$HYPR_LOOKNFEEL"

    # 寫入自訂 Look & Feel 設定
cat > "$HYPR_LOOKNFEEL" << 'EOF'
# Custom looknfeel settings by setup-looknfeel.sh

# macOS-like look'n'feel for Omarchy Hyprland
#
# Omarchy defaults being overridden:
#   gaps_in=5, gaps_out=10, border_size=2, orange active border, dark gray inactive border
#   rounding=0, shadow(range=2, render_power=3), blur(brightness=0.60, contrast=0.75)
#   animations: very slow (windows 3.79s, fade 1.73s)
# Theme: col.active_border = rgb(faa968) (golden/orange accent)

# -- Border colors --
# macOS has no colored borders. Focused window distinction comes from shadow depth.
# These are nearly-transparent white for minimal tiling separation.
$macBorder = rgba(ffffff18)        # ~9% opacity white — barely visible
$macBorderInactive = rgba(ffffff0d) # ~5% opacity white — even more subtle

# https://wiki.hyprland.org/Configuring/Variables/#general
general {
    # Gaps: keep Omarchy defaults (5 inner / 10 outer). Clean and moderate.
    # gaps_in = 5
    # gaps_out = 10

    # Border: 1px hairline (down from 2). macOS has 0, but 1px helps in tiling.
    border_size = 5

    # Border colors: nearly invisible, overriding the orange theme.
    col.active_border = $macBorder
    col.inactive_border = $macBorderInactive

    # Resize by dragging window edges/corners — standard macOS behavior.
    resize_on_border = true
}

# https://wiki.hyprland.org/Configuring/Variables/#decoration
decoration {
    # Rounding: 10px (macOS standard for most windows)
    rounding = 10

    # Shadow: large and soft — the primary focus indicator in macOS.
    shadow {
        enabled = true
        range = 20            # was 2. Large spread for soft, prominent shadow.
        render_power = 4      # was 3. Max quality for smoothest falloff.
        color = rgba(00000050) # was rgba(1a1a1aee). Lighter, more translucent.
    }

    # Blur: bright and clean — macOS vibrancy preserves content brightness.
    blur {
        enabled = true
        size = 4              # was 2. Smoother spread.
        passes = 3            # was 2. Better quality.
        special = true
        brightness = 0.90     # was 0.60. Much brighter, closer to macOS vibrancy.
        contrast = 0.85       # was 0.75. Sharper text through blur.
        vibrancy = 0.10       # was unset. Subtle saturation boost like macOS.
        noise = 0.0           # macOS blur is clean.
    }

    # Dim inactive: THE key macOS-like setting.
    # Unfocused windows get subtly darkened so the active one pops.
    dim_inactive = true
    dim_strength = 0.15      # 0.0 = none, 1.0 = full black. Tune 0.10–0.20.

    # Opacity: both 1.0 at decoration level. The tag-based opacity rules
    # in windows.conf (0.97/0.90) still apply, but dim_inactive is the
    # primary focus indicator here — exactly how macOS does it.
    active_opacity = 1.0
    inactive_opacity = 1.0
}

# https://wiki.hyprland.org/Configuring/Variables/#animations
animations {
    # macOS animations are snappy spring-based, 200–400ms.
    # Omarchy defaults are 3–4 seconds — we override all of them.
    # Speed unit: deciseconds (3 = 300ms).
    enabled = yes

    # Bezier curves:
    #   macSpring  — slight overshoot like macOS spring physics
    #   macOut     — clean ease-out for exits (no overshoot on close)
    #   macFade    — gentle ease-out for fades
    bezier = macSpring, 0.22, 1.05, 0.36, 1
    bezier = macOut, 0.16, 1, 0.3, 1
    bezier = macFade, 0.25, 0.1, 0.25, 1

    # Global fallback: 300ms
    animation = global, 1, 3, default

    # Windows: ~300ms with spring. was 3.79s.
    animation = windows, 1, 3, macSpring

    # Window open: scale-in with bounce. was 4.1s.
    animation = windowsIn, 1, 3, macSpring, popin 87%

    # Window close: slightly faster. was 1.49s.
    animation = windowsOut, 1, 2, macOut, popin 87%

    # Fades: quick opacity transitions. were ~1.5–1.7s.
    animation = fadeIn, 1, 2, macFade
    animation = fadeOut, 1, 1.5, macFade
    animation = fade, 1, 2, macFade

    # Border color transition. was 5.39s.
    animation = border, 1, 2, macFade

    # Layers (notifications, bars, etc.). was 3.81s.
    animation = layers, 1, 3, macSpring
    animation = layersIn, 1, 3, macSpring, fade
    animation = layersOut, 1, 2, macOut, fade
    animation = fadeLayersIn, 1, 2, macFade
    animation = fadeLayersOut, 1, 1.5, macFade

    # Workspace switch: subtle slide. was instant.
    animation = workspaces, 1, 3, macFade, slide

    # Special workspace (scratchpad). was 3s.
    animation = specialWorkspace, 1, 3, macOut, slidevert
}

# https://wiki.hyprland.org/Configuring/Dwindle-Layout/
dwindle {
    # Pseudotile: kept enabled (Omarchy default).
    # Windows float within their tile rather than stretching edge-to-edge —
    # this is more macOS-like than filling the entire tile area.
    # Toggle with Super+P if you need a window to fill its tile.
    # pseudotile = true
}

# Group/tab borders must match the main window border style.
group {
    col.border_active = $macBorder
    col.border_inactive = $macBorderInactive
}
EOF

    info "Look & Feel 設定已套用至 $HYPR_LOOKNFEEL"
    info "Hyprland 會自動重新載入設定"

    echo
    info "=============================="
    info "設定完成!"
    info "=============================="
    echo
    echo "套用的設定："
    echo "  🍎 macOS 風格佈景主題"
    echo "  🤍 近乎透明的白色邊框"
    echo "  🖼️  大範圍柔和陰影 (焦點辨識)"
    echo "  ✨ 明亮毛玻璃 (macOS vibrancy)"
    echo "  🌑 未聚焦視窗暗化 (細緻版)"
    echo "  ⚡ 快速彈簧動畫 (macSpring)"
    echo "  🖱️  邊框拖曳調整大小"
    echo
}

# 還原設定
uninstall() {
    info "還原 Look & Feel 設定..."

    if [ ! -f "$HYPR_LOOKNFEEL" ]; then
        warn "找不到 $HYPR_LOOKNFEEL"
        return 0
    fi

    # 移除我們的自訂設定 (透過 marker 判斷)
    if is_installed; then
        # 從 Omarchy 預設複製回來
        OARCHY_DEFAULT="$HOME/.local/share/omarchy/default/hypr/looknfeel.conf"
        if [ -f "$OARCHY_DEFAULT" ]; then
            cp "$OARCHY_DEFAULT" "$HYPR_LOOKNFEEL"
            info "已從 Omarchy 預設還原 looknfeel.conf"
        else
            warn "找不到 Omarchy 預設設定，手動還原可能需要"
        fi
    else
        info "沒有找到自訂 Look & Feel 設定，跳過"
    fi

    echo
    info "還原完成！"
    echo
}

# 顯示狀態
show_status() {
    echo -e "${CYAN}Look & Feel 設定狀態:${NC}"

    if [[ -f "$HYPR_LOOKNFEEL" ]]; then
        if is_installed; then
            echo -e "  ${GREEN}✓${NC} 自訂 Look & Feel 已套用"
        else
            echo -e "  ${YELLOW}!${NC} 使用 Omarchy 預設 Look & Feel"
        fi

        # 顯示目前的圓角設定
        local ROUNDING=$(grep -E '^[[:space:]]*rounding' "$HYPR_LOOKNFEEL" | head -1 | tr -d ' ' | cut -d'=' -f2)
        local BORDER_RESIZE=$(grep -E 'resize_on_border' "$HYPR_LOOKNFEEL" | head -1 | tr -d ' ' | cut -d'=' -f2)
        echo -e "  ${CYAN}ℹ${NC}  圓角大小: $ROUNDING px"
        echo -e "  ${CYAN}ℹ${NC}  邊框調整大小: $BORDER_RESIZE"
    else
        echo -e "  ${RED}✗${NC} looknfeel.conf 不存在"
    fi
}

# 使用說明
usage() {
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "Options:"
    echo "  -i, --install     安裝/套用設定 (預設)"
    echo "  -u, --uninstall   還原設定 (回復 Omarchy 預設)"
    echo "  -s, --status      顯示目前狀態"
    echo "  -h, --help        顯示此說明"
    echo ""
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
