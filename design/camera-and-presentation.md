# Design: camera and presentation

_How the 3D room is framed, lit and made legible, using only procedural geometry and materials. Owned by the technical artist._

## Goals

Pillar P1 (readable at a glance). The camera exists to make a turn-based puzzle readable in 3D; it is never a skill test and never hides a cell the player must reason about.

- Every cell of a 15x15 level is visible or can be made visible with one input, at the default angle, without zooming.
- Walls between the camera and the player or a crate fade, so the player never guesses what is behind a wall.
- The whole look is built from primitive meshes and flat materials generated at runtime, with no texture, model or font asset from outside the repository.

The page lands when a capture of level 1 and a capture of a 15x15 level both show the full room with the player and every crate visible, and rotating the camera never produces a cell that cannot be reached visually.

## Player experience

The room sits calm and centred in a dark background, seen from above at an isometric angle. The floor is warm sand, the walls slate blue, the crates wood, the goal plates teal. The player marker is a small red pawn. Nothing moves when the player does not move: no camera bob, no idle drift, no screen shake.

When the player walks behind a wall, the wall fades to a ghost within a tenth of a second and fades back when they step out. Pressing `Q` or `E` turns the room a quarter turn; the camera never free-orbits, so the player cannot get lost in a bad angle. Zoom is available but optional.

Each input has a small, deliberate weight: a step is a short glide, a crate is heavier, a crate landing on a plate settles and the plate lights teal. These are the only animations in the room. With reduced motion on, every one of them becomes instant.

## Rules

**Camera rig.**

- One `Camera3D` in orthogonal projection, attached to a rig node that orbits the level centre. There is no first-person, no free orbit and no collision camera.
- Default yaw is 45 degrees, pitch is 40 degrees below the horizon, and the rotation axis is vertical through the level centre.
- Rotation snaps between four quarter-turn states (0, 90, 180, 270 degrees relative to the default yaw). A rotation tween runs `camera_rotate_seconds` and cannot be interrupted by another rotation; input during the tween queues at most one further quarter turn.
- The camera centre is the centroid of the level's occupied cells, in world space.
- Projection size is fitted so the level's occupied bounds fill `camera_fill_ratio` of the shorter viewport axis, then clamped to `camera_size_min`..`camera_size_max` world units.
- Zoom is a multiplier on the fitted size: `camera_zoom_min`..`camera_zoom_max`, steps of `camera_zoom_step`, tweened over `camera_zoom_seconds`. Zoom resets to 1.0 at level start and on camera rotation.
- The rig never moves the camera below the floor plane; pitch is fixed and not player-adjustable in 1.0.

**Occlusion fade.**

- After every accepted move, every wall whose world-space footprint projects between the camera and the player's cell or any crate's cell fades out.
- A faded wall renders at `occlusion_alpha` and does not cast a shadow while faded. It restores to opaque over `occlusion_seconds` when it no longer occludes.
- Occlusion is recomputed on move, camera rotation, zoom and level load; it is not polled every frame.
- Occlusion never hides the floor a crate stands on: the floor slab of the player's and crates' cells is always opaque.
- The fade uses a second transparent material variant of the wall material, so a faded wall cannot shadow the room.

**Geometry and materials.**

- All meshes are Godot primitives (`BoxMesh`, `CylinderMesh`, `SphereMesh`, `CapsuleMesh`) or generated arrays. No imported mesh, texture, skybox or font file is used for the room.
- Materials are `StandardMaterial3D` with flat `albedo_color`, `roughness` 0.9, `metallic` 0.0, no albedo texture, no normal map. Goal plates use a flat emissive colour, not a light source.
- Tile size is 1.0 world unit, floor slab thickness `floor_thickness`, wall height `wall_height`. Crates are `crate_size` cubes; the player marker is a capsule of `player_radius` and `player_height`.
- Boxes carry a procedural shape marker (a raised cross on the top face) and goal plates carry a ring, so box and goal are distinguishable without colour; this is the shape contract in [accessibility.md](accessibility.md).
- No decal, no textured quad, no environment map. The background is a solid `background_color` clear colour.

**Lighting.**

- Exactly one `DirectionalLight3D` with shadow enabled, plus ambient light from the `Environment`. No real-time GI, no SSAO, no SSR, no volumetric fog, no glow; these are either unavailable or too costly in GL Compatibility.
- Shadow map size is 2048 on desktop and 1024 on Web. Directional shadow distance covers the whole level, `shadow_max_distance`.
- If shadows are disabled by the Web/low preset, a flat darkening quad under each crate and the player replaces them (blob shadow), because contact is needed to read height.

**Motion.**

- Tile tweens, camera tweens and material fades all come from the `scene/animation` settings data, not inline constants.
- No idle animation, no camera shake, no victory camera orbit; the victory panel is UI over the unchanged room.
- `reduce_motion` in [accessibility.md](accessibility.md) sets every tween duration to 0.0 and makes fades instant.

**Palette.** The palette is data in `resources/palette.tres` and is the single source for mesh colours; accessibility palettes swap entries, they do not repaint nodes.

| Role | Default hex | Notes |
|---|---|---|
| `background` | `#10131A` | clear colour |
| `floor` | `#C9B79C` | sand |
| `wall_side` | `#6B7A8F` | slate |
| `wall_top` | `#55637A` | darker top face reads height |
| `crate` | `#C98A4B` | wood |
| `crate_on_goal` | `#E0A960` | lighter, plus ring |
| `goal_empty` | `#3F7F6E` | teal plate, no emission |
| `goal_filled` | `#7FD1A8` | emissive 0.4 |
| `player` | `#E2574C` | distinct hue and shape |
| `focus` | `#FFD166` | UI focus only, never gameplay |

