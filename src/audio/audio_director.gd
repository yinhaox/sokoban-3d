class_name AudioDirector
extends Node

## Runtime-synthesized sound cues for the room, from issue #21.
##
## Seven short cues are generated with `AudioStreamGenerator` when the game
## boots, so the repository carries no binary audio file. Every cue lives in
## `CUES` with its duration, waveform, base frequency, envelope and minimum
## interval; `build_frames()` turns one entry into PCM frames and the tests read
## the same table, so a parameter outside its range fails the suite.
##
## One `AudioStreamPlayer` per cue keeps cues independent: a step never cuts a
## push, and a repeated cue can only restart its own voice. The SFX bus carries
## the players, while `apply_volumes()` maps the stored master and SFX settings
## onto the `AudioServer` buses. A linear volume of 0 mutes the bus; the cue still
## triggers and plays silently, so a muted player loses no feedback logic.
##
## `wire_button()` connects a `BaseButton.pressed` signal to the click cue.
## `_ready()` wires every button already in the tree and follows `node_added`, so
## a level card built at runtime gets the same click as a menu button.

signal cue_triggered(cue: String)

const MASTER_BUS := "Master"
const SFX_BUS := "SFX"

## design/audio.md `sample_rate_hz`; the generator works in float frames.
const SAMPLE_RATE := 44100
## Longer than the longest cue (400 ms) plus headroom for a replacing push.
const BUFFER_LENGTH_SECONDS := 0.5
## Peak of every normalized cue; overlapping cues stay below full scale.
const TARGET_PEAK := 0.5
const MS_PER_SECOND := 1000.0

const MIN_CUE_DURATION_MS := 40.0
const MAX_CUE_DURATION_MS := 400.0
const MIN_FREQUENCY_HZ := 40.0
const MAX_FREQUENCY_HZ := 2000.0
const MAX_MIN_INTERVAL_MS := 1000

const WAVEFORM_SINE := "sine"
const WAVEFORM_TRIANGLE := "triangle"
const WAVEFORM_NOISE := "noise"
const WAVEFORMS: Array[String] = [WAVEFORM_SINE, WAVEFORM_TRIANGLE, WAVEFORM_NOISE]

const CUE_STEP := "step"
const CUE_PUSH := "push"
const CUE_LAND := "land"
const CUE_UNDO := "undo"
const CUE_RESTART := "restart"
const CUE_WIN := "win"
const CUE_UI_CLICK := "ui_click"

## The cue table the acceptance asks for: one entry per wired event. `decay` is
## the exponential decay rate per second; attack and release are the linear
## edges of the envelope. `second_frequency_hz` on one cue makes two rising notes.
const CUES := {
	CUE_STEP: {
		"duration_ms": 60,
		"waveform": WAVEFORM_SINE,
		"frequency_hz": 220.0,
		"attack_ms": 3.0,
		"release_ms": 20.0,
		"decay": 28.0,
		"min_interval_ms": 60,
	},
	CUE_PUSH: {
		"duration_ms": 120,
		"waveform": WAVEFORM_NOISE,
		"frequency_hz": 120.0,
		"attack_ms": 6.0,
		"release_ms": 40.0,
		"decay": 16.0,
		"min_interval_ms": 80,
	},
	CUE_LAND: {
		"duration_ms": 140,
		"waveform": WAVEFORM_TRIANGLE,
		"frequency_hz": 95.0,
		"attack_ms": 2.0,
		"release_ms": 45.0,
		"decay": 20.0,
		"min_interval_ms": 120,
	},
	CUE_UNDO: {
		"duration_ms": 110,
		"waveform": WAVEFORM_SINE,
		"frequency_hz": 320.0,
		"attack_ms": 4.0,
		"release_ms": 30.0,
		"decay": 24.0,
		"min_interval_ms": 80,
	},
	CUE_RESTART: {
		"duration_ms": 150,
		"waveform": WAVEFORM_SINE,
		"frequency_hz": 260.0,
		"attack_ms": 5.0,
		"release_ms": 45.0,
		"decay": 14.0,
		"min_interval_ms": 120,
	},
	CUE_WIN: {
		"duration_ms": 340,
		"waveform": WAVEFORM_SINE,
		"frequency_hz": 523.25,
		"second_frequency_hz": 783.99,
		"attack_ms": 8.0,
		"release_ms": 70.0,
		"decay": 3.0,
		"min_interval_ms": 400,
	},
	CUE_UI_CLICK: {
		"duration_ms": 50,
		"waveform": WAVEFORM_SINE,
		"frequency_hz": 880.0,
		"attack_ms": 1.0,
		"release_ms": 16.0,
		"decay": 40.0,
		"min_interval_ms": 40,
	},
}

