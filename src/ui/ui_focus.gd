class_name UiFocus
extends RefCounted

## Shared focus-neighbour wiring for the screen scripts. The screen graph in
## design/ui-flow.md requires a defined focus order, so a keyboard or a d-pad can
## reach every control and the order follows the visual order of the screen.
##
## Each screen script builds its button list and calls one of these helpers in
## `_ready()`; nothing here reads or changes game state.


## Wraps a vertical button list top-to-bottom: up/down move through the list and
## wrap at both ends, and `focus_next`/`focus_previous` match.
static func wire_vertical(controls: Array[Control]) -> void:
	if controls.is_empty():
		return
	for index: int in controls.size():
		var control: Control = controls[index]
		control.focus_mode = Control.FOCUS_ALL
		var previous: Control = controls[posmod(index - 1, controls.size())]
		var next: Control = controls[(index + 1) % controls.size()]
		control.focus_neighbor_top = control.get_path_to(previous)
		control.focus_neighbor_bottom = control.get_path_to(next)
		control.focus_previous = control.get_path_to(previous)
		control.focus_next = control.get_path_to(next)


## Wraps a horizontal button list left-to-right, used by the confirm and victory
## button rows. Vertical neighbours are self-paths so focus never escapes.
static func wire_horizontal(controls: Array[Control]) -> void:
	if controls.is_empty():
		return
	for index: int in controls.size():
		var control: Control = controls[index]
		control.focus_mode = Control.FOCUS_ALL
		var previous: Control = controls[posmod(index - 1, controls.size())]
		var next: Control = controls[(index + 1) % controls.size()]
		control.focus_neighbor_left = control.get_path_to(previous)
		control.focus_neighbor_right = control.get_path_to(next)
		control.focus_previous = control.get_path_to(previous)
		control.focus_next = control.get_path_to(next)
