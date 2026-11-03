class_name InfoPanel
extends CanvasLayer

## A read-only placeholder screen: a title, one body and a Back button. Credits
## uses it; the boot scene sets the two translated strings and re-translates them
## on a language switch. The panel emits `back_requested` and owns nothing else.

signal back_requested

const BACK_KEY := "ui_common_back"

var _title: Label
var _body: Label
var _back: Button
var _bound: bool = false


func _ready() -> void:
	_bind()


## Sets the title and the wrapped body text for this instance.
func set_content(title_text: String, body_text: String) -> void:
	_bind()
	if _title == null or _body == null:
		return
	_title.text = title_text
	_body.text = body_text


func focus_default() -> void:
	_bind()
	if is_inside_tree() and _back != null:
		_back.grab_focus()


func refresh_texts() -> void:
	_bind()
	if _bound and _back != null:
		_back.text = tr(BACK_KEY)


func _bind() -> void:
	Localization.install()
	if _bound:
		return
	_bound = true
	var root := get_node_or_null("Root") as Control
	if root == null:
		push_error("info_panel: the Root control is missing")
		return
	if root.theme == null:
		root.theme = UiTheme.build()
	_title = get_node_or_null("Root/Content/Margin/Layout/Title") as Label
	_body = get_node_or_null("Root/Content/Margin/Layout/Body") as Label
	_back = get_node_or_null("Root/Content/Margin/Layout/Back") as Button
	if _title == null or _body == null or _back == null:
		push_error("info_panel: the title, body or back button is missing")
		return
	_back.custom_minimum_size = Vector2(200, UiTheme.MIN_TARGET_PX)
	var controls: Array[Control] = [_back]
	UiFocus.wire_vertical(controls)
	_back.pressed.connect(_on_back_pressed)
	refresh_texts()


func _on_back_pressed() -> void:
	back_requested.emit()
