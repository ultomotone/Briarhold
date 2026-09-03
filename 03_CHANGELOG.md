# CHANGELOG — decisions with reasoning, newest first

## 2026-09-02 — S000: the vertical slice and the doctrine (owner-present session)

**What exists.** A Godot 4.7 project with a pure deterministic sim (`sim/`, 57 tests green), a
view (`game/`), content tables (`content/`), a screenshot gate (`tools/gate.ps1`, `tools/shot.gd`),
and the doctrine ported from Embermarch. Playable from `Play Briarhold.cmd`.

The slice, in play: a thumb-high knight on a seeded overgrown field. An Ember shrine in the Hold's
clearing with twelve sprouts. Pluck (hold F, he walks the patch), follow in a loose ring with
per-sprig lag, select type (Q/E), throw at the cursor with an arc preview (Space), whistle with a
growing ring at the cursor (R), dismiss into piles by type (X), swarm (Shift), charge (C). Pellets
of 1/5/10 carried home on a baked navmesh at the 0.3→0.8 speed curve become seeds that arc out of
the shrine and root as sprouts; sprouts mature leaf → bud → bloom. A Stone shrine waits in the
field to be carried home (weight 12) with five Stone sprouts beside it. Three Bulb Grubs asleep
in the open with pellets at their feet: they wake, chase, telegraph on the body, bite three, and
shake off latched sprigs at an itch threshold. A fire vent with a fat pellet in it: Stone burns,
Ember does not, the whistle cures burning. A bramble gate with a pocket behind it holding an
Iron Key and a Heartroot (+10 field cap); the navmesh rebakes when it falls. Two relics in the
open. The knight's sword with a positional backstrike (×1.55, "Backstrike" on the number). Soft
day (15 min) and dangerous night (6 min): Dusk Stalkers come in from the rim for whatever is
outside the safe ring and retreat at dawn; a morning tally. Damage numbers with causes. Hold
total, field count against cap, relics and value on the layout. Title with slots, pause with the
control list, settings that exist. Saves: seed + deltas, atomic, v1, golden fixture, offline
delta on load.

**Why these choices.**
- Godot 4.7 over the Embermarch R3F stack: his call, desktop app first. GDScript over C# so the
  gate has one toolchain and the future mobile export is a setting.
- The sim stayed pure and the view stayed dumb, exactly as in Embermarch, because that is what
  makes 57 tests possible with no display and what makes the save contract enforceable.
- Held F walks him to the next sprout: standing still and mashing a key at a ring of sprouts was
  the first thing the tests said felt wrong.
- The terrain was not rendering at all for the first six shots: every ground triangle was wound
  counter-clockwise, and Godot's front faces wind clockwise, so the whole field was back-face
  culled and the grey "ground" was the procedural sky's lower hemisphere. Found by painting the
  sky ground magenta. Lesson, recorded: when a colour will not change no matter what you tune,
  check that the thing is on screen before tuning it again. The ground is now coloured in a small
  shader from world height and slope with the palette as uniforms.
- Sprig parts picked by height in the shader, not by vertex colour, because MultiMesh multiplies
  vertex colour into the instance colour and Stone sprigs came out red.
- The soft night over Pikmin's hard sunset: his profile wants to lose something, not everything,
  and hates forced stops. The safe ring makes the rule legible on the ground.

**Gate.** import · check · 57 tests · 5 shots read (desktop, throw, whistle, night, title).

**Not done, owed.** Scheduled tasks (owner's go). GitHub remote (owner's go). Weekly export. The
whistle shot showed the ring only after the harness override; a hand playtest is the real check.
