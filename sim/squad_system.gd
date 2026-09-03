## The squad: pluck, follow, select, throw, whistle, dismiss, swarm, charge, flight, landing,
## idle auto-tasking, attacking, and the leash. No two sprigs move alike: each has its own lag
## and phase from its own RNG stream, and separation is soft.
class_name SquadSystem
extends RefCounted

const SLAP_INTERVAL: float = 0.5


static func step(w: SimWorld, cmd: Commands, dt: float) -> void:
	var k: Entities.Knight = w.knight
	var c: ContentTables = w.content
	if k.down_t < 0.0:
		_select(w, cmd)
		_pluck(w, cmd, dt)
		_whistle(w, cmd, dt)
		if cmd.dismiss_pressed:
			_dismiss(w)
		if cmd.throw_pressed:
			_throw(w, cmd)
		if cmd.charge_pressed:
			_charge(w, cmd)
	_assign_slots(w)
	var trail: Vector3 = k.pos - Vector3(sin(k.yaw), 0.0, cos(k.yaw)) * 0.7
	var swarm_at: Vector3 = cmd.cursor if (cmd.swarm_held and cmd.has_cursor() and k.down_t < 0.0) else Vector3.INF
	for s: Entities.Sprig in w.sprigs:
		if s.state == Entities.Sprig.State.DEAD:
			continue
		if s.stun > 0.0:
			s.stun -= dt
			s.pos = w.push_out(s.pos, 0.2)
			continue
		match s.state:
			Entities.Sprig.State.FOLLOW:
				_follow(w, s, trail, swarm_at, dt)
			Entities.Sprig.State.THROWN:
				_fly(w, s, dt)
			Entities.Sprig.State.CHARGE:
				_run_charge(w, s, dt)
			Entities.Sprig.State.IDLE:
				_idle(w, s, dt)
			Entities.Sprig.State.ATTACK:
				_attack(w, s, dt)
			Entities.Sprig.State.CARRY:
				pass # CarrySystem moves carriers
	_separate(w)
	_leash(w, c.wn("squad", "leash_radius", 18.0))


# ---- commands ------------------------------------------------------------------------------

static func _select(w: SimWorld, cmd: Commands) -> void:
	var types: PackedStringArray = w.squad_types()
	if types.is_empty():
		return
	var cur: int = types.find(w.knight.selected_type)
	if cur < 0:
		w.knight.selected_type = types[0]
		return
	if cmd.select_delta != 0:
		cur = posmod(cur + cmd.select_delta, types.size())
		w.knight.selected_type = types[cur]


static func _pluck(w: SimWorld, cmd: Commands, dt: float) -> void:
	var k: Entities.Knight = w.knight
	if not cmd.pluck_held:
		k.pluck_t = 0.25
		return
	var r: float = w.content.wn("squad", "pluck_radius", 1.6)
	var seek: float = w.content.wn("squad", "pluck_seek_radius", 5.0)
	var best: Entities.Sprout = null
	var best_d: float = seek
	for sp: Entities.Sprout in w.sprouts:
		if sp.fl_t >= 0.0:
			continue
		var d: float = SimWorld.flat_dist(k.pos, sp.pos)
		if d < best_d:
			best_d = d
			best = sp
	if best == null:
		return
	if best_d > r:
		# holding the key walks him to the next sprout in the patch, unless he is steering
		if cmd.move_dir.length_squared() < 0.001:
			k.yaw = SimWorld.yaw_toward(k.pos, best.pos, k.yaw)
			k.pos = w.step_toward(k.pos, best.pos, w.content.wn("knight", "speed", 5.2) * 0.8, dt, 0.35)
		k.pluck_t = 0.25
		return
	k.pluck_t += dt
	if k.pluck_t < 0.25:
		return
	k.pluck_t = 0.0
	w.sprouts.erase(best)
	var s: Entities.Sprig = w.spawn_sprig(best.type_id, best.pos, Entities.Sprig.State.FOLLOW, best.maturity)
	s.stun = 0.15
	k.yaw = SimWorld.yaw_toward(k.pos, best.pos, k.yaw)
	w.events.push("pluck", {"pos": best.pos, "type": best.type_id})
	if w.squad_types().find(k.selected_type) < 0:
		k.selected_type = best.type_id


