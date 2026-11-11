#!/bin/bash
# Tests for .github/scripts/select-version.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

git_quiet() {
    git -c user.name=test -c user.email=test@example.com -c init.defaultBranch=main "$@" >/dev/null 2>&1
}

# Temp repo whose package.json has version $1; cds into it and sets PACKAGE_JSON.
setup_repo() {
    local repo
    repo="$(mktemp -d)"
    cd "$repo"
    git_quiet init
    mkdir -p Package
    printf '{\n  "version": "%s"\n}\n' "$1" > Package/package.json
    PACKAGE_JSON="$repo/Package/package.json"
    git_quiet add -A
    git_quiet commit -m "source"
}

# Tags a new orphan commit with subject $2 as version $1 (like a release on latest).
tag_release() {
    git_quiet checkout --orphan "release-$1"
    git_quiet commit --allow-empty -m "$2"
    git_quiet tag "$1"
    git_quiet checkout main
}

select_version() {
    bash "$SCRIPTS_DIR/select-version.sh" "$1" "$PACKAGE_JSON"
}

test_no_tags_uses_package_version() {
    setup_repo 3.0.0
    assert_eq "$(select_version abc1234)" "3.0.0"
}

test_package_version_wins_over_patch_bump() {
    setup_repo 3.0.0
    tag_release 2.2.7 "Release 2.2.7 (from main@1111111)"
    assert_eq "$(select_version abc1234)" "3.0.0"
}

test_patch_bump_after_release() {
    setup_repo 3.0.0
    tag_release 3.0.0 "Release 3.0.0 (from main@1111111)"
    assert_eq "$(select_version abc1234)" "3.0.1"
}

test_rerun_of_released_commit_reuses_version() {
    setup_repo 3.0.0
    tag_release 3.0.0 "Release 3.0.0 (from main@abc1234)"
    assert_eq "$(select_version abc1234)" "3.0.0"
}

test_non_semver_tags_ignored() {
    setup_repo 3.0.0
    tag_release 3.0.0 "Release 3.0.0 (from main@1111111)"
    tag_release v9.9.9 "Release whatever (from main@abc1234)"
    assert_eq "$(select_version abc1234)" "3.0.1"
}

run_tests
