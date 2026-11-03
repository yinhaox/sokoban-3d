---
id: ui-shell
status: done
updated: 2026-11-03
---

# Story: Menu, HUD, pause and victory shell

## Context

The playable slice loaded one level straight into gameplay, so the game had no
front door and no way to pause, restart from a menu or pick a level. This story
turns the slice into a game with a shell: a main menu, a level select, an
in-level HUD, a pause menu and a finished victory panel, plus the runtime input
actions from `design/input-and-controls.md` so gameplay and menus share one
action vocabulary. Design reference: `design/ui-flow.md`,
`design/input-and-controls.md`, `design/camera-and-presentation.md`,
`design/core-rules.md` (stars and par), `design/level-progression.md` (stars).
Source: issue #13.

## Acceptance

- [x] `scenes/main.tscn` is a screen router: boot lands on the main menu, a
      level can be entered and left for the main menu, and switching screens
      never restarts the process.
- [x] The main menu offers `Play` (first unfinished level, else the last level),
      `Level Select` (all levels, enterable), `Settings` (placeholder that says
      the next story implements it), `Credits` and `Quit`; every button is
      keyboard reachable and the focused button is visibly ringed.
- [x] The HUD shows moves, pushes, elapsed time, goal completion `x/y`, an Undo
      button, a Restart button and a Pause button; the numbers update without
      flicker.
- [x] `Esc` opens the pause menu with `Resume`, `Restart` (with confirmation),
      `Settings` (placeholder) and `Main Menu` (with confirmation); while paused
      input does not drive movement.
- [x] The victory panel shows moves, pushes and elapsed time, the 1-3 star
      rating computed from par, `Retry`, `Next` (disabled on the last level) and
      `Level Select`; it is keyboard reachable.
- [x] `move_up/down/left/right`, `undo`, `restart`, `pause`,
      `camera_rotate_left/right` and `camera_zoom_in/out` are registered in the
      `InputMap` at runtime from the design table, and existing code that read
      physical keys reads the actions instead.
- [x] Every screen fits 1280x720 and 1152x648 without overlap or overflow and
      no text is smaller than 16 px.
- [x] `tests/run_tests.gd` gains at least 20 assertions covering action
      registration, star calculation, HUD numbers, pause input blocking, router
      state and victory button availability (151 new checks, 514 total).
- [x] Screenshot evidence shows the main menu, gameplay HUD, pause menu and
      victory panel with `Run result: OBSERVED — …`.

## Out of scope

- Save data and level unlocking, the real settings screen, localization, audio,
  new level content and the 20-level campaign. `Level Select` shows the level
  files that exist and lets the player enter any of them.
- `project.godot`, `scripts/`, `addons/`, `design/` and `production/releases/`
  stay untouched; the action registration is done with `InputMap.add_action()`
  in `src/input/input_actions.gd`.

## Evidence

- `production/qa/evidence/ui-shell/index.md` — `Run result: OBSERVED — the boot menu, the level select, the HUD over level 001, the pause menu, the confirm modal, the settings and credits placeholders and the victory panel (Next disabled on level 003), repeated at 1280x720 without clipping`; the four required screens are `main-menu.png`, `hud.png`, `pause.png` and `victory.png`, with `check.log`, `test.log`, `run.log` and one capture log per PNG.

## Notes

- The issue names the camera actions `camera_left/right` and `zoom_in/out`, while
  the design table in `design/input-and-controls.md` — the page the issue names
  as the source of the bindings — calls them `camera_rotate_left`,
  `camera_rotate_right`, `camera_zoom_in` and `camera_zoom_out`. The story
  follows the design table, so there is exactly one action vocabulary and no
  alias that a remap could split in two.
- Input is registered in `src/input/input_actions.gd` with
  `InputMap.add_action()` and `InputMap.action_add_event()` because
  `project.godot` is outside the story boundary. `register_defaults()` is
  idempotent, so a project that later declares the same actions keeps its own
  bindings.
- The menu, pause and confirm screens use `UiTheme` (focus ring 3 px, body 18 px,
  title 64 px) and container layout; the scenes carry no colour, font-size or
  spacing overrides. The HUD buttons keep `focus_mode = ALL` and neighbours, but
  gameplay reads its actions in `_input()` and consumes them, so a focused HUD
  button can never turn an arrow key into menu navigation while the player is
  walking. Undo, restart and pause stay one keyboard action away (`Z`, `R`,
  `Esc`) with or without the buttons.
- `Play` opens the first level not completed in this session, otherwise the last
  level (`src/logic/level_progress.gd`); completion is remembered in memory.
  Save data is out of scope, and the save story replaces the caller, not the
  rule.
- `Level Select` currently lists the three level files that exist. Every card is
  selectable because unlocking is out of scope for this shell, as the issue
  allows.
- Capture aids: `main.gd` accepts `--screen=menu|level-select|gameplay|pause|victory|confirm|settings|credits`,
  `--level=`, `--script=`, `--capture-instant` and `--window=WxH` from the user
  arguments after `--`, so `capture_command` can produce every screen at both
  window sizes. They only apply to a capture boot and change no gameplay path.
- The overlay and screen labels are English literals held in the screen scripts,
  following the convention `victory_panel.gd` already documented, because
  localization is out of scope for issue #13 and `assets/data/` is outside this
  story's write boundary.
- The project declares no `application/config/version`, so the main menu hides
  its `v<version>` corner label instead of inventing one; it appears as soon as
  the project sets the setting.
