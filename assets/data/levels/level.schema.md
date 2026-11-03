# Level file schema

One level per file at `assets/data/levels/level-NNN.json`, UTF-8 without BOM, no comments, no trailing commas, snake_case keys. The file stem must equal `id`. The contract and its validation order are specified in [design/level-format.md](../../../design/level-format.md); the loader is `src/logic/level_data.gd`.

| Field | Type | Required | Constraint |
|---|---|---|---|
| `id` | string | yes | `level-NNN`, equals the file stem |
| `name` | string | yes | 1 to 48 characters, English fallback display name |
| `name_key` | string | yes | translation key, for example `level_001_name` |
| `author` | string | yes | 1 to 64 characters |
| `difficulty` | integer | yes | 1 to 10 |
| `par_moves` | integer | yes | 1 to 500, the 3-star move bound |
| `par_pushes` | integer | yes | 1 to `par_moves` |
| `columns` | integer | yes | 5 to 15, equals every tile row length |
| `rows` | integer | yes | 5 to 15, equals the `tiles` length |
| `tiles` | array of string | yes | exactly `rows` strings of `columns` legend characters |
| `notes` | string | no | 0 to 200 characters, authoring note, never shown to the player |
| `schema_version` | integer | no | 1; absent means 1 |

Legend, one character per cell:

| Character | Cell |
|---|---|
| `#` | wall |
| `_` | floor |
| `.` | goal (floor plus goal plate) |
| `$` | box on floor |
| `*` | box on a goal |
| `@` | player on floor |
| `+` | player on a goal |

A level is rejected when a required field is missing or wrongly typed, the size is outside 5 to 15, a row is the wrong length, a character is not in the legend, the outer border is not all walls, there is not exactly one player, the box count is outside 1 to 8, the goal count differs from the box count, the level is already solved at start, or `par_pushes` exceeds `par_moves`. Unknown keys warn and are ignored.