static func whistle_radius(w: SimWorld) -> float:
	var c: ContentTables = w.content
	var t: float = clampf(w.knight.whistle_t / maxf(0.01, c.wn("squad", "whistle_grow_seconds", 1.8)), 0.0, 1.0)
	return lerpf(c.wn("squad", "whistle_min_radius", 1.2), c.wn("squad", "whistle_max_radius", 6.0), t)


static func _whistle(w: SimWorld, cmd: Commands, dt: float) -> void:
	var k: Entities.Knight = w.knight
	if not cmd.whistle_held:
		k.whistle_t = 0.0
		return
	k.whistle_t += dt
	var centre: Vector3 = cmd.cursor if cmd.has_cursor() else k.pos
	var radius: float = whistle_radius(w)
	w.events.push("whistle", {"pos": centre, "radius": radius})
	var called: int = 0
	for s: Entities.Sprig in w.sprigs:
		if s.state == Entities.Sprig.State.DEAD or s.state == Entities.Sprig.State.THROWN:
			continue
		if SimWorld.flat_dist(s.pos, centre) > radius:
			continue
		if not s.status.is_empty():
			var hz: Types.HazardType = w.content.hazard(s.hazard_id)
			if hz != null and hz.whistle_cures:
				s.status = ""
				s.status_t = 0.0
				s.hazard_id = ""
		if s.state != Entities.Sprig.State.FOLLOW:
			w.set_state(s, Entities.Sprig.State.FOLLOW)
			s.stun = 0.0
			called += 1
	if called > 0 and w.squad_types().find(k.selected_type) < 0:
		k.selected_type = w.squad_types()[0]


static func _dismiss(w: SimWorld) -> void:
	var k: Entities.Knight = w.knight
	var types: PackedStringArray = w.squad_types()
	var n: int = 0
	for s: Entities.Sprig in w.sprigs:
		if s.state != Entities.Sprig.State.FOLLOW:
			continue
		var ti: int = types.find(s.type_id)
		var ang: float = k.yaw + PI + (float(ti) - float(types.size() - 1) * 0.5) * 0.9
		var r := Rng.stream("%s:dismiss:%d:%d" % [w.seed_str(), w.tick, s.id])
		var off := Vector3(sin(ang), 0.0, cos(ang)) * (2.2 + r.randf() * 1.2)
		off += Vector3(r.randf() - 0.5, 0.0, r.randf() - 0.5) * 1.4
		w.set_state(s, Entities.Sprig.State.IDLE)
		s.charge_target = w.ground(k.pos + off) # idle walks to its pile spot first
		n += 1
	if n > 0:
		w.events.push("dismiss", {"pos": k.pos, "count": n})


static func _throw(w: SimWorld, cmd: Commands) -> void:
	if not cmd.has_cursor():
		return
	var k: Entities.Knight = w.knight
	var best: Entities.Sprig = null
	var best_d: float = 1e9
	for s: Entities.Sprig in w.sprigs:
		if s.state != Entities.Sprig.State.FOLLOW or s.type_id != k.selected_type or s.stun > 0.0:
			continue
		var d: float = SimWorld.flat_dist(s.pos, k.pos)
		if d < best_d:
			best_d = d
			best = s
	if best == null:
		return
	var t: Types.SprigType = w.sprig_type(best)
	var target: Vector3 = Throw.clamp_target(k.pos, cmd.cursor, t.throw_range)
	target = w.ground(target)
	w.set_state(best, Entities.Sprig.State.THROWN)
	best.fl_start = k.pos + Vector3(0.0, 1.0, 0.0)
	best.fl_end = target
	best.fl_t = 0.0
	best.fl_total = w.content.wn("squad", "throw_flight_seconds", 0.62) * clampf(SimWorld.flat_dist(k.pos, target) / 5.0, 0.55, 1.15)
	best.pos = best.fl_start
	best.prev = best.pos
	k.yaw = SimWorld.yaw_toward(k.pos, target, k.yaw)
	w.events.push("throw", {"pos": k.pos, "type": best.type_id, "to": target})


static func _charge(w: SimWorld, cmd: Commands) -> void:
	if not cmd.has_cursor():
		return
	var n: int = 0
	for s: Entities.Sprig in w.sprigs:
		if s.state != Entities.Sprig.State.FOLLOW or s.type_id != w.knight.selected_type:
			continue
		w.set_state(s, Entities.Sprig.State.CHARGE)
		s.charge_target = w.ground(cmd.cursor)
		n += 1
	if n > 0:
		w.events.push("charge", {"pos": cmd.cursor, "count": n})


