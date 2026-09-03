# Pikmin design reference

Compiled 2026-09-02 from Pikipedia, the Pikifen manual and repo, Nintendo's "Ask the Developer"
interviews, and critique threads. Structure studied; names, art, and content never copied.
Numbers are the genre's tuning baseline; Briarhold's own live in `content/`.

## 1. Core loop

- Day length (real time): P1 13:30, P2 13:02, P3 13:00, P4 15:02; sunset warning 1–2 min;
  final countdown ~30 s. P1 had a 30-day limit; P2 none; P3 a renewable juice limit; P4 none.
- Sunset: Pikmin safe only in a leader's squad, near an active Onion, or still buried. Everyone
  else dies overnight. P4 corpses persist across days.
- Onion economy: pellets 1/5/10/20 → 2/5/10/20 seeds matching, 1/3/5/10 otherwise. Max carriers
  2× weight. Corpses give a fixed per-species seed count (Bulborb 10–12 at weight 10).
- Seeds only root while the field count is under the cap; excess stored. Sprout stages every
  ~2 min buried.
- Mixed carriers: the load goes to the majority type's Onion.
- Field cap 100 (P1–3); P4 starts at 20 and adds +10 per Flarlic (12 exist). P4 also caps
  types in the field at 3, widely disliked.
- Pluck: leader within pluck range; upgrades let the whistle pluck.

## 2. Types

Per-slap damage: Red 15; Yellow/Blue 10; Purple 20 (P2) / 15; White 5–10; Rock 20–40 impact;
Winged 5; Ice 5; Glow 10. Maturity does not change damage in the official games.

| Type | Immunity | Ability |
|---|---|---|
| Red | fire | 1.5× damage |
| Yellow | electric | highest throw, ×4 dig (P4), bomb carrier (P1) |
| Blue | water | walks underwater, rescues drowning |
| Purple | none | strength 10, slam 50 + stun |
| White | poison | fastest, poisons what eats it, finds buried treasure |
| Rock | crush, stab | impact attack, no latch, breaks crystal |
| Winged | crush, pits | flies, lifts hanging loads |
| Ice | freeze | fills a freeze meter; frozen enemies shatter airborne or thaw to nectar |
| Glow | all elemental | night only, teleports to squad, Glowmob stun |

Maturity: leaf < bud < flower in speed (Pikifen 100/110/120%). Nectar flowers instantly. Sprays:
10 berries = 1; spicy 30–40 s of ×2 attack rate; bitter 9 s petrify.

Teaching: every game introduces a type in a room only it can solve, then puts that hazard on the
critical path.

## 3. Commands

- Throw: hold grabs nearest of the selected type, release throws at the cursor; arc preview in
  P3/P4; ~3–4 throws/s; landing on a task starts it, on an enemy latches.
- Whistle: radius grows while held (~1.6–2 s to max); cures burning/poison/webbing, pulls
  drowning to shore; short whistle pauses workers, long recalls.
- Dismiss: splits by type into piles; idle Pikmin then auto-task.
- Swarm (P1/2): the squad moves as a blob. Charge (P3/4): squad rushes the locked target.
- Lock-on (P3): camera frames target and leader. P4's forced auto-lock was disliked.
- Group behaviour: loose circle behind the leader, elliptical when moving, leaf Pikmin lag;
  too far and they drop out; P2 added wall-following.
- Multi-captain (P2/P3): inactive leaders idle with their squad; Go Here draws a path.
- Oatchi (P4): rideable; merges leader and squad into one unit; own HP and skill tree (Buff to
  100 carry strength, Chomp, Rush, Dig, Paddle, Pluck, Heal, Command, Swallow). Widely judged to
  trivialise combat and carrying.

## 4. Carrying and treasure

- weight = minimum strength; max_carriers usually 2× weight; speed rises with carriers above the
  minimum. Pikifen: speed = base × lerp(0.3, 0.8, fill) − 0.0004 × weight.
- Carriers pick the shortest currently open route at pickup.
- P1: 30 ship parts, 25 mandatory. P2: 201 treasures, ~27k Pokos, 10k clears the debt. P3: 66
  fruit, 0.5–3 cups each, one cup a day. P4: ~240 treasure types, Sparklium gates areas
  (1.5k / 4k / 7k / 11k / 13k).

## 5. Enemies and combat

- Pikmin have no HP: attacks kill outright or apply a timed status the whistle cancels. Bite
  caps: P1 3, P2 5 per bite.
- Bulborb: 750–1100 HP, weight 10, sleeps by day; approach from behind, throw onto the back,
  retreat on the shake. Wollyhop: jump-crush, throw after the landing. Snagret: emerges,
  pecks 3–5, head is the weak point, 40% stuck-emerging punish window. Beady Long Legs:
  stomp-crush, hit the dangling core. Emperor Bulblax: bombs to stun, then Reds on the face.
  Waterwraith: invulnerable rolling crusher until Purples hit it; a cave timer boss. Plasm
  Wraith: a "use every type" exam.
