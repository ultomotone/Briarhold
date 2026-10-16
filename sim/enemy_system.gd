## Enemies: sleep, wake, chase, telegraph, strike, shake, and the night. Everything telegraphs;
## every strike lands on a timer he can see, never on a roll. What the strike is comes from the
## type's attack: bite, breath, gust, leap, charge, or burrow (enemies.json _doc).
class_name EnemySystem
extends RefCounted


static func step(w: SimWorld, dt: float) -> void:
	for e: Entities.Enemy in w.enemies:
		if e.state == Entities.Enemy.State.DEAD:
			continue
		var t: Types.EnemyType = w.enemy_type(e)
		e.strike_t += dt
		if e.state == Entities.Enemy.State.FROZEN:
			# frozen solid: no moving, no biting, no shaking; sprigs on it keep hitting
			e.timer -= dt
			e.wind = 0.0
			if e.timer <= 0.0:
				e.state = Entities.Enemy.State.IDLE
				e.freeze = 0.0
				w.events.push("thawed", {"pos": e.pos, "type": e.type_id})
			continue
		e.freeze = maxf(0.0, e.freeze - w.content.wn("frost", "decay_per_sec", 0.05) * dt)
		e.cooldown = maxf(0.0, e.cooldown - dt)
		e.itch_t += dt
		if t.attack == "burrow" and e.state != Entities.Enemy.State.BURROW:
			e.surface_t -= dt
			if e.surface_t <= 0.0 and (e.state == Entities.Enemy.State.IDLE or e.state == Entities.Enemy.State.CHASE):
				_go_under(w, e, t)
				continue
		# shake off whoever is hanging on: enough damage AND enough time since the last shake,
		# so a burst cannot shake it early and a trickle cannot shake it forever. Not mid-air,
		# not mid-rush, not underground.
		var busy: bool = e.state == Entities.Enemy.State.SHAKE or e.state == Entities.Enemy.State.LEAP or e.state == Entities.Enemy.State.RUSH or e.state == Entities.Enemy.State.BURROW
		if not busy and e.itch >= t.itch_damage and e.itch_t >= t.itch_time:
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
					_strike(w, e, t)
			Entities.Enemy.State.RECOVER:
				e.timer -= dt
				e.wind = maxf(0.0, e.timer / maxf(0.01, t.attack_cooldown)) * 0.3
				if e.timer <= 0.0:
					e.state = Entities.Enemy.State.IDLE
					e.dazed = false
			Entities.Enemy.State.SHAKE:
				e.timer -= dt
				if e.timer <= 0.0:
					e.itch = 0.0
					e.itch_t = 0.0
					e.state = Entities.Enemy.State.IDLE
			Entities.Enemy.State.RETREAT:
				_retreat(w, e, t, dt)
			Entities.Enemy.State.LEAP:
				_leap_step(w, e, t, dt)
			Entities.Enemy.State.RUSH:
				_rush_step(w, e, t, dt)
			Entities.Enemy.State.BURROW:
				_burrow_step(w, e, t, dt)


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
	var reach: float = t.attack_range
	if t.attack == "burrow":
		reach = t.bite_reach + t.radius # above ground it bites like anything else
	if SimWorld.flat_dist(e.pos, e.target_pos) <= reach:
		if e.cooldown <= 0.0:
			_wind_up(w, e, t)
		elif t.attack == "bite" or t.attack == "burrow":
			return
		else:
			e.yaw = SimWorld.yaw_toward(e.pos, e.target_pos, e.yaw)
		return
	e.yaw = SimWorld.yaw_toward(e.pos, e.target_pos, e.yaw)
	e.pos = w.step_toward(e.pos, e.target_pos, t.speed, dt, t.radius)