# ---- formation --------------------------------------------------------------------------------

static func _assign_slots(w: SimWorld) -> void:
	var i: int = 0
	for s: Entities.Sprig in w.sprigs:
		if s.state == Entities.Sprig.State.FOLLOW:
			s.slot = i
			i += 1


static func _slot_offset(w: SimWorld, slot: int, yaw: float) -> Vector3:
	var c: ContentTables = w.content
	var per: int = maxi(1, int(c.wn("squad", "follow_per_ring", 7.0)))
	var ring: int = slot / per
	var idx: int = slot % per
	var count: int = per + ring * 3
	idx = slot - _ring_start(per, ring)
	var r: float = c.wn("squad", "follow_ring_base", 1.1) + float(ring) * c.wn("squad", "follow_ring_step", 0.55)
	var ang: float = yaw + PI + (float(idx) + 0.5 * float(ring % 2)) / float(count) * TAU
	return Vector3(sin(ang), 0.0, cos(ang)) * r


static func _ring_start(per: int, ring: int) -> int:
	var n: int = 0
	for i: int in ring:
		n += per + i * 3
	return n


static func _follow(w: SimWorld, s: Entities.Sprig, trail: Vector3, swarm_at: Vector3, dt: float) -> void:
	var t: Types.SprigType = w.sprig_type(s)
	var k: Entities.Knight = w.knight
	var desired: Vector3
	var speed: float = t.speed * w.maturity_mult(s)
	if swarm_at != Vector3.INF:
		desired = swarm_at + _slot_offset(w, s.slot, k.yaw) * 0.45
		speed *= w.content.wn("squad", "swarm_speed_mult", 1.15)
	else:
		desired = trail + _slot_offset(w, s.slot, k.yaw)
	# per-sprig lag: the target it chases eases toward the slot, so laggards emerge on their own
	var a: float = clampf(dt / maxf(0.02, s.lag), 0.0, 1.0)
	s.smooth_target = s.smooth_target.lerp(desired, a)
	var d: float = SimWorld.flat_dist(s.pos, s.smooth_target)
	if d > 0.15:
		s.yaw = SimWorld.yaw_toward(s.pos, s.smooth_target, s.yaw)
		s.pos = w.step_toward(s.pos, s.smooth_target, speed * clampf(d / 0.6, 0.35, 1.0), dt, 0.2)
	else:
		s.pos = w.push_out(s.pos, 0.2)


# ---- flight and landing -------------------------------------------------------------------------

static func _fly(w: SimWorld, s: Entities.Sprig, dt: float) -> void:
	s.fl_t += dt
	var g: float = w.content.wn("squad", "throw_gravity", 22.0)
	if s.fl_t >= s.fl_total:
		s.pos = w.ground(s.fl_end)
		w.set_state(s, Entities.Sprig.State.IDLE)
		land(w, s)
		return
	s.pos = Throw.point_at(s.fl_start, s.fl_end, s.fl_total, g, s.fl_t)
	s.yaw = SimWorld.yaw_toward(s.fl_start, s.fl_end, s.yaw)


## What a sprig does where it lands: an enemy, a gate, a load, or nothing (idle, then scan).
static func land(w: SimWorld, s: Entities.Sprig) -> void:
	var t: Types.SprigType = w.sprig_type(s)
	for e: Entities.Enemy in w.enemies:
		if e.state == Entities.Enemy.State.DEAD:
			continue
		var et: Types.EnemyType = w.enemy_type(e)
		if SimWorld.flat_dist(s.pos, e.pos) <= et.radius + 0.45:
			if e.state == Entities.Enemy.State.SLEEP:
				e.state = Entities.Enemy.State.IDLE
				w.events.push("enemy_woke", {"pos": e.pos, "type": e.type_id})
			if t.attack == "impact":
				Damage.to_enemy(w, e, t.damage, t.name + " impact", e.pos + Vector3(0.0, et.height, 0.0))
				var away: Vector3 = s.pos - e.pos
				away.y = 0.0
				if away.length() < 0.01:
					away = Vector3(1.0, 0.0, 0.0)
				s.pos = w.push_out(e.pos + away.normalized() * (et.radius + 0.7), 0.2)
				s.stun = 0.5
				w.set_state(s, Entities.Sprig.State.IDLE)
			else:
				w.set_state(s, Entities.Sprig.State.ATTACK)
				s.enemy_id = e.id
				s.latched = true
				s.anchor = s.id % 12
				s.slap_t = 0.0
			return
	for g: Entities.Gate in w.gates:
		if g.open:
			continue
		if SimWorld.flat_dist(s.pos, g.pos) <= g.width * 0.5 + 0.6:
			w.set_state(s, Entities.Sprig.State.ATTACK)
			s.gate_id = g.id
			s.slap_t = 0.0
			return
	var o: Entities.WorldObject = _load_near(w, s.pos, 0.9)
	if o != null:
		CarrySystem.join(w, s, o)
		return
	w.set_state(s, Entities.Sprig.State.IDLE)


