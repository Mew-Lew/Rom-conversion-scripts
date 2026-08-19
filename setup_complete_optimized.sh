#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

GREEN='\e[32m'
YELLOW='\e[33m'
BLUE='\e[34m'
CYAN='\e[36m'
RED='\e[31m'
MAGENTA='\e[35m'
BOLD='\e[1m'
RESET='\e[0m'

SCRIPT_VERSION='3.5.1'
ROM_SCRIPTS_REF="${ROM_SCRIPTS_REF:-v3.5.1}"
REPOSITORY='Mew-Lew/Rom-conversion-scripts'
RAW_BASE_URL="https://raw.githubusercontent.com/$REPOSITORY/$ROM_SCRIPTS_REF"
CONVERT_SHA256='54b5d9b184c692d4e6e7a297fc01e891631dd1adce462c657b49b75a4df53f09'

TEMP_PATHS=()

on_error() {
    local status=$?
    printf '%bSetup failed on line %s with exit code %s.%b\n' \
        "$RED" "$1" "$status" "$RESET" >&2
    exit "$status"
}

cleanup() {
    local path
    for path in "${TEMP_PATHS[@]}"; do
        [[ -n "$path" && -e "$path" ]] && rm -rf -- "$path"
    done
}

trap 'on_error "$LINENO"' ERR
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

usage() {
    echo "Usage: $0 [--normal|--update]"
    echo '  --normal  Install or repair tools without a full system upgrade'
    echo '  --update  Upgrade Termux and Ubuntu packages, then install or repair tools'
}

print_menu_heading() {
    printf '%b%b%s%b\n' "$BOLD" "$CYAN" "$1" "$RESET"
}

print_menu_option() {
    local number="$1" label="$2" description="$3"
    printf '  %b%s)%b %b%-24s%b %s\n' \
        "$CYAN" "$number" "$RESET" "$GREEN" "$label" "$RESET" "$description"
}

case "${1:-}" in
    --normal|'') SETUP_MODE='normal' ;;
    --update) SETUP_MODE='update' ;;
    -h|--help) usage; exit 0 ;;
    *) printf '%bUnknown option: %s%b\n' "$RED" "$1" "$RESET" >&2; usage >&2; exit 2 ;;
esac

if (( $# == 0 )); then
    print_menu_heading "ROM Conversion Scripts setup $SCRIPT_VERSION"
    print_menu_option 1 'Normal setup or repair' 'Install or repair tools without full upgrades'
    print_menu_option 2 'Update and setup' 'Upgrade packages, then install or repair tools'
    print_menu_option 3 'Cancel' 'Exit without changing the installation'
    read -r -p 'Enter your choice (1-3): ' setup_choice
    case "$setup_choice" in
        1) SETUP_MODE='normal' ;;
        2) SETUP_MODE='update' ;;
        3) exit 0 ;;
        *) printf '%bInvalid setup choice.%b\n' "$RED" "$RESET" >&2; exit 2 ;;
    esac
fi

printf '%bUpdating Termux package lists...%b\n' "$GREEN" "$RESET"
pkg update -y
if [[ "$SETUP_MODE" == 'update' ]]; then
    printf '%bUpgrading Termux packages...%b\n' "$GREEN" "$RESET"
    pkg upgrade -y
else
    printf '%bSkipping the full Termux upgrade in normal mode.%b\n' "$YELLOW" "$RESET"
fi

printf '%bInstalling required Termux packages...%b\n' "$GREEN" "$RESET"
pkg install -y curl proot-distro

if [[ ! -e "$HOME/storage/shared" ]]; then
    printf '%bRequesting Termux storage access...%b\n' "$GREEN" "$RESET"
    termux-setup-storage
    read -r -p 'Grant storage permission, then press Enter to continue... '
    if [[ ! -e "$HOME/storage/shared" ]]; then
        printf '%bShared storage is still unavailable. Grant Termux storage permission and rerun setup.%b\n' \
            "$RED" "$RESET" >&2
        exit 1
    fi
fi

