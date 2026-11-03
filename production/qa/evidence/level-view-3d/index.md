# Evidence: level-view-3d

Run result: OBSERVED — the 1152x648 window shows the 7x7 sand room under an isometric camera: the red player at cell (2,3), the wood crate with its raised cross at (4,3) and the teal goal plate with its ring at (5,1), with the near-side walls faded to ghosts so the room reads from the camera.

- `level-view-3d-1.png` — `python scripts/studio.py capture --out production/qa/evidence/level-view-3d/level-view-3d-1.png`: the 7x7 room, player, crate and goal plate; the near-side walls are faded by the occlusion pass.
- `run.png` — `python scripts/studio.py run --capture production/qa/evidence/level-view-3d/run.png`: the same room from the boot scene, proving `scenes/main.tscn` starts the 3D view instead of the 2D placeholder.
- `capture.log` — output of the capture command: `[capture] OK`, 38062 bytes, exit code 0.
- `run.log` — output of the run command: Godot 4.7.2 on the GL Compatibility renderer, `studio_capture: wrote .../run.png`, exit code 0, no script errors.
- `check.log` — output of `python scripts/studio.py check`: `[check] import OK`, all 4 changed scripts parse, exit code 0.
- `test.log` — output of `python scripts/studio.py test`: 216 headless checks pass, `[test] PASS`, exit code 0.
