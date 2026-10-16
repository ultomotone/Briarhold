## The squad: pluck, follow, select, throw, whistle, dismiss, swarm, charge, flight, landing,
## idle auto-tasking, attacking, and the leash. No two sprigs move alike: each has its own lag
## and phase from its own RNG stream, and separation is soft.
##
## Shape after the Pikifen study (docs/research/pikifen-notes.md): ring counts derive from body
## size; the formation anchor only moves when he does or the squad strays (the shuffle
## deadband); throws pick the ripest sprig within grab range and fly to a fixed apex; idle work
## is nearest-wins; an attacker gives up past chase range; dismiss lays hex piles.
class_name SquadSystem
extends RefCounted

const SLAP_INTERVAL: float = 0.5
const HEX_ROWS: PackedInt32Array = [1, 6, 12, 18, 24]


static func step(w: SimWorld, cmd: Commands, dt: float) -> void:
	var k: Entities.Knight = w.knight
	var c: ContentTables = w.content
	if k.down_t < 0.0:
		_select(w, cmd)
		_pluck(w, cmd, dt)
		_store(w, cmd, dt)
		_whistle(w, cmd, dt)
		if cmd.dismiss_pressed:
			_dismiss(w)
		_throw_input(w, cmd, dt)
		if cmd.charge_pressed:
			_charge(w, cmd)
	_assign_slots(w)
	_update_anchor(w, dt)
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
				_follow(w, s, swarm_at, dt)
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


## The sprig's own speed with maturity and any status applied.
static func move_speed(w: SimWorld, s: Entities.Sprig) -> float:
	var t: Types.SprigType = w.sprig_type(s)
	var v: float = t.speed * w.maturity_mult(s)
	if not s.status.is_empty():
		var hz: Types.HazardType = w.content.hazard(s.hazard_id)
		if hz != null:
			v *= hz.speed_mult
	return v


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
	var seek: float = w.content.wn("squad", "pluck_seek_radius", 8.0)
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
		_withdraw(w, dt)
		return
	if best_d > r:
		# holding the key walks him to the next sprout in the patch, unless he is steering
		if cmd.move_dir.length_squared() < 0.001:
			k.yaw = SimWorld.yaw_toward(k.pos, best.pos, k.yaw)
			k.pos = w.step_toward(k.pos, best.pos, w.content.wn("knight", "speed", 5.6) * 0.8, dt, 0.35)
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


## Holding F beside a shrine with nothing left to pluck hands sprigs back out of storage, one
## every pluck interval, while the field has room. They step out of the shrine's foot and fall in.
static func _withdraw(w: SimWorld, dt: float) -> void:
	var k: Entities.Knight = w.knight
	var h: Hold = w.hold
	var best: Entities.Shrine = null
	var best_d: float = 3.2
	for sh: Entities.Shrine in w.shrines:
		if not sh.rooted or int(h.stored.get(sh.type_id, 0)) <= 0:
			continue
		var d: float = SimWorld.flat_dist(k.pos, sh.pos)
		if d < best_d:
			best_d = d
			best = sh
	if best == null:
		return
	if w.field_count() >= h.cap:
		return
	k.pluck_t += dt
	if k.pluck_t < 0.25:
		return
	k.pluck_t = 0.0
	h.stored[best.type_id] = int(h.stored[best.type_id]) - 1
	var to: Vector3 = best.pos.lerp(k.pos, 0.35)
	var s: Entities.Sprig = w.spawn_sprig(best.type_id, to, Entities.Sprig.State.FOLLOW, 0)
	s.stun = 0.2
	w.events.push("withdraw", {"pos": best.pos + Vector3(0.0, 2.3, 0.0), "to": to, "type": best.type_id, "left": int(h.stored[best.type_id])})
	if w.squad_types().find(k.selected_type) < 0:
		k.selected_type = best.type_id


