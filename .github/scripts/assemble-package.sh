#!/bin/bash
# Assembles the publishable UPM package (package contents at the root) into a dist directory.
# Usage: assemble-package.sh <src_repo_dir> <artifacts_dir> <dist_dir> <version>
#   <artifacts_dir> holds windows-plugin/UnityMCPProxy.dll, macos-plugin/UnityMCPProxy.bundle,
#   linux-plugin/libUnityMCPProxy.so (the CI build outputs).
# Everything in <dist_dir> except .git is replaced, so files deleted from the source disappear.
set -euo pipefail

if [ "$#" -ne 4 ]; then
    echo "usage: $0 <src_repo_dir> <artifacts_dir> <dist_dir> <version>" >&2
    exit 2
fi

src_dir="$1"
artifacts_dir="$2"
dist_dir="$3"
version="$4"

# artifact path (relative to artifacts_dir) -> package-relative destination
binary_sources=(
    "windows-plugin/UnityMCPProxy.dll"
    "macos-plugin/UnityMCPProxy.bundle"
    "linux-plugin/libUnityMCPProxy.so"
)
binary_destinations=(
    "Plugins/Windows/x86_64/UnityMCPProxy.dll"
    "Plugins/macOS/UnityMCPProxy.bundle"
    "Plugins/Linux/x86_64/libUnityMCPProxy.so"
)

for binary_source in "${binary_sources[@]}"; do
    if [ ! -f "$artifacts_dir/$binary_source" ]; then
        echo "error: missing build artifact $artifacts_dir/$binary_source" >&2
        exit 1
    fi
done

mkdir -p "$dist_dir"
find "$dist_dir" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +

cp -R "$src_dir/Package/." "$dist_dir/"

for index in "${!binary_sources[@]}"; do
    destination="$dist_dir/${binary_destinations[$index]}"
    mkdir -p "$(dirname "$destination")"
    cp "$artifacts_dir/${binary_sources[$index]}" "$destination"
done

# Plugin .meta files, the README stub and LICENSE.meta come from Package/. Refresh LICENSE from the root copy.
cp "$src_dir/LICENSE" "$dist_dir/LICENSE"

sed -i 's/"version": "[^"]*"/"version": "'"$version"'"/' "$dist_dir/package.json"
sed -i 's/const string ServerVersion = "[^"]*"/const string ServerVersion = "'"$version"'"/' "$dist_dir/Editor/Core/MCPServer.cs"
