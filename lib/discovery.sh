#!/bin/bash
#
# discovery.sh - Shared script-discovery helpers for omarchy-custom-scripts
#
# Extracted from setup-all.sh so multiple front-ends (menu, wizard) can share
# the same discovery logic. Requires $SCRIPT_DIR to be set by the sourcing
# script (resolved from BASH_SOURCE, works regardless of cwd).
#
# Discovery contract: every setup/fix script declares "# Category:" and
# "# Description:" metadata headers; scripts lacking them are still found,
# falling back to "Other" / the second comment line.

# ========================================
# Script Discovery
# ========================================

# Extract metadata from a script
get_script_metadata() {
    local script="$1"
    local key="$2"
    grep -E "^# $key:" "$SCRIPT_DIR/$script" | sed -E "s/^# $key:[[:space:]]*(.*)$/\1/" | head -1
}

# Get script category
get_script_category() {
    local script="$1"
    local category
    category=$(get_script_metadata "$script" "Category")
    echo "${category:-Other}"
}

# Get script description
get_script_description() {
    local script="$1"
    local desc
    desc=$(get_script_metadata "$script" "Description")
    if [[ -z "$desc" ]]; then
        # Fallback to second line comment
        desc=$(sed -n '2p' "$SCRIPT_DIR/$script" | sed -E 's/^# //')
    fi
    echo "${desc:-$script}"
}

# Get script device applicability (laptop|desktop|both, defaults to both)
get_script_device() {
    local script="$1"
    local device
    device=$(get_script_metadata "$script" "Device")
    device="${device:-both}"
    # Normalize to known values
    case "$device" in
        laptop|desktop) echo "$device" ;;
        *) echo "both" ;;
    esac
}

# Discover all setup scripts (exclude setup-all.sh itself)
discover_scripts() {
    local scripts=()
    for script in "$SCRIPT_DIR"/setup-*.sh; do
        local script_base=$(basename "$script")
        [[ "$script_base" == "setup-all.sh" ]] && continue
        scripts+=("$script_base")
    done
    # Add standalone scripts
    for script in "$SCRIPT_DIR"/fix-spotify-scale.sh; do
        [[ -f "$script" ]] && scripts+=("$(basename "$script")")
    done
    echo "${scripts[@]}"
}

# Group scripts by category
group_scripts_by_category() {
    local scripts=($(discover_scripts))
    local categories=()

    # First pass: get all unique categories
    for script in "${scripts[@]}"; do
        local category=$(get_script_category "$script")
        if ! [[ " ${categories[@]} " =~ " $category " ]]; then
            categories+=("$category")
        fi
    done

    # Sort categories by logical order (most frequently used first)
    local sorted=()
    for cat in "系統設定" "輸入法" "鍵盤" "快捷鍵" "遊戲相容" "容器工具" "修復工具" "Other"; do
        if [[ " ${categories[@]} " =~ " $cat " ]]; then
            sorted+=("$cat")
        fi
    done
    # Add any remaining categories
    for cat in "${categories[@]}"; do
        if ! [[ " ${sorted[@]} " =~ " $cat " ]]; then
            sorted+=("$cat")
        fi
    done

    echo "${sorted[@]}"
}

# Get scripts in a category
get_scripts_in_category() {
    local category="$1"
    local scripts=($(discover_scripts))
    local result=()

    for script in "${scripts[@]}"; do
        local script_cat=$(get_script_category "$script")
        if [[ "$script_cat" == "$category" ]]; then
            result+=("$script")
        fi
    done
    echo "${result[@]}"
}