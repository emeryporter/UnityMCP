#!/bin/bash
# Tests for Proxy~/fetch_plugins.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

REPO_ROOT="$(cd "$SCRIPTS_DIR/../.." && pwd)"
BINARY_PATHS=(
    "Plugins/Windows/x86_64/UnityMCPProxy.dll"
    "Plugins/macOS/UnityMCPProxy.bundle"
    "Plugins/Linux/x86_64/libUnityMCPProxy.so"
)

git_quiet() {
    git -c user.name=test -c user.email=test@example.com -c init.defaultBranch=main "$@" >/dev/null 2>&1
}

# Builds: UPSTREAM (bare, branch `latest` with root-layout binaries), ORIGIN (bare, only `main`),
# CHECKOUT (clone of ORIGIN holding the real fetch_plugins.sh, release-meta/ and .gitignore).
setup_fixture() {
    local root
    root="$(mktemp -d)"
    UPSTREAM="$root/upstream.git"
    ORIGIN="$root/origin.git"
    CHECKOUT="$root/checkout"

    local publish="$root/publish"
    mkdir -p "$publish"
    git_quiet -C "$publish" init
    for binary_path in "${BINARY_PATHS[@]}"; do
        mkdir -p "$publish/$(dirname "$binary_path")"
        echo "upstream bytes for $binary_path" > "$publish/$binary_path"
    done
    git_quiet -C "$publish" add -A
    git_quiet -C "$publish" commit -m "Release 3.0.0"
    git_quiet -C "$publish" tag 3.0.0
    git_quiet -C "$publish" tag 2.2.6
    git_quiet clone --bare "$publish" "$UPSTREAM"
    git_quiet -C "$UPSTREAM" branch -m main latest

    local source_tree="$root/source"
    mkdir -p "$source_tree/Proxy~" "$source_tree/Package/Plugins"
    cp "$REPO_ROOT/Proxy~/fetch_plugins.sh" "$source_tree/Proxy~/"
    cp -R "$REPO_ROOT/release-meta" "$source_tree/"
    cp "$REPO_ROOT/.gitignore" "$source_tree/"
    git_quiet -C "$source_tree" init
    git_quiet -C "$source_tree" add -A
    git_quiet -C "$source_tree" commit -m "source"
    git_quiet clone --bare "$source_tree" "$ORIGIN"
    git_quiet clone "$ORIGIN" "$CHECKOUT"

    export UNITYMCP_UPSTREAM="$UPSTREAM"
}

# Runs fetch_plugins.sh from directory $1 with optional ref $2; sets FETCH_OUTPUT and FETCH_EXIT.
run_fetch_from() {
    local working_dir="$1"
    shift
    FETCH_EXIT=0
    FETCH_OUTPUT="$(cd "$working_dir" && bash "$CHECKOUT/Proxy~/fetch_plugins.sh" "$@" 2>&1)" || FETCH_EXIT=$?
}

assert_binaries_fetched() {
    local binary_path
    for binary_path in "${BINARY_PATHS[@]}"; do
        assert_eq "$(cat "$CHECKOUT/Package/$binary_path")" "upstream bytes for $binary_path"
        # Compare with the checkout's own release-meta (line endings follow that clone's autocrlf).
        assert_same_content "$CHECKOUT/Package/$binary_path.meta" "$CHECKOUT/release-meta/$binary_path.meta"
    done
}

test_fetches_binaries_and_metas() {
    setup_fixture
    run_fetch_from "$CHECKOUT"
    assert_eq "$FETCH_EXIT" "0"
    assert_binaries_fetched
}

test_fetch_works_when_origin_lacks_latest() {
    setup_fixture
    git -C "$ORIGIN" rev-parse -q --verify refs/heads/latest >/dev/null && fail "fixture origin must not have latest"
    run_fetch_from "$CHECKOUT"
    assert_eq "$FETCH_EXIT" "0"
    assert_binaries_fetched
}

test_runs_from_any_cwd() {
    setup_fixture
    run_fetch_from "$CHECKOUT/Proxy~"
    assert_eq "$FETCH_EXIT" "0"
    rm -rf "$CHECKOUT/Package/Plugins"
    run_fetch_from "$(mktemp -d)"
    assert_eq "$FETCH_EXIT" "0"
    assert_binaries_fetched
}

test_fetches_a_3x_tag() {
    setup_fixture
    run_fetch_from "$CHECKOUT" 3.0.0
    assert_eq "$FETCH_EXIT" "0"
    assert_binaries_fetched
}

test_rejects_pre_3_tag() {
    setup_fixture
    run_fetch_from "$CHECKOUT" 2.2.6
    assert_eq "$FETCH_EXIT" "1"
    echo "$FETCH_OUTPUT" | grep -qF "Versions before 3.0.0 use a different layout; use a 3.x tag or 'latest'." \
        || fail "expected the pre-3.0 message, got: $FETCH_OUTPUT"
}

# Fetched binaries and metas are gitignored, so a fetch leaves the checkout clean.
test_git_status_clean_after_fetch() {
    setup_fixture
    run_fetch_from "$CHECKOUT"
    assert_eq "$FETCH_EXIT" "0"
    assert_eq "$(git -C "$CHECKOUT" status --porcelain)" ""
}

run_tests
