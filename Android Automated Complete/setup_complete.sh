#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

GREEN='\e[32m'
YELLOW='\e[33m'
BLUE='\e[34m'
MAGENTA='\e[35m'
RESET='\e[0m'
SCRIPT_VERSION='3.2.0'

on_error() {
    local exit_code=$?
    local line_number=$1
    echo -e "\e[31mSetup failed on line ${line_number} with exit code ${exit_code}.${RESET}" >&2
    exit "$exit_code"
}

trap 'on_error $LINENO' ERR

case "${1:-}" in
    --normal|'')
        SETUP_MODE='normal'
        ;;
    --update)
        SETUP_MODE='update'
        ;;
    -h|--help)
        echo "Usage: $0 [--normal|--update]"
        echo "  --normal  Install or repair required tools without full system upgrades"
        echo "  --update  Upgrade Termux and Ubuntu packages before installing or repairing tools"
        exit 0
        ;;
    *)
        echo -e "\e[31mUnknown option: ${1}\e[0m" >&2
        exit 2
        ;;
esac

if [ "$#" -eq 0 ]; then
    echo -e "${GREEN}ROM Conversion Scripts setup ${SCRIPT_VERSION}${RESET}"
    echo -e "${BLUE}1) Normal setup or repair${RESET}"
    echo -e "${YELLOW}2) Update system packages, then setup or repair${RESET}"
    echo -e "\e[31m3) Cancel${RESET}"
    read -r -p "Enter your choice (1-3): " setup_choice
    case "$setup_choice" in
        1) SETUP_MODE='normal' ;;
        2) SETUP_MODE='update' ;;
        3) exit 0 ;;
        *)
            echo -e "\e[31mInvalid setup choice.${RESET}" >&2
            exit 2
            ;;
    esac
fi

echo -e "\e[32mUpdating Termux package lists...\e[0m"
pkg update -y

if [ "$SETUP_MODE" = 'update' ]; then
    echo -e "\e[32mUpgrading Termux packages...\e[0m"
    pkg upgrade -y
else
    echo -e "${YELLOW}Skipping the full Termux upgrade in normal mode.${RESET}"
fi

if [ ! -e "$HOME/storage/shared" ]; then
    echo -e "${GREEN}Requesting Termux storage access...${RESET}"
    termux-setup-storage
    read -r -p "Grant storage permission, then press Enter to continue... "
fi

echo -e "\e[32mInstalling proot-distro...\e[0m"
pkg install proot-distro -y

if ! proot-distro login ubuntu -- true >/dev/null 2>&1; then
    echo -e "${GREEN}Installing the Ubuntu environment...${RESET}"
    proot-distro install ubuntu
else
    echo -e "${YELLOW}Ubuntu is already installed; reusing it.${RESET}"
fi

echo -e "\e[32mLogging into the installed Ubuntu environment and running the rest of the setup script...\e[0m"
if ! proot-distro login ubuntu -- env SETUP_MODE="$SETUP_MODE" bash -s << 'EOF'

set -Eeuo pipefail

trap 'exit_code=$?; echo -e "\e[31mUbuntu setup failed on line ${LINENO} with exit code ${exit_code}.\e[0m" >&2; exit "$exit_code"' ERR

export DEBIAN_FRONTEND=noninteractive

INSTALL_TEMP_PATHS=()

cleanup_install_temp() {
    local temp_path
    for temp_path in "${INSTALL_TEMP_PATHS[@]}"; do
        if [ -n "$temp_path" ] && [ -e "$temp_path" ]; then
            rm -rf -- "$temp_path"
        fi
    done
}

trap cleanup_install_temp EXIT

echo -e "\e[32mUpdating Ubuntu package lists...\e[0m"
apt update

if [ "$SETUP_MODE" = 'update' ]; then
    echo -e "\e[32mUpgrading Ubuntu packages...\e[0m"
    apt upgrade -y
else
    echo -e "\e[33mSkipping the full Ubuntu upgrade in normal mode.\e[0m"
fi

echo -e "\e[32mInstalling the required Ubuntu packages...\e[0m"
apt install -y \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    mame-tools \
    tar \
    unzip \
    zarchive-tools

EXTRACT_XISO_COMMIT="b72e5b60d598ec6df80534cda19cdcd4361aa18c"
EXTRACT_XISO_ARCHIVE_SHA256="68789095f8a6011f0cd07ab5794909be867dc5f8448f062c503316e262f046a0"
EXTRACT_XISO_ARCHIVE_URL="https://github.com/XboxDev/extract-xiso/archive/${EXTRACT_XISO_COMMIT}.tar.gz"
EXTRACT_XISO_STAMP="/usr/local/share/rom-conversion-scripts/extract-xiso.commit"

ISO2GOD_VERSION="v1.8.1"
ISO2GOD_SHA256="e32c812a803da0a3ff65cd405a42a463b05e09a8589e06a956db57d99eba852b"
ISO2GOD_URL="https://github.com/iliazeus/iso2god-rs/releases/download/${ISO2GOD_VERSION}/iso2god-aarch64-linux"
ISO2GOD_BIN="/usr/local/bin/iso2god"

if [ "$(uname -m)" != 'aarch64' ]; then
    echo -e "\e[31mUnsupported Ubuntu architecture: $(uname -m). This installer requires AArch64.\e[0m" >&2
    exit 1
