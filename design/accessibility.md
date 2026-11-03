# Design: accessibility

_How the game stays playable for colourblind, low-vision, motor-impaired and motion-sensitive players without a separate mode. Owned by the game designer._

## Goals

Pillar P4 (playable by everyone). Accessibility is a set of properties of the existing screens, not an option screen bolted on: if the default build is unreadable for a player, no toggle list fixes it.

- No rule, state or result is communicated by colour alone; shape, position, icon and text carry the same information.
- Every screen and every gameplay action is reachable with a keyboard or a gamepad, with a visible focus state and no time limit.
- The player can make the game bigger, calmer and quieter from Settings, and each of those changes is visible in play.

The page lands when a reviewer completes level 3 with the game muted, at 150% UI scale, in deuteranopia mode, with reduced motion on, and can still tell a crate from a plate, a locked level from an unlocked one, and a 2-star run from a 3-star run.

## Player experience

A colourblind player sees the crate as a beveled cube with a raised cross, the empty plate as a flat ring, and a filled plate as a ring with a lit check. They never need to compare hues to know whether the last push worked.

A low-vision player raises UI scale to 150%: text stays inside its containers, the level select shows three larger cards per row instead of four, and the HUD strip grows while the room keeps most of the screen. The room itself can be zoomed with the camera, and the same key that zoomed in zooms back out.

A motion-sensitive player turns on reduced motion: camera quarter turns and crate slides are instant, wall fades are instant, and the victory stars appear without animation. A player with a motor impairment plays entirely with the keyboard or a single gamepad, because every control is focusable and no action requires two simultaneous inputs or rapid taps. A player with no audio plays normally, because every sound has a visual counterpart already on screen.

## Rules

**Colour independence.**

- Every gameplay distinction is carried by shape, icon, position or text as well as colour:
  - crate: cube with a raised cross on top; crate on plate: the cross plus a lit ring;
  - empty plate: flat ring inset in the floor; filled plate: ring with an emissive check;
  - player: capsule with a facing nub; focused control: outline ring, not a fill swap;
  - locked level card: lock icon plus dimmed card plus "Locked" text; unlocked: no icon;
  - stars: 1-3 filled star shapes plus the number; empty stars are outlines.
- The dead-end warning is a text chip with two buttons, not a colour flash.
- HUD counters are text with labels; colour is never the only difference between "on plate" and "off plate" counts.

**Palettes.**

- Four colour modes: `off`, `deuteranopia`, `protanopia`, `tritanopia`. Each mode swaps palette entries in `resources/palette.tres`; shapes never change, so a mode cannot remove information.
- Colour modes are previewed on the settings screen with the actual meshes, so the player chooses by looking rather than by name.
- Text contrast is at least `contrast_text_ratio` (4.5:1) against its background; large text and meaningful graphics at least `contrast_graphics_ratio` (3:1), measured on the palette pairs, not eyeballed.
- Focus rings use a hue and a value step from the surrounding UI, so they remain visible in every palette.

**Text and UI size.**

- Minimum body text is `font_body_px` (18 px) at 100% scale; no interactive label is smaller than 16 px at any scale.
- UI scale offers 100%, 125% and 150%; at 150% every screen still fits 1152x648 without clipping, scrolling or overlapping, and the level select grid reduces its column count.
- Text wraps with `autowrap_mode` and grows containers; the UI never ellipsizes a rule or a button label.
- Line height is at least `line_height_ratio` (1.4) of the font size for body text.
- Chinese text uses a `SystemFont` fallback chain so it renders without shipping a font file; a missing CJK glyph is a release blocker, not a cosmetic issue.
- Numbers stay monospaced in the HUD timer and counters so they do not jitter the layout.

**Keyboard and gamepad.**

- Every screen is fully operable with keyboard and with gamepad, with no pointer-only control; the pointer is an optional shortcut.
- Focus is always visible, always inside the current screen, and always lands on a sensible default when a screen opens.
- Menu navigation keys are fixed and not remappable, so no remap can lock a player out of a menu; gameplay keys are remappable per [input-and-controls.md](input-and-controls.md).
- No action requires two simultaneous inputs, rapid repeated taps, or holding for longer than `max_hold_seconds` (0.5 s). Holding a direction to repeat is optional: single presses always move one tile.
- The pause menu is reachable at any time during play, and pausing is never penalized.

**Motion, flashing and timing.**

- Reduced motion sets every tween, camera rotation, camera zoom and fade duration to 0.0 and disables the victory star animation; the hint chips and focus still appear.
- There is no screen shake, no camera bob, no idle motion and no full-screen flash at any setting.
- Flashing is limited to at most `max_flashes_per_second` (3) and no more than 25% of the screen area; the game uses no flashing effects in 1.0.
- Camera pitch stays at 40 degrees and the camera never spins freely, which keeps the room stable for motion-sensitive players.
- Levels have no time limit and the timer is informational only, per [core-rules.md](core-rules.md).

**Audio independence.**

- Every sound cue in [audio.md](audio.md) has a visual counterpart on screen; the game is fully playable muted, and the dead-end warning is visible as a chip even when it is also audible.
- No subtitle system is needed in 1.0 because there is no voice or music with lyrics.

