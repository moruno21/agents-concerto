# Orchestrator tests

Two things are tested here:

1. **Deterministic checks** (`run-tests.sh`) — the parts of the orchestrator that
   are *code*, so they are reproducible and CI-able.
2. **End-to-end scenarios** (`fixtures/`) — the two required behavioral
   scenarios, run through the real pipeline with `/run`. These depend on
   an LLM, so they are steered by fixture design rather than being bit-for-bit
   deterministic.

## 1. Deterministic checks

```bash
tests/run-tests.sh
```

Exits non-zero if any check fails. It covers:

- **Scenario A accounting**: a first-try `CLEAN` event stream produces a summary
  with 1 PR, 0 fix cycles, 1 completed, 0 escalated.
- **Scenario B accounting**: a `NEEDS_FIXES × 3` + escalation event stream
  produces 3 fix cycles, 0 completed, 1 escalated, and the cost reminder.
- **Worktree isolation**: `worktree-create.sh` yields a *linked* worktree
  (git-dir ≠ git-common-dir), leaves the main checkout intact, and
  `worktree-cleanup.sh` removes it.
- **No-merge invariant**: `.claude/settings.json` has no `merge` rule in `allow`
  and denies `gh pr merge`.
- **Plugin packaging**: `plugin.json` is valid and all 4 agents are present.

These run against temp dirs (`AGENT_WORKSPACE` / `WORKTREE_ROOT` are redirected),
so they never touch real project state.

## 2. End-to-end scenarios (manual)

Each scenario is a `feature-request.md` fixture designed to force a specific
outcome. Run them against a throwaway sandbox repo so nothing real is touched.

### Setup (once)

Create a sandbox git repo to act as the target, and point a local config at it:

```bash
SB=$(mktemp -d)/sandbox
git init -b main "$SB" && (cd "$SB" && git commit --allow-empty -m init)
```

Write `.agent-workspace/config.md` with a single repo whose `path` is `$SB`,
`task_source: none`, and `base_branch: main`.

### Scenario A — expected: CLEAN on first attempt

```bash
cp tests/fixtures/scenario-a/feature-request.md .agent-workspace/feature-request.md
```

Run the pipeline (standalone: ask the orchestrator to run the task; plugin:
`/agents-concerto:run add a CHANGELOG.md`).

**Expected outcome**: the reviewer returns `CLEAN` on cycle 1; an open PR/branch
is produced; nothing is merged. Verify with the run summary:

```bash
cat .agent-workspace/runs/<RUN_ID>/summary.md
# Completed (reviewed CLEAN): 1   |   Total fix cycles: 0   |   Escalated: 0
```

### Scenario B — expected: exhaust 3 cycles → ready-for-human

```bash
cp tests/fixtures/scenario-b/feature-request.md .agent-workspace/feature-request.md
```

Run the pipeline the same way. The fixture's acceptance criteria are
contradictory on purpose, so the reviewer returns `NEEDS_FIXES` every cycle.

**Expected outcome**: after 3 review→fix cycles the orchestrator hits the cap,
labels the PR `ready-for-human`, and stops (no merge). Verify:

```bash
cat .agent-workspace/runs/<RUN_ID>/summary.md
# Escalated (ready-for-human): 1   |   Total fix cycles: 3   |   Completed: 0
```

### Cleanup

```bash
scripts/worktree-cleanup.sh "$SB" --all
rm -rf "$SB"
```

## Note on reproducibility

The deterministic checks are exactly reproducible. The e2e scenarios are
*outcome-reproducible* by design — the fixtures constrain the pipeline hard
enough that A passes clean and B escalates — but the exact commits, wording, and
timing vary because an LLM drives them.
