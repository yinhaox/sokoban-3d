# Design: level format

_The on-disk level contract: one JSON file per level under `assets/data/levels/`, validated on load and by a headless test. Owned by the technical director._

## Goals

Pillar P3 (learn by doing). Levels are content, so a designer must be able to add, retune or reorder one without touching GDScript, and a broken level must fail before a player sees it.

- One level per JSON file, human-diffable, with the same shape for level 1 and level 20.
- The loader rejects a malformed level instead of half-loading it, and a headless test fails on any invalid file in the repository.
- Every field a designer tunes (name, author, difficulty, par values) lives in the file, not in code.

The page lands when a level file can be authored by hand from the field table below, the loader accepts it, the level is playable in game, and deleting a required key makes the test suite fail with a file-and-field error.

## Player experience

The player never sees the JSON. They see a level select card whose name comes from the file's translation key, a difficulty label from the file's `difficulty`, and a star threshold derived from the file's `par_moves`. When a level cannot load, the card shows as unavailable with a neutral message and the rest of the game keeps working; a broken data file never blocks the main menu.

For the studio, adding a level is a five-minute task: copy the template, paint the grid with the legend, fill the header fields, add two translation strings, run the check and test commands, and the level appears in the select list in id order.

## Rules

**Location and naming.**

- Levels live at `assets/data/levels/` as `level-NNN.json`, `NNN` zero-padded three digits, starting at `001`.
- The file stem must equal the `id` field; a mismatch is a load error for that file.
- Level select order is ascending `id`. The producer may reorder levels only by renumbering files and ids together, in one change.
- A level's display name is its `name_key`; `name` is the English fallback shown when the translation is missing, and the label used in tools and error messages.

**File shape.** Every file is UTF-8 without BOM, no comments, no trailing commas, snake_case keys (`.dsh/rules/data.md`). Unknown keys produce a warning and are ignored, so a newer file does not break an older build.

| Field | Type | Required | Unit / constraint |
|---|---|---|---|
| `id` | string | yes | `^level-[0-9]{3}$`, unique across `assets/data/levels/`, equals file stem |
| `name` | string | yes | 1 to 48 characters, English fallback display name |
| `name_key` | string | yes | translation key existing in every shipped locale, e.g. `level_001_name` |
| `author` | string | yes | 1 to 64 characters, person or studio credited in the level info |
| `difficulty` | integer | yes | 1 to 10, matches the band in [level-progression.md](level-progression.md) |
| `par_moves` | integer | yes | moves; 1 to 500, the 3-star bound |
| `par_pushes` | integer | yes | pushes; 1 to `par_moves`, shown in records and used by the solver test |
| `columns` | integer | yes | cells; 5 to 15, must equal every tile row length |
| `rows` | integer | yes | cells; 5 to 15, must equal `tiles` length |
| `tiles` | array of string | yes | exactly `rows` strings, each exactly `columns` characters from the legend |
| `notes` | string | no | 0 to 200 characters, authoring note for the studio; never shown to the player |
| `schema_version` | integer | no | 1 in 1.0; absent means 1 |

**Legend.** One character per cell. The two-cell characters (`*`, `+`) are boxes and players that start on a goal plate.

| Character | Cell |
|---|---|
| `#` | wall |
| `_` | floor |
| `.` | goal (floor plus goal plate) |
| `$` | box on floor |
| `*` | box on a goal |
| `@` | player on floor |
| `+` | player on a goal |

`_` is used for floor instead of the classic space so that rows are visible in a diff; a space is rejected by the loader.

**Validation.** The loader validates in this order and reports every failure for the file, then skips the file.

1. File parses as JSON and is under `level_max_file_bytes`.
2. Required fields present; types match the table; no duplicate keys (JSON parser).
3. `id` matches the file stem and the id pattern; no other file in the folder declares the same `id`.
4. `columns` in 5..15, `rows` in 5..15, `tiles` has `rows` entries, every entry has exactly `columns` characters from the legend, and no other character appears.
5. The outer border is all `#`; void outside the grid does not exist in 1.0.
6. Exactly one player character (`@` or `+`), between `min_boxes` and `max_boxes` boxes (`$` or `*`), and the number of goals (`.`, `*`, `+`) equals the number of boxes.
7. The level is not already solved: at least one box is not on a goal.
8. `par_pushes <= par_moves`, `difficulty` in 1..10, `name_key` non-empty and present in every locale.
9. `name_key` duplicates another level's key: error, because level select would show two identical names.

- A file that fails validation is unavailable to the player and listed in a load report. The main menu, settings and other levels still work.
- `tests/run_tests.gd` loads every file in `assets/data/levels/`, asserts zero validation errors, and asserts every level is solvable by the reference solver (see [technical-architecture.md](technical-architecture.md)).
- A `.schema.md` file documenting this table ships next to the levels as `assets/data/levels/level.schema.md`, per `.dsh/rules/data.md`.

**Example: level 1.** Copied verbatim from `assets/data/levels/level-001.json`; its seven tile rows are each seven characters, matching `columns: 7`.