## Holding G beside a shrine sends the following sprigs of its type inside, one at a time: the
## nearest walks the last step, vanishes into the foot of the shrine, and counts as inside.
static func _store(w: SimWorld, cmd: Commands, dt: float) -> void:
	var k: Entities.Knight = w.knight
	if not cmd.store_held:
		k.store_t = 0.14
		return
	var best: Entities.Shrine = null
	var best_d: float = 3.2
	for sh: Entities.Shrine in w.shrines:
		if not sh.rooted:
			continue
		var d: float = SimWorld.flat_dist(k.pos, sh.pos)
		if d < best_d:
			best_d = d
			best = sh
	if best == null:
		return
	k.store_t += dt
	if k.store_t < 0.14:
		return
	var pick: Entities.Sprig = null
	var pick_d: float = 1e9
	for s: Entities.Sprig in w.sprigs:
		if s.state != Entities.Sprig.State.FOLLOW or s.type_id != best.type_id:
			continue
		var d: float = SimWorld.flat_dist(s.pos, best.pos)
		if d < pick_d:
			pick_d = d
			pick = s
	if pick == null:
		return
	k.store_t = 0.0
	w.hold.store(pick.type_id, 1)
	w._detach(pick)
	pick.state = Entities.Sprig.State.DEAD # leaves the field without a tally: it is inside, not lost
	w.events.push("stored_in", {"pos": best.pos + Vector3(0.0, 0.6, 0.0), "type": pick.type_id, "inside": int(w.hold.stored.get(pick.type_id, 0))})


static func whistle_radius(w: SimWorld) -> float:
	var c: ContentTables = w.content
	var t: float = clampf(w.knight.whistle_t / maxf(0.01, c.wn("squad", "whistle_grow_seconds", 0.45)), 0.0, 1.0)
	return lerpf(c.wn("squad", "whistle_min_radius", 1.2), c.wn("squad", "whistle_max_radius", 6.0), t)


## Where the whistle lands: the cursor, no farther from him than whistle_reach.
static func whistle_centre(w: SimWorld, cmd: Commands) -> Vector3:
	var k: Entities.Knight = w.knight
	if not cmd.has_cursor():
		return k.pos
	return w.ground(Throw.clamp_target(k.pos, cmd.cursor, w.content.wn("squad", "whistle_reach", 8.0)))


static func _whistle(w: SimWorld, cmd: Commands, dt: float) -> void:
	var k: Entities.Knight = w.knight
	if not cmd.whistle_held:
		k.whistle_t = 0.0
		return
	k.whistle_t += dt
	var centre: Vector3 = whistle_centre(w, cmd)
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
		# the whistle shaves a knockdown short, for anyone, once
		if s.stun > 0.25:
			s.stun = 0.25
		if s.state != Entities.Sprig.State.FOLLOW:
			w.set_state(s, Entities.Sprig.State.FOLLOW)
			called += 1
	if called > 0 and w.squad_types().find(k.selected_type) < 0:
		k.selected_type = w.squad_types()[0]


## Dismiss: each type becomes a hex pile (rows of 1, 6, 12, 18) laid on an arc behind the
## squad's own centre, so piles read as piles and not as blobs the separation pass sorted out.
static func _dismiss(w: SimWorld) -> void:
	var k: Entities.Knight = w.knight
	var types: PackedStringArray = w.squad_types()
	if types.is_empty():
		return
	var c: ContentTables = w.content
	var row_gap: float = c.wn("squad", "dismiss_row_spacing", 0.32)
	var arc_d: float = c.wn("squad", "dismiss_arc_distance", 2.0)
	# base direction: from him toward where the squad actually is
	var mean := Vector3.ZERO
	var n: int = 0
	for s: Entities.Sprig in w.sprigs:
		if s.state == Entities.Sprig.State.FOLLOW:
			mean += s.pos
			n += 1
	mean /= float(maxi(1, n))
	var base: float = SimWorld.yaw_toward(k.pos, mean, k.yaw + PI) if n > 0 else k.yaw + PI
	var per_type: Array[Array] = []
	for id: String in types:
		var members: Array = []
		for s: Entities.Sprig in w.sprigs:
			if s.state == Entities.Sprig.State.FOLLOW and s.type_id == id:
				members.append(s)
		per_type.append(members)
	var count: int = 0
	for ti: int in types.size():
		var members: Array = per_type[ti]
		var rows: int = _hex_rows_for(members.size())
		var pile_r: float = 0.3 + row_gap * float(rows - 1)
		var ang: float = base + (float(ti) - float(types.size() - 1) * 0.5) * (2.0 * pile_r + 1.0) / arc_d
		var centre: Vector3 = k.pos + Vector3(sin(ang), 0.0, cos(ang)) * (arc_d + pile_r)
		var spots: PackedVector3Array = _hex_spots(members.size(), row_gap, ang)
		for i: int in members.size():
			var s: Entities.Sprig = members[i]
			w.set_state(s, Entities.Sprig.State.IDLE)
			s.charge_target = w.push_out(centre + spots[i], 0.2)
			s.idle_scan = -300 # the pile stands a while before it looks for work (bump lock)
			count += 1
	if count > 0:
		w.events.push("dismiss", {"pos": k.pos, "count": count})