## Numbers and tuning

_来源约定：issue #1、project.godot 或本页引用的既有页面已经固定的值为事实；其余数值是 proposal（提案），影响手感或发布门槛的 proposal 在 Open questions 中列出。_

| Value | Default | Range | Notes |
|---|---|---|---|
| `tile_size_m` | 1.0 | 0.5 to 2.0 | world metres per cell, from [core-rules.md](core-rules.md) |
| `camera_yaw_degrees` | 45 | 30 to 60 | degrees; four snap states at +90 each |
| `camera_pitch_degrees` | 40 | 30 to 55 | degrees below the horizon |
| `camera_size_min` | 6.0 | 4.0 to 10.0 | orthographic size, world units |
| `camera_size_max` | 18.0 | 12.0 to 24.0 | orthographic size, world units; covers 15x15 |
| `camera_fill_ratio` | 0.80 | 0.65 to 0.90 | ratio of the shorter viewport axis the level fills |
| `camera_zoom_min` | 0.60 | 0.40 to 0.80 | multiplier of fitted size |
| `camera_zoom_max` | 1.80 | 1.20 to 2.50 | multiplier of fitted size |
| `camera_zoom_step` | 0.10 | 0.05 to 0.25 | multiplier change per input |
| `camera_rotate_seconds` | 0.28 | 0.15 to 0.40 | seconds per quarter turn |
| `camera_zoom_seconds` | 0.15 | 0.08 to 0.30 | seconds per zoom step |
| `occlusion_alpha` | 0.12 | 0.05 to 0.25 | 0..1 alpha of a faded wall |
| `occlusion_seconds` | 0.12 | 0.05 to 0.25 | seconds for fade in and out |
| `wall_height_m` | 1.0 | 0.6 to 1.5 | world metres |
| `floor_thickness_m` | 0.10 | 0.05 to 0.20 | world metres |
| `crate_size_m` | 0.84 | 0.70 to 0.92 | world metres; must stay below `tile_size_m` |
| `player_radius_m` | 0.28 | 0.20 to 0.40 | world metres |
| `player_height_m` | 0.55 | 0.35 to 0.75 | world metres |
| `shadow_map_size_px` | 2048 | 1024 to 4096 | pixels, desktop; 1024 on Web |
| `shadow_max_distance` | 30 | 10 to 60 | world units |
| `directional_light_energy` | 1.0 | 0.6 to 1.4 | light energy |
| `ambient_light_energy` | 0.35 | 0.15 to 0.60 | ambient light ratio |

## Edge cases

- **A 15x15 level at the default angle.** Fitted size clamps at `camera_size_max`; the room still fills the view and no occupied cell falls off screen.
- **A rotation is requested during a rotation tween.** One extra quarter turn is queued and runs after the current tween; a third request is dropped.
- **The player stands behind a wall in all four rotations.** The fade works on the wall currently between camera and player, so the player is always visible; if two walls occlude, both fade.
- **Zoom is changed while a crate tween runs.** Camera zoom never affects logic timing; the two tweens are independent.
- **The window is resized.** The projection is refitted on the next frame using the new viewport aspect; the UI rescales by its own rules in [ui-flow.md](ui-flow.md).
- **Reduced motion is on.** Rotation, zoom and occlusion fades are instant; there is no queued rotation tween because there is no tween.
- **The Web build cannot afford shadows.** The low preset disables the directional shadow and enables blob shadows; the room must remain readable, and that preset is part of the release checklist in [release.md](release.md).
- **A custom accessibility palette is active.** Mesh materials read the swapped palette entries; goal plates keep the ring and crates keep the cross, so shape still carries the meaning.
- **The camera pitch is lowered below 30 degrees.** Forbidden: walls would hide cells behind them and pillar P1 would fail.

## Open questions

1. **Orthographic versus perspective (technical artist, proposal).** The plan is orthogonal projection for a clean isometric read. Decision needed: confirm, because WebGL2 handles ortho differently on some drivers and perspective can look warmer.
2. **Wall fade versus wall cutaway (technical artist, proposal).** Fading to 12% alpha is the plan. Decision needed: whether a dithered dissolve or a height-cutaway reads better and avoids transparent-sorting artifacts, which would change the material rules above.
3. **Palette ownership (creative director / technical artist, proposal).** The warm-sand/slate/wood palette is a proposal; it must be approved as the game's look before release-prep writes the store art, since no external art may replace it.
4. **Shadow cost on integrated GPUs and Web (technical director, proposal).** 2048 desktop shadows plus one directional light is the budget. Decision needed: whether low-end hardware must ship the blob-shadow preset by default, which would make two visual presets a 1.0 requirement.
5. **Grid lines and coordinate aids (technical artist, proposal).** The plan draws no grid lines; cell edges are read from slab gaps. Decision needed: whether an optional "show grid" toggle belongs in accessibility instead.

## Links

- Related systems: [overview.md](overview.md), [core-rules.md](core-rules.md), [level-format.md](level-format.md), [accessibility.md](accessibility.md), [technical-architecture.md](technical-architecture.md), [release.md](release.md)
- Stories: `production/stories/` (none yet)
- Evidence: `production/qa/evidence/<story-slug>/index.md` with captures from `python scripts/studio.py capture`
