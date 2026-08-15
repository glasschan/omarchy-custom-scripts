#!/bin/bash

# setup-looknfeel.sh
# Hyprland 視覺與動畫設定 (Omarchy v4 Lua 設定)
# - macOS 風格白色透明邊框
# - 圓角視窗 (10px)
# - 大範圍柔和陰影 (macOS 風格)
# - 明亮毛玻璃效果 (vibrancy)
# - 快速彈簧動畫 (macSpring)
# 以 marker 區塊附加到 ~/.config/hypr/looknfeel.lua，唔會重寫整個檔案
# Category: 系統設定
# Description: Hyprland Look & Feel (macOS 風格佈景)

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 載入共用函式庫
source "$SCRIPT_DIR/lib/common.sh"

# 設定檔路徑
LOOKNFEEL_LUA="$HOME/.config/hypr/looknfeel.lua"

BEGIN_MARKER="-- BEGIN macOS looknfeel settings (setup-looknfeel.sh)"
END_MARKER="-- END macOS looknfeel settings (setup-looknfeel.sh)"

# 檢查是否已安裝
is_installed() {
    [[ -f "$LOOKNFEEL_LUA" ]] && grep -qF -- "$BEGIN_MARKER" "$LOOKNFEEL_LUA"
}

# 移除區塊（區塊永遠附加在檔尾：由 BEGIN 行起刪到 EOF）
strip_block() {
    local first_line
    first_line=$(grep -n -F -- "$BEGIN_MARKER" "$LOOKNFEEL_LUA" | cut -d: -f1 | head -1)
    [[ -z "$first_line" ]] && return 0

    local cut_line=$first_line
    if (( cut_line > 1 )) && [[ -z "$(sed -n "$((cut_line - 1))p" "$LOOKNFEEL_LUA")" ]]; then
        cut_line=$((cut_line - 1))
    fi
    sed -i "${cut_line},\$d" "$LOOKNFEEL_LUA"
}

# 安裝設定
install() {
    info "開始設定 Hyprland Look & Feel..."

    # -f/--force: 跳過存在性檢查，強制重新套用（用於手動改壞咗之後還原）
    local force=false
    [[ "$1" == "-f" || "$1" == "--force" ]] && force=true

    if ! $force; then
        if is_installed; then
            warn "Look & Feel 設定似乎已經套用，跳過重複設定（用 -f 強制重新套用）"
            return
        fi
    fi

    mkdir -p "$(dirname "$LOOKNFEEL_LUA")"
    create_backup "$LOOKNFEEL_LUA"

    # -f 時先移除舊區塊再重加
    strip_block

    # 附加自訂 Look & Feel 設定（用戶檔案在 Omarchy 預設之後載入，覆蓋生效）
    cat >>"$LOOKNFEEL_LUA" <<'EOF'

-- BEGIN macOS looknfeel settings (setup-looknfeel.sh)
-- macOS-like look'n'feel for Omarchy Hyprland (v4 Lua)
--
-- Omarchy defaults being overridden:
--   gaps_in=5, gaps_out=10, border_size=2, colored active border
--   rounding=0, shadow disabled, blur disabled
--   animations: very slow (windows 3.79s, fade 1.73s)

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
hl.config({
  general = {
    -- Border: 1px hairline (down from 2). macOS has 0, but 1px helps in tiling.
    -- Border colors: nearly-transparent white (macOS has no colored borders;
    -- focused window distinction comes from shadow depth).
    border_size = 1,
    col = {
      active_border = "rgba(ffffff18)",   -- ~9% opacity white
      inactive_border = "rgba(ffffff0d)", -- ~5% opacity white
    },

    -- Resize by dragging window edges/corners — standard macOS behavior.
    resize_on_border = true,
  },
})

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
hl.config({
  decoration = {
    -- Rounding: 10px (macOS standard for most windows)
    rounding = 10,

    -- Shadow: large and soft — the primary focus indicator in macOS.
    shadow = {
      enabled = true,
      range = 20,             -- was 0 (disabled). Large spread for soft shadow.
      render_power = 4,       -- Max quality for smoothest falloff.
      color = "rgba(00000050)", -- Light, translucent.
    },

    -- Blur: bright and clean — macOS vibrancy preserves content brightness.
    blur = {
      enabled = true,
      size = 4,        -- Smoother spread.
      passes = 3,      -- Better quality.
      special = true,
      brightness = 0.90, -- Much brighter, closer to macOS vibrancy.
      contrast = 0.85,
      vibrancy = 0.10,  -- Subtle saturation boost like macOS.
      noise = 0.0,      -- macOS blur is clean.
    },

    -- Dim inactive: 關閉 — 滑鼠 focus 轉移時唔想睇到視窗變暗。
    dim_inactive = false,
    dim_strength = 0.0,

    -- Opacity: 1.0 at decoration level. Tag-based opacity rules in Omarchy
    -- defaults (0.985/0.96) still apply — dim_inactive is off by user preference.
    active_opacity = 1.0,
    inactive_opacity = 1.0,
  },
})

-- Group/tab borders must match the main window border style.
hl.config({
  group = {
    col = {
      border_active = "rgba(ffffff18)",
      border_inactive = "rgba(ffffff0d)",
    },
  },
})

-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
-- macOS animations are snappy spring-based, 200–400ms.
-- Omarchy defaults are 3–4 seconds — we override all of them.

-- Bezier curves:
--   macSpring — slight overshoot like macOS spring physics
--   macOut    — clean ease-out for exits (no overshoot on close)
--   macFade   — gentle ease-out for fades
hl.curve("macSpring", { type = "bezier", points = { { 0.22, 1.05 }, { 0.36, 1 } } })
hl.curve("macOut", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.curve("macFade", { type = "bezier", points = { { 0.25, 0.1 }, { 0.25, 1 } } })

-- Global fallback: 300ms
hl.animation({ leaf = "global", enabled = true, speed = 3, bezier = "default" })

-- Windows: ~300ms with spring. was 3.79s.
hl.animation({ leaf = "windows", enabled = true, speed = 3, bezier = "macSpring" })

-- Window open: scale-in with bounce. was 4.1s.
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, bezier = "macSpring", style = "popin 87%" })

