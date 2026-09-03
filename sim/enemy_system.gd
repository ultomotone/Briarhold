## Enemies: sleep, wake, chase, telegraph, bite, shake, and the night. Everything telegraphs;
## the bite lands on a timer he can see, never on a roll.
class_name EnemySystem
extends RefCounted


static func step(w: SimWorld, dt: float) -> void:
	for e: Entities.Enemy in w.enemies:
		if e.state == Entities.Enemy.State.DEAD:
			continue
		var t: Types.EnemyType = w.enemy_type(e)
		e.cooldown = maxf(0.0, e.cooldown - dt)
		e.itch_t += dt
		# shake off whoever is hanging on: enough damage AND enough time since the last shake,
		# so a burst cannot shake it early and a trickle cannot shake it forever
		if e.itch >= t.itch_damage and e.itch_t >= t.itch_time and e.state != Entities.Enemy.State.SHAKE:
			e.state = Entities.Enemy.State.SHAKE
			e.timer = t.shake_stun_seconds
			e.wind = 0.0
			_shake_off(w, e, t)
		match e.state:
			Entities.Enemy.State.SLEEP:
				_sleep(w, e, t)
			Entities.Enemy.State.IDLE, Entities.Enemy.State.CHASE:
				_hunt(w, e, t, dt)
			Entities.Enemy.State.TELEGRAPH:
				e.timer -= dt
				e.wind = 1.0 - clampf(e.timer / maxf(0.01, t.telegraph_seconds), 0.0, 1.0)
				if e.timer <= 0.0:
					_bite(w, e, t)
			Entities.Enemy.State.RECOVER:
				e.timer -= dt
				e.wind = maxf(0.0, e.timer / maxf(0.01, t.attack_cooldown)) * 0.3
				if e.timer <= 0.0:
					e.state = Entities.Enemy.State.IDLE
			Entities.Enemy.State.SHAKE:
				e.timer -= dt
				if e.timer <= 0.0:
					e.itch = 0.0
					e.itch_t = 0.0
					e.state = Entities.Enemy.State.IDLE
			Entities.Enemy.State.RETREAT:
				_retreat(w, e, t, dt)


static func _sleep(w: SimWorld, e: Entities.Enemy, t: Types.EnemyType) -> void:
	if SimWorld.flat_dist(w.knight.pos, e.pos) <= t.wake_radius and w.knight.down_t < 0.0:
		_wake(w, e)
		return
	for sid: int in w.hash.query(e.pos, t.wake_radius):
		var s: Entities.Sprig = w.sprig_by_id(sid)
		if s != null and s.state != Entities.Sprig.State.DEAD:
			_wake(w, e)
			return


static func _wake(w: SimWorld, e: Entities.Enemy) -> void:
	e.state = Entities.Enemy.State.IDLE
	w.events.push("enemy_woke", {"pos": e.pos, "type": e.type_id})


static func _pick_target(w: SimWorld, e: Entities.Enemy, t: Types.EnemyType) -> void:
	e.target_kind = ""
	e.target_id = -1
	e.target_pos = Vector3.INF
	var best_d: float = t.wake_radius * (1.6 if not e.night else 1.0)
	var k: Entities.Knight = w.knight
	if k.down_t < 0.0 and not (e.night and w.hold.in_safe(k.pos)):
		var dk: float = SimWorld.flat_dist(e.pos, k.pos)
		if dk < best_d:
			best_d = dk
			e.target_kind = "knight"
			e.target_pos = k.pos
	for sid: int in w.hash.query(e.pos, best_d):
		var s: Entities.Sprig = w.sprig_by_id(sid)
		if s == null or s.state == Entities.Sprig.State.DEAD or s.state == Entities.Sprig.State.THROWN:
			continue
		if s.latched and s.enemy_id == e.id:
			continue
		if e.night and w.hold.in_safe(s.pos):
			continue
		var d: float = SimWorld.flat_dist(e.pos, s.pos)
		if d < best_d:
			best_d = d
			e.target_kind = "sprig"
			e.target_id = s.id
			e.target_pos = s.pos


