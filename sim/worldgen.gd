## The field, rolled from the seed. Everything placed here carries a seed_id so the save can
## store only what changed (taken, felled, opened, rooted) and regenerate the rest.
##
## Owner verdict 2026-10-20: "more map, any direction, more randomness, campsites to relocate to,
## not so organised as a circle; trees, logs to travel through; it's too grasslandy; bosses."
## So: the far places (territories, boss arenas, campsites) are scattered anywhere in the square
## field with room between them, never on a ring; the ground is five biomes (see
## Heightfield.biome) and the scenery follows them: woodland has trees, hollow logs you walk
## through, stumps and mushrooms; rocky country has crags and outcrops; marsh has pools, reeds
## and lilies; old garden ground has flower pots (some tipped over, something inside), bricks
## and ruins; meadow has giant daisies and the odd lone tree.
class_name Worldgen
extends RefCounted

const CAMP_NAMES: PackedStringArray = ["Mossfall Camp", "Rootcellar Camp", "Kiln Camp", "Dewpond Camp", "Lantern Stump Camp", "Thistle Camp", "Old Gate Camp"]


static func _n(w: SimWorld, key: String, dflt: int) -> int:
	return w.content.wi_in("field", key, dflt)


static func populate(w: SimWorld) -> void:
	var ss: String = w.seed_str()
	var b: float = w.field.bound
	# home: the Ember shrine stands in the clearing; twelve sprouts wait at its foot
	var ember: Entities.Shrine = w.root_shrine("ember", Vector3(5.5, 0.0, -3.0))
	var r0 := Rng.stream(ss + ":start")
	for i: int in 12:
		var ang: float = float(i) / 12.0 * TAU + r0.randf() * 0.3
		var d: float = 1.5 + r0.randf() * 1.6
		w.spawn_sprout("ember", ember.pos + Vector3(sin(ang), 0.0, cos(ang)) * d, Vector3.INF, 1 if i < 4 else 0)
	w.camps.append({"id": "home", "name": "The Hold", "pos": w.ground(w.hold.pos)})
	w.reserved.append({"pos": w.hold.pos, "r": 30.0})
	# the far places claim their ground first, scattered anywhere with room between them
	_place_regions(w)
	_place_arenas(w)
	_place_camps(w)
	for i: int in w.regions.size():
		_build_region(w, i, w.regions[i]["pos"])
	for ar: Dictionary in w.arenas:
		_build_arena(w, ar)
	# water before anything solid, so nothing stands in a pool
	var rw := Rng.stream(ss + ":pools")
	for i: int in _n(w, "pools", 7):
		var p: Vector3 = _open_spot(w, rw, 26.0, b * 1.4)
		var rad: float = 3.2 + rw.randf() * 2.2
		if w.blocked_wide(p, rad + 0.5):
			continue
		_zone(w, "water", p, rad)
		w.spawn_object("pellet_10" if i % 2 == 0 else "relic_marble", p + Vector3(0.4, 0.0, 0.2), "pool:%d" % i, "ember")
	_marsh_water(w)
	_climate_hazards(w)
	# every basin and clearing is in: sample the ground once, read it back from here on
	w.field.bake_heights()
	# the furniture, biggest first, then the field's stones
	_climate_scenery(w)
	_scenery(w)
	_stones(w)
	# the Stone shrine waits in the field with a few sprouts of its own
	var stone_at: Vector3 = _open_spot(w, Rng.stream(ss + ":stone"), 32.0, 40.0)
	w.spawn_shrine_object("stone", stone_at, "shrine:stone")
	var r1 := Rng.stream(ss + ":stone-sprouts")
	for i: int in 5:
		var ang: float = float(i) / 5.0 * TAU + r1.randf() * 0.4
		w.spawn_sprout("stone", stone_at + Vector3(sin(ang), 0.0, cos(ang)) * (1.6 + r1.randf()), Vector3.INF, 0)
	# posies: pellet flowers that regrow on a clock
	var rpo := Rng.stream(ss + ":posies")
	for i: int in _n(w, "posies", 22):
		var p: Vector3 = _open_spot(w, rpo, 14.0, b * 1.4)
		var po: Entities.Posy = w.spawn_posy(p, "ember" if rpo.randf() < 0.6 else "stone", i)
		po.timer = 20.0 + rpo.randf() * 60.0
	# pellets scattered over the field
	var rp := Rng.stream(ss + ":pellets")
	for i: int in _n(w, "pellets", 110):
		var p: Vector3 = _open_spot(w, rp, 13.0, b * 1.4)
		var roll: float = rp.randf()
		var tid: String = "pellet_1" if roll < 0.6 else ("pellet_5" if roll < 0.9 else "pellet_10")
		var ptype: String = "ember" if rp.randf() < 0.65 else "stone"
		w.spawn_object(tid, p, "pellet:%d" % i, ptype)
	# relics in the open: a reason to go looking
	var rr := Rng.stream(ss + ":relics")
	w.spawn_object("relic_button", _open_spot(w, rr, 18.0, 50.0), "relic:button")
	w.spawn_object("relic_thimble", _open_spot(w, rr, 50.0, 100.0), "relic:thimble")
	w.spawn_object("relic_coin", _open_spot(w, rr, 80.0, 160.0), "relic:coin")
	w.spawn_object("relic_bead", _open_spot(w, rr, 30.0, 120.0), "relic:bead")
	w.spawn_object("relic_bottlecap", _open_spot(w, rr, 100.0, b * 1.4), "relic:bottlecap")
	# grubs asleep in the open, each with pellets at its feet
	var rg := Rng.stream(ss + ":grubs")
	var placed: Array[Vector3] = []
	var tries: int = 0
	while placed.size() < _n(w, "grubs", 12) and tries < 240:
		tries += 1
		var p: Vector3 = _open_spot(w, rg, 26.0, b * 1.4)
		var ok: bool = true
		for q: Vector3 in placed:
			if SimWorld.flat_dist(p, q) < 18.0:
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
	for i: int in _n(w, "vents", 3):
		var vent_at: Vector3 = _open_spot(w, rv, 18.0 + float(i) * 40.0, 40.0 + float(i) * 70.0)
		var z := Entities.HazardZone.new()
		z.id = w.new_id()
		z.hazard_id = "fire"
		z.pos = w.ground(vent_at)
		z.radius = 2.2
		w.hazards.insert(i, z) # vents first: tests and the view index them that way
		w.spawn_object("pellet_10", vent_at + Vector3(0.4, 0.0, 0.3), "vent:%d:pellet" % i, "ember")
	# bramble gates and the pockets behind them: rings of stones with one way in
	var rgate := Rng.stream(ss + ":gate")
	for gi: int in _n(w, "pockets", 3):
		var c: Vector3 = _far_spot(w, rgate, 40.0 + float(gi) * 30.0, b * 1.4, 9.0, 6.0)
		w.reserved.append({"pos": c, "r": 9.0})
		_pocket(w, rgate, c, gi)
	# the beasts, each where its kind would live
	_beasts(w)
	# the day's first animals
	var rb := Rng.stream(ss + ":beetles")
	for i: int in w.content.wi_in("arrivals", "start_beetles", 4):
		var e: Entities.Enemy = w.spawn_enemy("field_beetle", _open_spot(w, rb, 14.0, b * 1.4), "beetle:%d" % i)
		e.state = Entities.Enemy.State.IDLE
	_plants(w)


