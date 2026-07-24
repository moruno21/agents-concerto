#!/usr/bin/env bash
set -euo pipefail

die() { echo "run-log: $*" >&2; exit 1; }

[ $# -ge 2 ] || die "usage: run-log.sh <run-id> <event|summary> [key=value ...]"

RUN_ID=$1; shift
CMD=$1; shift

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ORCH_ROOT=$(dirname "$SCRIPT_DIR")
WS="${AGENT_WORKSPACE:-$ORCH_ROOT/.agent-workspace}"
RUN_DIR="$WS/runs/$RUN_ID"
EVENTS="$RUN_DIR/events.jsonl"
SUMMARY="$RUN_DIR/summary.md"

mkdir -p "$RUN_DIR"

case "$CMD" in
  event)
    RUN_ID="$RUN_ID" EVENTS="$EVENTS" python3 - "$@" <<'PY'
import json, os, sys, datetime
obj = {"ts": datetime.datetime.now(datetime.timezone.utc).isoformat(), "run": os.environ["RUN_ID"]}
for arg in sys.argv[1:]:
    if "=" not in arg:
        continue
    k, v = arg.split("=", 1)
    obj[k] = v
with open(os.environ["EVENTS"], "a") as f:
    f.write(json.dumps(obj, ensure_ascii=False) + "\n")
print(json.dumps(obj, ensure_ascii=False))
PY
    ;;
  summary)
    [ -f "$EVENTS" ] || die "no events for run '$RUN_ID' at $EVENTS"
    RUN_ID="$RUN_ID" EVENTS="$EVENTS" SUMMARY="$SUMMARY" python3 - <<'PY'
import json, os, collections
events = []
with open(os.environ["EVENTS"]) as f:
    for line in f:
        line = line.strip()
        if line:
            events.append(json.loads(line))
subtasks = collections.OrderedDict()
for e in events:
    st = e.get("subtask")
    if not st:
        continue
    d = subtasks.setdefault(st, {"repo": "", "model": "", "pr": "", "fix_cycles": 0, "status": ""})
    if e.get("repo"):
        d["repo"] = e["repo"]
    if e.get("model"):
        d["model"] = e["model"]
    if e.get("pr"):
        d["pr"] = e["pr"]
    if e.get("verdict") == "NEEDS_FIXES":
        d["fix_cycles"] += 1
    if e.get("status") == "ready-for-human":
        d["status"] = "escalated"
    elif e.get("verdict") == "CLEAN" or e.get("status") == "clean":
        if d["status"] != "escalated":
            d["status"] = "completed"

prs = sum(1 for d in subtasks.values() if d["pr"])
total_cycles = sum(d["fix_cycles"] for d in subtasks.values())
completed = sum(1 for d in subtasks.values() if d["status"] == "completed")
escalated = sum(1 for d in subtasks.values() if d["status"] == "escalated")

L = []
L.append("# Run summary — " + os.environ["RUN_ID"])
L.append("")
L.append("- Sub-tasks: %d" % len(subtasks))
L.append("- PRs opened: %d" % prs)
L.append("- Total fix cycles: %d" % total_cycles)
L.append("- Completed (reviewed CLEAN): %d" % completed)
L.append("- Escalated (ready-for-human): %d" % escalated)
L.append("")
L.append("## Per sub-task")
L.append("")
L.append("| Sub-task | Repo | Model | Fix cycles | Status | PR |")
L.append("|---|---|---|---|---|---|")
for st, d in subtasks.items():
    L.append("| %s | %s | %s | %d | %s | %s |" % (
        st, d["repo"] or "-", d["model"] or "-", d["fix_cycles"], d["status"] or "unknown", d["pr"] or "-"))
L.append("")
L.append("## Cost")
L.append("")
L.append("A team of agents costs roughly 4-6x a single Claude Code session. This run "
         "spawned classify/implement/review agents across %d sub-task(s); factor that "
         "multiple into your usage." % len(subtasks))
L.append("")
L.append("## Stop point")
L.append("")
L.append("Pipeline stops at PRs ready for human review. Nothing was merged; the human reviews and merges by hand.")
text = "\n".join(L) + "\n"
with open(os.environ["SUMMARY"], "w") as f:
    f.write(text)
print(text)
PY
    ;;
  *)
    die "unknown command: $CMD (expected 'event' or 'summary')"
    ;;
esac
