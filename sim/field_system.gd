## Life on a clock. Posies regrow a pellet on a seeded timer; each dawn the field gets its
## arrivals (EnemySystem.on_dawn calls arrivals()). Nothing rolls at tick time: every timer and
## every arrival comes from a stream named by the seed, the posy, and the day.
class_name FieldSystem
extends RefCounted


static func step(w: SimWorld, dt: float) -> void:
	var c: ContentTables = w.content
	for po: Entities.Posy in w.posies:
		# whether its last pellet is still there, looked at every 15 ticks (staggered by posy) and
		# not every tick: the look walks every object in the field
		if (w.tick + po.index) % 15 == 0:
			po.holding = _has_pellet(w, po)
		if po.holding:
			continue
		po.timer -= dt
		if po.timer > 0.0:
			continue
		_grow(w, po, c)


static func _has_pellet(w: SimWorld, po: Entities.Posy) -> bool:
	var prefix: String = "posy:%d:" % po.index
	for o: Entities.WorldObject in w.objects:
		if not o.taken and o.seed_id.begins_with(prefix):
			return true
	return false


static func _grow(w: SimWorld, po: Entities.Posy, c: ContentTables) -> void:
	# skip ids the save already recorded as taken, so a reload does not regrow old pellets
	var taken: PackedStringArray = w.deltas["taken"]
	var sid: String = "posy:%d:%d" % [po.index, po.grown]
	while taken.has(sid):
		po.grown += 1
		sid = "posy:%d:%d" % [po.index, po.grown]
	var r := Rng.stream("%s:posy:%d:%d" % [w.seed_str(), po.index, po.grown])
	var tid: String = "pellet_1" if r.randf() < 0.7 else "pellet_5"
	w.spawn_object(tid, po.pos + Vector3(0.0, 0.0, 0.0), sid, po.pellet_type)
	po.grown += 1
	po.holding = true
	po.timer = c.wn("arrivals", "posy_regrow_seconds", 150.0) + (r.randf() - 0.5) * 2.0 * c.wn("arrivals", "posy_regrow_spread", 90.0)
	w.events.push("posy_grew", {"pos": po.pos, "type": po.pellet_type})


## Dawn: beetles at open spots; sometimes a grub wanders in from the rim to a spot of its own.
static func arrivals(w: SimWorld, day: int) -> void:
	var c: ContentTables = w.content
	var r := Rng.stream("%s:arrivals:day%d" % [w.seed_str(), day])
	var n: int = r.randi_range(c.wi_in("arrivals", "beetles_min", 2), c.wi_in("arrivals", "beetles_max", 5))
	var came: int = 0
	for i: int in n:
		var p: Vector3 = Worldgen.open_spot(w, r, 16.0, 140.0)
		var e: Entities.Enemy = w.spawn_enemy("field_beetle", p)
		e.state = Entities.Enemy.State.IDLE
		came += 1
	var visitor: bool = r.randf() < c.wn("arrivals", "visitor_chance", 0.5)
	if visitor:
		var ang: float = r.randf() * TAU
		var rim: Vector3 = w.field.clamp_bound(w.hold.pos + Vector3(sin(ang), 0.0, cos(ang)) * minf(w.field.bound - 3.0, 110.0))
		var e: Entities.Enemy = w.spawn_enemy("grub", rim)
		e.state = Entities.Enemy.State.IDLE
		e.home = Worldgen.open_spot(w, r, 24.0, 140.0) # it walks to its new bed and sleeps
		e.wander = e.home
	# and sometimes a beast of some other kind settles somewhere new
	var beast: String = ""
	if r.randf() < c.wn("beasts", "beast_chance", 0.6):
		var kinds: PackedStringArray = ["pounce_toad", "gale_puff", "hollow_mole", "cinder_hog", "shellback"]
		beast = kinds[r.randi_range(0, kinds.size() - 1)]
		w.spawn_enemy(beast, Worldgen.open_spot(w, r, 30.0, 160.0))
	w.events.push("arrivals", {"beetles": came, "visitor": visitor, "beast": beast, "day": day})
