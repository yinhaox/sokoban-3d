class_name SettingsScreen
extends CanvasLayer

## The real Settings screen from design/settings-and-save.md "Player experience"
## and issue #16: master volume, SFX volume, language, camera sensitivity,
## colorblind mode, reduce motion and fullscreen.
##
## The screen owns no state. `bind_values()` shows the current model values, and
## every control emits `setting_changed(key, value)`; the boot scene stores the
## value, applies it and hands the clamped result back. Labels go through `tr()`,
## and `refresh_texts()` re-reads them after a language switch, so no restart is
## needed. All colours, sizes and spacing come from `UiTheme`.

signal setting_changed(key: String, value: Variant)
signal back_requested

const TITLE_KEY := "ui_settings_title"
const BACK_KEY := "ui_common_back"
const ROW_LABEL_MIN_WIDTH := 260
const VALUE_LABEL_MIN_WIDTH := 90
const CONTROL_MIN_HEIGHT := UiTheme.MIN_TARGET_PX
const VOLUME_SLIDER_MAX := 100
const VOLUME_SLIDER_STEP := 5
const CAMERA_SLIDER_MIN := 50
const CAMERA_SLIDER_MAX := 200
const CAMERA_SLIDER_STEP := 5
const PERCENT_DIVISOR := 100.0

var _title: Label
var _back: Button
var _row_labels: Dictionary = {}
var _headings: Array[Label] = []
var _value_labels: Dictionary = {}
var _sliders: Dictionary = {}
var _language_option: OptionButton
var _colorblind_option: OptionButton
var _reduce_motion_check: CheckButton
var _fullscreen_check: CheckButton
var _bound: bool = false
var _binding: bool = false


func _ready() -> void:
	_bind()


## Shows the stored values without emitting a change back to the caller.
func bind_values(settings: Dictionary) -> void:
	_bind()
	if _bound != true:
		return
	_binding = true
	_sliders[SettingsModel.MASTER_VOLUME].value = (
		float(settings.get(SettingsModel.MASTER_VOLUME, 0.8)) * PERCENT_DIVISOR
	)
	_sliders[SettingsModel.SFX_VOLUME].value = (
		float(settings.get(SettingsModel.SFX_VOLUME, 0.9)) * PERCENT_DIVISOR
	)
	_sliders[SettingsModel.CAMERA_SENSITIVITY].value = (
		float(settings.get(SettingsModel.CAMERA_SENSITIVITY, 1.0)) * PERCENT_DIVISOR
	)
	_language_option.select(
		SettingsModel.language_index(str(settings.get(SettingsModel.LANGUAGE, "en")))
	)
	_colorblind_option.select(
		SettingsModel.colorblind_index(str(settings.get(SettingsModel.COLORBLIND_MODE, "off")))
	)
	_reduce_motion_check.button_pressed = bool(settings.get(SettingsModel.REDUCE_MOTION, false))
	_fullscreen_check.button_pressed = bool(settings.get(SettingsModel.FULLSCREEN, false))
	_binding = false
	_update_value_labels()


## Re-reads every label from `tr()`. Called on open and after a language switch.
func refresh_texts() -> void:
	_bind()
	if not _bound:
		return
	_title.text = tr(TITLE_KEY)
	_headings[0].text = tr("ui_settings_group_audio")
	_headings[1].text = tr("ui_settings_group_display")
	_headings[2].text = tr("ui_settings_group_controls")
	_headings[3].text = tr("ui_settings_group_accessibility")
	_row_labels[SettingsModel.MASTER_VOLUME].text = tr("ui_settings_master_volume")
	_row_labels[SettingsModel.SFX_VOLUME].text = tr("ui_settings_sfx_volume")
	_row_labels[SettingsModel.LANGUAGE].text = tr("ui_settings_language")
	_row_labels[SettingsModel.CAMERA_SENSITIVITY].text = tr("ui_settings_camera_sensitivity")
	_row_labels[SettingsModel.COLORBLIND_MODE].text = tr("ui_settings_colorblind_mode")
	_reduce_motion_check.text = tr("ui_settings_reduce_motion")
	_fullscreen_check.text = tr("ui_settings_fullscreen")
	_back.text = tr(BACK_KEY)
	_fill_option(_language_option, ["ui_settings_language_en", "ui_settings_language_zh"])
	_fill_option(
		_colorblind_option,
		[
			"ui_settings_colorblind_off",
			"ui_settings_colorblind_deuteranopia",
			"ui_settings_colorblind_protanopia",
			"ui_settings_colorblind_tritanopia",
		]
	)
	_update_value_labels()


func focus_default() -> void:
	_bind()
	if is_inside_tree() and _bound:
		(_sliders[SettingsModel.MASTER_VOLUME] as Control).grab_focus()