const NOISE_FILTER_BLEND := 0.35
const NOISE_MIX := 0.75
const TONE_MIX := 0.25
const TWO_NOTE_SPLIT_RATIO := 0.5

var _voices: Dictionary = {}
var _frame_cache: Dictionary = {}
var _last_played_ms: Dictionary = {}
var _log_cues: bool = false


func _ready() -> void:
	_ensure_bus(SFX_BUS)
	_create_voices()
	_connect_buttons_in_tree()
	if get_tree() != null:
		get_tree().node_added.connect(_on_node_added)


## Plays one cue unless its minimum interval has not elapsed. Returns true when
## the cue was accepted, false for an unknown name or a throttled repeat. The
## optional `now_ms` lets the tests drive the clock without waiting.
func play_cue(cue: String, now_ms: int = -1) -> bool:
	if not CUES.has(cue):
		push_warning("audio: unknown cue '%s'" % cue)
		return false
	var now := now_ms if now_ms >= 0 else Time.get_ticks_msec()
	if not _interval_elapsed(cue, now):
		return false
	_last_played_ms[cue] = now
	cue_triggered.emit(cue)
	if _log_cues:
		push_warning("audio: cue %s" % cue)
	_push_frames(cue)
	return true


## Logs one warning per accepted cue. Only the evidence run turns this on.
func set_logging(enabled: bool) -> void:
	_log_cues = enabled


## Applies the stored linear master and SFX volumes to the audio buses. 0 mutes
## the bus, so playback continues silently instead of being stopped.
func apply_volumes(master_linear: float, sfx_linear: float) -> void:
	_ensure_bus(SFX_BUS)
	_apply_bus_volume(MASTER_BUS, master_linear)
	_apply_bus_volume(SFX_BUS, sfx_linear)


## Connects one button's `pressed` signal to the click cue. A second call for the
## same button is a no-op.
func wire_button(button: BaseButton) -> void:
	if button == null or button.pressed.is_connected(_on_button_pressed):
		return
	button.pressed.connect(_on_button_pressed)


## The identical PCM frames for one cue, built once. Tests call this directly to
## check the duration and the normalized peak without an audio device.
static func build_frames(cue: String, sample_rate: int = SAMPLE_RATE) -> PackedVector2Array:
	if not CUES.has(cue) or sample_rate <= 0:
		push_warning("audio: cannot synthesize cue '%s'" % cue)
		return PackedVector2Array()
	var definition: Dictionary = CUES[cue]
	var frame_count := duration_frames(definition, sample_rate)
	var second := float(definition.get("second_frequency_hz", 0.0))
	if second <= 0.0:
		return _normalized(
			_render_note(definition, float(definition["frequency_hz"]), frame_count, sample_rate, hash(cue))
		)
	var split := maxi(int(round(frame_count * TWO_NOTE_SPLIT_RATIO)), 1)
	var first := _render_note(
		definition, float(definition["frequency_hz"]), split, sample_rate, hash(cue)
	)
	var second_note := _render_note(
		definition, second, frame_count - split, sample_rate, hash(cue) + 1
	)
	first.append_array(second_note)
	return _normalized(first)


## Frames a cue's duration produces at `sample_rate`.
static func duration_frames(definition: Dictionary, sample_rate: int = SAMPLE_RATE) -> int:
	var seconds := float(definition["duration_ms"]) / MS_PER_SECOND
	return maxi(int(round(seconds * float(sample_rate))), 1)


func _interval_elapsed(cue: String, now_ms: int) -> bool:
	if not _last_played_ms.has(cue):
		return true
	var interval := int((CUES[cue] as Dictionary)["min_interval_ms"])
	return now_ms - int(_last_played_ms[cue]) >= interval


