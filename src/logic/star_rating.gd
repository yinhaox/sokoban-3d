class_name StarRating
extends RefCounted

## Star rating for a completed attempt, per design/core-rules.md "Win" and
## design/level-progression.md "Stars and records":
## - 3 stars when `moves <= par_moves`;
## - 2 stars when `moves <= ceil(par_moves * star_2_multiplier)`;
## - 1 star for any completion.
##
## `par_moves` is authored per level, never computed at runtime, so this class
## only compares the attempt's move count against it.

const MIN_STARS := 1
const MAX_STARS := 3
## design/core-rules.md `star_2_multiplier`.
const STAR_2_MULTIPLIER := 1.25


static func stars_for_moves(moves: int, par_moves: int) -> int:
	if moves <= par_moves:
		return MAX_STARS
	if moves <= star_2_bound(par_moves):
		return 2
	return MIN_STARS


## Highest move count that still earns two stars.
static func star_2_bound(par_moves: int) -> int:
	return ceili(float(par_moves) * STAR_2_MULTIPLIER)
