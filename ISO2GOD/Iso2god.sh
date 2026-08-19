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
        compact|fast) return 0 ;;
        '') ;;
        *)
            printf '%bISO2GOD_MODE must be compact or fast.%b\n' "$RED" "$RESET" >&2
            return 2
            ;;
    esac

    while true; do
        echo
        printf '%bISO2GOD conversion mode%b\n' "$GREEN" "$RESET"
        echo '1) Compact  Smaller output using ISO2GOD native trimming'
        echo '2) Fast     Quicker conversion without trimming'
        echo '3) Cancel'
        read -r -p 'Select a mode [1-3]: ' choice
        case "$choice" in
            1) CONVERSION_MODE='compact'; return 0 ;;
            2) CONVERSION_MODE='fast'; return 0 ;;
            3) return 130 ;;
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
    if [[ "$CONVERSION_MODE" == 'compact' ]]; then
        "$ISO2GOD_BIN" --trim -j "$THREADS" "$iso_file" "$destination"
    else
        "$ISO2GOD_BIN" -j "$THREADS" "$iso_file" "$destination"
    fi
}

convert_iso_to_god() {
    local iso_file="$1"
    local file_name title_id expected_target='' staging_root staged_output
    local title_dir actual_target
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
    mkdir -p -- "$staged_output"

    printf '%b%s mode: converting %s with %s workers...%b\n' \
        "$GREEN" "${CONVERSION_MODE^}" "$file_name" "$THREADS" "$RESET"
    if ! run_iso2god "$iso_file" "$staged_output"; then
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
