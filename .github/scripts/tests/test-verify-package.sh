#!/bin/bash
# Tests for .github/scripts/verify-package.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Assembles a valid package (version 1.2.3) into a fresh temp dir and sets DIST.
setup_valid_package() {
    local root
    root="$(mktemp -d)"
    make_fixture_src "$root/src"
    make_fixture_artifacts "$root/artifacts"
    DIST="$root/dist"
    bash "$SCRIPTS_DIR/assemble-package.sh" "$root/src" "$root/artifacts" "$DIST" 1.2.3
}

# Runs verify-package.sh; sets VERIFY_OUTPUT and VERIFY_EXIT.
run_verify() {
    VERIFY_EXIT=0
    VERIFY_OUTPUT="$(bash "$SCRIPTS_DIR/verify-package.sh" "$DIST" "${1:-1.2.3}" 2>&1)" || VERIFY_EXIT=$?
}

expect_failure_naming() {
    [ "$VERIFY_EXIT" -eq 1 ] || fail "expected exit 1, got $VERIFY_EXIT"
    echo "$VERIFY_OUTPUT" | grep -qF -- "$1" || fail "output should name '$1', got: $VERIFY_OUTPUT"
}

test_valid_package_passes() {
    setup_valid_package
    run_verify
    assert_eq "$VERIFY_EXIT" "0"
}

test_missing_binary_fails() {
    setup_valid_package
    rm "$DIST/Plugins/macOS/UnityMCPProxy.bundle"
    run_verify
    expect_failure_naming "Plugins/macOS/UnityMCPProxy.bundle"
}

test_empty_binary_fails() {
    setup_valid_package
    : > "$DIST/Plugins/Windows/x86_64/UnityMCPProxy.dll"
    run_verify
    expect_failure_naming "Plugins/Windows/x86_64/UnityMCPProxy.dll"
}

test_missing_meta_fails() {
    setup_valid_package
    rm "$DIST/README.md.meta"
    run_verify
    expect_failure_naming "README.md.meta"
}

test_wrong_version_fails() {
    setup_valid_package
    run_verify 9.9.9
    expect_failure_naming "9.9.9"
}

test_wrong_name_fails() {
    setup_valid_package
    sed -i 's/com.emeryporter.unitymcp/com.other.pkg/' "$DIST/package.json"
    run_verify
    expect_failure_naming "com.emeryporter.unitymcp"
}

run_tests