static func _hex_rows_for(n: int) -> int:
	var total: int = 0
	for r: int in HEX_ROWS.size():
		total += HEX_ROWS[r]
		if n <= total:
			return r + 1
	return HEX_ROWS.size()


static func _hex_spots(n: int, gap: float, rot: float) -> PackedVector3Array:
	var out: PackedVector3Array = []
	var ring: int = 0
	var idx: int = 0
	while out.size() < n:
		var in_ring: int = HEX_ROWS[mini(ring, HEX_ROWS.size() - 1)]
		if ring == 0:
			out.append(Vector3.ZERO)
		else:
			var r: float = gap * float(ring)
			var a: float = rot + float(idx) / float(in_ring) * TAU
			out.append(Vector3(sin(a), 0.0, cos(a)) * r)
		idx += 1
		if idx >= in_ring:
			idx = 0
			ring += 1
	return out


## Space: the first press throws; holding keeps throwing, faster the longer it is held.
static func _throw_input(w: SimWorld, cmd: Commands, dt: float) -> void:
	var k: Entities.Knight = w.knight
	var c: ContentTables = w.content
	if cmd.throw_pressed:
		_throw(w, cmd)
		k.throw_held = 0.0
		k.throw_repeat = 0.0
		return
	if not cmd.throw_held or k.throw_held < 0.0:
		k.throw_held = -1.0
		return
	k.throw_held += dt
	var start: float = c.wn("squad", "throw_repeat_start", 0.5)
	if k.throw_held < start:
		return
	var ramp: float = maxf(0.01, c.wn("squad", "throw_repeat_ramp", 1.0))
	var interval: float = lerpf(start, c.wn("squad", "throw_repeat_min", 0.18), clampf((k.throw_held - start) / ramp, 0.0, 1.0))
	k.throw_repeat += dt
	if k.throw_repeat >= interval:
		k.throw_repeat -= interval
		_throw(w, cmd)


static func _throw(w: SimWorld, cmd: Commands) -> void:
	if not cmd.has_cursor():
		return
	var k: Entities.Knight = w.knight
	var grab: float = w.content.wn("squad", "throw_grab_radius", 5.4)
	# ripest first, then nearest: the bloom at the back goes before the leaf at his heel
	var best: Entities.Sprig = null
	var best_key: float = 1e9
	for s: Entities.Sprig in w.sprigs:
		if s.state != Entities.Sprig.State.FOLLOW or s.type_id != k.selected_type or s.stun > 0.0:
			continue
		var d: float = SimWorld.flat_dist(s.pos, k.pos)
		if d > grab:
			continue
		var key: float = float(2 - s.maturity) * 100.0 + d
		if key < best_key:
			best_key = key
			best = s
	if best == null:
		return
	var t: Types.SprigType = w.sprig_type(best)
	var target: Vector3 = w.ground(Throw.clamp_target(k.pos, cmd.cursor, t.throw_range))
	w.set_state(best, Entities.Sprig.State.THROWN)
	best.fl_start = k.pos + Vector3(0.0, 1.0, 0.0)
	best.fl_end = target
	best.fl_t = 0.0
	best.fl_total = flight_time(w, t)
	best.pos = best.fl_start
	best.prev = best.pos
	k.yaw = SimWorld.yaw_toward(k.pos, target, k.yaw)
	w.events.push("throw", {"pos": k.pos, "type": best.type_id, "to": target})


