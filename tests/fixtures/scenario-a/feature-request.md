# Feature request — Scenario A (expected: CLEAN on first attempt)

## Task

As a contributor, I want a `CHANGELOG.md` at the repo root, so that anyone can
see what changed in a release without reading the git log.

## Acceptance criteria

- Given the repo root, when the change is applied, then a `CHANGELOG.md` file
  exists there.
- Given `CHANGELOG.md`, when it is opened, then it starts with a `# Changelog`
  title followed by a one-line intro.
- Given `CHANGELOG.md`, when its sections are read, then it contains an
  `## [Unreleased]` section with an `### Added` subsection that mentions the
  changelog itself.

## Scope

- Out: No other files changed.

## Why this should pass clean

The task is trivial and additive, satisfiable in a single behavioral commit, and
its criteria are consistent. A correct implementation meets every criterion, so
the reviewer should return `CLEAN` on cycle 1 with no fix cycles.
