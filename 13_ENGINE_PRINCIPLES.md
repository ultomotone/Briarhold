# ENGINE PRINCIPLES — how the code stays sound as it grows

Carried from Embermarch, restated for Godot. Fixed in principle, open in implementation.

1. **Persistent state = saved. Rolled content = f(seed, deltas).** `Worldgen.populate` builds the
   field from the seed; `Serialize` stores what he changed and what accumulated. Never store a
   rolled floor, a rolled pellet field, or a rolled raid; regenerate it.
2. **Seeded RNG, per subsystem, call-order stable.** `Rng.stream("world:%d:<subsystem>")`. One
   stream per concern, consumed in a fixed order. Never `randi()`, `randf()`, `randomize()`, or
   `RandomNumberGenerator` in `sim/`. `test_sim.gd` greps for it.
3. **Offline progress = one capped timestamp delta on load.** `HoldSystem.apply_offline`. Never
   simulate the gap tick by tick.
4. **Damage is one pure sink.** `Damage.to_enemy / to_knight / to_gate`: the caller supplies
   amount and cause, the sink applies and reports. No rolls inside. Every number on screen came
   through one of these three functions.
5. **Save: additive, versioned, idempotent, atomic.** `02_SAVE_SCHEMA.md`.
6. **Content is data; rows are Type-Objects.** `content/*.json` → `Types.*.from_dict`. An entity
   references a type; promotion swaps the reference. Behaviour stays in systems, content stays
   in rows.
7. **Sim and view never blur.** `sim/` has no Node, Input, Time, or rendering. The view reads
   the sim after each step and interpolates with `Engine.get_physics_interpolation_fraction()`.
   Input becomes `Commands` in `game/main.gd` and nowhere else.
8. **Determinism is order.** Iterate arrays, not dictionaries, for anything that affects state;
   sort with an id tiebreak; ids never recycle within a session.
9. **Measure before you optimise.** 100 sprigs are MultiMesh instances and a spatial hash;
   enemies and loads are nodes because there are dozens, not hundreds. When profiling shows a
   frame-time drop, then and only then reach for more.
10. **The palette is data with invariants.** `content/palette.json` holds every colour and light
    number; `tests/unit/test_palette.gd` asserts the contrasts and seams that keep it legible.
11. **Interface must be plain.** See the naming law in `06_VERDICTS.md`.

Chassis replacement (engine, renderer, language, the sim/view split) is never the builder's call.
