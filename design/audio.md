# Design: audio

_Every sound is synthesized at runtime by project code with `AudioStreamGenerator`; the repository ships no audio file. Owned by the technical artist._

## Goals

Pillar P1 (readable at a glance) and P4 (playable by everyone). Sound confirms an action the player already sees, never carries information the screen does not show, and needs no external asset.

- A fixed seven-cue set synthesized from one testable table in `src/audio/audio_director.gd`, with no third-party sample, loop or library and no binary audio file.
- Every cue is audible in the default mix, distinct from its neighbours, and short enough not to mask the next action.
- Audio failure (no device, muted bus) never blocks play and never changes rules.

The page lands when the test suite proves the cue table, the minimum intervals and the button wiring, and a windowed run logs the six gameplay cues in order.

## Player experience

The player hears the room, not a soundtrack. A step is a 60 ms sine tap; a push is a short 120 Hz filtered-noise scrape; a crate settling on a plate adds a warm 95 Hz triangle thump; undo answers with a quick 320 Hz tone; restart resets the room with a 150 ms 260 Hz tone; the victory cue is a two-note rising pair; every button answers with a 50 ms 880 Hz click. A rejected move (wall bump) is silent in 1.0.

There is no music in 1.0 by design: a puzzle is easier to think in without a loop, and the asset constraint forbids licensed music. The master and SFX sliders act on the buses immediately; setting SFX to zero mutes every cue without a pop.

## Rules

**Cue table.** Seven cues, one row each in `AudioDirector.CUES`. `src/main.gd` creates the director under the boot scene (it is not an autoload), and `tests/run_tests.gd` reads the same table, so a parameter outside its range fails the suite. An unknown cue name warns and is refused.

**Synthesis.** `build_frames()` renders each cue at 44.1 kHz:

