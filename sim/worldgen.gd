## The field, rolled from the seed. Everything placed here carries a seed_id so the save can
## store only what changed (taken, felled, opened, rooted) and regenerate the rest.
class_name Worldgen
extends RefCounted


static func populate(w: SimWorld) -> void:
	var ss: String = w.seed_str()
	# the Ember shrine stands in the clearing; twelve sprouts wait at its foot
	var ember: Entities.Shrine = w.root_shrine("ember", Vector3(5.5, 0.0, -3.0))
	var r0 := Rng.stream(ss + ":start")
	for i: int in 12:
		var ang: float = float(i) / 12.0 * TAU + r0.randf() * 0.3
		var d: float = 1.5 + r0.randf() * 1.6
		w.spawn_sprout("ember", ember.pos + Vector3(sin(ang), 0.0, cos(ang)) * d, Vector3.INF, 1 if i < 4 else 0)
	# the outer territories claim their ground first, then the field's stones go around them
	var region_centres: Array[Vector3] = _reserve_regions(w)
	# stones: the field's furniture and its walls
	_stones(w)
	# the bigger furniture: stumps, fallen branches, ruins, mushrooms, daisies
	_scenery(w)
	for i: int in region_centres.size():
		_build_region(w, i, region_centres[i])
	# the Stone shrine waits in the field with a few sprouts of its own
	var stone_at: Vector3 = _open_spot(w, Rng.stream(ss + ":stone"), 22.0, 30.0)
	w.spawn_shrine_object("stone", stone_at, "shrine:stone")
	var r1 := Rng.stream(ss + ":stone-sprouts")
	for i: int in 5:
		var ang: float = float(i) / 5.0 * TAU + r1.randf() * 0.4
		w.spawn_sprout("stone", stone_at + Vector3(sin(ang), 0.0, cos(ang)) * (1.6 + r1.randf()), Vector3.INF, 0)
	# pools: water, with something in them that only a Tide sprig will fetch
	var rw := Rng.stream(ss + ":pools")
	for i: int in 4:
		var p: Vector3 = _open_spot(w, rw, 26.0, w.field.bound - 10.0)
		var rad: float = 3.2 + rw.randf() * 2.2
		_zone(w, "water", p, rad)
		w.spawn_object("pellet_10" if i % 2 == 0 else "relic_marble", p + Vector3(0.4, 0.0, 0.2), "pool:%d" % i, "ember")
	# posies: pellet flowers that regrow on a clock
	var rpo := Rng.stream(ss + ":posies")
	for i: int in 12:
		var p: Vector3 = _open_spot(w, rpo, 14.0, w.field.bound - 8.0)
		var po: Entities.Posy = w.spawn_posy(p, "ember" if rpo.randf() < 0.6 else "stone", i)
		po.timer = 20.0 + rpo.randf() * 60.0
	# pellets scattered over the field
	var rp := Rng.stream(ss + ":pellets")
	for i: int in 56:
		var p: Vector3 = _open_spot(w, rp, 13.0, w.field.bound - 6.0)
		var roll: float = rp.randf()
		var tid: String = "pellet_1" if roll < 0.6 else ("pellet_5" if roll < 0.9 else "pellet_10")
		var ptype: String = "ember" if rp.randf() < 0.65 else "stone"
		w.spawn_object(tid, p, "pellet:%d" % i, ptype)
	# relics in the open: a reason to go looking
	var rr := Rng.stream(ss + ":relics")
	w.spawn_object("relic_button", _open_spot(w, rr, 18.0, 40.0), "relic:button")
	w.spawn_object("relic_thimble", _open_spot(w, rr, 36.0, 60.0), "relic:thimble")
	w.spawn_object("relic_coin", _open_spot(w, rr, 50.0, 90.0), "relic:coin")
	w.spawn_object("relic_bead", _open_spot(w, rr, 20.0, 70.0), "relic:bead")
	w.spawn_object("relic_bottlecap", _open_spot(w, rr, 60.0, 100.0), "relic:bottlecap")
	# grubs asleep in the open, each with pellets at its feet
	var rg := Rng.stream(ss + ":grubs")
	var placed: Array[Vector3] = []
	var tries: int = 0
	while placed.size() < 7 and tries < 120:
		tries += 1
		var p: Vector3 = _open_spot(w, rg, 24.0, w.field.bound - 8.0)
		var ok: bool = true
		for q: Vector3 in placed:
			if SimWorld.flat_dist(p, q) < 16.0:
				ok = false
		if SimWorld.flat_dist(p, stone_at) < 10.0:
			ok = false
		if not ok:
			continue
		placed.append(p)
		var e: Entities.Enemy = w.spawn_enemy("grub", p, "grub:%d" % placed.size())
		e.yaw = rg.randf() * TAU
		for j: int in 2:
			var ang: float = rg.randf() * TAU
			w.spawn_object("pellet_5", p + Vector3(sin(ang), 0.0, cos(ang)) * (2.6 + rg.randf()), "grub:%d:pellet:%d" % [placed.size(), j], "ember")
	# fire vents with fat pellets in the flames: Ember work
	var rv := Rng.stream(ss + ":vent")
	for i: int in 2:
		var vent_at: Vector3 = _open_spot(w, rv, 18.0 + float(i) * 30.0, 34.0 + float(i) * 50.0)
		var z := Entities.HazardZone.new()
		z.id = w.new_id()
		z.hazard_id = "fire"
		z.pos = w.ground(vent_at)
		z.radius = 2.2
		w.hazards.insert(i, z) # vents first: tests and the view index them that way
		w.spawn_object("pellet_10", vent_at + Vector3(0.4, 0.0, 0.3), "vent:%d:pellet" % i, "ember")
	# bramble gates and the pockets behind them: rings of stones with one way in
	var rgate := Rng.stream(ss + ":gate")
	var gate_ang0: float = rgate.randf() * TAU
	for gi: int in 2:
		_pocket(w, rgate, gate_ang0 + float(gi) * 2.4, 44.0 + float(gi) * 36.0, gi)
	# the beasts, each where its kind would live
	_beasts(w)
	# the day's first animals
	var rb := Rng.stream(ss + ":beetles")
	for i: int in w.content.wi_in("arrivals", "start_beetles", 4):
		var e: Entities.Enemy = w.spawn_enemy("field_beetle", _open_spot(w, rb, 14.0, w.field.bound - 8.0), "beetle:%d" % i)
		e.state = Entities.Enemy.State.IDLE
	# green scatter for the view only: leaves, stalks, tufts, clover, ferns and small flowers,
	# never in the way. Thickets where the slow noise says so; flowers where the meadow noise does.
	var rpl := Rng.stream(ss + ":plants")
	for i: int in 1800:
		var p: Vector3 = _open_spot(w, rpl, 6.0, w.field.bound - 2.0, false)
		var thick: float = w.field.noise2(p.x * 0.05 + 3.0, p.z * 0.05 - 9.0)
		var meadow: float = w.field.noise2(p.x * 0.035 - 40.0, p.z * 0.035 + 12.0)
		if thick < 0.42 and meadow < 0.5 and rpl.randf() < 0.6:
			continue
		var roll: float = rpl.randf()
		var kind: String
		if meadow > 0.55 and roll < 0.45:
			kind = "flower"
		elif roll < 0.3:
			kind = "stalk"
		elif roll < 0.52:
			kind = "leaf"
		elif roll < 0.72:
			kind = "tuft"
		elif roll < 0.86:
			kind = "clover"
		else:
			kind = "fern"
		w.plants.append({"pos": w.ground(p), "s": 0.5 + rpl.randf() * 1.3, "kind": kind, "rot": rpl.randf() * TAU, "c": rpl.randi_range(0, 2)})


