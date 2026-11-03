# Design: input and controls

_How the player drives the game: one input action vocabulary, two devices, a remap screen that cannot break navigation. Owned by the game designer._

## Goals

Pillars P2 (one push at a time) and P4 (playable by everyone). Input must be boring and reliable: every action has a default that a player can find without reading a manual, and every action except menu navigation can be rebound.

- One action vocabulary used by gameplay and UI, so a remap can never leave a screen unreachable.
- Keyboard and gamepad are first-class on every screen from main menu to victory panel.
- A remap is atomic: it either fully takes effect or is refused with a visible reason; it never leaves two actions on one binding.

The page lands when a headless test can assert the action list, each action's default bindings and the remap-conflict rule, and a manual run can play levels 1-3 with keyboard only and with gamepad only.

## Player experience

The player opens the game, presses arrows or the left stick, and the menu selection moves. Enter or the south face button starts. In a level, arrows, WASD, the d-pad or the left stick step the player; the crate moves with the same input. Holding a direction keeps walking after a short pause, so a long corridor does not need thirty presses. `Z` or the west face button undoes. `R` or the north face button restarts. `Esc` or Start pauses; in a menu `Esc` or the east face button goes back.

Camera rotation and zoom are never required to solve a puzzle: `Q`/`E` or the shoulder buttons orbit in quarter turns, the wheel or the triggers zoom, and every level is readable at the default angle. A player who never touches the camera never has a hidden cell.

Remapping lives in Settings as a list of actions. The player picks an action, the game says "press a key or button", the next device input is captured, and the row updates. If the binding is already used, the game names the other action and clears it, with a toast. Cancel or a five-second timeout leaves everything unchanged.

## Rules

**Action vocabulary.** Gameplay and UI read the same InputMap actions. Menu navigation actions are fixed and cannot be remapped; every other action has `remap_slots_per_action` = 2 bindings.

| Action | Keyboard default | Gamepad default | Remappable |
|---|---|---|---|
| `move_up` | Arrow Up, W | D-pad up, left stick up | yes |
| `move_down` | Arrow Down, S | D-pad down, left stick down | yes |
| `move_left` | Arrow Left, A | D-pad left, left stick left | yes |
| `move_right` | Arrow Right, D | D-pad right, left stick right | yes |
| `undo` | Z, Ctrl+Z | Y / Triangle | yes |
| `restart` | R | X / Square | yes |
| `pause` | Escape, P | Start / Menu | yes |
| `camera_rotate_left` | Q | Left shoulder | yes |
| `camera_rotate_right` | E | Right shoulder | yes |
| `camera_zoom_in` | `=` / wheel up | Right trigger | yes |
| `camera_zoom_out` | `-` / wheel down | Left trigger | yes |
| `ui_accept` | Enter, Space | A / Cross | no |
| `ui_back` | Escape | B / Circle | no |
| `ui_focus_up/down/left/right` | Arrows, WASD | D-pad, left stick | no |

The InputMap entry for an action holds exactly the bindings shown; the remap screen rewrites those entries and the save file at the same time.

**Context stack.** Exactly one input context is active: `gameplay`, `menu`, `modal`, `remap_capture`.

- In `gameplay`, movement, undo, restart, pause and camera actions are forwarded to the game; UI navigation is not.
- In `menu` and `modal`, only UI navigation, `ui_accept` and `ui_back` are forwarded; gameplay actions are ignored. `Escape` maps to `ui_back` in menus and to `pause` in gameplay, resolved by the active context, never both.
- In `remap_capture`, every device input is captured by the remap screen and no action fires. `ui_back` cancels without changes.
- Opening a menu from gameplay pushes a context; closing it restores the previous context without replaying the inputs consumed while it was open.

**Movement input.**

- A direction is emitted only when the game is in `playing` state (see [core-rules.md](core-rules.md)); `ready` accepts the first direction and starts the timer.
- Keyboard movement is edge-triggered: one step per key-down. Holding a direction repeats after `move_repeat_delay_seconds`, then every `move_repeat_interval_seconds`.
- Gamepad stick movement uses `axis_deadzone` = 0.25 and a direction threshold of 0.5 on the dominant axis; diagonals are impossible because the four directions are discrete actions and the dominant axis wins.
- Undo, restart and pause never repeat while held.
- Mouse wheel zoom is clamped by the camera zoom range in [camera-and-presentation.md](camera-and-presentation.md).

**Remapping.**

- Only the actions marked remappable above appear in the remap list; a remap cannot create a new action.
- Capture accepts one keyboard key, mouse wheel direction, gamepad button, or gamepad axis direction. `Escape` is reserved and is refused as a gameplay binding with the message "reserved for Back".
- If the captured input already belongs to another action, the other action's binding is cleared and a toast names it; the two actions never share a binding.
- Each action must keep at least one binding; the remap screen refuses to clear the last one and offers "Reset to default" instead.
- The remap screen offers "Reset all to defaults"; the save stores only bindings that differ from defaults, so a future default change reaches players who never remapped.
- Conflicts are checked against the InputMap, not against the save file, so a migrated or hand-edited save cannot produce a double binding at runtime.

