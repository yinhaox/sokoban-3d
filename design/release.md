# Design: release

_What "1.0" means in versions, platforms, licences and failure handling, and the gates a build must pass before a human approves a release. Owned by the release manager._

## Goals

Pillar P4 (playable by everyone). A commercial release needs more than a playable build: it needs a version someone can state, a licence list a lawyer can read, a build that fails gracefully, and a checklist that a reviewer can verify without trusting a worker's word.

- One version scheme for the application and one independent schema version for the save, so a patch cannot silently break saves.
- Three platforms with explicit minimum specifications, build notes and a smoke test each: Windows, Linux and Web.
- A licence and credits block that covers every byte shipped, and a crash path that never shows the player a stack trace or loses a save.

The page lands when a release candidate has a filled checklist, a licence list, a real capture set for the store page, and a named human approval before anything is tagged or uploaded.

## Player experience

A player buys or downloads the game, runs it, and never meets an engine dialog. If something breaks, they see a plain screen in the game's own style that says what happened, saves what can be saved, and offers a restart or a reload; the technical detail goes to a log they can copy from Settings.

The game works offline, keeps its save on their machine, sends nothing about them anywhere, and credits every sound and line of code the studio did not write. The version number under the title on the main menu matches the version on the store page.

## Rules

**Versioning.**

- The application version is semantic `MAJOR.MINOR.PATCH`, shipped as `1.0.0` for the first commercial release. Pre-release development builds use `0.x.y` and are never distributed publicly.
- `MAJOR` changes for a save-breaking or content-breaking release, `MINOR` for a content or feature release, `PATCH` for fixes only.
- The save schema has its own integer version in `user://save/profile.json` (`save_version`, per [settings-and-save.md](settings-and-save.md)); it is not the application version and changes only when the schema changes.
- The application version is set once per release in `project.godot` (`application/config/version`) and recorded in the release document. The release document, `project.godot` and the main-menu label must agree; a mismatch fails the checklist. `project.godot` currently has no version key; the story that adds the main-menu label adds the key in the same change.
- The main menu shows `v<application_version>` in a corner; the About/Credits screen repeats it with the Godot version.

**Platforms and distribution.** 1.0 targets three export platforms, each with its own build note.

| Platform | Build | Minimum target | Save location |
|---|---|---|---|
| Windows | 64-bit `.exe` in a zip (installer only if the release manager adds one) | Windows 10 64-bit, 2 GB RAM, GL 3.3-class GPU, 1152x648 | `%APPDATA%\Godot\app_userdata\<project name>\save\profile.json` |
| Linux | 64-bit executable in a zip (no distro package in 1.0) | glibc 2.31, Vulkan not required, GL 3.3-class GPU | `~/.local/share/godot/app_userdata/<project name>/save/profile.json` |
| Web | static HTML/JS/WASM bundle served over HTTPS | WebGL2, desktop browser with 512 MB available, gamepad via Gamepad API | IndexedDB through `user://` |

- Exports use the GL Compatibility renderer from `project.godot`; no platform may override it with Forward+ or Mobile.
- Export presets are engineering configuration; a story implements them, and no release document edits `export_presets.cfg`. The design requires: one preset per platform, the icon and splash set from the repository, and the version string injected from the application version.
- Web must start audio only after a user gesture (see [audio.md](audio.md)) and must not promise cross-device saves (see [settings-and-save.md](settings-and-save.md)).
- x86_64 only in 1.0. macOS, 32-bit, mobile and consoles are out of scope and are stated as such on the store page.

**Licences and credits.**

- Repository code is MIT. The full licence text ships in `LICENSE`.
- Generated audio (`assets/audio/sfx/*.wav`) is dedicated to CC0 1.0 by the studio, per [audio.md](audio.md); the generator script is part of the MIT code.
- The Godot Engine is MIT; its copyright notice ships in the credits screen and in the release document's third-party list.
- No external art, font, music, sample or model asset ships in 1.0. Chinese text uses OS fonts through `SystemFont`, which are not distributed; if a bundled font is later approved per [accessibility.md](accessibility.md), it must be an OFL font with its licence file and a credits line.
- The credits screen lists: studio, role credits as the studio chooses, the generated-audio note, the Godot notice, and every level's `author` field.
- The store page and the release document carry the same licence summary, so nothing shipped is unlisted.

