#!/bin/bash
# Writes Markdown release notes from main's history. GitHub's --generate-notes can't be used:
# `latest` shares no history with main, so comparing release tags fails or lists only bot commits.
# Usage: release-notes.sh <version> <head_sha>   (run in a repo with full history and tags)
# Range: from the previous release's source commit ("from main@<sha>" in its tag's subject, or the
# tag itself for legacy tags on main) to <head_sha>, first-parent only. Release commits are skipped;
# PR merge commits are listed by PR title.
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <version> <head_sha>" >&2
    exit 2
fi

version="$1"
head_sha="$2"

previous_tag="$( { git tag -l | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' || true; echo "$version"; } \
    | sort -uV | awk -v current="$version" '$0 == current { print previous; exit } { previous = $0 }')"

echo "## What's changed"
echo

if [ -z "$previous_tag" ]; then
    echo "- Initial release."
    exit 0
fi

previous_subject="$(git log -1 --format=%s "refs/tags/$previous_tag")"
if [[ "$previous_subject" =~ from\ main@([0-9a-f]+) ]]; then
    range_start="${BASH_REMATCH[1]}"
else
    range_start="refs/tags/$previous_tag"
fi

entry_count=0
while IFS= read -r commit_sha; do
    subject="$(git log -1 --format=%s "$commit_sha")"
    [[ "$subject" == Release\ * ]] && continue
    if [[ "$subject" =~ ^Merge\ pull\ request\ \#([0-9]+)\ from ]]; then
        pr_number="${BASH_REMATCH[1]}"
        pr_title="$(git log -1 --format=%b "$commit_sha" | sed '/^[[:space:]]*$/d' | head -n1)"
        echo "- ${pr_title:-$subject} (#$pr_number)"
    else
        echo "- $subject"
    fi
    entry_count=$((entry_count + 1))
done < <(git rev-list --first-parent "$range_start..$head_sha")

if [ "$entry_count" -eq 0 ]; then
    echo "- No changes listed."
fi