func _update_value_labels() -> void:
	_value_labels[SettingsModel.MASTER_VOLUME].text = _percent_text(
		_sliders[SettingsModel.MASTER_VOLUME].value
	)
	_value_labels[SettingsModel.SFX_VOLUME].text = _percent_text(
		_sliders[SettingsModel.SFX_VOLUME].value
	)
	_value_labels[SettingsModel.CAMERA_SENSITIVITY].text = tr("ui_settings_value_ratio") % (
		_sliders[SettingsModel.CAMERA_SENSITIVITY].value / PERCENT_DIVISOR
	)


func _percent_text(value: float) -> String:
	return tr("ui_settings_value_percent") % int(round(value))


## Writes the translated option labels in place, so a language switch that is
## handled during `item_selected` does not destroy the control that emitted it.
func _fill_option(option: OptionButton, key_list: Array[String]) -> void:
	var selected := option.selected
	if option.item_count != key_list.size():
		option.clear()
		for key: String in key_list:
			option.add_item(tr(key))
	else:
		for index: int in key_list.size():
			option.set_item_text(index, tr(key_list[index]))
	option.select(clampi(selected, 0, key_list.size() - 1))


func _bind() -> void:
	Localization.install()
	if _bound:
		return
	_bound = true
	var root := get_node_or_null("Root") as Control
	if root == null:
		push_error("settings_screen: the Root control is missing")
		return
	if root.theme == null:
		root.theme = UiTheme.build()
	if not _find_nodes():
		push_error("settings_screen: the settings rows are incomplete")
		return
	_configure_controls()
	_connect_controls()
	refresh_texts()


## Finds every node the screen reads from the scene. Returns false when one is
## missing, so `_bind()` reports one clear error instead of failing halfway.
func _find_nodes() -> bool:
	var rows_path := "Root/Content/Margin/Layout/Scroll/Rows"
	_title = get_node_or_null("Root/Content/Margin/Layout/Title") as Label
	_back = get_node_or_null("Root/Content/Margin/Layout/Back") as Button
	for heading_name: String in ["AudioHeading", "DisplayHeading", "ControlsHeading", "AccessibilityHeading"]:
		var heading := get_node_or_null("%s/%s" % [rows_path, heading_name]) as Label
		if heading != null:
			_headings.append(heading)
	_find_row_labels(rows_path)
	_find_value_labels(rows_path)
	_find_sliders(rows_path)
	_language_option = get_node_or_null("%s/LanguageRow/Option" % rows_path) as OptionButton
	_colorblind_option = get_node_or_null("%s/ColorblindRow/Option" % rows_path) as OptionButton
	_reduce_motion_check = get_node_or_null("%s/ReduceMotion" % rows_path) as CheckButton
	_fullscreen_check = get_node_or_null("%s/Fullscreen" % rows_path) as CheckButton
	return _is_complete()


func _find_row_labels(rows_path: String) -> void:
	_row_labels[SettingsModel.MASTER_VOLUME] = get_node_or_null(
		"%s/MasterRow/Label" % rows_path
	) as Label
	_row_labels[SettingsModel.SFX_VOLUME] = get_node_or_null("%s/SfxRow/Label" % rows_path) as Label
	_row_labels[SettingsModel.LANGUAGE] = get_node_or_null(
		"%s/LanguageRow/Label" % rows_path
	) as Label
	_row_labels[SettingsModel.CAMERA_SENSITIVITY] = get_node_or_null(
		"%s/CameraRow/Label" % rows_path
	) as Label
	_row_labels[SettingsModel.COLORBLIND_MODE] = get_node_or_null(
		"%s/ColorblindRow/Label" % rows_path
	) as Label


func _find_value_labels(rows_path: String) -> void:
	_value_labels[SettingsModel.MASTER_VOLUME] = get_node_or_null(
		"%s/MasterRow/Value" % rows_path
	) as Label
	_value_labels[SettingsModel.SFX_VOLUME] = get_node_or_null(
		"%s/SfxRow/Value" % rows_path
	) as Label
	_value_labels[SettingsModel.CAMERA_SENSITIVITY] = get_node_or_null(
		"%s/CameraRow/Value" % rows_path
	) as Label


func _find_sliders(rows_path: String) -> void:
	_sliders[SettingsModel.MASTER_VOLUME] = get_node_or_null(
		"%s/MasterRow/Slider" % rows_path
	) as HSlider
	_sliders[SettingsModel.SFX_VOLUME] = get_node_or_null("%s/SfxRow/Slider" % rows_path) as HSlider
	_sliders[SettingsModel.CAMERA_SENSITIVITY] = get_node_or_null(
		"%s/CameraRow/Slider" % rows_path
	) as HSlider


## True when every node the screen reads was found in the scene.
func _is_complete() -> bool:
	if _title == null or _back == null or _language_option == null:
		return false
	if _colorblind_option == null or _reduce_motion_check == null or _fullscreen_check == null:
		return false
	if _headings.size() != 4:
		return false
	for key: String in SettingsModel.SETTINGS_KEYS:
		if key == SettingsModel.LANGUAGE or key == SettingsModel.COLORBLIND_MODE:
			continue
		if key == SettingsModel.REDUCE_MOTION or key == SettingsModel.FULLSCREEN:
			continue
		if not _sliders.has(key) or not _value_labels.has(key):
			return false
	return true