if ! proot-distro login ubuntu -- true >/dev/null 2>&1; then
    printf '%bInstalling the Ubuntu environment...%b\n' "$GREEN" "$RESET"
    proot-distro install ubuntu
else
    printf '%bUbuntu is already installed; reusing it.%b\n' "$YELLOW" "$RESET"
fi

printf '%bConfiguring conversion tools inside Ubuntu...%b\n' "$GREEN" "$RESET"
if ! proot-distro login ubuntu -- env \
    SETUP_MODE="$SETUP_MODE" \
    ROM_RAW_BASE_URL="$RAW_BASE_URL" \
    bash -s <<'UBUNTU_SETUP'
set -Eeuo pipefail

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
RESET='\e[0m'
export DEBIAN_FRONTEND=noninteractive

INSTALL_TEMP_PATHS=()
cleanup_install_temp() {
    local path
    for path in "${INSTALL_TEMP_PATHS[@]}"; do
        [[ -n "$path" && -e "$path" ]] && rm -rf -- "$path"
    done
}
trap 'status=$?; printf "\e[31mUbuntu setup failed on line %s with exit code %s.\e[0m\n" "$LINENO" "$status" >&2; exit "$status"' ERR
trap cleanup_install_temp EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

printf '%bUpdating Ubuntu package lists...%b\n' "$GREEN" "$RESET"
apt-get update
if [[ "$SETUP_MODE" == 'update' ]]; then
    printf '%bUpgrading Ubuntu packages...%b\n' "$GREEN" "$RESET"
    apt-get upgrade -y
else
    printf '%bSkipping the full Ubuntu upgrade in normal mode.%b\n' "$YELLOW" "$RESET"
fi

printf '%bInstalling required Ubuntu packages...%b\n' "$GREEN" "$RESET"
apt-get install -y \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    mame-tools \
    tar \
    unzip \
    zarchive-tools

if [[ "$(uname -m)" != 'aarch64' ]]; then
    printf '%bUnsupported Ubuntu architecture: %s. This installer requires AArch64.%b\n' \
        "$RED" "$(uname -m)" "$RESET" >&2
    exit 1
fi

file_sha256_matches() {
    local file_path="$1" expected_hash="$2"
    [[ -f "$file_path" ]] &&
        [[ "$(sha256sum "$file_path" | awk '{print $1}')" == "$expected_hash" ]]
}

download_verified() {
    local url="$1" destination="$2" expected_hash="$3"
    local download
    download=$(mktemp)
    INSTALL_TEMP_PATHS+=("$download")
    curl -fL --retry 3 --retry-delay 2 --connect-timeout 20 "$url" -o "$download"
    if ! file_sha256_matches "$download" "$expected_hash"; then
        printf '%bChecksum verification failed for %s.%b\n' "$RED" "$url" "$RESET" >&2
        return 1
    fi
    install -m 0755 "$download" "$destination"
}

EXTRACT_XISO_COMMIT='b72e5b60d598ec6df80534cda19cdcd4361aa18c'
EXTRACT_XISO_ARCHIVE_SHA256='68789095f8a6011f0cd07ab5794909be867dc5f8448f062c503316e262f046a0'
EXTRACT_XISO_ARCHIVE_URL="https://github.com/XboxDev/extract-xiso/archive/${EXTRACT_XISO_COMMIT}.tar.gz"
EXTRACT_XISO_STAMP='/usr/local/share/rom-conversion-scripts/extract-xiso.commit'

ISO2GOD_VERSION='v1.8.1'
ISO2GOD_SHA256='e32c812a803da0a3ff65cd405a42a463b05e09a8589e06a956db57d99eba852b'
ISO2GOD_URL="https://github.com/iliazeus/iso2god-rs/releases/download/${ISO2GOD_VERSION}/iso2god-aarch64-linux"
ISO2GOD_BIN='/usr/local/bin/iso2god'

if command -v extract-xiso >/dev/null 2>&1 &&
   [[ -f "$EXTRACT_XISO_STAMP" ]] &&
   [[ "$(tr -d '\r\n' < "$EXTRACT_XISO_STAMP")" == "$EXTRACT_XISO_COMMIT" ]]; then
    printf '%bextract-xiso is already current; skipping its build.%b\n' "$YELLOW" "$RESET"
