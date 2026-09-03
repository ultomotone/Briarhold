# THE CODEX — design intent for Briarhold

The roadmap fixes what; this fixes why. Fixed in shape, open in flesh.

## 1. The three laws

1. **Randomness sets the problem, skill solves it.** Where things are is rolled from the seed.
   What happens when he acts on them is deterministic. No dice in combat, ever.
2. **Matchup prices, investment decides.** Ember's fire immunity, Stone's crush immunity, a
   Warden's class advantage: prices, never outcomes. Enough invested strength overcomes any
   matchup; a disadvantage is a tax the strong can afford.
3. **Nothing is ever lost.** Swarm sprigs are the expected cost of the field. Wardens wilt to
   seed. The Hold total only rises. Banked relics are safe.

## 2. Pikmin coverage, uncapped

Every mechanic of Pikmin 1–4 has a home. The caps are what we removed.

| Pikmin | Briarhold | Uncapped |
|---|---|---|
| Captain, throw, whistle, dismiss | Knight with the same verbs | He also fights, with a sword kit |
| Swarm, charge, lock-on | All from the start | Charge by type or all |
| Onion, pluck, seeds | Shrine, sprouts, seeds | Shrines grow, merge, and graft hybrids |
| Leaf / bud / flower, nectar | Leaf / bud / bloom, nectar | Bloom is a floor; sprigs keep levelling |
| 100 cap, +10 per Flarlic | 20 start, +10 per Heartroot | No designed ceiling |
| 3-type field limit | none | removed |
| 9 types | 8 base + Wisp + hybrids | Roster is data |
| Carry weight, carriers, speed curve | Same numbers | Oak ×10, Wardens add strength |
| Treasure, ship parts, fruit | Relics + sets, Heartroots, provisions | Relic lists re-roll in burrows |
| Day timer, sunset losses | Soft day, dangerous night | No guillotine |
| Enemies: sleep, eat, crush, shake, corpses | Same archetypes, own bestiary | Intelligence scales with presence |
| Hazards: fire, water, electric, poison, ice, crush | Status / vulnerability matrix | New hazards are rows |
| Gates, walls, bridges, boxes, bags, tunnels | Same catalogue | Delegable to work-crews |
| Bomb rocks | Blast burrs | Craftable |
| Sprays | Pollen (rage / petrify) | Brewed from provisions |
| Caves, Rewind | Burrows: seeded, severity at the mouth, time at 1/6 | No rewind (no undo) |
| Multi-captain, Go Here | Wardens lead detachments on drawn paths | Any number |
| Oatchi | The Hound, with its own tree | More mounts later |
| Castaways, Pup Drive | Rescued Wardens, promotion items | Open-ended roster |
| Gear bought with raw material | Workshop gadgets bought with relic value | Grows per era |
| Dandori challenges and battles | Trials, scored, medals; simulated rivals | A daily trial |
| Night expeditions, Glow Pikmin | Every night is one; Wisp sprigs from night pellets | — |
| Onion merging, storage | Shrine merging; storage unlimited | — |
| Difficulty modes | none; threat scales with presence | — |
| Story, ending | none; the world keeps expanding | — |

## 3. The eight types (and one)

Name → immunity → job → what it unlocks. Names decode on sight.

- **Ember**: fire · +50% damage · fire vents, burning brambles.
- **Stone**: crush and stab · impact attack, no latch · crystal, stompers.
- **Spark**: electric · highest throw, ×4 dig · wires, ledges, buried things.
- **Tide**: water · walks submerged · pools, drowning rescue.
- **Thorn**: poison · fastest, ×0.5 damage, ×2 vs brambles · poison gas, gates.
- **Moth**: crush, pits · flies over water and walls, lifts · shortcuts, hanging loads.
- **Frost**: freeze · fills a freeze ring; frozen shatter or thaw to nectar · crossing water.
- **Oak**: none · strength 10, slow, slam · heavy loads, boss stuns.
- **Wisp**: everything on the ground · night only · night defence.

Hybrids (Arc 6): two shrines grafted at the Hold yield a type with both immunities and the mean
of the rest. Data rows, generated once, named by their parents ("Ember-Tide").

## 4. The two-tier army

The **swarm** is plentiful and expected to die. **Wardens** are named sprigs that earn experience
from what they carry, fight, and dig; promote along class lines (Ember sprig → Cinder Squire →
Pyre Knight; Stone → Flint Warden → Bastion); carry a second silhouette read when promoted; add
strength, damage, or speed to carry groups and fights they join; and lead detachments. At 0 HP a
Warden **wilts to a seed** that returns to the Hold's seedbed; replanting costs a Heartroot
fragment or a night's watch. Fire Emblem's grammar, Solo Leveling's rule.

## 5. The day

Fifteen minutes of day, six of night, a ninety-second dusk warning. At night stalkers enter from
the rim in a count that rises with the day and the Hold total (`EnemySystem.raid_size`). Anything
outside the safe ring is prey: sprigs, loads, him. Inside the ring nothing touches. Dawn drives
them off and the morning tally reads what it cost. Offline, nights resolve as a capped delta:
farthest exposed sprigs first.

## 6. The Hold

Origin. Radius 9 (the ring), safe radius 14. Holds shrines, the seedbed, the stock of relics, and
(Arc 3) the workshop. The **Hold total** = seeds grown + relic value + felled×5 + gates×25 +
heartroots×50. It is the score, the visible mark of time, and the threat driver.

## 7. Burrows (Arcs 7–9)

Mouths in the field with a severity readout (1–5) and a size. Inside: seeded sublevels, no
shrine, time at 1/6, a rest floor every third, a boss floor last with a geyser out. Trash
respawns on re-entry; bosses do not. Contents re-roll on a schedule. Opt-in, with the risk stated
at the mouth. Relic sets and Heartroots live here.

## 8. Enemies

Four to six base behaviours; variety by stat and silhouette. Every enemy telegraphs on the body.
Every kill drops something (corpse for seeds, or nectar, or a relic). Bosses gain **influence**:
they command nearby packs. Intelligence rises with the Hold total: they start to ignore bait,
flank, and target the knight.

## 9. Relics, gadgets, delegation

Relics carry value and a set. Value buys gadgets at the workshop: Long Whistle, Rush Boots,
Scorch Guard, Idle Call, Lantern, Survey Moth, Blast Burr pouch. Delegation: a work-crew is a
standing order on a spot (gather, dig, build) that resolves on the clock while he is away.

## 10. The register

Overgrown garden at thumb scale, seen from an angled overhead camera close enough to read a leaf.
Green-gold and weathered, fog-and-light-driven, serious not cute. Faceted ground, primitive
silhouettes, one unmistakable shape per thing. Colour interest from light, not pigment. No
Disney, no cozy, no storybook. The HUD is dark glass and plain words; the world is the picture.
All colours in `content/palette.json`; the tests hold the seams.