## Creatures with abilities, placed by habit: Cinder Hogs doze by the fire vents, Pounce Toads
## sit by the pools, Gale Puffs live beside a vent or a pool (and blow sprigs into it),
## Shellbacks and Hollow Moles have the open field. Counts from world.json "beasts".
static func _beasts(w: SimWorld) -> void:
	var r := Rng.stream(w.seed_str() + ":beasts")
	var vents: Array[Dictionary] = []
	var pools: Array[Dictionary] = []
	for z: Entities.HazardZone in w.hazards:
		if _in_reserved(w, z.pos):
			continue
		if z.hazard_id == "fire":
			vents.append({"pos": z.pos, "r": z.radius})
		elif z.hazard_id == "water":
			pools.append({"pos": z.pos, "r": z.radius})
	var both: Array[Dictionary] = []
	for i: int in maxi(vents.size(), pools.size()):
		if i < vents.size():
			both.append(vents[i])
		if i < pools.size():
			both.append(pools[i])
	var placed: Array[Vector3] = []
	var plan: Array = [["cinder_hog", vents], ["pounce_toad", pools], ["gale_puff", both], ["shellback", []], ["hollow_mole", []]]
	for row: Array in plan:
		var kind: String = row[0]
		var homes: Array[Dictionary] = []
		homes.assign(row[1])
		var n: int = w.content.wi_in("beasts", kind, 0)
		for i: int in n:
			var p: Vector3
			if i < homes.size():
				var h: Dictionary = homes[i]
				var c: Vector3 = h["pos"]
				var ang: float = r.randf() * TAU
				p = w.push_out(c + Vector3(sin(ang), 0.0, cos(ang)) * (float(h["r"]) + 2.0 + r.randf() * 2.0), 1.0)
			else:
				p = _open_spot(w, r, 36.0, w.field.bound - 10.0)
				for tries: int in 12:
					var ok: bool = true
					for q: Vector3 in placed:
						if SimWorld.flat_dist(p, q) < 14.0:
							ok = false
							break
					if ok:
						break
					p = _open_spot(w, r, 36.0, w.field.bound - 10.0)
			placed.append(p)
			var e: Entities.Enemy = w.spawn_enemy(kind, p, "beast:%s:%d" % [kind, i])
			e.yaw = r.randf() * TAU