else
    printf '%bBuilding the pinned extract-xiso revision...%b\n' "$GREEN" "$RESET"
    extract_archive=$(mktemp --suffix=.tar.gz)
    extract_workspace=$(mktemp -d)
    INSTALL_TEMP_PATHS+=("$extract_archive" "$extract_workspace")
    curl -fL --retry 3 --retry-delay 2 --connect-timeout 20 \
        "$EXTRACT_XISO_ARCHIVE_URL" -o "$extract_archive"
    if ! file_sha256_matches "$extract_archive" "$EXTRACT_XISO_ARCHIVE_SHA256"; then
        printf '%bextract-xiso archive checksum verification failed.%b\n' "$RED" "$RESET" >&2
        exit 1
    fi
    tar -xzf "$extract_archive" -C "$extract_workspace"
    extract_source="$extract_workspace/extract-xiso-${EXTRACT_XISO_COMMIT}"
    cmake -S "$extract_source" -B "$extract_source/build" -DCMAKE_BUILD_TYPE=Release
    cmake --build "$extract_source/build" --parallel "$(nproc)"
    cmake --install "$extract_source/build"
    install -d "$(dirname -- "$EXTRACT_XISO_STAMP")"
    printf '%s\n' "$EXTRACT_XISO_COMMIT" > "$EXTRACT_XISO_STAMP"
fi

if file_sha256_matches "$ISO2GOD_BIN" "$ISO2GOD_SHA256"; then
    printf '%bISO2GOD %s is already installed; skipping its download.%b\n' \
        "$YELLOW" "$ISO2GOD_VERSION" "$RESET"
else
    printf '%bDownloading verified ISO2GOD %s...%b\n' "$GREEN" "$ISO2GOD_VERSION" "$RESET"
    download_verified "$ISO2GOD_URL" "$ISO2GOD_BIN" "$ISO2GOD_SHA256"
fi

mkdir -p -- \
    '/storage/emulated/0/Download/Roms/CD Input' \
    '/storage/emulated/0/Download/Roms/CD Output' \
    '/storage/emulated/0/Download/Roms/DVD Input' \
    '/storage/emulated/0/Download/Roms/DVD Output' \
    '/storage/emulated/0/Download/Roms/ISO Input' \
    '/storage/emulated/0/Download/Roms/XEX Input' \
    '/storage/emulated/0/Download/Roms/XEX Output' \
    '/storage/emulated/0/Download/Roms/ZAR Output' \
    '/storage/emulated/0/Download/Roms/ISO2GOD Input' \
    '/storage/emulated/0/Download/Roms/ISO2GOD Output'

script_dir="$HOME/rom scripts"
script_stage=$(mktemp -d)
INSTALL_TEMP_PATHS+=("$script_stage")

# Repository path | installed filename | SHA-256
SCRIPT_SPECS=(
    'common.sh|common.sh|9173a20e65aa83a9e33fc79f3f382c32170910b22b66442dcc292a5372f60ed6'
    'CHD/chdcreatecd.sh|chdcreatecd.sh|e63d2020896ffa36f4398d187547ecc813f0cb1492fb67559c7cfa547ebe3139'
    'CHD/chdcreatedvd.sh|chdcreatedvd.sh|8bd1fc120dab821baf91e23cf4733f4c66d2b92271fc97de3cd2adeb4ef017c3'
    'ISO-XEX-ZAR/iso2xex/iso2xex.sh|iso2xex.sh|77975e6992146ff5315f4bba7acc1daca5d753c8b0a3ac07428b6993124bebd6'
    'ISO-XEX-ZAR/iso2zar/iso2zar.sh|iso2zar.sh|8d0fd02ac6f03b7e67725ccab3d638549ddf979ac58440a05c68186fa14baa44'
    'ISO-XEX-ZAR/xex2zar/xex2zar.sh|xex2zar.sh|83c89e193921e14574a32b29670db8592423f253b8caeabab579c6b823f2212f'
    'ISO2GOD/Iso2god.sh|iso2god.sh|6328abab91cdc41ca6632fa24a2b45da94082bbcf044503258853763ae48be14'
)

