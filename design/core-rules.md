# Design: core rules

_The grid, the push, the deadlock warning, the win condition and the undo/restart contract. Owned by the game designer; every other page reads these numbers instead of restating them._

## Goals

Pillar P2 (one push at a time). This page must give the player a turn-based puzzle whose every outcome is explainable in one sentence, and give the programmer a rule set that is fully testable without a window.

- One accepted input produces exactly one observable state change: the player steps, or a box slides one tile, or nothing happens and the player sees why.
- The player never loses to time, reflexes, or hidden information. The only failure state is "stuck", and the game tells them before they waste a minute.
- Undo and restart are always one input away, so a mistake costs seconds rather than a level.

The page lands when `tests/run_tests.gd` can assert: a push into a wall is rejected with unchanged counters, a push of a box into a box is rejected, a corner box raises the deadlock flag, the last goal completes the level, and undo restores counters and positions exactly.

## Player experience

The player sees an isometric room. They press a direction. If the way is clear, the player marker steps one tile with a short ease. If a crate is in front and the cell behind it is free, the crate slides one tile and the player follows, with a heavier step. If either the player's cell or the crate's destination is blocked, the marker nudges and returns, the screen does not shake, and a dull bump plays.

The crate entering a goal plate is felt, not read: the plate lights, the crate settles half a centimetre, a click plays. A crate pushed into a corner away from every goal lights nothing and a soft warning chip appears over the HUD: the puzzle can no longer be finished from here. One press of Undo rewinds the last push and the warning disappears.

The loop is: read the room, plan two or three pushes, execute them, feel the crate land. The undo key is used freely. Restart is used when the plan is wrong, not when the fingers were.

## Rules

**Grid and entities.**

- A level is a rectangular grid of `columns` × `rows` cells, each 1.0 m square in world space, with `5 <= columns <= 15` and `5 <= rows <= 15`.
- Each cell is exactly one of: wall, floor, goal (a floor cell with a goal plate), or void. Void is not used by the 1.0 level set; the outer border is always wall.
- A level contains exactly one player marker and between 1 and 8 boxes. A cell holds at most one box; the player never occupies a cell that holds a box.
- A goal cell holds a box or is empty; an empty goal is a visible plate. A box on a goal is still a normal box and can be pushed off again.

**Movement.**

- Input is the four orthogonal directions only. Diagonals do not exist.
- A move request resolves in this order and stops at the first matching case:
  1. The target cell is a wall or outside the grid: the move is rejected. No counter changes, no history entry, the bump animation and the bump sound play. The player marker stays where it was.
  2. The target cell is floor, goal, or floor with no box: the player steps one tile. `moves += 1`, `pushes` unchanged, history grows by one entry.
  3. The target cell holds a box and the cell beyond it (in the same direction) is floor or an empty goal: the box and the player each move one tile. `moves += 1`, `pushes += 1`, history grows by one entry.
  4. The target cell holds a box and the cell beyond it is a wall, outside the grid, or another box: the move is rejected exactly as case 1.
- The player cannot pull a box, and a box cannot push another box.
- Accepted moves are strictly one at a time. While a move tween is running, input is buffered up to 2 moves; any further input is dropped. The buffered moves are consumed in order.
- The player facing is the direction of the last accepted move; it drives presentation only and never affects rules.

**Undo.**

- Every accepted move appends a history entry containing the move direction, whether it was a push, which box moved, and the counters before the move.
- Undo restores the player position, every box position, `moves` and `pushes` to the values before the last accepted move, and removes that entry. Undo of a rejected move does nothing.
- Undo is capped by `undo_limit` accepted moves. At the cap, the oldest entries are discarded so the player can rewind at most `undo_limit` moves. The cap does not count rejected moves. The valid range is 1 to 100; the default equals `GameSession.DEFAULT_UNDO_LIMIT` (100).
- Undo never lowers a best record, never lowers a star rating, and never unlocks a level.
- Undo while a move tween is running cancels the tween and lands directly on the pre-move state.

**Restart.**

- Restart restores the level's initial cells, empties the undo history, sets `moves = 0`, `pushes = 0`, `elapsed = 0`, and increments `attempts`.
- When `moves > 0` and the level is not complete, restart from the pause menu or a bound key asks for confirmation with Cancel pre-selected. At `moves == 0`, restart happens immediately.
- Restart never clears stars, best records, or unlock state.

**Deadlock warning.**

- After every accepted push, the pushed box is checked: it is deadlocked when it is not on a goal, at least one of its two horizontal neighbours is a wall, and at least one of its two vertical neighbours is a wall. Example: a wall to the left and a wall above the box; a wall to the right and a wall below is the same condition.
- The check uses static walls only; boxes are not walls for this check in 1.0.
- Deadlock is a warning, never a failure. The level stays playable, a non-blocking chip appears for `deadlock_chip_seconds`, and the chip offers Undo and Restart.
- The chip re-appears on each new deadlocked push; it is dismissed by Undo, Restart, or the timeout.

**Win.**

- After every accepted push, if every goal cell holds a box, the level is complete. (Pushes are the only moves that can complete a level; the check runs on pushes only.)
- On completion: input stops being forwarded to the game, the timer stops, the player's best moves/pushes/time are updated if better, the star rating is raised if better, the next level is unlocked, and the victory panel appears after `win_delay_seconds`.
- Star rating: 3 stars when `moves <= par_moves`; 2 stars when `moves <= ceil(par_moves * star_2_multiplier)`; otherwise 1 star. Best rating is monotonic; it never drops.
- `par_moves` and `par_pushes` come from the level JSON; they are never computed at runtime.

