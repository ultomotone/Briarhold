# ROADMAP — the work order

The builder's increment is the topmost unchecked step. Tick it when it ships; never reorder or
reword in a scheduled run. `[owner]` steps are owner-present sessions. Each step is sized to one
run. The roadmap fixes WHAT; HOW is the builder's, guided by `docs/design/CODEX.md`.

Weekly-visible rule: every seven consecutive runs include one step visible in the first thirty
seconds of play.

## Arc 0 — The slice (owner-present, 2026-09-02)

- [x] S000 Vertical slice: field, knight, shrine, squad verbs, carry, seeds, grub, vent, gate,
  night, shell, save, gate, doctrine.

## Arc 1 — Feel and legibility (the slice made honest)

- [ ] S001 Hand-playtest harness: `tools/play.gd` scripted 90-second run (pluck, throw at pellet,
  deliver, wake grub, survive dusk) that fails on any stuck sprig or a knight outside bounds.
- [ ] S002 Sprig arrival: followers slow and settle into slots instead of jittering; idle sprigs
  breathe and look around on their phase.
- [ ] S003 Throw feel: a held Space aims, release throws; the arc disc turns amber when it would
  land on a task (enemy, load, gate).
- [ ] S004 Whistle feel: ring grows with a soft pulse, sprigs answer in a wave by distance, the
  sound-less "called" flash on each sprig.
- [ ] S005 Carry legibility: a count over a load ("3 / 6") and a faint ground line along its path.
- [ ] S006 Grub legibility: the sleeping breath, the wake stretch, the mouth opening through the
  telegraph, the shake with sprigs flung along real arcs.
- [ ] S007 Knight feel: sword trail, a short step into the swing, hit-stop of two frames on
  contact, backstrike flash.
- [ ] S008 The night made visible: stalker eyes at the rim before they close, the ring glowing
  brighter as dusk falls, a dusk banner with the count coming.
- [ ] S009 Camera: smooth follow lead in the movement direction, a small pull-back when the squad
  spreads, the 45° turns eased.
- [ ] S010 Minimap top-right: the field as a fog-of-war disc that fills in as he walks; shrines,
  Hold, known gates and mouths as marks.

## Arc 2 — The squad, complete

- [ ] S011 Lock-on: hold Tab to lock the nearest enemy; throws and charges resolve on it; the
  camera frames both.
- [ ] S012 Nectar: drops from felled enemies and vent-adjacent flowers; an idle sprig drinks and
  blooms; the whistle pulls a squad through it.
- [ ] S013 Maturity that matters: bloom sprigs carry at ×1.2, slap ×1.1; the chip shows the
  bloom count.
- [ ] S014 Shrine storage: inside/outside counts on the chip; stand at a shrine and hold F to
  withdraw, Q/E to pick which type.
- [ ] S015 Sprig loss recovery: a felled sprig outside the safe ring leaves a seed 30% of the
  time (deterministic by id); a sprig that carries it home replants it.
- [ ] S016 Dismiss piles by type stay put; whistle a single pile by clicking near it.
- [ ] S017 Spark sprigs: shrine in the field behind a dirt wall; ×4 dig; the first buried relic.
- [ ] S018 Electric wire hazard: Spark walks it, others are shocked and flee; a wire gate.
- [ ] S019 Tide sprigs: a pool with a shrine on the far side; drowning status, Tide rescue.
- [ ] S020 Bridge: carry three planks to a gap; sprigs build; the navmesh grows.

## Arc 3 — Relics, the workshop, and gadgets

- [ ] S021 Relic codex on the pause screen: found / banked / set progress, one line each.
- [ ] S022 Relic sets: sewing, locks, coins; completing a set raises the Hold total and unlocks
  one workshop row.
- [ ] S023 The workshop panel at the Hold (layout button, not a menu): gadgets for relic value.
- [ ] S024 Gadget: Long Whistle (radius ×1.4).
- [ ] S025 Gadget: Rush Boots (knight ×1.25 speed).
- [ ] S026 Gadget: Scorch Guard (knight fire damage halved).
- [ ] S027 Gadget: Idle Call (a key that whistles every idle sprig in the field to him, once a
  day).
- [ ] S028 Blast burrs: craftable; a sprig carries one, drops it at a wall; reinforced walls.
- [ ] S029 Provisions: fruit-like loads that feed the Hold; a Hold that eats grows its ring.
- [ ] S030 Thorn sprigs: shrine behind a poison vent; ×2 on brambles; poison gas gate.

## Arc 4 — Night, made a game

- [ ] S031 Night pellets: glow pellets appear at dusk; carried home they make Wisp sprigs that
  vanish at dawn.
- [ ] S032 Wisp mob: hold C with Wisps selected to charge a stun burst.
- [ ] S033 Night defence objective: a Lantern at the ring that stalkers try to snuff; keeping it
  lit through the night pays a relic.
- [ ] S034 Stalker variety: a runner, a burrower that ignores the ring edge, a caller that brings
  more.
- [ ] S035 Pollen: brewed from provisions; rage (×2 attack rate 30 s), petrify (9 s, no corpse).
- [ ] S036 Morning report on the pause screen: what came, what was lost, what was kept.
- [ ] S037 Frost sprigs: a frozen pool crossing; freeze ring on enemies; shatter airborne.
- [ ] S038 Crystal walls: Stone breaks them; a crystal-caged relic.
- [ ] S039 Moth sprigs: fly over water and walls; lift a hanging bag gate.
- [ ] S040 Oak sprigs: strength 10; a boulder only they move; slam stun on bosses.

## Arc 5 — Wardens (the named ones)

