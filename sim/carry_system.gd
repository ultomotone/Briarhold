## Carrying: a load has a weight and a carrier limit; it moves once the carriers' strength meets
## the weight, faster with more hands, along a path the PathProvider gives, and delivers at the
## Hold. Carrier spots ring the load; the ring turns to face the first claimant and each arrival
## takes the nearest free spot, so a whistled-off carrier never reshuffles the rest.
##
## speed = base * max_mult * (1 - weight_mult * weight) * (min_mult + fill * (1 - min_mult))
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
	if o.slots.size() != o.max_carriers:
		o.slots.resize(o.max_carriers)
		o.slots.fill(-1)
	if o.carriers.is_empty():
		# the first claimant sets the ring: spot 0 faces it
		o.yaw = SimWorld.yaw_toward(o.pos, s.pos, o.yaw)
	var slot: int = _nearest_free_slot(o, s.pos)
	if slot < 0:
		w.set_state(s, Entities.Sprig.State.IDLE)
		return
	w.set_state(s, Entities.Sprig.State.CARRY)
	s.job_id = j.id
	s.anchor = slot
	o.slots[slot] = s.id
	o.carriers.append(s.id)
	j.carriers = o.carriers


static func _nearest_free_slot(o: Entities.WorldObject, from: Vector3) -> int:
	var best: int = -1
	var best_d: float = 1e9
	for i: int in o.slots.size():
		if o.slots[i] != -1:
			continue
		var d: float = SimWorld.flat_dist(from, anchor_point(o, i, o.max_carriers))
		if d < best_d:
			best_d = d
			best = i
	return best


static func speed_for(c: ContentTables, o: Entities.WorldObject, on_count: int, mat_avg: float) -> float:
	var fill: float = clampf(float(on_count) / float(maxi(1, o.max_carriers)), 0.0, 1.0)
	var lo: float = c.wn("carry", "speed_min_mult", 0.3)
	var hi: float = c.wn("carry", "speed_max_mult", 0.8)
	var weight_pen: float = clampf(1.0 - c.wn("carry", "speed_weight_mult", 0.01) * float(o.weight), 0.25, 1.0)
	return c.wn("carry", "base_speed", 2.6) * hi * weight_pen * (lo + fill * (1.0 - lo)) * mat_avg


static func anchor_point(o: Entities.WorldObject, anchor: int, total: int) -> Vector3:
	var n: int = maxi(1, total)
	var ang: float = float(anchor) / float(n) * TAU + o.yaw
	return o.pos + Vector3(sin(ang), 0.0, cos(ang)) * (o.radius + 0.28)


## Seeds go to the shrine of the carriers' majority type; relics and heartroots to the Hold's
## centre; a new shrine to its own spoke of the clearing.
static func destination(w: SimWorld, o: Entities.WorldObject) -> Vector3:
	if o.kind == "shrine":
		var i: int = w.shrines.size()
		var ang: float = -0.6 + float(i) * 1.1
		return w.ground(w.hold.pos + Vector3(sin(ang), 0.0, cos(ang)) * 5.5)
	if o.kind == "pellet" or o.kind == "corpse":
		var sh: Entities.Shrine = w.shrine_for(o.dest_type)
		if sh != null:
			return sh.pos
	return w.ground(w.hold.pos)


static func arrive_radius(w: SimWorld, o: Entities.WorldObject) -> float:
	if (o.kind == "pellet" or o.kind == "corpse") and w.shrine_for(o.dest_type) != null:
		return 1.6 + o.radius
	return w.hold.radius * 0.45


static func step(w: SimWorld, dt: float) -> void:
	var c: ContentTables = w.content
	var absorb: float = c.wn("sprout", "absorb_seconds", 0.9)
	for j: Entities.CarryJob in w.jobs:
		var o: Entities.WorldObject = w.object_by_id(j.object_id)
		if o == null:
			continue
		if o.absorb_t >= 0.0:
			# drawn up into the shrine, then it is seeds
			o.absorb_t += dt
			var u: float = clampf(o.absorb_t / absorb, 0.0, 1.0)
			o.pos = o.pos.lerp(o.absorb_to, u * u)
			if o.absorb_t >= absorb:
				_finish(w, o)
			continue
		j.carriers = o.carriers
		# carriers walk to their spots; only the ones on a spot lift
		var strength: int = 0
		var on_count: int = 0
		var mat_sum: float = 0.0
		for sid: int in o.carriers:
			var s: Entities.Sprig = w.sprig_by_id(sid)
			if s == null:
				continue
			var a: Vector3 = anchor_point(o, s.anchor, o.max_carriers)
			var d: float = SimWorld.flat_dist(s.pos, a)
			if d > 0.35 and not j.moving:
				s.yaw = SimWorld.yaw_toward(s.pos, a, s.yaw)
				s.pos = w.step_toward(s.pos, a, SquadSystem.move_speed(w, s), dt, 0.15)
			else:
				s.pos = w.ground(a)
				s.yaw = SimWorld.yaw_toward(s.pos, o.pos, s.yaw)
				strength += w.sprig_type(s).strength
				on_count += 1
				mat_sum += w.maturity_mult(s)
		if on_count == 0:
			j.moving = false
			continue
		j.moving = strength >= o.weight
		if not j.moving:
			continue
		# the route home: to the majority type's shrine, around every hazard some carrier is not
		# immune to, or straight over everything if they all fly. Re-asked when any of that, or
		# the walkable set, changes.
		var maj: String = majority_type(w, o)
		var route: Dictionary = route_for(w, o)
		var key: String = "%s|%s|%s" % [maj, ",".join(route["avoid"]), str(route["fly"])]
		if o.stuck_t > 0.0 and key == o.route_key and o.path_gen == w.paths.generation:
			o.stuck_t -= dt
			continue
		if o.path.is_empty() or o.path_gen != w.paths.generation or key != o.route_key:
			o.dest_type = maj
			o.route_key = key
			o.path = w.paths.path(o.pos, destination(w, o), route["avoid"], route["fly"])
			o.path_i = 1
			o.path_gen = w.paths.generation
			if o.path.is_empty():
				if not w.paths.is_ready():
					o.stuck_t = 0.5 # the routes are still being worked out; wait without a word
					continue
				o.stuck_t = 2.0
				o.stuck_count += 1
				if o.stuck_count == 2:
					w.events.push("stuck", {"pos": o.pos, "name": o.name})
				continue
			o.stuck_count = 0
		if o.path_i >= o.path.size():
			if SimWorld.flat_dist(o.pos, destination(w, o)) <= arrive_radius(w, o) + 1.0:
				_deliver(w, j, o)
			else:
				o.path = PackedVector3Array() # a stale route ran out short: ask again
				o.stuck_t = 1.0
			continue
		var speed: float = speed_for(c, o, on_count, mat_sum / float(on_count))
		var wp: Vector3 = o.path[o.path_i]
		var to: Vector3 = wp - o.pos
		to.y = 0.0
		var len: float = to.length()
		var m: float = speed * dt
		var heading: float = o.yaw
		if len <= m:
			o.pos = w.ground(wp)
			o.path_i += 1
		else:
			o.pos = w.ground(o.pos + to * (m / len))
			heading = SimWorld.yaw_toward(Vector3.ZERO, to, o.yaw)
		# the ring turns with the heading, so the front carriers stay in front
		o.yaw = lerp_angle(o.yaw, heading, clampf(dt * 3.0, 0.0, 1.0))
		if o.kind != "shrine" and SimWorld.flat_dist(o.pos, destination(w, o)) <= arrive_radius(w, o):
			_deliver(w, j, o)


