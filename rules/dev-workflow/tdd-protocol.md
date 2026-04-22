# TDD Protocol (/dev workflow integration)

ECC testing.md defines general TDD steps (RED→GREEN→REFACTOR→COVERAGE).
This file adds /dev-specific integration that ECC does not cover.

## After GREEN: verify + commit

3. **VERIFY** — Run full test suite, confirm no regressions (not just coverage)
4. **COMMIT** — Commit test + implementation together, one logical unit per subtask

## When to apply (by intent)

- **New features**: always TDD
- **Bug fixes**: write test reproducing the bug FIRST, then fix
- **Refactors**: ensure existing tests pass BEFORE and AFTER

## When to skip

Config-only changes, documentation, UI-only changes where visual review suffices.
