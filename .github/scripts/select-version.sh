#!/bin/bash
# Picks the release version for a source commit. Run inside a repo with tags (and their commits) fetched.
# Usage: select-version.sh <short_sha> <package_json>
# 1. If a semver tag was already released from main@<short_sha>, reuse it (re-runs resume, never re-publish).
# 2. Otherwise: the higher of (latest semver tag + 1 patch) and the package.json version.
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <short_sha> <package_json>" >&2
    exit 2
fi

short_sha="$1"
package_json="$2"
semver_pattern='^[0-9]+\.[0-9]+\.[0-9]+$'

existing_version="$(git for-each-ref refs/tags --format='%(refname:short)|%(subject)' \
    | awk -F'|' -v marker="from main@$short_sha)" 'index($2, marker) { print $1 }' \
    | grep -E "$semver_pattern" | sort -V | tail -n1 || true)"
if [ -n "$existing_version" ]; then
    echo "$existing_version"
    exit 0
fi

latest_tag="$(git tag -l | grep -E "$semver_pattern" | sort -V | tail -n1 || true)"
if [ -z "$latest_tag" ]; then
    auto_version="0.0.0"
else
    IFS=. read -r major minor patch <<< "$latest_tag"
    auto_version="$major.$minor.$((patch + 1))"
fi

package_version="$(sed -n 's/.*"version": "\([^"]*\)".*/\1/p' "$package_json" | head -n1)"
printf '%s\n%s\n' "$auto_version" "$package_version" | sort -V | tail -n1