**Device rules.**

- Exactly one gamepad is used at a time: the first device reported by Godot. Additional gamepads are ignored, not merged.
- Gamepad hot-plug is handled at runtime: on disconnect, all gamepad-derived held inputs are released and the game does not pause; on connect, the device is picked up on its first button press.
- On Web, the browser delivers gamepads only after a user gesture and only while the page has focus; the game does not advertise gamepad support on the pause screen until a device presses a button.

**Focus and text.**

- Every interactive control on every screen has `focus_mode = FOCUS_ALL`, a defined `focus_neighbor_*` order, and a visible focus state (see [ui-flow.md](ui-flow.md) and [accessibility.md](accessibility.md)).
- Focus never escapes the current screen; the first focusable control receives focus when the screen opens.
- The focused control is drawn with the focus ring from the UI theme, never with a color-only change.

## Numbers and tuning

_来源约定：issue #1、project.godot 或本页引用的既有页面已经固定的值为事实；其余数值是 proposal（提案），影响手感或发布门槛的 proposal 在 Open questions 中列出。_

| Value | Default | Range | Notes |
|---|---|---|---|
| `remap_slots_per_action` | 2 | 1 to 2 | bindings per remappable action |
| `axis_deadzone` | 0.25 | 0.10 to 0.40 | 0..1 ratio of full stick travel before a stick counts as centred |
| `axis_direction_threshold` | 0.5 | 0.30 to 0.70 | 0..1 ratio; smaller of x/y must reach this on the dominant axis |
| `move_repeat_delay_seconds` | 0.30 | 0.15 to 0.60 | seconds a held direction waits before repeating |
| `move_repeat_interval_seconds` | 0.10 | 0.05 to 0.25 | seconds between repeated steps |
| `remap_capture_timeout_seconds` | 5.0 | 3.0 to 10.0 | seconds before capture cancels itself |
| `max_gamepads` | 1 | 1 to 1 | design decision: first device only |
| `focus_ring_px` | 3 | 2 to 4 | pixels; drawn by the UI theme, not per node |
| `ui_repeat_delay_seconds` | 0.40 | 0.25 to 0.60 | menu navigation repeat while held |
| `ui_repeat_interval_seconds` | 0.12 | 0.08 to 0.20 | menu navigation repeat interval |

## Edge cases

- **Keyboard and gamepad press the same direction in the same frame.** The event that arrives first is processed; the other is dropped by the one-move-at-a-time rule in [core-rules.md](core-rules.md), so the player still moves one tile.
- **The gamepad disconnects while a direction is held.** Held gamepad input is released, the player does not keep walking, and no buffered move is executed.
- **The window loses focus while a key is held.** All held inputs are released; the game keeps running but does not auto-pause. The pause key is still the only way to stop the clock.
- **`Escape` is captured in the remap screen.** Refused with the reserved message; nothing changes.
- **A captured binding equals the action's own existing binding.** Treated as a no-op with a toast; other actions are untouched.
- **Two actions conflict after a save migration.** The loader validates bindings against the InputMap and drops the duplicate with a warning, keeping the first action's binding.
- **A gamepad is the only device connected.** Menus are fully reachable with the d-pad, the stick and `ui_accept`/`ui_back`; no screen requires a keyboard.
- **The player holds a direction through a level completion.** The buffered move is dropped when the state leaves `playing`.

## Open questions

1. **Mouse as a movement device (game designer, proposal).** 1.0 uses the mouse only for menus and wheel zoom; clicking a tile to walk there is not implemented. Decision needed: keep mouse out of movement, since it changes the rules from step-based to path-based.
2. **Default gamepad layout (game designer, proposal).** Undo on Y, restart on X, camera on shoulders is the proposal above. Decision needed: confirm against the first playtest, because restart on a face button is easy to hit by accident.
3. **Remapping menu navigation (game designer, proposal).** Navigation is deliberately fixed so no remap can lock a player out. Decision needed: whether 1.0 must allow rebinding menu navigation for accessibility, which requires a guaranteed-reset path.
4. **Keyboard layout coverage (producer / game designer, proposal).** Bindings assume QWERTY plus arrows. Decision needed: whether AZERTY and other layouts are in 1.0 scope, which would add layout presets to settings.

## Links

- Related systems: [overview.md](overview.md), [core-rules.md](core-rules.md), [ui-flow.md](ui-flow.md), [settings-and-save.md](settings-and-save.md), [accessibility.md](accessibility.md), [camera-and-presentation.md](camera-and-presentation.md)
- Stories: `production/stories/` (none yet)
