class_name Localization
extends RefCounted

## Runtime localization for the English/Chinese UI, per design/ui-flow.md
## "Localization".
##
## The project does not register a translation resource in `project.godot`
## (outside this story's write boundary), so the two flat JSON tables in
## `assets/data/i18n/` are loaded into `Translation` resources at boot and added
## to the `TranslationServer`. Screens then call `tr()` normally. `en` is the
## fallback table: a key that is missing from `zh` is filled with its English
## value when the `zh` resource is built, so a gap renders English instead of the
## raw key. `install()` is idempotent and safe to call from a headless test.

const I18N_DIRECTORY := "res://assets/data/i18n/"
const DEFAULT_LOCALE := "en"
const LOCALES: Array[String] = ["en", "zh"]

## Every key the screens, data and settings formats use. The test suite asserts
## that both shipped tables carry all of them.
const REQUIRED_KEYS: Array[String] = [
	"ui_menu_title",
	"ui_menu_subtitle",
	"ui_menu_play",
	"ui_menu_level_select",
	"ui_menu_settings",
	"ui_menu_credits",
	"ui_menu_quit",
	"ui_menu_notice",
	"ui_common_back",
	"ui_common_cancel",
	"ui_common_confirm",
	"ui_common_locked",
	"ui_common_completed",
	"ui_common_on",
	"ui_common_off",
	"ui_level_select_title",
	"ui_level_card_number",
	"ui_level_par",
	"ui_level_best",
	"ui_level_stars",
	"ui_difficulty_beginner",
	"ui_difficulty_easy",
	"ui_difficulty_medium",
	"ui_difficulty_hard",
	"ui_difficulty_expert",
	"level_001_name",
	"level_002_name",
	"level_003_name",
	"ui_hud_level",
	"ui_hud_moves",
	"ui_hud_pushes",
	"ui_hud_goals",
	"ui_hud_time",
	"ui_hud_undo",
	"ui_hud_restart",
	"ui_hud_pause",
	"ui_pause_title",
	"ui_pause_resume",
	"ui_pause_restart",
	"ui_pause_settings",
	"ui_pause_main_menu",
	"ui_victory_title",
	"ui_victory_retry",
	"ui_victory_next",
	"ui_victory_level_select",
	"ui_victory_moves_par",
	"ui_victory_moves",
	"ui_victory_pushes",
	"ui_victory_time",
	"ui_victory_stars",
	"ui_confirm_restart",
	"ui_confirm_leave",
	"ui_credits_title",
	"ui_credits_body",
	"ui_settings_title",
	"ui_settings_group_audio",
	"ui_settings_master_volume",
	"ui_settings_sfx_volume",
	"ui_settings_group_display",
	"ui_settings_language",
	"ui_settings_language_en",
	"ui_settings_language_zh",
	"ui_settings_fullscreen",
	"ui_settings_group_controls",
	"ui_settings_camera_sensitivity",
	"ui_settings_group_accessibility",
	"ui_settings_colorblind_mode",
	"ui_settings_colorblind_off",
	"ui_settings_colorblind_deuteranopia",
	"ui_settings_colorblind_protanopia",
	"ui_settings_colorblind_tritanopia",
	"ui_settings_reduce_motion",
	"ui_settings_value_percent",
	"ui_settings_value_ratio",
	"ui_notice_corrupt",
	"ui_notice_newer",
	"ui_notice_save_failed",
]

static var _installed: bool = false
static var _locale: String = DEFAULT_LOCALE
static var _messages: Dictionary = {}


## Loads both tables and registers them once. A second call is a no-op, so the
## first screen or the boot scene can call it without ordering assumptions.
static func install() -> void:
	if _installed:
		return
	_installed = true
	var en := load_dictionary("en")
	var zh := load_dictionary("zh")
	_messages = {"en": en, "zh": zh}
	TranslationServer.add_translation(build_translation("en", en, en))
	TranslationServer.add_translation(build_translation("zh", zh, en))
	set_locale(_locale)


## Reads one table from `res://assets/data/i18n/<locale>.json`. A missing or
## malformed file logs an error and yields an empty table instead of crashing.
static func load_dictionary(locale: String) -> Dictionary:
	var path := I18N_DIRECTORY + locale + ".json"
	if not FileAccess.file_exists(path):
		push_error("localization: missing translation table %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("localization: cannot read translation table %s" % path)
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("localization: %s is not a JSON object" % path)
		return {}
	var table: Dictionary = {}
	for key: Variant in (parsed as Dictionary).keys():
		table[str(key)] = str((parsed as Dictionary)[key])
	return table


## Builds one `Translation`. `fallback` is layered first, so `messages` overrides
## it key by key and a key absent from `messages` keeps the fallback value.
static func build_translation(
	locale: String, messages: Dictionary, fallback: Dictionary
) -> Translation:
	var translation := Translation.new()
	translation.locale = locale
	for key: Variant in fallback.keys():
		translation.add_message(str(key), str(fallback[key]))
	for key: Variant in messages.keys():
		translation.add_message(str(key), str(messages[key]))
	return translation


## Switches the UI locale immediately. An unknown locale falls back to `en`.
static func set_locale(locale: String) -> void:
	_locale = locale if LOCALES.has(locale) else DEFAULT_LOCALE
	TranslationServer.set_locale(_locale)


static func current_locale() -> String:
	return _locale


## The loaded table for one locale, used by the settings screen and the tests.
static func messages_for(locale: String) -> Dictionary:
	return _messages.get(locale, {}) as Dictionary
