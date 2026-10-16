# VERDICTS

Daniel's rulings on what stays and what dies. **The kill list is absolute.** The builder appends
here from anything he says in chat and re-emits this file complete whenever it changes.

Carried from Embermarch on 2026-09-02: rulings there that are about how he plays, not about that
game's content, bind here too.

## Killed — never build this again

- **Pointer capture, any control that takes his cursor.** No lock-on-click, no lock toggle, no
  "immersive mode." The cursor is visible, free, hoverable. (Embermarch 2026-07-29.)
- **Node-graph traversal / top-down abstract traversal.** A token on a field of shapes. He is a
  character walking a continuous world.
- **Browser-tab delivery.** It is a desktop app.
- **A game with no title screen, no save slots, no version stamp.**
- **Unlabelled controls.**
- **Synchronised, identical follower behaviour.** The squad reading as one rigid organism is a
  fail. Per-sprig lag, pace, arrival, and idle life; no two alike. (Embermarch 2026-07-28.)
- **Dice.** Hit chance, damage rolls, crit-chance stats. Never, under any name.
- **Permadeath of a developed character.** Wardens wilt to seed; they are never gone.
- **Invented words on the interface.** A stat, button, meter, panel, or verb says what it is.
  "What the fuck is a turnblow?" (Embermarch 2026-08-02.)
- **Pikmin's three-type field limit.** Removed on purpose; it does not come back.
- **A hard sunset that kills everything outside.** The night has teeth; it is not a guillotine.
- **Firearms, futuristic weaponry.** Medieval. Swords first.
- **Forced story.** Situations, not dialogue. No ending.
- **Prestige / reset loops.** Nothing resets. The world matures and old areas outscale.

## The naming law (2026-08-02, carried)

1. Content may be invented: creatures, relics, places, Warden classes, gadgets.
2. Interface must be plain: stats, buttons, panels, meters, verbs, system words.
3. Invented content names must still decode. "Ember sprig" passes. "Thrumkin" does not.

Standing test: could a player who never read a design document work out what this does?

## Verdicts in play

- 2026-09-02: "D is move right, A is move left." The camera's right vector was mirrored; fixed.
- 2026-09-02: "Change the main character to a gnome." Done: red cap, white beard, blue tunic,
  boots, still the sword and the round shield. Code keeps the `knight` record name.
- 2026-09-02: "Otherwise I am liking the direction so far. This is so cool." The slice's
  direction is Keep.
- 2026-09-02: "Bringing pellets back and nothing happens; no animation from the monolith; the
  counts don't match." Cause: the field cap (20) was already nearly full from the starting
  sprouts, so seeds went inside the shrine silently. Fixed: cap starts at 40; loads now carry to
  the shrine of their type and are drawn up into it, seeds puff out of the top and arc down;
  the log says when a seed is kept inside because the field is full; the counts read "in the
  field N of cap", "inside shrines N", and each chip says "with you · in field · inside" in the
  same words. The shrine is the interface word for the monolith; "Onion" is Nintendo's.
- 2026-09-02: "No way to get access to sprigs in reserve." Hold F beside a shrine hands them
  back out one at a time while the field has room; the chip says how many are inside.
- 2026-09-02: "Build the village, sprigs doing things around it, defend that little area at
  night against monsters that go anywhere." Arc 1b on the roadmap: build tasks, the hearth,
  standing village work, raiders that chew what you built, the hut.
- 2026-09-02: "Make the sprigs way more cute, like the real thing." Rebuilt: a big round head
  on a small body, two dark eyes, stick arms and legs, one stem from the crown with a leaf, a
  bud, or a five-petal bloom by maturity; sprouts are the stem and its top out of the ground.
  Original primitives; proportions are the reference, nothing else.
- 2026-09-02: "How do I return them to their homes? F takes, how do I give?" G beside a shrine
  sends the squad of its type inside, one at a time; the chip counts them as inside.
- 2026-09-02: "Expand the map, more landscape; I ran around for ten minutes looking for new
  stuff and it wasn't there; randomized timers, animals, monsters. The night is super cool and
  intense." Field 160 → 240 m with hills and downs, four pools (Tide work, teased), two vents,
  two gated pockets, 56 pellets, five relic kinds in the open, seven grubs, 80 stones,
  thickets. Life on a clock: twelve pellet posies regrow on seeded timers; field beetles roam
  and bolt (six seeds if caught); every dawn rolls new beetles and, half the time, a grub that
  wanders in from the rim to a new bed. The night is Keep.
- 2026-09-02: "Hold Space to auto-throw, faster fights." Held Space repeats from 0.22 s at a
  cadence ramping to 0.15 s (Pikmin's throw cooldown).

- 2026-10-16: "Can we switch to the 4.8 beta?" Done through the owner gate: Godot 4.8 beta 1
  installed beside 4.7.2 in `%USERPROFILE%\Tools\Godot-4.8-beta1`, checksum verified; the gate
  passed on it unchanged (68 tests, five shots, no new warnings, identical renders). The gate,
  launchers, feature tag, and export templates now default to 4.8; 4.7.2 stays as the fallback.

## Keep — proven, protect it

- The direction of the slice (2026-09-02): gnome, sprigs, the Hold, the soft night.

## Watch — mixed signal, needs another look

- (nothing yet)

## Free notes

- 2026-09-02, commissioning: "I want you to create a Pikmin game. But that, like, that's way
  cooler... open world, exploratory, collect things, gadgets, maybe more variety... uniquely cool
  to me based on what I like." Then: "desktop app for now... I liked all the mechanics normal
  Pikmin had, I just want to uncap the potential if that makes sense, and with my own flavor
  revitalized." Decisions taken in that session: Godot 4.7, vertical slice plus doctrine, the
  tiny-knight setting, soft day / dangerous night, Forward+ desktop first, mobile later, web not
  a goal. Working title Briarhold; the brand is his to rename.

## How to read silence

No verdict for 3 builds: stop shipping new systems, deepen. 7 builds: the era is probably dead.
He plays and says nothing: the last thing built is Watch, not Keep. Never nag for a verdict.