static func _in_reserved(w: SimWorld, p: Vector3) -> bool:
	for rs: Dictionary in w.reserved:
		var c: Vector3 = rs["pos"]
		if SimWorld.flat_dist(p, c) < float(rs["r"]):
			return true
	return false


static func _pocket(w: SimWorld, rgate: Rng, gate_ang: float, dist: float, gi: int) -> void:
	var pocket_c: Vector3 = w.ground(Vector3(sin(gate_ang), 0.0, cos(gate_ang)) * dist)
	var toward_hold: Vector3 = (w.hold.pos - pocket_c)
	toward_hold.y = 0.0
	toward_hold = toward_hold.normalized()
	var g := Entities.Gate.new()
	g.id = w.new_id()
	g.pos = w.ground(pocket_c + toward_hold * 7.0)
	g.yaw = atan2(toward_hold.z, toward_hold.x) + PI * 0.5
	g.width = 4.6
	g.hp = 420.0
	g.max_hp = g.hp
	g.seed_id = "gate:%d" % (gi + 1)
	w.gates.append(g)
	var gate_dir_ang: float = atan2(toward_hold.x, toward_hold.z)
	for i: int in 9:
		var ang: float = gate_dir_ang + (float(i + 1) / 10.0) * TAU
		var sp: Vector3 = pocket_c + Vector3(sin(ang), 0.0, cos(ang)) * 7.0
		var d: float = absf(wrapf(ang - gate_dir_ang, -PI, PI))
		if d < 0.42:
			continue
		w.obstacles.append({"pos": w.ground(sp), "r": 1.6, "h": 2.4 + rgate.randf() * 0.8})
	if gi == 0:
		w.spawn_object("relic_key", pocket_c + Vector3(1.4, 0.0, 0.8), "pocket:key")
		w.spawn_object("heartroot", pocket_c + Vector3(-1.8, 0.0, -1.2), "pocket:heartroot")
	else:
		w.spawn_object("heartroot", pocket_c + Vector3(1.2, 0.0, 0.6), "pocket:%d:heartroot" % gi)
		w.spawn_object("pellet_20", pocket_c + Vector3(-1.6, 0.0, -1.0), "pocket:%d:pellet" % gi, "stone")


## The ring of territories: one per row in regions.json, evenly round the field from a seeded
## start angle. Their ground is reserved before anything else is placed.
static func _reserve_regions(w: SimWorld) -> Array[Vector3]:
	var cfg: Dictionary = w.content.regions
	var rows: Array = cfg.get("regions", [])
	var dist: float = minf(float(cfg.get("ring_distance", 122.0)), w.field.bound - float(cfg.get("radius", 18.0)) - 4.0)
	var rad: float = float(cfg.get("radius", 18.0))
	var r := Rng.stream(w.seed_str() + ":regions")
	var a0: float = r.randf() * TAU
	var out: Array[Vector3] = []
	for i: int in rows.size():
		var row: Dictionary = rows[i]
		var a: float = a0 + float(i) / float(rows.size()) * TAU
		var c: Vector3 = w.ground(w.hold.pos + Vector3(sin(a), 0.0, cos(a)) * dist)
		w.reserved.append({"pos": c, "r": rad + 2.0})
		w.regions.append({"id": str(row["id"]), "name": str(row["name"]), "type": str(row["type"]), "pos": c, "radius": rad, "line": str(row.get("line", ""))})
		out.append(c)
	return out


