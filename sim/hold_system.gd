## The Hold's seed loop: queued seeds fly out of their type's shrine and root as sprouts while the
## field has room; the rest wait inside. Sprouts mature in the ground. Nothing here is random
## beyond the seeded scatter of where a seed lands.
class_name HoldSystem
extends RefCounted

const SEED_INTERVAL: float = 0.12


static func step(w: SimWorld, dt: float) -> void:
	var h: Hold = w.hold
	var c: ContentTables = w.content
	h.seed_timer += dt
	while h.seed_timer >= SEED_INTERVAL:
		h.seed_timer -= SEED_INTERVAL
		if w.field_count() < h.cap:
			var t: String = h.pop_seed()
			if t.is_empty():
				t = h.take_stored()
			if t.is_empty():
				break
			_plant(w, t)
		else:
			var t: String = h.pop_seed()
			if t.is_empty():
				break
			h.store(t)
			h.seeds_grown += 1
			w.events.push("stored", {"type": t, "inside": h.stored_total(), "cap": h.cap})
	for sp: Entities.Sprout in w.sprouts:
		if sp.fl_t >= 0.0:
			sp.fl_t += dt
			if sp.fl_t >= sp.fl_total:
				sp.fl_t = -1.0
				w.events.push("rooted", {"pos": sp.pos, "type": sp.type_id})
			continue
		sp.age += dt
		var m: int = maturity_for(c, sp.age)
		if m != sp.maturity:
			sp.maturity = m
			w.events.push("matured", {"pos": sp.pos, "type": sp.type_id, "maturity": m})


## Leaf, then bud after stage 1, bloom after stage 1 + stage 2. The third stage is longer on
## purpose: the bloom is earned.
static func maturity_for(c: ContentTables, age: float) -> int:
	var s1: float = c.wn("sprout", "stage_seconds_1", 120.0)
	var s2: float = c.wn("sprout", "stage_seconds_2", 120.0)
	if age >= s1 + s2:
		return 2
	if age >= s1:
		return 1
	return 0


static func _plant(w: SimWorld, type_id: String) -> void:
	var h: Hold = w.hold
	var sh: Entities.Shrine = w.shrine_for(type_id)
	if sh == null:
		h.store(type_id)
		h.seeds_grown += 1
		return
	# no roll: the seed count walks a golden angle, and the distance cycles, so seeds spread
	# evenly and the same Hold always sows the same patch
	var n: int = h.seeds_grown
	var scatter: float = w.content.wn("sprout", "seed_scatter_radius", 3.5)
	var ang: float = float(n) * TAU * 0.12345
	var dist: float = 1.2 + sqrt(fmod(float(n) * 0.618034, 1.0)) * scatter
	var p: Vector3 = sh.pos + Vector3(sin(ang), 0.0, cos(ang)) * dist
	p = w.push_out(p, 0.2)
	w.spawn_sprout(type_id, p, sh.pos + Vector3(0.0, 2.2, 0.0))
	h.seeds_grown += 1
	w.events.push("seed", {"pos": sh.pos, "to": p, "type": type_id})


## Offline: sprouts mature by the elapsed time; each night that passed took field sprigs
## outside the safe ring, farthest from the Hold first. One step, deterministic, capped by the clock.
static func apply_offline(w: SimWorld, elapsed: float) -> Dictionary:
	var c: ContentTables = w.content
	var nights: int = w.clock.advance_offline(elapsed, c.wi("offline_cap_days", 7))
	var capped: float = minf(elapsed, float(c.wi("offline_cap_days", 7)) * w.clock.cycle())
	var matured: int = 0
	for sp: Entities.Sprout in w.sprouts:
		if sp.fl_t >= 0.0:
			sp.fl_t = -1.0
		sp.age += capped
		var m: int = maturity_for(c, sp.age)
		if m > sp.maturity:
			matured += 1
		sp.maturity = m
	# the queue resolves in full while he was away
	while true:
		var t: String = w.hold.pop_seed()
		if t.is_empty():
			break
		if w.field_count() < w.hold.cap:
			_plant(w, t)
		else:
			w.hold.store(t)
			w.hold.seeds_grown += 1
	var lost: int = 0
	for n: int in nights:
		var exposed: Array[Entities.Sprig] = []
		for s: Entities.Sprig in w.sprigs:
			if s.state != Entities.Sprig.State.DEAD and not w.hold.in_safe(s.pos):
				exposed.append(s)
		exposed.sort_custom(func(a: Entities.Sprig, b: Entities.Sprig) -> bool:
			var da: float = SimWorld.flat_dist(a.pos, w.hold.pos)
			var db: float = SimWorld.flat_dist(b.pos, w.hold.pos)
			if absf(da - db) < 0.0001:
				return a.id > b.id
			return da > db)
		var take: int = mini(exposed.size(), EnemySystem.raid_size(w))
		for i: int in take:
			w.kill_sprig(exposed[i], "taken in the night")
			lost += 1
	w._end_tick()
	var report: Dictionary = {"nights": nights, "lost": lost, "matured": matured, "elapsed": capped}
	w.events.push("offline", report.duplicate())
	return report
