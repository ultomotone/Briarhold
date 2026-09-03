# RESOURCES — external material you may use

**The old "no external assets" rule is dead.** It existed when the game was a single HTML file in a
chat window. It is now an Electron app in a git repo, and that rule was the direct cause of boxy
placeholder characters. Assets may live in the repo.

**The replacement rule: licence discipline is absolute.** Every asset that enters this repo gets a
line in `CREDITS.md` recording name, author, source URL, and licence. No exceptions, including CC0.
An asset whose licence you cannot confirm does not enter the repo.

---

## Licence policy

Treat this project as if it will one day be distributed.

- **CC0** — preferred default. No attribution required. Use freely.
- **CC-BY** — acceptable. Attribution mandatory in `CREDITS.md`.
- **MIT / Apache-2.0 / ISC / BSD** — acceptable for code and libraries.
- **CC-BY-SA, CC-BY-NC, CC-BY-ND, GPL — forbidden.** Copyleft and non-commercial terms are traps.
  Study these codebases, never copy their code or ship their content.
- **"NoAI" riders** — shipping the asset in the game is fine. Never feed it to model training.

---

## Art and animation — CC0 first

**Kenney** — the safest source that exists. Everything on the asset pages is CC0, no attribution
required, glTF included.
- https://kenney.nl/assets/category:3D
- https://kenney-assets.itch.io — the all-in-one bundle

**Quaternius** — the most important source for characters and animation. Mostly CC0, but licence is
per-pack, so verify each one.
- https://quaternius.com — packs index
- https://quaternius.com/packs/universalbasecharacters.html — customisable humanoid base, shared rig
- https://quaternius.itch.io/universal-animation-library-2 — ~130 animations, CC0
- Universal Animation Library 1 — ~120 animations on the same rig

Together these give a complete CC0 character and animation stack on one shared rig, which means no
per-character retargeting work.

**Retargeting and IK, when a clip and a mesh DON'T already share a rig** (e.g. driving a Mixamo asset,
or the Fantasy peasant off the animation-library clips). three.js ships the helpers:
`SkeletonUtils.retargetClip` / `retargetSkeleton` (in `examples/jsm/utils/SkeletonUtils.js`) map one
skeleton's animation onto another by bone correspondence — but bone-name-identical rigs (which the
Quaternius Universal line is) often need no retarget at all: `AnimationMixer` binds tracks by node
name, so the clip just plays. For motion no clip covers — foot planting on the downs' uneven terrain,
look-at/aim — `CCDIKSolver` (also `examples/jsm`) does inverse kinematics; bake locomotion + IK
touch-ups, not full procedural locomotion. Vendor the specific helper file as a global build, the same
way `GLTFLoader` was vendored (the page is `file://`, so no ES-module loaders).

**AccuRIG** (Reallusion) — free desktop auto-rigger, the escape hatch when a bespoke humanoid mesh
needs a skeleton and no CC0 pack covers it. Upload a mesh, get a rig, export FBX/glTF. Reach for it
before hunting more packs. (Cascadeur is the physics-assisted keyframe alternative; its free tier is
non-commercial-only for standard-format export.)

**Poly Pizza** — 10,000+ low-poly models, mixed licence. Use the CC0 filter.
- https://poly.pizza/search/CC0

**Poly Haven** — CC0 textures and HDRIs.
- https://polyhaven.com

**ambientCG** — 1,500+ CC0 PBR materials.
- https://ambientcg.com

**awesome-cc0** — community index of every reliable CC0 source.
- https://github.com/madjin/awesome-cc0

**Mixamo** — usable and free for commercial embedding, but unmaintained since 2015 and it went down
for days in mid-2025. Acceptable as a supplement. **Never a dependency.**

**Format rule:** prefer glTF/GLB. three.js loads it natively. FBX and OBJ are fallbacks.

