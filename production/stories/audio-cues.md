---
id: audio-cues
status: done
updated: 2026-11-03
---

# Story: Procedural audio cues tied to gameplay

## Context

The game is silent: a move, a push, a crate landing on a plate, undo, restart,
a win and every button press have no sound. This story adds the short cues the
room needs, synthesized at runtime by project code, and applies the stored
master and SFX volumes to the audio buses.

Issue #21 asks for the seven cues `src/audio/audio_director.gd` must synthesize
with `AudioStreamGenerator` and for no binary audio file in the repository, with
the volume following the existing settings screen. Reference design:
`design/audio.md` (sound set and mixing rules) and
`design/settings-and-save.md` (master/SFX settings). Source: issue #21.

**Design divergence recorded here.** `design/audio.md` "Generation" and
"Open questions" 2 currently specify a Python WAV generator and committed WAV
files, with runtime synthesis explicitly left open. Issue #21 decides that
question the other way: the cues are synthesized at runtime and no binary audio
file is introduced. This story follows the issue. `design/audio.md` is outside a
story worker's write boundary, so a design-doc follow-up must update its
Generation rule and close Open question 2.

**Cue list.** The issue headline names 脚步 / 推动 / 落位 / 胜利 / 撤销 / 错误 /
界面点击 (seven), while the acceptance list wires 移动一步 / 推箱 / 箱子落到目标 /
撤销 / 重开 / 胜利 / 按钮点击 (seven). The numbered acceptance list is the
testable contract and it constrains the generator to seven cues, so this story
synthesizes exactly `step`, `push`, `land`, `undo`, `restart`, `win`,
`ui_click`. The headline's 错误 (rejected move) is not one of the seven; it is
listed as a follow-up candidate below rather than added as an eighth cue.

## Acceptance

- [x] `src/audio/audio_director.gd` (held by `src/main.gd`, no autoload needed)
      synthesizes seven short cues at runtime with `AudioStreamGenerator`; no
      binary audio file is added to the repository.
- [x] Every cue has explicit parameters in a testable table: duration 40–400 ms,
      waveform, base frequency and envelope (attack/release/decay); repeated
      triggers of one cue are limited by a minimum interval and never stack.
- [x] Events are wired once each: move a step, push a crate, crate lands on a
      goal, undo, restart, win, button click. The win cue is a two-note rising
      pair.
- [x] The `settings` master and SFX volumes apply live to the `AudioServer`
      buses; a volume of 0 mutes output while the cue still triggers.
- [x] `tests/run_tests.gd` asserts that the seven cues exist and every parameter
      is in range, that the minimum interval works, that the 0..1 to dB
      conversion is correct, and that an unknown event does not crash.
- [x] Screenshot: the Settings screen with the SFX slider at 50%. A `run_command`
      log of about five seconds records the cue trigger order (there is no audio
      file to screenshot).
- [x] `check_command` and `test_command` pass and the evidence index reports
      `Run result: OBSERVED — …`.

## Out of scope

- Background music, an ambient loop, positional/3D audio, audio export and any
  external or committed audio asset (issue #21 "Out of scope").
- A rejected-move (错误) cue: the headline names it but the acceptance list
  caps the set at seven and names restart instead. Follow-up story candidate.
- `design/`, `project.godot` (no autoload or bus-layout edit), `studio.yaml`,
  `scripts/`, `addons/` and the existing settings/save model stay untouched.

## Evidence

- `production/qa/evidence/audio-cues/index.md` — `Run result: OBSERVED —` the real
  Settings screen with SFX volume at 50% (`audio-cues-settings.png` from
  `capture_command`) and a five-second windowed run (`run.log`) logging
  `audio: cue step`, `push`, `undo`, `restart`, `land`, `win` in order;
  `check.log`, `test.log` (855 checks, 222 new) and `capture-settings.log` are
  beside them.

## Notes

- **Cue table.** `AudioDirector.CUES` holds one entry per cue:
  `step` 60 ms sine 220 Hz (interval 60 ms), `push` 120 ms filtered noise
  120 Hz (80 ms), `land` 140 ms triangle 95 Hz (120 ms), `undo` 110 ms sine
  320 Hz (80 ms), `restart` 150 ms sine 260 Hz (120 ms), `win` 340 ms sine
  523.25 Hz rising to 783.99 Hz (400 ms), `ui_click` 50 ms sine 880 Hz (40 ms).
  Every entry carries `duration_ms`, `waveform`, `frequency_hz`, `attack_ms`,
  `release_ms`, `decay` and `min_interval_ms`; the tests read the same table.
  The table lives in the script rather than `assets/data/` because `assets/` is
  outside a story worker's write boundary and the acceptance asks for the table
  in the director.
- **Synthesis.** `build_frames()` renders each cue from its table entry with a
  linear attack/release and exponential decay, fixed noise seeds per cue, and a
  peak normalization to 0.5 so overlapping cues stay below full scale. The win
  cue renders two half-length notes with the second frequency above the first.
  The director keeps one `AudioStreamPlayer` with its own `AudioStreamGenerator`
  per cue, so a step never cuts a push; a retrigger accepted after the minimum
  interval clears and replaces that cue's own buffer, which is why repeats
  cannot stack.
- **Event wiring.** `GameplayController` emits `cue_requested(cue)` from the
  accepted step/push (`_on_move_committed`), the crate-on-goal case, an accepted
  `undo()`, `restart_level()` and `_emit_victory()`; `main` connects that signal
  to `AudioDirector.play_cue`. Click cues come from `AudioDirector` itself:
  `_ready()` wires every `Button` already in the tree and `SceneTree.node_added`
  wires cards built later, so each `pressed` signal requests one `ui_click`.
- **Volume.** `AudioDirector.apply_volumes(master, sfx)` creates the `SFX` bus
  beside `Master` and sets both with `SettingsModel.volume_to_db()`; a linear 0
  mutes the bus (`is_bus_mute`) while the cue still triggers and plays silently.
  `main._apply_audio()` calls it at boot and after every settings change, so the
  sliders take effect live. Moving this mapping into the audio director kept one
  conversion function and made the bus state directly testable.
- **Evidence aids.** `src/main.gd` gained `--sfx-volume=`, `--audio-log` and
  `--quit-after=` beside the existing capture aids, and `--script=` now accepts
  `undo`/`restart` tokens, so one timed run can reach those real events. They
  apply only to a capture or diagnostic boot. The run log shows six of the seven
  events; the click cue is asserted in `test.log` with a real `Button.pressed`
  because a scripted run cannot produce pointer input.
- **Checks.** `tests/run_tests.gd` gains 222 assertions in an appended block and
  one call line in `_init`. The suite passes at 855 checks.
- **Follow-ups.** (1) Update `design/audio.md` Generation and close its Open
  question 2 for runtime synthesis, since this story cannot edit `design/`.
  (2) Add the rejected-move 错误 cue as its own story if the owner wants eight
  cues; it needs a matching acceptance range and a test for the cue count.
- **Boundary.** No `assets/`, `design/`, `project.godot`, `studio.yaml`,
  `scripts/` or `addons/` file changed; the engine-generated `.uid` files were
  left uncommitted, as the repository does not track them.
