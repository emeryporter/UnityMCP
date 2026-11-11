#!/bin/bash
# Tests for .github/scripts/assemble-package.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Builds fixtures in a fresh temp dir and sets SRC, ARTIFACTS, DIST.
setup_fixture() {
    local root
    root="$(mktemp -d)"
    SRC="$root/src"
    ARTIFACTS="$root/artifacts"
    DIST="$root/dist"
    make_fixture_src "$SRC"
    make_fixture_artifacts "$ARTIFACTS"
    mkdir -p "$DIST"
}

assemble() {
    bash "$SCRIPTS_DIR/assemble-package.sh" "$SRC" "$ARTIFACTS" "$DIST" "${1:-9.8.7}"
}

test_copies_package_contents_to_root() {
    setup_fixture
    assemble
    assert_file "$DIST/package.json"
    assert_file "$DIST/Editor/Foo.cs"
    assert_no_file "$DIST/Package"
}

test_places_binaries_and_metas() {
    setup_fixture
    assemble
    assert_same_content "$DIST/Plugins/Windows/x86_64/UnityMCPProxy.dll" "$ARTIFACTS/windows-plugin/UnityMCPProxy.dll"
    assert_same_content "$DIST/Plugins/macOS/UnityMCPProxy.bundle" "$ARTIFACTS/macos-plugin/UnityMCPProxy.bundle"
    assert_same_content "$DIST/Plugins/Linux/x86_64/libUnityMCPProxy.so" "$ARTIFACTS/linux-plugin/libUnityMCPProxy.so"
    assert_same_content "$DIST/Plugins/Windows/x86_64/UnityMCPProxy.dll.meta" "$SRC/release-meta/Plugins/Windows/x86_64/UnityMCPProxy.dll.meta"
    assert_same_content "$DIST/Plugins/macOS/UnityMCPProxy.bundle.meta" "$SRC/release-meta/Plugins/macOS/UnityMCPProxy.bundle.meta"
    assert_same_content "$DIST/Plugins/Linux/x86_64/libUnityMCPProxy.so.meta" "$SRC/release-meta/Plugins/Linux/x86_64/libUnityMCPProxy.so.meta"
}

test_copies_root_readme_and_license() {
    setup_fixture
    assemble
    assert_same_content "$DIST/README.md" "$SRC/README.md"
    assert_same_content "$DIST/LICENSE" "$SRC/LICENSE"
    assert_file "$DIST/README.md.meta"
    assert_file "$DIST/LICENSE.meta"
}

test_writes_version() {
    setup_fixture
    assemble 9.8.7
    assert_contains "$DIST/package.json" '"version": "9.8.7"'
    assert_contains "$DIST/Editor/Core/MCPServer.cs" 'internal const string ServerVersion = "9.8.7";'
}

test_removes_stale_files_keeps_git() {
    setup_fixture
    mkdir -p "$DIST/.git"
    echo "ref: refs/heads/latest" > "$DIST/.git/HEAD"
    echo "stale" > "$DIST/Stale.cs"
    assemble
    assert_no_file "$DIST/Stale.cs"
    assert_eq "$(cat "$DIST/.git/HEAD")" "ref: refs/heads/latest"
}

test_fails_when_artifact_missing() {
    setup_fixture
    rm -rf "$ARTIFACTS/linux-plugin"
    local error_output exit_code=0
    error_output="$(assemble 2>&1 >/dev/null)" || exit_code=$?
    [ "$exit_code" -ne 0 ] || fail "expected non-zero exit"
    echo "$error_output" | grep -qF "libUnityMCPProxy.so" || fail "stderr should name libUnityMCPProxy.so, got: $error_output"
}

run_tests