## Small green scatter for the view only, never in the way, by biome: ferns and fallen leaves in
## the woods, tufts on the rocks, reeds and clover in the marsh, clover and flowers in the old
## garden, flowers and tufts in the meadow.
static func _plants(w: SimWorld) -> void:
	var rpl := Rng.stream(w.seed_str() + ":plants")
	for i: int in _n(w, "plants", 4200):
		var p: Vector3 = _open_spot(w, rpl, 6.0, w.field.bound * 1.4, false)
		var bw: Vector4 = w.field.biome(p.x, p.z)
		var cl: Vector3 = w.field.climate(p.x, p.z)
		var roll: float = rpl.randf()
		var kind: String = "tuft"
		if cl.x > 0.5:
			if roll < 0.55:
				continue # snow
			kind = "tuft"
		elif cl.y > 0.5:
			if roll < 0.65:
				continue # sand
			kind = "tuft" if roll < 0.9 else "stalk"
		elif cl.z > 0.5:
			kind = "fern" if roll < 0.4 else ("flower" if roll < 0.6 else ("leaf" if roll < 0.85 else "stalk"))
		elif bw.x > 0.5:
			kind = "fern" if roll < 0.45 else ("leaf" if roll < 0.8 else "stalk")
		elif bw.y > 0.5:
			if roll < 0.5:
				continue # bare rock
			kind = "tuft"
		elif bw.z > 0.5:
			kind = "stalk" if roll < 0.5 else ("clover" if roll < 0.85 else "tuft")
		elif bw.w > 0.5:
			kind = "clover" if roll < 0.4 else ("flower" if roll < 0.75 else "leaf")
		else:
			var meadow: float = w.field.noise2(p.x * 0.035 - 40.0, p.z * 0.035 + 12.0)
			if meadow > 0.52 and roll < 0.5:
				kind = "flower"
			elif roll < 0.25:
				kind = "stalk"
			elif roll < 0.45:
				kind = "leaf"
			elif roll < 0.8:
				kind = "tuft"
			else:
				kind = "clover"
		w.plants.append({"pos": w.ground(p), "s": 0.5 + rpl.randf() * 1.3, "kind": kind, "rot": rpl.randf() * TAU, "c": rpl.randi_range(0, 2)})


