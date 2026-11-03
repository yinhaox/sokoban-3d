# Evidence: boot-aids

Run result: OBSERVED — `--level=010` opened level 10 ("Level 10: Three's a Crowd", Moves 0, three crates and three plates), `--screen=settings --lang=zh` opened the Settings screen with Chinese labels and 中文 selected, and `--level=001 --script=right,right` opened level 1 after two moves and one push (Moves 2, Pushes 1, crate one cell right).

- `play-level-010.png` — level 010 is on screen directly after boot: HUD reads "Level 10: Three's a Crowd" with Moves 0, Pushes 0, Goals 0/3, Time 0:00.0, and the room shows the three crates and three goal plates of `level-010.json`.
- `zh-settings.png` — the Settings screen opened by `--screen=settings --lang=zh`: the title reads 设置, every group and row label is Chinese, the language option shows 中文, and the colorblind option shows 关闭.
- `script.png` — level 001 after the parsed `right,right` sequence: HUD reads "Level 1: First Push" with Moves 2, Pushes 1, Goals 0/1, and the crate has moved one cell right with the player behind it.
- `check.log` — `python scripts/studio.py check` (exit 0): import OK and both changed scripts parse.
- `test.log` — `python scripts/studio.py test` (exit 0): 825 checks passed, including the boot-argument parsing, invalid level, override-not-persisted and scripted-move counts.
- `capture-play-level-010.log` — `python scripts/studio.py capture --out production/qa/evidence/boot-aids/play-level-010.png -- --level=010` (exit 0).
- `capture-zh-settings.log` — `python scripts/studio.py capture --out production/qa/evidence/boot-aids/zh-settings.png -- --screen=settings --lang=zh` (exit 0).
- `capture-script.log` — `python scripts/studio.py capture --out production/qa/evidence/boot-aids/script.png -- --level=001 --script=right,right` (exit 0).

The three captures come from the same build and branch as this change; each launched the normal main scene with the argument under test and no mock or edited frame. The level and screen differ in all three, and the script capture's counters come from the normal `GameplayController.request_move()` path.
