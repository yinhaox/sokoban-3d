---
id: level-content-20
status: done
updated: 2026-11-03
---

# Story: Twenty hand-tuned levels with a quick solvability check

## Context

The campaign plan in `design/level-progression.md` lists 20 levels with a name,
a size, a teaching purpose, a difficulty and par values, but only
`level-001` to `level-003` were committed. A previous attempt at this story
(`level-content-20`) spent its time building a generator and a solver and
produced nine uncommitted levels. This converged version keeps the scope to the
data: levels 004-020 are hand-authored in the existing format, and the levels
that already existed are kept. The work stays inside a short time box and uses
one quick, scripted solvability check instead of a solver.

Source: issue #17, which supersedes the generator/solver plan of issue #15.

## Acceptance

- [x] `assets/data/levels/` holds 20 levels (`level-001` ... `level-020`); ids
      are continuous, names are unique, and every file passes `LevelData`
      validation.
- [x] Levels 1-5 stay the simplest teaching sequence; levels 6-20 carry two to
      four crates in 7x7 to 10x8 rooms, and difficulty rises overall.
- [x] Every level has a real verification record: a script running the existing
      `src/logic` `GameSession` walks a winning move sequence, and
      `production/qa/evidence/level-content-20/verify.log` records level id,
      moves, pushes and win.
- [x] `tests/run_tests.gd` gains one campaign-manifest assertion block: twenty
      levels, ids unique and ordered, box count equals goal count, exactly one
      player.
- [x] Evidence: `verify.log` plus at least three representative level
      screenshots, with a `Run result: OBSERVED - ...` index line.
- [x] `check_command` and `test_command` pass.

## Out of scope

- Level generators, committed solvers and any `.levelgen/` directory. Temporary
  authoring scripts live in the system temporary directory and are not
  committed.
- Game logic, UI, save data, audio, and `design/`.
- Exact shortest solutions: a winning path is enough, and `par_moves` is the
  length of the verified path plus 10 percent, rounded up.

## Evidence

- `production/qa/evidence/level-content-20/index.md`
- `production/qa/evidence/level-content-20/verify.log`
