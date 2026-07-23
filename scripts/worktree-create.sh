#!/usr/bin/env bash
set -euo pipefail

die() { echo "worktree-create: $*" >&2; exit 1; }

[ $# -ge 2 ] || die "usage: worktree-create.sh <repo-path> <branch-name> [base-ref]"

REPO_ARG=$1
BRANCH=$2
BASE_REF=${3:-}

command -v git >/dev/null 2>&1 || die "git not found"

[ -d "$REPO_ARG" ] || die "repo path does not exist: $REPO_ARG"
REPO_PATH=$(cd "$REPO_ARG" && git rev-parse --path-format=absolute --show-toplevel 2>/dev/null) \
  || die "not a git repo: $REPO_ARG"

REPO_SLUG=$(basename "$REPO_PATH")

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ORCH_ROOT=$(dirname "$SCRIPT_DIR")
WORKTREE_ROOT=${WORKTREE_ROOT:-"$ORCH_ROOT/.worktrees"}

BRANCH_SLUG=$(printf '%s' "$BRANCH" | tr '/ ' '--' | tr -cd '[:alnum:]._-')
[ -n "$BRANCH_SLUG" ] || die "branch name produced an empty slug: $BRANCH"
DEST="$WORKTREE_ROOT/$REPO_SLUG/$BRANCH_SLUG"

case "$DEST/" in
  "$REPO_PATH"/*) die "refusing: worktree dest is inside the target checkout: $DEST" ;;
esac
[ "$DEST" = "$REPO_PATH" ] && die "refusing: worktree dest equals the target checkout"
[ -e "$DEST" ] && die "worktree destination already exists: $DEST"

if [ -z "$BASE_REF" ]; then
  BASE_REF=$(git -C "$REPO_PATH" symbolic-ref --quiet --short HEAD 2>/dev/null) \
    || BASE_REF=$(git -C "$REPO_PATH" rev-parse HEAD)
fi

mkdir -p "$(dirname "$DEST")"

git -C "$REPO_PATH" worktree add -b "$BRANCH" "$DEST" "$BASE_REF" >&2 \
  || die "git worktree add failed"

GD=$(git -C "$DEST" rev-parse --path-format=absolute --git-dir 2>/dev/null) \
  || { git -C "$REPO_PATH" worktree remove --force "$DEST" 2>/dev/null || true; die "could not resolve git-dir for $DEST"; }
GCD=$(git -C "$DEST" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) \
  || { git -C "$REPO_PATH" worktree remove --force "$DEST" 2>/dev/null || true; die "could not resolve git-common-dir for $DEST"; }

if [ "$GD" = "$GCD" ]; then
  git -C "$REPO_PATH" worktree remove --force "$DEST" 2>/dev/null || true
  die "refusing to proceed: '$DEST' resolved to the main checkout, not a linked worktree"
fi

echo "$DEST"
