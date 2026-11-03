# Evidence: visual-polish

Run result: OBSERVED — at 1152x648 the level-10 room (three crates, three goal plates, three interior wall pillars) reads as a finished diorama: the border walls and pillars keep a crisp dark top outline and vertical edges even while their bodies ghost out, the sand floor shows one faint grid line per cell edge, the three crates and the red player capsule sit on soft contact shadows, every teal goal ring is edged by a soft contact shadow and stays readable without its emission, and the dark 0.05-unit base closes the floor edge under the faded walls so no black void remains at the room's corners. The same room stays readable at the other three quarter turns and in deuteranopia mode.

## Artifacts

- `before-level-010.png` — `python scripts/studio.py capture --out production/qa/evidence/visual-polish/before-level-010.png -- --level=level-010` on the unmodified branch before this change (baseline only, not the result): the interior pillars are glassy translucent blocks with no outline, the floor has no grid, and the floor edge under the faded border walls shows a dark void.
- `level-010-default.png` — `python scripts/studio.py capture --out production/qa/evidence/visual-polish/level-010-default.png -- --level=level-010`: the default view; each faded pillar keeps its top outline and four vertical edges, the floor grid is faint but continuous, the crates, the player and the three goal plates carry contact shadows, and the base rim closes the near floor edge.
- `level-010-quarter-turn-1.png` — `python scripts/studio.py capture --out production/qa/evidence/visual-polish/level-010-quarter-turn-1.png -- --level=level-010` with `STUDIO_CAPTURE_QUARTER_TURNS=1`: the same room at yaw 135°; the pillars on the new near side still read as walls, the goal rings and the player stay visible.
- `level-010-quarter-turn-2.png` — the same capture with `STUDIO_CAPTURE_QUARTER_TURNS=2`: yaw 225°; the opaque near walls now show their border and edges, the two faded pillars keep their outlines, and the player at the near edge is not hidden.
- `level-010-quarter-turn-3.png` — the same capture with `STUDIO_CAPTURE_QUARTER_TURNS=3`: yaw 315°; the room is still readable from the fourth snap state.
- `level-010-colorblind.png` — `python scripts/studio.py capture --out production/qa/evidence/visual-polish/level-010-colorblind.png -- --level=level-010 --colorblind=1`: deuteranopia mode; crates are yellow with the black raised cross and finial, the player is blue with the facing nub, and the goal plates keep the teal ring plus the dark check mark, so shape still separates all three.
- `level-010-reduce-motion.png` — `python scripts/studio.py capture --out production/qa/evidence/visual-polish/level-010-reduce-motion.png -- --level=level-010 --reduce-motion=1`: the grid is absent while the rest of the room is unchanged, proving the grid follows the `reduce_motion` setting.
- `run-window.png` — `python scripts/studio.py run --capture production/qa/evidence/visual-polish/run-window.png -- --level=level-010`: the same default room from the run command with a real window; `run.log` records the OpenGL 3.3 Compatibility renderer and `Godot exited with code 0`.

## Logs

- `check.log` — `python scripts/studio.py check`: `[check] import OK`, `[check] parsed 3 changed script(s)`, exit code 0.
- `test.log` — `python scripts/studio.py test`: `PASS: 905 checks passed`, `[test] PASS`, exit code 0. The visual-polish checks cover the fade cap alpha, the wall-outline toggle, the grid colour step and reduce-motion switch, one contact-shadow group per crate, goal and player, and the 0.05-unit room base.
- `before-capture.log`, `capture-default.log`, `capture-quarter-turn-1.log`, `capture-quarter-turn-2.log`, `capture-quarter-turn-3.log`, `capture-colorblind.log`, `capture-reduce-motion.log`, `run.log` — the recorded output of each command above; every capture reports `OK` with a PNG larger than 10 KB.
