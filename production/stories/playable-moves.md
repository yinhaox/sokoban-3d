---
id: playable-moves
status: done
updated: 2026-11-03
---

# Story: Playable movement, pushing, undo, restart and win

## Context

The room built by `level-view-3d` can be looked at but not played: `GameSession` resolves moves headless, yet nothing forwards a direction into it and no node animates. This story closes the playable loop for one level. `design/core-rules.md` defines movement, pushing, undo, restart and the win condition; `design/input-and-controls.md` defines the direction keys, hold-to-repeat and undo/restart bindings; `design/camera-and-presentation.md` defines the tile tweens, the goal-plate light and the crate settle. Source: issue #11.

## Acceptance

- [x] The arrow keys and `WASD` drive `GameSession.try_move()`, while `Q`/`E` still only rotate the camera and the two never interfere.
- [x] The player and a crate move with a `Tween` of about 0.12–0.16 s, new movement input is ignored while a move runs, and holding a direction keeps moving.
- [x] A move blocked by a wall or a crate gives visible feedback (a small nudge) and leaves the state and the counters unchanged.
- [x] `Z` undoes one step and `Ctrl+Z` undoes repeatedly up to the undo cap; `R` restarts the level and resets the counters; undo and restart reset instantly without rebuilding the room, so nothing flickers.
- [x] A crate landing on a goal plate is visibly acknowledged (the plate lights and the crate settles on it), and filling every goal completes the level.
- [x] On completion a centred overlay shows the moves, the pushes and the elapsed time with a `Retry` and a `Next` button; `Next` is disabled on the last level.
- [x] `tests/run_tests.gd` gains at least 12 assertions covering the input-to-direction mapping, the undo sequence after a push, the restart counters, a rejected move after the win and the completion data.
- [x] Screenshot evidence: entering the level, after one push and the completion overlay, with `Run result: OBSERVED — …`.

## Out of scope

- Main menu, level select, save data, settings, audio, localization and the pause menu. The completion overlay uses the engine default theme; UI polish, translation keys and the restart confirmation modal belong to the UI-flow story.

## Evidence

- `production/qa/evidence/playable-moves/index.md` — `Run result: OBSERVED — the room before input, after one push, a crate on a lit goal plate, and the result overlay on a middle and on the last level`; `enter.png`, `after-push.png`, `goal-filled.png`, `victory.png`, `victory-last-level.png`, `check.log`, `test.log`, `run.log` and the four capture logs are attached there.

## Notes

- The restart confirmation described in `design/core-rules.md` (only when `moves > 0`, Cancel pre-selected) is not implemented because the confirm modal belongs to `design/ui-flow.md` and is outside this story; `R` restarts immediately, as issue #11 asks.
- Input is read from `InputEventKey.physical_keycode` in the controller, the same way `camera_rig.gd` already reads `Q`/`E`; `project.godot` is outside the story boundary, so the `InputMap` actions from `design/input-and-controls.md` arrive with the settings/remap story.
- The overlay strings are English literals because localization is explicitly out of scope for issue #11 and `assets/data/` is outside this story's write boundary; the localization story replaces them with `tr()` keys. Scene-side strings live in `src/ui/victory_panel.gd` constants, not in the `.tscn`, so the scene carries wiring only.
- Capture aids: `main.gd` accepts `--level=<n|id>`, `--script=right,right,…` and `--capture-instant` from the user arguments after `--`, so `capture_command` can produce a state-specific frame. They only apply to a capture run and change no gameplay code path.
- `LevelSequence` lists `assets/data/levels/*.json` in file-name order, which is what decides `Next` availability; the last level in that list disables it.
