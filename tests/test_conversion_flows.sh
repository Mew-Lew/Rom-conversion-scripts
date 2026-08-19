#!/usr/bin/env bash

set -Eeuo pipefail

REPOSITORY_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)

cleanup() {
    rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    printf 'Test failed: %s\n' "$1" >&2
    exit 1
}

assert_file_contains() {
    local file_path="$1" expected_value="$2"
    grep -Fqx -- "$expected_value" "$file_path" ||
        fail "Expected $file_path to contain $expected_value"
}

assert_file_lacks() {
    local file_path="$1" unexpected_value="$2"
    if grep -Fqx -- "$unexpected_value" "$file_path"; then
        fail "Did not expect $file_path to contain $unexpected_value"
    fi
}

assert_file_has_fragment() {
    local file_path="$1" expected_value="$2"
    grep -Fq -- "$expected_value" "$file_path" ||
        fail "Expected $file_path to contain $expected_value"
}

test_batch_output_action() {
    local first_target="$TEST_ROOT/first-output"
    local second_target="$TEST_ROOT/second-output"

    ROM_ROOT="$TEST_ROOT/Roms"
    SAFE_OUTPUT_ROOT="$ROM_ROOT"
    source "$REPOSITORY_ROOT/common.sh"
    trap cleanup EXIT

    : > "$first_target"
    : > "$second_target"
    BATCH_OUTPUT_ACTION=''
    select_output_action "$first_target" <<< '5' > /dev/null
    [[ "$OUTPUT_ACTION" == 'overwrite' ]] || fail 'Replace all did not select overwrite'
    [[ "$BATCH_OUTPUT_ACTION" == 'overwrite' ]] || fail 'Replace all was not saved for the batch'

    select_output_action "$second_target"
    [[ "$OUTPUT_ACTION" == 'overwrite' ]] || fail 'Batch overwrite was not reused'
}

write_iso2god_mock() {
    local mock_path="$1"
    cat > "$mock_path" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${1:-}" == '--dry-run' ]]; then
    printf 'Title ID: 12345678\n'
    exit 0
fi

printf '%s\n' "$@" > "$MOCK_LOG"
destination="${!#}"
mkdir -p -- "$destination/12345678"
MOCK
    chmod +x "$mock_path"
}

write_extract_xiso_mock() {
    local mock_path="$1"
    cat > "$mock_path" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail

source_iso=''
destination=''
while (( $# > 0 )); do
    case "$1" in
        -r) source_iso="$2"; shift 2 ;;
        -d) destination="$2"; shift 2 ;;
        *) shift ;;
    esac
done

mv -- "$source_iso" "${source_iso}.old"
mkdir -p -- "$destination"
: > "$destination/rebuilt.iso"
MOCK
    chmod +x "$mock_path"
}

write_unzip_mock() {
    local mock_path="$1"
    cat > "$mock_path" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
    chmod +x "$mock_path"
}

test_iso2god_mode() {
    local mode="$1"
    local mode_root="$TEST_ROOT/iso2god-$mode"
    local installed_dir="$mode_root/installed"
    local mock_dir="$mode_root/mock-bin"
    local rom_root="$mode_root/Roms"
    local input_dir="$rom_root/ISO2GOD Input"
    local output_dir="$rom_root/ISO2GOD Output"
    local log_path="$mode_root/iso2god.log"

    mkdir -p -- "$installed_dir" "$mock_dir" "$input_dir"
    cp -- "$REPOSITORY_ROOT/ISO2GOD/Iso2god.sh" "$installed_dir/iso2god.sh"
    cp -- "$REPOSITORY_ROOT/common.sh" "$installed_dir/common.sh"
    write_iso2god_mock "$mock_dir/iso2god"
    write_extract_xiso_mock "$mock_dir/extract-xiso"
    write_unzip_mock "$mock_dir/unzip"
    : > "$input_dir/game.iso"

    MOCK_LOG="$log_path" PATH="$mock_dir:$PATH" ROM_ROOT="$rom_root" \
        ISO2GOD_MODE="$mode" ISO2GOD_BIN="$mock_dir/iso2god" \
        bash "$installed_dir/iso2god.sh" > /dev/null

    [[ -d "$output_dir/12345678" ]] || fail "ISO2GOD $mode did not create output"
    case "$mode" in
        untouched)
            assert_file_lacks "$log_path" '--trim'
            assert_file_contains "$log_path" "$input_dir/game.iso"
            ;;
        partial)
            assert_file_contains "$log_path" '--trim'
            assert_file_contains "$log_path" "$input_dir/game.iso"
            ;;
        remove-all)
            assert_file_has_fragment "$log_path" "$output_dir/.iso2god-stage"
            [[ -f "$input_dir/game.iso" ]] || fail 'Remove all did not restore the source ISO'
            [[ ! -e "$input_dir/game.iso.old" ]] || fail 'Remove all left a recovery ISO behind'
            [[ -z "$(find "$output_dir" -maxdepth 1 -name '.iso2god-stage.*' -print -quit)" ]] ||
                fail 'Remove all did not remove its staged rebuilt ISO'
            ;;
    esac
}

test_batch_output_action
test_iso2god_mode untouched
test_iso2god_mode partial
test_iso2god_mode remove-all

printf 'All conversion flow tests passed.\n'