static func _load_near(w: SimWorld, p: Vector3, extra: float) -> Entities.WorldObject:
	var best: Entities.WorldObject = null
	var best_d: float = 1e9
	for o: Entities.WorldObject in w.objects:
		if o.taken or o.carriers.size() >= o.max_carriers:
			continue
		var d: float = SimWorld.flat_dist(p, o.pos) - o.radius
		if d <= extra and d < best_d:
			best_d = d
			best = o
	return best


static func _run_charge(w: SimWorld, s: Entities.Sprig, dt: float) -> void:
	var t: Types.SprigType = w.sprig_type(s)
	if s.charge_target == Vector3.INF:
		w.set_state(s, Entities.Sprig.State.IDLE)
		return
	var speed: float = t.speed * w.maturity_mult(s) * w.content.wn("squad", "charge_speed_mult", 1.6)
	s.yaw = SimWorld.yaw_toward(s.pos, s.charge_target, s.yaw)
	s.pos = w.step_toward(s.pos, s.charge_target, speed, dt, 0.2)
	if SimWorld.flat_dist(s.pos, s.charge_target) < 0.5:
		var at: Vector3 = s.charge_target
		w.set_state(s, Entities.Sprig.State.IDLE)
		s.pos = w.ground(at)
		land(w, s)


# ---- idle and work --------------------------------------------------------------------------

static func _idle(w: SimWorld, s: Entities.Sprig, dt: float) -> void:
	var t: Types.SprigType = w.sprig_type(s)
	# a dismissed sprig first walks to its pile spot
	if s.charge_target != Vector3.INF:
		if SimWorld.flat_dist(s.pos, s.charge_target) > 0.3:
			s.yaw = SimWorld.yaw_toward(s.pos, s.charge_target, s.yaw)
			s.pos = w.step_toward(s.pos, s.charge_target, t.speed * 0.8, dt, 0.2)
			return
		s.charge_target = Vector3.INF
	s.idle_scan += 1
	if (s.idle_scan + s.id) % 10 != 0:
		s.pos = w.push_out(s.pos, 0.2)
		return
	var r: float = w.content.wn("squad", "idle_task_radius", 3.0)
	# 1. something to fight
	var best_e: Entities.Enemy = null
	var best_d: float = r
	for e: Entities.Enemy in w.enemies:
		if e.state == Entities.Enemy.State.DEAD or e.state == Entities.Enemy.State.SLEEP or e.state == Entities.Enemy.State.RETREAT:
			continue
		var d: float = SimWorld.flat_dist(s.pos, e.pos) - w.enemy_type(e).radius
		if d < best_d:
			best_d = d
			best_e = e
	if best_e != null:
		w.set_state(s, Entities.Sprig.State.ATTACK)
		s.enemy_id = best_e.id
		s.latched = false
		s.anchor = s.id % 12
		return
	# 2. something to carry
	var o: Entities.WorldObject = _load_near(w, s.pos, r)
	if o != null:
		CarrySystem.join(w, s, o)
		return
	# 3. something to break
	for g: Entities.Gate in w.gates:
		if g.open:
			continue
		if SimWorld.flat_dist(s.pos, g.pos) <= g.width * 0.5 + r:
			w.set_state(s, Entities.Sprig.State.ATTACK)
			s.gate_id = g.id
			return


