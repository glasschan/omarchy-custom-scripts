#!/bin/bash
#
# test-idempotency.sh - 驗證腳本冪等性
# 確保腳本執行兩次後，設定檔內容完全相同
#
# Usage:
#   ./test-idempotency.sh setup-keybindings.sh   # 測試單一腳本
#   ./test-idempotency.sh                         # 測試所有腳本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 載入共用函式庫
source "$SCRIPT_DIR/lib/common.sh"

# 測試結果統計
TOTAL_TESTS=0
PASSED=0
FAILED=0

# 測試單一腳本的函數
test_script() {
    local script="$1"
    local config_file="$2"
    local backup_file="${config_file}.bak.idempotency_test"

    # 如果設定檔不存在，跳過備份
    if [[ -f "$config_file" ]]; then
        cp "$config_file" "$backup_file"
    fi

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    header "測試 $script 冪等性"

    # 第一次執行
    info "[1/3] 第一次執行..."
    "./$script" -i 2>&1 | sed 's/^/  /'

    # 記錄第一次後的狀態
    if [[ -f "$config_file" ]]; then
        local checksum1=$(md5sum "$config_file" 2>/dev/null)
        detail "Checksum 1: $checksum1"
    else
        local checksum1="new_file"
        detail "設定檔為新建立"
    fi

    # 第二次執行
    echo ""
    info "[2/3] 第二次執行..."
    "./$script" -i 2>&1 | sed 's/^/  /'

    # 記錄第二次後的狀態
    if [[ -f "$config_file" ]]; then
        local checksum2=$(md5sum "$config_file" 2>/dev/null)
        detail "Checksum 2: $checksum2"
    else
        local checksum2="new_file"
    fi

    # 比對
    echo ""
    info "[3/3] 驗證..."
    if [[ "$checksum1" == "$checksum2" ]]; then
        PASSED=$((PASSED + 1))
        echo -e "${GREEN}✓ 通過 - 兩次執行結果完全相同${NC}"
        result="PASS"
    else
        FAILED=$((FAILED + 1))
        echo -e "${RED}✗ 失敗 - 兩次執行結果不同！${NC}"
        detail "Checksum 1: $checksum1"
        detail "Checksum 2: $checksum2"
        detail "設定檔差異："
        diff -u <(echo "$checksum1") <(echo "$checksum2") || true
        result="FAIL"
    fi

    # 恢復備份
    if [[ -f "$backup_file" ]]; then
        mv "$backup_file" "$config_file"
    elif [[ -f "$config_file" ]]; then
        # 如果是測試時建立的，嘗試用 -u 移除
        "./$script" -u 2>&1 | sed 's/^/  /'
    fi

    echo ""
}

# 顯示幫助
usage() {
    cat <<EOF
Usage: $0 [SCRIPT_NAME]

  不指定參數: 測試所有已知的腳本
  指定腳本名: 只測試那個腳本

Examples:
  $0 setup-keybindings.sh    # 只測試快捷鍵腳本
  $0                           # 測試所有腳本
EOF
}

# 主程式
main() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        usage
        exit 0
    fi

    header "Omarchy Custom Scripts - 冪等性測試"
    echo ""

    if [[ -n "$1" ]]; then
        # 測試單一腳本
        case "$1" in
            setup-keybindings.sh)
                test_script "setup-keybindings.sh" "$HOME/.config/elephant/clipboard.toml"
                ;;
            setup-fonts.sh)
                test_script "setup-fonts.sh" "$HOME/.config/chromium-flags.conf"
                ;;
            setup-distrobox.sh)
                test_script "setup-distrobox.sh" "$HOME/.bashrc"
                ;;
            setup-gaming.sh)
                test_script "setup-gaming.sh" "$HOME/.config/hypr/envs.conf"
                ;;
            setup-macos-input.sh)
                test_script "setup-macos-input.sh" "$HOME/.config/hypr/input.conf"
                ;;
            setup-input.sh)
                test_script "setup-input.sh" "$HOME/.local/share/fcitx5/rime/scj6.custom.yaml"
                ;;
            *)
                error "未知腳本: $1"
                ;;
        esac
    else
        # 測試所有腳本
        warn "全測試需要 sudo 權限並會修改系統設定"
        read -p "確定要繼續嗎？(y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            info "已取消"
            exit 0
        fi

        # 這裡可以加入全測試
        info "全測試模式尚未實作，請指定單一腳本測試"
        exit 1
    fi

    # 顯示總結
    header "測試結果總結"
    echo -e "總測試數: $TOTAL_TESTS"
    echo -e "${GREEN}通過: $PASSED${NC}"
    echo -e "${RED}失敗: $FAILED${NC}"
    echo ""

    if [[ $FAILED -gt 0 ]]; then
        warn "有測試失敗！請檢查上述輸出"
        exit 1
    else
        info "所有測試通過！"
        exit 0
    fi
}

main "$@"
