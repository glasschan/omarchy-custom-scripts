#!/bin/bash

# setup-keybindings.sh
# 設定自訂快捷鍵 - 截圖、錄影、剪貼簿管理 (Omarchy v4 Lua 設定)
# - ALT SHIFT + Q: 區域截圖
# - ALT SHIFT + E: 視窗截圖
# - ALT SHIFT + F: 全螢幕截圖
# - ALT SHIFT + R: 螢幕錄影
# - ALT SHIFT CTRL + R: 螢幕錄影 (含攝影機)
# - ALT SHIFT + A: 顏色選擇器
# - ALT SHIFT + O: OCR 文字辨識
# - CTRL + `: 開啟剪貼簿管理員 (Omarchy v4 內建)
# 以 marker 區塊附加到 ~/.config/hypr/bindings.lua，唔會重寫整個檔案
# Category: 快捷鍵
# Description: 設定截圖/錄影/剪貼簿快捷鍵

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared library
source "$SCRIPT_DIR/lib/common.sh"

BINDINGS_LUA="$HOME/.config/hypr/bindings.lua"

BEGIN_MARKER="-- BEGIN custom keybindings (setup-keybindings.sh)"
END_MARKER="-- END custom keybindings (setup-keybindings.sh)"
OCR_BIND_MARKER='Extract text (OCR)'
OCR_PKG="tesseract-data-chi_tra"
OCR_READY=0

# 檢查依賴（OCR 語言包係可選依賴，另由 ensure_ocr_lang 處理）
check_dependencies() {
    info "檢查依賴..."

    if ! command -v omarchy-capture-screenshot &>/dev/null; then
        error "omarchy-capture-screenshot 未安裝（需要 Omarchy v4）"
        exit 1
    fi

    info "依賴檢查完成"
}

# OCR 語言包（可選）：缺失時經 install_package 補裝；補裝失敗唔中止安裝
check_ocr_lang() {
    tesseract --list-langs 2>/dev/null | grep -q "chi_tra"
}

ensure_ocr_lang() {
    if check_ocr_lang; then
        OCR_READY=1
        return 0
    fi

    warn "偵測不到 tesseract chi_tra 語言包，經 install_package 補裝 $OCR_PKG ..."
    install_package "$OCR_PKG"

    if check_ocr_lang; then
        OCR_READY=1
    else
        warn "$OCR_PKG 補裝後仍缺 chi_tra；OCR 快捷鍵暫不安裝，其餘快捷鍵照常設定（補裝成功後重跑 -i 即可加上）"
    fi
}

# 檢查是否已安裝
is_installed() {
    [[ -f "$BINDINGS_LUA" ]] && grep -qF -- "$BEGIN_MARKER" "$BINDINGS_LUA"
}

# 移除區塊（區塊永遠附加在檔尾：由 BEGIN 行起刪到 EOF）
strip_block() {
    local first_line
    first_line=$(grep -n -F -- "$BEGIN_MARKER" "$BINDINGS_LUA" | cut -d: -f1 | head -1)
    [[ -z "$first_line" ]] && return 0

    local cut_line=$first_line
    if (( cut_line > 1 )) && [[ -z "$(sed -n "$((cut_line - 1))p" "$BINDINGS_LUA")" ]]; then
        cut_line=$((cut_line - 1))
    fi
    sed -i "${cut_line},\$d" "$BINDINGS_LUA"
}

# 附加自訂快捷鍵區塊（OCR 部分視乎 OCR_READY 決定是否寫入）
append_block() {
    cat >>"$BINDINGS_LUA" <<'EOF'

-- BEGIN custom keybindings (setup-keybindings.sh)
-- 截圖（v4 預設 PRINT 已有截圖；以下係 ALT SHIFT 組合鍵）
o.bind("ALT + SHIFT + Q", "Screenshot (region)", "omarchy-capture-screenshot region")
o.bind("ALT + SHIFT + E", "Screenshot (window)", "omarchy-capture-screenshot windows")
o.bind("ALT + SHIFT + F", "Screenshot (fullscreen)", "omarchy-capture-screenshot fullscreen")

-- Color picker
o.bind("ALT + SHIFT + A", "Color picker", "pkill hyprpicker || hyprpicker -a")

-- Screen recording
o.bind("ALT + SHIFT + R", "Screen recording", "omarchy-capture-screenrecording")
o.bind("ALT + SHIFT + CTRL + R", "Screen recording (with camera)", "omarchy-capture-screenrecording --with-webcam")

-- Clipboard manager (Omarchy v4 內建剪貼簿，取代 v3 walker + elephant)
o.bind("CTRL + grave", "Clipboard manager", "omarchy-shell shell toggle omarchy.clipboard")
EOF

    if (( OCR_READY )); then
        cat >>"$BINDINGS_LUA" <<'EOF'

-- OCR text extraction (中英混合)
o.bind("ALT + SHIFT + O", "Extract text (OCR)", "env OMARCHY_OCR_LANGS=eng+chi_tra omarchy-capture-text")
EOF
    fi

    cat >>"$BINDINGS_LUA" <<'EOF'
-- END custom keybindings (setup-keybindings.sh)
EOF
}

