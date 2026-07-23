# Feature request — Scenario A (expected: CLEAN on first attempt)

## Task

Add a root `CHANGELOG.md` to the target repo.

## Acceptance criteria

- A new `CHANGELOG.md` at the repo root.
- Follows the "Keep a Changelog" format: a `# Changelog` title, a one-line
  intro, and an `## [Unreleased]` section with an `### Added` subsection that
  mentions the changelog itself.
- No other files changed.

## Why this should pass clean

The task is trivial and additive, satisfiable in a single behavioral commit, and
its criteria are consistent. A correct implementation meets every criterion, so
the reviewer should return `CLEAN` on cycle 1 with no fix cycles.