fi

file_sha256_matches() {
    local file_path="$1"
    local expected_hash="$2"
    [ -f "$file_path" ] && [ "$(sha256sum "$file_path" | awk '{print $1}')" = "$expected_hash" ]
}

if command -v extract-xiso >/dev/null 2>&1 &&
   [ -f "$EXTRACT_XISO_STAMP" ] &&
   [ "$(tr -d '\r\n' < "$EXTRACT_XISO_STAMP")" = "$EXTRACT_XISO_COMMIT" ]; then
    echo -e "\e[33mextract-xiso is already current; skipping its build.\e[0m"
else
    echo -e "\e[32mBuilding the pinned extract-xiso release...\e[0m"
    extract_archive=$(mktemp --suffix=.tar.gz)
    extract_workspace=$(mktemp -d)
    INSTALL_TEMP_PATHS+=("$extract_archive" "$extract_workspace")

    curl -fL --retry 3 --retry-delay 2 "$EXTRACT_XISO_ARCHIVE_URL" -o "$extract_archive"
    if ! file_sha256_matches "$extract_archive" "$EXTRACT_XISO_ARCHIVE_SHA256"; then
        echo -e "\e[31mextract-xiso archive checksum verification failed.\e[0m" >&2
        exit 1
    fi

    tar -xzf "$extract_archive" -C "$extract_workspace"
    extract_source="$extract_workspace/extract-xiso-${EXTRACT_XISO_COMMIT}"
    cmake -S "$extract_source" -B "$extract_source/build" -DCMAKE_BUILD_TYPE=Release
    cmake --build "$extract_source/build" --parallel "$(nproc)"
    cmake --install "$extract_source/build"
    install -d "$(dirname "$EXTRACT_XISO_STAMP")"
    printf '%s\n' "$EXTRACT_XISO_COMMIT" > "$EXTRACT_XISO_STAMP"
fi

if file_sha256_matches "$ISO2GOD_BIN" "$ISO2GOD_SHA256"; then
    echo -e "\e[33mISO2GOD ${ISO2GOD_VERSION} is already installed; skipping its download.\e[0m"
else
    echo -e "\e[32mDownloading the verified ISO2GOD ${ISO2GOD_VERSION} AArch64 binary...\e[0m"
    iso2god_download=$(mktemp)
    INSTALL_TEMP_PATHS+=("$iso2god_download")
    curl -fL --retry 3 --retry-delay 2 "$ISO2GOD_URL" -o "$iso2god_download"
    if ! file_sha256_matches "$iso2god_download" "$ISO2GOD_SHA256"; then
        echo -e "\e[31mISO2GOD checksum verification failed.\e[0m" >&2
        exit 1
    fi
    install -m 0755 "$iso2god_download" "$ISO2GOD_BIN"
fi

cd "$HOME"

mkdir -p \
    "/storage/emulated/0/Download/Roms/CD Input" \
    "/storage/emulated/0/Download/Roms/CD Output" \
    "/storage/emulated/0/Download/Roms/DVD Input" \
    "/storage/emulated/0/Download/Roms/DVD Output" \
    "/storage/emulated/0/Download/Roms/ISO Input" \
    "/storage/emulated/0/Download/Roms/XEX Input" \
    "/storage/emulated/0/Download/Roms/XEX Output" \
    "/storage/emulated/0/Download/Roms/ZAR Output" \
    "/storage/emulated/0/Download/Roms/ISO2GOD Input" \
    "/storage/emulated/0/Download/Roms/ISO2GOD Output"

echo -e "\e[32mCreating iso2xex.sh script...\e[0m"
mkdir -p "rom scripts"
cat << 'EOT' > "rom scripts/common.sh"
#!/bin/bash

set -uo pipefail

GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'
RESET='\e[0m'
SAFE_OUTPUT_ROOT="${SAFE_OUTPUT_ROOT:-/storage/emulated/0/Download/Roms}"

TEMP_DIRS=()
TEMP_DIR=''
OUTPUT_ACTION='new'
BACKUP_PATH=''

ATTEMPTED=0
SUCCEEDED=0
SKIPPED=0
FAILED=0

cleanup_temp_dirs() {
    local temp_dir
    for temp_dir in "${TEMP_DIRS[@]}"; do
        if [ -n "$temp_dir" ] && [ -d "$temp_dir" ]; then
            rm -rf -- "$temp_dir"
        fi
    done
}

trap cleanup_temp_dirs EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

make_temp_dir() {
    local template="$1"
    TEMP_DIR=$(mktemp -d -- "$template") || return 1
    TEMP_DIRS+=("$TEMP_DIR")
}

remove_temp_dir() {
    local temp_dir="$1"
    if [ -n "$temp_dir" ] && [ -d "$temp_dir" ]; then
        rm -rf -- "$temp_dir"
    fi
}

