#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

CYAN='\e[36m'
GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'
BOLD='\e[1m'
RESET='\e[0m'

SETUP_SCRIPT="$HOME/setup_complete_optimized.sh"

on_error() {
    local status=$?
    printf '%bConversion launcher failed on line %s (exit %s).%b\n' \
        "$RED" "$1" "$status" "$RESET" >&2
    exit "$status"
}
trap 'on_error "$LINENO"' ERR

run_ubuntu_script() {
    local script_name="$1"
    proot-distro login ubuntu -- bash -c 'cd "$HOME/rom scripts" && exec "./$1"' bash "$script_name"
}

run_choice() {
    case "$1" in
        1) run_ubuntu_script chdcreatecd.sh ;;
        2) run_ubuntu_script chdcreatedvd.sh ;;
        3) run_ubuntu_script iso2xex.sh ;;
        4) run_ubuntu_script xex2zar.sh ;;
        5) run_ubuntu_script iso2zar.sh ;;
        6) run_ubuntu_script iso2god.sh ;;
        7)
            [[ -x "$SETUP_SCRIPT" ]] || {
                printf '%bInstaller is missing: %s%b\n' "$RED" "$SETUP_SCRIPT" "$RESET" >&2
                return 1
            }
            "$SETUP_SCRIPT" --normal
            ;;
        8)
            [[ -x "$SETUP_SCRIPT" ]] || {
                printf '%bInstaller is missing: %s%b\n' "$RED" "$SETUP_SCRIPT" "$RESET" >&2
                return 1
            }
            "$SETUP_SCRIPT" --update
            ;;
        *)
            printf '%bInvalid choice. Select a number from 1 to 8.%b\n' "$RED" "$RESET" >&2
            return 2
            ;;
    esac
}

if ! command -v proot-distro >/dev/null 2>&1; then
    printf '%bproot-distro is not installed. Run the setup script first.%b\n' "$RED" "$RESET" >&2
    exit 1
fi

echo
printf '%b%bROM Conversion Tools%b\n' "$BOLD" "$CYAN" "$RESET"
printf '  %b1)%b %bConvert CD image to CHD%b       CD compression\n' "$CYAN" "$RESET" "$GREEN" "$RESET"
printf '  %b2)%b %bConvert DVD image to CHD%b      DVD compression\n' "$CYAN" "$RESET" "$GREEN" "$RESET"
printf '  %b3)%b %bExtract Xbox ISO to XEX%b\n' "$CYAN" "$RESET" "$GREEN" "$RESET"
printf '  %b4)%b %bCompress XEX folder to ZAR%b\n' "$CYAN" "$RESET" "$GREEN" "$RESET"
printf '  %b5)%b %bConvert Xbox ISO to ZAR%b\n' "$CYAN" "$RESET" "$GREEN" "$RESET"
printf '  %b6)%b %bConvert Xbox 360 ISO to GOD%b\n' "$CYAN" "$RESET" "$GREEN" "$RESET"
echo
printf '%b%bMaintenance%b\n' "$BOLD" "$YELLOW" "$RESET"
printf '  %b7)%b Repair conversion tools\n' "$YELLOW" "$RESET"
printf '  %b8)%b Update packages and repair tools\n' "$YELLOW" "$RESET"
echo

read -r -p 'Select an option [1-8]: ' choice
run_choice "$choice"
