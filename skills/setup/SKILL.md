---
name: setup
description: Bootstrap agents-concerto in the current project by interviewing the user for every configurable option — target repos (with per-repo PR host), task_source, base branch, commit convention, and fix-cycle cap — then writing a filled .agent-workspace/config.md. Detects sensible defaults and asks for confirmation rather than making the user edit YAML by hand.
disable-model-invocation: true
---

# /setup — interactively configure the orchestrator for this project

Prepare the current project to run `/agents-concerto:run`. This creates only
**local** project config; the orchestrator logic stays in the plugin. Your job is
to **interview the user** for each configurable option and write a complete
`./.agent-workspace/config.md` — the user should not have to hand-edit YAML.

## How to ask

- Ask **one decision at a time**, and always **offer a default** (or a value you
  detected) so the user can accept with a single word. Prefer structured choices
  over free text where the option is an enum.
- **Detect, then confirm** — don't ask cold when you can infer. Sniff the repo
  for its remote, default branch, and test command, propose what you found, and
  let the user correct it.
- Offer an **"accept all defaults"** fast path up front for users who just want a
  single-repo, `task_source: none` setup.
- Keep the two axes explicit whenever they come up: **`task_source`** is where
  tasks are *read from*; a repo's **`host`** is where PRs are *opened*. They are
  independent.

## Steps

1. **Workspace.** Ensure `./.agent-workspace/` exists in the current project.

2. **Don't clobber.** If `./.agent-workspace/config.md` already exists, do **not**
   overwrite it silently — show its current contents and ask whether to edit it,
   reconfigure from scratch, or leave it. Only proceed to write once the user
   chooses.

3. **Interview — target repos** (the *implement* axis). Repos are a list; one or
   N is the same to the pipeline. For each repo, gather:
   - **`path`**: an absolute path. **Validate it exists on disk** and is a git
     repo; if not, flag it and re-ask.
   - **`slug`**: a short id. Propose one from the directory name; confirm.
   - **`test`** (optional): a bounded suite command. Sniff the repo (e.g.
     `package.json` scripts, `pyproject.toml`, `Makefile`) and propose one; let
     the user accept, change, or skip it.
   - **`host`** (optional): where PRs open for this repo — `github`, `gitlab`, or
     `none` (branch-only). **Auto-detect from the repo's git remote** and propose
     that (github.com/gitlab.com → that host; no usable remote → `none`); the
     user confirms or overrides. Record `host` explicitly only when it differs
     from what auto-detection would give, or when the user wants it pinned.
   Then ask **"add another repo?"** and loop until done.

4. **Interview — `task_source`** (the *read* axis). Ask where tasks are read
   from: `none` (default — supplied to `/run` or read from
   `.agent-workspace/feature-request.md`), `github`, `gitlab`, `linear`, or
   `jira`. Remind the user this is independent of `host` — e.g. read from Linear,
   open PRs on GitHub.

5. **Interview — conventions & limits.** For each, propose the default and let
   the user accept or change:
   - **`base_branch`**: the ref feature branches are cut from. **Detect the
     repo's default branch** (e.g. `main`/`master`) and propose it. If repos
     disagree, ask per repo or pick the common one and note it.
   - **`commit_convention`**: `conventional` (default) or `default` (free-form).
     Either way the structural-then-behavioral split is enforced.
   - **`max_fix_cycles`**: the review→fix cap before escalating to
     `ready-for-human` (default `3`).
   - **`branch_convention`**: default `feat/<task>-<repo-slug>`. Only ask if the
     user wants to customize it; otherwise keep the default silently.

6. **Write the config.** Write `./.agent-workspace/config.md` from the collected
   answers, following the structure and comments of
   `${CLAUDE_PLUGIN_ROOT}/.agent-workspace/config.md.example`. Then **show the
   final file** and ask the user to confirm it reads correctly.

7. **Gitignore reminder.** Remind the user that local runtime files (`config.md`,
   `feature-request.md`, `plan.md`, `runs/`) are project-local and should be
   gitignored in their project if they don't want them committed.

8. **Next step.** Point them at:
   `/agents-concerto:run <task description>` (or, with `task_source: none`, run
   `/agents-concerto:shape <rough idea>` first to generate
   `./.agent-workspace/feature-request.md` with testable acceptance criteria).

Do not run the pipeline from here — `/setup` only prepares config.