## A spot anywhere in the square field (not a ring round the Hold): rmin..rmax from the Hold,
## my_r clear of the field's edge, and gap clear of every reserved place's own radius.
static func _far_spot(w: SimWorld, r: Rng, rmin: float, rmax: float, my_r: float, gap: float) -> Vector3:
	var b: float = w.field.bound
	for pass_i: int in 3:
		var g: float = gap * (1.0 - 0.4 * float(pass_i))
		for attempt: int in 300:
			var p := Vector3((r.randf() * 2.0 - 1.0) * (b - my_r - 4.0), 0.0, (r.randf() * 2.0 - 1.0) * (b - my_r - 4.0))
			var d: float = SimWorld.flat_dist(p, w.hold.pos)
			if d < rmin or d > rmax:
				continue
			var ok: bool = true
			for rs: Dictionary in w.reserved:
				if SimWorld.flat_dist(p, rs["pos"]) < float(rs["r"]) + my_r + g:
					ok = false
					break
			if ok:
				return w.ground(p)
	return w.ground(Vector3(rmin, 0.0, 0.0))


static func _place_regions(w: SimWorld) -> void:
	var cfg: Dictionary = w.content.regions
	var rows: Array = cfg.get("regions", [])
	var rad: float = float(cfg.get("radius", 18.0))
	var r := Rng.stream(w.seed_str() + ":regions")
	for i: int in rows.size():
		var row: Dictionary = rows[i]
		var c: Vector3 = _far_spot(w, r, 70.0, w.field.bound * 1.42, rad + 2.0, 30.0)
		w.reserved.append({"pos": c, "r": rad + 2.0})
		w.regions.append({"id": str(row["id"]), "name": str(row["name"]), "type": str(row["type"]), "pos": c, "radius": rad, "line": str(row.get("line", ""))})


## Boss arenas: a levelled clearing ringed by great stones with three ways in.
static func _place_arenas(w: SimWorld) -> void:
	var rows: Array = w.content.world.get("arenas", [])
	var r := Rng.stream(w.seed_str() + ":arenas")
	for i: int in rows.size():
		var row: Dictionary = rows[i]
		var c: Vector3 = _far_spot(w, r, 110.0, w.field.bound * 1.42, 24.0, 22.0)
		w.field.add_clearing(c.x, c.z, 16.0)
		c = w.ground(c)
		w.reserved.append({"pos": c, "r": 24.0})
		w.arenas.append({"id": "arena:%d" % i, "name": str(row["name"]), "pos": c, "radius": 15.0, "boss": str(row["boss"]), "relic": str(row["relic"])})


## Campsites the Hold can move to: levelled clearings, scattered.
static func _place_camps(w: SimWorld) -> void:
	var r := Rng.stream(w.seed_str() + ":camps")
	for i: int in _n(w, "camps", 5):
		var c: Vector3 = _far_spot(w, r, 60.0, w.field.bound * 1.42, 14.0, 26.0)
		w.field.add_clearing(c.x, c.z, 10.0)
		c = w.ground(c)
		w.reserved.append({"pos": c, "r": 14.0})
		w.camps.append({"id": "camp:%d" % i, "name": CAMP_NAMES[i % CAMP_NAMES.size()], "pos": c})


static func _build_arena(w: SimWorld, ar: Dictionary) -> void:
	var id: String = ar["id"]
	var r := Rng.stream("%s:%s" % [w.seed_str(), id])
	var c: Vector3 = ar["pos"]
	var rad: float = float(ar["radius"])
	var gaps: Array[float] = []
	var g0: float = r.randf() * TAU
	for k: int in 3:
		gaps.append(g0 + float(k) * TAU / 3.0 + (r.randf() - 0.5) * 0.5)
	for k: int in 30:
		var a: float = float(k) / 30.0 * TAU
		var open: bool = false
		for g: float in gaps:
			if absf(wrapf(a - g, -PI, PI)) < 0.28:
				open = true
		if open:
			continue
		var rr: float = 1.4 + r.randf() * 0.9
		w.obstacles.append({"pos": w.ground(c + Vector3(sin(a), 0.0, cos(a)) * (rad + 1.5)), "r": rr, "h": 2.6 + r.randf() * 3.0})
	var e: Entities.Enemy = w.spawn_enemy(str(ar["boss"]), c, "boss:" + id)
	e.yaw = r.randf() * TAU
	var ra: float = r.randf() * TAU
	w.spawn_object(str(ar["relic"]), c + Vector3(sin(ra), 0.0, cos(ra)) * (rad - 4.0), id + ":relic")
	w.spawn_object("heartroot", c - Vector3(sin(ra), 0.0, cos(ra)) * (rad - 4.0), id + ":heartroot")


