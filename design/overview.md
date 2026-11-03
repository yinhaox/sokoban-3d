# Design: 3D Sokoban overview

_What this game is and what every other design page must serve. Owned by the creative director; the system pages live next to this one and are listed in [systems-index.md](systems-index.md)._

## Goals

This page is the map of the design set for a commercial-ready, data-driven 3D Sokoban built on the existing Godot 4.7 / GL Compatibility template.

- Give every system page a pillar to answer to, so a story can be accepted or cut against a written promise instead of taste.
- Fix what "commercial-ready" means for this studio in observable terms: 20 levels, three platforms, EN/ZH, full keyboard and gamepad support, settings, a versioned save, accessibility, and no unlicensed asset.
- Name the parts of a Sokoban this project will deliberately not build, so scope stays honest while the core is made good.

This page lands when: a reviewer can open any system page, see which pillar it serves, and find every page in the doc map below.

## Player experience

The player is a puzzle player, 12 years and older, on desktop or web, with five to thirty minutes to spend. They open the game, see a calm isometric wooden room, and are pushing their first crate within ten seconds. Nothing in the room is decorative: walls, floor, crates and goal plates are read at a glance in 3D.

**Pillars.** Four promises, each testable in play. The canonical wording lives in [vision.md](vision.md); this table mirrors it, and the creative director owns later changes.

| Pillar | The player should be able to say | How a design is tested against it |
|---|---|---|
| P1 Readable at a glance | "I can see why that push failed." | The camera, occlusion fade and box/goal shapes make the whole puzzle legible without rotating to hunt for hidden cells. |
| P2 One push at a time | "The game never asked for reflexes." | Every rule is turn-based; undo is instant and unlimited in effect; no timer ever ends a level. |
| P3 Learn by doing | "Nobody explained the rules to me." | Levels 1-5 teach push, undo, deadlock and restart through layout, not through text walls. |
| P4 Playable by everyone | "I could play it with my own hands." | Keyboard, gamepad, EN/ZH, colorblind modes, reduced motion and readable text are part of 1.0, not a patch. |

**Anti-goals.** Not a time-attack game, because the pillar is turn-based precision. Not a combat or enemy game, because no pillar pays for it. No microtransactions, ads or telemetry, because the studio ships a paid, offline, complete product. No external art or audio, because the asset constraint is part of the design. No level editor and no online features in 1.0, because neither pillar pays for them.

**Session shape.** A session is one to three levels, 2 to 15 minutes each. The first five minutes are tutorial levels 1-3: push, corner, undo. The player returns because a locked level sits one ahead of the map, a star rating sits one below the best, and the next level's new mechanic is visible in its name.

**Doc map.**

| Page | Covers | Primary pillar |
|---|---|---|
| [core-rules.md](core-rules.md) | Grid, movement, pushing, deadlock, win, moves/pushes, timer, undo, restart | P2 |
| [input-and-controls.md](input-and-controls.md) | Keyboard and gamepad bindings, remapping, camera input, hold-repeat | P2 / P4 |
| [level-format.md](level-format.md) | JSON level format under `assets/data/levels/`, validation, how to add a level | P3 |
| [level-progression.md](level-progression.md) | 20-level plan, difficulty curve, par values, unlock order | P3 |
| [camera-and-presentation.md](camera-and-presentation.md) | Camera angle, zoom, rotation, wall occlusion fade, lighting, materials, tween timing | P1 |
| [ui-flow.md](ui-flow.md) | Main menu, level select, HUD, pause, victory, restart confirm, undo cap | P1 / P4 |
| [settings-and-save.md](settings-and-save.md) | Settings, save fields, versioning, migration, corrupted-save recovery | P4 |
| [audio.md](audio.md) | Procedural SFX, generation method, licenses | P1 / P4 |
| [accessibility.md](accessibility.md) | Colorblind shapes, text size, keyboard navigation, reduced motion | P4 |
| [technical-architecture.md](technical-architecture.md) | Logic/render split, autoloads, scene split, performance budgets | P2 / P4 |
| [release.md](release.md) | Version, export platforms, licenses, credits, crash handling | P4 |

## Rules