func _configure_controls() -> void:
	_set_slider(_sliders[SettingsModel.MASTER_VOLUME], VOLUME_SLIDER_MAX, VOLUME_SLIDER_STEP)
	_set_slider(_sliders[SettingsModel.SFX_VOLUME], VOLUME_SLIDER_MAX, VOLUME_SLIDER_STEP)
	_set_slider(_sliders[SettingsModel.CAMERA_SENSITIVITY], CAMERA_SLIDER_MAX, CAMERA_SLIDER_STEP)
	(_sliders[SettingsModel.CAMERA_SENSITIVITY] as HSlider).min_value = CAMERA_SLIDER_MIN
	for key: String in _row_labels:
		(_row_labels[key] as Label).custom_minimum_size = Vector2(ROW_LABEL_MIN_WIDTH, CONTROL_MIN_HEIGHT)
		(_row_labels[key] as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for key: String in _value_labels:
		(_value_labels[key] as Label).custom_minimum_size = Vector2(VALUE_LABEL_MIN_WIDTH, CONTROL_MIN_HEIGHT)
		(_value_labels[key] as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		(_value_labels[key] as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for key: String in _sliders:
		var slider := _sliders[key] as HSlider
		slider.custom_minimum_size = Vector2(0, CONTROL_MIN_HEIGHT)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.focus_mode = Control.FOCUS_ALL
	for option: OptionButton in [_language_option, _colorblind_option]:
		option.custom_minimum_size = Vector2(0, CONTROL_MIN_HEIGHT)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.focus_mode = Control.FOCUS_ALL
	for check: CheckButton in [_reduce_motion_check, _fullscreen_check]:
		check.custom_minimum_size = Vector2(0, CONTROL_MIN_HEIGHT)
		check.focus_mode = Control.FOCUS_ALL
	_back.custom_minimum_size = Vector2(200, CONTROL_MIN_HEIGHT)


func _set_slider(slider: HSlider, maximum: int, step: int) -> void:
	slider.min_value = 0
	slider.max_value = maximum
	slider.step = step


func _connect_controls() -> void:
	(_sliders[SettingsModel.MASTER_VOLUME] as HSlider).value_changed.connect(
		_on_volume_changed.bind(SettingsModel.MASTER_VOLUME)
	)
	(_sliders[SettingsModel.SFX_VOLUME] as HSlider).value_changed.connect(
		_on_volume_changed.bind(SettingsModel.SFX_VOLUME)
	)
	(_sliders[SettingsModel.CAMERA_SENSITIVITY] as HSlider).value_changed.connect(
		_on_camera_changed
	)
	_language_option.item_selected.connect(_on_language_selected)
	_colorblind_option.item_selected.connect(_on_colorblind_selected)
	_reduce_motion_check.toggled.connect(_on_reduce_motion_toggled)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_back.pressed.connect(_on_back_pressed)
	var controls: Array[Control] = [
		_sliders[SettingsModel.MASTER_VOLUME],
		_sliders[SettingsModel.SFX_VOLUME],
		_language_option,
		_fullscreen_check,
		_sliders[SettingsModel.CAMERA_SENSITIVITY],
		_colorblind_option,
		_reduce_motion_check,
		_back,
	]
	for index: int in controls.size():
		var control := controls[index]
		var previous := controls[posmod(index - 1, controls.size())]
		var next := controls[(index + 1) % controls.size()]
		control.focus_neighbor_top = control.get_path_to(previous)
		control.focus_neighbor_bottom = control.get_path_to(next)
		control.focus_previous = control.get_path_to(previous)
		control.focus_next = control.get_path_to(next)


func _on_volume_changed(value: float, key: String) -> void:
	if _binding:
		return
	setting_changed.emit(key, value / PERCENT_DIVISOR)
	_update_value_labels()


func _on_camera_changed(value: float) -> void:
	if _binding:
		return
	setting_changed.emit(SettingsModel.CAMERA_SENSITIVITY, value / PERCENT_DIVISOR)
	_update_value_labels()


func _on_language_selected(index: int) -> void:
	if _binding:
		return
	setting_changed.emit(
		SettingsModel.LANGUAGE, SettingsModel.LANGUAGES[clampi(index, 0, 1)]
	)


func _on_colorblind_selected(index: int) -> void:
	if _binding:
		return
	setting_changed.emit(
		SettingsModel.COLORBLIND_MODE,
		SettingsModel.COLORBLIND_MODES[clampi(index, 0, SettingsModel.COLORBLIND_MODES.size() - 1)]
	)


func _on_reduce_motion_toggled(pressed: bool) -> void:
	if not _binding:
		setting_changed.emit(SettingsModel.REDUCE_MOTION, pressed)


func _on_fullscreen_toggled(pressed: bool) -> void:
	if not _binding:
		setting_changed.emit(SettingsModel.FULLSCREEN, pressed)


func _on_back_pressed() -> void:
	back_requested.emit()