## Fixed apex per type: T = sqrt(8h / g). The same type always clears the same wall.
static func flight_time(w: SimWorld, t: Types.SprigType) -> float:
	var g: float = maxf(0.1, w.content.wn("squad", "throw_gravity", 22.0))
	return sqrt(8.0 * maxf(0.2, t.throw_height) / g)


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

## Followers are sorted so the selected type leads and, within it, bloom before leaf: the front
## of the formation is what he throws next.
static func _assign_slots(w: SimWorld) -> void:
	var followers: Array[Entities.Sprig] = []
	for s: Entities.Sprig in w.sprigs:
		if s.state == Entities.Sprig.State.FOLLOW:
			followers.append(s)
	var sel: String = w.knight.selected_type
	followers.sort_custom(func(a: Entities.Sprig, b: Entities.Sprig) -> bool:
		var sa: int = 0 if a.type_id == sel else 1
		var sb: int = 0 if b.type_id == sel else 1
		if sa != sb:
			return sa < sb
		if a.maturity != b.maturity:
			return a.maturity > b.maturity
		return a.id < b.id)
	for i: int in followers.size():
		followers[i].slot = i


## Ring n sits at n * (2r + gap) from the centre; spots per ring come from how many bodies fit
## around it, which yields 1, 3, 8, 12, 16... Spot 0 is the centre, then rings fill from the front.
static func slot_offset(w: SimWorld, slot: int, yaw: float) -> Vector3:
	if slot == 0:
		return Vector3.ZERO
	var c: ContentTables = w.content
	var body: float = c.wn("squad", "separation_radius", 0.42)
	var gap: float = c.wn("squad", "follow_ring_gap", 0.16)
	var pitch: float = body + gap
	var ring: int = 1
	var first: int = 1
	while true:
		var d: float = pitch * float(ring)
		var n: int = _ring_count(d, body + gap)
		if slot < first + n:
			var idx: int = slot - first
			# fill from the front: alternate left and right of the leader-facing axis
			var half: int = (idx + 1) / 2
			var side: float = 1.0 if (idx % 2 == 1) else -1.0
			var ang: float = yaw + PI + side * float(half) * (TAU / float(n))
			return Vector3(sin(ang), 0.0, cos(ang)) * d
		first += n
		ring += 1
		if ring > 24:
			break
	return Vector3(sin(yaw + PI), 0.0, cos(yaw + PI)) * pitch * 25.0


static func _ring_count(d: float, diameter: float) -> int:
	var half: float = diameter * 0.5
	if d <= half:
		return 1
	var middle: float = sqrt(maxf(0.0001, d * d - half * half))
	var angular: float = 2.0 * atan2(diameter, 2.0 * middle)
	return maxi(1, int(floorf(TAU / angular)))


## The anchor trails him and only moves when he moves, or when the squad's centre has strayed
## past the deadband; an idle squad settles instead of jittering with his facing.
static func _update_anchor(w: SimWorld, dt: float) -> void:
	var k: Entities.Knight = w.knight
	var moved: bool = k.prev.distance_squared_to(k.pos) > 0.000004
	var trail: Vector3 = k.pos - Vector3(sin(k.yaw), 0.0, cos(k.yaw)) * 1.1
	if w.anchor == Vector3.INF or moved:
		w.anchor = trail
		w.anchor_yaw = k.yaw
		return
	var mean := Vector3.ZERO
	var n: int = 0
	for s: Entities.Sprig in w.sprigs:
		if s.state == Entities.Sprig.State.FOLLOW:
			mean += s.pos
			n += 1
	if n == 0:
		return
	mean /= float(n)
	var dead: float = w.content.wn("squad", "follow_deadband", 1.7)
	if SimWorld.flat_dist(mean, k.pos) > dead + sqrt(float(n)) * 0.3:
		# ease the anchor home rather than snapping it
		w.anchor = w.anchor.lerp(trail, clampf(dt * 4.0, 0.0, 1.0))
		w.anchor_yaw = lerp_angle(w.anchor_yaw, k.yaw, clampf(dt * 4.0, 0.0, 1.0))


