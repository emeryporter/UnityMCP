#!/bin/bash
# Tests for .github/scripts/release-state.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Creates a temp git repo with one commit (subject $1) and cds into it.
setup_repo_with_commit() {
    local repo
    repo="$(mktemp -d)"
    cd "$repo"
    git init -q
    git -c user.name=test -c user.email=test@example.com commit -q --allow-empty -m "$1"
}

release_state() {
    bash "$SCRIPTS_DIR/release-state.sh" "$1" "$2"
}

test_no_tag_is_new() {
    setup_repo_with_commit "initial"
    assert_eq "$(release_state 1.2.3 abc1234)" "new"
}

test_tag_from_same_sha_is_published() {
    setup_repo_with_commit "Release 1.2.3 (from main@abc1234)"
    git tag 1.2.3
    assert_eq "$(release_state 1.2.3 abc1234)" "published"
}

test_tag_from_other_sha_is_conflict() {
    setup_repo_with_commit "Release 1.2.3 (from main@abc1234)"
    git tag 1.2.3
    assert_eq "$(release_state 1.2.3 def5678)" "conflict"
}

test_legacy_release_tag_is_conflict() {
    setup_repo_with_commit "Release 1.2.3"
    git tag 1.2.3
    assert_eq "$(release_state 1.2.3 abc1234)" "conflict"
}

run_tests
