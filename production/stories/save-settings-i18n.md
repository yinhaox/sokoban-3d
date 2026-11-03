---
id: save-settings-i18n
status: done
updated: 2026-11-03
---

# Story: Save, progression, settings and bilingual UI

## Context

The game forgot everything when it closed: no profile, no unlocked levels, no
records, a Settings placeholder and English literals in every screen. This story
adds the versioned save file, level unlocking and records, a real settings screen
whose values take effect immediately, and an English/Chinese UI that switches
without a restart. Design reference: `design/settings-and-save.md`,
`design/ui-flow.md`, `design/accessibility.md`,
`design/input-and-controls.md`. Source: issue #16.

The issue is the source of truth for this story. Where it differs from the
reference design (`user://save.json` and the top-level fields `version`,
`unlocked`, `levels`, `settings` instead of `user://save/profile.json` with
`save_version` and `progress.*`), this story follows the issue and records the
difference here.

## Acceptance

- [x] A versioned save at `user://save.json` holds `version`, per-level best
      moves/pushes/time/stars, `unlocked` and `settings`; writes are atomic
      (temp file plus rename); a damaged file is backed up as
      `save.corrupt-<ts>.json`, the game starts from defaults and never crashes.
- [x] An older `version` is migrated through a migration chain to the current
      version; a newer `version` is read-only, never written, and reported.
- [x] Completing a level unlocks the next one; main-menu `Play` opens the most
      recent unfinished unlocked level; level select shows locked cards, stars
      and best records.
- [x] Settings take effect immediately and persist: master volume, SFX volume,
      language (EN/中文), camera sensitivity, colorblind mode, reduce motion and
      fullscreen.
- [x] Every player-visible string goes through `tr()`; `assets/data/i18n/` ships
      `en` and `zh`; switching language applies without a restart; a missing key
      falls back to English and a test asserts no key is missing.
- [x] In colorblind mode the goal, the crate and the player are distinguished by
      shape or icon as well as colour; reduce motion makes tweens, camera turns
      and bump feedback instant.
- [x] `tests/run_tests.gd` gains at least 20 assertions covering save round trip,
      corruption recovery, migration, unlock rules, best-record merging, setting
      clamping, translation-key coverage and colorblind markers.
- [x] Screenshot evidence shows the settings screen, the Chinese UI and the
      colorblind mode, with `Run result: OBSERVED — …`.

## Out of scope

- Audio resources, export packaging and new level content.
- `design/`, `production/releases/`, `studio.yaml`, `project.godot`,
  `scripts/` and `addons/` stay untouched. Translations are registered at
  runtime from `assets/data/i18n/*.json` because `project.godot` is outside this
  story's write boundary.
- Key remapping and its sub-screen, UI scale and per-mode palette tuning are
  reference-design items the issue does not ask for; they are not added.

## Evidence

- `production/qa/evidence/save-settings-i18n/index.md` — `Run result: OBSERVED —`
  the real Settings screen with all seven settings, the fully Chinese level
  select with locked cards, and level 001 in deuteranopia mode with shape
  markers on the crate, goal and player; `settings.png`, `chinese-ui.png` and
  `colorblind.png` come from `capture_command`, `run.png` from `run_command`,
  with `check.log`, `test.log` and one capture log beside them.

## Notes

- **Schema follows the issue, not the reference design.** The live file is
  `user://save.json` with `version`, `unlocked`, `levels.<id>` (completed,
  stars, best_moves, best_pushes, best_time_ms), `settings` and `stats`. The
  reference page's `user://save/profile.json` / `save_version` / `progress.*`
  layout is not used because issue #16 names the path and the fields.
- **Atomic write.** `SaveStore.save_now()` serialises to `save.json.tmp`, rotates
  the current file to `save.json.bak`, then renames the temp into place; a failed
  final rename puts the backup back. A damaged profile is copied to
  `save.corrupt-<unix>.json`, a newer one to `save.newer-<unix>.json`, and the
  newer file is never overwritten (`read_only`).
- **Migration.** `CURRENT_VERSION` is 1 and the chain carries a v0-to-v1 step for
  pre-schema profiles (missing sections filled with defaults). The test suite
  loads a v0 fixture, asserts the migrated values and that the migrated profile
  is written back.
- **Progress.** `complete_level()` merges records (best moves only improve, its
  pushes and time travel with it, stars only rise) and unlocks the next level id.
  `Play` opens the lowest unlocked, uncompleted level and falls back to the last
  level when everything is complete. Locked cards are disabled and unfocusable.
- **Settings model.** `src/logic/settings_model.gd` owns defaults and ranges:
  master/SFX volume 0..1, camera sensitivity 0.5..2.0, language `en`/`zh`,
  colorblind `off`/`deuteranopia`/`protanopia`/`tritanopia`, two booleans. Invalid
  values are clamped with a `push_warning`. The screen emits intent and the boot
  scene stores, applies and flushes; the store debounces settings writes by 0.5 s
  and flushes immediately on level completion and on quit (button and window
  close).
- **Settings apply for real.** Audio busses are set from linear volume (the SFX
  bus is created on first boot), fullscreen calls the display server, camera
  sensitivity scales the rotate/zoom tween duration, reduce motion zeroes tile
  tweens, the bump and the camera/occlusion tweens, and colorblind mode toggles
  the palette plus the shape markers.
- **Bilingual UI.** `src/logic/localization.gd` loads `assets/data/i18n/en.json`
  and `zh.json`, builds two `Translation` resources (the `zh` one layered over
  `en`, so a missing key renders English) and registers them at boot; screens
  call `tr()` and expose `refresh_texts()`, which the boot scene calls after a
  language change. The theme uses a `SystemFont` fallback list, so Chinese
  renders without shipping a font file. The test suite asserts both tables carry
  every required key and that the menu re-translates in place.
- **Colorblind shapes.** Every board builds one finial per crate, two check bars
  per goal and one facing nub on the player. They are hidden unless a colorblind
  mode is on; the palette also switches to the accessible orange/blue values.
  Tests assert the markers exist, hide, show and are attached to the right
  nodes.
- **Checks.** `tests/run_tests.gd` now has 630 checks (116 new). The new block is
  appended and its call is a single added line in `_init`, keeping conflict
  surface with the parallel level story small.
- **Evidence.** Three capture runs plus one `run_command` boot on this branch; the
  commands and their exit codes are in the evidence index. The captures use
  throwaway `user://evidence-save-*.json` profiles so the screenshots show the
  stored defaults rather than a previous run's progress.
