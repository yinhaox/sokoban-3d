# Evidence: playable-moves

Run result: OBSERVED — the 1152x648 window shows level-001 before input, the same room after one push, a crate resting on a lit goal plate under a second crate on level-003, and the centred "Level Complete" overlay with moves, pushes, time, Retry and Next — enabled on level-001 and disabled on the last level.

- `enter.png` — the boot level (level-001) before any input: the red player, one wood crate with its top cross and the teal goal plate on the sand floor, with no overlay.
- `after-push.png` — after `right,right`: the player has stepped right and pushed the crate one cell towards the goal, and the plate is still empty.
- `goal-filled.png` — level-003 after a partial solution: the crate on the upper goal plate is drawn in the lighter on-goal colour and settles on the plate, whose ring shows lit, while the second plate stays dark with its crate still off it.
- `victory.png` — level-001 solved in 6 moves and 3 pushes: the centred overlay reports "Level Complete", Moves: 6, Pushes: 3 and Time: 0:00.0, with Retry focused and Next enabled because level-002 follows.
- `victory-last-level.png` — level-003 solved in 19 moves and 7 pushes: the same overlay with Next visibly disabled and dimmed on the last level.
- `run.log` — `python scripts/studio.py run --capture production/qa/evidence/playable-moves/enter.png` (exit 0); the windowed run boots with no script errors.
- `capture-push.log` — `python scripts/studio.py capture --out production/qa/evidence/playable-moves/after-push.png -- --script=right,right` (exit 0).
- `capture-goal.log` — `python scripts/studio.py capture --out production/qa/evidence/playable-moves/goal-filled.png -- --level=3 --script=left,up,up,right,right,right,right` (exit 0).
- `capture-victory.log` — `python scripts/studio.py capture --out production/qa/evidence/playable-moves/victory.png -- --level=1 --script=right,right,down,right,up,up` (exit 0).
- `capture-victory-last.log` — `python scripts/studio.py capture --out production/qa/evidence/playable-moves/victory-last-level.png -- --level=3 --script=up,right,up,right,down,left,down,right,right,left,left,left,left,up,up,right,right,right,right` (exit 0).
- `check.log` — `python scripts/studio.py check` (exit 0; imports the project and parse-checks the six changed scripts).
- `test.log` — `python scripts/studio.py test` (exit 0; 363 checks pass, including the input-to-direction mapping, the undo sequence after a push, the restart counters, the ignored input during a tile tween, the hold-to-repeat steps, the rejected move after the win and the completion payload).

## Notes

- `--level`, `--script` and `--capture-instant` are the capture aid documented in `src/main.gd`; the scripted moves go through the normal `GameplayController.request_move()` path, so each captured frame is a state the game really reached. The aid only applies to a capture boot.
- The overlay time reads `0:00.0` in both victory captures because the scripted sequence is applied in `_ready()` before the first frame, so no frame time elapsed. The field and its `m:ss.t` format are on screen; during interactive play the timer starts on the first accepted move.
- The blocked-move nudge lasts `bump_seconds` (0.06 s), so a still frame cannot show it. `test.log` asserts that a blocked move leaves the player cell and the counters unchanged and that the bump ends by clearing the busy state.
- All PNGs are full-window captures from `capture_command` on this branch, larger than 1 KB (32–39 KB each).
