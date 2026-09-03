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
	# stones: the field's furniture and its walls
	_stones(w)
	# the Stone shrine waits in the field with a few sprouts of its own
	var stone_at: Vector3 = _open_spot(w, Rng.stream(ss + ":stone"), 22.0, 30.0)
	w.spawn_shrine_object("stone", stone_at, "shrine:stone")
	var r1 := Rng.stream(ss + ":stone-sprouts")
	for i: int in 5:
		var ang: float = float(i) / 5.0 * TAU + r1.randf() * 0.4
		w.spawn_sprout("stone", stone_at + Vector3(sin(ang), 0.0, cos(ang)) * (1.6 + r1.randf()), Vector3.INF, 0)
	# pellets scattered over the field
	var rp := Rng.stream(ss + ":pellets")
	for i: int in 26:
		var p: Vector3 = _open_spot(w, rp, 13.0, 64.0)
		var roll: float = rp.randf()
		var tid: String = "pellet_1" if roll < 0.6 else ("pellet_5" if roll < 0.9 else "pellet_10")
		var ptype: String = "ember" if rp.randf() < 0.65 else "stone"
		w.spawn_object(tid, p, "pellet:%d" % i, ptype)
	# relics in the open: a reason to go looking
	var rr := Rng.stream(ss + ":relics")
	w.spawn_object("relic_button", _open_spot(w, rr, 18.0, 40.0), "relic:button")
	w.spawn_object("relic_thimble", _open_spot(w, rr, 36.0, 60.0), "relic:thimble")
	# grubs asleep in the open, each with pellets at its feet
	var rg := Rng.stream(ss + ":grubs")
	var placed: Array[Vector3] = []
	var tries: int = 0
	while placed.size() < 3 and tries < 60:
		tries += 1
		var p: Vector3 = _open_spot(w, rg, 24.0, 56.0)
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
	# one fire vent with a fat pellet in the flames: Ember work
	var rv := Rng.stream(ss + ":vent")
	var vent_at: Vector3 = _open_spot(w, rv, 18.0, 34.0)
	var z := Entities.HazardZone.new()
	z.id = w.new_id()
	z.hazard_id = "fire"
	z.pos = w.ground(vent_at)
	z.radius = 2.2
	w.hazards.append(z)
	w.spawn_object("pellet_10", vent_at + Vector3(0.4, 0.0, 0.3), "vent:pellet", "ember")
	# the bramble gate and the pocket behind it: a ring of stones with one way in
	var rgate := Rng.stream(ss + ":gate")
	var gate_ang: float = rgate.randf() * TAU
	var pocket_c: Vector3 = w.ground(Vector3(sin(gate_ang), 0.0, cos(gate_ang)) * 44.0)
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
	g.seed_id = "gate:1"
	w.gates.append(g)
	var gate_dir_ang: float = atan2(toward_hold.x, toward_hold.z)
	for i: int in 9:
		var ang: float = gate_dir_ang + (float(i + 1) / 10.0) * TAU
		var sp: Vector3 = pocket_c + Vector3(sin(ang), 0.0, cos(ang)) * 7.0
		var d: float = absf(wrapf(ang - gate_dir_ang, -PI, PI))
		if d < 0.42:
			continue
		w.obstacles.append({"pos": w.ground(sp), "r": 1.6, "h": 2.4 + rgate.randf() * 0.8})
	w.spawn_object("relic_key", pocket_c + Vector3(1.4, 0.0, 0.8), "pocket:key")
	w.spawn_object("heartroot", pocket_c + Vector3(-1.8, 0.0, -1.2), "pocket:heartroot")
	# green scatter for the view only: leaves and stalks, never in the way
	var rpl := Rng.stream(ss + ":plants")
	for i: int in 260:
		var p: Vector3 = _open_spot(w, rpl, 6.0, w.field.bound - 2.0)
		w.plants.append({"pos": w.ground(p), "s": 0.5 + rpl.randf() * 1.3, "kind": "stalk" if rpl.randf() < 0.55 else "leaf", "rot": rpl.randf() * TAU})


static func _stones(w: SimWorld) -> void:
	var r := Rng.stream(w.seed_str() + ":stones")
	for i: int in 34:
		var p: Vector3 = _open_spot(w, r, 12.0, w.field.bound - 3.0)
		var rad: float = 0.7 + r.randf() * 1.6
		w.obstacles.append({"pos": w.ground(p), "r": rad, "h": 0.6 + r.randf() * 1.6})


## A point in the annulus [rmin, rmax] around the Hold that is not inside a stone.
static func _open_spot(w: SimWorld, r: Rng, rmin: float, rmax: float) -> Vector3:
	for attempt: int in 40:
		var ang: float = r.randf() * TAU
		var d: float = rmin + r.randf() * (rmax - rmin)
		var p: Vector3 = w.hold.pos + Vector3(sin(ang), 0.0, cos(ang)) * d
		p = w.field.clamp_bound(p)
		var clear: bool = true
		for ob: Dictionary in w.obstacles:
			var c: Vector3 = ob["pos"]
			if SimWorld.flat_dist(p, c) < float(ob["r"]) + 1.2:
				clear = false
				break
		if clear:
			return w.ground(p)
	return w.ground(w.hold.pos + Vector3(rmin, 0.0, 0.0))