- Every system page under `design/` appears in [systems-index.md](systems-index.md) exactly once; this page and the index are the only entry points a story needs.
- A system page is written against exactly one primary pillar, named in its Goals section. A page that cannot name one is not ready for review.
- Rules in system pages are observable sentences a programmer can turn into an assertion in `tests/run_tests.gd`; numbers carry units.
- A number the issue did not specify is a proposal: it appears in the page's Numbers and tuning table labelled `proposal`, and is repeated in that page's Open questions.
- Content is data, not code: levels live as JSON under `assets/data/levels/`, text lives in translation keys, and no level is hardcoded in GDScript.
- The engine, renderer, window size, main scene and autoload set are inherited from `project.godot` and `studio.yaml`. A page that needs to change one records it as an open question, not as a rule.
- The 1.0 scope is exactly: 20 levels, 3-star records, level select, settings, EN/ZH localization, keyboard and gamepad, accessibility options, save/restore, pause/victory/restart, release on Windows, Linux and Web. Anything else is out of 1.0 or an open question.

**Commercial bar.** The studio calls the game commercial-ready when all of these hold together:

1. All 20 levels are solvable by construction and have par values in data; each is verified by a headless solver test.
2. All strings the player sees come from translation keys, and EN and ZH are both complete.
3. The game runs at 60 fps at 1152x648 on the GL Compatibility renderer on the minimum hardware in [technical-architecture.md](technical-architecture.md).
4. Saves survive a kill during write, a corrupted file and a version upgrade.
5. No camera angle, occlusion state or color alone hides a rule.
6. Every shipped platform has a build note and a smoke test, and the asset license list is complete and human-reviewed.
7. There is no placeholder art, audio, text or record: "programmatic geometry" is the art direction, not a stand-in.

## Numbers and tuning

_来源约定：issue #1、project.godot 或本页引用的既有页面已经固定的值为事实；其余数值是 proposal（提案），影响手感或发布门槛的 proposal 在 Open questions 中列出。_

| Value | Default | Range | Notes |
|---|---|---|---|
| `level_count` | 20 | 20 to 30 | proposal; ships levels, all authored as JSON data |
| `tutorial_level_count` | 5 | 3 to 5 | proposal; levels 1-5 teach without text walls |
| `levels_per_session_estimate` | 2 | 1 to 3 | design intent for pacing, not enforced |
| `target_fps` | 60 | 60 to 60 | frames per second at 1152x648, GL Compatibility |
| `minimum_supported_width_px` | 1152 | 1024 to 1280 | window width in px; narrowest window the UI must fit |
| `minimum_supported_height_px` | 648 | 576 to 720 | window height in px; narrowest window the UI must fit |
| `supported_platform_count` | 3 | 3 to 3 | Windows, Linux, Web in 1.0 |
| `supported_language_count` | 2 | 2 to 2 | English and Chinese in 1.0 |
| `age_rating_target` | E / PEGI 3 | E to E10 | proposal; no violence, no text chat |

## Edge cases

- **A story needs a system with no page.** The story is not ready; the page is written first, reviewed, and added to the index in the same pull request that creates it.
- **Two pages disagree on a number.** The page that owns the number wins; the other cites it. Shared timing numbers are owned by [core-rules.md](core-rules.md), shared UI sizes by [ui-flow.md](ui-flow.md), shared save fields by [settings-and-save.md](settings-and-save.md).
- **A pillar and a feature conflict.** The pillar wins and the feature is cut or deferred; the decision is recorded in this page's Open questions until the creative director moves it into `design/vision.md`.
- **The commercial bar cannot be met for a platform.** The platform drops from 1.0 and the release page says so; the bar is not lowered for the platforms that remain.
- **A page grows past one sitting.** It splits by system, not by paragraph, and both halves are indexed; a page is never left as a half-updated reference.
- **This page and `design/vision.md` disagree.** The vision page wins; this table is updated in the same change, and a system page cites the pillar name from `design/vision.md`.

## Open questions

1. **Working title (creative director / producer).** All pages use "Sokoban 3D" and the project is still named "Game Studio" in `project.godot`. Decision needed: the shipping title and whether it is baked into `project.godot` before or after localization keys are frozen.
2. **Extra systems beyond the 20-level scope (producer).** No level editor, daily puzzle, hints or music are planned for 1.0. Decision needed: confirm the cut list, since each one changes the story plan and the commercial bar.
3. **Web export as a shipped platform (producer / release manager).** The issue names Windows, Linux and Web. Web brings IndexedDB save limits, a user-gesture requirement for audio and a second QA pass. Decision needed: is Web a 1.0 platform or a post-1.0 target?
4. **PEGI/ESRB confirmation (release manager).** The target rating is a proposal until the storefront questionnaire is filled in. Decision needed: who submits the rating and which storefronts are in scope.

## Links

- Related systems: [systems-index.md](systems-index.md), all pages under `design/`
- Vision: [vision.md](vision.md)
- Source request: issue #1, `Type: design - 3D Sokoban design for a commercial-ready release`
- Stories: `production/stories/` (none yet; the producer derives them from these pages)
