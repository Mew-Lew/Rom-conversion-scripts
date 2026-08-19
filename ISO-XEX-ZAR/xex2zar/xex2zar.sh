#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

INPUT_DIR="$ROM_ROOT/XEX Input"
OUTPUT_DIR="$ROM_ROOT/ZAR Output"
mkdir -p -- "$INPUT_DIR" "$OUTPUT_DIR"
require_commands mktemp zarchive

convert_xex_folder() {
    local folder="$1"
    local folder_name target staging_root staged_zar

    folder_name=$(basename -- "$folder")
    target="$OUTPUT_DIR/$folder_name.zar"
    ((++ATTEMPTED))

    if ! prepare_output_target "$target" "$folder_name"; then return 0; fi
    if ! make_temp_dir "$OUTPUT_DIR/.xex2zar.XXXXXX"; then
        ((++FAILED)); return 0
    fi
    staging_root="$TEMP_DIR"
    staged_zar="$staging_root/$folder_name.zar"

    printf '%bCreating ZAR for %s...%b\n' "$GREEN" "$folder_name" "$RESET"
    if zarchive "$folder" "$staged_zar" &&
       commit_staged_output "$staged_zar" "$target"; then
        ((++SUCCEEDED))
        printf '%bCreated:%b %s\n' "$GREEN" "$RESET" "$target"
    else
        ((++FAILED))
        printf '%bFailed:%b %s\n' "$RED" "$RESET" "$folder_name" >&2
    fi
    remove_temp_dir "$staging_root"
}

shopt -s nullglob
for folder in "$INPUT_DIR"/*; do
    [[ -d "$folder" ]] && convert_xex_folder "$folder"
done
shopt -u nullglob

(( ATTEMPTED > 0 )) || printf '%bNo XEX folders were found.%b\n' "$YELLOW" "$RESET"
if ! finish_with_summary; then exit 1; fi