- [ ] S041 Warden records: a sprig that has carried 50 weight or landed 30 slaps is offered a
  name at the shrine; named sprigs are saved and never lost.
- [ ] S042 Warden panel (layout): name, type, class, level, deeds.
- [ ] S043 Warden experience: carries, slaps, digs, nights survived; levels raise strength and
  damage.
- [ ] S044 Promotion, first rank: an item from a burrow or a gate clear; Ember → Cinder Squire,
  Stone → Flint Warden; a second silhouette read.
- [ ] S045 Wilting: a Warden at 0 HP becomes a seed that flies to the seedbed; replant costs a
  Heartroot fragment.
- [ ] S046 Wardens in carry groups: a Warden's strength counts double; the group moves at its
  pace.
- [ ] S047 Wardens in fights: a Warden slaps for its own damage and does not get shaken on the
  first shake.
- [ ] S048 Second rank: Pyre Knight, Bastion; class lines for Spark, Tide, Thorn.
- [ ] S049 Rescued Wardens: a Warden of a type he does not have, found in a burrow.
- [ ] S050 `[owner]` First play session: verdicts on feel, night, Wardens.

## Arc 6 — Shrines and detachments

- [ ] S051 Shrine merging at the Hold: one shrine with rings per type.
- [ ] S052 Grafting: two shrines and a Heartroot make a hybrid type row.
- [ ] S053 Detachments: a promoted Warden leads a group on a drawn path (right-drag) and holds
  there.
- [ ] S054 Standing orders: gather, dig, build; resolve while away on the clock.
- [ ] S055 The delegation ledger on the pause screen.
- [ ] S056 Territory: outer shrines that raise the safe ring; stalkers can snuff them.
- [ ] S057 Weather: rain slows, fog hides the rim, wind bends throws.
- [ ] S058 The map fills in; secrets marked only when found.
- [ ] S059 Fast travel: root-gates between rooted shrines.
- [ ] S060 `[owner]` Second play session.

## Arc 7 — Burrows

- [ ] S061 Burrow mouths with a severity readout; enter with the squad; a single generated floor.
- [ ] S062 Sublevel generator: rooms and corridors from the seed, typed spawn spots.
- [ ] S063 Rest floors and the geyser out.
- [ ] S064 Boss floors: a Snag-neck (snagret grammar).
- [ ] S065 Burrow relics and the contents re-roll schedule.
- [ ] S066 Time at 1/6 inside; the night still comes.
- [ ] S067 Burrow hazards by theme: fire floors, flooded floors, wired floors.
- [ ] S068 A second boss: the Stomper (beady long legs grammar), Stone and Moth work.
- [ ] S069 Candy-shrines: convert five sprigs to a type he lacks.
- [ ] S070 Deep burrows: ten floors, a long special every few days.

## Arc 8 — Trials and the score

- [ ] S071 Trials: timed collect-everything on a generated plot; score = weight + seconds left.
- [ ] S072 Medals and a best-score line on the title.
- [ ] S073 The daily trial: seeded by the date.
- [ ] S074 Rival crews: a simulated crew on the split plot; sneak burrs and comeback rules.
- [ ] S075 Battle trials: defeat everything on the plot.
- [ ] S076 Boss trials.
- [ ] S077 A leaderboard of his own bests by trial and by day.
- [ ] S078 Trial rewards: cured Wardens, raw material for gadgets.
- [ ] S079 Trial replays as ghosts.
- [ ] S080 `[owner]` Third play session.

## Arc 9 — Bosses, presence, and the widening field

- [ ] S081 Influence: a boss commands nearby packs.
- [ ] S082 Intelligence by presence: enemies ignore bait, flank, and target him above a Hold
  total threshold.
- [ ] S083 The field widens: a second region past the rim, gated by a Heartroot count.
- [ ] S084 Region two's shrine, hazards, and boss.
- [ ] S085 A third region.
- [ ] S086 Bosses heal with a visible cause, never on a timer.
- [ ] S087 The Emperor grammar: a buried boss that needs bombs and Oaks.
- [ ] S088 A shapeshifting final-grammar boss that needs every type.
- [ ] S089 Boss relics and the boss codex.
- [ ] S090 `[owner]` Fourth play session.

## Arc 10 — The Hound and the knight's growth

- [ ] S091 The Hound: a mount found in region two; ride it; the squad rides with him.
- [ ] S092 Hound tree: Buff, Chomp, Rush, Dig, Paddle, Pluck, Heal, Command.
- [ ] S093 Knight skills that rise by use: sword, whistle, throwing, plucking.
- [ ] S094 Knight abilities with cooldowns: Dash, Rally, Guard.
- [ ] S095 Knight gear: helm, blade, boots, charm; one effect each, on the body.
- [ ] S096 The forge: relic value and materials into gear.
- [ ] S097 Respec at the Hold; nothing lost.
- [ ] S098 The knight's death pile: dropped loads where he fell.
- [ ] S099 Custom knight name and colours.
- [ ] S100 `[owner]` Fifth play session, the name of the game confirmed or changed.

## Arcs 11–12 — Polish, sound, mobile (sketched; expanded at S100)

- [ ] S101 Sound: the first ten sounds (pluck, throw, land, whistle, slap, bite, deliver, seed,
  dusk, dawn).
- [ ] S102 Music: one dawn theme, one dusk theme.
- [ ] S103 Authored knight model (CC0 glTF) on the same rig discipline.
- [ ] S104 Authored sprig mesh per type.
- [ ] S105 Mobile renderer wall-test.
- [ ] S106 Touch controls.
- [ ] S107 Phone layout.
- [ ] S108 Android export.
- [ ] S109 Steam-shaped export: icon, installer, storefront copy.
- [ ] S110 `[owner]` Where next.
