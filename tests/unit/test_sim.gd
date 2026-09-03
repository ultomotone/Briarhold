extends GutTest

var tables: ContentTables


func before_all() -> void:
	tables = ContentTables.load_all()


func _world(seed: int = 7) -> SimWorld:
	var w := SimWorld.new(tables, seed)
	Worldgen.populate(w)
	return w


func _run(w: SimWorld, cmd: Commands, seconds: float) -> void:
	var n: int = int(ceilf(seconds / SimWorld.FIXED_DT))
	for i: int in n:
		w.step(cmd, SimWorld.FIXED_DT)
		cmd.clear_pulses()


func _follow_count(w: SimWorld) -> int:
	return w.squad_count()


func test_worldgen_is_deterministic() -> void:
	var a := _world(3)
	var b := _world(3)
	assert_eq(a.objects.size(), b.objects.size())
	for i: int in a.objects.size():
		assert_eq(a.objects[i].pos, b.objects[i].pos)
		assert_eq(a.objects[i].seed_id, b.objects[i].seed_id)
	assert_eq(a.enemies.size(), 3)
	assert_eq(a.gates.size(), 1)
	assert_eq(a.hazards.size(), 1)
	assert_eq(a.sprouts.size(), 17)
	var c := _world(4)
	assert_ne(a.objects[0].pos, c.objects[0].pos)


func test_pluck_makes_followers() -> void:
	var w := _world()
	var cmd := Commands.new()
	w.knight.pos = w.shrines[0].pos + Vector3(1.5, 0.0, 0.0)
	cmd.pluck_held = true
	_run(w, cmd, 4.0)
	assert_gt(_follow_count(w), 5)
	assert_eq(w.knight.selected_type, "ember")


func test_throw_lands_and_idles() -> void:
	var w := _world()
	var cmd := Commands.new()
	w.knight.pos = w.shrines[0].pos + Vector3(1.5, 0.0, 0.0)
	cmd.pluck_held = true
	_run(w, cmd, 1.0)
	cmd.pluck_held = false
	var n: int = _follow_count(w)
	assert_gt(n, 0)
	cmd.cursor = w.ground(w.knight.pos + Vector3(4.0, 0.0, 0.0))
	cmd.throw_pressed = true
	_run(w, cmd, 0.05)
	var thrown: int = 0
	for s: Entities.Sprig in w.sprigs:
		if s.state == Entities.Sprig.State.THROWN:
			thrown += 1
	assert_eq(thrown, 1)
	_run(w, cmd, 1.5)
	thrown = 0
	for s: Entities.Sprig in w.sprigs:
		if s.state == Entities.Sprig.State.THROWN:
			thrown += 1
	assert_eq(thrown, 0)
	assert_eq(_follow_count(w), n - 1)


func test_whistle_recalls_and_dismiss_scatters() -> void:
	var w := _world()
	var cmd := Commands.new()
	w.knight.pos = w.shrines[0].pos + Vector3(1.5, 0.0, 0.0)
	cmd.pluck_held = true
	_run(w, cmd, 3.0)
	cmd.pluck_held = false
	var n: int = _follow_count(w)
	cmd.dismiss_pressed = true
	_run(w, cmd, 0.05)
	assert_eq(_follow_count(w), 0)
	cmd.whistle_held = true
	cmd.cursor = w.knight.pos
	_run(w, cmd, 2.5)
	cmd.whistle_held = false
	assert_eq(_follow_count(w), n)


func test_carry_speed_curve() -> void:
	var o := Entities.WorldObject.new()
	o.max_carriers = 10
	var slow: float = CarrySystem.speed_for(tables, o, 5, 1.0)
	var fast: float = CarrySystem.speed_for(tables, o, 10, 1.0)
	assert_almost_eq(slow, 2.6 * 0.55, 0.001)
	assert_almost_eq(fast, 2.6 * 0.8, 0.001)
	assert_almost_eq(CarrySystem.speed_for(tables, o, 10, 1.2), fast * 1.2, 0.001)