static func _hunt(w: SimWorld, e: Entities.Enemy, t: Types.EnemyType, dt: float) -> void:
	e.wind = 0.0
	if t.prey:
		_prey(w, e, t, dt)
		return
	_pick_target(w, e, t)
	if e.target_kind.is_empty():
		e.state = Entities.Enemy.State.IDLE
		if e.wander != Vector3.INF and e.wander == e.home and SimWorld.flat_dist(e.pos, e.home) > 1.2:
			# a visitor walking to its new bed
			e.yaw = SimWorld.yaw_toward(e.pos, e.home, e.yaw)
			e.pos = w.step_toward(e.pos, e.home, t.speed * 0.8, dt, t.radius)
			return
		if e.wander == e.home and t.sleeps_by_day and not w.clock.is_night():
			e.wander = Vector3.INF
			e.state = Entities.Enemy.State.SLEEP
			return
		if e.night:
			# prowl the edge of the safe ring, waiting for something to step out
			var ring: Vector3 = w.hold.pos + (e.pos - w.hold.pos).normalized() * (w.hold.safe_radius + 1.5)
			ring = w.ground(ring)
			if SimWorld.flat_dist(e.pos, ring) > 0.6:
				e.yaw = SimWorld.yaw_toward(e.pos, ring, e.yaw)
				e.pos = w.step_toward(e.pos, ring, t.speed * 0.5, dt, t.radius)
		elif t.roams:
			_roam(w, e, t, dt, 0.5)
		elif SimWorld.flat_dist(e.pos, e.home) > 0.8:
			e.yaw = SimWorld.yaw_toward(e.pos, e.home, e.yaw)
			e.pos = w.step_toward(e.pos, e.home, t.speed * 0.6, dt, t.radius)
		return
	e.state = Entities.Enemy.State.CHASE
	if not e.night and SimWorld.flat_dist(e.pos, e.home) > t.leash_radius:
		e.target_kind = ""
		e.state = Entities.Enemy.State.IDLE
		return
	var reach: float = t.bite_reach + t.radius
	if SimWorld.flat_dist(e.pos, e.target_pos) <= reach:
		if e.cooldown <= 0.0:
			e.state = Entities.Enemy.State.TELEGRAPH
			e.timer = t.telegraph_seconds
			e.yaw = SimWorld.yaw_toward(e.pos, e.target_pos, e.yaw)
			w.events.push("telegraph", {"pos": e.pos, "type": e.type_id, "seconds": t.telegraph_seconds})
		return
	e.yaw = SimWorld.yaw_toward(e.pos, e.target_pos, e.yaw)
	e.pos = w.step_toward(e.pos, e.target_pos, t.speed, dt, t.radius)


## Prey ambles around its home and bolts from the gnome or any sprig that comes close.
static func _prey(w: SimWorld, e: Entities.Enemy, t: Types.EnemyType, dt: float) -> void:
	e.state = Entities.Enemy.State.IDLE
	var threat: Vector3 = Vector3.INF
	var best: float = t.wake_radius
	var dk: float = SimWorld.flat_dist(e.pos, w.knight.pos)
	if w.knight.down_t < 0.0 and dk < best:
		best = dk
		threat = w.knight.pos
	for sid: int in w.hash.query(e.pos, t.wake_radius):
		var s: Entities.Sprig = w.sprig_by_id(sid)
		if s == null or s.state == Entities.Sprig.State.DEAD:
			continue
		if s.latched and s.enemy_id == e.id:
			continue
		var d: float = SimWorld.flat_dist(e.pos, s.pos)
		if d < best:
			best = d
			threat = s.pos
	if threat != Vector3.INF:
		var away: Vector3 = e.pos - threat
		away.y = 0.0
		if away.length() < 0.01:
			away = Vector3(sin(e.yaw), 0.0, cos(e.yaw))
		var to: Vector3 = e.pos + away.normalized() * 4.0
		# keep to its range: bolt along the leash edge rather than off the map
		if SimWorld.flat_dist(to, e.home) > t.leash_radius:
			to = e.home + (to - e.home).normalized() * t.leash_radius
		e.yaw = SimWorld.yaw_toward(e.pos, to, e.yaw)
		e.pos = w.step_toward(e.pos, to, t.speed, dt, t.radius)
		e.wander = Vector3.INF
		return
	_roam(w, e, t, dt, 0.45)


## An ambling walk between spots near home, each spot from the enemy's own stream.
static func _roam(w: SimWorld, e: Entities.Enemy, t: Types.EnemyType, dt: float, pace: float) -> void:
	e.wander_t -= dt
	if e.wander == Vector3.INF or e.wander_t <= 0.0 or SimWorld.flat_dist(e.pos, e.wander) < 0.6:
		var r := Rng.stream("%s:roam:%d:%d" % [w.seed_str(), e.id, w.tick])
		var ang: float = r.randf() * TAU
		var d: float = 2.0 + r.randf() * (t.leash_radius * 0.6)
		e.wander = w.field.clamp_bound(e.home + Vector3(sin(ang), 0.0, cos(ang)) * d)
		e.wander_t = 2.5 + r.randf() * 4.0
		if r.randf() < 0.35:
			return # it stands and looks about for a while
	if SimWorld.flat_dist(e.pos, e.wander) > 0.6:
		e.yaw = SimWorld.yaw_toward(e.pos, e.wander, e.yaw)
		e.pos = w.step_toward(e.pos, e.wander, t.speed * pace, dt, t.radius)


