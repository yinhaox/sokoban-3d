# Design: technical architecture

_How the game is split so rules can be tested without a window, what each autoload owns, and the frame budget a GL Compatibility build must stay inside. Owned by the technical director._

## Goals

Pillars P2 (one push at a time) and P4 (playable by everyone). The architecture has one job that pays for itself: the entire puzzle must run and be tested headless, because that is how every rule in [core-rules.md](core-rules.md) is verified before a screenshot is taken.

- Pure logic in `src/logic/` with no `Node`, `SceneTree`, `Input` or rendering dependency; every rule is callable from `tests/run_tests.gd` with no window.
- Rendering, input mapping, audio and UI are replaceable shells around that logic, each with one owner and one signal contract.
- The project stays inside the pinned budget: Godot 4.7, GL Compatibility, 60 fps at 1152x648, one main scene, `res://scenes/main.tscn`.

The page lands when `python scripts/studio.py test` runs the rule suite headless with a green result, and a level loads, plays and saves at 60 fps with the budgets below.

## Player experience

The player never sees the architecture, only its consequences: a level appears in under a quarter of a second, a push resolves at the same speed on a five-year-old laptop as on a desktop, and a missing level or a damaged save is a one-line notice rather than a stuck screen.

For the team the consequence is that a rule change is proven by a test command before anyone opens the editor, and a look change is proven by a capture command. That keeps a small studio from debugging presentation and rules at the same time.

## Rules

**Layering.** Dependencies point one way: `src/logic` knows nothing; `src/game` reads logic and writes scenes; `scripts/ui` reads models and emits intent; autoloads own process-wide services. No layer reaches upward.

| Layer | Directory | May use | Must not use |
|---|---|---|---|
| Logic | `src/logic/` | GDScript, `RefCounted`, `Array`, `Dictionary`, `String` | `Node`, `SceneTree`, `Input`, `InputEvent`, `RenderingServer`, `AudioServer`, `FileAccess` writes, `get_tree()` |
| Game / rendering | `src/game/` | logic classes, scenes, `Node3D`, tween, `AudioStreamPlayer` | save-file IO directly, UI nodes |
| UI | `scripts/ui/` | models, signals, `Control`, theme | gameplay state mutation, scene instantiation of gameplay (`.dsh/rules/ui.md`) |
| Autoloads | `src/autoload/` | all of the above, one service each | gameplay simulation state |
| Tests | `tests/run_tests.gd` | `preload` of logic scripts and scenes | rendering, input devices, wall-clock waits |

**Logic layer (headless).** These classes carry every rule and are the only place a rule is implemented.

| Class | Responsibility | Evidence it is testable |
|---|---|---|
| `LevelData` | Parses one JSON level, validates it per [level-format.md](level-format.md), exposes cells, boxes, goals, par values | `from_dictionary()` is called with fixtures; no file IO |
| `LevelCatalog` | Loads a directory of level files, rejects duplicate or invalid ids, returns ordered metadata | loader takes an injected file map, so tests use dictionaries |
| `GameSession` | Player/box positions, move resolution, counters, history, deadlock check, win check, star result | `try_move(direction)` is a pure state transition returning a result enum |
| `Deadlock` | Corner-deadlock predicate over a grid and one box position | static function on arrays |
| `MoveRecord` | One undo entry and the counters before it | value object, compared in tests |
| `SaveSchema` | Serializes and validates the save dictionary, runs the migration chain | `to_dictionary()` / `from_dictionary()` fixtures, no file IO |
| `SettingsModel` | Typed settings values with defaults and clamping | plain class, no scene |
| `LevelRecord` | Best moves, pushes, time, stars, attempts for one level, with merge rules | merge is a pure function |

- Logic classes never call `push_error` for rule violations that the player caused; they return a typed result. `push_warning` is reserved for data errors.
- Logic never reads `Input`; a direction enum is passed in.
- Logic never formats player-facing strings; it returns ids and counts.

**Scene layer.** Nodes carry wiring only; all logic sits in the classes above.

| Scene | Root | Responsibility |
|---|---|---|
| `scenes/main.tscn` | `Main` | Boot, load save and catalogue, own the `ScreenRouter`; stays the project main scene from `project.godot` |
| `scenes/game/level_view.tscn` | `LevelView` (Node3D) | Build the room from `LevelData`, hold `Board`, `Actors`, `CameraRig`, forward input intents, play tweens and audio |
| `scenes/ui/main_menu.tscn` | `MainMenu` | Continue / New Game / Level Select / Settings / Credits / Quit |
| `scenes/ui/level_select.tscn` | `LevelSelect` | Level card grid, info panel, unlock and record display |
| `scenes/ui/hud.tscn` | `HUD` | Counters, timer, goal count, undo/restart/pause buttons, deadlock chip |
| `scenes/ui/pause_menu.tscn` | `PauseMenu` | Resume, Restart, Settings, Level Select, Main Menu |
| `scenes/ui/victory_panel.tscn` | `VictoryPanel` | Stars, records, Next Level / Retry / Level Select |
| `scenes/ui/settings_screen.tscn` | `SettingsScreen` | Audio, Display, Accessibility, Controls tabs |
| `scenes/ui/credits_screen.tscn` | `CreditsScreen` | Licence and credit list |
| `scenes/ui/confirm_modal.tscn` | `ConfirmModal` | One destructive question, Cancel focused |
| `scenes/ui/load_error_screen.tscn` | `LoadErrorScreen` | Empty, invalid-level and save-notice states |

