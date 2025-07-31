#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <branch-name>"
    exit 1
fi
branch="$1"

if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: not a git repository" >&2
    exit 1
fi

if ! git fetch origin; then
    echo "Failed to fetch from origin" >&2
    exit 1
fi

if ! git switch "$branch"; then
    echo "Failed to switch to branch '$branch'" >&2
    exit 1
fi

if ! git rebase origin/main; then
    echo "Rebase onto origin/main failed" >&2
    exit 1
fi

if ! git push origin "$branch"; then
    echo "Push to origin failed" >&2
    exit 1
fi

echo "Branch '$branch' synchronized with origin/main" 