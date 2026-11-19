#!/bin/bash
#
# test-idempotency.sh - 驗證腳本冪等性同還原
# 確保 -i 執行兩次後設定檔內容完全相同，-u 亦能還原到 -i 之前嘅狀態
#
# Usage:
#   ./test-idempotency.sh setup-keybindings.sh   # 測試單一腳本
#   ./test-idempotency.sh                         # 測試所有腳本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 載入共用函式庫
source "$SCRIPT_DIR/lib/common.sh"

# 單一映射表：腳本 → 冪等性測試要驗證的設定檔。
# 這是唯一的映射來源：單腳本測試與全跑都從這裡衍生。
# 同一個腳本可以登記多行（多個設定檔）；全跑時同一腳本只執行一次，
# 但會驗證它名下所有設定檔。格式: "腳本名|設定檔路徑"，陣列順序 = 全跑順序
SCRIPT_CONFIG_MAP=(
	"setup-fonts.sh|$HOME/.config/fontconfig/fonts.conf"
	"setup-chromium-scale.sh|$HOME/.config/chromium-flags.conf"
	"setup-input.sh|$HOME/.local/share/fcitx5/rime/scj6.custom.yaml"
	"setup-input.sh|$HOME/.local/share/fcitx5/rime/default.custom.yaml"
	"setup-macos-input.sh|$HOME/.config/hypr/input.lua"
	"setup-keybindings.sh|$HOME/.config/hypr/bindings.lua"
)

# 從映射表查出腳本名下所有設定檔（每行一個）；未登記則回傳非零
config_for_script() {
	local script="$1"
	local entry found=false
	for entry in "${SCRIPT_CONFIG_MAP[@]}"; do
		if [[ "${entry%%|*}" == "$script" ]]; then
			printf '%s\n' "${entry#*|}"
			found=true
		fi
	done
	$found
}

# 列出映射表中所有已登記的腳本（去重）
registered_scripts() {
	local entry script seen=" "
	for entry in "${SCRIPT_CONFIG_MAP[@]}"; do
		script="${entry%%|*}"
		if [[ "$seen" != *" $script "* ]]; then
			echo "  $script"
			seen+="$script "
		fi
	done
}

# 測試結果統計
TOTAL_TESTS=0
PASSED=0
FAILED=0

# 回報設定檔目前狀態：存在則輸出 checksum，否則輸出 "absent"
config_state() {
	local file="$1"
	if [[ -f "$file" ]]; then
		md5sum "$file" | awk '{print $1}'
	else
		echo "absent"
	fi
}

# 執行腳本一個階段（-i 或 -u），輸出寫入日誌檔後再加縮排顯示。
# 直接捕捉腳本真實結束碼；唔可以將腳本 pipe 去 sed（pipe 只會俾 sed 嘅結束碼）。
run_stage() {
	local script="$1"
	local mode="$2"
	local log="$3"
	local rc=0

	"./$script" "$mode" </dev/null >"$log" 2>&1 || rc=$?
	sed 's/^/  /' "$log" || true
	return "$rc"
}

