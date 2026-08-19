#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

INPUT_DIR="$ROM_ROOT/ISO2GOD Input"
OUTPUT_DIR="$ROM_ROOT/ISO2GOD Output"
ISO2GOD_BIN="${ISO2GOD_BIN:-/usr/local/bin/iso2god}"
THREADS="${ISO2GOD_THREADS:-2}"
CONVERSION_MODE="${ISO2GOD_MODE:-}"

mkdir -p -- "$INPUT_DIR" "$OUTPUT_DIR"
require_commands "$ISO2GOD_BIN" find mktemp unzip

case "$THREADS" in
    ''|*[!0-9]*|0)
        printf '%bInvalid ISO2GOD_THREADS value; using 2.%b\n' "$YELLOW" "$RESET"
        THREADS=2
        ;;
esac

choose_conversion_mode() {
    local choice
    CONVERSION_MODE="${CONVERSION_MODE,,}"
    case "$CONVERSION_MODE" in
        untouched|partial|remove-all) return 0 ;;
        '') ;;
        *)
            printf '%bISO2GOD_MODE must be untouched, partial, or remove-all.%b\n' \
                "$RED" "$RESET" >&2
            return 2
            ;;
    esac

    while true; do
        echo
        printf '%bISO2GOD conversion mode%b\n' "$GREEN" "$RESET"
        echo '1) Untouched   Standard conversion without trimming'
        echo '2) Partial     Use ISO2GOD native trimming (--trim)'
        echo '3) Remove all  Rebuild with extract-xiso, then convert'
        echo '4) Cancel'
        read -r -p 'Select a mode [1-4]: ' choice
        case "$choice" in
            1) CONVERSION_MODE='untouched'; return 0 ;;
            2) CONVERSION_MODE='partial'; return 0 ;;
            3) CONVERSION_MODE='remove-all'; return 0 ;;
            4) return 130 ;;
            *) printf '%bInvalid choice.%b\n' "$RED" "$RESET" ;;
        esac
    done
}

read_title_id() {
    local iso_file="$1"
    "$ISO2GOD_BIN" --dry-run "$iso_file" "$OUTPUT_DIR" 2>/dev/null |
        awk '/^[[:space:]]*Title ID:/ {print $3; exit}'
}

run_iso2god() {
    local iso_file="$1" destination="$2"
    if [[ "$CONVERSION_MODE" == 'partial' ]]; then
        "$ISO2GOD_BIN" --trim -j "$THREADS" "$iso_file" "$destination"
    else
        "$ISO2GOD_BIN" -j "$THREADS" "$iso_file" "$destination"
    fi
}

ACTIVE_ORIGINAL=''
ACTIVE_OLD=''
REBUILT_ISO=''

restore_active_original() {
    [[ -n "$ACTIVE_ORIGINAL" ]] || return 0

    if [[ ! -e "$ACTIVE_ORIGINAL" && -e "$ACTIVE_OLD" ]]; then
        if ! mv -- "$ACTIVE_OLD" "$ACTIVE_ORIGINAL"; then
            printf '%bCould not restore source ISO:%b %s\n' \
                "$RED" "$RESET" "$ACTIVE_ORIGINAL" >&2
            return 1
        fi
    elif [[ ! -e "$ACTIVE_ORIGINAL" && ! -e "$ACTIVE_OLD" ]]; then
        printf '%bSource ISO and recovery file are both missing:%b %s\n' \
            "$RED" "$RESET" "$ACTIVE_ORIGINAL" >&2
        return 1
    elif [[ -e "$ACTIVE_ORIGINAL" && -e "$ACTIVE_OLD" ]]; then
        printf '%bBoth the source ISO and its .old file exist; refusing to overwrite either:%b %s\n' \
            "$RED" "$RESET" "$ACTIVE_ORIGINAL" >&2
        return 1
    fi

    ACTIVE_ORIGINAL=''
    ACTIVE_OLD=''
}

cleanup_iso2god() {
    restore_active_original || true
    cleanup_temp_dirs
}

trap cleanup_iso2god EXIT
trap 'cleanup_iso2god; exit 130' INT
trap 'cleanup_iso2god; exit 143' TERM

recover_interrupted_sources() {
    local old_file original_file

    while IFS= read -r -d '' old_file; do
        original_file="${old_file%.old}"
        if [[ ! -e "$original_file" ]]; then
            if mv -- "$old_file" "$original_file"; then
                printf '%bRestored an ISO left by an interrupted rebuild:%b %s\n' \
                    "$YELLOW" "$RESET" "$original_file"
            else
                printf '%bCould not restore interrupted source ISO:%b %s\n' \
                    "$RED" "$RESET" "$original_file" >&2
                return 1
            fi
        fi
    done < <(find "$INPUT_DIR" -type f -iname '*.iso.old' -print0)
}