**Out of scope for 1.0.** Screen-reader output through OS accessibility APIs, dyslexic-friendly font substitution, and a colour-blindness simulator inside the game are not shipped; the text-first UI and the palette modes are the 1.0 path. The reason is recorded in Open questions.

## Numbers and tuning

_来源约定：issue #1、project.godot 或本页引用的既有页面已经固定的值为事实；其余数值是 proposal（提案），影响手感或发布门槛的 proposal 在 Open questions 中列出。_

| Value | Default | Range | Notes |
|---|---|---|---|
| `font_body_px` | 18 | 16 to 24 | pixels at 100% UI scale; minimum body text |
| `font_min_px` | 16 | 14 to 20 | pixels; no label below this at any scale |
| `line_height_ratio` | 1.40 | 1.30 to 1.60 | ratio of line height to font size |
| `ui_scale_steps` | 1.00, 1.25, 1.50 | 1.00 to 1.50 | multiplier steps offered in Settings |
| `contrast_text_ratio` | 4.5 | 4.5 to 7.0 | WCAG AA normal text |
| `contrast_graphics_ratio` | 3.0 | 3.0 to 4.5 | WCAG AA non-text |
| `focus_ring_px` | 3 | 2 to 4 | pixels, from [input-and-controls.md](input-and-controls.md) |
| `max_flashes_per_second` | 3 | 1 to 3 | flashes per second; 0 in 1.0 |
| `flash_area_max_ratio` | 0.25 | 0.10 to 0.25 | ratio of screen area a flash may cover |
| `max_hold_seconds` | 0.5 | 0.3 to 1.0 | seconds; no action holds longer |
| `reduced_motion_duration_seconds` | 0.0 | 0.0 to 0.0 | all tween durations under reduced motion |
| `hud_strip_opacity` | 0.85 | 0.70 to 1.00 | HUD background opacity, text stays 4.5:1 |
| `color_mode_count` | 4 | 4 to 4 | off plus three colourblind palettes |
| `min_target_px` | 44 | 44 to 64 | pixels, from [ui-flow.md](ui-flow.md) |

## Edge cases

- **Deuteranopia mode plus 150% UI scale on a 15x15 level.** The room still fits by camera fit; the grid drops to three cards per row; crate and plate shapes are unchanged.
- **The system has no CJK font installed.** Chinese text renders as tofu boxes. This is a release blocker for the ZH locale and is resolved by an approved font fallback or a bundled font (Open question 2), not by accepting the boxes.
- **The player uses unlimited undo and reduced motion.** Undo is instant; the deadlock chip still appears long enough to read, because its duration is independent of motion settings.
- **The player turns warnings off in Settings.** The dead-end chip is hidden, but the rule still exists and undo/restart remain available; the setting is labelled as a difficulty aid, not as a rule change.
- **A focus ring is invisible against the level card art.** The theme draws a two-tone ring (light outer, dark inner) so it survives every palette; QA checks it in all four colour modes.
- **A gamepad is the only device and a modal opens.** Focus moves into the modal and is trapped there until it closes; the d-pad reaches every button.
- **The player is colourblind and also mute-audio.** The crate/plate distinction is shape-based, so the game is still fully readable.
- **Reduced motion is toggled while a camera tween runs.** The running tween completes instantly at the next frame; no camera keeps sliding after the toggle.
- **The player needs a bigger font than 150%.** Not supported in 1.0; the recommendation is OS display scaling plus the camera zoom, and the gap is in Open questions.

## Open questions

1. **Screen-reader support (game designer / technical director, proposal).** Not in 1.0 because Godot's OS accessibility bridge is limited. Decision needed: is "text-first UI with no image-only labels" enough for the commercial bar, or does 1.0 need a Godot accessibility addon or a custom spoken-hint system?
2. **Bundled CJK font (creative director / release manager, proposal).** The plan uses `SystemFont` fallbacks to avoid shipping a font. Decision needed: whether an OFL-licensed font such as Noto Sans SC is bundled for reliable Chinese on Linux and Web, which adds a licensed asset outside the "no external art" rule and must be approved.
3. **Text size beyond 150% (game designer, proposal).** UI scale stops at 150%. Decision needed: whether 200% is required, which forces layout work on the level select and HUD.
4. **Warnings-off setting (game designer, proposal).** `show_warnings` can hide the dead-end chip. Decision needed: whether hiding a warning is acceptable in the default build, since a struggling player who turns it off loses the only in-game hint.
5. **Accessibility evidence method (qa lead, proposal).** Evidence for colour modes and reduced motion is a capture plus a manual checklist. Decision needed: whether the studio must capture each colour mode as a screenshot per story or accept one capture plus the palette test.

## Links

- Related systems: [overview.md](overview.md), [core-rules.md](core-rules.md), [input-and-controls.md](input-and-controls.md), [ui-flow.md](ui-flow.md), [camera-and-presentation.md](camera-and-presentation.md), [settings-and-save.md](settings-and-save.md), [audio.md](audio.md), [release.md](release.md)
- UI rules: `.dsh/rules/ui.md`
- Stories: `production/stories/` (none yet)
