# FOUNDATION — fixed, never reinvented

Everything here is settled. It is not a design choice and it is not yours to reconsider. It
outranks every other document except the kill list in `06_VERDICTS.md`. Your creative authority
lives above this layer; read "What is yours" before you conclude you have been fenced in.

## 0. The chassis

- **Godot 4.7, GDScript with static typing, Forward+ renderer, Windows desktop first.** Mobile
  later through Godot's Mobile renderer; web is not a goal. Materials stay StandardMaterial3D
  plus the one sprig shader so the renderer switch stays a setting.
- **The sim is pure.** `sim/` is RefCounted classes stepped once per physics tick by
  `game/main.gd`. No Node, no Input, no Time, no engine randomness in `sim/`. The view reads the
  sim and draws it; it never decides anything the sim could decide.
- **Seeded and deterministic.** FNV-1a → mulberry32 streams per subsystem (`sim/rng.gd`).
  World content is a function of the seed; the save stores deltas.
- **Content is data.** `content/*.json`. A new sprig type, enemy, hazard, relic, or gadget is a
  row, never a subclass.
- **The gate** is import → typecheck → tests → screenshots, run by `tools/gate.ps1`, scheduled by
  `build.ps1`. It never lowers.

## 0b. The shell

- A title screen: New Hold, Continue, Load, Settings, Quit. A version stamp on it.
- Save slots on disk, named, dated, with the day and the squad at a glance. Autosave at dawn and
  dusk. Never a single invisible save that silently overwrites.
- A pause menu on Escape that does not eject him: Resume, Save, Settings, the full control list,
  Quit to title.
- Settings that exist: fullscreen, reduced motion, UI scale. More as they are earned.
- Controls are shown, not guessed.
- **Full-screen windowed on launch.**

## 1. Camera and control

- Angled overhead, close, centred on him. Close enough to read his sword and the sprigs' leaves.
  Z and V turn in steps; the wheel zooms.
- **The cursor is his.** Visible, free, never captured, under any name.
- WASD moves him. Right-click on the ground walks him there. Left-click swings. Space throws at
  the cursor. R whistles at the cursor. X dismisses. C charges. Shift swarms. Q/E select type.
  F plucks, and at a shrine takes sprigs out; G at a shrine sends them in. These may gain
  alternates; they do not lose meaning.
- The world is continuous. He walks it. Terrain has real height and things to walk around.

## 2. The character is him

One persistent gnome (owner verdict 2026-09-02; the code still calls the record `knight`) with a name, a body, a sword, health, and eventually gear and skills. He
fights: real-time, positional, no twitch. Damage is visible and traceable. He can retreat. He
goes down and gets back up at the Hold; he never loses the Hold.

## 3. The squad

- Sprigs: plucked from shrines, typed, plentiful, expected losses. Every Pikmin verb: pluck,
  follow, throw, whistle, dismiss, swarm, charge, select, idle auto-task, carry, latch, dig,
  build. A field cap that rises with Heartroots and never hits a designed ceiling.
- Wardens (Arc 5): named sprigs that level and promote along class lines and never die for good.
  They wilt to seed and are replanted at the Hold's seedbed.
- No three-type field limit. Ever.

## 4. The loop

Leave the Hold, go out, find something that was not on a list, deal with what is there, come back
heavier. The Hold holds the bank, the shrines, the seedbed, and the workshop. Banked is safe;
field is at risk. Burrows re-roll. Every danger carries a reward.

## 5. The day

Soft day, dangerous night. Fifteen minutes of day, six of night. No forced extraction at dusk.
At dusk predators come in from the rim for whatever is left outside the Hold's safe ring. He can
fight, retreat, or keep working. The morning tally says what the night cost.

## 6. Stakes

He loses something when he loses, never everything. Field sprigs can die. Banked relics, the
Hold, the shrines, and Wardens cannot be lost. High-risk content (burrows, night expeditions)
is opt-in with the risk stated at the mouth.

## 7. Progression

The Hold total rises and never resets. Sprigs mature. Wardens promote. Gadgets accumulate. Skills
rise by use. Threat scales with the Hold's presence, never with a difficulty slider. No prestige,
no wipe, no ending.

---

## What is yours

The setting's detail, every creature, relic, hazard, gadget, burrow, and place; the type roster
beyond the eight; the Warden class lines; the workshop and its economy; trials and night
expeditions; the mount; weather; secrets; what the world does while he is away; the look within
the register (`docs/design/CODEX.md` §10). Be bold with all of it. He should not be able to
predict what he will find. He should always be able to predict that he is a knight, with a sword,
and a swarm at his heel.
