# Reproduction: faded walls read as hollow boxes with noisy seams (issue #30)

## Inputs

- Level: `assets/data/levels/level-010.json` (10x8, three crates, three goals,
  interior wall pillars at (3,4), (5,4) and (7,4)).
- Camera: default boot view, yaw 45 degrees, pitch 40 degrees, window 1152x648.
- Commands, run from the project root:
  - `python scripts/studio.py capture --out production/qa/evidence/fix-wall-artifacts-aac3cd51a4a3/before-level-010-default.png -- --level=level-010`
  - `$env:STUDIO_CAPTURE_QUARTER_TURNS='1'; python scripts/studio.py capture --out .../before-level-010-quarter-turn-1.png -- --level=level-010`
  - `python scripts/studio.py capture --out .../before-level-014.png -- --level=level-014`
- The before run used the unmodified branch head, `origin/main` commit `0ed346c`,
  checked out in a detached worktree so the failing capture and the fixed capture
  come from the same project on this machine.

## Expected, from issue #30

- A faded wall or pillar keeps its top face (low alpha, a lighter tone), so no
  dark cavity shows through it; the sides only need a very faint outline.
- A continuous wall segment draws no line between its own 1x1 cells; only the
  segment's outer boundary and top-face edge are drawn, and the top contour is
  lighter than the side stroke.
- Opaque walls stay solid; no part of a faded wall is above 25% opacity.
- The floor grid stays, but no grid line is drawn under a wall or a crate.
- The result also holds in colour-blind mode.

## Actual on the unmodified code

- `before-level-010-default.png` (1152x648, 79,244 B): the three interior pillars
  are transparent boxes whose top cap is `wall_top_color` `#55637A` at 0.70 alpha,
  so the top face reads as a dark hole; each wall cell also draws one top border
  and four vertical edge strips (8 opaque outline boxes), which shows as a line at
  every 1x1 boundary of the faded border wall.
- `before-level-010-quarter-turn-1.png` (70,917 B): the same artifacts after one
  quarter turn.
- `before-level-014.png` (74,401 B): the long interior wall has the same per-cell
  seams.

## Reduction

- One wall cell carries one cap and 8 outline boxes; the outline count grows by 8
  per wall cell, so the seam density is a property of the per-cell outline, not of
  the level.
- The fade math is `max(alpha, 0.70)`, so the faded cap is 0.70 while the sides are
  0.22 — the cap is darker and far more opaque than the sides, which is the
  "black hole".
- `tests/run_tests.gd` encodes the acceptance: a flagged-wall cap alpha of at most
  0.25, a full-cell top face per wall, fewer merged outline lines than wall cells,
  and a grid that only sits on empty floor. On the unmodified code those checks
  fail (`regression-before.log`), and they pass after the fix (`regression-after.log`).
