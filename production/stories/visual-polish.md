---
id: visual-polish
status: done
updated: 2026-11-03
---

# Story: Visual polish: faded walls, floor grid and contact shadows

## Context

Issue #26 asks for one visual-polish pass so the room reads like a finished product
without changing gameplay, level content, UI layout, audio or export. The look is
defined by `design/camera-and-presentation.md` (primitive geometry, flat materials,
occlusion fade, one directional light) and `design/accessibility.md` (shape carries
meaning, reduced motion removes decorative motion). The room currently fades walls
to a glassy translucent block, has no floor grid, relies on the directional shadow
alone for contact, and leaves the floor edge open under the faded border walls.

## Acceptance

- [x] A faded wall no longer reads as a translucent glass block: its top outline and
      edges stay crisp while the body is ghosted, and a wall cell reads as a wall from
      every quarter turn.
- [x] The floor carries one very faint grid line per cell edge, with a value step of at
      most 8% from the floor tone, so cells are readable without stealing the frame.
      The grid is hidden while the `reduce_motion` setting is on.
- [x] Crates, goal plates and the player cast a soft contact shadow on the floor, and
      an empty goal plate stays clearly visible without its emission.
- [x] The floor edge under the border walls no longer shows a black void: a dark
      0.05-unit base extends around the room.
- [x] Colour-blind mode keeps crate, goal and player distinguishable by shape, shown
      by a comparison screenshot.
- [x] `tests/run_tests.gd` asserts the fade alpha and the outline toggle, the grid
      material parameters, and the contact shadow nodes, all passing headless.
- [x] Screenshots of level 10 (three crates) at the default view, after a quarter turn,
      and in colour-blind mode each make wall, crate and goal readable at a glance,
      with `Run result: OBSERVED — …`.
- [x] `check_command` and `test_command` pass.

## Out of scope

- Gameplay rules, level data, UI layout, audio and export.
- Code outside `src/game/`, `src/ui/ui_theme.gd` (only if a material parameter is
  needed), `tests/run_tests.gd` and the evidence directory.

## Evidence

- `production/qa/evidence/visual-polish/index.md` — `Run result: OBSERVED — at 1152x648 the level-10 room … reads as a finished diorama`; `level-010-default.png`, `level-010-quarter-turn-1.png`, `level-010-quarter-turn-2.png`, `level-010-quarter-turn-3.png`, `level-010-colorblind.png`, `level-010-reduce-motion.png` and `run-window.png` show the room, and `check.log` / `test.log` record the passing commands.

## Notes

- The wall finish is a top border of four bars plus four vertical edge strips per wall, in a darker slate (`wall_outline_color`). They are not part of the fade tween, so they stay opaque while the wall body ghosts; `set_wall_outlines_enabled()` hides the whole group and is covered by the tests. The faded top cap alpha moved from 0.55 to 0.70 so the top face still reads as a wall.
- The floor grid is `floor_color.darkened(0.07)` — a 7% value step, inside the story's 8% cap — built once as thin boxes on shared floor-cell edges and shared across the board. `set_reduce_motion()` keeps it in step with the existing accessibility setting; `CameraRig.reduce_motion` now forwards its value to the board so a settings change hides the grid without editing `src/main.gd`, which the issue's out-of-scope list excludes.
- Contact shadows are three concentric transparent discs (widest and faintest first) parented to each crate, goal plate and the player, so they follow a move, undo and restart. The goal plate also keeps its bright ring, so an empty plate stays visible without emission.
- The room base is a 0.05-unit dark box whose top sits 0.001 below the floor plane; it fills the void under the faded border walls without z-fighting the floor slabs. `room_bounds()` now includes the base margin and underside so the camera frames it.
- Issue #26 asks for a "rotated 45°" shot. The camera rig has exactly four 90° snap states and no free yaw (`design/camera-and-presentation.md` "Camera rig"), so the evidence uses all three quarter turns (yaw 135°, 225°, 315°) instead of inventing a 45° state.
