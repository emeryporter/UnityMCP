#!/bin/bash
# Tests for .github/scripts/release-notes.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

git_quiet() {
    git -c user.name=test -c user.email=test@example.com -c init.defaultBranch=main "$@" >/dev/null 2>&1
}

commit_on_main() {
    git_quiet commit --allow-empty -m "$1"
}

# Temp repo with one commit 'base' on main; cds into it and sets BASE_SHORT.
setup_repo() {
    local repo
    repo="$(mktemp -d)"
    cd "$repo"
    git_quiet init
    commit_on_main "base"
    BASE_SHORT="$(git rev-parse --short=7 HEAD)"
}

# Tags version $1 on an orphan commit (like the latest branch) built from main@$2.
tag_release_from() {
    git_quiet checkout --orphan "release-$1"
    git_quiet commit --allow-empty -m "Release $1 (from main@$2)"
    git_quiet tag "$1"
    git_quiet checkout main
}

# Adds a merge commit for PR #$1 whose branch has commit subject $2 and PR title $3.
merge_pr() {
    git_quiet checkout -b "pr-$1"
    git_quiet commit --allow-empty -m "$2"
    git_quiet checkout main
    git_quiet merge --no-ff "pr-$1" -m "Merge pull request #$1 from someone/pr-$1" -m "$3"
}

notes_for() {
    bash "$SCRIPTS_DIR/release-notes.sh" "$1" "$(git rev-parse HEAD)"
}

test_lists_changes_since_previous_release_source() {
    setup_repo
    tag_release_from 1.0.0 "$BASE_SHORT"
    commit_on_main "feat: add x (#5)"
    merge_pr 6 "wip commit" "fix: handle y"
    NOTES="$(notes_for 1.0.1)"
    echo "$NOTES" | grep -qxF -- "- feat: add x (#5)" || fail "missing squash entry: $NOTES"
    echo "$NOTES" | grep -qxF -- "- fix: handle y (#6)" || fail "missing PR title entry: $NOTES"
    echo "$NOTES" | grep -qF "base" && fail "should not list commits before the previous release: $NOTES"
    return 0
}

test_only_first_parent_commits() {
    setup_repo
    tag_release_from 1.0.0 "$BASE_SHORT"
    merge_pr 7 "wip commit" "feat: z"
    NOTES="$(notes_for 1.0.1)"
    echo "$NOTES" | grep -qF "wip commit" && fail "branch commits should not be listed: $NOTES"
    return 0
}

test_skips_release_commits() {
    setup_repo
    tag_release_from 1.0.0 "$BASE_SHORT"
    commit_on_main "Release 1.0.0 (from main@$BASE_SHORT)"
    commit_on_main "docs: readme"
    NOTES="$(notes_for 1.0.1)"
    echo "$NOTES" | grep -qF "Release 1.0.0" && fail "release commits should be skipped: $NOTES"
    echo "$NOTES" | grep -qxF -- "- docs: readme" || fail "missing entry: $NOTES"
}

test_legacy_previous_tag_on_main() {
    setup_repo
    git_quiet tag 0.9.0
    commit_on_main "feat: after legacy"
    NOTES="$(notes_for 0.9.1)"
    echo "$NOTES" | grep -qxF -- "- feat: after legacy" || fail "missing entry: $NOTES"
    echo "$NOTES" | grep -qF "base" && fail "should start after the legacy tag: $NOTES"
    return 0
}

test_previous_is_highest_lower_version() {
    setup_repo
    tag_release_from 1.0.0 "$BASE_SHORT"
    commit_on_main "feat: in 1.1.0"
    tag_release_from 1.1.0 "$(git rev-parse --short=7 HEAD)"
    commit_on_main "feat: in 1.1.1"
    NOTES="$(notes_for 1.1.1)"
    echo "$NOTES" | grep -qF "in 1.1.0" && fail "should start after 1.1.0: $NOTES"
    echo "$NOTES" | grep -qxF -- "- feat: in 1.1.1" || fail "missing entry: $NOTES"
}

test_no_previous_release() {
    setup_repo
    NOTES="$(notes_for 1.0.0)"
    echo "$NOTES" | grep -qF "Initial release" || fail "expected initial release note: $NOTES"
}

run_tests
