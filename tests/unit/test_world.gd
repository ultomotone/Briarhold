extends GutTest
## The open world (2026-10-20): far places scattered without a pattern, climates you walk into,
## campsites the Hold can move to, bosses with more than one move, and the ground baked once.

var tables: ContentTables


func before_all() -> void:
	tables = ContentTables.load_all()


func _world(seed: int = 7) -> SimWorld:
	var w := SimWorld.new(tables, seed)
	Worldgen.populate(w)
	return w


func test_far_places_are_not_on_a_ring() -> void:
	var w := _world()
	var dists: Array[float] = []
	for r: Dictionary in w.regions:
		dists.append(SimWorld.flat_dist(r["pos"], w.hold.pos))
	dists.sort()
	assert_gt(dists[dists.size() - 1] - dists[0], 30.0, "territories lie at different distances")
	# and they keep their room: no two far places overlap
	var places: Array[Vector3] = []
	for r: Dictionary in w.regions:
		places.append(r["pos"])
	for a: Dictionary in w.arenas:
		places.append(a["pos"])
	for c: Dictionary in w.camps:
		places.append(c["pos"])
	for i: int in places.size():
		for j: int in range(i + 1, places.size()):
			assert_gt(SimWorld.flat_dist(places[i], places[j]), 20.0)


func test_every_world_has_all_three_far_climates_somewhere() -> void:
	for seed: int in [7, 12345, 99]:
		var w := _world(seed)
		var best := Vector3.ZERO
		var b: float = w.field.bound
		var x: float = -b
		while x <= b:
			var z: float = -b
			while z <= b:
				var cl: Vector3 = w.field.climate(x, z)
				best = Vector3(maxf(best.x, cl.x), maxf(best.y, cl.y), maxf(best.z, cl.z))
				z += 12.0
			x += 12.0
		assert_gt(best.x, 0.8, "arctic in world %d" % seed)
		assert_gt(best.y + best.z, 0.8, "desert or jungle in world %d" % seed)
		# and the Hold's own country is temperate
		assert_eq(w.field.climate(0.0, 0.0), Vector3.ZERO)


func test_snow_slows_all_but_frost_and_sand_all_but_ember() -> void:
	var w := _world()
	var snow := Vector3.INF
	var sand := Vector3.INF
	var b: float = w.field.bound
	var x: float = -b
	while x <= b and (snow == Vector3.INF or sand == Vector3.INF):
		var z: float = -b
		while z <= b:
			var cl: Vector3 = w.field.climate(x, z)
			if cl.x > 0.95 and snow == Vector3.INF:
				snow = Vector3(x, 0.0, z)
			if cl.y > 0.95 and sand == Vector3.INF:
				sand = Vector3(x, 0.0, z)
			z += 8.0
		x += 8.0
	if snow != Vector3.INF:
		assert_almost_eq(w.ground_mult(snow, "frost"), 1.0 - 0.15 * w.field.climate(snow.x, snow.z).y - 0.12 * w.field.climate(snow.x, snow.z).z, 0.01)
		assert_lt(w.ground_mult(snow, "ember"), 0.82)
		assert_eq(w.ground_mult(snow, "moth"), 1.0)
	if sand != Vector3.INF:
		assert_gt(w.ground_mult(sand, "ember"), w.ground_mult(sand, "frost"))
	assert_eq(w.ground_mult(Vector3.ZERO, "ember"), 1.0, "nothing slows you at home")


func test_holding_t_at_a_camp_moves_the_hold_and_its_shrines() -> void:
	var w := _world()
	var cp: Dictionary = w.camps[1]
	var beacon: Vector3 = CampSystem.beacon(w, cp)
	w.knight.pos = beacon
	var cmd := Commands.new()
	cmd.camp_held = true
	var moved: bool = false
	for i: int in 90:
		w.step(cmd, SimWorld.FIXED_DT)
		for ev: Dictionary in w.events.drain():
			if ev["kind"] == "camp_moved":
				moved = true
	assert_true(moved)
	assert_eq(w.camp_id, str(cp["id"]))
	assert_lt(SimWorld.flat_dist(w.hold.pos, cp["pos"]), 0.5)
	for sh: Entities.Shrine in w.shrines:
		assert_lt(SimWorld.flat_dist(sh.pos, w.hold.pos), 9.0, "the shrines came along")
	# the save keeps it
	var back: SimWorld = Serialize.from_doc(tables, Serialize.to_doc(w, 1000))
	assert_eq(back.camp_id, w.camp_id)
	assert_lt(SimWorld.flat_dist(back.hold.pos, w.hold.pos), 0.5)


func test_v2_save_migrates_to_the_home_camp_and_the_v3_fixture_loads() -> void:
	var v2: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/save-v2.json"))
	var m: Dictionary = Migrate.run(v2)
	assert_eq(str(m["camp"]), "home")
	var v3: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/save-v3.json"))
	var doc: Dictionary = v3
	assert_eq(JSON.stringify(Migrate.run(doc)), JSON.stringify(Migrate.run(Migrate.run(doc))))
	var w: SimWorld = Serialize.from_doc(tables, doc)
	assert_eq(w.camp_id, "camp:0")
	assert_lt(SimWorld.flat_dist(w.hold.pos, CampSystem.camp_by_id(w, "camp:0")["pos"]), 0.5)


func test_a_boss_stomp_flattens_all_but_stone_and_throws_off_riders() -> void:
	var w := _world()
	w.enemies.clear()
	w.hazards.clear()
	w.obstacles.clear()
	var c: Vector3 = w.ground(Vector3(0.0, 0.0, 40.0))
	var boss: Entities.Enemy = w.spawn_enemy("thornback_behemoth", c)
	boss.state = Entities.Enemy.State.IDLE
	boss.move_i = 1 # its stomp is next
	w.knight.pos = w.ground(Vector3(0.0, 0.0, -60.0))
	var ember: Entities.Sprig = w.spawn_sprig("ember", c + Vector3(0.0, 0.0, 3.0), Entities.Sprig.State.IDLE)
	ember.stun = 999.0
	var stone: Entities.Sprig = w.spawn_sprig("stone", c + Vector3(0.4, 0.0, 3.0), Entities.Sprig.State.IDLE)
	stone.stun = 999.0
	var rider: Entities.Sprig = w.spawn_sprig("ember", c, Entities.Sprig.State.ATTACK)
	rider.enemy_id = boss.id
	rider.latched = true
	var slammed: bool = false
	var cmd := Commands.new()
	for i: int in 120:
		w.step(cmd, SimWorld.FIXED_DT)
		for ev: Dictionary in w.events.drain():
			if ev["kind"] == "slam":
				slammed = true
		if slammed:
			break
	assert_true(slammed)
	assert_eq(ember.state, Entities.Sprig.State.DEAD)
	assert_ne(stone.state, Entities.Sprig.State.DEAD)
	assert_false(rider.latched, "thrown off")


func test_baked_ground_matches_the_noise() -> void:
	var w := _world()
	var worst: float = 0.0
	var r := Rng.stream("bake-check")
	for i: int in 400:
		var x: float = (r.randf() * 2.0 - 1.0) * 240.0
		var z: float = (r.randf() * 2.0 - 1.0) * 240.0
		worst = maxf(worst, absf(w.field.height_at(x, z) - w.field._height_raw(x, z)))
	assert_true(w.field.is_baked())
	assert_lt(worst, 0.6, "the 2 m grid stays within a hand's breadth of the noise")