static func _bite(w: SimWorld, e: Entities.Enemy, t: Types.EnemyType) -> void:
	e.state = Entities.Enemy.State.RECOVER
	e.timer = t.attack_cooldown
	e.cooldown = t.attack_cooldown
	e.wind = 0.0
	var reach: float = t.bite_reach + t.radius
	var fwd := Vector3(sin(e.yaw), 0.0, cos(e.yaw))
	var mouth: Vector3 = e.pos + fwd * t.radius * 0.6
	# sprigs in front, nearest first; the bite takes up to bite_count of them
	var victims: Array[Entities.Sprig] = []
	for sid: int in w.hash.query(mouth, reach):
		var s: Entities.Sprig = w.sprig_by_id(sid)
		if s == null or s.state == Entities.Sprig.State.DEAD or s.state == Entities.Sprig.State.THROWN:
			continue
		if s.latched:
			continue
		var d: Vector3 = s.pos - e.pos
		d.y = 0.0
		if d.length() > 0.05 and fwd.dot(d.normalized()) < 0.1:
			continue
		victims.append(s)
	victims.sort_custom(func(a: Entities.Sprig, b: Entities.Sprig) -> bool:
		var da: float = SimWorld.flat_dist(a.pos, mouth)
		var db: float = SimWorld.flat_dist(b.pos, mouth)
		if absf(da - db) < 0.0001:
			return a.id < b.id
		return da < db)
	var eaten: int = 0
	for s: Entities.Sprig in victims:
		if eaten >= t.bite_count:
			break
		w.kill_sprig(s, "eaten by " + t.name)
		eaten += 1
	var k: Entities.Knight = w.knight
	if k.down_t < 0.0 and SimWorld.flat_dist(k.pos, e.pos) <= reach + 0.35:
		var dk: Vector3 = k.pos - e.pos
		dk.y = 0.0
		if dk.length() < 0.05 or fwd.dot(dk.normalized()) > 0.1:
			Damage.to_knight(w, t.damage_to_knight, t.name + " bite")
	w.events.push("bite", {"pos": mouth, "type": e.type_id, "eaten": eaten})


static func _shake_off(w: SimWorld, e: Entities.Enemy, t: Types.EnemyType) -> void:
	var n: int = 0
	for s: Entities.Sprig in w.sprigs:
		if s.enemy_id != e.id or not s.latched:
			continue
		var ang: float = float(s.anchor) / 12.0 * TAU
		w.set_state(s, Entities.Sprig.State.IDLE)
		s.pos = w.push_out(e.pos + Vector3(sin(ang), 0.0, cos(ang)) * (t.radius + 1.3), 0.2)
		s.stun = 0.9
		n += 1
	w.events.push("shake", {"pos": e.pos, "type": e.type_id, "count": n})


static func _retreat(w: SimWorld, e: Entities.Enemy, t: Types.EnemyType, dt: float) -> void:
	var away: Vector3 = e.pos - w.hold.pos
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3(1.0, 0.0, 0.0)
	var rim: Vector3 = w.hold.pos + away.normalized() * (w.field.bound - 1.0)
	e.yaw = SimWorld.yaw_toward(e.pos, rim, e.yaw)
	e.pos = w.step_toward(e.pos, rim, t.speed * 1.4, dt, t.radius)
	if SimWorld.flat_dist(e.pos, rim) < 1.5:
		e.state = Entities.Enemy.State.DEAD # gone with the dark; no corpse, no tally
		e.hp = 0.0


## Night falls: stalkers come in from the rim. Count rises with the Hold's presence, never a slider.
static func on_night(w: SimWorld) -> void:
	w.lost_tonight = 0
	var count: int = raid_size(w)
	var r := Rng.stream("%s:raid:day%d" % [w.seed_str(), w.clock.day])
	var base_ang: float = r.randf() * TAU
	for i: int in count:
		var ang: float = base_ang + float(i) * 0.35 + (r.randf() - 0.5) * 0.4
		var p: Vector3 = w.hold.pos + Vector3(sin(ang), 0.0, cos(ang)) * (w.field.bound - 3.0)
		var e: Entities.Enemy = w.spawn_enemy("night_stalker", p)
		e.state = Entities.Enemy.State.IDLE
	w.events.push("raid", {"count": count, "day": w.clock.day})


static func raid_size(w: SimWorld) -> int:
	return clampi(1 + w.clock.day / 2 + w.hold.total() / 400, 2, 9)


static func on_dawn(w: SimWorld) -> void:
	FieldSystem.arrivals(w, w.clock.day)
	var gone: int = 0
	for e: Entities.Enemy in w.enemies:
		if e.night and e.state != Entities.Enemy.State.DEAD:
			e.state = Entities.Enemy.State.RETREAT
			gone += 1
	w.last_night_report = {"day": w.clock.day - 1, "lost": w.lost_tonight, "stalkers": gone}
	w.events.push("morning", w.last_night_report.duplicate())
