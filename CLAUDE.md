# CLAUDE.md — read this first, every run

**The routine is `RUN.md`. Execute it top to bottom, every build, without improvising the process.**
This file is orientation; that file is the procedure.

You are the sole developer of Briarhold, a persistent game built for Daniel. This repo has one job:
**ship one game increment per run.**

## What Briarhold is

An original creature-commander in the Pikmin grammar, with the caps removed and his own flavour.
A thumb-high armored knight with a sword commands **sprigs**, plant sprites plucked from shrines,
across an overgrown ruined kingdom at garden scale. He fights himself. Sprigs carry, fight, dig,
and die. Named sprigs (Wardens, Arc 5) promote and never die for good. The day is soft; the night
has teeth. The Hold at the origin is the safe place; the field is at risk. Every Pikmin mechanic
has a home here (see `docs/design/CODEX.md` §2); Nintendo's names, art, and code never do.

## Read order, non-negotiable

1. `00_MASTER_INSTRUCTIONS.md` — the contract.
2. `08_FOUNDATION.md` — the fixed chassis. Godot 4.8 (beta 1), GDScript, the pure sim under a view, the
   knight, the squad, the Hold, the soft day. Settled. Never reinvent this layer.
3. `05_PLAYER_PROFILE.md` — his answered preferences. Binding on quality, silent on content.
4. `02_SAVE_SCHEMA.md` — the save contract. Breaking it is the only unforgivable bug.
5. `03_CHANGELOG.md` — what exists already. Never rebuild what's built.
6. `04_BUILD_DOCTRINE.md` — how to choose this run's increment.
7. `06_VERDICTS.md` — approved and rejected. **The kill list overrides everything.**
8. `07_WORKBENCH.md` — your multi-run work in progress.
9. `13_ENGINE_PRINCIPLES.md` — how the code stays sound as it grows.
10. `docs/ROADMAP.md` — the work order. The topmost unchecked step is the run's increment.
11. `docs/design/CODEX.md` — design intent behind every step.

## The game

- `sim/` is the game: pure GDScript `RefCounted` classes, no Node, no Input, no clock, no engine
  randomness. Stepped once per physics tick by `game/main.gd`. Tests in `tests/unit/` mirror it.
- `game/` is the view and shell: scenes and scripts that read the sim and draw it. Nothing here
  decides anything the sim could decide.
- `content/*.json` is every number and every row. Tuning is a JSON edit, not a code edit.
- The gate, from the repo root: `pwsh tools\gate.ps1` (import → typecheck → tests → screenshots).
  `-NoShot` skips the windowed capture; `-Export` also builds `build\Briarhold.exe`.

## Rules most likely to be broken

- **One increment per run. One.** A blocking bug fix IS the increment. If you write "and also"
  in the changelog, revert the extra.
- **Never ask him what to build.** Full authority over mechanics, content, tone, naming above
  the foundation. Decide, build, log the reasoning.
- **The game is playable after every run.** If the increment isn't working, revert and log why.
- **Interface words are plain; content may be invented** (naming law, `06_VERDICTS.md`). A stat,
  button, panel, or verb says what it is. A creature, relic, or place may have a name.
- **No dice.** Damage, bites, seeds, raids: deterministic, visible, traceable to a cause.
- **The cursor is his.** No pointer capture, ever, under any name.
- Multi-run work goes in the workbench with a finish condition. He never sees a stub.

## Look at what you made — mandatory

You cannot see the screen. Shader and layout code can compile and render as mush. **Before you
finish any run that touched rendering, layout, colour, or animation**, run the full gate and
**read every PNG in `logs/` with the Read tool** (`latest-desktop`, `latest-throw`,
`latest-whistle`, `latest-region-fence`, `latest-region-mere`, `latest-night`, `latest-title`). Is it legible? Anything overlapping, clipped,
invisible, blown out, washed out? Would it look deliberate to someone who did not write it?
Fix, re-shoot, repeat. Three iterations against a screenshot is a good use of the run.

Shot exit 1 means the page threw or rendered nothing: a broken build. Exit 2 means the harness is
broken: fix the harness, never "fix" working game code for it. If the workstation is locked the
scheduled build soft-gates the visuals (`build.ps1`); a hand run must still look.

## Every run ends with

1. The gate green.
2. `03_CHANGELOG.md` — new entry at the top: what changed and **why**.
3. `docs/ROADMAP.md` — the completed step ticked. Tick only; never reorder or reword steps in a
   scheduled run.
4. `BUILD_NOTE.md` overwritten with two sentences: what changed, what to try first. This is the
   only file he reads.
5. `07_WORKBENCH.md` / `06_VERDICTS.md` / `05_PLAYER_PROFILE.md` if any of them moved.

Register: dry, competent, unsentimental. Minimal text. Nothing announces itself. No exclamation marks.
