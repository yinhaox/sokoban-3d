# Evidence: core-rules-headless

Run result: N/A — 纯逻辑变更，无运行时表现

- `test.log` — `python scripts/studio.py test` output: 175 headless checks pass, `[test] PASS`, exit code 0. It covers level parsing and each rejection path, four-way movement, pushing, blocked pushes, the 100-step undo cap, restart, the win condition on one and two goals, corner deadlock, and the three committed level files. The single `WARNING` line is the expected unknown-field warning, asserted by the check "an unknown field only warns and is ignored".
- `check.log` — `python scripts/studio.py check` output: `[check] import OK`, every changed script parses, exit code 0.

There is no screenshot because this story ships `src/logic/` only. No scene, input, camera or rendering code changed, so the game still boots to the unchanged Game Studio placeholder and there is no on-screen state this story could show. The rule layer is exercised entirely by `test.log`; `run_command` was not needed to prove it.
