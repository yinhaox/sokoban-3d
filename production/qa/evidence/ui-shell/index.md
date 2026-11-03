# Evidence: ui-shell

Run result: OBSERVED — at 1152x648 the boot window shows the main menu with Play focused, the level select lists all three level files, the in-level strip shows level name, moves, pushes, goals 0/1 and the running timer over the room, the pause menu dims the frozen room with Resume focused, the confirm modal asks "Discard this attempt?" with Cancel focused, and the victory panel shows three gold stars, moves against par, pushes, time and Retry/Next/Level Select, with Next visibly disabled on the last level; every screen repeats without clipping or overlap at 1280x720.

## Screens at 1152x648

- `main-menu.png` — the boot screen: "Sokoban 3D", the subtitle, and Play (focused, yellow ring), Level Select, Settings, Credits and Quit; no room is previewed behind it.
- `level-select.png` — all three level files as cards with number, name, par and difficulty; the first card is focused and a Back button sits below the grid.
- `hud.png` — level-001 after `right,right`: the top strip reads "Level 1: First Push", "Moves: 2", "Pushes: 1", "Goals: 0/1" and "Time: 0:00.3" with Undo, Restart and Pause buttons to their right, and the room keeps the rest of the window.
- `pause.png` — Escape state over level-001: the frozen room is dimmed and the panel shows Paused with Resume (focused), Restart, Settings and Main Menu; the HUD strip is hidden.
- `confirm.png` — the destructive-action modal over the paused level after `right,right`: "Discard this attempt?" with Cancel focused and Confirm beside it.
- `settings.png` — the Settings placeholder: one line saying the next story implements audio, display, accessibility and controls, with a Back button.
- `credits.png` — the Credits screen with the project credit lines and a Back button.
- `victory.png` — level-001 solved in 6 moves against par 6: three gold stars, "3 of 3 stars", Moves, Pushes, Time, Retry focused, Next enabled and Level Select.
- `victory-last.png` — level-003 solved in 19 moves against par 24: the same panel with Next visibly disabled on the last level and Retry and Level Select still enabled.
- `run.png` — the same boot frame written by `run_command`, proving the normal game boot matches the capture boot.

## The same screens at 1280x720

The project uses `canvas_items` stretch, so these captures show the 1152x648 layout scaled into a 1280x720 window; no text, button or panel is clipped at either size.

- `main-menu-1280.png`, `level-select-1280.png`, `hud-1280.png`, `pause-1280.png`, `victory-1280.png`, `confirm-1280.png`, `settings-1280.png`, `credits-1280.png` — the eight screens above at 1280x720.

## Logs

- `check.log` — `python scripts/studio.py check` (exit 0; imports the project and parse-checks the 20 changed scripts).
- `test.log` — `python scripts/studio.py test` (exit 0; 514 checks pass, 151 more than the 363 of `playable-moves`, covering action registration, star calculation, HUD numbers, pause input blocking, router state and victory button availability).
- `run.log` — `python scripts/studio.py run --capture production/qa/evidence/ui-shell/run.png` (exit 0; the window boots to the main menu with no script errors).
- `capture-main-menu.log` — `python scripts/studio.py capture --out production/qa/evidence/ui-shell/main-menu.png -- --screen=menu` (exit 0).
- `capture-level-select.log` — `python scripts/studio.py capture --out production/qa/evidence/ui-shell/level-select.png -- --screen=level-select` (exit 0).
- `capture-hud.log` — `python scripts/studio.py capture --out production/qa/evidence/ui-shell/hud.png -- --screen=gameplay --level=1 --script=right,right` (exit 0).
- `capture-pause.log` — `python scripts/studio.py capture --out production/qa/evidence/ui-shell/pause.png -- --screen=pause --level=1 --script=right,right` (exit 0).
- `capture-victory.log` — `python scripts/studio.py capture --out production/qa/evidence/ui-shell/victory.png -- --screen=victory --level=1 --script=right,right,down,right,up,up` (exit 0).
- `capture-victory-last.log` — `python scripts/studio.py capture --out production/qa/evidence/ui-shell/victory-last.png -- --screen=victory --level=3 --script=up,right,up,right,down,left,down,right,right,left,left,left,left,up,up,right,right,right,right` (exit 0).
- `capture-confirm.log` — `python scripts/studio.py capture --out production/qa/evidence/ui-shell/confirm.png -- --screen=confirm --level=1 --script=right,right` (exit 0).
- `capture-settings.log` — `python scripts/studio.py capture --out production/qa/evidence/ui-shell/settings.png -- --screen=settings` (exit 0).
- `capture-credits.log` — `python scripts/studio.py capture --out production/qa/evidence/ui-shell/credits.png -- --screen=credits` (exit 0).
- `capture-*-1280.log` — the eight same-named commands with `--window=1280x720` appended (all exit 0).

## Notes

- The scripted captures drive the normal input path: `--script=` calls `GameplayController.request_move()` for each direction and `--screen=` only chooses which screen the boot scene shows, so each frame is a state the game really reached.
- The victory time reads `0:00.0` because the scripted moves run during `_ready()`, before any frame time elapses; the HUD capture shows the timer running (`0:00.3`).
- The 1280x720 captures are scaled by the project's `canvas_items` stretch mode and prove the window shows the same screens without clipping; the 1152x648 captures are the minimum-size layout the design requires.