static func _zone(w: SimWorld, hazard_id: String, p: Vector3, radius: float) -> void:
	if hazard_id == "water":
		w.field.add_basin(p.x, p.z, radius) # the ground dips under the water
	var z := Entities.HazardZone.new()
	z.id = w.new_id()
	z.hazard_id = hazard_id
	z.pos = w.ground(p)
	z.radius = radius
	w.hazards.append(z)
	if hazard_id == "water":
		w.nav_blockers.append({"pos": z.pos, "r": radius + 0.4})


## One territory: the type's shrine with sprouts at its foot on the Hold side, a landmark stone,
## and the puzzle on the far side with its rewards.
static func _build_region(w: SimWorld, i: int, c: Vector3) -> void:
	var cfg: Dictionary = w.content.regions
	var row: Dictionary = (cfg["regions"] as Array)[i]
	var id: String = str(row["id"])
	var type_id: String = str(row["type"])
	var hz: String = str(row.get("hazard", ""))
	var r := Rng.stream("%s:region:%s" % [w.seed_str(), id])
	var toward: Vector3 = w.hold.pos - c
	toward.y = 0.0
	toward = toward.normalized()
	var side := Vector3(toward.z, 0.0, -toward.x)
	# shrine and sprouts
	var shrine_at: Vector3 = c + toward * 7.5
	w.spawn_shrine_object(type_id, shrine_at, "shrine:" + type_id)
	var n_sprouts: int = int(cfg.get("sprouts", 4))
	for k: int in n_sprouts:
		var a: float = float(k) / float(n_sprouts) * TAU + r.randf() * 0.4
		w.spawn_sprout(type_id, shrine_at + Vector3(sin(a), 0.0, cos(a)) * (1.7 + r.randf() * 0.9), Vector3.INF, 0)
	w.landmarks.append({"pos": w.ground(c + toward * 11.0 + side * 3.5), "type": type_id})
	# the puzzle
	var pc: Vector3 = c - toward * 3.0
	var rewards: Array[Vector3] = []
	match str(row.get("layout", "open")):
		"pools":
			var spots: Array[Vector3] = [pc, pc + side * 6.8, pc - side * 6.2]
			var radii: Array[float] = [4.2, 3.4, 3.0]
			for k: int in 3:
				_zone(w, hz, spots[k], radii[k])
			rewards = spots
		"ring":
			for k: int in 9:
				var a: float = float(k) / 9.0 * TAU
				_zone(w, hz, pc + Vector3(sin(a), 0.0, cos(a)) * 4.6, 1.95)
			rewards = [pc, pc + side * 1.2]
		"cluster":
			for k: int in 3:
				var a: float = float(k) / 3.0 * TAU
				_zone(w, hz, pc + Vector3(sin(a), 0.0, cos(a)) * 1.6, 2.8)
			rewards = [pc, pc + side * 1.1, pc - side * 1.1]
		"walls":
			for k: int in 13:
				var a: float = float(k) / 13.0 * TAU
				w.obstacles.append({"pos": w.ground(pc + Vector3(sin(a), 0.0, cos(a)) * 5.4), "r": 1.45, "h": 2.6 + r.randf() * 0.9})
			rewards = [pc, pc + side * 1.2]
		_:
			rewards = [pc, pc + side * 3.0]
	# rewards: the relic first, then pellets of the region's type, then a heartroot if any
	var ri: int = 0
	w.spawn_object(str(row["relic"]), rewards[ri % rewards.size()], "region:%s:relic" % id)
	ri += 1
	for k: int in int(row.get("pellets", 1)):
		var tid: String = "pellet_20" if str(row.get("layout", "")) == "open" else "pellet_10"
		w.spawn_object(tid, rewards[ri % rewards.size()] + Vector3(0.6, 0.0, 0.4) * float(ri / rewards.size()), "region:%s:pellet:%d" % [id, k], type_id)
		ri += 1
	if bool(row.get("heartroot", false)):
		w.spawn_object("heartroot", rewards[ri % rewards.size()] + Vector3(-0.6, 0.0, 0.5), "region:%s:heartroot" % id)
	var g: String = str(row.get("guardian", ""))
	if not g.is_empty():
		var e: Entities.Enemy = w.spawn_enemy(g, pc + side * 8.0 - toward * 2.0, "region:%s:guardian" % id)
		e.yaw = r.randf() * TAU


