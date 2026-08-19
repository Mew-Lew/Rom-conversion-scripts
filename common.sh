#!/usr/bin/env bash

set -Eeuo pipefail

CYAN='\e[36m'
GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'
BOLD='\e[1m'
RESET='\e[0m'

ROM_ROOT="${ROM_ROOT:-/storage/emulated/0/Download/Roms}"
ROM_ROOT="${ROM_ROOT%/}"
SAFE_OUTPUT_ROOT="${SAFE_OUTPUT_ROOT:-$ROM_ROOT}"
SAFE_OUTPUT_ROOT="${SAFE_OUTPUT_ROOT%/}"

TEMP_DIRS=()
TEMP_DIR=''
OUTPUT_ACTION='new'
BATCH_OUTPUT_ACTION=''
BACKUP_PATH=''

ATTEMPTED=0
SUCCEEDED=0
SKIPPED=0
FAILED=0

report_error() {
    local status=$?
    local line_number="$1"
    local command="$2"
    printf '%bError on line %s (exit %s): %s%b\n' \
        "$RED" "$line_number" "$status" "$command" "$RESET" >&2
    return "$status"
}

cleanup_temp_dirs() {
    local temp_dir
    for temp_dir in "${TEMP_DIRS[@]}"; do
        if [[ -n "$temp_dir" && -d "$temp_dir" ]]; then
            rm -rf -- "$temp_dir"
        fi
    done
}

trap 'report_error "$LINENO" "$BASH_COMMAND"' ERR
trap cleanup_temp_dirs EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

require_commands() {
    local command_name
    local missing=0
    for command_name in "$@"; do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            printf '%bRequired command is unavailable: %s%b\n' \
                "$RED" "$command_name" "$RESET" >&2
            missing=1
        fi
    done
    (( missing == 0 ))
}

print_menu_heading() {
    printf '\n%b%b%s%b\n' "$BOLD" "$CYAN" "$1" "$RESET"
}

print_menu_option() {
    local number="$1" label="$2" description="$3"
    printf '  %b%s)%b %b%-16s%b %s\n' \
        "$CYAN" "$number" "$RESET" "$GREEN" "$label" "$RESET" "$description"
}

make_temp_dir() {
    local template="$1"
    TEMP_DIR=$(mktemp -d -- "$template")
    TEMP_DIRS+=("$TEMP_DIR")
}

remove_temp_dir() {
    local temp_dir="$1"
    if [[ -n "$temp_dir" && -d "$temp_dir" ]]; then
        rm -rf -- "$temp_dir"
    fi
}

