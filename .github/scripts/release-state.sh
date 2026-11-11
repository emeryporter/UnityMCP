#!/bin/bash
# Decides whether a release still needs publishing. Run inside a repo with tags fetched.
# Usage: release-state.sh <version> <short_sha>
# Prints one of:
#   new        - tag <version> does not exist
#   published  - tag exists and was made by a release of main@<short_sha> (safe to resume)
#   conflict   - tag exists for some other commit (must not overwrite)
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <version> <short_sha>" >&2
    exit 2
fi

version="$1"
short_sha="$2"

if ! git rev-parse -q --verify "refs/tags/$version" >/dev/null; then
    echo "new"
    exit 0
fi

tag_subject="$(git log -1 --format=%s "refs/tags/$version")"
if [[ "$tag_subject" == *"from main@$short_sha"* ]]; then
    echo "published"
else
    echo "conflict"
fi
