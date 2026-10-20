# CHANGELOG — decisions with reasoning, newest first

## 2026-10-20 — S000g: an open world with climates, campsites and bosses (owner-present session)

His asks: more nature, trees, logs to travel through, less grassland; the territories not laid
out in a circle, more map in any direction, optional campsites to move to, an open-world feel;
bosses like the real thing; sprigs that look and feel like his reference images; graphics
closer to them. Then, mid-session: no symmetry anywhere, and biomes that slowly turn into other
environments (arctic, desert, jungle) with their own conditions.

- **A bigger, unpatterned map.** 500 m across (was 320). Territories, three boss arenas and five
  campsites are scattered anywhere in the square with room between them; no ring, no even
  spacing, different every seed.
- **Climates.** Each world has a seeded cold direction and wet direction bent by slow noise:
  one side runs to arctic, the other to desert or jungle, through tens of metres of blend. Snow
  slows everything but Frost sprigs, sand everything but Embers, jungle undergrowth everything
  but Thorns; Moths fly over all of it. Each climate has its trouble (ice fields, hot vents,
  spore clouds, each with a pellet inside) and its look: snowy pines and ice crags; dunes,
  cacti, sandstone and the ribs of something huge you walk through; jungle trees with vines,
  giant leaves, mossy boulders. The air changes with it: pale haze and falling snow, warm dust,
  green damp and drifting spores. A banner says when he crosses into the snow, sand or jungle.
- **Temperate biomes.** Woodland (great trees, hollow logs you walk through, stumps,
  mushrooms), rocky country (crags, outcrops), marsh (pools with lilies, reeds), old garden
  (flower pots, some tipped over with a pellet inside; bricks; ruins), meadow (giant daisies).
  The terrain is coloured per vertex by biome and climate and shaded smooth.
- **Campsites.** Hold T at a camp's beacon for a second and the Hold moves there: shrines, safe
  ring, night raids and all. The origin is a camp too. Save schema v3 keeps which camp.
- **Bosses.** Thornback Behemoth (bites six, stomps, charges), Hollow Queen (burrows, bursts up,
  bites, stomps), Cinder Matriarch (stomps, breathes fire, charges), each in an arena with a
  relic and a Heartroot. Bosses try a list of moves in turn; the stomp is new (crushes all
  but Stone and Moth, throws riders off). A health bar shows while one fights nearby.
- **Sprigs** now have the genre's proportions: a teardrop head tapering into a long stem, big
  eyes, a slim body, thin limbs; Embers have a pointed nose, Sparks big ears.
- **Graphics.** Brighter sky and grass, a dense grass-and-clover carpet near the camera, softer
  far focus, smoother stones. Anything tall (crowns, logs, pots, crags) cuts a dithered window
  round the gnome so he never vanishes behind it.
- **Map.** The minimap now centres on him, shows 150 m round him tinted by biome and climate,
  and pins known camps, arenas and territories to its rim.

**Speed.** The bigger world first ran at 16 s to load and 11 ms per sim tick. Now: climate and
biome maps baked once per seed, heights baked to a 2 m grid after worldgen (0.8 µs a lookup,
was 32), the noise hash inlined, the spatial hash at 3 m with an early-out, obstacles indexed
incrementally, posy checks staggered. Worldgen about 2 s, sim about 3 ms a tick with a squad out.

**Gate.** import · check · 94 tests · fourteen shots read (new: forest, arctic, desert, jungle,
boss).

## 2026-10-16 — S000f: cuter sprigs, clear shrines, a freer camera, beasts, and more ground (owner-present session)

His asks, all in one session: cuter sprigs with leafier leaves; shrines at the Hold that say
which is which; zoom out farther; hold the middle mouse button to move the view; smoother day
and night; more terrain; more creatures with skills of their own.

- **Sprigs.** Bigger head, eyes with whites, pupils and a highlight, blush, a small smile, a
  blink on each sprig's own phase, a breath in the body. The leaf is a real leaf now: broad,
  pointed, folded on a dark midrib with faint veins, curling forward on a curved stem. The bud
  is a teardrop with two small leaves; the bloom has round petals.
- **Shrines.** The body is the type's colour, a coloured ring marks the ground, and an emblem of
  its own turns over the top: flame, block, bolt, drop, thorn star, wings, snowflake, acorn. A
  name with its inside count floats above, the same size on screen at any zoom.
- **Camera.** Zoom reaches 46 m (was 18), in steps that grow with distance. Holding the middle
  mouse button and dragging turns the view freely and tilts it. The cursor stays free.
- **Day and night.** The light was switching: at nightfall the darkness dropped from half back
  to zero and the sun jumped to the moon's angle. Now one darkness value runs over the whole
  cycle (dusk from 150 s before nightfall to 70 s after; dawn the same way), with a warm band
  through dusk and dawn and a light that slides from sun to moon. A test walks the whole cycle
  in half seconds and fails on any step over 0.01.