- Root node names are PascalCase and match the file name (`.dsh/rules/scenes.md`).
- Screens communicate through the router and signals; a screen never reaches into another screen's nodes.
- One screen is instantiated at a time under the router; a screen is freed on leave, and tweens owned by it are killed with it.

**Autoloads.** The current pin is exactly one autoload, `StudioCapture`, used for evidence captures (`.dsh/rules/gdscript.md`, tech-director brief). This design proposes three more, and each one is a written decision the technical director must accept before a story registers it in `project.godot`:

| Autoload | Owns | Does not own |
|---|---|---|
| `StudioCapture` (existing) | `--studio-capture=<path>` screenshot and exit | anything in a normal run; stays registered in every build |
| `SaveManager` (proposal) | `user://save/profile.json` IO, atomic writes, backups, migration, the in-memory `SaveSchema` | gameplay state, UI |
| `AudioDirector` (proposal) | Bus layout, the `voice_count` player pool, throttles, SFX playback requests | decisions about when a cue is right; gameplay timing |
| `LocaleManager` (proposal) | Translation loading, `auto` locale resolution, language changes at runtime | layout; screens re-read strings on a `locale_changed` signal |
| `GameRouter` (proposal, alternative) | If screens need a shared navigation owner, the router may be an autoload instead of a node under `main.tscn` | level state |

- Autoload count must stay at or below `autoload_max_count` (5 with the four proposals) and every autoload must be free of gameplay simulation state, so `tests/run_tests.gd` can still run without a window.
- Autoload order is defined in `project.godot`: `StudioCapture`, `LocaleManager`, `SaveManager`, `AudioDirector`, `GameRouter`; no autoload may depend on another that loads after it.
- Adding an autoload is a change to `project.godot`, which a story may make only after the technical director's written decision names the responsibility above.

**Signal contracts.** These names are the public interface between layers; renaming one is a breaking change that updates every caller in the same change.

| Signal | Payload | Emitter | Consumers |
|---|---|---|---|
| `move_committed` | `direction: int`, `was_push: bool`, `box_index: int` | `GameSession` | `LevelView`, `HUD`, `AudioDirector` |
| `move_rejected` | `direction: int`, `reason: int` | `GameSession` | `LevelView` (bump), `AudioDirector` |
| `undo_performed` | `moves_left: int` | `GameSession` | `LevelView`, `HUD` |
| `deadlock_detected` | `box_cell: Vector2i` | `GameSession` | `HUD` chip, `LevelView` highlight, `AudioDirector` |
| `level_completed` | `stats: Dictionary` | `GameSession` | `VictoryPanel`, `SaveManager`, `AudioDirector` |
| `state_changed` | `state: int` | `GameSession` | `HUD`, `LevelView`, router |
| `settings_changed` | `key: String`, `value: Variant` | `SettingsModel` | `AudioDirector`, `LocaleManager`, `LevelView` |
| `locale_changed` | `locale: String` | `LocaleManager` | every visible screen |
| `intent` | `name: String`, `payload: Variant` | UI screens | router or `LevelView` |

- UI never calls a `GameSession` mutator directly; it emits an intent and the owner applies it (`.dsh/rules/ui.md`).
- A signal handler never mutates the emitter's state; it reacts and returns.

**Data, loading and localization.**

- Gameplay data comes from `assets/data/levels/*.json` through `LevelCatalog`; no level table is inlined in a script (`.dsh/rules/gdscript.md`).
- Tuning data that is not per level (move timing, camera values) lives in `resources/*.tres` or a settings data file, not in constants, per `.dsh/rules/gdscript.md`.
- Localization uses Godot CSV translation files in `assets/data/locale/strings.en.csv` and `strings.zh.csv`; every player-visible string is a key resolved with `tr()`, never a concatenated literal.
- One loader function per data type: `LevelCatalog.load()`, `LevelData.from_dictionary()`, `SaveSchema.from_dictionary()`, and no ad-hoc JSON parsing elsewhere.
- There is no threading and no async resource streaming in 1.0; a level is small enough to load synchronously inside the `level_load_budget_ms` budget.

**Performance budget.** Measured on the minimum hardware in the release checklist with the Godot Monitor panel, at 1152x648, GL Compatibility.

| Budget | Value | How it is measured |
|---|---|---|
| Frame time at 60 fps | <= 16.6 ms | Godot Monitor, frame time graph over a 60 s play of level 15 |
| Draw calls | <= 80 | Renderer monitor per level |
| Rendered triangles | <= 40000 | Renderer monitor per level |
| Nodes in a level scene | <= 300 | Scene tree count on level 15 |
| Autoloads | <= 5 | `project.godot` review |
| Level load | <= 250 ms | logged from level select selection to first drawn frame |
| Save write | <= 20 ms | logged around the atomic write |
| Process memory | <= 200 MB | OS process working set after 10 levels |
| Per-frame allocations | none in steady state | review: no array/string construction in `_process` |

