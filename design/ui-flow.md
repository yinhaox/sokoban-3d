# Design: UI flow

_Every screen the player sees, how they move between them, and the one modal that can interrupt a level. Owned by the game designer._

## Goals

Pillars P1 (readable at a glance) and P4 (playable by everyone). The UI must answer "where am I, what is the goal, what did I just do" without covering the room, and every screen must be fully usable with a keyboard and a gamepad.

- Seven screens plus modals: Main Menu, Level Select, Gameplay (HUD), Pause, Victory, Settings, Credits, with Restart Confirm, Leave Confirm and the error panel as modals or overlays over them.
- No screen requires reading a paragraph to act; every screen has one obvious default action and one obvious way back.
- All text comes from translation keys, all sizes from the theme, and all navigation from focus neighbours, so localization and accessibility are properties of the system, not per-screen patches.

The page lands when a reviewer can walk the full graph with keyboard only and gamepad only, and every destructive action (restart, quit to menu) asks once before it happens.

## Player experience

The player launches the game and lands on a calm main menu: the title, a Continue or New Game button, Level Select, Settings, Credits, Quit. The room from the last level is not previewed; the background is the same dark clear colour as the game.

In Level Select, cards for 20 levels sit in a four-column grid. Completed cards show stars and best moves; locked cards show a lock and their number, never a spoiler name. Moving focus highlights a card and shows its name, difficulty label and par in a side panel.

In a level, the HUD is a thin strip at the top: level name, moves, pushes, timer, a goal counter, and Undo / Restart / Pause buttons at the right. The room keeps at least 60% of the screen height. Undo shows its remaining count. A dead-end warning chip appears near the HUD, never over the room's centre.

Pause opens a translucent panel over the frozen room: Resume, Restart, Settings, Level Select, Main Menu. The timer stops and the room is not reachable. Victory opens after the last crate settles: stars animating in, moves against par, pushes, time, then Next Level, Retry, Level Select. Restart and "leave the level" both ask "Discard this attempt?" with Cancel focused.

## Rules

**Screen graph.** Exactly these screens and transitions exist in 1.0.

```text
Boot -> Main Menu -> Level Select -> Gameplay
                 \-> Settings  \-> Settings (from Pause)
                 \-> Credits
Gameplay -> Pause -> (Resume | Restart | Settings | Level Select | Main Menu)
Gameplay -> Victory -> (Next Level | Retry | Level Select)
Pause -> Restart Confirm (modal)
Pause -> Leave Confirm (modal)
```

- Boot resolves the save and the level list, then shows Main Menu. There is no splash animation and no "press any key" screen.
- Main Menu buttons: Continue (only when a save exists and a next level is known), New Game (only on first run, leads to Level 001), Level Select, Settings, Credits, Quit (desktop only; hidden on Web).
- Main Menu shows `v<application_version>` in a corner, matching the release rules in [release.md](release.md); it is a plain text label, not a selectable control.
- Level Select always shows all `level_count` cards; locked ones are dimmed with a lock icon and their number visible. A card shows stars, best moves and best time when completed.
- Continue loads the lowest-numbered unlocked, uncompleted level; when every level is complete it loads the last level.
- Selecting a level the player cheated open with `--unlock-all` is allowed; the card still displays the lock until it is completed.
- Gameplay HUD elements, left to right: level name, moves, pushes, goal counter `filled/total`, timer, then Undo, Restart, Pause buttons. Undo shows `remaining/limit`, or an infinity glyph with unlimited undo.
- HUD never covers the room: it is a top strip of `hud_strip_height` with a transparent background over the clear colour; no rule-critical cell is ever under a HUD control at default zoom.
- The deadlock chip is one line plus two buttons (Undo, Restart), positioned below the HUD strip, and auto-dismisses after `deadlock_chip_seconds` from [core-rules.md](core-rules.md).
- Pause stops the timer, the tile tweens are allowed to finish, and the camera keeps its last pose. Resume restores the gameplay context without replaying consumed inputs.
- Victory locks gameplay input, shows stars (1-3), moves and par, pushes, elapsed time, and a "New best" marker when the run set a record. Next Level is hidden on level 20; Retry always restarts the same level.
- Restart Confirm appears only when the attempt has moves, per [core-rules.md](core-rules.md), and focuses Cancel. Leave Confirm appears when the player leaves a level with moves from Pause or Quit; leaving at `moves == 0` is immediate.
- Settings and Credits are reachable from Main Menu and from Pause; opening Settings from Pause keeps the pause context underneath, closing it returns to Pause.
- Exactly one modal is open at a time. A second destructive request while a modal is open is ignored, not queued.
- All transitions between screens use the same `screen_fade_seconds` fade; modal open and close use `modal_scale_seconds`.

**Layout and focus.**

- All layout uses containers and anchors; no absolute `position` for children of a container (`.dsh/rules/ui.md`).
- Focus order follows the visual order of the screen and is set with `focus_neighbor_*`; opening a screen focuses the default button, and Escape/B always go back exactly one level.
- Every focusable control has a visible focus ring from the theme, at least `focus_ring_px` wide, with a shape change (outline plus brighter fill), never colour alone.
- Interactive targets are at least `min_target_px` square.
- Text is set in translation keys via `tr()`; the UI never formats an English string with concatenation. Numbers use locale-appropriate formatting for time and count.
- The layout must not wrap or clip at the minimum supported window (1152x648) at `ui_scale_max`; text uses `autowrap_mode` and containers, and the level select grid drops to fewer columns rather than overflowing.
- UI never mutates gameplay state: buttons emit intent signals that the owning screen or gameplay controller handles (`.dsh/rules/ui.md`).