static func _follow(w: SimWorld, s: Entities.Sprig, swarm_at: Vector3, dt: float) -> void:
	var k: Entities.Knight = w.knight
	var desired: Vector3
	var speed: float = move_speed(w, s)
	if swarm_at != Vector3.INF:
		# the swarm stretches toward the cursor: long along the throw line, thin across it
		var to: Vector3 = swarm_at - k.pos
		to.y = 0.0
		var mag: float = clampf(to.length() / 8.0, 0.0, 1.0)
		var off: Vector3 = slot_offset(w, s.slot, k.yaw)
		var axis: Vector3 = to.normalized() if to.length() > 0.01 else Vector3(sin(k.yaw), 0.0, cos(k.yaw))
		var side := Vector3(axis.z, 0.0, -axis.x)
		var along: float = off.dot(axis) * (1.0 + mag * 1.5)
		var across: float = off.dot(side) * (1.0 - 0.5 * mag)
		desired = swarm_at + axis * along + side * across
		speed *= w.content.wn("squad", "swarm_speed_mult", 1.15)
	else:
		desired = w.anchor + slot_offset(w, s.slot, w.anchor_yaw)
	var a: float = clampf(dt / maxf(0.02, s.lag), 0.0, 1.0)
	s.smooth_target = s.smooth_target.lerp(desired, a)
	var d: float = SimWorld.flat_dist(s.pos, s.smooth_target)
	if d > 0.21:
		# face the way it walks, but not for the last little shuffle: that reads as twitching
		if d > 0.4:
			s.yaw = SimWorld.yaw_toward(s.pos, s.smooth_target, s.yaw)
		s.pos = w.step_toward(s.pos, s.smooth_target, minf(speed, d / dt * 0.5 + 0.5), dt, 0.2)
	else:
		# settled: turn, slowly, to face where he faces
		s.yaw = lerp_angle(s.yaw, k.yaw, clampf(dt * 3.0, 0.0, 1.0))
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
				Damage.to_enemy(w, e, Damage.facing_mult(e, et, s.pos) * t.damage, t.name + " impact", e.pos + Vector3(0.0, et.height, 0.0))
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
	if s.charge_target == Vector3.INF:
		w.set_state(s, Entities.Sprig.State.IDLE)
		return
	var speed: float = move_speed(w, s) * w.content.wn("squad", "charge_speed_mult", 1.6)
	s.yaw = SimWorld.yaw_toward(s.pos, s.charge_target, s.yaw)
	s.pos = w.step_toward(s.pos, s.charge_target, speed, dt, 0.2)
	if SimWorld.flat_dist(s.pos, s.charge_target) < 0.5:
		var at: Vector3 = s.charge_target
		w.set_state(s, Entities.Sprig.State.IDLE)
		s.pos = w.ground(at)
		land(w, s)


# ---- idle and work --------------------------------------------------------------------------

## Idle work is nearest-wins across everything in reach: a load half a metre away beats a grub
## three metres away. No category priority, exactly as the reference engine does it.
static func _idle(w: SimWorld, s: Entities.Sprig, dt: float) -> void:
	# a dismissed or delivered sprig first walks to its spot
	if s.charge_target != Vector3.INF:
		if SimWorld.flat_dist(s.pos, s.charge_target) > 0.3:
			s.yaw = SimWorld.yaw_toward(s.pos, s.charge_target, s.yaw)
			s.pos = w.step_toward(s.pos, s.charge_target, move_speed(w, s) * 0.8, dt, 0.2)
			return
		s.charge_target = Vector3.INF
	s.idle_scan += 1
	if s.idle_scan < 0 or (s.idle_scan + s.id) % 10 != 0:
		s.pos = w.push_out(s.pos, 0.2)
		return
	if not s.status.is_empty():
		return # a burning sprig has other things on its mind
	var r: float = w.content.wn("squad", "idle_task_radius", 3.0)
	var best_d: float = r
	var best_e: Entities.Enemy = null
	var best_o: Entities.WorldObject = null
	var best_g: Entities.Gate = null
	for e: Entities.Enemy in w.enemies:
		if e.state == Entities.Enemy.State.DEAD or e.state == Entities.Enemy.State.SLEEP or e.state == Entities.Enemy.State.RETREAT:
			continue
		var d: float = SimWorld.flat_dist(s.pos, e.pos) - w.enemy_type(e).radius
		if d < best_d:
			best_d = d
			best_e = e
	for o: Entities.WorldObject in w.objects:
		if o.taken or o.carriers.size() >= o.max_carriers:
			continue
		var d: float = SimWorld.flat_dist(s.pos, o.pos) - o.radius
		if d < best_d:
			best_d = d
			best_o = o
			best_e = null
	for g: Entities.Gate in w.gates:
		if g.open:
			continue
		var d: float = SimWorld.flat_dist(s.pos, g.pos) - g.width * 0.5
		if d < best_d:
			best_d = d
			best_g = g
			best_o = null
			best_e = null
	if best_e != null:
		w.set_state(s, Entities.Sprig.State.ATTACK)
		s.enemy_id = best_e.id
		s.latched = false
		s.anchor = s.id % 12
	elif best_o != null:
		CarrySystem.join(w, s, best_o)
	elif best_g != null:
		w.set_state(s, Entities.Sprig.State.ATTACK)
		s.gate_id = best_g.id


