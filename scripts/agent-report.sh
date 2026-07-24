#!/usr/bin/env bash
set -euo pipefail

die() { echo "agent-report: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || die "python3 not found"

TRANSCRIPT="${1:-}"

if [ -z "$TRANSCRIPT" ]; then
  ENC=$(printf '%s' "$PWD" | tr '/' '-')
  DIR="$HOME/.claude/projects/$ENC"
  [ -d "$DIR" ] || die "no transcript dir for this project ($DIR). Pass a transcript path explicitly."
  TRANSCRIPT=$(ls -t "$DIR"/*.jsonl 2>/dev/null | head -1) || true
  [ -n "$TRANSCRIPT" ] || die "no .jsonl transcript found in $DIR"
fi

[ -f "$TRANSCRIPT" ] || die "transcript not found: $TRANSCRIPT"

TRANSCRIPT="$TRANSCRIPT" python3 - <<'PY'
import json, os, sys

# --- Pricing per 1M tokens (edit to taste) ---------------------------------
# cache_write_5m = 1.25x input, cache_write_1h = 2x input, cache_read = 0.1x input.
# Sonnet 5 has an intro rate of $2/$10 through 2026-08-31; table uses standard.
PRICES = {
    "opus":   {"in": 5.0,  "out": 25.0, "cr": 0.5, "cw5": 6.25, "cw1": 10.0},
    "sonnet": {"in": 3.0,  "out": 15.0, "cr": 0.3, "cw5": 3.75, "cw1": 6.0},
    "haiku":  {"in": 1.0,  "out": 5.0,  "cr": 0.1, "cw5": 1.25, "cw1": 2.0},
    "fable":  {"in": 10.0, "out": 50.0, "cr": 1.0, "cw5": 12.5, "cw1": 20.0},
}

def price_key(model):
    m = (model or "").lower()
    for k in ("opus", "sonnet", "haiku", "fable", "mythos"):
        if k in m:
            return "fable" if k == "mythos" else k
    return None

def short_model(model):
    return (model or "?").replace("claude-", "")

path = os.environ["TRANSCRIPT"]
entries = []
with open(path) as f:
    for line in f:
        line = line.strip()
        if line:
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError:
                pass

by_uuid = {e.get("uuid"): e for e in entries if e.get("uuid")}

# Task tool_use -> subagent_type, grouped by the assistant message that spawned it
task_by_msg = {}
for e in entries:
    if e.get("type") == "assistant" and not e.get("isSidechain"):
        content = e.get("message", {}).get("content", [])
        if isinstance(content, list):
            for b in content:
                if isinstance(b, dict) and b.get("type") == "tool_use" and b.get("name") == "Task":
                    st = (b.get("input") or {}).get("subagent_type", "subagent")
                    task_by_msg.setdefault(e.get("uuid"), []).append(st)

def root_and_spawner(e):
    cur, seen = e, set()
    while True:
        p = cur.get("parentUuid")
        parent = by_uuid.get(p) if p else None
        if parent is None or not parent.get("isSidechain"):
            return cur.get("uuid"), p
        if cur.get("uuid") in seen:
            return cur.get("uuid"), None
        seen.add(cur.get("uuid"))
        cur = parent

# Order sidechain roots under each spawner, then zip with that spawner's Task types
root_spawner, root_order, seen = {}, {}, set()
for e in entries:
    if e.get("isSidechain"):
        rid, sp = root_and_spawner(e)
        if rid not in seen:
            seen.add(rid)
            root_spawner[rid] = sp
            root_order.setdefault(sp, []).append(rid)

root_type = {}
for sp, roots in root_order.items():
    tasks = task_by_msg.get(sp, [])
    for i, rid in enumerate(roots):
        if i < len(tasks):
            root_type[rid] = tasks[i]
        elif len(tasks) == 1:
            root_type[rid] = tasks[0]
        else:
            root_type[rid] = "subagent"

# Aggregate: one group per subagent invocation, plus one for the main/orchestrator turns
def new_group():
    return {"model": None, "in": 0, "out": 0, "cr": 0, "cw5": 0, "cw1": 0, "tools": [], "order": None}

groups = {}
order_counter = 0

def target(block):
    inp = block.get("input") or {}
    name = block.get("name")
    if name in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
        return inp.get("file_path")
    if name == "Bash":
        return inp.get("description") or (inp.get("command", "")[:40])
    return None

for e in entries:
    if e.get("type") != "assistant":
        continue
    msg = e.get("message", {})
    usage = msg.get("usage") or {}
    if e.get("isSidechain"):
        rid, _ = root_and_spawner(e)
        key = ("sub", rid)
    else:
        key = ("main", "main")
    g = groups.setdefault(key, new_group())
    if g["order"] is None:
        g["order"] = order_counter
        order_counter += 1
    if g["model"] is None and msg.get("model"):
        g["model"] = msg.get("model")
    g["in"] += usage.get("input_tokens", 0) or 0
    g["out"] += usage.get("output_tokens", 0) or 0
    g["cr"] += usage.get("cache_read_input_tokens", 0) or 0
    cc = usage.get("cache_creation") or {}
    w5 = cc.get("ephemeral_5m_input_tokens")
    w1 = cc.get("ephemeral_1h_input_tokens")
    if w5 is None and w1 is None:
        g["cw5"] += usage.get("cache_creation_input_tokens", 0) or 0
    else:
        g["cw5"] += w5 or 0
        g["cw1"] += w1 or 0
    content = msg.get("content", [])
    if isinstance(content, list):
        for b in content:
            if isinstance(b, dict) and b.get("type") == "tool_use":
                g["tools"].append((b.get("name"), target(b)))

def summarize(tools):
    parts = []
    tasks = sum(1 for (n, _) in tools if n == "Task")
    files, seen_f = [], set()
    for (n, t) in tools:
        if n in ("Edit", "Write", "MultiEdit", "NotebookEdit") and t:
            b = os.path.basename(t)
            if b not in seen_f:
                seen_f.add(b); files.append(b)
    reads = sum(1 for (n, _) in tools if n == "Read")
    finds = sum(1 for (n, _) in tools if n in ("Grep", "Glob"))
    bashes = sum(1 for (n, _) in tools if n == "Bash")
    if tasks:
        parts.append(f"coordinó {tasks} agente(s)")
    if files:
        shown = ", ".join(files[:3]) + (f" +{len(files)-3}" if len(files) > 3 else "")
        parts.append(f"editó {shown}")
    if reads:
        parts.append(f"leyó {reads}")
    if finds:
        parts.append(f"buscó {finds}")
    if bashes:
        parts.append(f"Bash ×{bashes}")
    return " · ".join(parts) if parts else "—"

def cost(g, pk):
    if pk is None:
        return None
    p = PRICES[pk]
    return (g["in"] * p["in"] + g["out"] * p["out"] + g["cr"] * p["cr"]
            + g["cw5"] * p["cw5"] + g["cw1"] * p["cw1"]) / 1_000_000

rows = []
for key, g in groups.items():
    kind, ident = key
    if kind == "main":
        label = "orchestrator" if any(n == "Task" for (n, _) in g["tools"]) else "(main session)"
    else:
        label = root_type.get(ident, "subagent")
    pk = price_key(g["model"])
    tok = g["in"] + g["out"] + g["cr"] + g["cw5"] + g["cw1"]
    rows.append({
        "order": g["order"], "agent": label, "model": short_model(g["model"]),
        "did": summarize(g["tools"]), "tokens": tok, "cost": cost(g, pk),
    })

rows.sort(key=lambda r: r["order"])

total_tokens = sum(r["tokens"] for r in rows)
total_cost = sum(r["cost"] for r in rows if r["cost"] is not None)

def fmt_tok(n): return f"{n:,}"
def fmt_cost(c): return "n/a" if c is None else f"${c:,.4f}"

w_agent = max([len("agent")] + [len(r["agent"]) for r in rows]) if rows else 5
w_model = max([len("model")] + [len(r["model"]) for r in rows]) if rows else 5
w_did = max([len("what it did")] + [len(r["did"]) for r in rows]) if rows else 11
w_did = min(w_did, 48)
w_tok = max([len("tokens")] + [len(fmt_tok(r["tokens"])) for r in rows] + [len(fmt_tok(total_tokens))])
w_cost = max([len("$ (API ref)")] + [len(fmt_cost(r["cost"])) for r in rows] + [len(fmt_cost(total_cost))])

def clip(s, w): return s if len(s) <= w else s[:w-1] + "…"

print(f"\nAgentes de este run — {os.path.basename(path)}")
print("(leído del transcript de la sesión; $ = referencia a tarifa API, no un cargo)\n")
hdr = (f"  {'agent':<{w_agent}}  {'model':<{w_model}}  {'what it did':<{w_did}}  "
       f"{'tokens':>{w_tok}}  {'$ (API ref)':>{w_cost}}")
print(hdr)
print("  " + "-" * (len(hdr) - 2))
for r in rows:
    print(f"  {r['agent']:<{w_agent}}  {r['model']:<{w_model}}  {clip(r['did'], w_did):<{w_did}}  "
          f"{fmt_tok(r['tokens']):>{w_tok}}  {fmt_cost(r['cost']):>{w_cost}}")
print("  " + "-" * (len(hdr) - 2))
print(f"  {'TOTAL':<{w_agent}}  {'':<{w_model}}  {'':<{w_did}}  "
      f"{fmt_tok(total_tokens):>{w_tok}}  {fmt_cost(total_cost):>{w_cost}}")
print()
PY