- Shadows, materials and geometry stay inside the GL Compatibility feature set per [camera-and-presentation.md](camera-and-presentation.md); no post-processing effect is added without a decision, because each one is a draw call or a full-screen pass.
- `tests/run_tests.gd` stays headless and must not require a rendering server, an audio device or an input device.

**Errors and diagnostics.** `push_error` and `push_warning` are the only diagnostic output in committed code, no `print()` (`.dsh/rules/gdscript.md`). A failed level load, a failed save write or a missing translation is recoverable and reported in-game per [ui-flow.md](ui-flow.md), never with a crash dialog.

## Numbers and tuning

_来源约定：issue #1、project.godot 或本页引用的既有页面已经固定的值为事实；其余数值是 proposal（提案），影响手感或发布门槛的 proposal 在 Open questions 中列出。_

| Value | Default | Range | Notes |
|---|---|---|---|
| `target_fps` | 60 | 60 to 60 | frames per second at 1152x648 |
| `frame_budget_ms` | 16.6 | 16.6 to 16.6 | milliseconds per frame at target |
| `draw_call_budget` | 80 | 40 to 150 | draw calls per level |
| `triangle_budget` | 40000 | 10000 to 80000 | rendered triangles per level |
| `node_budget_per_level` | 300 | 150 to 600 | nodes in a level scene |
| `autoload_max_count` | 5 | 1 to 6 | includes `StudioCapture` |
| `level_load_budget_ms` | 250 | 100 to 500 | milliseconds to first drawn frame |
| `save_write_budget_ms` | 20 | 5 to 50 | milliseconds for the atomic write |
| `memory_budget_mb` | 200 | 100 to 400 | process working set |
| `level_scene_count` | 1 | 1 to 2 | one level scene reused for every level, not one per level |
| `screen_scene_count` | 10 | 6 to 14 | scenes under `scenes/ui/` |
| `logic_class_count` | 8 | 4 to 16 | classes in `src/logic/` |

## Edge cases

- **A level is selected while the previous level's exit tween runs.** The router frees the old `LevelView` (and its tweens) before instantiating the new one; no tween writes to a freed node.
- **A missing level directory.** `LevelCatalog` returns an empty list and a report; `LoadErrorScreen` shows the empty state; the main menu still works.
- **A save fails to write while a level completes.** The victory panel still shows; the record lives in memory for the session and the next write retries; a toast reports the failure.
- **Two autoloads would need each other.** The later one is not registered; the dependency is moved into a logic class or a signal, and the autoload list in this page is updated first.
- **A test needs a scene.** Only scene-level wiring may be tested by instantiation; rules are asserted through `GameSession` directly, so a headless run never needs a window.
- **`project.godot` needs a new input action or autoload.** The story that adds it records why, updates this page's table in the same change, and never changes the Godot version, renderer or main scene.
- **The frame budget is exceeded on a 15x15 level.** The first suspects are per-tile meshes and shadow map size; the fix is instancing or batching, not lowering the target fps.
- **A screen is opened twice.** The router refuses a second instance of the same screen and focuses the existing one; no duplicate modal can exist.
- **The StudioCapture autoload runs in a normal session.** It does nothing without `--studio-capture`; it never writes a file unless the argument is present.

## Open questions

1. **Three new autoloads (technical director, proposal).** `SaveManager`, `AudioDirector` and `LocaleManager`, plus an optional `GameRouter`. Decision needed: approve or reject each one, because the current written pin is "only StudioCapture until a decision says otherwise", and this page is that decision draft.
2. **Reference solver in tests (technical director, proposal).** Level validation plus a solver proves solvability and par. Decision needed: whether the solver ships as a test-only script and whether its runtime stays under the test command's timeout.
3. **CSV versus gettext localization (technical director, proposal).** Godot CSV translations are the plan. Decision needed: confirm, because gettext handles plural forms better but adds `.po` tooling the studio does not have.
4. **`StudioCapture` in shipping builds (technical director, proposal).** It stays registered everywhere so `capture_command` works on any build. Decision needed: whether release builds must strip it, which would change `tests/run_tests.gd` and the evidence workflow.
5. **Main scene as router (technical director, proposal).** `scenes/main.tscn` stays the boot and router scene, so `project.godot`'s main scene does not change. Decision needed: confirm, since the alternative is a dedicated `boot.tscn` and a `project.godot` edit.

## Links

- Related systems: [overview.md](overview.md), [level-format.md](level-format.md), [core-rules.md](core-rules.md), [settings-and-save.md](settings-and-save.md), [camera-and-presentation.md](camera-and-presentation.md), [audio.md](audio.md), [release.md](release.md)
- Rules: `.dsh/rules/gdscript.md`, `.dsh/rules/scenes.md`, `.dsh/rules/ui.md`, `.dsh/rules/data.md`
- Commands: `studio.yaml` (`check_command`, `test_command`, `run_command`, `capture_command`)
- Stories: `production/stories/` (none yet)
