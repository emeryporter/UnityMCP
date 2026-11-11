#!/bin/bash
# Shared helpers for .github/scripts tests. Source this file; call run_tests at the end.

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_PASSED=0
TESTS_FAILED=0

fail() {
    echo "    assertion failed: $*" >&2
    return 1
}

assert_file() {
    [ -f "$1" ] || fail "expected file: $1"
}

assert_no_file() {
    [ ! -e "$1" ] || fail "expected no file: $1"
}

assert_eq() {
    [ "$1" = "$2" ] || fail "expected '$2', got '$1'"
}

assert_contains() {
    grep -qF -- "$2" "$1" || fail "expected '$1' to contain '$2'"
}

assert_same_content() {
    cmp -s "$1" "$2" || fail "expected '$1' to equal '$2'"
}

# Creates a minimal source checkout (Package/, root README/LICENSE, release-meta/) in $1.
make_fixture_src() {
    local src_dir="$1"
    mkdir -p "$src_dir/Package/Editor/Core" "$src_dir/release-meta/Plugins/Windows/x86_64" \
        "$src_dir/release-meta/Plugins/macOS" "$src_dir/release-meta/Plugins/Linux/x86_64"
    printf '{\n  "name": "com.emeryporter.unitymcp",\n  "version": "0.0.1"\n}\n' > "$src_dir/Package/package.json"
    echo "class Foo {}" > "$src_dir/Package/Editor/Foo.cs"
    echo '        internal const string ServerVersion = "0.0.1";' > "$src_dir/Package/Editor/Core/MCPServer.cs"
    echo "package readme" > "$src_dir/Package/README.md"
    echo "root readme" > "$src_dir/README.md"
    echo "root license" > "$src_dir/LICENSE"
    echo "meta dll" > "$src_dir/release-meta/Plugins/Windows/x86_64/UnityMCPProxy.dll.meta"
    echo "meta bundle" > "$src_dir/release-meta/Plugins/macOS/UnityMCPProxy.bundle.meta"
    echo "meta so" > "$src_dir/release-meta/Plugins/Linux/x86_64/libUnityMCPProxy.so.meta"
    echo "meta readme" > "$src_dir/release-meta/README.md.meta"
    echo "meta license" > "$src_dir/release-meta/LICENSE.meta"
}

# Creates CI-style artifact folders with distinct fake binaries in $1.
make_fixture_artifacts() {
    local artifacts_dir="$1"
    mkdir -p "$artifacts_dir/windows-plugin" "$artifacts_dir/macos-plugin" "$artifacts_dir/linux-plugin"
    echo "fake dll" > "$artifacts_dir/windows-plugin/UnityMCPProxy.dll"
    echo "fake bundle" > "$artifacts_dir/macos-plugin/UnityMCPProxy.bundle"
    echo "fake so" > "$artifacts_dir/linux-plugin/libUnityMCPProxy.so"
}

# Runs every function named test_* defined in the calling script, each in a subshell.
run_tests() {
    local test_name test_status
    for test_name in $(declare -F | awk '{print $3}' | grep '^test_'); do
        # Not inside `if`: bash ignores set -e in an if-condition, which would hide failures.
        ( set -e; "$test_name" )
        test_status=$?
        if [ "$test_status" -eq 0 ]; then
            echo "PASS $test_name"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo "FAIL $test_name"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    done
    echo "$TESTS_PASSED passed, $TESTS_FAILED failed"
    [ "$TESTS_FAILED" -eq 0 ]
}