## The visible wind-up. Where the strike will land is fixed now, so he can step out of it.
static func _wind_up(w: SimWorld, e: Entities.Enemy, t: Types.EnemyType) -> void:
	e.state = Entities.Enemy.State.TELEGRAPH
	e.timer = t.telegraph_seconds
	e.yaw = SimWorld.yaw_toward(e.pos, e.target_pos, e.yaw)
	e.aim = e.target_pos
	if t.attack == "leap" and SimWorld.flat_dist(e.pos, e.aim) > t.attack_range:
		e.aim = e.pos + (e.aim - e.pos).normalized() * t.attack_range
	e.aim = w.ground(w.field.clamp_bound(e.aim))
	w.events.push("telegraph", {"pos": e.pos, "type": e.type_id, "seconds": t.telegraph_seconds, "attack": t.attack, "aim": e.aim})


static func _strike(w: SimWorld, e: Entities.Enemy, t: Types.EnemyType) -> void:
	e.strike_t = 0.0
	match t.attack:
		"breath":
			_breath(w, e, t)
		"gust":
			_gust(w, e, t)
		"leap":
			_begin_leap(w, e, t)
		"charge":
			_begin_rush(w, e, t)
		"none":
			_recover(e, t, t.attack_cooldown)
		_:
			_bite(w, e, t)


static func _recover(e: Entities.Enemy, t: Types.EnemyType, seconds: float) -> void:
	e.state = Entities.Enemy.State.RECOVER
	e.timer = seconds
	e.cooldown = maxf(seconds, t.attack_cooldown)
	e.wind = 0.0


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


# ---- strikes ---------------------------------------------------------------------------------

static func _bite(w: SimWorld, e: Entities.Enemy, t: Types.EnemyType) -> void:
	_recover(e, t, t.attack_cooldown)
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
	var eaten: int = _eat(w, e, t, victims, mouth)
	var k: Entities.Knight = w.knight
	if k.down_t < 0.0 and SimWorld.flat_dist(k.pos, e.pos) <= reach + 0.35:
		var dk: Vector3 = k.pos - e.pos
		dk.y = 0.0
		if dk.length() < 0.05 or fwd.dot(dk.normalized()) > 0.1:
			Damage.to_knight(w, t.damage_to_knight, t.name + " bite")
	w.events.push("bite", {"pos": mouth, "type": e.type_id, "eaten": eaten})


## Eat up to bite_count of these, nearest to `at` first (ties by id). A Thorn sprig poisons
## whatever eats it: the price of the meal, on the meal's own clock.
static func _eat(w: SimWorld, e: Entities.Enemy, t: Types.EnemyType, victims: Array[Entities.Sprig], at: Vector3) -> int:
	victims.sort_custom(func(a: Entities.Sprig, b: Entities.Sprig) -> bool:
		var da: float = SimWorld.flat_dist(a.pos, at)
		var db: float = SimWorld.flat_dist(b.pos, at)
		if absf(da - db) < 0.0001:
			return a.id < b.id
		return da < db)
	var eaten: int = 0
	var poisoned: int = 0
	for s: Entities.Sprig in victims:
		if eaten >= t.bite_count:
			break
		if s.type_id == "thorn":
			poisoned += 1
		w.kill_sprig(s, "eaten by " + t.name)
		eaten += 1
	for i: int in poisoned:
		Damage.to_enemy(w, e, w.content.wn("thorn", "poison_damage", 150.0), "Thorn poison", e.pos + Vector3(0.0, t.height, 0.0))
	return eaten


## True when p is inside the cone in front of e, out to range.
static func _in_cone(e: Entities.Enemy, t: Types.EnemyType, p: Vector3, reach: float) -> bool:
	var d: Vector3 = p - e.pos
	d.y = 0.0
	var len: float = d.length()
	if len > reach:
		return false
	if len < t.radius:
		return true
	var fwd := Vector3(sin(e.yaw), 0.0, cos(e.yaw))
	return fwd.dot(d / len) >= cos(deg_to_rad(t.cone_deg * 0.5))


