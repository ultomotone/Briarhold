# SAVE SCHEMA — the contract

Breaking a save is the only unforgivable bug. This file is law.

## Where

`user://saves/<slot>.json` (Windows: `%APPDATA%\Godot\app_userdata\Briarhold\saves\`). Slots are
named `hold-NN`. Each write is atomic: temp file, previous version kept as `<slot>.prev.json`,
rename over the slot. A corrupt slot falls back to `.prev`. Code: `sim/save/save_store.gd`.

## Shape

`Migrate.CURRENT` (in `sim/save/migrate.gd`) is the schema version; `Migrate.KEY` is
`briarhold:save` and never changes. Serialization: `sim/save/serialize.gd`.

Persist only what cannot be regenerated:

- `seed` — the world.
- `deltas` — what he changed: `taken` (object seed_ids), `felled` (enemy seed_ids), `opened`
  (gate seed_ids), `rooted` (shrine types carried home).
- `knight`, `hold`, `sprigs`, `sprouts`, `shrines`, `day`, `clock_time`, `lost_total`, `saved_at`.
- `discovered` — territory ids he has walked into (v2); campsite and arena ids too.
- `camp` — the campsite the Hold stands at (v3; "home" is the origin).

Everything rolled from the seed comes back from `Worldgen.populate` and the deltas apply over it.
Objects spawned in play without a seed_id (corpses) are not persisted; that matches the world's
own rule that corpses do not survive a day.

## The discipline

1. **Fields are added, never removed or renamed.**
2. **Every structural change bumps `Migrate.CURRENT`** and adds a step to `Migrate.run` that is
   pure, additive, field-by-field, and idempotent (`run(run(x)) == run(x)`).
3. **Same commit:** the migrator, a new golden fixture `tests/fixtures/save-vN.json`, and the
   test that loads every fixture through `Migrate.run` twice and through `Serialize.from_doc`.
4. **Round trip is stable:** `to_doc(from_doc(d)) == d` for a current document
   (`tests/unit/test_save.gd`).
5. JSON numbers arrive as floats; every loader normalises with `int()` where an int is meant.
6. Offline time is applied on load as one capped delta (`HoldSystem.apply_offline`), never by
   simulating the gap. The local clock is trusted and therefore cheatable; accepted for a
   single-player game.

## Versions

- **v1** (2026-09-02) — the first shape, as above.
- **v2** (2026-10-16) — adds `discovered` (array of region ids, default empty). Fixture
  `tests/fixtures/save-v2.json`.
- **v3** (2026-10-20) — adds `camp` (default "home"). Fixture `tests/fixtures/save-v3.json`.
