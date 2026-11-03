# Evidence: level-content-20

Run result: OBSERVED — the three 1152x648 captures boot real levels: level 10 shows "Level 10: Three's a Crowd" with three crates and three plates and Goals 0/3, level 15 shows "Level 15: Crossroads" with four crates and four plates and Goals 0/4, and level 20 shows "Level 20: Final Exam" with its inner walls, four crates and four plates and Goals 0/4. `verify.log` records a real `GameSession` win for all twenty levels, ending with `PASS: 20 levels won`.

## Level captures

- `level-010.png` — level 10, Three's a Crowd, at boot: the HUD reads Level 10, Moves 0, Pushes 0, Goals 0/3; three crates sit above three plates across the pillar wall.
- `level-015.png` — level 15, Crossroads, at boot: the HUD reads Level 15, Moves 0, Pushes 0, Goals 0/4; four crates sit above four plates.
- `level-020.png` — level 20, Final Exam, at boot: the HUD reads Level 20, Moves 0, Pushes 0, Goals 0/4; the inner door walls, four crates and four plates are visible.

## Solvability record

`verify.log` is the output of a temporary `.gd` script (kept in the system temporary directory, not committed) that loads each level with `LevelData` and replays one recorded winning sequence through `src/logic/game_session.gd`. Command:

```
godot --headless --path . -s <system-temp>/verify_levels.gd
```

Result: exit 0, one `level-NNN moves=… pushes=… won=true` line for each of levels 001-020, then `PASS: 20 levels won`.

## Commands

- `python scripts/studio.py check` — exit 0; the project imports and `tests/run_tests.gd` parse-checks. Log: `check.log`.
- `python scripts/studio.py test` — exit 0; 677 checks pass, including the twenty-level campaign manifest. Log: `test.log`.
- `python scripts/studio.py capture --out production/qa/evidence/level-content-20/level-010.png -- --screen=gameplay --level=level-010` — exit 0. Log: `capture-level-010.log`.
- `python scripts/studio.py capture --out production/qa/evidence/level-content-20/level-015.png -- --screen=gameplay --level=level-015` — exit 0. Log: `capture-level-015.log`.
- `python scripts/studio.py capture --out production/qa/evidence/level-content-20/level-020.png -- --screen=gameplay --level=level-020` — exit 0. Log: `capture-level-020.log`.

## Notes

- The captures use `--screen=gameplay` so the boot scene starts the requested level; `--level=` alone only preselects it. The HUD, crates and plates are the normal gameplay scene, not a mock.
- `par_moves` for levels 004-020 is the verified path length plus 10 percent, rounded up; `par_pushes` is the pushes on that path. Levels 001-003 keep their existing par values.
- The level select grid is not part of this story; with twenty cards it needs a scroll container, which is left for the UI story.