func _push_frames(cue: String) -> void:
	if not _voices.has(cue):
		return
	var voice: Dictionary = _voices[cue]
	var playback := voice.get("playback") as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var frames := _frames_for(cue)
	if not playback.can_push_buffer(frames.size()):
		playback.clear_buffer()
	playback.push_buffer(frames)
	var player := voice.get("player") as AudioStreamPlayer
	if player != null and not player.playing:
		player.play()


func _frames_for(cue: String) -> PackedVector2Array:
	if not _frame_cache.has(cue):
		_frame_cache[cue] = build_frames(cue)
	return _frame_cache[cue]


func _create_voices() -> void:
	for cue: String in CUES:
		var player := AudioStreamPlayer.new()
		player.name = "Cue_%s" % cue
		player.bus = SFX_BUS
		var generator := AudioStreamGenerator.new()
		generator.mix_rate = float(SAMPLE_RATE)
		generator.buffer_length = BUFFER_LENGTH_SECONDS
		player.stream = generator
		add_child(player)
		player.play()
		var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
		if playback == null:
			push_warning("audio: no stream playback for cue %s; it plays silently" % cue)
		_voices[cue] = {"player": player, "playback": playback}


func _connect_buttons_in_tree() -> void:
	if not is_inside_tree():
		return
	for node: Node in get_tree().root.find_children("*", "Button", true, false):
		if node is BaseButton:
			wire_button(node as BaseButton)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		wire_button(node as BaseButton)


func _on_button_pressed() -> void:
	play_cue(CUE_UI_CLICK)


static func _ensure_bus(bus_name: String) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		return index
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, MASTER_BUS)
	return index


func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var clamped := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(index, clamped <= 0.0)
	AudioServer.set_bus_volume_db(index, SettingsModel.volume_to_db(clamped))


## One note of a cue: `frame_count` mono frames at `frequency_hz`, shaped by the
## cue's waveform, attack/release/decay envelope and a fixed noise seed.
static func _render_note(
	definition: Dictionary,
	frequency: float,
	frame_count: int,
	sample_rate: int,
	noise_seed: int
) -> PackedVector2Array:
	var frames := PackedVector2Array()
	var duration := float(frame_count) / float(sample_rate)
	var attack := float(definition["attack_ms"]) / MS_PER_SECOND
	var release := float(definition["release_ms"]) / MS_PER_SECOND
	var decay := float(definition["decay"])
	var waveform := str(definition["waveform"])
	var phase := 0.0
	var noise := RandomNumberGenerator.new()
	noise.seed = noise_seed
	var filtered := 0.0
	for index: int in frame_count:
		var elapsed := float(index) / float(sample_rate)
		phase = fmod(phase + TAU * frequency / float(sample_rate), TAU)
		filtered = lerpf(filtered, noise.randf_range(-1.0, 1.0), NOISE_FILTER_BLEND)
		var wave := _wave_sample(waveform, phase, filtered)
		var envelope := _envelope(elapsed, duration, attack, release, decay)
		frames.append(Vector2(wave * envelope, wave * envelope))
	return frames


static func _wave_sample(waveform: String, phase: float, filtered_noise: float) -> float:
	match waveform:
		WAVEFORM_TRIANGLE:
			return 2.0 / PI * asin(sin(phase))
		WAVEFORM_NOISE:
			return filtered_noise * NOISE_MIX + sin(phase) * TONE_MIX
	return sin(phase)


static func _envelope(
	elapsed: float, duration: float, attack: float, release: float, decay: float
) -> float:
	var value := 1.0
	if attack > 0.0:
		value = minf(1.0, elapsed / attack)
	if release > 0.0:
		value = minf(value, maxf((duration - elapsed) / release, 0.0))
	return maxf(value * exp(-decay * elapsed), 0.0)


static func _normalized(frames: PackedVector2Array) -> PackedVector2Array:
	var peak := 0.0
	for frame: Vector2 in frames:
		peak = maxf(peak, absf(frame.x))
	if peak <= 0.0:
		return frames
	var scale := TARGET_PEAK / peak
	for index: int in frames.size():
		var sample := frames[index].x * scale
		frames[index] = Vector2(sample, sample)
	return frames
