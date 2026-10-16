## World <-> document. Persist only what cannot be regenerated: the seed, what he changed
## (deltas), what accumulated (hold, sprigs, sprouts, shrines, knight, clock). Everything rolled
## from the seed comes back from Worldgen and the deltas are applied over it.
class_name Serialize
extends RefCounted


static func to_doc(w: SimWorld, now_unix: int) -> Dictionary:
	var sprigs: Array = []
	for s: Entities.Sprig in w.sprigs:
		if s.state == Entities.Sprig.State.DEAD:
			continue
		var st: String = "follow" if s.state == Entities.Sprig.State.FOLLOW else "idle"
		var p: Vector3 = s.pos
		if s.state == Entities.Sprig.State.THROWN:
			p = s.fl_end
		sprigs.append({"t": s.type_id, "x": snappedf(p.x, 0.01), "z": snappedf(p.z, 0.01), "m": s.maturity, "st": st})
	var sprouts: Array = []
	for sp: Entities.Sprout in w.sprouts:
		sprouts.append({"t": sp.type_id, "x": snappedf(sp.pos.x, 0.01), "z": snappedf(sp.pos.z, 0.01), "age": snappedf(sp.age, 0.1), "m": sp.maturity})
	var shrines: Array = []
	for sh: Entities.Shrine in w.shrines:
		shrines.append({"t": sh.type_id, "x": snappedf(sh.pos.x, 0.01), "z": snappedf(sh.pos.z, 0.01)})
	var h: Hold = w.hold
	var queue: Array = []
	for q: Dictionary in h.queue:
		queue.append({"type": q["type"], "count": int(q["count"])})
	var deltas: Dictionary = {}
	for k: String in ["taken", "felled", "opened", "rooted"]:
		var arr: PackedStringArray = w.deltas[k]
		deltas[k] = Array(arr)
	return {
		"schemaVersion": Migrate.CURRENT,
		"key": Migrate.KEY,
		"name": "Briarhold",
		"seed": w.seed,
		"saved_at": now_unix,
		"day": w.clock.day,
		"clock_time": snappedf(w.clock.time, 0.01),
		"knight": {"x": snappedf(w.knight.pos.x, 0.01), "z": snappedf(w.knight.pos.z, 0.01), "yaw": snappedf(w.knight.yaw, 0.001), "hp": snappedf(w.knight.hp, 0.1), "selected": w.knight.selected_type},
		"hold": {"cap": h.cap, "value": h.value, "stock": h.stock.duplicate(), "stored": h.stored.duplicate(), "queue": queue, "seeds_grown": h.seeds_grown, "felled": h.felled, "relics_banked": h.relics_banked, "gates_opened": h.gates_opened, "heartroots": h.heartroots},
		"sprigs": sprigs,
		"sprouts": sprouts,
		"shrines": shrines,
		"deltas": deltas,
		"lost_total": w.lost_total,
		"discovered": Array(w.discovered),
	}


static func from_doc(tables: ContentTables, raw: Dictionary) -> SimWorld:
	var doc: Dictionary = Migrate.run(raw)
	var w := SimWorld.new(tables, int(doc["seed"]))
	Worldgen.populate(w)
	# deltas over the rolled world
	var dl: Dictionary = doc["deltas"]
	var taken: PackedStringArray = PackedStringArray(dl.get("taken", []))
	var felled: PackedStringArray = PackedStringArray(dl.get("felled", []))
	var opened: PackedStringArray = PackedStringArray(dl.get("opened", []))
	var rooted: PackedStringArray = PackedStringArray(dl.get("rooted", []))
	for o: Entities.WorldObject in w.objects:
		if not o.seed_id.is_empty() and taken.has(o.seed_id):
			o.taken = true
		if o.kind == "shrine" and rooted.has(o.shrine_type):
			o.taken = true
	for e: Entities.Enemy in w.enemies:
		if not e.seed_id.is_empty() and felled.has(e.seed_id):
			e.state = Entities.Enemy.State.DEAD
	for g: Entities.Gate in w.gates:
		if not g.seed_id.is_empty() and opened.has(g.seed_id):
			g.open = true
			g.hp = 0.0
			w.paths.generation += 1
	w.deltas = {"taken": taken, "felled": felled, "opened": opened, "rooted": rooted}
	# accumulated state replaces the rolled starting state
	w.shrines.clear()
	for row: Variant in doc["shrines"]:
		var r: Dictionary = row
		w.root_shrine(str(r["t"]), Vector3(float(r["x"]), 0.0, float(r["z"])))
	if w.shrines.is_empty():
		w.root_shrine("ember", Vector3(5.5, 0.0, -3.0))
	w.sprouts.clear()
	for row: Variant in doc["sprouts"]:
		var r: Dictionary = row
		var sp: Entities.Sprout = w.spawn_sprout(str(r["t"]), Vector3(float(r["x"]), 0.0, float(r["z"])), Vector3.INF, int(r["m"]))
		sp.age = float(r["age"])
	w.sprigs.clear()
	for row: Variant in doc["sprigs"]:
		var r: Dictionary = row
		var st: int = Entities.Sprig.State.FOLLOW if str(r["st"]) == "follow" else Entities.Sprig.State.IDLE
		w.spawn_sprig(str(r["t"]), Vector3(float(r["x"]), 0.0, float(r["z"])), st, int(r["m"]))
	var k: Dictionary = doc["knight"]
	w.knight.pos = w.ground(Vector3(float(k["x"]), 0.0, float(k["z"])))
	w.knight.prev = w.knight.pos
	w.knight.yaw = float(k["yaw"])
	w.knight.hp = clampf(float(k["hp"]), 1.0, w.knight.max_hp)
	w.knight.selected_type = str(k["selected"])
	var h: Dictionary = doc["hold"]
	w.hold.cap = int(h["cap"])
	w.hold.value = int(h["value"])
	w.hold.stock = _int_map(h["stock"])
	w.hold.stored = _int_map(h["stored"])
	w.hold.queue.clear()
	for row: Variant in h["queue"]:
		var q: Dictionary = row
		w.hold.queue_seeds(str(q["type"]), int(q["count"]))
	w.hold.seeds_grown = int(h["seeds_grown"])
	w.hold.felled = int(h["felled"])
	w.hold.relics_banked = int(h["relics_banked"])
	w.hold.gates_opened = int(h["gates_opened"])
	w.hold.heartroots = int(h["heartroots"])
	w.clock.day = int(doc["day"])
	w.clock.time = float(doc["clock_time"])
	w.lost_total = int(doc["lost_total"])
	w.discovered = PackedStringArray(doc.get("discovered", []))
	w._end_tick()
	w.nav_dirty = true
	return w


static func _int_map(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	if v is Dictionary:
		var d: Dictionary = v
		for k: Variant in d.keys():
			out[str(k)] = int(d[k])
	return out
