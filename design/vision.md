# Vision: Sokoban 3D (working title)

_Owned by the creative director. Every design document must serve this page; a design that cannot name the pillar it serves is not ready._

## Vision statement

Sokoban 3D is a calm, turn-based puzzle game for puzzle players 12 and older on desktop and web, with five to thirty minutes to spend. One isometric room, one crate at a time: the player reads the room, plans two or three pushes, and watches the crate settle onto a plate. The game never asks for reflexes, memorization or hidden information, and every mistake is one input away from being undone. The player leaves a session having solved something with their own hands, with the room still quiet around them.

## Pillars

Four promises, each testable in play. A system page names exactly one as its primary pillar.

- **P1 Readable at a glance** — the player can say "I can see why that push failed", because the camera, occlusion fade and box/goal shapes show the whole puzzle without rotating to hunt for hidden cells.
- **P2 One push at a time** — the player can say "the game never asked for reflexes", because every rule is turn-based, undo is instant, and no timer ever ends a level.
- **P3 Learn by doing** — the player can say "nobody explained the rules to me", because levels 1-5 teach push, undo, deadlock and restart through layout, not text walls.
- **P4 Playable by everyone** — the player can say "I could play it with my own hands", because keyboard, gamepad, EN/ZH, colorblind modes, reduced motion and readable text are part of 1.0, not a patch.

## Anti-goals

- Not a time-attack game: P2 is precision without reflexes, so no timer ends a level and speed never decides a star.
- Not a combat or enemy game: no pillar pays for it.
- No microtransactions, ads or telemetry: the studio ships a paid, offline, complete product.
- No external art or audio, and no level editor or online features in 1.0: the asset constraint is part of the design, and neither the editor nor online play serves a pillar.

## Session shape

A session is one to three levels, two to fifteen minutes each. The first five minutes are tutorial levels 1-3 — push, corner, undo — so the player is pushing a crate within ten seconds of launch. A run ends when the player closes the game from the level select or the pause menu; mid-level progress is not saved in 1.0. The player returns because a locked level sits one ahead on the map, a star rating sits one below their best, and the next level's new mechanic is visible in its name.

## Tone references

- **Classic Sokoban (1982).** Borrow the one-crate-at-a-time puzzle and the quiet, unhurried loop; do not borrow the flat 2D tiles or the bare utility look.
- **Architectural maquettes.** Borrow the calm dollhouse reading of a room — warm sand floor, slate walls, wood crates per the palette in [camera-and-presentation.md](camera-and-presentation.md); do not borrow realistic textures, props or scale detail, because the room is procedural geometry only.
- **A silent gallery.** Borrow the focus of a room where sound only confirms an action and nothing idles; do not borrow ambient music or atmosphere that competes with thinking, per [audio.md](audio.md).
