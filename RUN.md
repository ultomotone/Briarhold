# RUN — the exact procedure for one build

Execute in order, top to bottom, every run. If a step cannot be completed, say so in the changelog
and continue; never silently skip one.

## Phase 0 — Load the contract

Read completely, in this order: `00_MASTER_INSTRUCTIONS.md`, `08_FOUNDATION.md`,
`05_PLAYER_PROFILE.md`, `02_SAVE_SCHEMA.md`, `03_CHANGELOG.md`, `04_BUILD_DOCTRINE.md`,
`06_VERDICTS.md`, `07_WORKBENCH.md`, `09_WISHLIST.md`, `11_RESOURCES.md`,
`13_ENGINE_PRINCIPLES.md`, `docs/ROADMAP.md`, `docs/design/CODEX.md`.

## Phase 1 — Verdicts first

- Anything on the kill list that still exists in the game is removed this run. That is the run.
- If Daniel said anything since the last run, append it to `06_VERDICTS.md` under the right
  heading before you build.
- Anything in Watch that has sat three builds moves up or dies.
- Three builds with no verdict means stop shipping new systems and deepen what exists.

## Phase 2 — Choose exactly one increment

In this order. Take the first that applies and stop looking.

1. Kill-list item still present? Remove it.
2. Gate red (import, typecheck, tests, shot)? Fix it. Fix it and stop.
3. **The topmost unchecked step in `docs/ROADMAP.md`.** Steps marked `[owner]` are never yours;
   if the topmost is `[owner]`, take a polish or readability increment inside the current arc and
   tick nothing. The roadmap fixes WHAT; you decide HOW, guided by the codex.
4. Roadmap exhausted: open workbench thread, then deepen what he used most, then interface work,
   then the weekly surprise, then draw from `09_WISHLIST.md`.

If the step is too large for one run, open a workbench thread with a finish condition and a
budget, then build stage one. Do not shrink a good idea to fit; stage it.

## Phase 3 — Build it

- Sim logic in `sim/` with tests in `tests/unit/`. View in `game/`. Numbers in `content/`.
- `sim/` never imports Node, Input, Time, or engine randomness. `tests/unit/test_sim.gd`
  enforces the randomness and clock rules; keep it that way.
- Save safety: `Migrate.KEY` never changes; fields are added, never removed or renamed; any
  structural change bumps `Migrate.CURRENT` with an idempotent migration and a new golden fixture
  under `tests/fixtures/` in the same run.
- Assets per `11_RESOURCES.md`; every one recorded in `CREDITS.md`. CC0 preferred, CC-BY with
  attribution, copyleft and non-commercial forbidden.
- Multi-run work stays invisible until it works.

## Phase 4 — Look at what you made

1. `pwsh tools\gate.ps1` from the repo root.
2. Exit 2 is the harness: fix the harness, not the game. Exit 1 is a broken build: fix or revert.
3. Read every `logs/latest-*.png` with the Read tool. Actually look.
4. Fix what is wrong, re-shoot, repeat.

## Phase 5 — Write the record

- `03_CHANGELOG.md` — new entry at the top. What changed, and why.
- `BUILD_NOTE.md` — two sentences. No preamble, no enthusiasm.
- `docs/ROADMAP.md` — tick the step. Tick only.
- `07_WORKBENCH.md`, `06_VERDICTS.md`, `05_PLAYER_PROFILE.md` if they moved.
- Do not commit. The harness commits after it verifies you.

## Phase 6 — Stop

Do not start a second increment. Leftover capacity goes into polishing what you built, or into
nothing. At most one question at the end, never blocking, never the same question twice.
