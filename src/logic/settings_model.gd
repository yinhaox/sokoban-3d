class_name SettingsModel
extends RefCounted

## The typed settings model from design/settings-and-save.md "Settings model".
##
## Every value has a default and a range, and a value outside the range or of the
## wrong type is clamped or replaced with a warning, never silently ignored. The
## save manager owns one instance of this data; the settings screen reads it back
## and emits intent, it never writes the save file.

const MASTER_VOLUME := "master_volume"
const SFX_VOLUME := "sfx_volume"
const LANGUAGE := "language"
const CAMERA_SENSITIVITY := "camera_sensitivity"
const COLORBLIND_MODE := "colorblind_mode"
const REDUCE_MOTION := "reduce_motion"
const FULLSCREEN := "fullscreen"

const LANGUAGES: Array[String] = ["en", "zh"]
const COLORBLIND_MODES: Array[String] = [
	"off", "deuteranopia", "protanopia", "tritanopia"
]
const SETTINGS_KEYS: Array[String] = [
	MASTER_VOLUME,
	SFX_VOLUME,
	LANGUAGE,
	CAMERA_SENSITIVITY,
	COLORBLIND_MODE,
	REDUCE_MOTION,
	FULLSCREEN,
]

const DEFAULTS := {
	MASTER_VOLUME: 0.80,
	SFX_VOLUME: 0.90,
	LANGUAGE: "en",
	CAMERA_SENSITIVITY: 1.00,
	COLORBLIND_MODE: "off",
	REDUCE_MOTION: false,
	FULLSCREEN: false,
}

const FLOAT_RANGES := {
	MASTER_VOLUME: [0.0, 1.0],
	SFX_VOLUME: [0.0, 1.0],
	CAMERA_SENSITIVITY: [0.5, 2.0],
}

## Linear volume below this is treated as silence; `linear_to_db(0)` is -inf.
const MIN_AUDIBLE_VOLUME := 0.0001


## A fresh copy of the defaults, so no caller shares the constant dictionary.
static func defaults() -> Dictionary:
	return DEFAULTS.duplicate(true)


## A complete, valid settings dictionary built from `values`: unknown keys are
## dropped, missing keys take their default, and invalid values are clamped.
static func sanitize(values: Dictionary) -> Dictionary:
	var result := defaults()
	for key: String in SETTINGS_KEYS:
		if not values.has(key):
			continue
		result[key] = clamp_value(key, values[key])
	return result


## The valid form of one setting. A wrong type or an unknown enum name returns
## the default and logs which key was rejected.
static func clamp_value(key: String, value: Variant) -> Variant:
	var fallback: Variant = DEFAULTS.get(key)
	match key:
		MASTER_VOLUME, SFX_VOLUME, CAMERA_SENSITIVITY:
			if not (value is int or value is float):
				push_warning("settings: %s expects a number, got %s" % [key, typeof(value)])
				return fallback
			var limits: Array = FLOAT_RANGES[key]
			var clamped := clampf(float(value), float(limits[0]), float(limits[1]))
			if not is_equal_approx(clamped, float(value)):
				push_warning("settings: %s=%s clamped to %s" % [key, value, clamped])
			return clamped
		LANGUAGE:
			if not value is String or not LANGUAGES.has(value):
				push_warning("settings: language '%s' is not supported" % value)
				return fallback
			return value
		COLORBLIND_MODE:
			if not value is String or not COLORBLIND_MODES.has(value):
				push_warning("settings: colorblind mode '%s' is not supported" % value)
				return fallback
			return value
		REDUCE_MOTION, FULLSCREEN:
			if not value is bool:
				push_warning("settings: %s expects a bool, got %s" % [key, typeof(value)])
				return fallback
			return value
	return fallback


## Linear volume as the bus dB value the audio server takes. Silence maps to a
## very quiet but finite value; callers mute the bus at zero instead.
static func volume_to_db(value: float) -> float:
	return linear_to_db(maxf(value, MIN_AUDIBLE_VOLUME))


## Window mode a fullscreen toggle asks the display server for.
static func window_mode_for(fullscreen: bool) -> int:
	return DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED


static func language_index(language: String) -> int:
	return maxi(LANGUAGES.find(language), 0)


static func colorblind_index(mode: String) -> int:
	return maxi(COLORBLIND_MODES.find(mode), 0)