**Localization.**

- Two locales ship in 1.0: `en` and `zh`. The default locale follows the OS language, falls back to `en`, and is overridable in Settings.
- Key convention: `ui_<screen>_<element>`, `level_NNN_name`, `level_NNN_difficulty`, `settings_<group>_<label>`, `record_<label>`, `error_<code>`. Keys are snake_case and never renamed once referenced by code or data.
- The level select difficulty labels come from the mapping in [level-progression.md](level-progression.md); raw numbers are never the only label.
- Fonts: the UI uses Godot's default font for Latin and `SystemFont` fallbacks for Chinese (see [accessibility.md](accessibility.md)); no font file from outside the repository is shipped in 1.0.

**Error and empty states.**

- No levels found: Level Select shows an empty state with a retry button and a one-line explanation; Main Menu still works.
- A level failed validation: its card reads "Unavailable" and is not selectable; the load report is logged, per [level-format.md](level-format.md).
- Corrupt or newer-than-supported save: Main Menu shows one dismissible notice and the game starts a fresh profile; details in [settings-and-save.md](settings-and-save.md).
- Quitting is not possible on Web: the Quit button is hidden and the browser tab is the exit.

## Numbers and tuning

_来源约定：issue #1、project.godot 或本页引用的既有页面已经固定的值为事实；其余数值是 proposal（提案），影响手感或发布门槛的 proposal 在 Open questions 中列出。_

| Value | Default | Range | Notes |
|---|---|---|---|
| `hud_strip_height_px` | 56 | 40 to 80 | pixels at 100% UI scale; room stays at least 60% of height |
| `level_card_size_px` | 220x110 | 160x90 to 260x140 | pixels per level select card |
| `level_select_columns` | 4 | 3 to 5 | cards per row at 1152 px; fewer when scaled up |
| `min_target_px` | 44 | 44 to 64 | pixels; minimum interactive target edge |
| `font_body_px` | 18 | 16 to 24 | pixels at 100% UI scale; minimum 16 |
| `font_title_px` | 64 | 40 to 80 | pixels at 100% UI scale |
| `ui_scale_min` | 1.00 | 0.75 to 1.00 | multiplier; below 1.0 is not offered |
| `ui_scale_max` | 1.50 | 1.25 to 2.00 | multiplier |
| `screen_fade_seconds` | 0.15 | 0.10 to 0.30 | seconds for screen-to-screen fade |
| `modal_scale_seconds` | 0.15 | 0.10 to 0.25 | seconds for modal open and close |
| `toast_seconds` | 2.5 | 1.5 to 5.0 | seconds a toast stays |
| `victory_panel_delay_seconds` | 0.4 | 0.0 to 1.0 | from the last crate landing, from [core-rules.md](core-rules.md) |
| `deadlock_chip_seconds` | 3.0 | 1.0 to 6.0 | from [core-rules.md](core-rules.md) |
| `max_open_toasts` | 1 | 1 to 3 | a second toast replaces the first |
| `pause_resume_key` | Escape, P | n/a | toggle within gameplay context |

## Edge cases

- **The player opens Pause, then Settings, then presses Escape twice.** First Escape closes Settings back to Pause; second closes Pause back to the game. No input is replayed to the game.
- **The player presses Restart twice quickly.** The confirm modal opens once; the second request is ignored while it is open.
- **Leaving a level with 0 moves.** No confirmation; the level select opens immediately and no "attempt discarded" toast appears.
- **Victory appears while the player holds a direction.** The held input is released and no queued move runs; the room stays in its completed pose.
- **The last level is completed.** Victory shows Level Select and Retry; there is no Next Level button and no empty screen.
- **All levels are complete and Continue is pressed.** The last completed level loads; the main menu does not show an empty state.
- **A modal is open and the window is resized.** The modal stays centred and the room is refitted by camera rules; no control leaves the viewport.
- **A translation key is missing.** The UI shows the key text and a warning is logged; the screen stays usable and the missing key is visible in QA, per [settings-and-save.md](settings-and-save.md) error rules.
- **The player has unlimited undo on.** The HUD shows the infinity glyph and the Undo button never disables except with an empty history.
- **The level select grid would overflow at 150% scale.** The grid drops from four to three columns rather than clipping; the card list scrolls with the focus following the selected card.

## Open questions

1. **Continue versus New Game on first run (game designer, proposal).** Main Menu shows Continue only when a save exists; New Game appears only on first run to avoid a destructive button. Decision needed: confirm that no "delete profile" button exists in 1.0 outside Settings.
2. **Leaderboard-free records (producer, proposal).** Records are local to the save; there is no online board in 1.0. Decision needed: confirm, because the store copy must not imply online competition.
3. **In-level level info (game designer, proposal).** No panel shows the level's author or notes during play; author appears in Credits and in the level select info panel. Decision needed: whether credits for level authors belong on the card.
4. **Web quit behaviour (producer, proposal).** Quit is hidden on Web, leaving the tab as the only exit. Decision needed: whether a "Pause on visibility change" rule is required for Web, since the timer otherwise keeps running in a background tab.

## Links

- Related systems: [overview.md](overview.md), [core-rules.md](core-rules.md), [input-and-controls.md](input-and-controls.md), [level-progression.md](level-progression.md), [settings-and-save.md](settings-and-save.md), [accessibility.md](accessibility.md), [audio.md](audio.md)
- UI rules: `.dsh/rules/ui.md`
- Stories: `production/stories/` (none yet)
