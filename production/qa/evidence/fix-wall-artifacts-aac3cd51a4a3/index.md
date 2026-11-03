# Evidence: fix-wall-artifacts-aac3cd51a4a3

Run result: OBSERVED — at 1152x648 the level-10 room shows the three interior pillars and the faded near border walls as pale translucent walls with a complete top face and one merged contour per wall segment, with no dark cavity and no per-cell seam lines; the three crates, three goal plates and the player stay readable at the default view and after one 90 degree turn. Level 14 shows the same on its long interior wall, and the colour-blind view keeps the crate, goal and player markers distinct.

- `before-level-010-default.png` — level 10 on the unmodified branch head `0ed346c`, default view: the pillars are transparent boxes with a 0.70-alpha dark cap that reads as a hole, and every 1x1 wall cell draws its own outline.
- `before-level-010-quarter-turn-1.png` — the same room at yaw 135 degrees before the fix.
- `before-level-014.png` — level 14's long interior wall before the fix: the same per-cell seam lines.
- `after-level-010-default.png` — the fixed default view: each faded pillar has a pale full-cell top face at 25% alpha and one merged contour square, the faded border wall draws only its outer and inner contour, and no internal seam line crosses the wall top.
- `after-level-010-quarter-turn-1.png` — the same room at yaw 135 degrees after the fix; the newly faded pillars and border segment show the same complete top and single merged contour.
- `after-level-014.png` — level 14 after the fix: the long interior wall renders as one segment with a single contour and no seams between its cells; the opaque part stays solid.
- `after-level-010-colorblind.png` — level 10 in colour-blind mode: the faded walls keep their complete top and contour, and the yellow crates, blue player and teal checked goals stay distinct through them.
- `after-run-window.png` — the same default room captured by `run_command` with a real window (`run.log` records the OpenGL 3.3 Compatibility renderer and `Godot exited with code 0`).
- `capture-before-level-010-default.log`, `capture-before-level-010-quarter-turn-1.log`, `capture-before-level-014.log` — `capture_command` output for the before run (exit 0 each).
- `capture-after-level-010-default.log`, `capture-after-level-010-quarter-turn-1.log`, `capture-after-level-014.log`, `capture-after-level-010-colorblind.log` — `capture_command` output for the after run (exit 0 each).
- `regression-before.log` — `test_command` on the unmodified code with the new assertions: `FAIL: 4 of 909 checks failed`, exit 1.
- `regression-after.log` — `test_command` after the fix: `PASS: 911 checks passed`, exit 0.
- `check.log` — `check_command` after the fix: import OK, 3 changed scripts parsed, exit 0.
- `check-before.log` — `check_command` on the unmodified code: import OK, exit 0.
- `repro.md` — commands, inputs, expected behavior and the observed defect.
