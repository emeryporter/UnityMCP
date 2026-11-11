#!/bin/bash
# Copies the CI-built native plugins into Package/Plugins so a source checkout works in Unity,
# without needing a compiler. Uses only git.
# Usage: bash Proxy~/fetch_plugins.sh [ref]     (ref: 'latest' (default) or a 3.x tag, e.g. 3.0.1)
# Fetches from the upstream repo (override with UNITYMCP_UPSTREAM), not 'origin': forks usually
# don't have the 'latest' branch.
set -euo pipefail

ref="${1:-latest}"
upstream="${UNITYMCP_UPSTREAM:-https://github.com/emeryporter/UnityMCP.git}"

if [[ "$ref" =~ ^([0-9]+)\.[0-9]+\.[0-9]+$ ]] && [ "${BASH_REMATCH[1]}" -lt 3 ]; then
    echo "Versions before 3.0.0 use a different layout; use a 3.x tag or 'latest'." >&2
    exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

binary_paths=(
    "Plugins/Windows/x86_64/UnityMCPProxy.dll"
    "Plugins/macOS/UnityMCPProxy.bundle"
    "Plugins/Linux/x86_64/libUnityMCPProxy.so"
)

echo "Fetching native plugins from $upstream ($ref)..."
git fetch --no-tags --quiet "$upstream" "$ref"

for binary_path in "${binary_paths[@]}"; do
    destination="Package/$binary_path"
    mkdir -p "$(dirname "$destination")"
    git show "FETCH_HEAD:$binary_path" > "$destination.tmp"
    if ! mv -f "$destination.tmp" "$destination"; then
        rm -f "$destination.tmp"
        echo "Could not replace $destination. Close Unity and retry (the plugin is loaded)." >&2
        exit 1
    fi
    # The .meta is tracked. Unity deletes it if the project was opened while the plugin was missing;
    # restore it then, but never overwrite a local edit.
    if [ ! -f "$destination.meta" ]; then
        git checkout -- "$destination.meta"
    fi
done

echo "Native plugins installed from $ref."
# Replacing a loaded plugin usually succeeds, but Unity keeps using the copy it already loaded.
echo "Restart Unity if it is open; native plugins load once per editor session."