rebuild_iso() {
    local source_iso="$1" rebuilt_dir="$2"
    local source_old="${source_iso}.old" source_size available_bytes rewrite_status=0

    REBUILT_ISO=''
    require_commands extract-xiso || return 1

    if [[ -e "$source_old" ]]; then
        printf '%bCannot rebuild while this recovery file exists:%b %s\n' \
            "$RED" "$RESET" "$source_old" >&2
        return 1
    fi

    source_size=$(stat -c '%s' -- "$source_iso") || return 1
    available_bytes=$(df -PB1 -- "$OUTPUT_DIR" | awk 'NR == 2 {print $4}')
    if [[ "$available_bytes" =~ ^[0-9]+$ ]] && (( available_bytes < source_size )); then
        printf '%bNot enough free space for the temporary rebuilt ISO.%b\n' "$RED" "$RESET" >&2
        printf 'Needed: %s bytes; available: %s bytes.\n' "$source_size" "$available_bytes" >&2
        return 1
    fi

    mkdir -p -- "$rebuilt_dir"
    ACTIVE_ORIGINAL="$source_iso"
    ACTIVE_OLD="$source_old"
    if extract-xiso -r "$source_iso" -d "$rebuilt_dir"; then
        :
    else
        rewrite_status=$?
    fi
    restore_active_original || return 1

    if (( rewrite_status != 0 )); then
        printf '%bExtract-XISO could not rebuild:%b %s\n' \
            "$RED" "$RESET" "$(basename -- "$source_iso")" >&2
        return 1
    fi

    REBUILT_ISO=$(find "$rebuilt_dir" -type f -iname '*.iso' -print -quit)
    if [[ -z "$REBUILT_ISO" ]]; then
        REBUILT_ISO="$source_iso"
        printf '%bISO is already rebuilt; converting it directly.%b\n' "$YELLOW" "$RESET"
    fi
}

convert_iso_to_god() {
    local iso_file="$1"
    local file_name title_id expected_target='' staging_root staged_output rebuilt_dir
    local title_dir actual_target
    local conversion_source="$iso_file"
    local -a title_dirs=()

    file_name=$(basename -- "$iso_file")
    ((++ATTEMPTED))

    title_id=$(read_title_id "$iso_file" || true)
    if [[ "$title_id" =~ ^[[:xdigit:]]{8}$ ]]; then
        expected_target="$OUTPUT_DIR/${title_id^^}"
        if ! prepare_output_target "$expected_target" "$file_name"; then return 0; fi
    fi

    if ! make_temp_dir "$OUTPUT_DIR/.iso2god-stage.XXXXXX"; then
        ((++FAILED)); return 0
    fi
    staging_root="$TEMP_DIR"
    staged_output="$staging_root/output"
    rebuilt_dir="$staging_root/rebuilt"
    mkdir -p -- "$staged_output"

    if [[ "$CONVERSION_MODE" == 'remove-all' ]]; then
        printf '%bRemove all mode: rebuilding %s before conversion...%b\n' \
            "$GREEN" "$file_name" "$RESET"
        if ! rebuild_iso "$iso_file" "$rebuilt_dir"; then
            ((++FAILED))
            remove_temp_dir "$staging_root"
            return 0
        fi
        conversion_source="$REBUILT_ISO"
    fi

    printf '%b%s mode: converting %s with %s workers...%b\n' \
        "$GREEN" "${CONVERSION_MODE^}" "$file_name" "$THREADS" "$RESET"
    if ! run_iso2god "$conversion_source" "$staged_output"; then
        ((++FAILED))
        printf '%bConversion failed:%b %s\n' "$RED" "$RESET" "$file_name" >&2
        remove_temp_dir "$staging_root"
        return 0
    fi

    mapfile -d '' -t title_dirs < <(find "$staged_output" -mindepth 1 -maxdepth 1 -type d -print0)
    if (( ${#title_dirs[@]} != 1 )); then
        ((++FAILED))
        printf '%bISO2GOD produced %s title directories; expected exactly one:%b %s\n' \
            "$RED" "${#title_dirs[@]}" "$RESET" "$file_name" >&2
        remove_temp_dir "$staging_root"
        return 0
    fi

    title_dir="${title_dirs[0]}"
    actual_target="$OUTPUT_DIR/$(basename -- "$title_dir")"
    if [[ -z "$expected_target" || "$actual_target" != "$expected_target" ]]; then
        if ! prepare_output_target "$actual_target" "$file_name"; then
            remove_temp_dir "$staging_root"
            return 0
        fi
    fi

    if commit_staged_output "$title_dir" "$actual_target"; then
        ((++SUCCEEDED))
        printf '%bCreated:%b %s\n' "$GREEN" "$RESET" "$actual_target"
    else
        ((++FAILED))
        printf '%bFailed to commit GOD output:%b %s\n' "$RED" "$RESET" "$file_name" >&2
    fi
    remove_temp_dir "$staging_root"
}

process_iso_tree() {
    local search_root="$1" iso_file
    while IFS= read -r -d '' iso_file; do
        convert_iso_to_god "$iso_file"
    done < <(find "$search_root" -type f -iname '*.iso' -print0)
}

recover_interrupted_sources || exit 1
if choose_conversion_mode; then
    :
else
    mode_status=$?
    if (( mode_status == 130 )); then echo 'Cancelled.'; exit 0; fi
    exit "$mode_status"
fi
printf '%bUsing %s mode for every ISO in this run.%b\n' "$GREEN" "$CONVERSION_MODE" "$RESET"

process_iso_tree "$INPUT_DIR"
while IFS= read -r -d '' zip_file; do
    if ! make_temp_dir "$OUTPUT_DIR/.iso2god-zip.XXXXXX"; then
        ((++ATTEMPTED)); ((++FAILED)); continue
    fi
    zip_temp="$TEMP_DIR"
    printf '%bExtracting archive:%b %s\n' "$GREEN" "$RESET" "$zip_file"
    if unzip -q -- "$zip_file" -d "$zip_temp"; then
        process_iso_tree "$zip_temp"
    else
        ((++ATTEMPTED)); ((++FAILED))
        printf '%bFailed to extract:%b %s\n' "$RED" "$RESET" "$zip_file" >&2
    fi
    remove_temp_dir "$zip_temp"
done < <(find "$INPUT_DIR" -type f -iname '*.zip' -print0)

(( ATTEMPTED > 0 )) || printf '%bNo ISO or ZIP contents were found.%b\n' "$YELLOW" "$RESET"
if ! finish_with_summary; then exit 1; fi
