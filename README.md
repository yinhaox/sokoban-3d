# Sokoban 3D

A quiet 3D Sokoban in a small room. Push every crate onto a plate, one careful
move at a time, with undo, unlimited retries and no timer against you.

- **20 hand-tuned levels** that teach by layout, not by text.
- **Isometric room** with a rotating camera and walls that fade out of the way.
- **Move, push, undo, restart** with animate feedback and a 1–3 star result.
- **Keyboard and gamepad**, rebindable, with a colour-blind palette and a
  reduced-motion mode.
- **English and Chinese**, switchable in the settings screen.
- **Progress saved** locally: best moves, pushes, time and stars per level.
- **Three platforms**: Windows, Linux and Web, from the same project.

Version 0.1.0.

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Move / push | Arrow keys or `WASD` | Left stick or D-pad |
| Undo | `Z` (hold `Ctrl` to repeat) | `Y` / `Back` |
| Restart level | `R` | `X` / `View` |
| Pause | `Esc` | `Start` |
| Rotate camera | `Q` / `E` | Shoulders |
| Zoom | Mouse wheel | Triggers |

All bindings are remappable from the settings screen.

## Play it

Download the build for your platform from the releases page and run it. The web
build serves from any static host; open `index.html` over HTTP (not `file://`).

## Build from source

Requires [Godot 4.7](https://godotengine.org/) (the project is verified on
4.7.2) and Python 3 for the studio helper.

```sh
godot --headless --path . --import      # first import
python scripts/studio.py test           # 800+ headless checks
python scripts/studio.py run            # play it
```

Exports use the presets in `export_presets.cfg`:

```sh
godot --headless --path . --export-release "Windows Desktop" build/windows/Sokoban3D.exe
godot --headless --path . --export-release "Linux" build/linux/Sokoban3D.x86_64
godot --headless --path . --export-release "Web" build/web/index.html
```

Export templates for 4.7.2 must be installed.

## Project layout

```
src/logic/      rules, level data, save, settings, localization: no nodes
src/game/       board building, camera, gameplay controller
src/ui/         menu, HUD, pause, victory, level select, settings
src/input/      runtime InputMap actions
scenes/         main router, 3D level view, UI scenes
assets/data/    levels and translations
tests/          headless rule and UI checks (tests/run_tests.gd)
design/         the design set this build implements
production/qa/  evidence captured from real runs
scripts/        studio.py helper (check, test, run, capture)
```

## How this game was built

This repository was developed by an agent studio on GitHub: issues became
tickets, each ticket ran in an isolated worktree, and each pull request carried
its own test log and a screenshot captured from a real run. The studio kit is
[dsh-game-studio](https://github.com/yinhaox/dsh-game-studio).

## License

Code and content are MIT; the engine is MIT. See [LICENSES.md](LICENSES.md).