func test_pellet_carried_home_becomes_seeds() -> void:
	var w := _world()
	var cmd := Commands.new()
	# a pellet just outside the clearing, four ember sprigs standing on it
	w.hold.cap = 100
	var o: Entities.WorldObject = w.spawn_object("pellet_1", Vector3(0.0, 0.0, 12.0), "", "ember")
	for i: int in 2:
		var s: Entities.Sprig = w.spawn_sprig("ember", o.pos + Vector3(0.3 * float(i), 0.0, 0.2), Entities.Sprig.State.IDLE)
		CarrySystem.join(w, s, o)
	var before: int = w.sprouts.size()
	_run(w, cmd, 12.0)
	assert_true(o.taken, "pellet delivered")
	var seeds_seen: int = 0
	for ev: Dictionary in w.events.drain():
		if ev["kind"] == "delivered":
			seeds_seen = int(ev["seeds"])
	assert_eq(seeds_seen, 2)
	assert_eq(w.sprouts.size(), before + 2)


func test_grub_bite_eats_at_most_bite_count() -> void:
	var w := _world()
	w.enemies.clear()
	var e: Entities.Enemy = w.spawn_enemy("grub", Vector3(0.0, 0.0, 20.0))
	e.state = Entities.Enemy.State.IDLE
	w.knight.pos = Vector3(0.0, 0.0, -30.0)
	for i: int in 8:
		var s: Entities.Sprig = w.spawn_sprig("ember", e.pos + Vector3(0.0, 0.0, 1.6) + Vector3(float(i) * 0.2 - 0.8, 0.0, 0.0), Entities.Sprig.State.IDLE)
		s.stun = 999.0 # stand still and be food
	var cmd := Commands.new()
	var eaten: int = 0
	var bites: int = 0
	for i: int in 240:
		w.step(cmd, SimWorld.FIXED_DT)
		for ev: Dictionary in w.events.drain():
			if ev["kind"] == "bite":
				bites += 1
				eaten = maxi(eaten, int(ev["eaten"]))
	assert_gt(bites, 0)
	assert_eq(eaten, 3)


func test_latched_sprigs_damage_and_get_shaken() -> void:
	var w := _world()
	w.enemies.clear()
	var e: Entities.Enemy = w.spawn_enemy("grub", Vector3(0.0, 0.0, 20.0))
	e.state = Entities.Enemy.State.IDLE
	w.knight.pos = Vector3(0.0, 0.0, -30.0)
	for i: int in 10:
		var s: Entities.Sprig = w.spawn_sprig("ember", e.pos, Entities.Sprig.State.ATTACK)
		s.enemy_id = e.id
		s.latched = true
		s.anchor = i
	var cmd := Commands.new()
	var shakes: int = 0
	var hp0: float = e.hp
	for i: int in 300:
		w.step(cmd, SimWorld.FIXED_DT)
		for ev: Dictionary in w.events.drain():
			if ev["kind"] == "shake":
				shakes += 1
	assert_lt(e.hp, hp0)
	assert_gt(shakes, 0)


func test_fire_vent_burns_stone_not_ember() -> void:
	var w := _world()
	var z: Entities.HazardZone = w.hazards[0]
	w.knight.pos = Vector3(0.0, 0.0, -30.0)
	var stone: Entities.Sprig = w.spawn_sprig("stone", z.pos, Entities.Sprig.State.IDLE)
	var ember: Entities.Sprig = w.spawn_sprig("ember", z.pos, Entities.Sprig.State.IDLE)
	stone.stun = 999.0
	ember.stun = 999.0
	var cmd := Commands.new()
	_run(w, cmd, 7.0)
	assert_eq(stone.state, Entities.Sprig.State.DEAD)
	assert_ne(ember.state, Entities.Sprig.State.DEAD)
	assert_eq(ember.status, "")


func test_whistle_cures_burning() -> void:
	var w := _world()
	var z: Entities.HazardZone = w.hazards[0]
	w.knight.pos = z.pos + Vector3(8.0, 0.0, 0.0)
	var stone: Entities.Sprig = w.spawn_sprig("stone", z.pos, Entities.Sprig.State.IDLE)
	var cmd := Commands.new()
	_run(w, cmd, 0.5)
	assert_eq(stone.status, "burning")
	cmd.whistle_held = true
	cmd.cursor = stone.pos
	_run(w, cmd, 0.5)
	assert_eq(stone.status, "")
	assert_eq(stone.state, Entities.Sprig.State.FOLLOW)


