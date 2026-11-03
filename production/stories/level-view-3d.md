---
id: level-view-3d
status: done
updated: 2026-11-03
---

# Story: Render level-001 as a 3D room with camera

## Context

The headless logic layer already parses `level-001` and resolves moves, but the game still boots into the 2D "Game Studio" placeholder. This story turns the visible game into the 3D room the design describes: `design/camera-and-presentation.md` for the isometric camera, occlusion fade, lighting and primitive-mesh look, `design/technical-architecture.md` for the `src/game/` scene layer and the `scenes/main.tscn` boot scene, and `design/level-format.md` for the level data the room is built from. Source: issue #6. Movement, pushing, undo, UI/HUD, menus, audio and save data belong to later stories.

## Acceptance

- [x] `scenes/main.tscn` boots straight into the 3D level view, loads `assets/data/levels/level-001.json`, and is no longer the 2D placeholder scene.
- [x] `src/game/board_builder.gd` generates floor, walls, crates, goal plates and the player piece from the grid; crates and goals are distinguishable by shape/height as well as colour.
- [x] The camera is an isometric orbit: `Q`/`E` rotate, the mouse wheel zooms within a lower and upper bound, and walls between the camera and the player fade out automatically.
- [x] The scene carries a `DirectionalLight3D` and a `WorldEnvironment`, with no rendering errors under GL Compatibility.
- [x] The player piece and crates sit at their `LevelData` cells (1 cell = 1 world unit) with no intersection and no Z-fighting.
- [x] `tests/run_tests.gd` gains at least 8 assertions covering grid-to-world conversion, camera angle limits and the wall-fade decision, all passing headless.
- [x] Screenshot evidence: `capture_command` writes a PNG in which the 7x7 room and its player, crate and goal are readable, with `Run result: OBSERVED — …`.
- [x] `check_command` and `test_command` both pass.

## Out of scope

- Movement, pushing, undo, UI/HUD, menus, audio and save data. This story only delivers the visible room.

## Evidence

- `production/qa/evidence/level-view-3d/index.md` — `Run result: OBSERVED — the 1152x648 window shows the 7x7 sand room ...`; `level-view-3d-1.png` and `run.png` show the room, `check.log` and `test.log` record the passing commands.

## Notes

- The occlusion pass also keeps goal plate cells visible (centre plus four inset corners), not only the player's and crates' cells named in `design/camera-and-presentation.md`. `level-001`'s goal sits one cell behind the near border wall, so without that the screenshot acceptance ("goal readable") cannot be met, while the design page's stated goal is that no cell the player must reason about is hidden.
- Lighting is `light_energy` 0.4 and `ambient_light_energy` 0.2 instead of the page's proposal 1.0 / 0.35: the proposed values wash the sand floor to near-white under GL Compatibility at 1152x648. The palette colours themselves are unchanged. The numbers table marks these values as proposals.
- The palette lives as exported colours on `BoardBuilder` instead of `resources/palette.tres`, because `resources/` is outside this story's write boundary; a later story can move it there without touching the geometry.
- The room is built directly in `scenes/main.tscn` because issue #6 asks the main scene itself to become the 3D view; `scenes/game/level_view.tscn` can be extracted when the screen router arrives.