## Marsh water: small pools where the marsh is thickest, lilies on them.
static func _marsh_water(w: SimWorld) -> void:
	var r := Rng.stream(w.seed_str() + ":marsh")
	for i: int in _n(w, "marsh_pools", 10):
		var p: Vector3 = _biome_spot(w, r, 2, 0.55, 24.0, 1.0)
		if p == Vector3.INF:
			continue
		var rad: float = 2.4 + r.randf() * 2.4
		if w.blocked_wide(p, rad + 0.6):
			continue
		_zone(w, "water", p, rad)
		w.scenery.append({"kind": "lily", "pos": p, "r": rad, "rot": r.randf() * TAU})


## A spot where the far climate idx (0 arctic, 1 desert, 2 jungle) is at least min_w.
static func _climate_spot(w: SimWorld, r: Rng, idx: int, min_w: float, margin: float) -> Vector3:
	for t: int in 50:
		var p: Vector3 = _open_spot(w, r, 50.0, w.field.bound * 1.42)
		var cl: Vector3 = w.field.climate(p.x, p.z)
		if cl[idx] >= min_w and not w.blocked_wide(p, margin):
			return p
	return Vector3.INF


## Each far climate brings its own trouble, and the sprig that shrugs it off: ice fields in the
## arctic (Frost), hot vents in the desert (Ember), spore clouds in the jungle (Thorn). Each holds
## a fat pellet, so the right sprig has a reason to go in.
static func _climate_hazards(w: SimWorld) -> void:
	var r := Rng.stream(w.seed_str() + ":climate-hazards")
	var plan: Array = [[0, "freeze", _n(w, "ice_fields", 7), 3.0, 5.5], [1, "fire", _n(w, "hot_vents", 6), 2.0, 2.6], [2, "poison", _n(w, "spore_clouds", 6), 2.4, 3.4]]
	for row: Array in plan:
		var idx: int = row[0]
		var hz: String = row[1]
		for i: int in int(row[2]):
			var p: Vector3 = _climate_spot(w, r, idx, 0.55, 6.0)
			if p == Vector3.INF:
				continue
			var rad: float = float(row[3]) + r.randf() * (float(row[4]) - float(row[3]))
			_zone(w, hz, p, rad)
			w.spawn_object("pellet_10", p + Vector3(0.3, 0.0, -0.2), "%s:%d" % [hz, i], ["frost", "ember", "thorn"][idx])


