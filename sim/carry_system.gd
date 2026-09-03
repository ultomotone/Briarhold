## Carrying: a load has a weight and a carrier limit; it moves once the carriers' strength meets
## the weight, faster with more hands, along a path the PathProvider gives, and delivers at the
## Hold. speed = base * lerp(min, max, carriers / max_carriers).
class_name CarrySystem
extends RefCounted


static func join(w: SimWorld, s: Entities.Sprig, o: Entities.WorldObject) -> void:
	if o.taken or o.carriers.size() >= o.max_carriers:
		w.set_state(s, Entities.Sprig.State.IDLE)
		return
	var j: Entities.CarryJob = w.job_for_object(o.id)
	if j == null:
		j = Entities.CarryJob.new()
		j.id = w.new_id()
		j.object_id = o.id
		w.jobs.append(j)
	w.set_state(s, Entities.Sprig.State.CARRY)
	s.job_id = j.id
	s.anchor = o.carriers.size()
	o.carriers.append(s.id)
	j.carriers = o.carriers


static func speed_for(c: ContentTables, o: Entities.WorldObject, on_count: int, mat_avg: float) -> float:
	var fill: float = clampf(float(on_count) / float(maxi(1, o.max_carriers)), 0.0, 1.0)
	var m: float = lerpf(c.wn("carry", "speed_min_mult", 0.3), c.wn("carry", "speed_max_mult", 0.8), fill)
	return c.wn("carry", "base_speed", 2.6) * m * mat_avg


static func anchor_point(o: Entities.WorldObject, anchor: int, total: int) -> Vector3:
	var n: int = maxi(1, total)
	var ang: float = float(anchor) / float(n) * TAU + o.yaw
	return o.pos + Vector3(sin(ang), 0.0, cos(ang)) * (o.radius + 0.28)


static func destination(w: SimWorld, o: Entities.WorldObject) -> Vector3:
	if o.kind == "shrine":
		# a new shrine roots beside the others, on its own spoke of the clearing
		var i: int = w.shrines.size()
		var ang: float = -0.6 + float(i) * 1.1
		return w.ground(w.hold.pos + Vector3(sin(ang), 0.0, cos(ang)) * 5.5)
	return w.ground(w.hold.pos)


static func step(w: SimWorld, dt: float) -> void:
	var c: ContentTables = w.content
	for j: Entities.CarryJob in w.jobs:
		var o: Entities.WorldObject = w.object_by_id(j.object_id)
		if o == null:
			continue
		j.carriers = o.carriers
		# carriers walk to their anchors; only the ones on an anchor lift
		var strength: int = 0
		var on_count: int = 0
		var mat_sum: float = 0.0
		var total: int = o.carriers.size()
		var idx: int = 0
		for sid: int in o.carriers:
			var s: Entities.Sprig = w.sprig_by_id(sid)
			if s == null:
				idx += 1
				continue
			s.anchor = idx
			var t: Types.SprigType = w.sprig_type(s)
			var a: Vector3 = anchor_point(o, idx, total)
			var d: float = SimWorld.flat_dist(s.pos, a)
			if d > 0.35 and not j.moving:
				s.yaw = SimWorld.yaw_toward(s.pos, a, s.yaw)
				s.pos = w.step_toward(s.pos, a, t.speed * w.maturity_mult(s), dt, 0.15)
			else:
				s.pos = w.ground(a)
				s.yaw = SimWorld.yaw_toward(s.pos, o.pos, s.yaw)
				strength += t.strength
				on_count += 1
				mat_sum += w.maturity_mult(s)
			idx += 1
		if on_count == 0:
			j.moving = false
			continue
		j.moving = strength >= o.weight
		if not j.moving:
			continue
		# path to the Hold, re-requested when the walkable set changed
		if o.path.is_empty() or o.path_gen != w.paths.generation:
			o.path = w.paths.path(o.pos, destination(w, o))
			o.path_i = 1
			o.path_gen = w.paths.generation
		if o.path_i >= o.path.size():
			_deliver(w, j, o)
			continue
		var speed: float = speed_for(c, o, on_count, mat_sum / float(on_count))
		var wp: Vector3 = o.path[o.path_i]
		var to: Vector3 = wp - o.pos
		to.y = 0.0
		var len: float = to.length()
		var m: float = speed * dt
		if len <= m:
			o.pos = w.ground(wp)
			o.path_i += 1
		else:
			o.pos = w.ground(o.pos + to * (m / len))
			o.yaw = SimWorld.yaw_toward(Vector3.ZERO, to, o.yaw)
		if o.kind != "shrine" and w.hold.in_hold(o.pos) and SimWorld.flat_dist(o.pos, w.hold.pos) < w.hold.radius * 0.45:
			_deliver(w, j, o)


static func majority_type(w: SimWorld, o: Entities.WorldObject) -> String:
	var counts: Dictionary = {}
	for sid: int in o.carriers:
		var s: Entities.Sprig = w.sprig_by_id(sid)
		if s != null:
			counts[s.type_id] = int(counts.get(s.type_id, 0)) + 1
	var best: String = ""
	var best_n: int = -1
	for id: String in w.content.sprig_order:
		var n: int = int(counts.get(id, 0))
		if n > best_n:
			best_n = n
			best = id
	return best


static func _deliver(w: SimWorld, _j: Entities.CarryJob, o: Entities.WorldObject) -> void:
	var h: Hold = w.hold
	var carriers: PackedInt32Array = o.carriers.duplicate()
	var maj: String = majority_type(w, o)
	var seeds: int = 0
	var text: String = ""
	match o.kind:
		"pellet":
			seeds = o.seeds_match if (o.pellet_type.is_empty() or o.pellet_type == maj) else o.seeds_other
			text = "%s: %d seeds" % [o.name, seeds]
		"corpse":
			seeds = o.seeds_match
			text = "%s: %d seeds" % [o.name, seeds]
		"relic":
			h.bank_relic(o.type_id, o.value)
			text = "%s banked, +%d" % [o.name, o.value]
		"heartroot":
			h.cap += h.cap_per_heartroot
			h.heartroots += 1
			text = "Heartroot: field cap %d" % h.cap
		"shrine":
			var sh: Entities.Shrine = w.root_shrine(o.shrine_type, o.pos)
			var rooted: PackedStringArray = w.deltas["rooted"]
			rooted.append(o.shrine_type)
			w.deltas["rooted"] = rooted
			seeds = 6
			maj = o.shrine_type
			text = "%s rooted" % o.name
			w.events.push("shrine_rooted", {"pos": sh.pos, "type": sh.type_id})
	if seeds > 0:
		h.queue_seeds(maj, seeds)
	o.taken = true
	if not o.seed_id.is_empty():
		var taken: PackedStringArray = w.deltas["taken"]
		taken.append(o.seed_id)
		w.deltas["taken"] = taken
	# the carriers set it down and wait at the Hold
	var i: int = 0
	for sid: int in carriers:
		var s: Entities.Sprig = w.sprig_by_id(sid)
		if s == null:
			continue
		w.set_state(s, Entities.Sprig.State.IDLE)
		var ang: float = float(i) / float(maxi(1, carriers.size())) * TAU
		s.charge_target = w.ground(o.pos + Vector3(sin(ang), 0.0, cos(ang)) * 1.6)
		i += 1
	w.events.push("delivered", {"pos": o.pos, "text": text, "kind": o.kind, "seeds": seeds, "type": maj})
