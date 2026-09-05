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

# 對多個設定檔取快照 (每行 "md5  檔案";唔存在嘅檔案記 MISSING)
snapshot_configs() {
	local f
	for f in "$@"; do
		if [[ -f "$f" ]]; then
			md5sum "$f"
		else
			echo "MISSING  $f"
		fi
	done
}

# 測試單一腳本的函數
# 用法: test_script <script> <config> [<config>...] [-- <傳畀腳本嘅參數>...]
test_script() {
	local script="$1"
	shift
	local config_files=() script_args=() seen_args=false arg
	for arg in "$@"; do
		if [[ "$arg" == "--" ]]; then
			seen_args=true
		elif $seen_args; then
			script_args+=("$arg")
		else
			config_files+=("$arg")
		fi
	done

	# 如果設定檔不存在，跳過備份
	local f
	for f in "${config_files[@]}"; do
		if [[ -f "$f" ]]; then
			cp "$f" "$f.bak.idempotency_test"
		fi
	done

	TOTAL_TESTS=$((TOTAL_TESTS + 1))

	header "測試 $script 冪等性${script_args[*]:+ (args: ${script_args[*]})}"

	# 第一次執行
	info "[1/3] 第一次執行..."
	"./$script" -i ${script_args[@]+"${script_args[@]}"} </dev/null 2>&1 | sed 's/^/  /'

	# 記錄第一次後的狀態
	local detail1 checksum1
	detail1=$(snapshot_configs "${config_files[@]}")
	checksum1=$(printf '%s\n' "$detail1" | md5sum | cut -d' ' -f1)
	detail "Checksum 1: $checksum1"

	# 第二次執行
	echo ""
	info "[2/3] 第二次執行..."
	"./$script" -i ${script_args[@]+"${script_args[@]}"} </dev/null 2>&1 | sed 's/^/  /'

	# 記錄第二次後的狀態
	local detail2 checksum2
	detail2=$(snapshot_configs "${config_files[@]}")
	checksum2=$(printf '%s\n' "$detail2" | md5sum | cut -d' ' -f1)
	detail "Checksum 2: $checksum2"

	# 比對
	echo ""
	info "[3/3] 驗證..."
	if [[ "$checksum1" == "$checksum2" ]]; then
		PASSED=$((PASSED + 1))
		echo -e "${GREEN}✓ 通過 - 兩次執行結果完全相同${NC}"
	else
		FAILED=$((FAILED + 1))
		echo -e "${RED}✗ 失敗 - 兩次執行結果不同！${NC}"
		detail "第一次後狀態："
		echo "$detail1" | sed 's/^/  /'
		detail "第二次後狀態："
		echo "$detail2" | sed 's/^/  /'
	fi

	# 恢復：測試期間新建立嘅設定檔用 -u 移除，原有嘅由備份還原
	local created=false
	for f in "${config_files[@]}"; do
		if [[ -f "$f" && ! -f "$f.bak.idempotency_test" ]]; then
			created=true
		fi
	done
	if $created; then
		# 如果是測試時建立的，嘗試用 -u 移除
		"./$script" -u </dev/null 2>&1 | sed 's/^/  /'
	fi
	for f in "${config_files[@]}"; do
		if [[ -f "$f.bak.idempotency_test" ]]; then
			mv "$f.bak.idempotency_test" "$f"
		fi
	done

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
  $0                         # 測試所有腳本
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
			test_script "setup-keybindings.sh" "$HOME/.config/hypr/bindings.lua"
			;;
		setup-fonts.sh)
			test_script "setup-fonts.sh" \
				"$HOME/.config/chromium-flags.conf" \
				"$HOME/.config/fontconfig/fonts.conf" \
				-- --gui-font opposans
			;;
		setup-distrobox.sh)
			test_script "setup-distrobox.sh" "$HOME/.bashrc"
			;;
		setup-keyboard.sh)
			test_script "setup-keyboard.sh" "$HOME/.config/hypr/input.lua"
			;;
		setup-macos-touchpad.sh)
			test_script "setup-macos-touchpad.sh" "$HOME/.config/hypr/input.lua"
			;;
		setup-input.sh)
			test_script "setup-input.sh" "$HOME/.local/share/fcitx5/rime/scj6.custom.yaml"
			;;
		fix-spotify-scale.sh)
			test_script "fix-spotify-scale.sh" "$HOME/.config/spotify-flags.conf"
			;;
		*)
			error "未知腳本: $1"
			;;
		esac
	else
		# 測試所有腳本
		for script in setup-fonts.sh setup-input.sh setup-keyboard.sh setup-macos-touchpad.sh setup-keybindings.sh setup-distrobox.sh fix-spotify-scale.sh; do
			case "$script" in
			setup-keybindings.sh) test_script "$script" "$HOME/.config/hypr/bindings.lua" ;;
			setup-fonts.sh)
				test_script "$script" \
					"$HOME/.config/chromium-flags.conf" \
					"$HOME/.config/fontconfig/fonts.conf" \
					-- --gui-font opposans
				;;
			setup-distrobox.sh) test_script "$script" "$HOME/.bashrc" ;;
			setup-keyboard.sh) test_script "$script" "$HOME/.config/hypr/input.lua" ;;
			setup-macos-touchpad.sh) test_script "$script" "$HOME/.config/hypr/input.lua" ;;
			setup-input.sh) test_script "$script" "$HOME/.local/share/fcitx5/rime/scj6.custom.yaml" ;;
			fix-spotify-scale.sh) test_script "$script" "$HOME/.config/spotify-flags.conf" ;;
			esac
		done
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
