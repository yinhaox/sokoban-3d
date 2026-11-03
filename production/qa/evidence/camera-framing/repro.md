# Reproduction: camera framing and wall fade (issue #9)

Build: branch `agent/fix-room-framing-a25174f04f11` at commit `0c81720` (the `main` head the
ticket branch started from), Godot 4.7.2, GL Compatibility, window 1152x648.
Scene: `res://scenes/main.tscn` with `assets/data/levels/level-001.json`.

## Steps

1. `python scripts/studio.py check` → `[check] import OK`, exit code 0.
2. `python scripts/studio.py capture --out production/qa/evidence/camera-framing/before.png` →
   `[capture] OK`, 38062 bytes, exit code 0.
3. `python scripts/studio.py run` → the game window opens on the same room; `Q`/`E` rotate a
   quarter turn, the wheel zooms.

Expected, from the issue's acceptance list: the whole floor and all four border walls are
visible, the room is centred with equal margins, the near-side walls are semi-transparent but
keep their outline, the goal plate sits inside the walls, and the lighting is soft.

Actual (`before.png`): the content box is x 216..935, y 36..554 in a 1152x648 viewport, so the
room sits 28 px above the viewport centre (top margin 36 px, bottom margin 93 px). The near
border walls fade to alpha 0.12 and are effectively invisible, so the room reads as open and the
goal plate at cell (5,1) looks like it lies outside the wall. The inner faces of the far walls
render at rgb(78,94,124) and the crate's contact shadow is a hard dark edge.

## Measured reduction

- **Framing.** `CameraRig.setup()` placed the camera `camera_distance` (20 units) up the pitch
  direction from the level centre and set the orthographic `size` from the room box, but never
  subtracted the projected bounds centre. With a 40 degree pitch and a 1 unit wall the room box
  projects asymmetrically: vertical span 7.13 units, projected centre 0.38 units above the view
  centre, which is 28 px at the fitted size 8.91. The room is horizontally centred because the
  box is symmetric about its own centre; only the vertical axis was off.
  Fix: `CameraRig.frame_room()` now also returns the camera position inside the rig that puts the
  projected bounds centre in the middle of the viewport, and `setup()`, rotation and the capture
  aid all use it.
- **Wall fade.** `BoardBuilder._fade_wall()` tweened the wall sides and the darker top cap to the
  same `occlusion_alpha` (0.12), so a faded border wall vanished instead of reading as a
  translucent wall; the low alpha is what made the room look open and the goal plate look outside.
  Fix: the sides keep `occlusion_alpha` (raised to 0.22, still inside the design page's 0.05..0.25
  range) and the cap never drops below `OCCLUSION_CAP_ALPHA` (0.55), so the border keeps its
  outline while the room stays readable through it.
- **Lighting.** `ambient_light_energy` 0.2 against `light_energy` 0.4 left the far walls' inner
  faces at rgb(78,94,124) and gave the crate a hard shadow edge (`shadow_blur` at its default 1.0).
  Fix: ambient 0.35, key 0.45, `shadow_blur` 2.0, `shadow_opacity` 0.8. The floor now renders at
  rgb(222,207,186) against walls at rgb(91,110,145) with no channel clipped, so the palette's
  sand/slate split survives.

## Regression coverage

`tests/run_tests.gd` gained `_test_camera_framing()` and `_test_wall_fade_outline()`. For 7x7,
9x7 and 15x15 rooms at yaw 45/135/225/315 they assert that the projected room is centred
(`centre.length() < 0.01`), that the full width and height fit the orthographic size, that every
room corner is in front of the camera, and that the room fills its fill ratio; the fade checks
assert that a faded wall keeps alpha, that its cap stays more opaque than its sides and never
drops below a visible outline, and that `BoardBuilder.room_bounds()` covers the outer wall faces
and the floor slab. `regression-before.log` shows these failing on the unfixed code.

## Reproducing the other three angles

`python scripts/studio.py capture --out …` takes no extra arguments, so the boot scene reads the
optional `STUDIO_CAPTURE_QUARTER_TURNS` environment variable (`0..3`, default unset → whatever
`Q`/`E` would reach from the default yaw) and applies that snap state through
`CameraRig.set_quarter_turns()` before the capture frame. `angle-capture.log` records the three
commands; the images are identical to what `Q`/`E` produce because the capture aid calls the same
snap state the keys do.
