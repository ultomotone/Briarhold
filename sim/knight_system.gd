## The knight: movement, the sword, regen, and going down. He fights free of the squad.
class_name KnightSystem
extends RefCounted


static func step(w: SimWorld, cmd: Commands, dt: float) -> void:
	var k: Entities.Knight = w.knight
	var c: ContentTables = w.content
	if k.down_t >= 0.0:
		k.down_t += dt
		if k.down_t >= 2.2:
			k.down_t = -1.0
			k.hp = k.max_hp
			k.pos = w.ground(w.hold.pos + Vector3(0.0, 0.0, 2.5))
			k.prev = k.pos
			k.walk_target = Vector3.INF
			w.events.push("knight_up", {"pos": k.pos})
		return

	var speed: float = c.wn("knight", "speed", 5.2)
	if cmd.walk_target != Vector3.INF:
		k.walk_target = cmd.walk_target
	if cmd.move_dir.length_squared() > 0.001:
		k.walk_target = Vector3.INF
		var d: Vector3 = cmd.move_dir.normalized()
		k.pos = w.step_toward(k.pos, k.pos + d * 10.0, speed, dt, 0.35)
		k.yaw = SimWorld.yaw_toward(Vector3.ZERO, d, k.yaw)
	elif k.walk_target != Vector3.INF:
		if SimWorld.flat_dist(k.pos, k.walk_target) < 0.3:
			k.walk_target = Vector3.INF
		else:
			k.yaw = SimWorld.yaw_toward(k.pos, k.walk_target, k.yaw)
			k.pos = w.step_toward(k.pos, k.walk_target, speed, dt, 0.35)
	else:
		k.pos = w.push_out(k.pos, 0.35)

	# the sword: a committed swing, contact fires once at contact_at
	if cmd.strike and k.swing_t < 0.0:
		k.swing_t = 0.0
		k.swing_hit = false
		if cmd.has_cursor():
			k.yaw = SimWorld.yaw_toward(k.pos, cmd.cursor, k.yaw)
	if k.swing_t >= 0.0:
		k.swing_t += dt
		if not k.swing_hit and k.swing_t >= c.wn("knight", "contact_at", 0.17):
			k.swing_hit = true
			_contact(w)
		if k.swing_t >= c.wn("knight", "swing_seconds", 0.44):
			k.swing_t = -1.0

	k.since_hit += dt
	k.invuln = maxf(0.0, k.invuln - dt)
	if k.since_hit > c.wn("knight", "regen_after", 5.0) and k.hp < k.max_hp:
		k.hp = minf(k.max_hp, k.hp + c.wn("knight", "regen_per_sec", 3.4) * dt)


static func _contact(w: SimWorld) -> void:
	var k: Entities.Knight = w.knight
	var c: ContentTables = w.content
	var reach: float = c.wn("knight", "reach", 1.35)
	var arc: float = c.wn("knight", "arc_rad", 0.9)
	var dmg: float = c.wn("knight", "sword_damage", 12.0)
	var fwd := Vector3(sin(k.yaw), 0.0, cos(k.yaw))
	for e: Entities.Enemy in w.enemies:
		if e.state == Entities.Enemy.State.DEAD:
			continue
		var et: Types.EnemyType = w.enemy_type(e)
		var d: Vector3 = e.pos - k.pos
		d.y = 0.0
		var dist: float = d.length()
		if dist > reach + et.radius:
			continue
		if dist > 0.001 and fwd.angle_to(d) > arc:
			continue
		# positional, never a roll: behind it is a backstrike
		var efwd := Vector3(sin(e.yaw), 0.0, cos(e.yaw))
		var behind: bool = dist > 0.001 and efwd.dot(-d.normalized()) < -0.3
		var amount: float = dmg * (c.wn("knight", "backstrike_mult", 1.55) if behind else 1.0)
		Damage.to_enemy(w, e, amount, "Backstrike" if behind else "Sword", e.pos + Vector3(0.0, et.height, 0.0))
		if e.state == Entities.Enemy.State.SLEEP:
			e.state = Entities.Enemy.State.IDLE
			w.events.push("enemy_woke", {"pos": e.pos, "type": e.type_id})
	for g: Entities.Gate in w.gates:
		if g.open:
			continue
		if SimWorld.flat_dist(k.pos, g.pos) <= reach + g.width * 0.5:
			Damage.to_gate(w, g, dmg, "Sword", g.pos + Vector3(0.0, 1.2, 0.0))
