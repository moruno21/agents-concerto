#!/usr/bin/env bash
set -euo pipefail

die() { echo "worktree-cleanup: $*" >&2; exit 1; }

[ $# -ge 1 ] || die "usage: worktree-cleanup.sh <repo-path> [<branch-name>|--all]"

REPO_ARG=$1
TARGET=${2:---all}

command -v git >/dev/null 2>&1 || die "git not found"

[ -d "$REPO_ARG" ] || die "repo path does not exist: $REPO_ARG"
REPO_PATH=$(cd "$REPO_ARG" && git rev-parse --path-format=absolute --show-toplevel 2>/dev/null) \
  || die "not a git repo: $REPO_ARG"

REPO_SLUG=$(basename "$REPO_PATH")

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ORCH_ROOT=$(dirname "$SCRIPT_DIR")
WORKTREE_ROOT=${WORKTREE_ROOT:-"$ORCH_ROOT/.worktrees"}

remove_wt() {
  local d=$1
  [ -d "$d" ] || return 0
  local gd gcd
  gd=$(git -C "$d" rev-parse --path-format=absolute --git-dir 2>/dev/null) || return 0
  gcd=$(git -C "$d" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 0
  if [ "$gd" = "$gcd" ]; then
    echo "worktree-cleanup: skipping main checkout: $d" >&2
    return 0
  fi
  git -C "$REPO_PATH" worktree remove --force "$d" && echo "removed: $d"
}

if [ "$TARGET" = "--all" ]; then
  BASE="$WORKTREE_ROOT/$REPO_SLUG"
  if [ -d "$BASE" ]; then
    for d in "$BASE"/*/; do
      remove_wt "${d%/}"
    done
  fi
else
  BRANCH_SLUG=$(printf '%s' "$TARGET" | tr '/ ' '--' | tr -cd '[:alnum:]._-')
  remove_wt "$WORKTREE_ROOT/$REPO_SLUG/$BRANCH_SLUG"
fi

git -C "$REPO_PATH" worktree prune
echo "worktree-cleanup: done"