## A cone of its hazard: every sprig in it that is not immune takes the status (and a fire or
## poison status sends it running); the gnome takes a knock.
static func _breath(w: SimWorld, e: Entities.Enemy, t: Types.EnemyType) -> void:
	_recover(e, t, t.attack_cooldown)
	var reach: float = t.attack_range + 0.4
	var hit: int = 0
	for sid: int in w.hash.query(e.pos, reach):
		var s: Entities.Sprig = w.sprig_by_id(sid)
		if s == null or s.state == Entities.Sprig.State.DEAD or s.state == Entities.Sprig.State.THROWN or s.latched:
			continue
		if not _in_cone(e, t, s.pos, reach):
			continue
		if HazardSystem.afflict(w, s, t.breath_hazard, e.pos, reach + 2.5):
			hit += 1
	var k: Entities.Knight = w.knight
	if k.down_t < 0.0 and _in_cone(e, t, k.pos, reach) and t.damage_to_knight > 0.0:
		Damage.to_knight(w, t.damage_to_knight, t.name + " breath")
	w.events.push("breath", {"pos": e.pos, "yaw": e.yaw, "range": reach, "hazard": t.breath_hazard, "type": e.type_id, "hit": hit})


## A cone of wind: sprigs in it are blown back gust_push metres and dazed, dropping what they
## held. Anything immune to gust (the Oaks, by weight) stands firm. The gnome is pushed back.
static func _gust(w: SimWorld, e: Entities.Enemy, t: Types.EnemyType) -> void:
	_recover(e, t, t.attack_cooldown)
	var reach: float = t.attack_range + 0.4
	var blown: int = 0
	for sid: int in w.hash.query(e.pos, reach):
		var s: Entities.Sprig = w.sprig_by_id(sid)
		if s == null or s.state == Entities.Sprig.State.DEAD or s.state == Entities.Sprig.State.THROWN or s.latched:
			continue
		if not _in_cone(e, t, s.pos, reach):
			continue
		if w.sprig_type(s).immune.has("gust"):
			continue
		var away: Vector3 = _away(e, s.pos, s.id)
		w.set_state(s, Entities.Sprig.State.IDLE)
		s.pos = w.push_out(s.pos + away * t.gust_push, 0.2)
		s.stun = 1.2
		blown += 1
	var k: Entities.Knight = w.knight
	if k.down_t < 0.0 and _in_cone(e, t, k.pos, reach):
		k.pos = w.push_out(k.pos + _away(e, k.pos, 0) * t.gust_push * 0.5, 0.3)
		k.walk_target = Vector3.INF
	w.events.push("gust", {"pos": e.pos, "yaw": e.yaw, "range": reach, "type": e.type_id, "blown": blown})


static func _away(e: Entities.Enemy, p: Vector3, salt: int) -> Vector3:
	var d: Vector3 = p - e.pos
	d.y = 0.0
	if d.length() < 0.01:
		d = Vector3(sin(e.yaw + float(salt)), 0.0, cos(e.yaw + float(salt)))
	return d.normalized()


# ---- leap ------------------------------------------------------------------------------------

static func _begin_leap(w: SimWorld, e: Entities.Enemy, _t: Types.EnemyType) -> void:
	e.state = Entities.Enemy.State.LEAP
	e.leap_from = e.pos
	e.leap_t = 0.0
	e.wind = 0.0
	w.events.push("leap", {"pos": e.pos, "to": e.aim, "type": e.type_id})


static func _leap_step(w: SimWorld, e: Entities.Enemy, t: Types.EnemyType, dt: float) -> void:
	e.leap_t += dt
	var u: float = clampf(e.leap_t / maxf(0.05, t.leap_seconds), 0.0, 1.0)
	var p: Vector3 = w.ground(e.leap_from.lerp(e.aim, u))
	p.y += 4.0 * u * (1.0 - u) * 2.4
	e.pos = p
	e.yaw = SimWorld.yaw_toward(e.leap_from, e.aim, e.yaw)
	if u < 1.0:
		return
	e.leap_t = -1.0
	e.pos = w.push_out(e.aim, t.radius)
	_slam(w, e, t)
	_recover(e, t, t.attack_cooldown)


