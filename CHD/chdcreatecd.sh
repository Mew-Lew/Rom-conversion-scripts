#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

INPUT_DIR="$ROM_ROOT/CD Input"
OUTPUT_DIR="$ROM_ROOT/CD Output"
mkdir -p -- "$INPUT_DIR" "$OUTPUT_DIR"
require_commands chdman find mktemp unzip

convert_cd_image() {
    local source_file="$1"
    local file_name base_name target staging_root staged_chd

    file_name=$(basename -- "$source_file")
    base_name="${file_name%.*}"
    target="$OUTPUT_DIR/$base_name.chd"
    ((++ATTEMPTED))

    if ! prepare_output_target "$target" "$file_name"; then
        return 0
    fi
    if ! make_temp_dir "$OUTPUT_DIR/.chdcd.XXXXXX"; then
        ((++FAILED))
        return 0
    fi
    staging_root="$TEMP_DIR"
    staged_chd="$staging_root/$base_name.chd"

    printf '%bCreating CHD from %s...%b\n' "$GREEN" "$file_name" "$RESET"
    if chdman createcd -i "$source_file" -o "$staged_chd" &&
       commit_staged_output "$staged_chd" "$target"; then
        ((++SUCCEEDED))
        printf '%bCreated:%b %s\n' "$GREEN" "$RESET" "$target"
    else
        ((++FAILED))
        printf '%bFailed:%b %s\n' "$RED" "$RESET" "$file_name" >&2
    fi
    remove_temp_dir "$staging_root"
}

process_cd_tree() {
    local search_root="$1"
    local source_file
    while IFS= read -r -d '' source_file; do
        convert_cd_image "$source_file"
    done < <(find "$search_root" -type f \( -iname '*.cue' -o -iname '*.iso' -o -iname '*.gdi' \) -print0)
}

process_cd_tree "$INPUT_DIR"
while IFS= read -r -d '' zip_file; do
    if ! make_temp_dir "$OUTPUT_DIR/.chdcd-zip.XXXXXX"; then
        ((++ATTEMPTED)); ((++FAILED)); continue
    fi
    zip_temp="$TEMP_DIR"
    printf '%bExtracting archive:%b %s\n' "$GREEN" "$RESET" "$zip_file"
    if unzip -q -- "$zip_file" -d "$zip_temp"; then
        process_cd_tree "$zip_temp"
    else
        ((++ATTEMPTED)); ((++FAILED))
        printf '%bFailed to extract:%b %s\n' "$RED" "$RESET" "$zip_file" >&2
    fi
    remove_temp_dir "$zip_temp"
done < <(find "$INPUT_DIR" -type f -iname '*.zip' -print0)

(( ATTEMPTED > 0 )) || printf '%bNo CUE, ISO, GDI or ZIP contents were found.%b\n' "$YELLOW" "$RESET"
if ! finish_with_summary; then exit 1; fi