## The far climates' furniture. Arctic: snowy pines and ice crags. Desert: cacti, sandstone
## pillars and the bones of something huge you can walk through. Jungle: tall trees with broad
## crowns and hanging vines, giant leaves, and mossy boulders.
static func _climate_scenery(w: SimWorld) -> void:
	var r := Rng.stream(w.seed_str() + ":climate")
	for i: int in _n(w, "pines", 70):
		var p: Vector3 = _climate_spot(w, r, 0, 0.4, 2.6)
		if p == Vector3.INF:
			continue
		var rad: float = 0.9 + r.randf() * 0.8
		w.obstacles.append({"pos": p, "r": rad, "h": 10.0, "kind": "pine"})
		w.scenery.append({"kind": "pine", "pos": p, "r": rad, "h": 9.0 + r.randf() * 7.0, "rot": r.randf() * TAU})
	for i: int in _n(w, "ice_crags", 18):
		var p: Vector3 = _climate_spot(w, r, 0, 0.5, 3.0)
		if p == Vector3.INF:
			continue
		w.obstacles.append({"pos": p, "r": 1.6 + r.randf() * 1.6, "h": 3.0 + r.randf() * 5.0})
	for i: int in _n(w, "cacti", 45):
		var p: Vector3 = _climate_spot(w, r, 1, 0.45, 1.6)
		if p == Vector3.INF:
			continue
		var rad: float = 0.45 + r.randf() * 0.4
		w.obstacles.append({"pos": p, "r": rad, "h": 5.0, "kind": "cactus"})
		w.scenery.append({"kind": "cactus", "pos": p, "r": rad, "h": 2.8 + r.randf() * 3.5, "arms": r.randi_range(0, 3), "rot": r.randf() * TAU})
	for i: int in _n(w, "sandstone", 20):
		var p: Vector3 = _climate_spot(w, r, 1, 0.5, 3.2)
		if p == Vector3.INF:
			continue
		w.obstacles.append({"pos": p, "r": 2.0 + r.randf() * 1.6, "h": 4.0 + r.randf() * 6.0})
	var bone_i: int = 0
	for i: int in _n(w, "skeletons", 4):
		var a: Vector3 = _climate_spot(w, r, 1, 0.5, 2.0)
		if a == Vector3.INF:
			continue
		if _ribs(w, r, a, r.randf() * TAU, "bones:%d" % bone_i):
			bone_i += 1
	for i: int in _n(w, "jungle_trees", 75):
		var p: Vector3 = _climate_spot(w, r, 2, 0.4, 3.0)
		if p == Vector3.INF:
			continue
		var rad: float = 1.0 + r.randf() * 1.0
		w.obstacles.append({"pos": p, "r": rad, "h": 14.0, "kind": "jungle_tree"})
		w.scenery.append({"kind": "jungle_tree", "pos": p, "r": rad, "h": 14.0 + r.randf() * 8.0, "crown": 7.0 + r.randf() * 4.0, "vines": 3 + r.randi_range(0, 4), "rot": r.randf() * TAU})
	for i: int in _n(w, "big_leaves", 60):
		var p: Vector3 = _climate_spot(w, r, 2, 0.35, 1.2)
		if p == Vector3.INF:
			continue
		w.obstacles.append({"pos": p, "r": 0.35, "h": 2.5, "kind": "bigleaf"})
		w.scenery.append({"kind": "bigleaf", "pos": p, "n": 3 + r.randi_range(0, 3), "s": 1.6 + r.randf() * 1.6, "rot": r.randf() * TAU})
	for i: int in _n(w, "mossy_boulders", 18):
		var p: Vector3 = _climate_spot(w, r, 2, 0.45, 2.6)
		if p == Vector3.INF:
			continue
		w.obstacles.append({"pos": p, "r": 1.5 + r.randf() * 1.5, "h": 2.0 + r.randf() * 2.5})


## The ribs of some enormous dead thing, arching over the sand: walk in at the skull end, out
## at the tail. Two rows of rib-ends for the sim, the arch for the view.
static func _ribs(w: SimWorld, r: Rng, a: Vector3, ang: float, seed_id: String) -> bool:
	var b: float = w.field.bound
	var dir := Vector3(sin(ang), 0.0, cos(ang))
	var length: float = 12.0 + r.randf() * 6.0
	var e: Vector3 = a + dir * length
	if absf(e.x) > b - 4.0 or absf(e.z) > b - 4.0 or _in_reserved(w, e) or _near_blocker(w, a, e, 3.0):
		return false
	for k: int in 5:
		if w.blocked_wide(a.lerp(e, float(k) / 4.0), 3.6):
			return false
	var side := Vector3(dir.z, 0.0, -dir.x)
	var half: float = 2.6 + r.randf() * 0.6
	var n: int = 7 + r.randi_range(0, 3)
	for k: int in n:
		var q: Vector3 = a.lerp(e, (float(k) + 0.5) / float(n))
		for s: float in [-1.0, 1.0]:
			w.obstacles.append({"pos": w.ground(q + side * s * half), "r": 0.35, "h": 4.0, "kind": "rib"})
	w.scenery.append({"kind": "ribs", "a": w.ground(a), "b": w.ground(e), "half": half, "n": n})
	w.spawn_object("relic_bead" if r.randf() < 0.5 else "pellet_20", a.lerp(e, 0.5), seed_id, "ember")
	return true


## A spot where biome idx (0 wood, 1 rock, 2 marsh, 3 garden; -1 meadow) has at least min_w,
## clear of obstacles by margin. INF if none turns up.
static func _biome_spot(w: SimWorld, r: Rng, idx: int, min_w: float, rmin: float, margin: float) -> Vector3:
	for t: int in 40:
		var p: Vector3 = _open_spot(w, r, rmin, w.field.bound * 1.42)
		var bw: Vector4 = w.field.biome(p.x, p.z)
		var weight: float
		if idx < 0:
			weight = 1.0 - clampf(bw.x + bw.y + bw.z + bw.w, 0.0, 1.0)
		else:
			weight = bw[idx]
		if weight >= min_w and not w.blocked_wide(p, margin):
			return p
	return Vector3.INF


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
				p = _open_spot(w, r, 36.0, w.field.bound * 1.4)
				for tries: int in 12:
					var ok: bool = true
					for q: Vector3 in placed:
						if SimWorld.flat_dist(p, q) < 14.0:
							ok = false
							break
					if ok:
						break
					p = _open_spot(w, r, 36.0, w.field.bound * 1.4)
			placed.append(p)
			var e: Entities.Enemy = w.spawn_enemy(kind, p, "beast:%s:%d" % [kind, i])
			e.yaw = r.randf() * TAU


