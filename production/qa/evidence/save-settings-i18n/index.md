# Evidence: save-settings-i18n

Run result: OBSERVED — at 1152x648 the real Settings screen shows Audio (Master volume 80%, SFX volume 90%), Display (Language English, Fullscreen), Controls (Camera sensitivity 1.00x) and Accessibility (Colorblind mode Off, Reduce motion) with a Back button; the level select renders fully in Chinese with 第 01 关 unlocked and 第 02/03 关 marked 未解锁; and level 001 in deuteranopia colorblind mode draws a dark finial and cross on the orange crate, a dark check on the blue goal plate and a facing nub on the blue player.

## Screenshots

- `settings.png` — the real Settings screen opened from the main menu with a fresh profile: every one of the seven settings the issue asks for is visible on one page at 1152x648, with the stored defaults (master 80%, SFX 90%, English, fullscreen off, camera 1.00x, colorblind off, reduce motion off) and a Back button.
- `chinese-ui.png` — level select booted with `--language=zh`: the title, card numbers, level name, par, difficulty, star line, lock state and Back button are Chinese; the profile is fresh, so only 第 01 关 is unlocked and 第 02/03 关 show 未解锁 without a name.
- `colorblind.png` — level 001 booted with `--colorblind=deuteranopia`: the crate is orange with a raised dark cross plus a dark finial post, the goal plate is blue with a dark check mark, and the player is blue with a dark facing nub, so each piece is distinguishable by shape and not only by colour. The HUD strip stays English because the language setting was left at its default.
- `run.png` — the normal boot through `run_command`: the main menu with Play focused, proving the profile/settings boot path does not error and the game still starts on the menu.

## Logs

- `check.log` — `python scripts/studio.py check` (exit 0; imports the project and parse-checks the 17 changed scripts).
- `test.log` — `python scripts/studio.py test` (exit 0; 633 checks pass, 119 more than the 514 of `ui-shell`, covering save round trip, unknown-key preservation, backup adoption, corrupt recovery, newer version read-only, v0 migration, unlock rules, best-record merging, level-select lock/star/best cards, setting clamping, translation coverage/fallback, immediate locale switch, the settings screen and colorblind/reduce-motion behaviour).
- `run.log` — `python scripts/studio.py run --capture production/qa/evidence/save-settings-i18n/run.png` (exit 0; boots to the main menu and writes `run.png`; no script error or warning on the boot path).
- `capture-settings.log` — `python scripts/studio.py capture --out production/qa/evidence/save-settings-i18n/settings.png -- --screen=settings --save=user://evidence-save-settings.json --fresh-save` (exit 0).
- `capture-chinese-ui.log` — `python scripts/studio.py capture --out production/qa/evidence/save-settings-i18n/chinese-ui.png -- --screen=level-select --language=zh --save=user://evidence-save-zh.json --fresh-save` (exit 0).
- `capture-colorblind.log` — `python scripts/studio.py capture --out production/qa/evidence/save-settings-i18n/colorblind.png -- --screen=gameplay --level=1 --colorblind=deuteranopia --save=user://evidence-save-cb.json --fresh-save` (exit 0).

## Notes

- All four PNGs are 1152x648, the project window size. No image was mocked, cropped or reused.
- The capture arguments are the normal capture aids in `src/main.gd`: `--screen=` selects the screen, `--language=` and `--colorblind=` set the same settings the Settings screen writes, and `--save=` / `--fresh-save` point the run at a throwaway profile so each capture starts from the stored defaults. `--fresh-save` removed the profile, its temp file and its backup for those throwaway paths.
- The settings screen is reached through the same main-menu intent signal as a player would use; the capture boot only chooses the screen after the profile and settings are resolved.
- The save path is `user://save.json`. The test suite uses throwaway `user://test-save-*.json` files and removes them and their corrupt/newer backups after each case.