- Hazard counters: fire→Red; water→Blue (Ice freezes it, Winged fly over); electric→Yellow;
  poison→White; ice→Ice; crush/stab→Rock; gloom kills all.
- Corpses are resources; overworld respawns per day per species; cave enemies regenerate on
  re-entry.

## 6. Caves, Dandori, nights

- P2 caves: 14 caves, 2–15 sublevels; time frozen; no Onion so losses are permanent for the run;
  floors normal / rest / boss; generation from a seed via typed cave units and ordered spawn
  categories; each cave has a hazard theme.
- P4 caves: 23, hand-built, time at 1/6, mostly under 5 floors; Rewind replaces restart.
- Dandori Challenges: 5–7 min collect-a-thons; score = delivered weight + seconds left; four
  medals. Dandori Battles: 1v1 vs AI, weight scoring, capsules every 30 s, sneak bombs, comeback
  multipliers.
- Night expeditions: 4 min + dawn timer; defend Lumiknolls; Glow Pikmin from glow pellets 3:1;
  Glowmob stun; rewards Glow Sap and Glow Seeds.

## 7. Exploration and gadgets

- Areas: one landing site per area, hub-and-spoke with gated pockets; gates are investment
  decisions.
- Obstacles: bramble gate, dirt wall, reinforced wall (bombs), electric gate, crystal, ice wall,
  bridge fragments, boxes (push), paper bags (crush), clipboards (Winged lift), mud, sticky
  mould, jelly (freeze), tunnels (dig), geysers.
- P4 gear (raw material, gated by Sparklium): Charging Horn 20, Headlamp 30, Treasure Gauge 40,
  Air Armor 40/80/120, Anti-Electrifier 50, Idler's Alert 80, Homesick Signal 80, Brace Boots 80,
  Rush Boots 120, Plucking Whistle 240, Gunk Busters 240, Survey Drone, Scorch Guard, Thermal
  Defense, Lineup Trumpet, Extra Hand.

## 8. Meta

- Castaways = Pup Drive; leaflings cured via trials; Onion merging; Flarlic cap raises; medals;
  treasure catalog series bonuses; photo mode.
- Difficulty: P4 Relaxed / Normal / Fierce (60 cap, 2× HP, 2× bites).

## 9. Feel

- Cameras: P1/2 fixed zooms and two angles; P3 auto-zoom framing the squad line; P4 free
  right-stick, close to the ground.
- What makes it feel good: reactive tools (idle Pikmin auto-pick the nearest task within
  ~1–2 body-lengths×10), the whistle as a forgiving undo, squad cohesion that reads alive,
  enemies that telegraph, visible logistics.

## 10. Pikifen (data model to copy the shape of)

- Mob categories: pikmin, leader, enemy (FSM script), onion, ship, pellet, treasure, bridge,
  group_task, scale, track, bouncer, converter, decoration, drop, pile, resource, tool,
  interactable, custom.
- Common props: max_health, move_speed, radius, height, weight, max_carriers, territory_radius,
  health_regen, itch_damage / itch_time (shake-off), vulnerabilities per hazard (damage %,
  status), spike_damage.
- Pikmin type: attack_method latch|impact, carry_strength, max_throw_height, can_fly,
  sprout_evolution_time 120/120/180, knocked_down_duration 1.8 (+whistle bonus).
- Status: speed/attack/defense multipliers, health_change, auto_remove_time, remove_on_whistle,
  buildup (freeze meter), maturity_change, replacement_on_timeout.
- Config: max_pikmin_in_field 100, carry 0.3→0.8 by fill, whistle growth 180 px/s, max 200,
  idle_task_range 50, chase_range 200.
- Worth copying: the vulnerability/status split, the carry curve, itch_damage, territory
  leash, carry-path links with type rules, score-criteria-as-weights for missions.

## 11. Lessons

- Frustrations: sunset losses and hard day limits; P2 caves stretching sessions to 2 h with
  unrecoverable losses; P4's Oatchi trivialising things, forced lock-on, low camera, 3-type
  cap, heavy tutorials; AI pathing deaths; whistle grabbing workers you didn't want.
- Loved: dandori as a visible skill, solve-the-enemy combat, watching carry lines, type-gated
  exploration, the tiny-world tone, co-op, the battle modes.
- Wishlist: real pressure or a hard mode, no type cap, less handholding, fewer types with
  deeper interactions or genuinely new mechanics, roguelite expeditions with persistent base
  upgrades, world persistence, new settings.

## Quick-start sheet

Day 13–15 min, warning 1–2 min · cap 20 → +10 per relic → 100+ · pellets 1/5/10/20 → 2/5/10/20
matching, halved otherwise · carriers = 2× weight · carry speed 0.3 → 0.8 by fill · maturity every
2 min, bloom +20% · slap base 10, combat type 15, utility 5, heavy 10 strength / 50 slam · whistle
~1.8 s to max · idle task radius ~3 units · leash ~20 · enemy HP fodder 200, mid 750–1300, boss
2500–3300 · bite cap 3 · stun 5 s · freeze 6–9 s · timed modes 4–7 min, score = weight + seconds.
