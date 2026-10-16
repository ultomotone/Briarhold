## The one damage sink. Nothing rolls here: the caller supplies the amount and the cause, the sink
## applies it and reports it, so every number on screen traces to one line of code.
class_name Damage
extends RefCounted


## Damage from behind an enemy is scaled by its back_multiplier; from the front by its
## front_multiplier (armour); from the side, 1.0. Positional, never a roll.
static func facing_mult(e: Entities.Enemy, et: Types.EnemyType, from: Vector3) -> float:
	var fwd := Vector3(sin(e.yaw), 0.0, cos(e.yaw))
	var d: Vector3 = from - e.pos
	d.y = 0.0
	if d.length() < 0.01:
		return 1.0
	var dot: float = fwd.dot(d.normalized())
	if dot < -0.3:
		return et.back_multiplier
	if dot > 0.3:
		return et.front_multiplier
	return 1.0


## Underground, nothing reaches it.
static func untouchable(e: Entities.Enemy) -> bool:
	return e.state == Entities.Enemy.State.BURROW


static func to_enemy(w: SimWorld, e: Entities.Enemy, amount: float, cause: String, at: Vector3) -> float:
	if e.state == Entities.Enemy.State.DEAD or untouchable(e):
		return 0.0
	var dealt: float = minf(amount, e.hp)
	e.hp -= dealt
	e.itch += dealt
	w.events.push("damage", {"pos": at, "amount": dealt, "cause": cause, "target": "enemy", "id": e.id})
	if e.hp <= 0.0:
		e.hp = 0.0
		e.state = Entities.Enemy.State.DEAD
		w.on_enemy_felled(e, cause)
	return dealt


static func to_knight(w: SimWorld, amount: float, cause: String) -> float:
	var k: Entities.Knight = w.knight
	if k.down_t >= 0.0:
		return 0.0
	# a landed hit buys him a short window; steady hazard damage (small amounts) does not
	if amount >= 5.0:
		if k.invuln > 0.0:
			return 0.0
		k.invuln = w.content.wn("knight", "invuln_seconds", 0.9)
	var dealt: float = minf(amount, k.hp)
	k.hp -= dealt
	k.since_hit = 0.0
	w.events.push("damage", {"pos": k.pos, "amount": dealt, "cause": cause, "target": "knight", "id": 0})
	if k.hp <= 0.0:
		k.hp = 0.0
		w.on_knight_down(cause)
	return dealt


static func to_gate(w: SimWorld, g: Entities.Gate, amount: float, cause: String, at: Vector3) -> float:
	if g.open:
		return 0.0
	var dealt: float = minf(amount, g.hp)
	g.hp -= dealt
	w.events.push("damage", {"pos": at, "amount": dealt, "cause": cause, "target": "gate", "id": g.id})
	if g.hp <= 0.0:
		g.hp = 0.0
		g.open = true
		w.on_gate_opened(g)
	return dealt