## Landing: everything under it that is not immune to crush is flattened.
static func _slam(w: SimWorld, e: Entities.Enemy, t: Types.EnemyType) -> void:
	var n: int = 0
	for sid: int in w.hash.query(e.pos, t.leap_radius):
		var s: Entities.Sprig = w.sprig_by_id(sid)
		if s == null or s.state == Entities.Sprig.State.DEAD or s.state == Entities.Sprig.State.THROWN or s.latched:
			continue
		if w.sprig_type(s).immune.has("crush"):
			continue
		if SimWorld.flat_dist(s.pos, e.pos) <= t.leap_radius:
			w.kill_sprig(s, "squashed by " + t.name)
			n += 1
	var k: Entities.Knight = w.knight
	if k.down_t < 0.0 and SimWorld.flat_dist(k.pos, e.pos) <= t.leap_radius + 0.3:
		Damage.to_knight(w, t.damage_to_knight, t.name + " landing")
	w.events.push("slam", {"pos": e.pos, "radius": t.leap_radius, "type": e.type_id, "crushed": n})


# ---- charge ----------------------------------------------------------------------------------

static func _begin_rush(w: SimWorld, e: Entities.Enemy, t: Types.EnemyType) -> void:
	var d: Vector3 = e.aim - e.pos
	d.y = 0.0
	if d.length() < 0.05:
		d = Vector3(sin(e.yaw), 0.0, cos(e.yaw))
	e.rush_dir = d.normalized()
	e.yaw = atan2(e.rush_dir.x, e.rush_dir.z)
	e.rush_left = t.charge_distance
	e.state = Entities.Enemy.State.RUSH
	e.wind = 0.0
	w.events.push("rush", {"pos": e.pos, "type": e.type_id})


static func _rush_step(w: SimWorld, e: Entities.Enemy, t: Types.EnemyType, dt: float) -> void:
	var want: float = minf(e.rush_left, t.charge_speed * dt)
	var to: Vector3 = w.push_out(e.pos + e.rush_dir * want, t.radius)
	var moved: float = SimWorld.flat_dist(to, e.pos)
	e.pos = to
	e.rush_left -= want
	# trample what is in the way
	for sid: int in w.hash.query(e.pos, t.radius + 0.3):
		var s: Entities.Sprig = w.sprig_by_id(sid)
		if s == null or s.state == Entities.Sprig.State.DEAD or s.state == Entities.Sprig.State.THROWN or s.latched:
			continue
		if w.sprig_type(s).immune.has("crush"):
			s.pos = w.push_out(s.pos + _away(e, s.pos, s.id) * 0.4, 0.2)
			continue
		w.kill_sprig(s, "trampled by " + t.name)
	var k: Entities.Knight = w.knight
	if k.down_t < 0.0 and SimWorld.flat_dist(k.pos, e.pos) <= t.radius + 0.4:
		Damage.to_knight(w, t.damage_to_knight, t.name + " charge")
		var side := Vector3(e.rush_dir.z, 0.0, -e.rush_dir.x)
		if side.dot(k.pos - e.pos) < 0.0:
			side = -side
		k.pos = w.push_out(k.pos + side * 1.4, 0.3)
	var bonked: bool = moved < want * 0.5
	if e.rush_left <= 0.0 or bonked:
		_recover(e, t, t.daze_seconds)
		e.cooldown = t.daze_seconds + t.attack_cooldown
		e.dazed = true
		w.events.push("dazed", {"pos": e.pos, "type": e.type_id, "bonk": bonked})


# ---- burrow ----------------------------------------------------------------------------------

static func _go_under(w: SimWorld, e: Entities.Enemy, t: Types.EnemyType) -> void:
	if e.itch > 0.0:
		_shake_off(w, e, t)
	for s: Entities.Sprig in w.sprigs:
		if s.enemy_id == e.id:
			w.set_state(s, Entities.Sprig.State.IDLE)
	e.state = Entities.Enemy.State.BURROW
	e.emerge = -1.0
	e.wind = 0.0
	e.itch = 0.0
	w.events.push("burrow", {"pos": e.pos, "type": e.type_id})


