# Design: level progression

_The 20-level plan, the difficulty curve behind it, and the star and unlock rules that turn it into a session. Owned by the game designer._

## Goals

Pillar P3 (learn by doing). This page must give the studio a shippable 20-level campaign whose first five levels teach the rules without a tutorial wall, and whose last five still take a competent puzzle player a quarter of an hour.

- Every level in the plan has a size, a teaching purpose, a difficulty value and par values, so the producer can split it into stories without inventing content.
- The curve is visible as data: box count, board size and par grow in bands, not randomly.
- Stars give a replay reason after completion; completion, not stars, gates progress, so a stuck player is never locked out by perfectionism.

The page lands when 20 level files exist matching this table, all validate under [level-format.md](level-format.md), and the campaign's par values have been confirmed by the solver test.

## Player experience

Levels 1-5 are the teaching band, and each one teaches one idea by layout alone:

- Level 1 shows a crate, a plate and a straight push. Nothing else is in the room.
- Level 2 puts the plate around a corner, so the player must walk around the crate before the second push.
- Level 3 adds a second crate and a second plate, so the player meets ordering without being told.
- Level 4 offers a corner that looks like a shortcut; pushing into it deadlocks a crate and raises the warning chip. The level is recoverable with undo, and the chip is the lesson.
- Level 5 is a longer room where the shortest plan is still wrong, so restart becomes a tool rather than a punishment.

From level 6 the rooms stop being one-screen trivial: corridors force single-file pushes, plates sit behind crates that must first be parked aside, and later levels have several rooms joined by doors. Level 10 is the first with three crates. Level 15 is the first with four. Levels 19-20 use five and six and combine mechanics from earlier bands.

Beating a level unlocks the next. Stars show how close the player was to par; a 2-star run is one careless move away from 3, which is the reason to press Retry rather than Next.

## Rules

- The campaign ships exactly `level_count` = 20 levels, ids `level-001` to `level-020`, played in id order.
- Level `NNN` is unlocked when level `NNN-1` is completed; level 001 is always unlocked. Stars never gate anything.
- Each band below owns a size range, a box-count range, a difficulty range and a par range. A new level outside its band's range is out of the plan and the producer decides whether the band or the level changes.
- Par values are authored per level, then confirmed by the solver test described in [level-format.md](level-format.md); the table below is the proposal until that test exists.
- The teaching purpose of levels 1-5 is fixed: no level may move a level out of the tutorial band without the game designer's decision, because the campaign's no-text tutorial depends on the order.
- A level's display name comes from `name_key`; the names below are the English values for `name`.

**Campaign table.** Sizes are `columns` × `rows` in cells. Par is moves / pushes. Time is the target for a first successful solve, in seconds.

| # | Name | Size | Teaching purpose | Difficulty | Par moves | Par pushes | Target time |
|---|---|---|---|---|---|---|---|
| 1 | First Push | 7x7 | a straight push onto a plate; undo button exists | 1 | 6 | 3 | 60 |
| 2 | Turn the Corner | 8x7 | walk around the crate to push on the second axis | 1 | 14 | 6 | 90 |
| 3 | Two of a Kind | 9x7 | two crates, two plates, push order matters | 2 | 24 | 9 | 120 |
| 4 | Mind the Corner | 9x8 | a corner deadlocks a crate; warning chip, undo | 2 | 30 | 11 | 150 |
| 5 | Second Chances | 10x8 | the shortest plan fails; restart is a tool | 2 | 38 | 13 | 180 |
| 6 | Narrow Lane | 10x8 | single-file corridor, no second axis | 3 | 44 | 15 | 210 |
| 7 | Set It Aside | 10x9 | park a crate in a side pocket to pass it | 3 | 52 | 17 | 240 |
| 8 | Off the Plate | 10x9 | a crate starts on a plate and must move off it | 4 | 60 | 19 | 270 |
| 9 | Switchback | 11x9 | alternate push axes through an L-shaped room | 4 | 72 | 22 | 300 |
| 10 | Three's a Crowd | 11x9 | three crates, ordering across one corridor | 5 | 80 | 24 | 330 |
| 11 | The Gate | 11x10 | keep a door tile clear while routing a crate | 5 | 88 | 26 | 360 |
| 12 | Split Rooms | 12x10 | two rooms joined by one door; route both ways | 5 | 96 | 28 | 390 |
| 13 | Long Haul | 12x10 | long pushes with no room to turn around | 6 | 106 | 30 | 420 |
| 14 | Goal Line | 12x10 | plates along one wall; fill order decides | 6 | 116 | 32 | 450 |
| 15 | Crossroads | 13x11 | four crates whose paths cross | 7 | 130 | 36 | 480 |
| 16 | The Vault | 13x11 | an inner room with two doors; one is a trap | 7 | 142 | 38 | 510 |
| 17 | Chain Reaction | 13x11 | each crate must be finished before the next moves | 8 | 156 | 40 | 540 |
| 18 | Tight Squeeze | 14x11 | five crates in a tight block; order loss is total | 8 | 172 | 44 | 570 |
| 19 | The Labyrinth | 14x12 | multi-room maze, five crates, long routes | 9 | 196 | 48 | 600 |
| 20 | Final Exam | 15x12 | six crates; every earlier mechanic at once | 10 | 228 | 56 | 720 |

**Bands and curve.**

