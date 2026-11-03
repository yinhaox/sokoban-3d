---
id: boot-aids
status: done
updated: 2026-11-03
---

# Story: Boot aids for state-specific screenshots

## Context

The boot scene already carries a handful of ad-hoc capture switches, but they
do not form one named debug surface: the screen values, the language flag and
the colour-blind value differ from what the studio documents, and the settings
overrides are written through the save store. This story adds one boot-only
argument set so a capture can open a specific level or screen, override the
language and accessibility settings for that run, and replay a move sequence,
while a boot without arguments behaves exactly as before. Source: issue #20.
Design reference: `design/technical-architecture.md` (layering and the capture
autoload) and `design/ui-flow.md` (the screen graph).

The arguments are read from `OS.get_cmdline_user_args()` after the engine's
`--` in `src/main.gd`. They only affect that one startup: language, colour-blind
mode and reduce-motion are applied as in-memory overrides and are never written
to `user://save.json`.

## Acceptance

- [x] `--level=<id|position>` boots directly into that level.
- [x] `--screen=<menu|level_select|settings|credits|play>` boots directly to
      that screen.
- [x] `--lang=<en|zh>` overrides the language; `--colorblind=<0|1>` and
      `--reduce-motion=<0|1>` override those settings; `--script=<right,right,up>`
      runs the moves in order after the level is entered.
- [x] With no arguments the boot is unchanged (main menu), and none of these
      arguments write to the save file.
- [x] When `--level` and `--screen=play` are both given, `--level` wins; an
      unknown argument prints one warning line and is ignored.
- [x] `tests/run_tests.gd` asserts argument parsing (including an unknown
      argument and an invalid level), that setting overrides are not persisted,
      and the expected counters from a scripted move sequence on a test level.
- [x] Three captures differ and show the requested states: `play-level-010.png`
      (`--level=010`), `zh-settings.png` (`--screen=settings --lang=zh`) and
      `script.png` (`--level=001 --script=right,right`).
- [x] `python scripts/studio.py check` and `python scripts/studio.py test` pass.

## Out of scope

- Audio, export packaging and level content.
- `design/`, `production/releases/`, `studio.yaml`, `project.godot`, `scripts/`
  and `addons/` stay untouched.
- Normal boot, gameplay rules and save semantics; the arguments only affect a
  startup that names them.

## Evidence

- `production/qa/evidence/boot-aids/index.md` — `Run result: OBSERVED —` level 10
  opened directly with `--level=010`, the Settings screen rendered in Chinese
  with `--screen=settings --lang=zh`, and level 001 showed Moves 2 / Pushes 1
  after `--script=right,right`; `play-level-010.png`, `zh-settings.png`,
  `script.png`, `check.log`, `test.log` and one capture log per PNG are attached
  there.

## Notes

- The parser in `src/main.gd` is static and takes the user-argument array, so
  `tests/run_tests.gd` exercises it headless without booting the scene.
- `--colorblind=1` maps to `deuteranopia`, the mode named in the
  `design/accessibility.md` review example; `--colorblind=0` maps to `off`.
- The setting overrides are merged into an in-memory copy in
  `settings_with_boot_overrides()`; `SaveStore.set_setting()` is not called for
  them, and a test compares the profile bytes before and after a boot override.
- The earlier capture switches (`--screen=gameplay|level-select|pause|victory|confirm`,
  `--language=`, `--window=`, `--save=`, `--fresh-save`, `--capture-instant`)
  keep working as aliases so existing capture recipes stay valid.