static func _attack(w: SimWorld, s: Entities.Sprig, dt: float) -> void:
	var t: Types.SprigType = w.sprig_type(s)
	if s.enemy_id >= 0:
		var e: Entities.Enemy = w.enemy_by_id(s.enemy_id)
		if e == null or e.state == Entities.Enemy.State.DEAD:
			w.set_state(s, Entities.Sprig.State.IDLE)
			return
		var et: Types.EnemyType = w.enemy_type(e)
		if not s.latched:
			s.yaw = SimWorld.yaw_toward(s.pos, e.pos, s.yaw)
			s.pos = w.step_toward(s.pos, e.pos, t.speed * w.maturity_mult(s), dt, 0.2)
			if SimWorld.flat_dist(s.pos, e.pos) <= et.radius + 0.35:
				if t.attack == "impact":
					# impact types cannot hang on: they butt, bounce, and come back
					Damage.to_enemy(w, e, t.damage * 0.5, t.name + " butt", e.pos + Vector3(0.0, et.height * 0.6, 0.0))
					var away: Vector3 = (s.pos - e.pos)
					away.y = 0.0
					s.pos = w.push_out(e.pos + away.normalized() * (et.radius + 0.9), 0.2)
					s.stun = 0.7
				else:
					s.latched = true
					s.slap_t = 0.0
			return
		# latched: ride the body, slap on the interval
		var ang: float = float(s.anchor) / 12.0 * TAU
		s.pos = e.pos + Vector3(sin(ang), 0.0, cos(ang)) * et.radius * 0.8
		s.pos.y = e.pos.y + et.height * 0.6
		s.yaw = ang + PI
		s.slap_t += dt
		if s.slap_t >= SLAP_INTERVAL:
			s.slap_t -= SLAP_INTERVAL
			Damage.to_enemy(w, e, t.damage, t.name + " sprig", e.pos + Vector3(0.0, et.height, 0.0))
		return
	if s.gate_id >= 0:
		var g: Entities.Gate = w.gate_by_id(s.gate_id)
		if g == null or g.open:
			w.set_state(s, Entities.Sprig.State.IDLE)
			return
		var axis := Vector3(cos(g.yaw), 0.0, -sin(g.yaw))
		var rel: Vector3 = s.pos - g.pos
		var along: float = clampf(rel.dot(axis), -g.width * 0.45, g.width * 0.45)
		var spot: Vector3 = g.pos + axis * along
		if SimWorld.flat_dist(s.pos, spot) > 0.95:
			s.yaw = SimWorld.yaw_toward(s.pos, spot, s.yaw)
			s.pos = w.step_toward(s.pos, spot, t.speed * w.maturity_mult(s), dt, 0.2)
			return
		s.yaw = SimWorld.yaw_toward(s.pos, g.pos, s.yaw)
		s.slap_t += dt
		if s.slap_t >= SLAP_INTERVAL:
			s.slap_t -= SLAP_INTERVAL
			var mult: float = 2.0 if s.type_id == "thorn" else 1.0
			Damage.to_gate(w, g, t.damage * mult, t.name + " sprig", spot + Vector3(0.0, 1.0, 0.0))
		return
	w.set_state(s, Entities.Sprig.State.IDLE)


# ---- crowd -----------------------------------------------------------------------------------

static func _separate(w: SimWorld) -> void:
	var r: float = w.content.wn("squad", "separation_radius", 0.42)
	for s: Entities.Sprig in w.sprigs:
		if s.state == Entities.Sprig.State.THROWN or s.latched or s.state == Entities.Sprig.State.DEAD or s.state == Entities.Sprig.State.CARRY:
			continue
		var push := Vector3.ZERO
		for oid: int in w.hash.query(s.pos, r):
			if oid == s.id:
				continue
			var q: Vector3 = w.hash.position_of(oid)
			var d: Vector3 = s.pos - q
			d.y = 0.0
			var len: float = d.length()
			if len < 0.001:
				d = Vector3(sin(float(s.id)), 0.0, cos(float(s.id)))
				len = 1.0
			push += d * ((r - len) / len) * 0.5
		if push.length_squared() > 0.0:
			s.pos = w.ground(w.field.clamp_bound(s.pos + push))


static func _leash(w: SimWorld, leash: float) -> void:
	var k: Entities.Knight = w.knight
	for s: Entities.Sprig in w.sprigs:
		if s.state == Entities.Sprig.State.FOLLOW and SimWorld.flat_dist(s.pos, k.pos) > leash:
			w.set_state(s, Entities.Sprig.State.IDLE)
			w.events.push("lost_follow", {"pos": s.pos, "type": s.type_id})
