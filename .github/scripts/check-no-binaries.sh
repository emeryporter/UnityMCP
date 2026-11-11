#!/bin/bash
# Fails a PR that adds or changes native binaries; CI builds them from Proxy~/.
# Usage: check-no-binaries.sh <base_sha> <head_sha>   (needs full history for the merge base)
# Rejected: *.dll, *.bundle (file or anything inside a .bundle folder), *.so, *.dylib anywhere,
# and any file under Package/Plugins/ except .gitkeep files and folder .meta files.
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <base_sha> <head_sha>" >&2
    exit 2
fi

base_sha="$1"
head_sha="$2"
offending_paths=()

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
        if [ "$(basename "$changed_path")" = ".gitkeep" ] || is_folder_meta "$changed_path"; then
            continue
        fi
        offending_paths+=("$changed_path")
    fi
done < <(git diff --name-only --diff-filter=AMR "$base_sha...$head_sha")

if [ "${#offending_paths[@]}" -gt 0 ]; then
    echo "This PR adds or changes native binaries or plugin files:"
    printf '  - %s\n' "${offending_paths[@]}"
    echo "Binaries are built by CI from Proxy~/. Remove them from this PR."
    exit 1
fi

echo "No prebuilt binaries in this PR."
