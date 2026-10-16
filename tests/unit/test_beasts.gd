extends GutTest
## The creatures with abilities: each does the one thing its row says, and the counter to it
## (immunity, armour from the front only, the surfaced window) holds.

var tables: ContentTables


func before_all() -> void:
	tables = ContentTables.load_all()


## A cleared patch of field: no other beasts, hazards, or stones near the test, the gnome far off.
func _arena() -> SimWorld:
	var w := SimWorld.new(tables, 11)
	Worldgen.populate(w)
	w.enemies.clear()
	w.hazards.clear()
	w.obstacles.clear()
	w.gates.clear()
	w.sprouts.clear()
	w.knight.pos = w.ground(Vector3(0.0, 0.0, -70.0))
	return w


func _run(w: SimWorld, seconds: float) -> void:
	var cmd := Commands.new()
	for i: int in int(ceilf(seconds / SimWorld.FIXED_DT)):
		w.step(cmd, SimWorld.FIXED_DT)


## A sprig that will not walk off on its own during the test.
func _pinned(w: SimWorld, type_id: String, p: Vector3) -> Entities.Sprig:
	var s: Entities.Sprig = w.spawn_sprig(type_id, p, Entities.Sprig.State.IDLE)
	s.stun = 999.0
	return s


func test_every_beast_kind_lives_in_the_field() -> void:
	var w := SimWorld.new(tables, 7)
	Worldgen.populate(w)
	var counts: Dictionary = {}
	for e: Entities.Enemy in w.enemies:
		counts[e.type_id] = int(counts.get(e.type_id, 0)) + 1
	for kind: String in ["cinder_hog", "pounce_toad", "shellback", "gale_puff", "hollow_mole"]:
		assert_eq(int(counts.get(kind, 0)), tables.wi_in("beasts", kind, 0), kind)
	assert_eq(int(counts.get("mire_hog", 0)), 1, "the Fume Bog's guardian")
	# hogs doze by the fire vents
	var vents: Array[Vector3] = []
	for z: Entities.HazardZone in w.hazards:
		if z.hazard_id == "fire":
			vents.append(z.pos)
	var near_vent: int = 0
	for e: Entities.Enemy in w.enemies:
		if e.type_id != "cinder_hog":
			continue
		for v: Vector3 in vents:
			if SimWorld.flat_dist(e.pos, v) < 8.0:
				near_vent += 1
				break
	assert_eq(near_vent, mini(vents.size(), tables.wi_in("beasts", "cinder_hog", 0)))


func test_hog_breath_burns_everything_but_embers() -> void:
	var w := _arena()
	var c: Vector3 = w.ground(Vector3(0.0, 0.0, 40.0))
	var hog: Entities.Enemy = w.spawn_enemy("cinder_hog", c)
	hog.state = Entities.Enemy.State.IDLE
	var ember: Entities.Sprig = _pinned(w, "ember", c + Vector3(0.0, 0.0, 2.6))
	var stone: Entities.Sprig = _pinned(w, "stone", c + Vector3(0.3, 0.0, 2.6))
	var breathed: bool = false
	var cmd := Commands.new()
	for i: int in 120:
		w.step(cmd, SimWorld.FIXED_DT)
		for ev: Dictionary in w.events.drain():
			if ev["kind"] == "breath":
				breathed = true
	assert_true(breathed)
	assert_eq(stone.status, "burning")
	assert_eq(ember.status, "")


func test_toad_lands_where_you_stood_and_crushes_all_but_stone() -> void:
	var w := _arena()
	var c: Vector3 = w.ground(Vector3(0.0, 0.0, 40.0))
	var toad: Entities.Enemy = w.spawn_enemy("pounce_toad", c)
	toad.state = Entities.Enemy.State.IDLE
	var spot: Vector3 = c + Vector3(0.0, 0.0, 5.0)
	var ember: Entities.Sprig = _pinned(w, "ember", spot)
	var stone: Entities.Sprig = _pinned(w, "stone", spot + Vector3(0.3, 0.0, 0.0))
	_run(w, 2.5)
	assert_eq(ember.state, Entities.Sprig.State.DEAD)
	assert_ne(stone.state, Entities.Sprig.State.DEAD)
	assert_lt(SimWorld.flat_dist(toad.pos, spot), 1.5, "it landed on the spot")