# 驗證單一腳本：-i 兩次必須一致，-u 必須還原到測試前狀態。
# 設定檔清單由 SCRIPT_CONFIG_MAP 傳入（同一腳本可有多個）。
test_script() {
	local script="$1"
	shift
	local configs=("$@")
	local config backup_file i

	TOTAL_TESTS=$((TOTAL_TESTS + 1))
	local ok=true

	header "測試 $script 冪等性同還原"

	# 記錄每個設定檔測試前狀態，並備份現有檔案（先清掉舊測試備份）
	local pre_states=()
	for config in "${configs[@]}"; do
		backup_file="${config}.bak.idempotency_test"
		rm -f "$backup_file"
		if [[ -f "$config" ]]; then
			cp "$config" "$backup_file"
			pre_states+=("$(config_state "$config")")
			detail "測試前狀態 $config: ${pre_states[${#pre_states[@]}-1]}"
		else
			pre_states+=("absent")
			detail "測試前狀態 $config: absent（原本不存在）"
		fi
	done

	local log rc
	log=$(mktemp)

	# 第一次執行
	info "[1/4] 第一次執行 -i..."
	rc=0
	run_stage "$script" "-i" "$log" || rc=$?
	if (( rc != 0 )); then
		ok=false
		echo -e "${RED}✗ 失敗 - 第一次 -i 結束碼非零${NC}"
		detail "結束碼: $rc"
	fi

	# 記錄第一次後的狀態
	local states1=()
	for config in "${configs[@]}"; do
		states1+=("$(config_state "$config")")
		detail "Checksum 1 $config: ${states1[${#states1[@]}-1]}"
	done

	# 第二次執行
	echo ""
	info "[2/4] 第二次執行 -i..."
	rc=0
	run_stage "$script" "-i" "$log" || rc=$?
	if (( rc != 0 )); then
		ok=false
		echo -e "${RED}✗ 失敗 - 第二次 -i 結束碼非零${NC}"
		detail "結束碼: $rc"
	fi

	# 記錄第二次後的狀態
	local states2=()
	for config in "${configs[@]}"; do
		states2+=("$(config_state "$config")")
		detail "Checksum 2 $config: ${states2[${#states2[@]}-1]}"
	done

	# 比對兩次 -i
	echo ""
	info "[3/4] 驗證兩次 -i 一致..."
	local idem_ok=true
	for i in "${!configs[@]}"; do
		if [[ "${states1[i]}" != "${states2[i]}" ]]; then
			idem_ok=false
			echo -e "${RED}✗ 失敗 - ${configs[i]} 兩次執行結果不同！${NC}"
			detail "Checksum 1: ${states1[i]}"
			detail "Checksum 2: ${states2[i]}"
		fi
	done
	if $idem_ok; then
		echo -e "${GREEN}✓ 通過 - 兩次 -i 結果完全相同${NC}"
	else
		ok=false
	fi

	# -u 還原
	echo ""
	info "[4/4] 執行 -u 並驗證還原..."
	rc=0
	run_stage "$script" "-u" "$log" || rc=$?
	if (( rc != 0 )); then
		ok=false
		echo -e "${RED}✗ 失敗 - -u 結束碼非零${NC}"
		detail "結束碼: $rc"
	fi

	local restore_ok=true
	for i in "${!configs[@]}"; do
		config="${configs[i]}"
		if [[ "$(config_state "$config")" != "${pre_states[i]}" ]]; then
			restore_ok=false
			echo -e "${RED}✗ 失敗 - $config 未還原到測試前狀態${NC}"
			detail "測試前: ${pre_states[i]}"
			detail "現在:   $(config_state "$config")"
			# 測試前唔存在但 -u 冇刪：只在 -u 失敗時代它刪除，並講明；
			# -u 成功但仍然存在就只報告，唔好靜靜雞当無事。
			if [[ "${pre_states[i]}" == "absent" && -f "$config" ]]; then
				if (( rc != 0 )); then
					rm -f "$config"
					detail "已代 -u 刪除測試建立嘅檔案（-u 回報失敗）"
				else
					detail "測試遺留檔案仍在，請人手刪除（-u 回報成功）"
				fi
			fi
		fi
	done
	if $restore_ok; then
		echo -e "${GREEN}✓ 通過 - -u 已還原所有設定檔${NC}"
	else
		ok=false
	fi

	# 恢復測試前備份（無論成敗）
	for config in "${configs[@]}"; do
		backup_file="${config}.bak.idempotency_test"
		if [[ -f "$backup_file" ]]; then
			mkdir -p "$(dirname "$config")"
			mv "$backup_file" "$config"
		fi
	done
	rm -f "$log"

	if $ok; then
		PASSED=$((PASSED + 1))
		echo -e "${GREEN}✓ $script 全部檢查通過${NC}"
	else
		FAILED=$((FAILED + 1))
		echo -e "${RED}✗ $script 有檢查失敗${NC}"
	fi

	echo ""
}

# 顯示幫助
usage() {
	cat <<EOF
Usage: $0 [SCRIPT_NAME]

  不指定參數: 測試映射表中所有腳本
  指定腳本名: 只測試那個腳本（含它名下所有設定檔）

驗證內容: -i 兩次結果必須一致，-u 必須還原到測試前狀態。

已登記腳本（單一映射來源，新增腳本請加進 SCRIPT_CONFIG_MAP）:
$(registered_scripts)

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
		# 測試單一腳本（查同一份映射表，可能有多個設定檔）
		local script="$1" output
		local configs=()
		if ! output=$(config_for_script "$script"); then
			error "未知或未登記的腳本: $script（已登記腳本請用 -h 查看）"
		fi
		mapfile -t configs <<< "$output"
		test_script "$script" "${configs[@]}"
	else
		# 測試所有腳本（同一份映射表；同一腳本只跑一次，驗證多個設定檔）
		local entry script output seen=" "
		local configs=()
		for entry in "${SCRIPT_CONFIG_MAP[@]}"; do
			script="${entry%%|*}"
			if [[ "$seen" == *" $script "* ]]; then
				continue
			fi
			seen+="$script "
			configs=()
			mapfile -t configs <<< "$(config_for_script "$script")"
			test_script "$script" "${configs[@]}"
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