## The field's bigger furniture, all from one stream. Each piece is an entry in w.scenery for
## the view and one or more kind-tagged circles in w.obstacles for the sim and the navmesh.
## Old stumps with roots; fallen branches lying across the ground (a chain of circles);
## the kingdom's ruins (broken columns and runs of wall); giant mushrooms in clusters; and
## meadows of giant daisies on thin stems.
static func _scenery(w: SimWorld) -> void:
	var r := Rng.stream(w.seed_str() + ":scenery")
	var b: float = w.field.bound
	for i: int in 5:
		var p: Vector3 = _open_spot(w, r, 32.0, b - 14.0)
		var rad: float = 2.4 + r.randf() * 1.4
		var h: float = 1.5 + r.randf() * 1.3
		w.obstacles.append({"pos": p, "r": rad, "h": h, "kind": "stump"})
		w.scenery.append({"kind": "stump", "pos": p, "r": rad, "h": h, "rot": r.randf() * TAU})
	for i: int in 14:
		var a: Vector3 = _open_spot(w, r, 20.0, b - 10.0)
		var ang: float = r.randf() * TAU
		var length: float = 6.0 + r.randf() * 7.0
		var rad: float = 0.45 + r.randf() * 0.4
		var e: Vector3 = w.field.clamp_bound(a + Vector3(sin(ang), 0.0, cos(ang)) * length)
		if _in_reserved(w, e) or SimWorld.flat_dist(e, w.hold.pos) < 18.0 or _near_blocker(w, a, e, rad):
			continue
		var segs: int = int(ceilf(length / (rad * 1.3)))
		for k: int in segs + 1:
			var c: Vector3 = a.lerp(e, float(k) / float(segs))
			w.obstacles.append({"pos": w.ground(c), "r": rad, "h": rad * 2.0, "kind": "log"})
		w.scenery.append({"kind": "log", "a": w.ground(a), "b": w.ground(e), "r": rad, "rot": r.randf() * TAU})
	for i: int in 6:
		_ruin(w, r, _open_spot(w, r, 34.0, b - 16.0))
	for i: int in 11:
		var c: Vector3 = _open_spot(w, r, 16.0, b - 6.0)
		var n: int = 2 + r.randi_range(0, 2)
		for k: int in n:
			var ang: float = r.randf() * TAU
			var p: Vector3 = w.ground(c + Vector3(sin(ang), 0.0, cos(ang)) * (0.0 if k == 0 else 1.8 + r.randf() * 2.2))
			if w.blocked(p, 0.6):
				continue
			var stalk: float = 0.22 + r.randf() * 0.22
			var cap: float = stalk * 4.2 + r.randf() * 1.0
			var h: float = 1.6 + r.randf() * 2.4
			w.obstacles.append({"pos": p, "r": stalk + 0.1, "h": h, "kind": "mushroom"})
			w.scenery.append({"kind": "mushroom", "pos": p, "stalk": stalk, "cap": cap, "h": h, "tilt": (r.randf() - 0.5) * 0.3, "rot": r.randf() * TAU})
	for i: int in 9:
		var c: Vector3 = _open_spot(w, r, 18.0, b - 6.0)
		var col: int = r.randi_range(0, 2)
		for k: int in 5 + r.randi_range(0, 4):
			var ang: float = r.randf() * TAU
			var p: Vector3 = w.ground(c + Vector3(sin(ang), 0.0, cos(ang)) * (r.randf() * 5.0))
			if w.blocked(p, 0.5):
				continue
			var h: float = 3.0 + r.randf() * 3.5
			w.obstacles.append({"pos": p, "r": 0.22, "h": h, "kind": "daisy"})
			w.scenery.append({"kind": "daisy", "pos": p, "h": h, "bloom": 0.8 + r.randf() * 0.7, "c": col, "lean": Vector2(r.randf() - 0.5, r.randf() - 0.5) * 0.25, "rot": r.randf() * TAU})