func test_shellback_tramples_its_lane_and_is_armoured_only_in_front() -> void:
	var w := _arena()
	var c: Vector3 = w.ground(Vector3(0.0, 0.0, 40.0))
	var sb: Entities.Enemy = w.spawn_enemy("shellback", c)
	sb.state = Entities.Enemy.State.IDLE
	var ember: Entities.Sprig = _pinned(w, "ember", c + Vector3(0.0, 0.0, 7.0))
	var dazed: bool = false
	var cmd := Commands.new()
	for i: int in 240:
		w.step(cmd, SimWorld.FIXED_DT)
		for ev: Dictionary in w.events.drain():
			if ev["kind"] == "dazed":
				dazed = true
	assert_eq(ember.state, Entities.Sprig.State.DEAD)
	assert_true(dazed, "a rush ends dizzy")
	var et: Types.EnemyType = tables.enemy("shellback")
	sb.yaw = 0.0
	assert_almost_eq(Damage.facing_mult(sb, et, sb.pos + Vector3(0.0, 0.0, 2.0)), et.front_multiplier, 0.001)
	assert_almost_eq(Damage.facing_mult(sb, et, sb.pos + Vector3(0.0, 0.0, -2.0)), et.back_multiplier, 0.001)
	assert_almost_eq(Damage.facing_mult(sb, et, sb.pos + Vector3(2.0, 0.0, 0.0)), 1.0, 0.001)


func test_gale_puff_blows_sprigs_back_but_oaks_stand() -> void:
	var w := _arena()
	var c: Vector3 = w.ground(Vector3(0.0, 0.0, 40.0))
	var puff: Entities.Enemy = w.spawn_enemy("gale_puff", c)
	puff.state = Entities.Enemy.State.IDLE
	puff.yaw = 0.0
	var ember: Entities.Sprig = _pinned(w, "ember", c + Vector3(0.0, 0.0, 3.0))
	var oak: Entities.Sprig = _pinned(w, "oak", c + Vector3(0.4, 0.0, 3.0))
	_run(w, 1.4)
	assert_gt(SimWorld.flat_dist(ember.pos, c), 6.0, "blown back")
	assert_lt(SimWorld.flat_dist(oak.pos, c), 3.6, "too heavy to move")
	assert_ne(ember.state, Entities.Sprig.State.DEAD, "wind alone kills nothing")


func test_mole_is_untouchable_underground_then_comes_up_under_you() -> void:
	var w := _arena()
	var c: Vector3 = w.ground(Vector3(0.0, 0.0, 40.0))
	var mole: Entities.Enemy = w.spawn_enemy("hollow_mole", c)
	_run(w, 0.1)
	assert_eq(mole.state, Entities.Enemy.State.BURROW)
	assert_eq(Damage.to_enemy(w, mole, 50.0, "test", mole.pos), 0.0, "nothing reaches it underground")
	var spot: Vector3 = c + Vector3(0.0, 0.0, 6.0)
	var group: Array[Entities.Sprig] = []
	for i: int in 4:
		group.append(_pinned(w, "ember", spot + Vector3(0.12 * float(i), 0.0, 0.0)))
	var erupted: bool = false
	var cmd := Commands.new()
	for i: int in 360:
		w.step(cmd, SimWorld.FIXED_DT)
		for ev: Dictionary in w.events.drain():
			if ev["kind"] == "erupt":
				erupted = true
		if erupted:
			break
	assert_true(erupted)
	var dead: int = 0
	for s: Entities.Sprig in group:
		if s.state == Entities.Sprig.State.DEAD:
			dead += 1
	assert_eq(dead, tables.enemy("hollow_mole").bite_count, "it eats its bite and throws the rest clear")
	assert_ne(mole.state, Entities.Enemy.State.BURROW)
	assert_gt(Damage.to_enemy(w, mole, 50.0, "test", mole.pos), 0.0, "surfaced, it can be hit")


func test_dawn_can_bring_a_new_beast() -> void:
	var w := _arena()
	var brought: int = 0
	for day: int in range(2, 12):
		var before: int = w.enemies.size()
		FieldSystem.arrivals(w, day)
		for e: Entities.Enemy in w.enemies.slice(before):
			if e.type_id != "field_beetle" and e.type_id != "grub":
				brought += 1
	assert_gt(brought, 2)


func test_day_to_night_has_no_jumps() -> void:
	var day_s: float = 900.0
	var night_s: float = 360.0
	var prev: float = SkyEnv.darkness(0.0, day_s, night_s)
	var worst: float = 0.0
	var t: float = 0.5
	while t < day_s + night_s:
		var d: float = SkyEnv.darkness(t, day_s, night_s)
		worst = maxf(worst, absf(d - prev))
		prev = d
		t += 0.5
	# and across the wrap from the end of the night to daybreak
	worst = maxf(worst, absf(SkyEnv.darkness(0.0, day_s, night_s) - SkyEnv.darkness(day_s + night_s - 0.001, day_s, night_s)))
	assert_lt(worst, 0.01, "darkness never steps")
	assert_almost_eq(SkyEnv.darkness(day_s * 0.5, day_s, night_s), 0.0, 0.001, "noon is day")
	assert_almost_eq(SkyEnv.darkness(day_s + night_s * 0.5, day_s, night_s), 1.0, 0.001, "midnight is night")