- **Beasts** (`enemies.json`, a new `attack` per row): Cinder Hog (breathes fire in a cone;
  Embers shrug it off), Mire Hog (the same with poison; the Fume Bog's new guardian), Pounce
  Toad (leaps onto where you stood, a warning ring shows the spot; Stone and Moth are not
  crushed), Shellback (armoured in front at 0.2, soft behind at 2.5; rushes in a line,
  trampling, then is dizzy), Gale Puff (blows sprigs back into whatever hazard it lives beside;
  Oaks are too heavy), Hollow Mole (a moving mound nothing can touch; comes up under you, eats
  three, then fights on the surface for seven seconds). Hogs live by the vents, toads by the
  pools, puffs beside either; 17 in the field at the start and a chance of one more each dawn.
  The first time each one winds up, the log says what it is and how to fight it.
- **Ground.** Ridges in the rough country; clover patches and worn earth in the colouring. Old
  stumps with roots, fallen branches, six ruins of columns and wall courses, giant mushroom
  clusters and giant daisy meadows (their tops dither away near the camera so they never hide
  him), and the small scatter now has tufts, ferns, clover and flowers. Stones vary in tone.

**Found and fixed: the sim's random stream rolled engine dice.** Inside `Rng`, a bare `randf()`
resolves to the engine's global function, not the class's own. `randi_range`, `randf_range`
and `pick_weighted` all did that, so they were never seeded. Few callers used them until now
(the dawn beetle count did). The new scenery leaned on them and same-seed worlds came out
different. Every internal draw now goes through `self`, and a regression test pins it.

Obstacles are bucketed on a 6 m grid (`SimWorld.obstacles_near`), so the extra scenery costs
the per-tick collision nothing: a point checks the handful near it, not all five hundred.

**Gate.** import · check · 87 tests · nine shots read (new: `latest-bestiary`, `latest-far`).

## 2026-10-16 — S000e: every type in the field (owner-present session)

He asked where the water sprigs were. Seven types were in `content/sprigs.json`; only Ember and
Stone had a shrine in the world. The other six waited on roadmap steps (S017–S040) that the
never-registered schedule was meant to build. Now they are in the field, one territory each,
from `content/regions.json`, on a ring 122 m from the Hold at seeded angles:

- **The Mere** (Tide): three pools sunk into the ground (the heightfield has basins now). A
  shell relic sits on the bottom; only an all-Tide crew wades it out.
- **The Wire Fence** (Spark): nine live posts with wires. Others are shocked (slowed, killed
  after 2 s); Spark walks through and brings the lens out.
- **The Fume Bog** (Thorn): poison gas over a cache and a Heartroot, a grub on guard. Thorns
  breathe it, and a beast that eats a Thorn takes 150 poison.
- **The Stone Stacks** (Moth): thirteen standing stones with no way in. Moths fly the feather
  out over the top; an all-Moth crew flies straight.
- **The Frost Hollow** (Frost): frozen ground and a guardian grub. Frost slaps build a freeze
  meter; full, the beast is frozen solid for 6 s.
- **The Fallen Oak** (Oak): a brass acorn of weight 40. Only Oak strength lifts it in one trip.

Why routing changed: a load now asks for a route its carriers are all immune to. The view keeps
two navmeshes (hazards walled off, hazards open) and picks by the crew. A crew with no way home
stays put and says so instead of walking through walls. Bakes run on a worker thread; carriers
wait while the routes are worked out. The field is 320 m (was 240). A minimap under the counts
shows the Hold, the safe ring, each territory as "?" until found, shrines, and stalkers at night.
Walking into a territory names it ("Found: The Mere") and the save keeps it (schema v2, golden
fixture `save-v2.json`, v1 migrates with nothing found).

Animation: sprigs ease their turns and only face the way they move when they move; settled
followers turn with the gnome; new sprigs pop up out of the sprout; thrown sprigs tumble once;
the walk cycle runs at the speed they actually move; Moths have wings that flap. The gnome's legs
swing from the hip. Beasts ease their turns and step at their real speed; carried loads bob.

**Gate.** import · check · 78 tests · seven shots read, plus one probe shot per territory.

## 2026-10-16 — Godot 4.8 beta 1 (owner ruling)

The engine moves from 4.7.2 to 4.8 beta 1 at his request. Installed side by side from the
official godot-builds release with the SHA-512 checked, not over 4.7.2. The whole gate ran on the
beta before anything changed: import, typecheck, 68 tests, five screenshots, all green, no new
warnings, renders identical. Then the defaults moved: `tools/gate.ps1` and both launchers prefer
`%USERPROFILE%\Tools\Godot-4.8*` and fall back to winget's 4.7.2; `project.godot` declares 4.8;
the 4.8 Windows export templates are installed. New: `Edit in Godot.cmd` opens the editor on 4.8.
Beta risk is accepted by the owner; if a beta breaks the gate, the fallback is one env var
(`$env:GODOT`) away and the code is unchanged.

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