**Timer.**

- The timer starts on the first accepted move of the attempt, pauses while the pause menu is open, resumes on close, and stops on completion.
- Elapsed time is stored and displayed with `timer_precision_ms` = 100 ms precision; stored as integer milliseconds.
- Time is never a fail condition and never affects stars.

**State machine.**

`loading -> ready -> playing -> paused -> playing`, `playing -> won -> (level select | next level)`. `ready` exists so a level can be shown at `moves == 0` before the first input. Any screen other than `playing` (except `ready`) stops input forwarding and the timer.

## Numbers and tuning

_来源约定：issue #1、project.godot 或本页引用的既有页面已经固定的值为事实；其余数值是 proposal（提案），影响手感或发布门槛的 proposal 在 Open questions 中列出。_

| Value | Default | Range | Notes |
|---|---|---|---|
| `tile_size_m` | 1.0 | 0.5 to 2.0 | world metres per grid cell; presentation only, must divide exactly |
| `min_columns` | 5 | 5 to 15 | cells; level validator rejects outside |
| `min_rows` | 5 | 5 to 15 | cells |
| `max_columns` | 15 | 5 to 15 | cells; camera fit is designed for this bound |
| `max_rows` | 15 | 5 to 15 | cells |
| `min_boxes` | 1 | 1 to 8 | boxes per level |
| `max_boxes` | 8 | 1 to 8 | boxes per level; the 20-level plan uses 6 at most |
| `move_seconds` | 0.13 | 0.08 to 0.20 | seconds for one player step |
| `push_seconds` | 0.16 | 0.10 to 0.24 | seconds for one crate slide plus player follow |
| `input_buffer_moves` | 2 | 0 to 4 | moves buffered while a tween runs |
| `undo_limit` | 100 | 1 to 100 | accepted moves reachable by undo; equals `GameSession.DEFAULT_UNDO_LIMIT` |
| `unlimited_undo` | false | false to true | accessibility setting that ignores `undo_limit`; proposal |
| `timer_precision_ms` | 100 | 100 to 100 | stored integer milliseconds |
| `win_delay_seconds` | 0.4 | 0.0 to 1.0 | seconds between last push landing and victory panel |
| `deadlock_chip_seconds` | 3.0 | 1.0 to 6.0 | seconds the warning chip stays |
| `star_2_multiplier` | 1.25 | 1.10 to 1.50 | multiplier on `par_moves` for the 2-star bound |
| `bump_seconds` | 0.06 | 0.04 to 0.12 | seconds of the rejected-move nudge |

All values are tuned in `assets/data/` (levels) or `resources/` settings data, never as inline GDScript constants, per `.dsh/rules/gdscript.md`.

## Edge cases

- **Two moves arrive in the same frame.** They queue in input order; the second is consumed only after the first tween ends. Three or more are clipped to `input_buffer_moves`.
- **Undo pressed with an empty history.** Nothing changes, the undo button appears disabled, no sound plays.
- **Undo pressed during the win delay.** Input to the game is already closed; the victory panel wins and undo does nothing.
- **Restart pressed during a crate tween.** The tween is cancelled, the level is restored to its initial cells, and no partial box position is kept.
- **Pause opened during a tween.** The tween is allowed to finish while the timer is already stopped; no input is consumed until resume.
- **A level starts already solved** (every goal covered). The loader rejects it as invalid, because the level could never be observed as a puzzle.
- **A box is pushed onto the last empty goal but another goal is empty.** Not a win; the win check counts all goals.
- **The timer passes 99 hours.** Display clamps at `99:59:59.9`; stored milliseconds keep counting.
- **A deadlock warning is showing and the player completes the level.** The chip is dismissed by the victory panel; the completion is not blocked.
- **Save/quit during play.** The level is not persisted mid-play; quitting returns to the level select and the attempt is lost. This is deliberate and stated in [settings-and-save.md](settings-and-save.md).

## Open questions

1. **Unlimited undo toggle (game designer, proposal).** The cap is 100 accepted moves by default, and `unlimited_undo` ignores it. Decision needed: whether the toggle ships in 1.0, since P2 promises undo is unlimited in effect.
2. **Line deadlock detection (game designer, proposal).** 1.0 detects only corner deadlock. Decision needed: add "box against a wall with no goal on that wall" detection now or leave it to a post-1.0 tuning pass.
3. **Mid-level save (producer / game designer, proposal).** Currently quitting mid-level loses the attempt. Decision needed: whether 1.0 restores an in-progress level on relaunch, which changes the save schema in [settings-and-save.md](settings-and-save.md).
4. **Par authority (game designer, proposal).** Par values in the 20-level plan are hand estimates. Decision needed: whether a solver pass must confirm each `par_moves` before the level is considered shippable.

## Links

- Related systems: [overview.md](overview.md), [level-format.md](level-format.md), [input-and-controls.md](input-and-controls.md), [level-progression.md](level-progression.md), [camera-and-presentation.md](camera-and-presentation.md)
- Stories: `production/stories/` (none yet)
- Evidence: `production/qa/evidence/<story-slug>/index.md` once a story implements a rule here