**Crash and error handling.**

- The game never shows an engine stack trace to the player. Every recoverable failure has an in-game message per [ui-flow.md](ui-flow.md).
- Fatal errors write a log to `user://logs/` and replace the screen with a plain error panel offering "Copy diagnostics" and "Restart" (desktop) or "Reload" (Web). The save is written before the panel appears when possible.
- Logs rotate: at most `log_file_count` files of `log_max_bytes` each, so a long session cannot fill the disk. The "Copy diagnostics" button copies the last log plus version, platform and save schema version to the clipboard; the player chooses to send it.
- No telemetry, no crash reporting service, no user identifier and no network request at runtime. This is an anti-goal in [overview.md](overview.md) and a privacy promise on the store page.
- A release candidate is smoke-tested on each platform by launching, completing level 1, quitting and relaunching to confirm the save loaded. That run produces evidence for the release checklist.

**Release gates.** A release document (`production/releases/<version>.md`, owned by release-prep) is a proposal until a human approves it. It records, per item, pass/fail/not-applicable with the command or path that proves it:

1. `python scripts/studio.py check` exits 0 and `python scripts/studio.py test` exits 0 on the release commit.
2. Every story in scope is `done` with an evidence index reporting `Run result: OBSERVED`.
3. Every level validates and the solver test passes; `par_moves` matches the shipped campaign table.
4. The frame budget from [technical-architecture.md](technical-architecture.md) holds on the minimum Windows machine and the Web build.
5. Save schema migration fixtures pass; a killed-process save test recovers from `profile.json.bak`.
6. Locales `en` and `zh` have no missing keys; no CJK tofu appears in a capture of every screen.
7. Accessibility checklist from [accessibility.md](accessibility.md) passes at 150% scale in all four colour modes.
8. No placeholder asset, debug overlay, `--unlock-all` default or debug print ships; the Developer menu is absent.
9. The licence list is complete and reviewed by a human; the credits screen matches it.
10. Version strings agree across `project.godot`, the main menu, the release document and the store metadata.
11. No blocked story in scope and no open release-blocking bug.
12. Each platform build launches and completes the smoke test listed above.

- No step in this list tags, uploads or publishes anything. The release manager proposes; a human approves and publishes. This follows the delivery policy that agents never tag, publish or merge releases.

**Rollback.** Before a release is approved, the release document names the previous version to return to and states whether the save schema changed. Because saves are never downgraded (a newer `save_version` is backed up, not migrated backwards), a rollback that crosses a schema change is a known data loss for players who already ran the newer build; that risk is written in the release document, not discovered later.

**Store metadata.** The release document carries the text the store page will use: title, one-line description, short description, feature list, system requirements per platform, supported languages, accessibility summary, and the "no telemetry, offline" privacy statement. Screenshots come from real captures of the release candidate under `production/qa/evidence/<story-slug>/` or the release's own evidence directory; no mock-up, composite or design-document image is used as a store screenshot.

## Numbers and tuning

_来源约定：issue #1、project.godot 或本页引用的既有页面已经固定的值为事实；其余数值是 proposal（提案），影响手感或发布门槛的 proposal 在 Open questions 中列出。_