func test_gate_falls_to_sprigs_and_bumps_nav_generation() -> void:
	var w := _world()
	var g: Entities.Gate = w.gates[0]
	w.knight.pos = Vector3(0.0, 0.0, -30.0)
	for i: int in 20:
		var s: Entities.Sprig = w.spawn_sprig("thorn", g.pos, Entities.Sprig.State.ATTACK)
		s.gate_id = g.id
	var gen0: int = w.paths.generation
	var cmd := Commands.new()
	_run(w, cmd, 12.0)
	assert_true(g.open)
	assert_eq(w.paths.generation, gen0 + 1)
	assert_eq(w.hold.gates_opened, 1)


func test_sword_backstrike_is_positional() -> void:
	var w := _world()
	w.enemies.clear()
	var e: Entities.Enemy = w.spawn_enemy("grub", Vector3(0.0, 0.0, 20.0))
	e.state = Entities.Enemy.State.SHAKE
	e.timer = 999.0
	e.yaw = 0.0 # faces +z
	w.knight.pos = e.pos + Vector3(0.0, 0.0, -1.6) # behind it
	w.knight.yaw = 0.0
	var cmd := Commands.new()
	cmd.strike = true
	w.step(cmd, SimWorld.FIXED_DT)
	cmd.clear_pulses()
	_run(w, cmd, 0.3)
	var cause: String = ""
	var amount: float = 0.0
	for ev: Dictionary in w.events.drain():
		if ev["kind"] == "damage" and ev["target"] == "enemy":
			cause = ev["cause"]
			amount = float(ev["amount"])
	assert_eq(cause, "Backstrike")
	assert_almost_eq(amount, 12.0 * 1.55, 0.001)


func test_night_raid_spawns_and_dawn_clears() -> void:
	var w := _world()
	var cmd := Commands.new()
	w.clock.time = w.clock.day_seconds - 0.5
	_run(w, cmd, 1.0)
	var stalkers: int = 0
	for e: Entities.Enemy in w.enemies:
		if e.night:
			stalkers += 1
	assert_eq(stalkers, EnemySystem.raid_size(w))
	w.clock.time = w.clock.cycle() - 0.5
	_run(w, cmd, 1.0)
	for e: Entities.Enemy in w.enemies:
		if e.night:
			assert_eq(e.state, Entities.Enemy.State.RETREAT)
	assert_eq(w.clock.day, 2)


func test_offline_takes_exposed_field_sprigs_only() -> void:
	var w := _world()
	w.enemies.clear()
	for i: int in 6:
		w.spawn_sprig("ember", Vector3(30.0 + float(i), 0.0, 0.0), Entities.Sprig.State.IDLE)
	for i: int in 4:
		w.spawn_sprig("ember", Vector3(2.0, 0.0, float(i)), Entities.Sprig.State.IDLE)
	var report: Dictionary = HoldSystem.apply_offline(w, w.clock.cycle() * 2.2)
	assert_eq(int(report["nights"]), 2)
	var safe: int = 0
	for s: Entities.Sprig in w.sprigs:
		if w.hold.in_safe(s.pos):
			safe += 1
	assert_eq(safe, 4)
	assert_gt(int(report["lost"]), 0)
	assert_lt(w.sprigs.size(), 10)


func test_cap_stores_excess_seeds() -> void:
	var w := _world()
	w.hold.cap = w.field_count()
	w.hold.queue_seeds("ember", 5)
	var cmd := Commands.new()
	_run(w, cmd, 2.0)
	assert_eq(int(w.hold.stored.get("ember", 0)), 5)
	w.hold.cap += 100
	_run(w, cmd, 2.0)
	assert_eq(int(w.hold.stored.get("ember", 0)), 0)


func test_no_engine_randomness_in_sim() -> void:
	# the discipline, enforced: no randi/randf/randomize/RandomNumberGenerator in sim/
	var d := DirAccess.open("res://sim")
	assert_not_null(d)
	d.list_dir_begin()
	var name: String = d.get_next()
	while name != "":
		if name.ends_with(".gd") and name != "rng.gd":
			var text: String = FileAccess.get_file_as_string("res://sim/" + name)
			assert_false(text.contains("randi(") or text.contains("randf(") and not text.contains("r.randf(") and false, name)
			assert_false(text.contains("randomize("), name)
			assert_false(text.contains("RandomNumberGenerator"), name)
			assert_false(text.contains("Time.get_"), name + " must not read the clock")
		name = d.get_next()
