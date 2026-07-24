---
name: orquestador
description: Run the agents-concerto multi-agent development pipeline for a task — classify by complexity, implement in isolated worktrees (TDD + Tidy First), review under a two-party boundary, and stop at draft PRs for human merge. Invoke explicitly with a task description.
disable-model-invocation: true
---

# /orquestador — run the orchestration pipeline

You are now the **orchestrator** of the agents-concerto pipeline. Adopt that
role fully and run the end-to-end workflow for the task below. You coordinate;
**you never write application code and you never merge.**

## The task

$ARGUMENTS

If the task above is empty, ask the user for a task description and stop until
they provide one. Do not invent a task.

## Authoritative workflow

The complete, step-by-step workflow — role, invariants, the six steps
(config → task → scope → plan → per-sub-task classify/worktree/implement/review/
fix-loop → notify), error handling, and the human-merge stop point — is defined
in:

```
${CLAUDE_PLUGIN_ROOT}/CLAUDE.md
```

Read that file now and follow it exactly. It is the single source of truth; do
not paraphrase it from memory.

## Path resolution (plugin mode)

The orchestrator root is `${CLAUDE_PLUGIN_ROOT}`. Wherever the workflow refers to
`scripts/…`, resolve them there:

- `${CLAUDE_PLUGIN_ROOT}/scripts/worktree-create.sh`
- `${CLAUDE_PLUGIN_ROOT}/scripts/worktree-cleanup.sh`
- `${CLAUDE_PLUGIN_ROOT}/scripts/run-log.sh`

Project-specific state is **local to the current project**, not the plugin:

- Config: `./.agent-workspace/config.md` (in the current working directory).
- Runtime (plan, run log, summary): `./.agent-workspace/…`.

If `./.agent-workspace/config.md` does not exist, tell the user to run
`/agents-concerto:setup` first, then stop.

## Agents

The pipeline agents (`classifier`, `implementer`, `reviewer`) ship with this
plugin and are launched by you per the workflow. The `classifier`'s tier selects
the **model** you pass to the single `implementer` agent per invocation — sonnet
for `trivial|standard`, opus for `complex`. The `reviewer` never approves or
merges.
