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

print_menu_heading() {
    printf '%b%b%s%b\n' "$BOLD" "$CYAN" "$1" "$RESET"
}

print_menu_option() {
    local number="$1" label="$2" description="$3"
    printf '  %b%s)%b %b%-24s%b %s\n' \
        "$CYAN" "$number" "$RESET" "$GREEN" "$label" "$RESET" "$description"
}

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
print_menu_heading 'ROM Conversion Tools'
print_menu_option 1 'Convert CD image to CHD' 'CD compression'
print_menu_option 2 'Convert DVD image to CHD' 'DVD compression'
print_menu_option 3 'Extract Xbox ISO to XEX' 'Create an extracted game folder'
print_menu_option 4 'Compress XEX folder to ZAR' 'Archive an extracted game folder'
print_menu_option 5 'Convert Xbox ISO to ZAR' 'Extract and archive an Xbox ISO'
print_menu_option 6 'Convert Xbox 360 ISO to GOD' 'Create a Games on Demand container'
echo
print_menu_heading 'Maintenance'
print_menu_option 7 'Repair conversion tools' 'Repair without a full package upgrade'
print_menu_option 8 'Update packages and repair tools' 'Upgrade packages before repairing tools'
echo

read -r -p 'Select an option [1-8]: ' choice
run_choice "$choice"