is_safe_output_target() {
    case "$1" in
        "$SAFE_OUTPUT_ROOT"/*) return 0 ;;
        *) return 1 ;;
    esac
}

next_backup_path() {
    local target="$1"
    local timestamp
    local candidate
    local suffix=0

    timestamp=$(date +%Y%m%d-%H%M%S)
    candidate="${target}.backup-${timestamp}"
    while [ -e "$candidate" ]; do
        ((suffix++))
        candidate="${target}.backup-${timestamp}-${suffix}"
    done
    BACKUP_PATH="$candidate"
}

select_output_action() {
    local target="$1"
    local choice

    OUTPUT_ACTION='new'
    if [ ! -e "$target" ]; then
        return 0
    fi

    while true; do
        echo -e "${YELLOW}Output already exists:${RESET} $target"
        echo '1) Skip this item'
        echo '2) Overwrite it after the new conversion succeeds'
        echo '3) Rename the existing output as a timestamped backup'
        echo '4) Cancel'
        read -r -p 'Enter your choice (1-4): ' choice
        case "$choice" in
            1) OUTPUT_ACTION='skip'; return 0 ;;
            2) OUTPUT_ACTION='overwrite'; return 0 ;;
            3) OUTPUT_ACTION='backup'; return 0 ;;
            4) OUTPUT_ACTION='cancel'; return 0 ;;
            *) echo -e "${RED}Invalid choice.${RESET}" ;;
        esac
    done
}

commit_staged_output() {
    local staged="$1"
    local target="$2"

    if ! is_safe_output_target "$target"; then
        echo -e "${RED}Refusing unsafe output target: $target${RESET}" >&2
        return 1
    fi

    mkdir -p -- "$(dirname -- "$target")"
    case "$OUTPUT_ACTION" in
        new)
            if [ -e "$target" ]; then
                echo -e "${RED}Output appeared during conversion; refusing to overwrite it: $target${RESET}" >&2
                return 1
            fi
            ;;
        overwrite)
            rm -rf -- "$target"
            ;;
        backup)
            next_backup_path "$target"
            mv -- "$target" "$BACKUP_PATH" || return 1
            echo -e "${YELLOW}Existing output moved to:${RESET} $BACKUP_PATH"
            ;;
        *)
            echo -e "${RED}Invalid commit action: $OUTPUT_ACTION${RESET}" >&2
            return 1
            ;;
    esac

    if mv -- "$staged" "$target"; then
        return 0
    fi

    if [ "$OUTPUT_ACTION" = 'backup' ] && [ -e "$BACKUP_PATH" ] && [ ! -e "$target" ]; then
        mv -- "$BACKUP_PATH" "$target" || true
    fi
    return 1
}

handle_selected_action() {
    case "$OUTPUT_ACTION" in
        skip)
            ((SKIPPED++))
            return 10
            ;;
        cancel)
            print_summary
            exit 130
            ;;
        *) return 0 ;;
    esac
}

print_summary() {
    echo
    echo -e "${GREEN}Conversion summary${RESET}"
    echo "Attempted: $ATTEMPTED"
    echo "Succeeded: $SUCCEEDED"
    echo "Skipped:   $SKIPPED"
    echo "Failed:    $FAILED"
}

finish_with_summary() {
    print_summary
    if [ "$FAILED" -gt 0 ]; then
        exit 1
    fi
}
EOT

chmod +x "rom scripts/common.sh"

echo -e "\e[32mCreating iso2xex.sh script...\e[0m"
cat << 'EOT' > "rom scripts/iso2xex.sh"
#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

input_path="/storage/emulated/0/Download/Roms/ISO Input"
output_path="/storage/emulated/0/Download/Roms/XEX Output"

mkdir -p "$output_path"

convert_iso_to_xex() {
    local iso_file="$1"
    local file_name
    local base_name
    local target
    local staging_root
    local staged_output

    file_name=$(basename -- "$iso_file")
    base_name="${file_name%.*}"
    target="$output_path/$base_name"
    ((ATTEMPTED++))

    select_output_action "$target"
    handle_selected_action
    if [ "$?" -eq 10 ]; then
        echo -e "${YELLOW}Skipped:${RESET} $file_name"
        return 0
    fi

    make_temp_dir "$output_path/.iso2xex.XXXXXX" || {
        ((FAILED++))
        return 1
    }
    staging_root="$TEMP_DIR"
    staged_output="$staging_root/$base_name"
    mkdir -p -- "$staged_output"

    echo -e "${GREEN}Creating XEX files for $file_name...${RESET}"
    if extract-xiso -x "$iso_file" -d "$staged_output" &&
       commit_staged_output "$staged_output" "$target"; then
        ((SUCCEEDED++))
        echo -e "${GREEN}Created:${RESET} $target"
    else
        ((FAILED++))
        echo -e "${RED}Failed:${RESET} $file_name" >&2
    fi

    remove_temp_dir "$staging_root"
}

while IFS= read -r -d '' iso_file; do
    convert_iso_to_xex "$iso_file"
done < <(find "$input_path" -type f -iname '*.iso' -print0)

while IFS= read -r -d '' zip_file; do
    make_temp_dir "$output_path/.iso2xex-zip.XXXXXX" || {
        ((ATTEMPTED++))
        ((FAILED++))
        continue
    }
    zip_temp="$TEMP_DIR"
    echo -e "${GREEN}Extracting archive:${RESET} $zip_file"
    if unzip -q "$zip_file" -d "$zip_temp"; then
        while IFS= read -r -d '' iso_file; do
            convert_iso_to_xex "$iso_file"
        done < <(find "$zip_temp" -type f -iname '*.iso' -print0)
    else
        ((ATTEMPTED++))
        ((FAILED++))
        echo -e "${RED}Failed to extract:${RESET} $zip_file" >&2
    fi
    remove_temp_dir "$zip_temp"
done < <(find "$input_path" -type f -iname '*.zip' -print0)

if [ "$ATTEMPTED" -eq 0 ]; then
    echo -e "${YELLOW}No ISO or ZIP files were found.${RESET}"
fi

finish_with_summary
EOT

chmod +x "rom scripts/iso2xex.sh"

echo -e "\e[32mCreating iso2zar.sh script...\e[0m"
cat << 'EOT' > "rom scripts/iso2zar.sh"
#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

input_path="/storage/emulated/0/Download/Roms/ISO Input"
xex_output_path="/storage/emulated/0/Download/Roms/XEX Output"
zar_output_path="/storage/emulated/0/Download/Roms/ZAR Output"

mkdir -p "$xex_output_path" "$zar_output_path"

convert_iso_to_zar() {
    local iso_file="$1"
    local file_name
    local base_name
    local target
    local staging_root
    local xex_folder
    local staged_zar

    file_name=$(basename -- "$iso_file")
    base_name="${file_name%.*}"
    target="$zar_output_path/$base_name.zar"
    ((ATTEMPTED++))

    select_output_action "$target"
    handle_selected_action
    if [ "$?" -eq 10 ]; then
        echo -e "${YELLOW}Skipped:${RESET} $file_name"
        return 0
    fi

    make_temp_dir "$xex_output_path/.iso2zar.XXXXXX" || {
        ((FAILED++))
        return 1
    }
    staging_root="$TEMP_DIR"
    xex_folder="$staging_root/$base_name"
    staged_zar="$staging_root/$base_name.zar"
    mkdir -p -- "$xex_folder"

    echo -e "${GREEN}Extracting XEX files for $file_name...${RESET}"
    if extract-xiso -x "$iso_file" -d "$xex_folder"; then
        echo -e "${GREEN}Creating ZAR for $file_name...${RESET}"
        if zarchive "$xex_folder" "$staged_zar" &&
           commit_staged_output "$staged_zar" "$target"; then
            ((SUCCEEDED++))
            echo -e "${GREEN}Created:${RESET} $target"
        else
            ((FAILED++))
            echo -e "${RED}Failed to create ZAR:${RESET} $file_name" >&2
        fi
    else
        ((FAILED++))
        echo -e "${RED}Failed to extract XEX files:${RESET} $file_name" >&2
    fi

    remove_temp_dir "$staging_root"
}

while IFS= read -r -d '' iso_file; do
    convert_iso_to_zar "$iso_file"
done < <(find "$input_path" -type f -iname '*.iso' -print0)

while IFS= read -r -d '' zip_file; do
    make_temp_dir "$xex_output_path/.iso2zar-zip.XXXXXX" || {
        ((ATTEMPTED++))
        ((FAILED++))
        continue
    }
    zip_temp="$TEMP_DIR"
    echo -e "${GREEN}Extracting archive:${RESET} $zip_file"
    if unzip -q "$zip_file" -d "$zip_temp"; then
        while IFS= read -r -d '' iso_file; do
            convert_iso_to_zar "$iso_file"
        done < <(find "$zip_temp" -type f -iname '*.iso' -print0)
    else
        ((ATTEMPTED++))
        ((FAILED++))
        echo -e "${RED}Failed to extract:${RESET} $zip_file" >&2
    fi
    remove_temp_dir "$zip_temp"
done < <(find "$input_path" -type f -iname '*.zip' -print0)

if [ "$ATTEMPTED" -eq 0 ]; then
    echo -e "${YELLOW}No ISO or ZIP files were found.${RESET}"
fi

finish_with_summary
EOT

chmod +x "rom scripts/iso2zar.sh"

echo -e "\e[32mCreating xex2zar.sh script...\e[0m"
cat << 'EOT' > "rom scripts/xex2zar.sh"
#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

input_path="/storage/emulated/0/Download/Roms/XEX Input"
output_path="/storage/emulated/0/Download/Roms/ZAR Output"

mkdir -p "$input_path" "$output_path"

convert_xex_folder() {
    local folder="$1"
    local folder_name
    local target
    local staging_root
    local staged_zar

    folder_name=$(basename -- "$folder")
    target="$output_path/$folder_name.zar"
    ((ATTEMPTED++))

    select_output_action "$target"
    handle_selected_action
    if [ "$?" -eq 10 ]; then
        echo -e "${YELLOW}Skipped:${RESET} $folder_name"
        return 0
    fi

    make_temp_dir "$output_path/.xex2zar.XXXXXX" || {
        ((FAILED++))
        return 1
    }
    staging_root="$TEMP_DIR"
    staged_zar="$staging_root/$folder_name.zar"

    echo -e "${GREEN}Creating ZAR for $folder_name...${RESET}"
    if zarchive "$folder" "$staged_zar" &&
       commit_staged_output "$staged_zar" "$target"; then
        ((SUCCEEDED++))
        echo -e "${GREEN}Created:${RESET} $target"
    else
        ((FAILED++))
        echo -e "${RED}Failed:${RESET} $folder_name" >&2
    fi

    remove_temp_dir "$staging_root"
}

for folder in "$input_path"/*; do
    if [ -d "$folder" ]; then
        convert_xex_folder "$folder"
    fi
done

if [ "$ATTEMPTED" -eq 0 ]; then
    echo -e "${YELLOW}No XEX folders were found.${RESET}"
fi

finish_with_summary
EOT

chmod +x "rom scripts/xex2zar.sh"

echo -e "\e[32mCreating iso2god.sh script...\e[0m"
cat << 'EOT' > "rom scripts/iso2god.sh"
#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

input_path="/storage/emulated/0/Download/Roms/ISO2GOD Input"
output_path="/storage/emulated/0/Download/Roms/ISO2GOD Output"
iso2god_bin="/usr/local/bin/iso2god"
threads="${ISO2GOD_THREADS:-2}"
conversion_mode="${ISO2GOD_MODE:-}"

ACTIVE_ORIGINAL=''
ACTIVE_OLD=''
COMPACT_SOURCE=''

mkdir -p "$output_path"

case "$threads" in
    ''|*[!0-9]*|0) threads=2 ;;
esac

restore_active_original() {
    if [ -z "$ACTIVE_ORIGINAL" ]; then
        return 0
    fi

    if [ ! -e "$ACTIVE_ORIGINAL" ] && [ -e "$ACTIVE_OLD" ]; then
        if ! mv -- "$ACTIVE_OLD" "$ACTIVE_ORIGINAL"; then
            echo -e "${RED}Could not restore source ISO:${RESET} $ACTIVE_ORIGINAL" >&2
            return 1
        fi
    elif [ ! -e "$ACTIVE_ORIGINAL" ] && [ ! -e "$ACTIVE_OLD" ]; then
        echo -e "${RED}Source ISO and recovery file are both missing:${RESET} $ACTIVE_ORIGINAL" >&2
        return 1
    elif [ -e "$ACTIVE_ORIGINAL" ] && [ -e "$ACTIVE_OLD" ]; then
        echo -e "${RED}Both the source ISO and its .old file exist; refusing to overwrite either:${RESET} $ACTIVE_ORIGINAL" >&2
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
    local old_file
    local original_file

    while IFS= read -r -d '' old_file; do
        original_file="${old_file%.old}"
        if [ ! -e "$original_file" ]; then
            if mv -- "$old_file" "$original_file"; then
                echo -e "${YELLOW}Restored an ISO left by an interrupted compact conversion:${RESET} $original_file"
            else
                echo -e "${RED}Could not restore interrupted source ISO:${RESET} $original_file" >&2
                return 1
            fi
        fi
    done < <(find "$input_path" -type f -iname '*.iso.old' -print0)
}

choose_conversion_mode() {
    local choice

    conversion_mode="${conversion_mode,,}"
    case "$conversion_mode" in
        compact|fast) return 0 ;;
        '') ;;
        *)
            echo -e "${RED}ISO2GOD_MODE must be 'compact' or 'fast'.${RESET}" >&2
            return 1
            ;;
    esac

    while true; do
        echo
        echo -e "${GREEN}ISO2GOD conversion mode${RESET}"
        echo -e "  ${GREEN}1) Compact${RESET}  Smaller output; rebuilds each ISO first"
        echo -e "  ${YELLOW}2) Fast${RESET}     Quicker; uses less temporary space"
        echo -e "  ${RED}3) Cancel${RESET}"
        echo
        read -r -p 'Select a mode [1-3]: ' choice
        case "$choice" in
            1) conversion_mode='compact'; return 0 ;;
            2) conversion_mode='fast'; return 0 ;;
            3) return 130 ;;
            *) echo -e "${RED}Invalid choice.${RESET}" ;;
        esac
    done
}

compact_rewrite() {
    local source_iso="$1"
    local rebuilt_dir="$2"
    local source_old="${source_iso}.old"
    local source_size
    local available_bytes
    local rewrite_status
    local restore_status=0
    local rebuilt_iso=''

    COMPACT_SOURCE=''

    if [ -e "$source_old" ]; then
        echo -e "${RED}Cannot compact while this recovery file exists:${RESET} $source_old" >&2
        return 1
    fi

    source_size=$(stat -c '%s' -- "$source_iso") || return 1
    available_bytes=$(df -PB1 -- "$output_path" | awk 'NR == 2 {print $4}')
    if [[ "$available_bytes" =~ ^[0-9]+$ ]] && [ "$available_bytes" -lt "$source_size" ]; then
        echo -e "${RED}Not enough free space for the temporary compact ISO.${RESET}" >&2
        echo "Needed: $source_size bytes; available: $available_bytes bytes." >&2
        return 1
    fi

    mkdir -p -- "$rebuilt_dir"
    ACTIVE_ORIGINAL="$source_iso"
    ACTIVE_OLD="$source_old"

    extract-xiso -r "$source_iso" -d "$rebuilt_dir"
    rewrite_status=$?
    restore_active_original || restore_status=$?

    if [ "$restore_status" -ne 0 ]; then
        return 1
    fi
    if [ "$rewrite_status" -ne 0 ]; then
        echo -e "${RED}Extract-XISO could not rebuild:${RESET} $(basename -- "$source_iso")" >&2
        return 1
    fi

    rebuilt_iso=$(find "$rebuilt_dir" -type f -iname '*.iso' -print -quit)
    if [ -n "$rebuilt_iso" ]; then
        COMPACT_SOURCE="$rebuilt_iso"
    else
        # Extract-XISO creates no replacement when the source is already optimized.
        COMPACT_SOURCE="$source_iso"
        echo -e "${YELLOW}ISO is already compact; converting it directly.${RESET}"
    fi
}

read_title_id() {
    local iso_file="$1"
    "$iso2god_bin" --dry-run "$iso_file" "$output_path" 2>/dev/null |
        awk '/^[[:space:]]*Title ID:/ {print $3; exit}'
}

convert_iso_to_god() {
    local iso_file="$1"
    local file_name
    local title_id
    local expected_target=''
    local staging_root
    local staged_output
    local rebuilt_dir
    local title_dir=''
    local actual_target
    local conversion_source="$iso_file"
    local conversion_succeeded=false

    file_name=$(basename -- "$iso_file")
    ((ATTEMPTED++))

    title_id=$(read_title_id "$iso_file" || true)
    if [[ "$title_id" =~ ^[[:xdigit:]]{8}$ ]]; then
        expected_target="$output_path/${title_id^^}"
        select_output_action "$expected_target"
        handle_selected_action
        if [ "$?" -eq 10 ]; then
            echo -e "${YELLOW}Skipped:${RESET} $file_name"
            return 0
        fi
    fi

    make_temp_dir "$output_path/.iso2god-stage.XXXXXX" || {
        ((FAILED++))
        return 1
    }
    staging_root="$TEMP_DIR"
    staged_output="$staging_root/output"
    rebuilt_dir="$staging_root/rebuilt"
    mkdir -p -- "$staged_output"

    if [ "$conversion_mode" = 'compact' ]; then
        echo -e "${GREEN}Compact mode: rebuilding $file_name before conversion...${RESET}"
        if compact_rewrite "$iso_file" "$rebuilt_dir"; then
            conversion_source="$COMPACT_SOURCE"
            if "$iso2god_bin" -j "$threads" "$conversion_source" "$staged_output"; then
                conversion_succeeded=true
            fi
        fi
    else
        echo -e "${GREEN}Fast mode: converting $file_name directly with ${threads} workers...${RESET}"
        if "$iso2god_bin" -j "$threads" "$iso_file" "$staged_output"; then
            conversion_succeeded=true
        else
            echo -e "${YELLOW}Direct conversion failed. Trying the compact rebuild fallback...${RESET}"
            rm -rf -- "$staged_output"
            mkdir -p -- "$staged_output"
            if compact_rewrite "$iso_file" "$rebuilt_dir"; then
                conversion_source="$COMPACT_SOURCE"
                if "$iso2god_bin" -j "$threads" "$conversion_source" "$staged_output"; then
                    conversion_succeeded=true
                fi
            fi
        fi
    fi

    if [ "$conversion_succeeded" != true ]; then
        ((FAILED++))
        echo -e "${RED}Conversion failed:${RESET} $file_name" >&2
        remove_temp_dir "$staging_root"
        return 1
    fi

    title_dir=$(find "$staged_output" -mindepth 1 -maxdepth 1 -type d -print -quit)
    if [ -z "$title_dir" ]; then
        ((FAILED++))
        echo -e "${RED}ISO2GOD produced no title directory:${RESET} $file_name" >&2
        remove_temp_dir "$staging_root"
        return 1
    fi

    actual_target="$output_path/$(basename -- "$title_dir")"
    if [ -z "$expected_target" ] || [ "$actual_target" != "$expected_target" ]; then
        select_output_action "$actual_target"
        handle_selected_action
        if [ "$?" -eq 10 ]; then
            echo -e "${YELLOW}Converted output discarded because the existing title was skipped:${RESET} $file_name"
            remove_temp_dir "$staging_root"
            return 0
        fi
    fi

    if commit_staged_output "$title_dir" "$actual_target"; then
        ((SUCCEEDED++))
        echo -e "${GREEN}Created:${RESET} $actual_target"
    else
        ((FAILED++))
        echo -e "${RED}Failed to commit GOD output:${RESET} $file_name" >&2
    fi

    remove_temp_dir "$staging_root"
}

recover_interrupted_sources || exit 1
choose_conversion_mode
mode_status=$?
if [ "$mode_status" -eq 130 ]; then
    echo 'Cancelled.'
    exit 0
elif [ "$mode_status" -ne 0 ]; then
    exit "$mode_status"
fi

echo -e "${GREEN}Using ${conversion_mode} mode for every ISO in this run.${RESET}"

while IFS= read -r -d '' iso_file; do
    convert_iso_to_god "$iso_file"
done < <(find "$input_path" -type f -iname '*.iso' -print0)

while IFS= read -r -d '' zip_file; do
    make_temp_dir "$output_path/.iso2god-zip.XXXXXX" || {
        ((ATTEMPTED++))
        ((FAILED++))
        continue
    }
    zip_temp="$TEMP_DIR"
    echo -e "${GREEN}Extracting archive:${RESET} $zip_file"
    if unzip -q "$zip_file" -d "$zip_temp"; then
        while IFS= read -r -d '' iso_file; do
            convert_iso_to_god "$iso_file"
        done < <(find "$zip_temp" -type f -iname '*.iso' -print0)
    else
        ((ATTEMPTED++))
        ((FAILED++))
        echo -e "${RED}Failed to extract:${RESET} $zip_file" >&2
    fi
    remove_temp_dir "$zip_temp"
done < <(find "$input_path" -type f -iname '*.zip' -print0)

if [ "$ATTEMPTED" -eq 0 ]; then
    echo -e "${YELLOW}No ISO or ZIP files were found.${RESET}"
fi

finish_with_summary
EOT

chmod +x "rom scripts/iso2god.sh"

echo -e "\e[32mCreating chdcreatecd.sh script...\e[0m"
cat << 'EOT' > "rom scripts/chdcreatecd.sh"
#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

INPUT_DIR="/storage/emulated/0/Download/Roms/CD Input"
OUTPUT_DIR="/storage/emulated/0/Download/Roms/CD Output"

mkdir -p "$INPUT_DIR" "$OUTPUT_DIR"

convert_cd_image() {
    local source_file="$1"
    local file_name
    local base_name
    local target
    local staging_root
    local staged_chd

    file_name=$(basename -- "$source_file")
    base_name="${file_name%.*}"
    target="$OUTPUT_DIR/$base_name.chd"
    ((ATTEMPTED++))

    select_output_action "$target"
    handle_selected_action
    if [ "$?" -eq 10 ]; then
        echo -e "${YELLOW}Skipped:${RESET} $file_name"
        return 0
    fi

    make_temp_dir "$OUTPUT_DIR/.chdcd.XXXXXX" || {
        ((FAILED++))
        return 1
    }
    staging_root="$TEMP_DIR"
    staged_chd="$staging_root/$base_name.chd"

    echo -e "${GREEN}Creating CHD from $file_name...${RESET}"
    if chdman createcd -i "$source_file" -o "$staged_chd" &&
       commit_staged_output "$staged_chd" "$target"; then
        ((SUCCEEDED++))
        echo -e "${GREEN}Created:${RESET} $target"
    else
        ((FAILED++))
        echo -e "${RED}Failed:${RESET} $file_name" >&2
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
    make_temp_dir "$OUTPUT_DIR/.chdcd-zip.XXXXXX" || {
        ((ATTEMPTED++))
        ((FAILED++))
        continue
    }
    zip_temp="$TEMP_DIR"
    echo -e "${GREEN}Extracting archive:${RESET} $zip_file"
    if unzip -q "$zip_file" -d "$zip_temp"; then
        process_cd_tree "$zip_temp"
    else
        ((ATTEMPTED++))
        ((FAILED++))
        echo -e "${RED}Failed to extract:${RESET} $zip_file" >&2
    fi
    remove_temp_dir "$zip_temp"
done < <(find "$INPUT_DIR" -type f -iname '*.zip' -print0)

if [ "$ATTEMPTED" -eq 0 ]; then
    echo -e "${YELLOW}No CUE, ISO, GDI or ZIP files were found.${RESET}"
fi

finish_with_summary
EOT

chmod +x "rom scripts/chdcreatecd.sh"

echo -e "\e[32mCreating chdcreatedvd.sh script...\e[0m"
cat << 'EOT' > "rom scripts/chdcreatedvd.sh"
#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

INPUT_DIR="/storage/emulated/0/Download/Roms/DVD Input"
OUTPUT_DIR="/storage/emulated/0/Download/Roms/DVD Output"

mkdir -p "$INPUT_DIR" "$OUTPUT_DIR"

convert_dvd_image() {
    local source_file="$1"
    local file_name
    local base_name
    local extension
    local target
    local staging_root
    local staged_chd

    file_name=$(basename -- "$source_file")
    base_name="${file_name%.*}"
    extension="${file_name##*.}"
    target="$OUTPUT_DIR/$base_name.chd"
    ((ATTEMPTED++))

    select_output_action "$target"
    handle_selected_action
    if [ "$?" -eq 10 ]; then
        echo -e "${YELLOW}Skipped:${RESET} $file_name"
        return 0
    fi

    make_temp_dir "$OUTPUT_DIR/.chddvd.XXXXXX" || {
        ((FAILED++))
        return 1
    }
    staging_root="$TEMP_DIR"
    staged_chd="$staging_root/$base_name.chd"

    echo -e "${GREEN}Creating DVD CHD from $file_name...${RESET}"
    if [ "${extension,,}" = 'iso' ]; then
        chdman createdvd -hs 2048 -i "$source_file" -o "$staged_chd"
        conversion_status=$?
    else
        chdman createdvd -i "$source_file" -o "$staged_chd"
        conversion_status=$?
    fi

    if [ "$conversion_status" -eq 0 ] &&
       commit_staged_output "$staged_chd" "$target"; then
        ((SUCCEEDED++))
        echo -e "${GREEN}Created:${RESET} $target"
    else
        ((FAILED++))
        echo -e "${RED}Failed:${RESET} $file_name" >&2
    fi

    remove_temp_dir "$staging_root"
}

process_dvd_tree() {
    local search_root="$1"
    local source_file
    while IFS= read -r -d '' source_file; do
        convert_dvd_image "$source_file"
    done < <(find "$search_root" -type f \( -iname '*.cue' -o -iname '*.iso' \) -print0)
}

process_dvd_tree "$INPUT_DIR"

while IFS= read -r -d '' zip_file; do
    make_temp_dir "$OUTPUT_DIR/.chddvd-zip.XXXXXX" || {
        ((ATTEMPTED++))
        ((FAILED++))
        continue
    }
    zip_temp="$TEMP_DIR"
    echo -e "${GREEN}Extracting archive:${RESET} $zip_file"
    if unzip -q "$zip_file" -d "$zip_temp"; then
        process_dvd_tree "$zip_temp"
    else
        ((ATTEMPTED++))
        ((FAILED++))
        echo -e "${RED}Failed to extract:${RESET} $zip_file" >&2
    fi
    remove_temp_dir "$zip_temp"
done < <(find "$INPUT_DIR" -type f -iname '*.zip' -print0)

if [ "$ATTEMPTED" -eq 0 ]; then
    echo -e "${YELLOW}No CUE, ISO or ZIP files were found.${RESET}"
fi

finish_with_summary
EOT

chmod +x "rom scripts/chdcreatedvd.sh"

echo -e "\e[32mVerifying the completed installation...\e[0m"

required_commands=(extract-xiso chdman zarchive iso2god)
for required_command in "${required_commands[@]}"; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
        echo -e "\e[31mVerification failed: $required_command is unavailable.\e[0m" >&2
        exit 1
    fi
done

if ! file_sha256_matches "$ISO2GOD_BIN" "$ISO2GOD_SHA256"; then
    echo -e "\e[31mVerification failed: the ISO2GOD executable checksum is incorrect.\e[0m" >&2
    exit 1
fi

required_scripts=(
    common.sh
    iso2xex.sh
    iso2zar.sh
    xex2zar.sh
    iso2god.sh
    chdcreatecd.sh
    chdcreatedvd.sh
)

for required_script in "${required_scripts[@]}"; do
    if [ ! -x "$HOME/rom scripts/$required_script" ]; then
        echo -e "\e[31mVerification failed: $required_script is missing or not executable.\e[0m" >&2
        exit 1
    fi
done

echo -e "\e[32mInstallation verified successfully.\e[0m"

EOF
then
    echo -e "\e[31mUbuntu setup or verification failed. convert.sh was not created.\e[0m" >&2
    exit 1
fi

case "$0" in
    *.sh)
        if [ -f "$0" ] && grep -q "SCRIPT_VERSION='3.2.0'" "$0"; then
            source_installer=$(readlink -f "$0")
            saved_installer="$HOME/setup_complete_optimized.sh"
            if [ "$source_installer" != "$saved_installer" ]; then
                install -m 0755 "$source_installer" "$saved_installer"
            fi
        fi
        ;;
esac

echo -e "\e[32mCreating convert.sh script...\e[0m"
cat << 'EOT' > convert.sh
#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

CYAN='\e[36m'
GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'
BOLD='\e[1m'
RESET='\e[0m'

# Function to run a script in the Ubuntu environment
run_script_in_ubuntu() {
  case "$1" in
    1)
      proot-distro login ubuntu -- bash -c "cd ~/\"rom scripts\" && ./chdcreatecd.sh"
      ;;
    2)
      proot-distro login ubuntu -- bash -c "cd ~/\"rom scripts\" && ./chdcreatedvd.sh"
      ;;
    3)
      proot-distro login ubuntu -- bash -c "cd ~/\"rom scripts\" && ./iso2xex.sh"
      ;;
    4)
      proot-distro login ubuntu -- bash -c "cd ~/\"rom scripts\" && ./xex2zar.sh"
      ;;
    5)
      proot-distro login ubuntu -- bash -c "cd ~/\"rom scripts\" && ./iso2zar.sh"
      ;;
    6)
      proot-distro login ubuntu -- bash -c "cd ~/\"rom scripts\" && ./iso2god.sh"
      ;;
    7)
      "$HOME/setup_complete_optimized.sh" --normal
      ;;
    8)
      "$HOME/setup_complete_optimized.sh" --update
      ;;
    *)
      echo -e "\e[31mInvalid choice. Please select a number between 1 and 8.\e[0m"
      return 2
      ;;
  esac
}

# Display menu and prompt for user input
echo
echo -e "${BOLD}${CYAN}ROM Conversion Tools${RESET}"
echo -e "  ${CYAN}1)${RESET} ${GREEN}Convert CD image to CHD${RESET}       CD compression"
echo -e "  ${CYAN}2)${RESET} ${GREEN}Convert DVD image to CHD${RESET}      DVD compression"
echo -e "  ${CYAN}3)${RESET} ${GREEN}Extract Xbox ISO to XEX${RESET}"
echo -e "  ${CYAN}4)${RESET} ${GREEN}Compress XEX folder to ZAR${RESET}"
echo -e "  ${CYAN}5)${RESET} ${GREEN}Convert Xbox ISO to ZAR${RESET}"
echo -e "  ${CYAN}6)${RESET} ${GREEN}Convert Xbox 360 ISO to GOD${RESET}"
echo
echo -e "${BOLD}${YELLOW}Maintenance${RESET}"
echo -e "  ${YELLOW}7)${RESET} Repair conversion tools"
echo -e "  ${YELLOW}8)${RESET} Update packages and repair tools"
echo

read -r -p "Select an option [1-8]: " choice

# Run the script in the Ubuntu environment
run_script_in_ubuntu "$choice"

# Exit the script
exit 0
EOT

chmod +x convert.sh


echo -e "\e[35mSetup complete\e[0m"
echo -e "\e[32mTo use the conversion scripts, open Termux and type:\e[0m"
echo -e "\e[34m./convert.sh\e[0m"

