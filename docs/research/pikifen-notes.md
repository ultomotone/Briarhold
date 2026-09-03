# Pikifen study — what we took, what we left

2026-09-02. Pikifen (Espyo, MIT) is a 2D C++/Allegro Pikmin engine with 23 shipped enemies, a
data-driven mob model, and a mission system. Cloned read-only into the session scratchpad and
studied in four passes: squad and leader, carrying and paths, enemies and hazards, missions and
config. Nothing was copied verbatim; the shapes and numbers below were re-derived at our scale.
Scale: 1 m ≈ 24 Pikifen px (their Pikmin radius 5 px, our sprig radius 0.21 m).

## Applied in the slice (S000b)

| Area | Pikifen | Briarhold now | Where |
|---|---|---|---|
| Whistle growth | 180 px/s to 80 px → 0.44 s | 0.45 s to full radius | `world.json` squad |
| Whistle centre | cursor clamped to 200 px | clamped to 8 m (`whistle_reach`) | `SquadSystem.whistle_centre` |
| Whistle on knockdown | shaves 1.2 s off 1.8 s, once | shaves stun to 0.25 s, anyone in the ring | `_whistle` |
| Formation | rings at n·(2r+gap); counts from body size (1, 3, 8, 12…); sorted front-first | same formula, centre spot, selected type then bloom-first at the front | `slot_offset`, `_assign_slots` |
| Shuffle deadband | anchor eases only when squad centre strays | `follow_deadband` 1.7 m + √n·0.3 | `_update_anchor` |
| Swarm | anisotropic: long along the cursor line, half as wide | same | `_follow` |
| Throw pick | ripest first, then nearest, within 128 px | maturity-first within 5.4 m | `_throw` |
| Throw arc | fixed apex per type, time derived | `throw_height` per type, T = √(8h/g) | `flight_time` |
| Auto-throw | 0.15 s cooldown; hold: 0.5 s then ramps to 0.18 s | hold Space: 0.5 s then ramps to 0.18 s | `_throw_input` |
| Idle work | nearest-wins, no category priority, 50 px | nearest-wins across enemy, load, gate, 3 m | `_idle` |
| Chase leash | 200 px | 8 m: an attacker gives up | `_attack` |
| Dismiss | hex piles (1, 6, 12, 18 rows at 7.5 px) on an arc at 48 px, from the squad's centre | same at 0.32 m rows, 2 m arc; 5 s work lock on the pile | `_dismiss` |
| Leader speed | 135 vs 110 (1.23×) | knight 5.6 vs sprig 4.6 | `world.json` knight |
| Next-pluck range | 200 px | 8 m | `pluck_seek_radius` |
| Post-hit invuln | 1.5 s hit / 2.5 s knockback | 0.9 s on any hit ≥ 5 | `Damage.to_knight` |
| Carry speed | avg × (1 − 0.0004·weight) × 0.8 × (0.3 + fill·0.7) | base × 0.8 × (1 − 0.01·weight) × (0.3 + fill·0.7) | `CarrySystem.speed_for` |
| Carry spots | ring rotated to face the first claimant; nearest free spot | same, `WorldObject.slots` | `CarrySystem.join` |
| Carry type tie | majority, then smaller population | same | `majority_type` |
| Pellet 20 | 50 carriers | 50 | `objects.json` |
| Relic value | does not track weight | button 90 at weight 3, thimble 40 at 6 | `objects.json` |
| Seed scatter | hashed counter, angle += TAU·0.12345 | golden angle on the seed count, no roll | `HoldSystem._plant` |
| Sprout stages | 120 / 120 / 180 s | same | `stage_seconds_1/2/3` |
| Shake gate | itch_damage AND itch_time | same (`itch_time` per enemy) | `EnemySystem.step` |
| Back damage | back hitbox 0.8 (takes less) | `back_multiplier` 1.25 (takes more): our back is the reward, not the armour | `Damage.facing_mult` |
| Hazard statuses | speed multiplier, remove-on-leave vs remove-on-whistle, disables attack | `speed_mult`, `hazard_leave_cures`, `disables_attack` | `hazards.json`, `HazardSystem` |
| Trials config | criteria × points, four medal thresholds | `world.json` trial block; model in ROADMAP Arc 8 | — |

## Deferred to the roadmap

- **Enemy behaviour as data** (now S016). Pikifen's 23 enemies share one engine; every difference
  is a script of states, events, and a closed action vocabulary, with timing on the state. Our
  `enemy_system.gd` hardcodes one archetype. The proposed JSON shape is in ROADMAP S016; the
  rule that keeps it honest: `on` keys are only events the sim raises, `do` verbs are only what
  the sim implements, unknown keys fail the content test.
- **Trials as three lists** (Arc 8). No goal enum: end conditions (with `clear` true/false),
  tracked groups, score criteria with signed points; medals by thresholds; four HUD slots;
  `on_hud=false` for the time bonus so it never ticks down in front of him.
- **Tracked groups** for the minimap (S010) and the relic codex (S021): one declaration drives
  the counter, the highlights, and the "all of them" target.
- **Path-link flags** (`light_load_only`, `airborne_only`, ledge links) as the data-only way to
  make Moth-only and Tide-only routes when S020's bridge grows the navmesh. Carrier gating is
  all-or-nothing on the carrier set (every carrier must be immune to route through a hazard).
- **Group tasks** (push a box, build a bridge): power = Σ contribution, goal threshold, speed
  above goal. Add a `task` object kind at S020.
- **Piles and resources**: attack a pile to chip resources; resources carry to a target and
  `damage_mob` it (a bridge is 30 fragments against 30 HP). S020 again.
- **Storage returns the best stock** (highest maturity first): we store counts, not maturities.
  S014.
- **Sprig regen** (Pikifen Pikmin regen 10/s after 2 s; leaders never regen) is the opposite of
  ours. Watch how the knight's regen plays before deciding.
- **Enemy archetypes to add next**, with numbers from the study: Kilnhog (fire cone, HP 1000,
  itch 50/2 s), Stiltspider (jump-crush, HP 1600, itch 20/7 s, punishes clumps), Vaultbeetle
  (plated, weak spot only, HP 1300, 50 carriers). Arc 4 and Arc 9.

## Left alone on purpose

- Pikifen's Z is a ledge scalar, not an axis; its throw-height and "can I reach that ledge"
  logic does not port to a heightfield.
- Per-hitbox LATCHABLE/BOUNCY surfaces: our `attack: latch|impact` on the type is the right
  3D simplification.
- The 100 field cap and the leader-thrown-by-leader rule.
- `revive_time`: every shipped enemy sets it to 0. Not worth a field.

Sources: `source/source/content/mob/*.cpp`, `mob_script/*_fsm.cpp`, `core/pathing.cpp`,
`content/area/mission.*`, `game_data/base/misc/config.txt`, `game_data/base/mob_types/**`,
`game_data/base/statuses/*`, `game_data/base/areas/mission/*/data.txt`.
