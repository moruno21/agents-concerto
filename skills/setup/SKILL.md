---
name: setup
description: Bootstrap agents-concerto in the current project — create a local .agent-workspace/config.md from the shipped template and guide the user through declaring their target repos (with per-repo PR host), task_source, and branch conventions.
disable-model-invocation: true
---

# /setup — bootstrap the orchestrator config for this project

Prepare the current project to run `/agents-concerto:run`. This creates
only **local** project config; the orchestrator logic stays in the plugin.

## Steps

1. Ensure the workspace dir exists in the current project:
   `./.agent-workspace/`.

2. If `./.agent-workspace/config.md` already exists, do **not** overwrite it —
   show its current contents and ask whether to edit it. Otherwise, copy the
   shipped template:
   ```
   ${CLAUDE_PLUGIN_ROOT}/.agent-workspace/config.md.example  →  ./.agent-workspace/config.md
   ```

3. Help the user fill `./.agent-workspace/config.md`:
   - `repos`: one entry per target repo — `slug`, absolute `path`, an optional
     `test` command (bounded; runs the suite and exits non-zero on failure), and
     an optional `host` (`github`/`gitlab`/`none` — **where PRs open for that
     repo**; omit to auto-detect from its remote). The pipeline is agnostic to
     the count; one repo or N is just a longer list.
   - `task_source`: `none`, `github`, `gitlab`, `linear`, or `jira` — **where
     tasks are read from**, a separate axis from `host`. `none` → the task is
     supplied to `/run` (or read from `./.agent-workspace/feature-request.md`);
     the others → read from an issue/ticket on that platform. Make the split
     explicit to the user: reading from Linear/Jira and opening PRs on GitHub is
     a valid combination.
   - `branch_convention` (default `feat/<task>-<repo-slug>`) and `base_branch`.
   Validate that every `repo.path` exists on disk; flag any that don't.

4. Remind the user that local runtime files (`config.md`, `feature-request.md`,
   `plan.md`, `runs/`) are project-local and should be gitignored in their
   project if they don't want them committed.

5. Point them at the next step: run
   `/agents-concerto:run <task description>` (or, with `task_source: none`,
   write `./.agent-workspace/feature-request.md` first — run
   `/agents-concerto:shape <rough idea>` to generate it with testable
   acceptance criteria).

Do not run the pipeline from here — `/setup` only prepares config.
