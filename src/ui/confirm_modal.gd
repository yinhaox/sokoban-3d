class_name ConfirmModal
extends CanvasLayer

## One destructive question over the current screen, per design/ui-flow.md
## "Restart Confirm" and "Leave Confirm". Cancel is focused and one modal is open
## at a time; a second request while it is open is ignored by the caller.
##
## The modal owns no game state: it emits `confirmed` or `cancelled` and the boot
## scene applies the action that was waiting.

signal confirmed
signal cancelled

const CANCEL_TEXT := "Cancel"
const CONFIRM_TEXT := "Confirm"
const BUTTON_MIN_SIZE := Vector2(140, UiTheme.MIN_TARGET_PX)

var _question: Label
var _cancel: Button
var _confirm: Button
var _open: bool = false
var _bound: bool = false


func _ready() -> void:
	_bind()
	visible = false


## Opens the modal with one question. Cancel takes the focus so the safe answer
## is the default.
func ask(question: String) -> void:
	_bind()
	if _question == null or _cancel == null:
		return
	if _open:
		return
	_question.text = question
	_open = true
	visible = true
	if is_inside_tree():
		_cancel.grab_focus()


func is_open() -> bool:
	return _open


func cancel() -> void:
	if not _open:
		return
	_open = false
	visible = false
	cancelled.emit()


func confirm() -> void:
	if not _open:
		return
	_open = false
	visible = false
	confirmed.emit()


func _bind() -> void:
	if _bound:
		return
	_bound = true
	var root := get_node_or_null("Root") as Control
	if root == null:
		push_error("confirm_modal: the Root control is missing")
		return
	if root.theme == null:
		root.theme = UiTheme.build()
	_question = get_node_or_null("Root/Center/Panel/Content/Question") as Label
	_cancel = get_node_or_null("Root/Center/Panel/Content/Buttons/Cancel") as Button
	_confirm = get_node_or_null("Root/Center/Panel/Content/Buttons/Confirm") as Button
	if _question == null or _cancel == null or _confirm == null:
		push_error("confirm_modal: the question or buttons are missing")
		return
	_cancel.text = CANCEL_TEXT
	_confirm.text = CONFIRM_TEXT
	_cancel.custom_minimum_size = BUTTON_MIN_SIZE
	_confirm.custom_minimum_size = BUTTON_MIN_SIZE
	var controls: Array[Control] = [_cancel, _confirm]
	UiFocus.wire_horizontal(controls)
	_cancel.pressed.connect(cancel)
	_confirm.pressed.connect(confirm)