| Value | Default | Range | Notes |
|---|---|---|---|
| `app_version` | 1.0.0 | 0.1.0 to 99.99.99 | semantic version string |
| `save_version_current` | 1 | 1 to 99 | independent schema integer, from [settings-and-save.md](settings-and-save.md) |
| `platform_count` | 3 | 3 to 3 | Windows, Linux, Web in 1.0 |
| `windows_min_ram_gb` | 2 | 1 to 8 | GB; also the Linux minimum |
| `web_min_browser_ram_mb` | 512 | 256 to 2048 | MB available to the tab |
| `windows_zip_max_mb` | 60 | 20 to 200 | MB, compressed build |
| `linux_zip_max_mb` | 60 | 20 to 200 | MB, compressed build |
| `web_bundle_max_mb` | 40 | 15 to 80 | MB of served files, including the WASM |
| `min_gl_requirement` | 3.3 | 3.3 to 4.6 | OpenGL version class for desktop builds |
| `log_file_count` | 3 | 1 to 10 | rotated log files under `user://logs/` |
| `log_max_bytes` | 262144 | 65536 to 1048576 | bytes per log file |
| `smoke_test_minutes` | 10 | 5 to 30 | minutes per platform for the release smoke test |
| `evidence_required_per_story` | 1 | 1 to 1 | evidence index with an `OBSERVED` run per shipped story |

## Edge cases

- **The Web build cannot reach the store origin.** Saves are per-origin; moving the URL loses progress. The release document records the final origin, and the store page does not promise portable saves.
- **A Windows build has no code-signing certificate.** SmartScreen warns on first run; the release document records the warning as a known issue or the build is not approved for that channel.
- **A patch fixes a bug but changes no save field.** `PATCH` bump, `save_version` unchanged, migration fixtures still run.
- **A release needs a schema change.** `save_version` increments, a migration step and fixture ship in the same release, and the release document states that a rollback across it loses records.
- **The version in `project.godot` is edited by hand and disagrees.** The checklist fails gate 10; the release is not proposed until they match.
- **A store screenshot was taken from a development build with a debug overlay.** It cannot be used; a new capture from the release candidate is required.
- **A level author must be credited.** The credits screen reads the `author` field from the shipped level files, so the list cannot drift from the data.
- **The Web tab runs out of memory.** The error panel shows "Reload" and explains the save is safe in IndexedDB; no partial write is attempted after the failure.
- **A log cannot be written (disk full or Web quota).** The game continues; the crash panel omits "Copy diagnostics" and says logging is unavailable.
- **A human approves the release but the checklist has an unverified row.** The unverified row is recorded as a known risk with an owner; approval is the human's call, and the agent never marks the row pass.

## Open questions

1. **Title and the Sokoban trademark (producer / creative director).** "Sokoban" is a registered mark in some regions; the design uses "Sokoban 3D" as a working title. Decision needed: the shipping name, because it affects the store page, the credits, `project.godot` and possibly a licence agreement before 1.0.
2. **Distribution channels and price (producer).** The design names Windows, Linux and Web builds but not a storefront or price. Decision needed: itch.io, Steam or both, and whether Web is a demo or a sold SKU.
3. **Code signing and installers (release manager).** A Windows certificate and an installer are extras beyond a zip. Decision needed: whether 1.0 budget includes signing, and whether the Linux build is a zip or an AppImage.
4. **Age rating submission (release manager).** The design targets E / PEGI 3. Decision needed: who submits the storefront questionnaire and which rating systems are in scope for the first release.
5. **Trailer and store media (creative director).** Store screenshots come from real captures; a trailer is not planned. Decision needed: whether a trailer is a 1.0 gate, which would require a capture and edit plan not covered here.
6. **Privacy policy and EULA (release manager).** The game is offline with no telemetry, so a short privacy statement may suffice. Decision needed: whether a formal EULA and privacy policy are required by the chosen storefront.

## Links

- Related systems: [overview.md](overview.md), [technical-architecture.md](technical-architecture.md), [settings-and-save.md](settings-and-save.md), [accessibility.md](accessibility.md), [audio.md](audio.md), [camera-and-presentation.md](camera-and-presentation.md)
- Commands: `studio.yaml`; evidence under `production/qa/evidence/`
- Release documents: `production/releases/<version>.md` (proposal until a human approves)
- Stories: `production/stories/` (none yet)