```json
{
  "id": "level-001",
  "name": "First Push",
  "name_key": "level_001_name",
  "author": "Sokoban 3D Studio",
  "difficulty": 1,
  "par_moves": 6,
  "par_pushes": 3,
  "columns": 7,
  "rows": 7,
  "tiles": [
    "#######",
    "#____.#",
    "#_____#",
    "#_@_$_#",
    "#_____#",
    "#_____#",
    "#######"
  ],
  "notes": "Walk right, push the crate right once, circle below it and push it up twice onto the plate."
}
```

**How to add a level.**

1. Copy an existing file to `level-NNN.json` whose number is the next free id.
2. Set `id` to the same stem, `name` and `name_key`, `author`, `difficulty` in the band of its position, and hand-set `par_moves`/`par_pushes`.
3. Paint `tiles` with the legend: one player, equal boxes and goals, a full wall border, and no solved start.
4. Add the `name_key` string to every locale file so the check passes.
5. Run `python scripts/studio.py check` and `python scripts/studio.py test`; the level loader test fails on any rule above.
6. Play it with `python scripts/studio.py run` until par feels right, then update `par_moves`/`par_pushes` and the progression table in [level-progression.md](level-progression.md).

## Numbers and tuning

_来源约定：issue #1、project.godot 或本页引用的既有页面已经固定的值为事实；其余数值是 proposal（提案），影响手感或发布门槛的 proposal 在 Open questions 中列出。_

| Value | Default | Range | Notes |
|---|---|---|---|
| `level_file_count` | 20 | 20 to 30 | files under `assets/data/levels/` in 1.0 |
| `level_max_file_bytes` | 16384 | 4096 to 65536 | bytes per level file |
| `level_id_digits` | 3 | 3 to 4 | digits in `level-NNN` |
| `min_columns` | 5 | 5 to 15 | cells, mirrored from [core-rules.md](core-rules.md) |
| `max_columns` | 15 | 5 to 15 | cells |
| `min_rows` | 5 | 5 to 15 | cells |
| `max_rows` | 15 | 5 to 15 | cells |
| `min_boxes` | 1 | 1 to 8 | boxes per level |
| `max_boxes` | 8 | 1 to 8 | boxes per level |
| `name_max_characters` | 48 | 16 to 64 | characters in `name` |
| `author_max_characters` | 64 | 16 to 128 | characters in `author` |
| `difficulty_min` | 1 | 1 to 10 | difficulty scale |
| `difficulty_max` | 10 | 1 to 10 | difficulty scale |
| `par_moves_max` | 500 | 100 to 1000 | moves; basis for star bounds |
| `schema_version` | 1 | 1 to 1 | absent means 1 in 1.0 |

## Edge cases

- **Two files declare the same `id`.** Both are rejected and named in the load report; the loader never silently keeps one, per `.dsh/rules/data.md`.
- **The folder is missing or empty.** The level select shows an empty state with "No levels found" and a link to the settings screen; the game does not crash and the main menu still works.
- **A tile row is one character short.** Validation fails with the field name, row index and expected length; the level is unavailable.
- **The level is already solved at start.** Rejected, because the player could never observe the puzzle; see [core-rules.md](core-rules.md).
- **A box count does not equal a goal count.** Rejected: a level with an extra goal can never be completed, and an extra box can never land.
- **The translation key is missing at runtime.** The `name` fallback is displayed and a warning is logged; the level still loads.
- **A level file is edited while the game is running.** Levels are loaded once at level select; a running session keeps its copy and the next launch picks up the change.
- **An unknown key appears in a newer file.** A warning names the key and the file; the level still loads, so a forward-compatible file is not fatal.
- **CRLF line endings or a BOM.** Rejected with a clear message telling the author to save as UTF-8 without BOM, matching `.dsh/rules/data.md`.
- **`par_moves` is wrong (too low).** The level is still playable and the 3-star bound is simply unreachable; the solver test reports the discrepancy rather than blocking the build.

## Open questions

1. **Solvability proof (technical director, proposal).** The plan is a reference solver in the headless tests that verifies every level has a solution and reports its minimum moves; par is then set from that number. Decision needed: whether a full solver is in 1.0 scope or the test only checks known solutions from data.
2. **Multiple level packs / DLC layout (producer, proposal).** 1.0 is a flat folder of 20 files. Decision needed: whether the path needs a sub-folder per pack now, before ids and localization keys freeze.
3. **Author field for licensed level sets (release manager, proposal).** `author` is a free string. Decision needed: whether third-party or licensed level content is possible, which would require the credit list and license block in [release.md](release.md) to cover it.
4. **Reorder versus renumber (game designer, proposal).** Reordering requires renaming files and ids. Decision needed: whether 1.0 should instead carry an explicit `order` integer so ids stay stable forever.

## Links

- Related systems: [overview.md](overview.md), [core-rules.md](core-rules.md), [level-progression.md](level-progression.md), [technical-architecture.md](technical-architecture.md), [settings-and-save.md](settings-and-save.md)
- Stories: `production/stories/` (none yet)
- Data rules: `.dsh/rules/data.md`