## What this carrier group has to route around, and whether it flies. A hazard is avoided if any
## carrier is not immune to it (one drowning carrier drowns the trip); flying needs every carrier
## to fly.
static func route_for(w: SimWorld, o: Entities.WorldObject) -> Dictionary:
	var ids: PackedStringArray = []
	for z: Entities.HazardZone in w.hazards:
		if not ids.has(z.hazard_id):
			ids.append(z.hazard_id)
	ids.sort()
	var types: Array[Types.SprigType] = []
	for sid: int in o.carriers:
		var s: Entities.Sprig = w.sprig_by_id(sid)
		if s != null:
			types.append(w.sprig_type(s))
	var fly: bool = not types.is_empty()
	for t: Types.SprigType in types:
		if not t.can_fly:
			fly = false
	var avoid: PackedStringArray = []
	for id: String in ids:
		var all_immune: bool = not types.is_empty()
		for t: Types.SprigType in types:
			if not t.immune.has(id):
				all_immune = false
				break
		if not all_immune:
			avoid.append(id)
	return {"avoid": avoid, "fly": fly}


static func majority_type(w: SimWorld, o: Entities.WorldObject) -> String:
	var counts: Dictionary = {}
	for sid: int in o.carriers:
		var s: Entities.Sprig = w.sprig_by_id(sid)
		if s != null:
			counts[s.type_id] = int(counts.get(s.type_id, 0)) + 1
	# ties go to the type with the smaller population: the scarce type grows
	var census: Dictionary = w.census()
	var best: String = ""
	var best_n: int = -1
	var best_pop: int = 1 << 30
	for id: String in w.content.sprig_order:
		var n: int = int(counts.get(id, 0))
		var pop: int = int(census.get(id, 0))
		if n > best_n or (n == best_n and n > 0 and pop < best_pop):
			best_n = n
			best_pop = pop
			best = id
	return best


## Arrival: the carriers set it down and step back; the load is drawn into the shrine (or, for
## relics, heartroots, and shrines, taken at once).
static func _deliver(w: SimWorld, _j: Entities.CarryJob, o: Entities.WorldObject) -> void:
	o.absorb_type = majority_type(w, o)
	var carriers: PackedInt32Array = o.carriers.duplicate()
	var i: int = 0
	for sid: int in carriers:
		var s: Entities.Sprig = w.sprig_by_id(sid)
		if s == null:
			continue
		w.set_state(s, Entities.Sprig.State.IDLE)
		var ang: float = float(i) / float(maxi(1, carriers.size())) * TAU
		s.charge_target = w.ground(o.pos + Vector3(sin(ang), 0.0, cos(ang)) * 1.8)
		i += 1
	var sh: Entities.Shrine = w.shrine_for(o.absorb_type) if (o.kind == "pellet" or o.kind == "corpse") else null
	if sh != null:
		o.absorb_t = 0.0
		o.absorb_to = sh.pos + Vector3(0.0, 2.4, 0.0)
		w.events.push("absorb", {"pos": o.pos, "to": o.absorb_to, "type": o.absorb_type, "kind": o.kind})
		return
	_finish(w, o)


static func _finish(w: SimWorld, o: Entities.WorldObject) -> void:
	var h: Hold = w.hold
	var maj: String = o.absorb_type if not o.absorb_type.is_empty() else majority_type(w, o)
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
		var room: int = maxi(0, h.cap - w.field_count() - h.queued())
		h.queue_seeds(maj, seeds)
		if room < seeds:
			text += " (%d kept inside: field full)" % (seeds - room)
	o.taken = true
	if not o.seed_id.is_empty():
		var taken: PackedStringArray = w.deltas["taken"]
		taken.append(o.seed_id)
		w.deltas["taken"] = taken
	w.events.push("delivered", {"pos": o.pos, "text": text, "kind": o.kind, "seeds": seeds, "type": maj})
