---
id: core-rules-headless
status: done
updated: 2026-11-03
---

# Story: Headless Sokoban rules and level data

## Context

The first playable slice starts as a rule set that can be proven without a window, per `design/technical-architecture.md` (the logic layer may not touch `Node`, `SceneTree`, `Input`, rendering or file IO). This story implements that logic layer and the on-disk level contract it reads: `design/core-rules.md` for movement, pushing, undo, restart, deadlock and the win condition; `design/level-format.md` for the JSON shape and its validation rules. Source: issue #3.

## Acceptance

- [x] `src/logic/level_data.gd` parses and validates a level per `design/level-format.md`; a wrong size, unequal box and goal counts, a missing player and out-of-grid coordinates return explicit errors instead of crashing.
- [x] `src/logic/game_session.gd` implements four-way movement, pushing, a failed result with unchanged state for a wall or a blocked box, the win condition, move and push counters, at least 100 undo steps, and restart.
- [x] `src/logic/deadlock.gd` detects a box pushed into a non-goal corner.
- [x] `tests/run_tests.gd` covers every rule above with at least 25 assertions, all passing headless.
- [x] `assets/data/levels/level-001.json`, `level-002.json` and `level-003.json` exist and each loads through `LevelData` and validates.
- [x] `test_command` and `check_command` pass.
- [x] `production/qa/evidence/core-rules-headless/index.md` records `Run result: N/A — 纯逻辑变更，无运行时表现` and attaches the test log.

## Out of scope

- 3D scenes, camera, UI, audio, save data and settings. This story ships only the headless rule layer and level data, so it adds no on-screen behaviour.

## Evidence

- `production/qa/evidence/core-rules-headless/index.md` — `Run result: N/A — 纯逻辑变更，无运行时表现`; `test.log` and `check.log` are attached there.

## Notes

- `design/core-rules.md` proposes `undo_limit` 50 (range 10..100); issue #3 requires at least 100 reachable undo steps, so `GameSession` defaults to the documented maximum of 100.
- `design/level-format.md`'s example for level 1 declares `columns: 7` but four of its tile rows are 8 characters, so the loader rejects that example as written. `level-001.json` keeps the example's layout and intent on a 7x7 grid.