# 新增自訂快捷鍵到 hyprland (v4 Lua)
setup_hypr_keybindings() {
    info "附加自訂快捷鍵到 ~/.config/hypr/bindings.lua..."

    if is_installed; then
        # 區塊已存在但缺 OCR 快捷鍵，而家語言包就緒：安全條件下重寫本區塊補上
        if (( OCR_READY )) && ! grep -qF -- "$OCR_BIND_MARKER" "$BINDINGS_LUA"; then
            local last_line
            last_line="$(tail -n 1 "$BINDINGS_LUA")"
            if [[ "$last_line" == *"$END_MARKER"* ]]; then
                info "OCR 語言包已就緒，補上 OCR 快捷鍵"
                create_backup "$BINDINGS_LUA"
                strip_block
                append_block
                info "快捷鍵已附加至 $BINDINGS_LUA"
                info "Hyprland 會自動重新載入設定"
            else
                warn "bindings.lua 於本區塊之後有其他內容，無法自動補上 OCR 快捷鍵（請先 -u 再 -i）"
            fi
            return
        fi
        info "自訂快捷鍵已存在，無需重複新增"
        return
    fi

    mkdir -p "$(dirname "$BINDINGS_LUA")"
    create_backup "$BINDINGS_LUA"
    append_block

    info "快捷鍵已附加至 $BINDINGS_LUA"
    info "Hyprland 會自動重新載入設定"
}

# 還原設定
uninstall() {
    info "還原自訂快捷鍵設定..."

    if [ ! -f "$BINDINGS_LUA" ]; then
        warn "找不到 $BINDINGS_LUA"
        return 0
    fi

    if is_installed; then
        strip_block
        info "已從 $BINDINGS_LUA 移除自訂快捷鍵"
    else
        info "沒有找到已加入的自訂快捷鍵，跳過"
    fi

    echo
    info "還原完成！"
    echo
}

# 顯示狀態
show_status() {
    echo -e "${CYAN}自訂快捷鍵設定狀態:${NC}"

    if [[ -f "$BINDINGS_LUA" ]]; then
        if is_installed; then
            echo -e "  ${GREEN}✓${NC} 自訂快捷鍵已安裝"

            if grep -qF -- "$OCR_BIND_MARKER" "$BINDINGS_LUA"; then
                if check_ocr_lang; then
                    echo -e "  ${GREEN}✓${NC} OCR 快捷鍵已就緒 (chi_tra)"
                else
                    echo -e "  ${YELLOW}!${NC} OCR 快捷鍵未就緒（缺 $OCR_PKG 語言包，重跑 -i 可補裝）"
                fi
            else
                if check_ocr_lang; then
                    echo -e "  ${YELLOW}!${NC} OCR 快捷鍵未寫入（重跑 -i 可加入）"
                else
                    echo -e "  ${YELLOW}!${NC} OCR 快捷鍵未就緒（缺 $OCR_PKG 語言包，重跑 -i 可補裝）"
                fi
            fi
        else
            echo -e "  ${RED}✗${NC} 自訂快捷鍵未安裝"
        fi
    else
        echo -e "  ${YELLOW}!${NC} bindings.lua 不存在"
    fi
}

# 使用說明
usage() {
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "Options:"
    echo "  -i, --install     安裝設定 (預設)"
    echo "  -u, --uninstall   還原設定"
    echo "  -s, --status      顯示目前狀態"
    echo "  -h, --help        顯示此說明"
    echo ""
    echo "注意:"
    echo "  OCR (ALT SHIFT + O) 係可選依賴 — 需要 $OCR_PKG 語言包；"
    echo "  缺失時 -i 會自動經 install_package 補裝，補裝唔成其餘快捷鍵照常安裝"
    echo ""
}

# 安裝模式
install() {
    info "開始設定自訂快捷鍵..."

    check_dependencies
    ensure_ocr_lang
    setup_hypr_keybindings

    echo
    info "=============================="
    info "設定完成!"
    info "=============================="
    echo
    echo "新增的快捷鍵："
    echo "  ALT SHIFT + Q      → 區域截圖"
    echo "  ALT SHIFT + E      → 視窗選取截圖"
    echo "  ALT SHIFT + F      → 全螢幕截圖"
    echo "  ALT SHIFT + R      → 開始螢幕錄影"
    echo "  ALT SHIFT CTRL + R → 開始螢幕錄影 (含攝影機)"
    echo "  ALT SHIFT + A      → 顏色選擇器"
    if (( OCR_READY )); then
        echo "  ALT SHIFT + O      → OCR 文字辨識 (中英混合)"
    else
        echo "  ALT SHIFT + O      → 未就緒（缺 $OCR_PKG 語言包；補裝成功後重跑 -i 即可加上）"
    fi
    echo '  CTRL + `           → 開啟剪貼簿管理員 (Omarchy 內建)'
    echo
    echo "剪貼簿管理員亦可用預設快捷鍵 SUPER+CTRL+V 開啟"
    echo
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