- waveform: `sine` = sin φ, `triangle` = 2/π·asin(sin φ), `noise` = one-pole-filtered white noise (blend 0.35) at 0.75 plus sine at 0.25;
- envelope: linear attack, linear release at the tail, exponential decay `exp(-decay·t)`, multiplied and clamped at zero;
- every cue is peak-normalized to 0.5 (about -6 dBFS), so overlapping cues stay below full scale;
- `win` renders two notes split at half the frames, 523.25 Hz then 783.99 Hz;
- the noise seed is fixed per cue (the cue name's hash), so the frames are deterministic; nothing is pitch-shifted at playback.

**Playback.**

- One `AudioStreamPlayer` with its own `AudioStreamGenerator` per cue on the `SFX` bus, so cue voices never cut each other. A retrigger appends to only its own buffer and clears it first if it is full.
- Every cue has `min_interval_ms`; a repeat inside that window returns false and is dropped, never queued or stacked.
- Events wired once: `step` accepted non-push move, `push` accepted push, `land` crate settles on a goal plate (same frame as `push`, both play), `undo` accepted undo, `restart` level restart, `win` level completed (after `win_delay_seconds` 0.4 s, or immediately under reduced motion), `ui_click` any `Button.pressed`. The director wires buttons already in the tree and follows `node_added`, so runtime-built level cards click too.
- No other audio plays in 1.0: a rejected move, the deadlock warning, victory stars, unlock and focus movement are silent. Every button press gets the same `ui_click`, including Back. Ambient loop, music and voice are out of scope, and every cue is non-positional.
- Sounds never change timing: no gameplay code waits on audio. Playback is fire-and-forget.
- **Replacement path.** A future story replaces the cue table or the whole director; gameplay only emits `cue_requested(cue)` and never calls a player directly, so recorded files or another synthesizer can replace playback without touching gameplay code. Keep the seven cue names and only the director and its assets change; renaming them also touches `src/game/gameplay_controller.gd` and the tests.

**Mixing and volume.**

- Bus layout: `Master` with one child `SFX` created at boot; the seven cue players send to `SFX`. No `Music` bus is created in 1.0.
- Slider `0..1` maps to `linear_to_db(max(value, 0.0001))`; `0` mutes that bus. Master and SFX gains multiply through the bus tree.
- Defaults `master_volume` 0.80 and `sfx_volume` 0.90 come from [settings-and-save.md](settings-and-save.md); `main._apply_audio()` reapplies them at boot and after every settings change, so a row needs no Apply button.
- Setting SFX to 0 mutes the bus but does not stop playback: the cue still triggers and plays silently, so mute never removes feedback logic.

**Silence and failure.**

- If a generator playback is unavailable, the director warns for that cue and the cue is silent; play continues normally.
- The game is fully playable muted: every cue has a visual counterpart already on screen, and no rule, state or result exists only in audio. This is restated in [accessibility.md](accessibility.md).
- On Web the audio context stays suspended until the first user gesture; the game adds no "click to enable audio" overlay.

**Licence.**

- No audio file is committed or shipped; all cues are frames generated by repository code. That code is covered by the repository licence in [release.md](release.md), and no sample pack, model output or third-party loop is used.
- The credits page needs no audio attribution because no audio asset ships; if recorded cues later replace synthesis, their licence and attribution must be decided before shipping and added there.

## Numbers and tuning

_Cue values are the constants in `src/audio/audio_director.gd` that the tests enforce; volume defaults come from [settings-and-save.md](settings-and-save.md)._

| Cue | Trigger | Duration (ms) | Waveform | Frequency (Hz) | Attack / release (ms) | Decay (1/s) | Min interval (ms) |
|---|---|---|---|---|---|---|---|
| `step` | accepted step | 60 | sine | 220 | 3 / 20 | 28 | 60 |
| `push` | accepted push | 120 | noise | 120 | 6 / 40 | 16 | 80 |
| `land` | crate lands on goal | 140 | triangle | 95 | 2 / 45 | 20 | 120 |
| `undo` | accepted undo | 110 | sine | 320 | 4 / 30 | 24 | 80 |
| `restart` | level restart | 150 | sine | 260 | 5 / 45 | 14 | 120 |
| `win` | level completed | 340 | sine | 523.25 then 783.99 | 8 / 70 | 3 | 400 |
| `ui_click` | `Button.pressed` | 50 | sine | 880 | 1 / 16 | 40 | 40 |

| Value | Default | Range | Notes |
|---|---|---|---|
| `sample_rate_hz` | 44100 | fixed | Hz; `AudioStreamGenerator.mix_rate`; frames are mono doubled to stereo |
| `buffer_seconds` | 0.5 | fixed | s; longer than the longest cue plus headroom |
| `target_peak` | 0.5 | fixed | linear peak, about -6 dBFS per cue |
| `cue_duration_ms` | per table | 40 to 400 | ms; enforced on every entry |
| `cue_frequency_hz` | per table | 40 to 2000 | Hz; enforced on every entry |
| `min_interval_ms` | per table | 0 to 1000 | ms; enforced on every entry |
| `master_volume_default` | 0.80 | 0.00 to 1.00 | linear, from settings-and-save.md |
| `sfx_volume_default` | 0.90 | 0.00 to 1.00 | linear, from settings-and-save.md |

## Edge cases

- **The player pushes a crate onto the last goal.** `push` and `land` start in the same frame on separate voices; with motion on, `win` waits for `win_delay_seconds` 0.4 s, so it clears the 140 ms `land` cue. Under reduced motion the win cue starts immediately and overlaps `land`; both are short and peak-normalized, so neither cuts the other.
- **Undo is spammed.** The 80 ms interval drops repeats inside the window, so the player hears one rewind per window instead of a stutter.
- **A direction is held down a corridor.** Each accepted move requests `step`; the 60 ms interval suppresses commits closer than that, so the rhythm follows the move animation rather than stacking.
- **SFX is set to 0.** The bus is muted, every cue still triggers and plays silently, and no click or pop is heard because gain is applied at the bus.
- **Two cues start at once.** Different voices and buffers mean neither cuts the other; `push` and `land` are the common pair.
- **The audio device is missing or a generator playback is null.** One warning per cue, silent cues, play continues, and settings still show their sliders.
- **The Web tab is backgrounded.** The browser suspends audio; on return the next cue plays, and nothing is queued or replayed.
- **A cue sounds different between runs.** That is a bug, not variation: the noise seed is fixed per cue, so identical frames are built every run.

## Open questions

1. **Music in 1.0 (creative director / technical artist, proposal).** None ships and no `Music` bus is created. Decision needed: keep audio cue-only (recommended, matches the seven-cue scope), or add a generated ambient loop with a `Music` bus and slider.
2. **Positional audio (technical artist, proposal).** All cues are non-positional. Decision needed: whether crate sounds should come from the crate's world position in 1.0, which needs `AudioStreamPlayer3D` and a listener on the camera.
3. **Loudness standard (technical artist, proposal).** Per-cue peak normalization to 0.5 is the only loudness rule; there is no integrated LUFS target. Decision needed: whether the store build needs an LUFS pass for the SFX bus.

## Links

- Related systems: [overview.md](overview.md), [ui-flow.md](ui-flow.md), [settings-and-save.md](settings-and-save.md), [accessibility.md](accessibility.md), [release.md](release.md)
- Stories: [audio-cues](../production/stories/audio-cues.md)
- Evidence: [audio-cues](../production/qa/evidence/audio-cues/index.md)
