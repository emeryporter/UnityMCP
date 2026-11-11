#!/bin/bash
# Refuses a real (non-dry-run) release from any ref other than main, so a manual
# "Run workflow" on a feature branch can't publish unreviewed commits.
# Usage: check-release-ref.sh <git_ref> <dry_run>   (dry_run: "true" or anything else)
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <git_ref> <dry_run>" >&2
    exit 2
fi

git_ref="$1"
dry_run="$2"

if [ "$dry_run" = "true" ] || [ "$git_ref" = "refs/heads/main" ]; then
    exit 0
fi

echo "error: real releases only run from refs/heads/main (got $git_ref). Re-run with dry_run=true to test a branch." >&2
exit 1