static func _attack(w: SimWorld, s: Entities.Sprig, dt: float) -> void:
	var t: Types.SprigType = w.sprig_type(s)
	if not s.status.is_empty():
		var hz: Types.HazardType = w.content.hazard(s.hazard_id)
		if hz != null and hz.disables_attack:
			w.set_state(s, Entities.Sprig.State.IDLE)
			return
	if s.enemy_id >= 0:
		var e: Entities.Enemy = w.enemy_by_id(s.enemy_id)
		if e == null or e.state == Entities.Enemy.State.DEAD:
			w.set_state(s, Entities.Sprig.State.IDLE)
			return
		var et: Types.EnemyType = w.enemy_type(e)
		if not s.latched:
			# it gives up past chase range: no sprig pursues a grub across the whole field
			if SimWorld.flat_dist(s.pos, e.pos) > w.content.wn("squad", "chase_range", 8.0):
				w.set_state(s, Entities.Sprig.State.IDLE)
				return
			s.yaw = SimWorld.yaw_toward(s.pos, e.pos, s.yaw)
			s.pos = w.step_toward(s.pos, e.pos, move_speed(w, s), dt, 0.2)
			if SimWorld.flat_dist(s.pos, e.pos) <= et.radius + 0.35:
				if t.attack == "impact":
					Damage.to_enemy(w, e, Damage.facing_mult(e, et, s.pos) * t.damage * 0.5, t.name + " butt", e.pos + Vector3(0.0, et.height * 0.6, 0.0))
					var away: Vector3 = (s.pos - e.pos)
					away.y = 0.0
					s.pos = w.push_out(e.pos + away.normalized() * (et.radius + 0.9), 0.2)
					s.stun = 0.7
				else:
					s.latched = true
					s.slap_t = 0.0
			return
		var ang: float = float(s.anchor) / 12.0 * TAU
		s.pos = e.pos + Vector3(sin(ang), 0.0, cos(ang)) * et.radius * 0.8
		s.pos.y = e.pos.y + et.height * 0.6
		s.yaw = ang + PI
		s.slap_t += dt
		if s.slap_t >= SLAP_INTERVAL:
			s.slap_t -= SLAP_INTERVAL
			Damage.to_enemy(w, e, Damage.facing_mult(e, et, s.pos) * t.damage, t.name + " sprig", e.pos + Vector3(0.0, et.height, 0.0))
			if s.type_id == "frost":
				EnemySystem.add_freeze(w, e, w.content.wn("frost", "buildup_per_slap", 0.08))
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
			s.pos = w.step_toward(s.pos, spot, move_speed(w, s), dt, 0.2)
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
			push += d * ((r - len) / len) * 0.3
		if push.length_squared() > 0.0:
			s.pos = w.ground(w.field.clamp_bound(s.pos + push))


static func _leash(w: SimWorld, leash: float) -> void:
	var k: Entities.Knight = w.knight
	for s: Entities.Sprig in w.sprigs:
		if s.state == Entities.Sprig.State.FOLLOW and SimWorld.flat_dist(s.pos, k.pos) > leash:
			w.set_state(s, Entities.Sprig.State.IDLE)
			w.events.push("lost_follow", {"pos": s.pos, "type": s.type_id})