static func _in_reserved(w: SimWorld, p: Vector3) -> bool:
	for rs: Dictionary in w.reserved:
		var c: Vector3 = rs["pos"]
		if SimWorld.flat_dist(p, c) < float(rs["r"]):
			return true
	return false


static func _pocket(w: SimWorld, rgate: Rng, pocket_c: Vector3, gi: int) -> void:
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


## The field's furniture, all from one stream, biggest first so the big pieces get their room.
## Each piece is an entry in w.scenery for the view and kind-tagged circles in w.obstacles for
## the sim and the navmesh.
static func _scenery(w: SimWorld) -> void:
	var r := Rng.stream(w.seed_str() + ":scenery")
	var b: float = w.field.bound
	# woodland: great trees, their trunks the pillars of the place
	for i: int in _n(w, "trees", 80):
		var p: Vector3 = _biome_spot(w, r, 0, 0.4, 22.0, 3.2)
		if p == Vector3.INF:
			continue
		_tree(w, r, p)
	# and a few lone trees out in the meadow
	for i: int in _n(w, "lone_trees", 10):
		var p: Vector3 = _biome_spot(w, r, -1, 0.7, 30.0, 4.0)
		if p != Vector3.INF:
			_tree(w, r, p)
	# hollow logs lying in the woods: walk in one end and out the other
	var hollow_i: int = 0
	for i: int in _n(w, "hollow_logs", 18) * 5:
		if hollow_i >= _n(w, "hollow_logs", 18):
			break
		# woodland mostly, and the jungle's floor
		var a: Vector3 = _biome_spot(w, r, 0, 0.25, 24.0, 1.0) if i % 3 != 2 else _climate_spot(w, r, 2, 0.4, 1.0)
		if a == Vector3.INF:
			continue
		var ang: float = r.randf() * TAU
		var length: float = 10.0 + r.randf() * 5.0
		var rad: float = 1.5 + r.randf() * 0.5
		if _tube(w, r, a, ang, length, rad, false, "hollow:%d" % hollow_i):
			hollow_i += 1
	# rocky country: crags and outcrops
	for i: int in _n(w, "crags", 14):
		var p: Vector3 = _biome_spot(w, r, 1, 0.45, 28.0, 3.4)
		if p == Vector3.INF:
			continue
		w.obstacles.append({"pos": p, "r": 2.2 + r.randf() * 1.0, "h": 6.0 + r.randf() * 4.0})
	for i: int in _n(w, "outcrops", 30):
		var c: Vector3 = _biome_spot(w, r, 1, 0.3, 24.0, 2.0)
		if c == Vector3.INF:
			continue
		for k: int in 3 + r.randi_range(0, 3):
			var ang: float = r.randf() * TAU
			var p: Vector3 = w.ground(c + Vector3(sin(ang), 0.0, cos(ang)) * (r.randf() * 4.5))
			var rad: float = 1.2 + r.randf() * 1.8
			if not w.blocked_wide(p, rad + 0.2):
				w.obstacles.append({"pos": p, "r": rad, "h": 1.6 + r.randf() * 3.4})
	# the old garden: flower pots (some tipped over, something inside), bricks, ruins
	for i: int in _n(w, "pots", 16):
		var p: Vector3 = _biome_spot(w, r, 3, 0.35, 26.0, 3.0)
		if p == Vector3.INF:
			continue
		var rad: float = 1.6 + r.randf() * 0.8
		var h: float = 2.4 + r.randf() * 1.2
		w.obstacles.append({"pos": p, "r": rad, "h": h, "kind": "pot"})
		w.scenery.append({"kind": "pot", "pos": p, "r": rad, "h": h, "rot": r.randf() * TAU})
	var pot_i: int = 0
	for i: int in _n(w, "tipped_pots", 10) * 4:
		if pot_i >= _n(w, "tipped_pots", 10):
			break
		var a: Vector3 = _biome_spot(w, r, 3, 0.25, 26.0, 1.0)
		if a == Vector3.INF:
			continue
		if _tube(w, r, a, r.randf() * TAU, 3.4 + r.randf() * 1.2, 1.5 + r.randf() * 0.4, true, "pot:%d" % pot_i):
			pot_i += 1
	for i: int in _n(w, "bricks", 14):
		var c: Vector3 = _biome_spot(w, r, 3, 0.25, 22.0, 1.6)
		if c == Vector3.INF:
			continue
		var yaw: float = r.randf() * TAU
		var n: int = 2 + r.randi_range(0, 3)
		w.scenery.append({"kind": "bricks", "pos": c, "rot": yaw, "n": n})
		var ax := Vector3(cos(yaw), 0.0, -sin(yaw))
		for k: int in n:
			w.obstacles.append({"pos": w.ground(c + ax * (float(k % 3) - 1.0) * 1.0), "r": 0.75, "h": 0.8 * float(1 + k / 3), "kind": "brick"})
	for i: int in _n(w, "ruins", 9):
		var c: Vector3 = _biome_spot(w, r, 3, 0.2, 34.0, 1.6)
		if c == Vector3.INF:
			c = _open_spot(w, r, 34.0, b * 1.4)
		_ruin(w, r, c)
	# woods and wet ground: stumps, fallen branches, giant mushrooms
	for i: int in _n(w, "stumps", 10):
		var p: Vector3 = _biome_spot(w, r, 0, 0.15, 30.0, 3.0)
		if p == Vector3.INF:
			continue
		var rad: float = 2.4 + r.randf() * 1.4
		var h: float = 1.5 + r.randf() * 1.3
		w.obstacles.append({"pos": p, "r": rad, "h": h, "kind": "stump"})
		w.scenery.append({"kind": "stump", "pos": p, "r": rad, "h": h, "rot": r.randf() * TAU})
	for i: int in _n(w, "logs", 22):
		var a: Vector3 = _biome_spot(w, r, 0, 0.15, 20.0, 1.0) if i % 3 != 2 else _open_spot(w, r, 20.0, b * 1.4)
		if a == Vector3.INF:
			continue
		var ang: float = r.randf() * TAU
		var length: float = 6.0 + r.randf() * 7.0
		var rad: float = 0.45 + r.randf() * 0.4
		var e: Vector3 = a + Vector3(sin(ang), 0.0, cos(ang)) * length
		if absf(e.x) > b - 3.0 or absf(e.z) > b - 3.0 or _in_reserved(w, e) or _near_blocker(w, a, e, rad) or w.blocked_wide(e, rad + 0.6):
			continue
		var segs: int = int(ceilf(length / (rad * 1.3)))
		for k: int in segs + 1:
			var c: Vector3 = a.lerp(e, float(k) / float(segs))
			w.obstacles.append({"pos": w.ground(c), "r": rad, "h": rad * 2.0, "kind": "log"})
		w.scenery.append({"kind": "log", "a": w.ground(a), "b": w.ground(e), "r": rad, "rot": r.randf() * TAU})
	for i: int in _n(w, "mushrooms", 20):
		var c: Vector3 = _biome_spot(w, r, 0 if i % 3 != 2 else 2, 0.2, 16.0, 1.0)
		if c == Vector3.INF:
			continue
		for k: int in 2 + r.randi_range(0, 2):
			var ang: float = r.randf() * TAU
			var p: Vector3 = w.ground(c + Vector3(sin(ang), 0.0, cos(ang)) * (0.0 if k == 0 else 1.8 + r.randf() * 2.2))
			if w.blocked(p, 0.6):
				continue
			var stalk: float = 0.22 + r.randf() * 0.22
			var cap: float = stalk * 4.2 + r.randf() * 1.0
			var h: float = 1.6 + r.randf() * 2.4
			w.obstacles.append({"pos": p, "r": stalk + 0.1, "h": h, "kind": "mushroom"})
			w.scenery.append({"kind": "mushroom", "pos": p, "stalk": stalk, "cap": cap, "h": h, "tilt": (r.randf() - 0.5) * 0.3, "rot": r.randf() * TAU})
	# meadows of giant daisies
	for i: int in _n(w, "daisy_meadows", 14):
		var c: Vector3 = _biome_spot(w, r, -1, 0.6, 18.0, 1.0)
		if c == Vector3.INF:
			continue
		var col: int = r.randi_range(0, 2)
		for k: int in 5 + r.randi_range(0, 4):
			var ang: float = r.randf() * TAU
			var p: Vector3 = w.ground(c + Vector3(sin(ang), 0.0, cos(ang)) * (r.randf() * 5.0))
			if w.blocked(p, 0.5):
				continue
			var h: float = 3.0 + r.randf() * 3.5
			w.obstacles.append({"pos": p, "r": 0.22, "h": h, "kind": "daisy"})
			w.scenery.append({"kind": "daisy", "pos": p, "h": h, "bloom": 0.8 + r.randf() * 0.7, "c": col, "lean": Vector2(r.randf() - 0.5, r.randf() - 0.5) * 0.25, "rot": r.randf() * TAU})
	# reeds in the marsh: the view's only, sprigs push through them
	for i: int in _n(w, "reeds", 50):
		var p: Vector3 = _biome_spot(w, r, 2, 0.3, 16.0, 0.4)
		if p == Vector3.INF:
			continue
		w.scenery.append({"kind": "reeds", "pos": p, "n": 6 + r.randi_range(0, 8), "h": 1.8 + r.randf() * 1.6, "rot": r.randf() * TAU})