-- Window close: slightly faster. was 1.49s.
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "macOut", style = "popin 87%" })

-- Fades: quick opacity transitions. were ~1.5–1.7s.
hl.animation({ leaf = "fadeIn", enabled = true, speed = 2, bezier = "macFade" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.5, bezier = "macFade" })
hl.animation({ leaf = "fade", enabled = true, speed = 2, bezier = "macFade" })

-- Border color transition. was 5.39s.
hl.animation({ leaf = "border", enabled = true, speed = 2, bezier = "macFade" })

-- Layers (notifications, bars, etc.). was 3.81s.
hl.animation({ leaf = "layers", enabled = true, speed = 3, bezier = "macSpring" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 3, bezier = "macSpring", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2, bezier = "macOut", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 2, bezier = "macFade" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.5, bezier = "macFade" })

-- Workspace switch: subtle slide. Omarchy default: disabled.
hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "macFade", style = "slide" })

-- Special workspace (scratchpad). was 3s.
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, bezier = "macOut", style = "slidevert" })
-- END macOS looknfeel settings (setup-looknfeel.sh)
EOF

    info "Look & Feel 設定已附加至 $LOOKNFEEL_LUA"
    info "Hyprland 會自動重新載入設定"

    echo
    info "=============================="
    info "設定完成!"
    info "=============================="
    echo
    echo "套用的設定："
    echo "  🍎 macOS 風格佈景主題"
    echo "  🤍 近乎透明的白色邊框 (1px)"
    echo "  🖼️  大範圍柔和陰影 (焦點辨識)"
    echo "  ✨ 明亮毛玻璃 (macOS vibrancy)"
    echo "  🌑 未聚焦視窗不暗化"
    echo "  ⚡ 快速彈簧動畫 (macSpring)"
    echo "  🖱️  邊框拖曳調整大小"
    echo
}

# 還原設定
uninstall() {
    info "還原 Look & Feel 設定..."

    if [ ! -f "$LOOKNFEEL_LUA" ]; then
        warn "找不到 $LOOKNFEEL_LUA"
        return 0
    fi

    # 移除我們的自訂設定 (透過 marker 判斷)
    if is_installed; then
        strip_block
        info "已移除自訂設定（looknfeel.lua 回復 Omarchy v4 範本 + 預設）"
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

    if [[ -f "$LOOKNFEEL_LUA" ]]; then
        if is_installed; then
            echo -e "  ${GREEN}✓${NC} 自訂 Look & Feel 已套用"
        else
            echo -e "  ${YELLOW}!${NC} 使用 Omarchy 預設 Look & Feel"
        fi

        # 顯示目前生效的設定（來自 hyprctl，而非檔案內容）
        local ROUNDING=$(hyprctl getoption decoration:rounding 2>/dev/null | awk '/^int:/{print $2}')
        local BORDER_SIZE=$(hyprctl getoption general:border_size 2>/dev/null | awk '/^int:/{print $2}')
        local BORDER_RESIZE=$(hyprctl getoption general:resize_on_border 2>/dev/null | awk '/^bool:/{print $2}')
        echo -e "  ${CYAN}ℹ${NC}  圓角: $ROUNDING px / 邊框: $BORDER_SIZE px / 邊框調整: $BORDER_RESIZE"
    else
        echo -e "  ${RED}✗${NC} looknfeel.lua 不存在"
    fi
}

# 使用說明
usage() {
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "Options:"
    echo "  -i, --install     安裝/套用設定 (預設)"
    echo "  -f, --force       強制重新套用（跳過重複檢查，還原被手動修改嘅設定）"
    echo "  -u, --uninstall   還原設定 (回復 Omarchy 預設)"
    echo "  -s, --status      顯示目前狀態"
    echo "  -h, --help        顯示此說明"
    echo ""
}

# 主程式
main() {
    case "${1:-}" in
        -u | --uninstall)
            uninstall
            ;;
        -s | --status)
            show_status
            ;;
        -h | --help)
            usage
            ;;
        -f | --force)
            install --force
            ;;
        -i | --install | "")
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
