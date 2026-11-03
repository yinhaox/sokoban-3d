class_name UiFormat
extends RefCounted

## Shared formatting for values the HUD and the victory panel both show, so the
## same attempt never renders two different time strings.

const MILLISECONDS_PER_SECOND := 1000
const MILLISECONDS_PER_TENTH := 100
const SECONDS_PER_MINUTE := 60
const MAX_HOURS := 99


## `h:mm:ss.t` with a tenth of a second, matching the 100 ms timer precision in
## design/core-rules.md `timer_precision_ms`. Above 99 hours the displayed value
## clamps as design/core-rules.md "Edge cases" requires.
static func elapsed_ms(milliseconds: int) -> String:
	var safe_ms: int = maxi(milliseconds, 0)
	var total_seconds: int = safe_ms / MILLISECONDS_PER_SECOND
	var total_minutes: int = total_seconds / SECONDS_PER_MINUTE
	var hours: int = total_minutes / SECONDS_PER_MINUTE
	var minutes: int = total_minutes % SECONDS_PER_MINUTE
	var seconds: int = total_seconds % SECONDS_PER_MINUTE
	var tenths: int = (safe_ms % MILLISECONDS_PER_SECOND) / MILLISECONDS_PER_TENTH
	if hours > MAX_HOURS:
		hours = MAX_HOURS
		minutes = SECONDS_PER_MINUTE - 1
		seconds = SECONDS_PER_MINUTE - 1
		tenths = 9
	if hours > 0:
		return "%d:%02d:%02d.%d" % [hours, minutes, seconds, tenths]
	return "%d:%02d.%d" % [minutes, seconds, tenths]
