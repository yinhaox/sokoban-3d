# Design: settings and save

_The settings the player can change, the versioned save file that holds them and all progress, and what happens when that file is damaged. Owned by the technical director._

## Goals

Pillar P4 (playable by everyone). Settings must be reachable from both the main menu and pause, persist exactly as chosen, and never be lost because of a crash or a version upgrade.

- One save file holds settings, progress and records; it is written atomically, backed up, and versioned.
- Every settings value has a default, a range and a visible effect; a value the current build cannot honor is clamped with a logged warning, not silently ignored.
- A damaged, foreign or newer save never blocks the game: the player keeps playing with a fresh profile and is told what happened.

The page lands when a headless test can load a v1 fixture, migrate it, round-trip it, reject a corrupted file with a backup, and when a kill during write still leaves one readable save.

## Player experience

The player opens Settings from the main menu or pause and sees four tabs: Audio, Display, Accessibility, Controls. Every slider and toggle applies immediately, with a preview sound for volume and a live text-size sample for accessibility. Closing Settings keeps the values; the game does not ask "apply?".

Progress is invisible until it matters: a level card shows stars, the next level unlocks, and Continue remembers where the player was. On a fresh machine, the game starts a new profile without a dialog. If the save was damaged, a single notice explains that a new profile was started and that the old file was kept, and the game continues.

## Rules

**Settings model.**

- Settings are a typed model in `src/`, owned by the save manager; UI reads the model and emits intent, it never writes the save directly (`.dsh/rules/ui.md`).
- Every value has: key, type, default, min, max, step, and a label translation key. Values outside the range are clamped on load and on set, with a `push_warning` naming the key.
- Changes apply immediately and are persisted on a `save_debounce_seconds` debounce, and on every level completion and application quit.

| Group | Setting | Type | Default | Range | Effect |
|---|---|---|---|---|---|
| Audio | `master_volume` | float | 0.80 | 0.00 to 1.00 | master bus volume, linear slider mapped to dB |
| Audio | `music_volume` | float | 0.70 | 0.00 to 1.00 | music bus; no music ships in 1.0, bus reserved |
| Audio | `sfx_volume` | float | 0.90 | 0.00 to 1.00 | SFX bus |
| Display | `language` | enum | `auto` | `auto`, `en`, `zh` | UI locale; `auto` follows the OS |
| Display | `ui_scale` | float | 1.00 | 1.00 to 1.50 | UI multiplier, step 0.25 |
| Display | `camera_speed` | float | 1.00 | 0.50 to 2.00 | camera tween duration multiplier, inverted: 2.0 is twice as fast |
| Accessibility | `colorblind_mode` | enum | `off` | `off`, `deuteranopia`, `protanopia`, `tritanopia` | palette and shapes per [accessibility.md](accessibility.md) |
| Accessibility | `reduce_motion` | bool | false | false/true | all tweens and fades become instant |
| Accessibility | `unlimited_undo` | bool | false | false/true | ignores `undo_limit` from [core-rules.md](core-rules.md) |
| Accessibility | `show_warnings` | bool | true | false/true | deadlock chip on/off; off only hides the chip, never the rule |
| Controls | `keybinds` | dict | defaults | binds per [input-and-controls.md](input-and-controls.md) | per-action bindings, only non-defaults stored |
| Controls | `reset_bindings` | action | n/a | n/a | restores the default InputMap |

**Save file.**

- Path: `user://save/profile.json` (Godot `user://`, so Windows `%APPDATA%`, Linux `~/.local/share`, Web IndexedDB).
- One profile. There is no multi-slot support in 1.0.
- The file is UTF-8 JSON, snake_case keys, no comments, formatted with two-space indentation for diffability and support.
- The file is written atomically: serialize to `profile.json.tmp`, flush and close, rename the current `profile.json` to `profile.json.bak`, rename the temp to `profile.json`. A failure at any step leaves either the old file or the backup readable.
- Writes are debounced by `save_debounce_seconds` for settings, and immediate for level completion and quit.
- The file is validated on load: size under `save_max_bytes`, valid JSON, `save_version` an integer. Unknown keys are logged and preserved in memory, then written back, so a downgrade does not silently destroy data it did not understand.

**Schema v1.**

| Field | Type | Meaning |
|---|---|---|
| `save_version` | integer | 1 in 1.0; drives migration |
| `profile.created_utc` | string | ISO 8601 UTC profile creation time, informational |
| `profile.last_played_id` | string | last level id opened; drives Continue |
| `settings` | object | the settings table above |
| `progress.levels` | object | map of level id to the level record below |
| `progress.highest_unlocked` | string | highest unlocked level id, kept separately so a missing record cannot lock a player out |
| `progress.levels.<id>.completed` | bool | level completed at least once |
| `progress.levels.<id>.stars` | integer | 1 to 3, best rating |
| `progress.levels.<id>.best_moves` | integer | fewest moves in a completed run |
| `progress.levels.<id>.best_pushes` | integer | pushes in that best-moves run |
| `progress.levels.<id>.best_time_ms` | integer | fastest completed run, milliseconds |
| `progress.levels.<id>.attempts` | integer | number of restarts plus completions |
| `stats.total_moves` | integer | lifetime moves, informational |
| `stats.total_plays` | integer | lifetime level loads |
| `stats.total_undos` | integer | lifetime undos, informational |
| `unlocks.all_levels` | bool | set by the developer `--unlock-all` argument; never set by UI |

- A level record is only written for a level the player has touched; absent means never played.
- Records are merged, never replaced: a new result replaces `best_moves` only when better, and `stars` only when higher.
- Records for level ids the build does not have are kept in the file and ignored, so deleting or renaming a level does not destroy history.

