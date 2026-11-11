#!/bin/bash
# Tests for .github/scripts/check-no-binaries.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

git_quiet() {
    git -c user.name=test -c user.email=test@example.com -c init.defaultBranch=main "$@" >/dev/null 2>&1
}

# Creates a repo whose base commit has the Plugins folder structure (+ one tracked binary to delete later),
# then checks out a 'pr' branch. Sets REPO and BASE_SHA; cds into REPO.
setup_repo() {
    REPO="$(mktemp -d)"
    cd "$REPO"
    git_quiet init
    mkdir -p Package/Plugins/Linux/x86_64 Package/Editor
    echo "folder meta" > Package/Plugins/Linux.meta
    touch Package/Plugins/Linux/x86_64/.gitkeep
    echo "class A {}" > Package/Editor/A.cs
    echo "old binary" > Package/Plugins/Linux/x86_64/old.so
    git_quiet add -A
    git_quiet commit -m base
    BASE_SHA="$(git rev-parse HEAD)"
    git_quiet checkout -b pr
}

# Commits the working tree on the PR branch and runs the check; sets CHECK_OUTPUT and CHECK_EXIT.
commit_and_check() {
    git_quiet add -A
    git_quiet commit -m pr
    CHECK_EXIT=0
    CHECK_OUTPUT="$(bash "$SCRIPTS_DIR/check-no-binaries.sh" "$BASE_SHA" "$(git rev-parse HEAD)" 2>&1)" || CHECK_EXIT=$?
}

expect_rejected() {
    assert_eq "$CHECK_EXIT" "1"
    local offending_path
    for offending_path in "$@"; do
        echo "$CHECK_OUTPUT" | grep -qF "$offending_path" || fail "output should name $offending_path, got: $CHECK_OUTPUT"
    done
    echo "$CHECK_OUTPUT" | grep -qF "Binaries are built by CI from Proxy~/. Remove them from this PR." \
        || fail "missing guidance message, got: $CHECK_OUTPUT"
}

test_cs_only_passes() {
    setup_repo
    echo "class B {}" > Package/Editor/B.cs
    echo "changed" >> Package/Editor/A.cs
    commit_and_check
    assert_eq "$CHECK_EXIT" "0"
}

test_dll_anywhere_fails() {
    setup_repo
    mkdir -p Tools
    echo "binary" > Tools/Helper.DLL
    echo "binary" > Package/Plugins/Linux/x86_64/UnityMCPProxy.dll
    commit_and_check
    expect_rejected "Tools/Helper.DLL" "Package/Plugins/Linux/x86_64/UnityMCPProxy.dll"
}

test_bundle_so_dylib_fail() {
    setup_repo
    mkdir -p Native
    echo "binary" > Native/a.bundle
    echo "binary" > Native/b.so
    echo "binary" > Native/c.dylib
    commit_and_check
    expect_rejected "Native/a.bundle" "Native/b.so" "Native/c.dylib"
}

test_bundle_directory_contents_fail() {
    setup_repo
    mkdir -p Native/Plugin.bundle/Contents/MacOS
    echo "binary" > Native/Plugin.bundle/Contents/MacOS/Plugin
    commit_and_check
    expect_rejected "Native/Plugin.bundle/Contents/MacOS/Plugin"
}

test_plugin_binary_meta_fails() {
    setup_repo
    echo "meta" > Package/Plugins/Linux/x86_64/libUnityMCPProxy.so.meta
    commit_and_check
    expect_rejected "Package/Plugins/Linux/x86_64/libUnityMCPProxy.so.meta"
}

test_folder_meta_and_gitkeep_pass() {
    setup_repo
    echo "changed folder meta" >> Package/Plugins/Linux.meta
    echo "x86_64 folder meta" > Package/Plugins/Linux/x86_64.meta
    echo "keep" > Package/Plugins/Linux/x86_64/.gitkeep
    commit_and_check
    assert_eq "$CHECK_EXIT" "0"
}

test_deleting_binary_passes() {
    setup_repo
    git rm -q Package/Plugins/Linux/x86_64/old.so
    commit_and_check
    assert_eq "$CHECK_EXIT" "0"
}

run_tests
