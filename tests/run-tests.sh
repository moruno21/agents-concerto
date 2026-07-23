#!/usr/bin/env bash
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
ok() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
no() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
want() {
  if printf '%s' "$2" | grep -qF "$3"; then ok "$1"; else no "$1 (missing: '$3')"; fi
}

export AGENT_WORKSPACE="$TMP/ws"

echo "Scenario A — clean on first attempt (CLEAN)"
RA=scenario-a
"$ROOT/scripts/run-log.sh" "$RA" event subtask=ST-1 repo=demo agent=dispatcher model=sonnet phase=dispatch >/dev/null
"$ROOT/scripts/run-log.sh" "$RA" event subtask=ST-1 repo=demo agent=implementer phase=pr_opened pr=PR-A1 >/dev/null
"$ROOT/scripts/run-log.sh" "$RA" event subtask=ST-1 repo=demo agent=reviewer verdict=CLEAN cycle=1 status=clean >/dev/null
SA=$("$ROOT/scripts/run-log.sh" "$RA" summary)
want "A: 1 draft PR"            "$SA" "Draft PRs opened: 1"
want "A: 0 fix cycles"          "$SA" "Total fix cycles: 0"
want "A: 1 completed"           "$SA" "Completed (reviewed CLEAN): 1"
want "A: 0 escalated"           "$SA" "Escalated (ready-for-human): 0"

echo "Scenario B — exhaust 3 fix cycles then escalate (ready-for-human)"
RB=scenario-b
"$ROOT/scripts/run-log.sh" "$RB" event subtask=ST-1 repo=demo agent=dispatcher model=opus phase=dispatch >/dev/null
"$ROOT/scripts/run-log.sh" "$RB" event subtask=ST-1 repo=demo agent=implementer phase=pr_opened pr=PR-B1 >/dev/null
"$ROOT/scripts/run-log.sh" "$RB" event subtask=ST-1 repo=demo agent=reviewer verdict=NEEDS_FIXES cycle=1 >/dev/null
"$ROOT/scripts/run-log.sh" "$RB" event subtask=ST-1 repo=demo agent=reviewer verdict=NEEDS_FIXES cycle=2 >/dev/null
"$ROOT/scripts/run-log.sh" "$RB" event subtask=ST-1 repo=demo agent=reviewer verdict=NEEDS_FIXES cycle=3 >/dev/null
"$ROOT/scripts/run-log.sh" "$RB" event subtask=ST-1 repo=demo agent=orchestrator phase=escalate status=ready-for-human >/dev/null
SB=$("$ROOT/scripts/run-log.sh" "$RB" summary)
want "B: 3 fix cycles"          "$SB" "Total fix cycles: 3"
want "B: 0 completed"           "$SB" "Completed (reviewed CLEAN): 0"
want "B: 1 escalated"           "$SB" "Escalated (ready-for-human): 1"
want "B: cost reminder present" "$SB" "4-6x"

echo "Worktree isolation + cleanup"
SBREPO="$TMP/repo"
git init -q -b main "$SBREPO"
git -C "$SBREPO" config user.email t@t.co
git -C "$SBREPO" config user.name test
printf 'x\n' >"$SBREPO/f.txt"
git -C "$SBREPO" add -A
git -C "$SBREPO" commit -q -m init
export WORKTREE_ROOT="$TMP/wt"
DEST=$("$ROOT/scripts/worktree-create.sh" "$SBREPO" "feat/test-demo" main)
GD=$(git -C "$DEST" rev-parse --path-format=absolute --git-dir 2>/dev/null)
GCD=$(git -C "$DEST" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
if [ -n "$GD" ] && [ "$GD" != "$GCD" ]; then ok "worktree is a linked worktree"; else no "worktree not linked"; fi
if [ "$(git -C "$SBREPO" rev-parse --abbrev-ref HEAD)" = "main" ] && [ -z "$(git -C "$SBREPO" status --short)" ]; then
  ok "main checkout intact and clean"
else
  no "main checkout was disturbed"
fi
"$ROOT/scripts/worktree-cleanup.sh" "$SBREPO" --all >/dev/null 2>&1
if [ ! -d "$DEST" ]; then ok "worktree removed by cleanup"; else no "worktree not removed"; fi

echo "No-merge permission invariant"
if python3 - "$ROOT/.claude/settings.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
allow = d.get("permissions", {}).get("allow", [])
deny = d.get("permissions", {}).get("deny", [])
bad_allow = [p for p in allow if "merge" in p.lower()]
has_deny = any("gh pr merge" in p for p in deny)
sys.exit(0 if (not bad_allow and has_deny) else 1)
PY
then ok "settings.json: no merge in allow, gh pr merge denied"; else no "settings.json merge invariant broken"; fi

echo "Plugin manifest + agents resolve"
if python3 - "$ROOT/.claude-plugin/plugin.json" <<'PY'
import json, sys
json.load(open(sys.argv[1]))
PY
then ok "plugin.json is valid JSON"; else no "plugin.json invalid"; fi
NAGENTS=$(find "$ROOT/agents" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
if [ "$NAGENTS" = "4" ]; then ok "4 agents present in agents/"; else no "expected 4 agents, found $NAGENTS"; fi

echo ""
echo "Totals: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