is_safe_output_target() {
    local target="$1"
    [[ -n "$SAFE_OUTPUT_ROOT" && "$SAFE_OUTPUT_ROOT" != '/' ]] || return 1
    case "$target" in
        "$SAFE_OUTPUT_ROOT"/*) return 0 ;;
        *) return 1 ;;
    esac
}

next_available_path() {
    local target="$1"
    local label="$2"
    local timestamp candidate
    local suffix=0

    timestamp=$(date +%Y%m%d-%H%M%S)
    candidate="${target}.${label}-${timestamp}"
    while [[ -e "$candidate" ]]; do
        ((++suffix))
        candidate="${target}.${label}-${timestamp}-${suffix}"
    done
    BACKUP_PATH="$candidate"
}

select_output_action() {
    local target="$1"
    local choice

    OUTPUT_ACTION='new'
    [[ -e "$target" ]] || return 0

    if [[ -n "$BATCH_OUTPUT_ACTION" ]]; then
        OUTPUT_ACTION="$BATCH_OUTPUT_ACTION"
        return 0
    fi

    while true; do
        print_menu_heading 'Existing output'
        printf '%bOutput already exists:%b %s\n' "$YELLOW" "$RESET" "$target"
        print_menu_option 1 'Skip this item' 'Leave the existing output untouched'
        print_menu_option 2 'Replace this item' 'Replace it after conversion succeeds'
        print_menu_option 3 'Keep a backup' 'Move the existing output to a timestamped backup'
        print_menu_option 4 'Skip all existing' 'Skip every remaining item with existing output'
        print_menu_option 5 'Replace all existing' 'Replace every remaining item after conversion succeeds'
        print_menu_option 6 'Cancel batch' 'Stop this conversion batch'
        read -r -p 'Select an option [1-6]: ' choice
        case "$choice" in
            1) OUTPUT_ACTION='skip'; return 0 ;;
            2) OUTPUT_ACTION='overwrite'; return 0 ;;
            3) OUTPUT_ACTION='backup'; return 0 ;;
            4) BATCH_OUTPUT_ACTION='skip'; OUTPUT_ACTION='skip'; return 0 ;;
            5) BATCH_OUTPUT_ACTION='overwrite'; OUTPUT_ACTION='overwrite'; return 0 ;;
            6) OUTPUT_ACTION='cancel'; return 0 ;;
            *) printf '%bInvalid choice.%b\n' "$RED" "$RESET" ;;
        esac
    done
}

prepare_output_target() {
    local target="$1"
    local item_name="$2"

    select_output_action "$target"
    case "$OUTPUT_ACTION" in
        skip)
            ((++SKIPPED))
            printf '%bSkipped:%b %s\n' "$YELLOW" "$RESET" "$item_name"
            return 1
            ;;
        cancel)
            print_summary
            exit 130
            ;;
        new|overwrite|backup)
            return 0
            ;;
        *)
            printf '%bInvalid output action: %s%b\n' \
                "$RED" "$OUTPUT_ACTION" "$RESET" >&2
            return 2
            ;;
    esac
}

commit_staged_output() {
    local staged="$1"
    local target="$2"
    local displaced=''

    if [[ ! -e "$staged" ]]; then
        printf '%bStaged output is missing: %s%b\n' "$RED" "$staged" "$RESET" >&2
        return 1
    fi
    if ! is_safe_output_target "$target"; then
        printf '%bRefusing unsafe output target: %s%b\n' "$RED" "$target" "$RESET" >&2
        return 1
    fi

    mkdir -p -- "$(dirname -- "$target")"
    case "$OUTPUT_ACTION" in
        new)
            if [[ -e "$target" ]]; then
                printf '%bOutput appeared during conversion; refusing to replace it: %s%b\n' \
                    "$RED" "$target" "$RESET" >&2
                return 1
            fi
            ;;
        overwrite)
            if [[ ! -e "$target" ]]; then
                printf '%bExisting output disappeared during conversion: %s%b\n' \
                    "$RED" "$target" "$RESET" >&2
                return 1
            fi
            next_available_path "$target" 'replace'
            displaced="$BACKUP_PATH"
            mv -- "$target" "$displaced"
            ;;
        backup)
            if [[ ! -e "$target" ]]; then
                printf '%bExisting output disappeared during conversion: %s%b\n' \
                    "$RED" "$target" "$RESET" >&2
                return 1
            fi
            next_available_path "$target" 'backup'
            displaced="$BACKUP_PATH"
            mv -- "$target" "$displaced"
            printf '%bExisting output moved to:%b %s\n' "$YELLOW" "$RESET" "$displaced"
            ;;
        *)
            printf '%bInvalid commit action: %s%b\n' \
                "$RED" "$OUTPUT_ACTION" "$RESET" >&2
            return 1
            ;;
    esac

    if mv -- "$staged" "$target"; then
        if [[ "$OUTPUT_ACTION" == 'overwrite' && -n "$displaced" ]]; then
            rm -rf -- "$displaced"
        fi
        return 0
    fi

    if [[ -n "$displaced" && -e "$displaced" && ! -e "$target" ]]; then
        mv -- "$displaced" "$target" || true
    fi
    return 1
}

print_summary() {
    echo
    printf '%bConversion summary%b\n' "$GREEN" "$RESET"
    printf 'Attempted: %s\n' "$ATTEMPTED"
    printf 'Succeeded: %s\n' "$SUCCEEDED"
    printf 'Skipped:   %s\n' "$SKIPPED"
    printf 'Failed:    %s\n' "$FAILED"
}

finish_with_summary() {
    print_summary
    (( FAILED == 0 ))
}