## A ruin: the footprint of some small hall, its columns standing or broken, two or three runs of
## wall with gaps in them, moss on all of it.
static func _ruin(w: SimWorld, r: Rng, c: Vector3) -> void:
	var yaw: float = r.randf() * TAU
	var ax := Vector3(cos(yaw), 0.0, -sin(yaw))
	var az := Vector3(sin(yaw), 0.0, cos(yaw))
	var hw: float = 4.5 + r.randf() * 2.0
	var hd: float = 3.5 + r.randf() * 1.5
	var spots: Array[Vector3] = []
	for sx: float in [-1.0, 0.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			spots.append(c + ax * hw * sx + az * hd * sz)
	for p: Vector3 in spots:
		if r.randf() < 0.2:
			continue # this one fell long ago
		var g: Vector3 = w.ground(p)
		var broken: bool = r.randf() < 0.55
		var h: float = (0.8 + r.randf() * 1.6) if broken else (3.4 + r.randf() * 1.4)
		w.obstacles.append({"pos": g, "r": 0.55, "h": h, "kind": "column"})
		w.scenery.append({"kind": "column", "pos": g, "r": 0.5, "h": h, "broken": broken, "rot": r.randf() * TAU})
	# walls along the long sides, each run short of the corners so there are ways in
	for side: float in [-1.0, 1.0]:
		if r.randf() < 0.25:
			continue
		var from: float = -hw + 1.0 + r.randf() * 1.5
		var to: float = hw - 1.0 - r.randf() * 2.5
		if to - from < 2.0:
			continue
		var a: Vector3 = w.ground(c + az * hd * side + ax * from)
		var e: Vector3 = w.ground(c + az * hd * side + ax * to)
		var h: float = 0.9 + r.randf() * 1.4
		var segs: int = int(ceilf((to - from) / 0.6))
		for k: int in segs + 1:
			w.obstacles.append({"pos": w.ground(a.lerp(e, float(k) / float(segs))), "r": 0.42, "h": h, "kind": "wall"})
		w.scenery.append({"kind": "wall", "a": a, "b": e, "h": h, "t": 0.7})
	# a fallen block or two inside
	for k: int in r.randi_range(0, 2):
		var p: Vector3 = w.ground(c + ax * (r.randf() - 0.5) * hw + az * (r.randf() - 0.5) * hd)
		var s: float = 0.6 + r.randf() * 0.5
		w.obstacles.append({"pos": p, "r": s, "h": s * 1.2, "kind": "block"})
		w.scenery.append({"kind": "block", "pos": p, "s": s, "rot": r.randf() * TAU})


## True if a segment a..b (with radius rad) would cross a pool or other nav blocker.
static func _near_blocker(w: SimWorld, a: Vector3, b: Vector3, rad: float) -> bool:
	for nb: Dictionary in w.nav_blockers:
		var c: Vector3 = nb["pos"]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var t: float = 0.0
		if ab.length_squared() > 0.0001:
			t = clampf(Vector2(c.x - a.x, c.z - a.z).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var q := Vector2(a.x, a.z) + ab * t
		if q.distance_to(Vector2(c.x, c.z)) < float(nb["r"]) + rad + 1.0:
			return true
	return false


static func _stones(w: SimWorld) -> void:
	var r := Rng.stream(w.seed_str() + ":stones")
	for i: int in 80:
		var p: Vector3 = _open_spot(w, r, 12.0, w.field.bound - 3.0)
		var rad: float = 0.7 + r.randf() * 1.6
		w.obstacles.append({"pos": w.ground(p), "r": rad, "h": 0.6 + r.randf() * 1.6})


## A point in the annulus [rmin, rmax] around the Hold that is not inside a stone, a pool, or
## (unless avoid_reserved is off) a region's ground.
static func open_spot(w: SimWorld, r: Rng, rmin: float, rmax: float, avoid_reserved: bool = true) -> Vector3:
	return _open_spot(w, r, rmin, rmax, avoid_reserved)


static func _open_spot(w: SimWorld, r: Rng, rmin: float, rmax: float, avoid_reserved: bool = true) -> Vector3:
	for attempt: int in 40:
		var ang: float = r.randf() * TAU
		var d: float = rmin + r.randf() * (rmax - rmin)
		var p: Vector3 = w.hold.pos + Vector3(sin(ang), 0.0, cos(ang)) * d
		p = w.field.clamp_bound(p)
		var clear: bool = not w.blocked(p, 1.2)
		if clear and avoid_reserved:
			for rs: Dictionary in w.reserved:
				var c: Vector3 = rs["pos"]
				if SimWorld.flat_dist(p, c) < float(rs["r"]):
					clear = false
					break
		if clear:
			for nb: Dictionary in w.nav_blockers:
				var c: Vector3 = nb["pos"]
				if SimWorld.flat_dist(p, c) < float(nb["r"]) + 1.0:
					clear = false
					break
		if clear:
			return w.ground(p)
	return w.ground(w.hold.pos + Vector3(rmin, 0.0, 0.0))
