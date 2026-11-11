#!/bin/bash
# Checks an assembled package before it is published. Lists every failed check.
# Usage: verify-package.sh <dist_dir> <version>
set -uo pipefail

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <dist_dir> <version>" >&2
    exit 2
fi

dist_dir="$1"
version="$2"
expected_name="com.emeryporter.unitymcp"
problems=()

binaries=(
    "Plugins/Windows/x86_64/UnityMCPProxy.dll"
    "Plugins/macOS/UnityMCPProxy.bundle"
    "Plugins/Linux/x86_64/libUnityMCPProxy.so"
)

for binary in "${binaries[@]}"; do
    if [ ! -s "$dist_dir/$binary" ]; then
        problems+=("missing or empty binary: $binary")
    fi
done

for meta_owner in "${binaries[@]}" "README.md" "LICENSE"; do
    if [ ! -f "$dist_dir/$meta_owner.meta" ]; then
        problems+=("missing meta: $meta_owner.meta")
    fi
done

if ! grep -qF "\"version\": \"$version\"" "$dist_dir/package.json" 2>/dev/null; then
    problems+=("package.json version is not $version")
fi

if ! grep -qF "\"name\": \"$expected_name\"" "$dist_dir/package.json" 2>/dev/null; then
    problems+=("package.json name is not $expected_name")
fi

if [ "${#problems[@]}" -gt 0 ]; then
    echo "Package verification failed:" >&2
    printf '  - %s\n' "${problems[@]}" >&2
    exit 1
fi

echo "Package verified: $expected_name $version"
