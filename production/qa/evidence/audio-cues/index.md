# Evidence: audio-cues

Run result: OBSERVED — at 1152x648 the real Settings screen shows the SFX slider at its middle value, 50%, with Master at 80%; a windowed run held open for five seconds logs the synthesized cue order step → push → undo → restart → land → win while it solves level-001, and the click cue is proven by the test suite's real button press.

## Screenshots

- `audio-cues-settings.png` — the real Settings screen opened on this branch with `--sfx-volume=0.5`: the Audio group shows Master volume 80% and SFX volume 50% with the SFX knob halfway along its 0–100 slider, plus the Display, Controls and Accessibility rows and the Back button. 1152x648, 41,657 bytes, produced by `capture_command`.

## Logs

- `check.log` — `python scripts/studio.py check` (exit 0; imports the project and parse-checks the four changed scripts: `src/audio/audio_director.gd`, `src/game/gameplay_controller.gd`, `src/main.gd`, `tests/run_tests.gd`).
- `test.log` — `python scripts/studio.py test` (exit 0; 855 checks pass, 222 more than the 633 of `save-settings-i18n`. The new block asserts seven cues with duration/waveform/frequency/envelope/interval in range, the two-note win pair, full-duration peak-normalized synthesis, the per-cue minimum interval, the 0..1 to dB mapping on the Master/SFX buses, silent-but-triggering playback at volume 0, unknown-cue refusal, every gameplay event wiring, and a real `Button.pressed` → click cue).
- `run.log` — `python scripts/studio.py run -- --screen=gameplay --script=right,right,undo,restart,right,right,down,right,up,up --quit-after=5 --audio-log --save=user://evidence-save-audio-run.json --fresh-save` (exit 0; the window stays open five seconds. The log records `audio: cue step`, `push`, `undo`, `restart`, `land`, `win` in that order as the scripted solve goes through the normal controller, undo and restart paths; repeated same-frame steps and pushes are suppressed by the minimum interval, so each cue appears once).
- `capture-settings.log` — `python scripts/studio.py capture --out production/qa/evidence/audio-cues/audio-cues-settings.png -- --screen=settings --sfx-volume=0.5 --save=user://evidence-save-audio.json --fresh-save` (exit 0; the helper verified the PNG is larger than 1024 bytes).

## Notes

- The run leaves the click cue out of `run.log` because a scripted run cannot produce a real pointer press; `test.log` proves the wiring with an actual `Button.pressed` signal and asserts one click cue per press. No cue was mocked or hand-written: every `audio: cue …` line comes from the accepted `AudioDirector.play_cue()` path and the real gameplay controller signals.
- `--sfx-volume=`, `--audio-log` and `--quit-after=` are capture/diagnostic aids added to `src/main.gd` beside the existing `--screen=`/`--script=`/`--save=` aids. They only apply to a capture or diagnostic boot, and `--script=` now also accepts `undo` and `restart` tokens so one run can reach those real events. A normal boot reads none of them.
- The screenshot was taken with a throwaway profile (`user://evidence-save-audio.json --fresh-save`), so the 50% SFX value is the capture override rather than a previous run's setting. The audio scene (`user://evidence-save-audio-run.json`) is also throwaway.
- No binary audio file exists or was added: all seven cues are produced by `AudioStreamGenerator` from the `AudioDirector.CUES` table at runtime, as issue #21 requires.
