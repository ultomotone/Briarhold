# CHANGELOG — decisions with reasoning, newest first

## 2026-09-02 — S000d: the wider field and life on a clock (owner-present session)

He emptied the field in ten minutes and asked for more map and things that happen. The field
is now 240 m across (was 160) with a slow roughness noise so there are hills and downs; four
pools (water, with a fat pellet or a marble in each that only a Tide sprig will fetch; carriers
route around them); two vents; two gated pockets; 56 pellets, five relic kinds in the open,
seven grubs, 80 stones, and thickets where the noise is dense. And a clock: twelve pellet
posies each regrow a pellet on a seeded timer (150 s ± 90); field beetles roam near a home and
bolt from him and the squad (six seeds if caught; harmless); every dawn rolls two to five new
beetles and, half the time, a grub that walks in from the rim to a bed of its own. All of it
from streams named by the seed, the posy, and the day: randomness sets the problem.

Verbs added since S000c: G beside a shrine sends the squad of its type inside; the sprigs
were rebuilt cuter (big head, eyes, stick limbs, leaf/bud/bloom tops).

**Gate.** import · check · 68 tests · shots read.

## 2026-09-02 — S000c: first play feedback (owner-present session)

A and D were mirrored (camera right vector was forward x up flipped); fixed. The character is a
gnome by verdict: cap, beard, nose, tunic, boots, sword and shield. Delivery now goes to the
shrine of the carriers' type and the load is drawn up into it over 0.9 s, seeds puff from the
top and arc down to root; when the field is full the log says so. The starting cap goes from
20 to 40 because the world starts with 17 sprouts and the old cap was full after two pellets,
which read as "nothing happens." Counts on the layout use one vocabulary: in the field, of cap,
inside shrines, with you. Held Space auto-throws from 0.22 s, ramping to 0.15 s.

**Gate.** import · check · 64 tests · shots read.

## 2026-09-02 — S000b: the Pikifen pass (owner-present session)

**What changed.** Four read-only studies of Pikifen's source (MIT), re-derived at our scale and
applied where cheap: the squad's ring layout now comes from body size (1, 3, 8, 12… per ring)
with the selected type and blooms at the front; the formation anchor only moves when he moves
or the squad strays (no more idle jitter); the swarm stretches along the cursor line; the
whistle fills in 0.45 s, lands no farther than 8 m, and shortens any knockdown in its ring;
throws pick the ripest sprig within grab range and fly to a fixed apex per type (`throw_height`),
and holding Space keeps throwing at a ramping cadence; idle work is nearest-wins across enemies,
loads, and gates; attackers give up past 8 m; dismiss lays hex piles per type on an arc from
the squad's own centre with a 5 s work lock. Carrying uses the real curve (weight penalty,
0.8 ceiling, 0.3 floor), the ring turns to face the first claimant and each arrival takes the
nearest free spot, and ties in type go to the scarcer type. Seeds scatter on a golden angle
from the seed count (no roll). Sprouts mature 120 / 120 / 180 s. Enemies need both itch damage
and itch time to shake. A hit from behind an enemy does `back_multiplier`. Hazard statuses carry
a speed multiplier, a leave-cures flag, and a disables-attack flag. The knight has a 0.9 s
window after a real hit. The big pellet takes 50 carriers; relic value no longer tracks weight.

**Why.** He asked whether the Pikifen repo would have streamlined this; it would have, and it
did. Each number above replaced a guess with a value the reference engine ships and players
have tuned against for years. The two structural ideas that were too big for one pass, enemy
behaviour as data and the three-list trial model, went to the roadmap (S016, Arc 8) with their
shapes written down, so the scheduled builder gets them as work orders, not as ideas.

**Gate.** import · check · 64 tests · shots read. Notes: `docs/research/pikifen-notes.md`.

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
