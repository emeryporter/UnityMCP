#!/bin/bash
# Fails a PR that adds or changes native binaries; CI builds them from Proxy~/.
# Usage: check-no-binaries.sh <base_sha> <head_sha>   (needs full history for the merge base)
# Rejected: *.dll, *.bundle (file or anything inside a .bundle folder), *.so, *.dylib anywhere;
# any added/changed file under Package/Plugins/ except .gitkeep files, folder .meta files and the
# plugin .meta files; and deleting a plugin .meta file (Unity deletes them in a checkout that has
# no plugins, and committing that deletion would break the next release).
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <base_sha> <head_sha>" >&2
    exit 2
fi

base_sha="$1"
head_sha="$2"
offending_paths=()
plugin_meta_paths=(
    "Package/Plugins/Windows/x86_64/UnityMCPProxy.dll.meta"
    "Package/Plugins/macOS/UnityMCPProxy.bundle.meta"
    "Package/Plugins/Linux/x86_64/libUnityMCPProxy.so.meta"
)

is_plugin_meta() {
    local plugin_meta_path
    for plugin_meta_path in "${plugin_meta_paths[@]}"; do
        [ "$1" = "$plugin_meta_path" ] && return 0
    done
    return 1
}

is_folder_meta() {
    local changed_path="$1"
    [[ "$changed_path" == *.meta ]] || return 1
    [ "$(git cat-file -t "$head_sha:${changed_path%.meta}" 2>/dev/null)" = "tree" ]
}

while IFS= read -r changed_path; do
    [ -n "$changed_path" ] || continue
    lowercase_path="${changed_path,,}"
    case "$lowercase_path" in
        *.dll | *.bundle | *.so | *.dylib | *.bundle/*)
            offending_paths+=("$changed_path")
            continue
            ;;
    esac
    if [[ "$changed_path" == Package/Plugins/* ]]; then
        if [ "$(basename "$changed_path")" = ".gitkeep" ] || is_folder_meta "$changed_path" || is_plugin_meta "$changed_path"; then
            continue
        fi
        offending_paths+=("$changed_path")
    fi
done < <(git diff --name-only --diff-filter=AMR "$base_sha...$head_sha")

while IFS= read -r deleted_path; do
    if is_plugin_meta "$deleted_path"; then
        offending_paths+=("$deleted_path (deleted; restore it with: git checkout origin/main -- \"$deleted_path\")")
    fi
done < <(git diff --name-only --diff-filter=D "$base_sha...$head_sha")

if [ "${#offending_paths[@]}" -gt 0 ]; then
    echo "This PR adds or changes native binaries or plugin files:"
    printf '  - %s\n' "${offending_paths[@]}"
    echo "Binaries are built by CI from Proxy~/. Remove them from this PR."
    exit 1
fi

echo "No prebuilt binaries in this PR."
