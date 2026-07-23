# Feature request — Scenario B (expected: exhaust 3 fix cycles → ready-for-human)

## Task

Add a root `CONSTANTS.md` to the target repo.

## Acceptance criteria (deliberately contradictory — cannot all be satisfied)

- The file `CONSTANTS.md` MUST contain the exact line `VALUE = 1`.
- The file `CONSTANTS.md` MUST NOT contain the digit `1` anywhere.
- The file MUST be non-empty.
- No other files changed.

## Why this should escalate

Criteria 1 and 2 are mutually exclusive: any file that contains `VALUE = 1` also
contains the digit `1`, and any file without `1` cannot contain `VALUE = 1`. No
implementation can satisfy both, so the reviewer must return `NEEDS_FIXES` every
cycle. After 3 review→fix cycles the orchestrator hits the cap, labels the PR
`ready-for-human`, and stops. This exercises the escape hatch, not a bug.

The reviewer must NOT relax a criterion to force a pass; hitting the cap and
escalating is the correct behavior here.
