# agents-concerto

Multi-agent development orchestrator on Claude Code — the agents perform, the
human keeps the baton (reviews and merges).

A task is classified by complexity, implemented in an isolated git worktree
following **TDD + Tidy First**, reviewed under a **two-party boundary** (whoever
writes code never approves or merges), and the pipeline **stops at an open PR
ready for review**. The human reviews and merges by hand. It is agnostic to the number of target
repos: that is just a list in local config.

## Two ways to use it

### A) As a plugin (recommended, reusable across projects)

The reusable logic (agents, `/run` and `/setup` skills, scripts)
ships as a plugin; each project supplies its own local config.

Install (from a remote git repo once this is pushed):

```bash
claude plugin marketplace add moruno21/agents-concerto
claude plugin install agents-concerto@moruno-plugins
```

Or add it locally, straight from this checkout:

```bash
claude plugin marketplace add /Users/antoniomorunogracia/Developer/personal/agents-concerto
claude plugin install agents-concerto@moruno-plugins
```

Then, inside any project you want to orchestrate:

```
/agents-concerto:setup
/agents-concerto:run <task description>
```

`/setup` scaffolds a local `./.agent-workspace/config.md`; `/run` runs
the pipeline for the task.

### B) Standalone (open Claude in this repo)

`CLAUDE.md` is the always-on orchestrator brain. Copy the config template and
run a task:

```bash
cp .agent-workspace/config.md.example .agent-workspace/config.md
# edit config.md: repos (+ per-repo PR host), task_source, conventions
```

Then describe the task (or write `.agent-workspace/feature-request.md` when
`task_source: none`) and let the orchestrator run the workflow.

## Layout

```
.claude-plugin/     plugin.json + marketplace.json (plugin packaging)
agents/             classifier, implementer (model chosen per invocation),
                    reviewer, orchestrator (spec)
.claude/
  settings.json     standalone permissions (no merge)
skills/
  shape/            /shape — turn a rough idea into a runnable task file
  run/              /run — run the pipeline for a task
  setup/            /setup — bootstrap a project's local config
scripts/            worktree-create / worktree-cleanup / run-log / agent-report
CLAUDE.md           the workflow — single source of truth (both modes)
.agent-workspace/   local config + runtime (gitignored); .example is the template
```

## Design invariants

Config-driven repo count; agents by pipeline function not technology; two-party
authority (no code-writer merges); worktree isolation; model chosen by
complexity; **stop at "PR ready"** (no auto-merge); a finite review→fix cap
(`max_fix_cycles`, default 3) then `ready-for-human`.

## Cost

A team of agents costs roughly 4–6× a single Claude Code session. Every run
writes a summary (`.agent-workspace/runs/<id>/summary.md`) with that reminder
plus counts of PRs, fix cycles, and escalations.

For a per-agent breakdown, run:

```bash
scripts/agent-report.sh
```

It reads the current Claude Code session transcript and prints one table per
run: **what each agent did** (files touched, commands, agents coordinated) and
**its token usage plus an API-rate cost reference**. It separates the
orchestrator's own turns from each subagent (`classifier` / `implementer` /
`reviewer`), prices each by model with the three cache tiers, and needs no
`run-log` correlation — the transcript is the single source of truth. Pass a
transcript path as the first argument to report on a different session.

The `$` column is a reference at API rates, **not a charge** — under a Claude
subscription you are not billed per token, so treat it as the token-cost
equivalent (useful for comparing runs or deciding whether a workload belongs on
the pay-per-token API). The editable price table lives at the top of the script.
