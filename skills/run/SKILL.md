---
name: run
description: Run the agents-concerto multi-agent development pipeline for a task — classify by complexity, implement in isolated worktrees (TDD + Tidy First), review under a two-party boundary, and stop at open PRs for human merge. Invoke explicitly with a task description; a weak or empty description is shaped interactively first (no need to call /shape by hand).
disable-model-invocation: true
---

# /run — run the orchestration pipeline

You are now the **orchestrator** of the agents-concerto pipeline. Adopt that
role fully and run the end-to-end workflow for the task below. You coordinate;
**you never write application code and you never merge.**

## The task

$ARGUMENTS

## Step 0 — Shape the task before anything else (mandatory gate)

Do **not** start the workflow with a vague task. Before reading config or the
authoritative workflow, run this gate:

1. **If the task above is empty**, ask the user to describe what they want in a
   sentence or two, and wait. Do not invent a task.

2. **Assess whether the task is runnable.** A task is runnable only if it has a
   clear goal **and** acceptance criteria that a reviewer could check
   mechanically. Treat it as **not runnable** when it is a one-liner, a rough
   idea, missing acceptance criteria, ambiguous in scope, or self-contradictory.

3. **If it is not runnable, shape it inline — do not bounce the user to
   `/shape`.** Apply the shaping method defined in
   `${CLAUDE_PLUGIN_ROOT}/skills/shape/SKILL.md` yourself, in this same session:
   read that file, then interrogate the ambiguity in one focused round of
   questions, derive **testable** acceptance criteria, and flag any
   contradictions before proceeding. Show the user the resulting
   `## Task` + `## Acceptance criteria` and get their confirmation.
   - When `tracker: none`, persist the shaped result to
     `./.agent-workspace/feature-request.md` (the shape skill's output contract),
     then continue with it.
   - When `tracker: github`/`gitlab`, the workflow reads the task from an issue.
     Use the shaped task for this run and offer the text for the user to paste
     into an issue; do **not** create the issue yourself.

4. **Only once the task is runnable (already well-formed, or freshly shaped and
   confirmed), proceed** to the workflow below.

The goal: `/run` is the single entry point. The user never has to call `/shape`
by hand — a weak description is shaped here, interactively, then run.

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