**Optimising the glTF that ships.** `gltf-transform` (Don McCurdy, MIT — https://gltf-transform.dev) is
the CLI/library for it: `optimize`, `prune`, `dedup`, `simplify`, `resize`, Draco/meshopt geometry
compression, and KTX2/Basis texture compression (stays GPU-compressed, ~10× less VRAM than PNG). Wire
`DRACOLoader`/`KTX2Loader`/meshopt decoder into `GLTFLoader` only if a shipped asset actually needs it;
`gltfjsx` (also McCurdy) is React-only and not for this chassis. Not required at the current one-figure
scale — reach for it when texture/geometry weight shows up in a load or a frame budget.

---

## Data references — study the structure, never ship the content

Everything here is **reference only**. It lives in `reference/`, which is gitignored. RS3 wiki content
is CC BY-NC-SA, Riot's and Nintendo's data are proprietary. Structure informs our design; their names,
stats, and content never enter the shipping game.

**RuneScape 3** — the reference for the item directory, drop tables, skill curve, and Grand Exchange
economy. RS3, not Old School, per Daniel. (The osrsreboxed repo referenced in earlier notes is
OSRS-only — do not use it. RS3 has no single pre-built JSON repo, so pull from the wiki and Jagex APIs.)
- RuneScape Wiki, MediaWiki API: https://runescape.wiki/api.php — bestiary, drop tables, skills,
  equipment structure.
- Bulk GE data and item IDs (weirdgloop): https://chisel.weirdgloop.org/gazproj/gazbot/ — historical
  prices at https://api.weirdgloop.org
- Official Jagex RS3 Item DB API (RS3 only):
  https://secure.runescape.com/m=itemdb_rs/api/catalogue/detail.json?item=ID and /api/info.json
- Skill curve: classic XP table to 99 (13,034,431 XP, roughly doubling every 7 levels, level 92 is
  almost exactly half the total XP to 99); RS3 extends select skills to 120. "92 is half of 99" is the
  key pacing heuristic.

**League of Legends** — the reference for items that grant abilities, not just stats. The community
sites you have seen (op.gg, Mobalytics, the LoL Wiki) are front-ends built on Riot's own data. Go to
the source, not the scraper.
- Data Dragon (official): https://ddragon.leagueoflegends.com/api/versions.json , then item.json and
  champion.json per version.
- Community Dragon — richer, includes fields Data Dragon omits, best for item passives and actives:
  https://www.communitydragon.org , raw at https://raw.communitydragon.org
- Accurate ability values (ddragon's are unreliable per Riot's own docs):
  https://github.com/meraki-analytics/lolstaticdata
- Wild Rift has no data API and its items differ from PC. PC LoL is the proxy. Riot data is
  proprietary — study only.

**Fire Emblem** — the reference for class identity and promotion.
- Fire Emblem Wiki (independent, MediaWiki API): https://fireemblemwiki.org
- Fandom FE Wiki, has machine-readable Lua data modules such as Module:CharStat/data:
  https://fireemblem.fandom.com
- Structured CSV data, the best machine-readable source (work in progress, Fates-heavy):
  https://github.com/ViolaBuddy/Fire-Emblem-Data
- Serenes Forest for growth rates, stat caps, and promotion trees.
- Model: class defines caps, growths, weapon access, and skills. Promotion is a discrete identity
  change that resets level and raises caps, not a smooth curve. Underlying data is Nintendo/IS
  proprietary — study only.

## Codebases worth reading

- https://github.com/2004scape — RuneScape emulator in **TypeScript**. Closest to our stack. Read it
  for how content data is separated from engine code, and for its tick loop.
- https://github.com/rsmod/rsmod — Kotlin, ISC licensed, clean modern architecture and pathfinding.
- https://github.com/ondras/rot.js — MIT. Dungeon generation, FOV, pathfinding, scheduling.
- https://github.com/hogart/rpg-tools — inventory operations, dice notation, modifier application,
  JSON item definitions with inheritance.
- https://github.com/ddmills/geotic — MIT (dormant). Study its `world.serialize()`/`deserialize()`
  and JSON prefabs-with-inheritance — maps onto our save contract and Type-Object classes. Design
  reference only; do not adopt.
- https://github.com/Mugen87/yuka — MIT. Engine-agnostic game-AI kit: FSM, A*/Dijkstra, steering
  (seek/flee/wander/**flocking**), perception, navmesh, JSON save. Read it for follower/enemy brains
  and for boids that break robotic synchrony; port the ideas, don't add the dependency.
- https://github.com/isaac-mason/recast-navigation-js — MIT. WASM Recast/Detour; **runtime** navmesh
  generation for procedural dungeons, obstacles, crowds. The reference for pathfinding once there are
  interiors to path through.
- https://github.com/gkjohnson/three-mesh-bvh — MIT, actively maintained. BVH acceleration for
  raycasting / collision / spatial queries — the reference if per-frame picking or "what's near me"
  in an open world ever needs to be fast. Plain three.js, chassis-compatible.
- Red Blob Games (Amit Patel) — https://www.redblobgames.com/pathfinding/a-star/introduction — the
  canonical A*, hex-grid, and grid-as-graph tutorials for any future grid/pathfinding work.
- https://github.com/mxgmn/WaveFunctionCollapse — the original WFC, for coherent procedural room/tile
  adjacency (pairs with BSP; see Systems patterns).
- Robert Nystrom, *Game Programming Patterns* — https://gameprogrammingpatterns.com — the pattern
  vocabulary these docs use: Component, Update Method, Game Loop, State, Object Pool, **Type Object**
  (classes/items), Event Queue, Spatial Partition, Flyweight, data-driven design.
- Glenn Fiedler, "Fix Your Timestep!" — https://gafferongames.com/post/fix_your_timestep/ — the
  fixed-timestep+interpolation loop. **Study-only for this chassis** (our loop is variable-dt clamped;
  see `13_ENGINE_PRINCIPLES.md`); it belongs to the rewrite proposal, not a current build.

**Not for adoption in this chassis:** React Three Fiber, an ECS library (Miniplex/Koota/bitECS),
Rapier, TypeScript, a bundler. They assume a different engine — see the guardrail in
`13_ENGINE_PRINCIPLES.md` and the owner-gated proposal in `docs/FUTURE_R3F_REWRITE.md`. Study for
ideas; never add as a dependency here.

> **Dated correction (2026-08-01):** the paragraph above is the pre-conversion rule, kept for
> the record. The owner walked the rewrite gate on 2026-07-30; the chassis IS now R3F +
> Miniplex + TypeScript + Vite in `engine/`. What survives unchanged: chassis replacement is
> never the builder's call — the same gate governs any future change (see the S410 renderer
> gate in `docs/ROADMAP_500.md`). Rapier remains unadopted.

---

## Systems patterns

**Loot generation, Diablo model.** Items carry an item level. Affixes are split into prefix and
suffix pools, each weighted, each belonging to a family so an item cannot roll two of the same kind.
Rarity gates how many affixes an item may have. Fixed uniques with rolling value ranges provide the
chase items. Combinatorics give infinite items; families and tiers stop it becoming noise.

**Terrain.**
- https://www.npmjs.com/package/@interverse/three-terrain-lod — quadtree chunked LOD, the right
  choice for a streaming world
- https://github.com/mattes3/THREE.Terrain — maintained fork of the classic generator

**Dungeons.** Binary space partitioning for built structures, cellular automata for caves. Add loops
to the room graph rather than shipping a pure tree; pure mazes are bad for combat.

**Enemy design.** https://book.leveldesignbook.com/process/combat/enemy
Define four to six base behaviours and generate variety by stat and model reskin. Lay the roster out
on a matrix of speed, range, HP, and role to find gaps. Named archetypes to fill it: swarmer,
telegrapher (the grike, already), glass-cannon, tank, ranged/caster, support/leader — behaviour is the
"class", stat/model reskin is the "unit".

**Offline / delegated progression.** The industry technique is timestamp-delta, not background
simulation: on load, read elapsed real time and compute the result forward in one step (drill already
does this via `march` drift — see `13_ENGINE_PRINCIPLES.md` §3). For growth/curve design when jobs get
richer: Anthony Pecorella, "The Math of Idle Games" (gamedeveloper.com, 3 parts). The device clock is
cheatable — a caveat to weigh if trust ever matters.

---

## Character design — how to make classes readable

Riot's published clarity rules, which map directly onto the class-identity pillar:

- A silhouette has **primary, secondary, and tertiary** features. The primary feature is never
  removed or altered. Senna's gun. Diana's crescent blade.
- The silhouette should telegraph where the character's power comes from. A bow means ranged.
- Facing direction must be readable from silhouette alone.
- **Squint test:** blur the image until detail disappears. If it still reads, it works.
- Detail should reinforce the major silhouette reads, never break them up. Alternate dense detail
  with visual rest.

**Applied here:** one unmistakable shape per class. Knight reads as pauldrons and a shield block,
archer as a bow curve, rogue as hood and daggers. **Promotion adds a secondary read rather than
replacing the primary** — bigger pauldrons, a cape, a crown. That is how a promoted unit stays
recognisably the same character.

---

## Performance ceiling — plan around this, do not discover it

Draw calls are the bottleneck, not triangles. Past roughly 500 draw calls per frame most hardware
struggles.

**In WebGL, instancing does not cover skinned animated characters.** Plan for **a few dozen
individually animated humanoids on screen, not hundreds.**

- Instance every static prop. Grass, trees, rocks, crates.
- Share materials and texture atlases so batching can happen.
- LOD distant characters down to simplified meshes.
- Cap simultaneous full-skinned actors, roughly 20 to 40 nearby.
- Keep every character on one shared skeleton.

If hundreds of animated characters ever become necessary, that is the trigger to move to WebGPU,
which Electron's Chromium supports. Do not fight WebGL to get there.

**Concretely, the skinned-crowd options, in order of preference:** (1) ordinary `SkinnedMesh` +
`AnimationMixer` for the handful of hero/near-camera units — the default, all we need now; (2) **VAT**
(vertex animation textures — bake animation frames into a texture, read in the vertex shader; NVIDIA
GPU Gems 3 Ch.2 got ~10k characters on 2007 hardware) for many distant units, at the cost of no
runtime blending; (3) **WebGPU** native skinning+instancing (cleanest, needs the WebGPU renderer);
(4) a userland `InstancedSkinnedMesh` copied from three.js PR #22667 — **no maintained npm package
exists**, and the CPU cost of filling the per-instance bone texture each frame is the real bottleneck.
Treat skinned-crowd scaling as an explicit R&D iteration, not a library install, and only when
profiling shows the drop — community reports put the wall around 20 on-screen skinned actors.
