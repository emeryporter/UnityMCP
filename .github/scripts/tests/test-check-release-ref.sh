#!/bin/bash
# Tests for .github/scripts/check-release-ref.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Runs check-release-ref.sh; sets CHECK_OUTPUT and CHECK_EXIT.
run_check() {
    CHECK_EXIT=0
    CHECK_OUTPUT="$(bash "$SCRIPTS_DIR/check-release-ref.sh" "$1" "$2" 2>&1)" || CHECK_EXIT=$?
}

test_main_real_release_allowed() {
    run_check refs/heads/main ""
    assert_eq "$CHECK_EXIT" "0"
}

test_main_dry_run_allowed() {
    run_check refs/heads/main true
    assert_eq "$CHECK_EXIT" "0"
}

test_branch_dry_run_allowed() {
    run_check refs/heads/feat/some-branch true
    assert_eq "$CHECK_EXIT" "0"
}

test_branch_real_release_rejected() {
    run_check refs/heads/feat/some-branch false
    assert_eq "$CHECK_EXIT" "1"
    echo "$CHECK_OUTPUT" | grep -qF "dry_run" || fail "message should mention dry_run, got: $CHECK_OUTPUT"
}

run_tests