**Versioning and migration.**

- `save_version` is independent of the application version. It changes only when the schema changes.
- Migration is a chain of pure functions `migrate_vN_to_v(N+1)`; a load runs from the file's version to the current one, each step tested with a fixture file.
- A file whose `save_version` is newer than the build's: not migrated, backed up to `profile.newer-<unix>.json`, a fresh profile starts, and Main Menu shows one notice. The game never downgrades data.
- A file that fails JSON parse, size, or required top-level checks: backed up to `profile.corrupt-<unix>.json`, a fresh profile starts, and Main Menu shows one notice naming the backup.
- A missing key inside a valid version is filled with its default and logged; a wrong type is treated as missing.
- If `profile.json` is missing but `profile.json.tmp` or `profile.json.bak` parses, the newest readable one is adopted and a warning is logged.

**Deletion and reset.**

- Settings offers "Reset all settings" (keeps progress) and, behind a confirm modal, "Delete profile" (erases the save file and starts fresh). Both are single-purpose buttons with Cancel focused.
- There is no import/export and no cloud sync in 1.0.

**Privacy.** The save stays on the player's machine; the game sends no telemetry, no identifiers and no play data anywhere, matching the anti-goals in [overview.md](overview.md).

**Web storage.** On Web the save lives in IndexedDB through `user://`. The game flushes after each write and warns once if a write fails because storage is unavailable (private browsing or a full quota). The save is per-origin and per-browser; there is no cross-device sync and the store page must not promise one.

## Numbers and tuning

_来源约定：issue #1、project.godot 或本页引用的既有页面已经固定的值为事实；其余数值是 proposal（提案），影响手感或发布门槛的 proposal 在 Open questions 中列出。_

| Value | Default | Range | Notes |
|---|---|---|---|
| `save_version_current` | 1 | 1 to 99 | integer schema version |
| `save_debounce_seconds` | 0.5 | 0.2 to 2.0 | seconds before a settings change is written |
| `save_max_bytes` | 65536 | 16384 to 1048576 | bytes; larger files are treated as corrupt |
| `save_backup_count` | 2 | 1 to 3 | `profile.json.bak` plus `profile.json.tmp` during writes |
| `profile_count` | 1 | 1 to 1 | one profile in 1.0 |
| `master_volume_default` | 0.80 | 0.00 to 1.00 | linear slider, converted with `linear_to_db` |
| `music_volume_default` | 0.70 | 0.00 to 1.00 | bus reserved for future music |
| `sfx_volume_default` | 0.90 | 0.00 to 1.00 | SFX bus |
| `camera_speed_default` | 1.00 | 0.50 to 2.00 | tween duration multiplier, inverted |
| `ui_scale_default` | 1.00 | 1.00 to 1.50 | step 0.25 |
| `settings_tab_count` | 4 | 4 to 4 | Audio, Display, Accessibility, Controls |
| `record_total_stats_max` | 2147483647 | n/a | integer overflow guard for lifetime counters |

## Edge cases

- **The process is killed during a write.** Either `profile.json` or `profile.json.bak` parses on next launch; the readable one wins, a warning is logged, and no record is double-applied.
- **The disk is full.** The write fails, a one-line toast says progress could not be saved, the game keeps running, and the next write retries. No modal, no crash.
- **The save references a level id that no longer exists.** The record is ignored for UI but retained in the file and written back.
- **A newer build wrote the save.** The file is backed up, a fresh profile starts, and the notice says the old file was kept.
- **A hand-edited save sets `stars` to 4.** Clamped to 3 with a warning; `best_moves` is clamped to a positive integer.
- **The player switches language while a level is paused.** Strings update at the next screen redraw; the room, timer and counters are untouched.
- **The player remaps a key that a menu needs.** Navigation keys are not remappable, per [input-and-controls.md](input-and-controls.md); the remap screen refuses reserved inputs.
- **Storage is unavailable on Web.** The game plays normally, the settings and progress live only for the session, and one warning explains why.
- **Two instances of the game run at once.** Last writer wins; there is no file lock in 1.0, and this is acceptable for a single-player offline game.
- **The system clock changes.** Play time uses the engine clock, not wall time; only `created_utc` uses the wall clock and it is informational.

## Open questions

1. **Mid-level save (producer / technical director, proposal).** The schema stores no in-progress board. Decision needed: whether 1.0 restores an interrupted level, which adds a `session` object and a board snapshot to the save.
2. **Music bus (creative director, proposal).** A music bus and volume slider ship with no music. Decision needed: either no music in 1.0 (recommended, matches the procedural-audio constraint) and the slider hidden, or a procedural ambient loop from [audio.md](audio.md).
3. **Multiple profiles (producer, proposal).** 1.0 ships one profile. Decision needed: whether a second local profile is in scope, which changes the path, the menu and the reset flow.
4. **Save location for the Web build (release manager, proposal).** IndexedDB is per-origin; moving the store URL loses saves. Decision needed: whether a stable origin plus a documented save-export path is required before shipping Web.
5. **Unknown-key preservation (technical director, proposal).** The plan preserves unknown keys on write. Decision needed: confirm, because preservation is what makes a downgrade non-destructive but it also means a corrupt extra key is written back.

## Links

- Related systems: [overview.md](overview.md), [core-rules.md](core-rules.md), [input-and-controls.md](input-and-controls.md), [ui-flow.md](ui-flow.md), [accessibility.md](accessibility.md), [audio.md](audio.md), [technical-architecture.md](technical-architecture.md), [release.md](release.md)
- Data rules: `.dsh/rules/data.md`
- Stories: `production/stories/` (none yet)