## A great tree: one trunk the sim walks round, a crown high overhead for the view.
static func _tree(w: SimWorld, r: Rng, p: Vector3) -> void:
	var rad: float = 1.1 + r.randf() * 1.1
	w.obstacles.append({"pos": p, "r": rad, "h": 12.0, "kind": "tree"})
	w.scenery.append({"kind": "tree", "pos": p, "r": rad, "h": 12.0 + r.randf() * 8.0, "crown": 6.0 + r.randf() * 4.0, "rot": r.randf() * TAU})


## A tube lying on the ground you can walk through: a hollow log (open both ends) or a tipped
## flower pot (open one end, a fat pellet inside). Two rows of circles for its walls (and one
## across the back of a pot), the passage between them left clear for the navmesh. False if the
## ground there will not take it (off the field, in the way, too steep).
static func _tube(w: SimWorld, r: Rng, a: Vector3, ang: float, length: float, rad: float, closed: bool, seed_id: String) -> bool:
	var b: float = w.field.bound
	var dir := Vector3(sin(ang), 0.0, cos(ang))
	var e: Vector3 = a + dir * length
	if absf(e.x) > b - 3.0 or absf(e.z) > b - 3.0 or _in_reserved(w, e) or _near_blocker(w, a, e, rad):
		return false
	var lo: float = 1e9
	var hi: float = -1e9
	for k: int in 7:
		var q: Vector3 = a.lerp(e, float(k) / 6.0)
		if w.blocked_wide(q, rad + 0.6):
			return false
		var hgt: float = w.field.height_at(q.x, q.z)
		lo = minf(lo, hgt)
		hi = maxf(hi, hgt)
	if hi - lo > 1.0:
		return false
	var side := Vector3(dir.z, 0.0, -dir.x)
	var segs: int = int(ceilf(length / 0.7))
	var kind: String = "pot_tipped" if closed else "hollow"
	for k: int in segs + 1:
		var q: Vector3 = a.lerp(e, float(k) / float(segs))
		for s: float in [-1.0, 1.0]:
			w.obstacles.append({"pos": w.ground(q + side * s * (rad - 0.25)), "r": 0.42, "h": rad * 2.0, "kind": kind})
	if closed:
		for k: int in 5:
			var q: Vector3 = e + side * (float(k) / 4.0 - 0.5) * (rad * 1.6)
			w.obstacles.append({"pos": w.ground(q), "r": 0.42, "h": rad * 2.0, "kind": kind})
	w.scenery.append({"kind": kind, "a": w.ground(a), "b": w.ground(e), "r": rad, "y": hi})
	if closed or r.randf() < 0.5:
		w.spawn_object("pellet_10", a.lerp(e, 0.6), seed_id, "ember" if r.randf() < 0.6 else "stone")
	return true


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
	for i: int in _n(w, "stones", 170):
		var p: Vector3 = _open_spot(w, r, 12.0, w.field.bound * 1.4)
		var rad: float = 0.7 + r.randf() * 1.6
		w.obstacles.append({"pos": w.ground(p), "r": rad, "h": 0.6 + r.randf() * 1.6})


## A point at least rmin and roughly up to rmax from the Hold (a square, so the corners count),
## on the field, not inside a stone, a pool, or (unless avoid_reserved is off) a reserved place.
static func open_spot(w: SimWorld, r: Rng, rmin: float, rmax: float, avoid_reserved: bool = true) -> Vector3:
	return _open_spot(w, r, rmin, rmax, avoid_reserved)


static func _open_spot(w: SimWorld, r: Rng, rmin: float, rmax: float, avoid_reserved: bool = true) -> Vector3:
	var b: float = w.field.bound
	for attempt: int in 60:
		# anywhere in the square around the Hold out to rmax, kept on the field, at least rmin off
		var p: Vector3 = w.hold.pos + Vector3((r.randf() * 2.0 - 1.0) * rmax, 0.0, (r.randf() * 2.0 - 1.0) * rmax)
		if absf(p.x) > b - 2.0 or absf(p.z) > b - 2.0:
			continue
		if SimWorld.flat_dist(p, w.hold.pos) < rmin:
			continue
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
	return w.ground(w.field.clamp_bound(w.hold.pos + Vector3(rmin, 0.0, 0.0)))