printf '%bDownloading verified conversion scripts...%b\n' "$GREEN" "$RESET"
for spec in "${SCRIPT_SPECS[@]}"; do
    IFS='|' read -r repository_path installed_name expected_hash <<< "$spec"
    download_verified \
        "$ROM_RAW_BASE_URL/$repository_path" \
        "$script_stage/$installed_name" \
        "$expected_hash"
    bash -n "$script_stage/$installed_name"
done

mkdir -p -- "$script_dir"
for staged_script in "$script_stage"/*.sh; do
    install -m 0755 "$staged_script" "$script_dir/$(basename -- "$staged_script")"
done

required_commands=(extract-xiso chdman zarchive iso2god)
for required_command in "${required_commands[@]}"; do
    command -v "$required_command" >/dev/null 2>&1 || {
        printf '%bVerification failed: %s is unavailable.%b\n' \
            "$RED" "$required_command" "$RESET" >&2
        exit 1
    }
done
file_sha256_matches "$ISO2GOD_BIN" "$ISO2GOD_SHA256" || {
    printf '%bVerification failed: ISO2GOD checksum is incorrect.%b\n' "$RED" "$RESET" >&2
    exit 1
}
for spec in "${SCRIPT_SPECS[@]}"; do
    IFS='|' read -r _ installed_name expected_hash <<< "$spec"
    file_sha256_matches "$script_dir/$installed_name" "$expected_hash" || {
        printf '%bVerification failed: %s is missing or incorrect.%b\n' \
            "$RED" "$installed_name" "$RESET" >&2
        exit 1
    }
done

printf '%bUbuntu installation verified successfully.%b\n' "$GREEN" "$RESET"
UBUNTU_SETUP
then
    printf '%bUbuntu setup or verification failed. convert.sh was not installed.%b\n' \
        "$RED" "$RESET" >&2
    exit 1
fi

file_sha256_matches_termux() {
    local file_path="$1" expected_hash="$2"
    [[ -f "$file_path" ]] &&
        [[ "$(sha256sum "$file_path" | awk '{print $1}')" == "$expected_hash" ]]
}

download_termux_file() {
    local url="$1" destination="$2" expected_hash="$3"
    local download
    download=$(mktemp)
    TEMP_PATHS+=("$download")
    curl -fL --retry 3 --retry-delay 2 --connect-timeout 20 "$url" -o "$download"
    if ! file_sha256_matches_termux "$download" "$expected_hash"; then
        printf '%bChecksum verification failed for %s.%b\n' "$RED" "$url" "$RESET" >&2
        return 1
    fi
    bash -n "$download"
    install -m 0755 "$download" "$destination"
}

printf '%bInstalling the Termux launcher...%b\n' "$GREEN" "$RESET"
download_termux_file "$RAW_BASE_URL/convert.sh" "$HOME/convert.sh" "$CONVERT_SHA256"

# Keep a reusable installer. A local file is preferred; piped installs fetch the same pinned revision.
current_source="${BASH_SOURCE[0]:-}"
if [[ -n "$current_source" && -f "$current_source" ]]; then
    install -m 0755 "$current_source" "$HOME/setup_complete_optimized.sh"
else
    saved_installer_temp=$(mktemp)
    TEMP_PATHS+=("$saved_installer_temp")
    curl -fL --retry 3 --retry-delay 2 --connect-timeout 20 \
        "$RAW_BASE_URL/setup_complete_optimized.sh" -o "$saved_installer_temp"
    bash -n "$saved_installer_temp"
    install -m 0755 "$saved_installer_temp" "$HOME/setup_complete_optimized.sh"
fi

printf '%bSetup complete%b\n' "$MAGENTA" "$RESET"
printf '%bTo use the conversion scripts, open Termux and run:%b\n' "$GREEN" "$RESET"
printf '%b./convert.sh%b\n' "$BLUE" "$RESET"
