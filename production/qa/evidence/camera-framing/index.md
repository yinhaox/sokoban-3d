# Evidence: camera-framing

Run result: OBSERVED — the 1152x648 window shows the whole 7x7 room centred with equal opposite margins: warm sand floor, slate walls on all four sides, the near-side border walls rendered as semi-transparent ghosts whose darker top caps still draw the wall outline, the red player at cell (2,3), the wood crate at (4,3) and the teal goal plate at (5,1) sitting inside the wall ring; the same room is complete and readable at yaw 135, 225 and 315 degrees, and the crate and the player cast soft contact shadows on the floor.

## Artifacts

- `before.png` — `python scripts/studio.py capture --out production/qa/evidence/camera-framing/before.png` on the unfixed branch (commit `0c81720`, branch `agent/fix-room-framing-a25174f04f11`): the room's content box is x 216..935, y 36..554 in the 1152x648 viewport, so it sits 28 px above the centre (top margin 36 px, bottom margin 93 px); the near border walls are faded to alpha 0.12 and effectively invisible, so the room reads as open and the goal plate at (5,1) looks like it lies outside the wall.
- `after.png` — the same `capture_command` after the fix: content box x 221..930, y 65..576, margins L=221 R=221 T=65 B=71 (centre 575.5,320.5 against the viewport centre 575.5,323.5); the near border walls are translucent with their top caps still drawn, and the goal plate is inside the wall ring.
- `view-135.png`, `view-225.png`, `view-315.png` — the other three quarter turns of the same build, captured with `capture_command` and the boot-time capture aid `STUDIO_CAPTURE_QUARTER_TURNS=1|2|3`. The room's content box is x 221..930, y 65..576 in all four views.
- `run-after.png` — `python scripts/studio.py run --capture …`: the boot scene (`res://scenes/main.tscn`) renders the same room with no engine errors, on Godot 4.7.2 / GL Compatibility.
- `repro.md` — the reproduction steps, the measured defect and the root cause.
- `regression-before.log` — `test_command` before the fix: `FAIL: 15 of 287 checks failed` (the projected room is not centred at any of the four yaws, and the faded wall cap is not an outline), `[test] FAIL (exit code 1)`.
- `regression-after.log` — `test_command` after the fix: `PASS: 287 checks passed`, `[test] PASS`, exit code 0.
- `check.log` — `check_command`: `[check] import OK`, `[check] parsed 4 changed script(s)`, exit code 0.
- `capture-before.log`, `capture-after.log`, `angle-capture.log`, `run-after.log` — the recorded output of the capture and run commands above.