| Band | Levels | Difficulty | Size (cells) | Boxes | Par moves | Target first-solve rate |
|---|---|---|---|---|---|---|
| A Teaching | 1-5 | 1-2 | 7x7 to 10x8 | 1-2 | 6-38 | >= 90% |
| B Corridors | 6-9 | 3-4 | 10x8 to 11x9 | 1-2 | 44-72 | >= 75% |
| C Ordering | 10-14 | 5-6 | 11x9 to 12x10 | 3-4 | 80-116 | >= 60% |
| D Multi-room | 15-18 | 7-8 | 13x11 to 14x11 | 4-5 | 130-172 | >= 45% |
| E Expert | 19-20 | 9-10 | 14x12 to 15x12 | 5-6 | 196-228 | >= 30% |

- Board size grows one cell roughly every two levels; par grows about 12% per level inside a band and jumps about 15% between bands.
- Push density (pushes / moves) stays between 0.20 and 0.30 for every level, so a level is never a walking simulator.
- No level reuses another level's exact solution skeleton; levels 15-20 each combine at least two mechanisms taught earlier.
- `difficulty` in the level file is the number in the table; level select shows it as a label from the mapping `1-2 Beginner`, `3-4 Easy`, `5-6 Medium`, `7-8 Hard`, `9-10 Expert` (translation keys, never raw numbers alone).

**Stars and records.**

- 3 stars: `moves <= par_moves`.
- 2 stars: `moves <= ceil(par_moves * 1.25)`.
- 1 star: level completed by any number of moves.
- Best record per level keeps fewest moves, then fewest pushes, then fastest time; a star rating only ever improves.
- The level select card shows best moves, best time and stars; "Retry for 3 stars" appears when fewer than 3 are held.

## Numbers and tuning

_来源约定：issue #1、project.godot 或本页引用的既有页面已经固定的值为事实；其余数值是 proposal（提案），影响手感或发布门槛的 proposal 在 Open questions 中列出。_

| Value | Default | Range | Notes |
|---|---|---|---|
| `level_count` | 20 | 20 to 30 | shipped levels; below 20 misses the issue's minimum |
| `tutorial_level_count` | 5 | 3 to 5 | levels taught without text |
| `band_count` | 5 | 3 to 5 | curve bands in the table above |
| `par_growth_within_band_percent` | 12 | 8 to 20 | % increase in par per level within a band |
| `par_growth_between_bands_percent` | 15 | 10 to 25 | % jump in par between bands |
| `push_density_min` | 0.20 | 0.15 to 0.30 | pushes per move, ratio |
| `push_density_max` | 0.30 | 0.25 to 0.40 | pushes per move, ratio |
| `star_2_multiplier` | 1.25 | 1.10 to 1.50 | from [core-rules.md](core-rules.md) |
| `target_first_solve_rate_band_a` | 0.90 | 0.80 to 1.00 | ratio of new players completing level 1-5 first try |
| `target_first_solve_rate_band_e` | 0.30 | 0.20 to 0.50 | ratio for levels 19-20 |
| `target_session_levels` | 2 | 1 to 3 | levels per session, design intent only |
| `max_boxes_in_campaign` | 6 | 3 to 8 | highest box count shipped; validator allows 8 |

## Edge cases

- **A player completes a level with 2 stars and then retries worse.** The record keeps the better result; nothing is lowered.
- **A player retries with unlimited undo.** Undo does not count as a move, so stars are unaffected; see [core-rules.md](core-rules.md).
- **The solver says a level is unsolvable.** The level does not ship; the producer moves it to blocked and the level file is fixed or cut from the plan.
- **The solver finds a shorter route than par.** `par_moves` is lowered only by the game designer, and the 3-star bound tightens with it; this is a tuning change, not a bug fix.
- **A level is inserted in the middle of the campaign.** All later files are renumbered, ids and translation keys change together, and existing saves reference old ids; the save migration in [settings-and-save.md](settings-and-save.md) decides what happens to old records.
- **The player deletes the save file.** All levels except 001 lock again; stars and records reset. This is expected and is not recovered.
- **A player never collects a star after the first level.** Level 2 still unlocks on completion; no star is required to progress.
- **Band D and E levels take longer than the session target.** The target time is a design estimate, not a limit; a player may save-quit between levels only, per [core-rules.md](core-rules.md).

## Open questions

1. **Par authority and solver (game designer / technical director, proposal).** Every par value in the table is a hand estimate. Decision needed: confirm the solver test computes minimum moves and that par is set from it, or accept hand-set par for 1.0.
2. **Campaign length (producer, proposal).** 20 levels meets the issue's minimum; 24 would give the curve two more expert steps. Decision needed: 20 (recommended, shorter content tail) or 24.
3. **Difficulty labels (game designer, proposal).** Level select shows `Beginner/Easy/Medium/Hard/Expert` next to the level; no numeric rating is shown to players. Decision needed: keep labels, or hide difficulty entirely so players discover it.
4. **Unlock-all for reviewers and accessibility (producer, proposal).** No in-game unlock-all exists beyond the developer argument `--unlock-all`. Decision needed: whether the settings screen offers a "practice any level" toggle, which weakens the unlock loop but helps reviewers and players who stall.

## Links

- Related systems: [overview.md](overview.md), [core-rules.md](core-rules.md), [level-format.md](level-format.md), [ui-flow.md](ui-flow.md), [settings-and-save.md](settings-and-save.md)
- Stories: `production/stories/` (none yet)
- Evidence: `production/qa/evidence/<story-slug>/index.md` per implemented level band