static func _burrow_step(w: SimWorld, e: Entities.Enemy, t: Types.EnemyType, dt: float) -> void:
	if e.emerge >= 0.0:
		e.emerge -= dt
		e.wind = 1.0 - clampf(e.emerge / maxf(0.01, t.telegraph_seconds), 0.0, 1.0)
		if e.emerge <= 0.0:
			_erupt(w, e, t)
		return
	e.wind = 0.0
	_pick_target(w, e, t)
	if e.target_kind.is_empty() or SimWorld.flat_dist(e.target_pos, e.home) > t.leash_radius:
		if SimWorld.flat_dist(e.pos, e.home) > 1.0:
			e.yaw = SimWorld.yaw_toward(e.pos, e.home, e.yaw)
			e.pos = w.step_toward(e.pos, e.home, t.speed * 0.5, dt, 0.3)
		return
	e.yaw = SimWorld.yaw_toward(e.pos, e.target_pos, e.yaw)
	e.pos = w.step_toward(e.pos, e.target_pos, t.speed, dt, 0.3)
	if SimWorld.flat_dist(e.pos, e.target_pos) < 0.7:
		# the mound stops and shakes: the warning
		e.emerge = t.telegraph_seconds
		e.aim = e.pos
		w.events.push("telegraph", {"pos": e.pos, "type": e.type_id, "seconds": t.telegraph_seconds, "attack": "burrow", "aim": e.pos})


## Up through the ground: the nearest few are eaten, the rest thrown clear.
static func _erupt(w: SimWorld, e: Entities.Enemy, t: Types.EnemyType) -> void:
	e.emerge = -1.0
	e.strike_t = 0.0
	e.pos = w.push_out(e.pos, t.radius)
	var near: Array[Entities.Sprig] = []
	for sid: int in w.hash.query(e.pos, t.radius + 1.8):
		var s: Entities.Sprig = w.sprig_by_id(sid)
		if s == null or s.state == Entities.Sprig.State.DEAD or s.state == Entities.Sprig.State.THROWN or s.latched:
			continue
		near.append(s)
	var mouth: Array[Entities.Sprig] = []
	for s: Entities.Sprig in near:
		if SimWorld.flat_dist(s.pos, e.pos) <= t.radius + 0.5:
			mouth.append(s)
	var eaten: int = _eat(w, e, t, mouth, e.pos)
	for s: Entities.Sprig in near:
		if s.state == Entities.Sprig.State.DEAD:
			continue
		w.set_state(s, Entities.Sprig.State.IDLE)
		s.pos = w.push_out(s.pos + _away(e, s.pos, s.id) * 1.2, 0.2)
		s.stun = 0.8
	var k: Entities.Knight = w.knight
	if k.down_t < 0.0 and SimWorld.flat_dist(k.pos, e.pos) <= t.radius + 0.6:
		Damage.to_knight(w, t.damage_to_knight, t.name + " ambush")
	e.surface_t = t.surface_seconds
	_recover(e, t, t.attack_cooldown)
	w.events.push("erupt", {"pos": e.pos, "type": e.type_id, "eaten": eaten})


# ---- frost, shaking, retreat, the night ---------------------------------------------------------

## Frost buildup. Full, the enemy is frozen solid for frozen_seconds.
static func add_freeze(w: SimWorld, e: Entities.Enemy, amount: float) -> void:
	if e.state == Entities.Enemy.State.DEAD or e.state == Entities.Enemy.State.FROZEN or e.state == Entities.Enemy.State.RETREAT:
		return
	if e.state == Entities.Enemy.State.LEAP or e.state == Entities.Enemy.State.BURROW:
		return
	e.freeze += amount
	if e.freeze >= 1.0:
		e.freeze = 0.0
		e.state = Entities.Enemy.State.FROZEN
		e.timer = w.content.wn("frost", "frozen_seconds", 6.0)
		e.wind = 0.0
		e.dazed = false
		w.events.push("frozen", {"pos": e.pos, "type": e.type_id})


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
