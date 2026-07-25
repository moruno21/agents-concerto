---
name: shape
description: Turn a rough idea into a well-formed task the pipeline can run — interrogate the ambiguity, derive testable acceptance criteria, flag contradictions, and write .agent-workspace/feature-request.md in the exact shape /run consumes. The upstream step before /agents-concerto:run. Invoke explicitly with a rough idea.
disable-model-invocation: true
---

# /shape — turn an idea into a runnable task

This is the **upstream** step of the pipeline. The orchestrator's `/run` starts
from a *well-formed* task (an issue/ticket named by `task_source`, or
`.agent-workspace/feature-request.md`).
Your job here is to produce that task — nothing more. You **do not** run the
pipeline, spawn agents, write code, or create worktrees.

## The idea

$ARGUMENTS

If the idea above is empty, ask the user for a one-paragraph description of what
they want and stop until they provide one. Do not invent an idea.

## Why this step matters

The reviewer grades each PR **against the acceptance criteria** you write here,
and the escape hatch (contradictory criteria → `ready-for-human`) only works if
the criteria are crisp. Vague or contradictory criteria waste an entire run. So
the whole point of `/shape` is to hand `/run` criteria that are **observable and
testable**, and to catch contradictions *before* a run is spent.

## Steps

1. **Interrogate the ambiguity — briefly.** Ask only the questions needed to
   close real gaps; do not run a long questionnaire. Cover, as needed:
   - The **goal**: what outcome does the user actually want, and why.
   - **Scope**: what is explicitly in, and what is explicitly out.
   - **"Done" looks like**: the observable end state.
   - **Which repo(s)** it touches (a filter over `config.md`'s `repos`), if the
     user knows.
   - **Constraints**: compatibility, data, performance, security — only if
     relevant.
   Prefer one focused round of questions. If the idea is already precise, skip
   straight to drafting and just confirm.

2. **Derive testable acceptance criteria.** Turn the answers into a bullet list
   where **each criterion is independently verifiable** — an observable file,
   output, behavior, or state, not a vibe. Favor criteria a reviewer (or a test)
   could check mechanically.

3. **Check for contradictions.** Before writing, verify no two criteria are
   mutually exclusive and that the set is satisfiable. If you find a conflict,
   surface it to the user and resolve it now — do not write a contradictory
   spec (that is exactly what forces a wasted run and an escalation).

4. **Write the task file.** Write `./.agent-workspace/feature-request.md` in the
   current project, in the exact shape the pipeline reads:

   ```markdown
   # Feature request — <short title>

   ## Task

   <one or two sentences: what to build and why>

   ## Acceptance criteria

   - <testable criterion>
   - <testable criterion>
   - <scope boundary, e.g. "No other files changed." when it matters>
   ```

   Keep `## Task` and `## Acceptance criteria` as the two required sections —
   that is what `/run` and the reviewer consume. If
   `./.agent-workspace/feature-request.md` already exists, show it and ask
   before overwriting.

5. **Hand off — do not run.** Tell the user the task is ready and point them at
   the next step:
   - Default (`task_source: none`): `/agents-concerto:run <the task>`.
   - If their `config.md` sets `task_source` to `github`/`gitlab`/`linear`/`jira`,
     `/run` reads the task from an **issue/ticket** on that platform, not this
     file. In that case treat what you wrote as a draft the user can paste into a
     new ticket. **Do not create the ticket yourself** — that is a side effect
     the user should own.

## Hard limits

- You only write `./.agent-workspace/feature-request.md`. No code, no worktrees,
  no agents, no PRs, no merges.
- Never create tracker issues/tickets, push branches, or run `/run` on the
  user's behalf — shaping stops at a ready task file.
