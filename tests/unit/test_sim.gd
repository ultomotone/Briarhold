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
	assert_eq(a.enemies.size(), 7 + 4 + 2 + 17) # field grubs, beetles, two region guardians, the beasts
	assert_eq(a.gates.size(), 2)
	assert_eq(a.hazards.size(), 2 + 4 + 3 + 9 + 3 + 3) # vents, field pools, then the regions'
	assert_eq(a.hazards[0].hazard_id, "fire")
	assert_eq(a.posies.size(), 12)
	assert_eq(a.regions.size(), 6)
	assert_eq(a.sprouts.size(), 17 + 6 * 4)
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
	o.weight = 5
	var pen: float = 1.0 - 0.01 * 5.0
	var slow: float = CarrySystem.speed_for(tables, o, 5, 1.0)
	var fast: float = CarrySystem.speed_for(tables, o, 10, 1.0)
	assert_almost_eq(slow, 2.6 * 0.8 * pen * 0.65, 0.001)
	assert_almost_eq(fast, 2.6 * 0.8 * pen, 0.001)
	assert_almost_eq(CarrySystem.speed_for(tables, o, 10, 1.2), fast * 1.2, 0.001)
	# heavier is slower, and never below a quarter
	o.weight = 20
	assert_lt(CarrySystem.speed_for(tables, o, 10, 1.0), fast)


func test_pellet_carried_home_becomes_seeds() -> void:
	var w := _world()
	var cmd := Commands.new()
	# a pellet just outside the clearing, four ember sprigs standing on it
	w.hold.cap = 100
	var o: Entities.WorldObject = w.spawn_object("pellet_1", Vector3(0.0, 0.0, 9.5), "", "ember")
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
	# room appearing does not empty the reserve on its own; the shrine keeps them for him
	w.hold.cap += 100
	_run(w, cmd, 2.0)
	assert_eq(int(w.hold.stored.get("ember", 0)), 5)


func test_carry_slots_face_first_claimant_and_fill_nearest() -> void:
	var w := _world()
	w.hold.cap = 100
	var o: Entities.WorldObject = w.spawn_object("pellet_5", Vector3(0.0, 0.0, 14.0), "", "ember")
	var a: Entities.Sprig = w.spawn_sprig("ember", o.pos + Vector3(0.0, 0.0, 3.0), Entities.Sprig.State.IDLE)
	CarrySystem.join(w, a, o)
	assert_eq(a.anchor, 0)
	var spot0: Vector3 = CarrySystem.anchor_point(o, 0, o.max_carriers)
	assert_lt(SimWorld.flat_dist(spot0, a.pos), SimWorld.flat_dist(o.pos, a.pos))
	var b: Entities.Sprig = w.spawn_sprig("ember", o.pos + Vector3(0.0, 0.0, -3.0), Entities.Sprig.State.IDLE)
	CarrySystem.join(w, b, o)
	assert_ne(b.anchor, 0)
	var spot_b: Vector3 = CarrySystem.anchor_point(o, b.anchor, o.max_carriers)
	assert_lt(SimWorld.flat_dist(spot_b, b.pos), SimWorld.flat_dist(spot0, b.pos))
	# whistling a away frees its slot without moving b
	w.set_state(a, Entities.Sprig.State.FOLLOW)
	assert_eq(o.slots[0], -1)
	assert_eq(o.slots[b.anchor], b.id)


func test_throw_apex_is_fixed_per_type() -> void:
	var w := _world()
	var t: Types.SprigType = tables.sprig("spark")
	var total: float = SquadSystem.flight_time(w, t)
	assert_almost_eq(Throw.peak_height(total, 22.0), t.throw_height, 0.001)
	assert_gt(SquadSystem.flight_time(w, tables.sprig("spark")), SquadSystem.flight_time(w, tables.sprig("oak")))


func test_throw_prefers_the_ripest() -> void:
	var w := _world()
	var cmd := Commands.new()
	var leaf: Entities.Sprig = w.spawn_sprig("ember", w.knight.pos + Vector3(0.5, 0.0, 0.0), Entities.Sprig.State.FOLLOW, 0)
	var bloom: Entities.Sprig = w.spawn_sprig("ember", w.knight.pos + Vector3(-2.0, 0.0, 0.0), Entities.Sprig.State.FOLLOW, 2)
	w.knight.selected_type = "ember"
	cmd.cursor = w.ground(w.knight.pos + Vector3(4.0, 0.0, 0.0))
	cmd.throw_pressed = true
	w.step(cmd, SimWorld.FIXED_DT)
	assert_eq(bloom.state, Entities.Sprig.State.THROWN)
	assert_eq(leaf.state, Entities.Sprig.State.FOLLOW)


func test_held_throw_repeats() -> void:
	var w := _world()
	var cmd := Commands.new()
	for i: int in 8:
		w.spawn_sprig("ember", w.knight.pos + Vector3(0.5 + 0.2 * float(i), 0.0, 0.5), Entities.Sprig.State.FOLLOW)
	w.knight.selected_type = "ember"
	cmd.cursor = w.ground(w.knight.pos + Vector3(4.0, 0.0, 0.0))
	cmd.throw_pressed = true
	cmd.throw_held = true
	w.step(cmd, SimWorld.FIXED_DT)
	cmd.clear_pulses()
	var thrown_after_first: int = 8 - w.squad_count()
	assert_eq(thrown_after_first, 1)
	_run(w, cmd, 2.0)
	assert_gt(8 - w.squad_count(), 3)


func test_shake_needs_time_as_well_as_damage() -> void:
	var w := _world()
	w.enemies.clear()
	var e: Entities.Enemy = w.spawn_enemy("grub", Vector3(0.0, 0.0, 20.0))
	e.state = Entities.Enemy.State.IDLE
	e.itch_t = 0.0 # it just shook
	w.knight.pos = Vector3(0.0, 0.0, -30.0)
	Damage.to_enemy(w, e, 500.0, "test", e.pos)
	var cmd := Commands.new()
	w.step(cmd, SimWorld.FIXED_DT)
	assert_ne(e.state, Entities.Enemy.State.SHAKE)
	_run(w, cmd, 4.2)
	assert_eq(e.state, Entities.Enemy.State.SHAKE)


func test_maturity_stages_are_uneven() -> void:
	assert_eq(HoldSystem.maturity_for(tables, 119.0), 0)
	assert_eq(HoldSystem.maturity_for(tables, 121.0), 1)
	assert_eq(HoldSystem.maturity_for(tables, 239.0), 1)
	assert_eq(HoldSystem.maturity_for(tables, 241.0), 2)


func test_dismiss_lays_piles_by_type() -> void:
	var w := _world()
	var cmd := Commands.new()
	for i: int in 7:
		w.spawn_sprig("ember", w.knight.pos + Vector3(0.3 * float(i), 0.0, 0.5), Entities.Sprig.State.FOLLOW)
	for i: int in 3:
		w.spawn_sprig("stone", w.knight.pos + Vector3(-0.3 * float(i), 0.0, 0.5), Entities.Sprig.State.FOLLOW)
	cmd.dismiss_pressed = true
	_run(w, cmd, 3.0)
	var ember_c := Vector3.ZERO
	var stone_c := Vector3.ZERO
	for s: Entities.Sprig in w.sprigs:
		if s.type_id == "ember":
			ember_c += s.pos / 7.0
		else:
			stone_c += s.pos / 3.0
	assert_gt(SimWorld.flat_dist(ember_c, stone_c), 1.0)
	assert_eq(w.squad_count(), 0)


func test_hold_f_at_a_shrine_withdraws_stored() -> void:
	var w := _world()
	w.sprouts.clear()
	w.hold.cap = 100
	w.hold.store("ember", 4)
	var sh: Entities.Shrine = w.shrines[0]
	w.knight.pos = sh.pos + Vector3(2.0, 0.0, 0.0)
	var cmd := Commands.new()
	cmd.pluck_held = true
	_run(w, cmd, 1.5)
	assert_eq(int(w.hold.stored.get("ember", 0)), 0)
	assert_eq(w.squad_count("ember"), 4)
	# a full field keeps them inside
	w.hold.store("ember", 2)
	w.hold.cap = w.field_count()
	_run(w, cmd, 1.0)
	assert_eq(int(w.hold.stored.get("ember", 0)), 2)


func test_hold_g_at_a_shrine_sends_sprigs_inside() -> void:
	var w := _world()
	var sh: Entities.Shrine = w.shrines[0]
	w.knight.pos = sh.pos + Vector3(2.0, 0.0, 0.0)
	for i: int in 5:
		w.spawn_sprig("ember", w.knight.pos + Vector3(0.3 * float(i), 0.0, 0.5), Entities.Sprig.State.FOLLOW)
	var stone: Entities.Sprig = w.spawn_sprig("stone", w.knight.pos + Vector3(0.0, 0.0, -0.5), Entities.Sprig.State.FOLLOW)
	var lost0: int = w.lost_total
	var cmd := Commands.new()
	cmd.store_held = true
	_run(w, cmd, 1.2)
	assert_eq(int(w.hold.stored.get("ember", 0)), 5)
	assert_eq(w.squad_count("ember"), 0)
	assert_eq(stone.state, Entities.Sprig.State.FOLLOW) # no Stone shrine here: it stays with him
	assert_eq(w.lost_total, lost0) # inside is not lost


func test_posies_regrow_on_a_seeded_clock() -> void:
	var w := _world()
	var po: Entities.Posy = w.posies[0]
	po.timer = 0.5
	var cmd := Commands.new()
	_run(w, cmd, 1.0)
	var found: int = 0
	for o: Entities.WorldObject in w.objects:
		if o.seed_id.begins_with("posy:%d:" % po.index):
			found += 1
	assert_eq(found, 1)
	assert_gt(po.timer, 30.0)
	# the same seed grows the same pellet
	var w2 := _world()
	w2.posies[0].timer = 0.5
	_run(w2, cmd, 1.0)
	var a: String = ""
	var b: String = ""
	for o: Entities.WorldObject in w.objects:
		if o.seed_id == "posy:0:0":
			a = o.type_id
	for o: Entities.WorldObject in w2.objects:
		if o.seed_id == "posy:0:0":
			b = o.type_id
	assert_eq(a, b)


func test_beetles_flee_and_dawn_brings_arrivals() -> void:
	var w := _world()
	w.enemies.clear()
	var e: Entities.Enemy = w.spawn_enemy("field_beetle", Vector3(0.0, 0.0, 30.0))
	e.state = Entities.Enemy.State.IDLE
	w.knight.pos = e.pos + Vector3(0.0, 0.0, -2.0)
	var d0: float = SimWorld.flat_dist(e.pos, w.knight.pos)
	var cmd := Commands.new()
	_run(w, cmd, 1.0)
	assert_gt(SimWorld.flat_dist(e.pos, w.knight.pos), d0 + 1.0)
	assert_eq(w.knight.hp, w.knight.max_hp)
	var before: int = w.enemies.size()
	w.clock.time = w.clock.cycle() - 0.5
	_run(w, cmd, 1.0)
	assert_gt(w.enemies.size(), before)


func test_every_type_has_a_territory_with_its_shrine_and_sprouts() -> void:
	var w := _world()
	for id: String in ["tide", "spark", "thorn", "moth", "frost", "oak"]:
		var region: Dictionary = {}
		for r: Dictionary in w.regions:
			if r["type"] == id:
				region = r
		assert_false(region.is_empty(), "region for " + id)
		var shrine: Entities.WorldObject = null
		for o: Entities.WorldObject in w.objects:
			if o.kind == "shrine" and o.shrine_type == id:
				shrine = o
		assert_not_null(shrine, "shrine for " + id)
		assert_lt(SimWorld.flat_dist(shrine.pos, region["pos"]), float(region["radius"]), id + " shrine inside its region")
		var sprouts: int = 0
		for sp: Entities.Sprout in w.sprouts:
			if sp.type_id == id:
				sprouts += 1
		assert_eq(sprouts, 4, id + " sprouts")
		assert_lt(SimWorld.flat_dist(region["pos"], w.hold.pos), w.field.bound, id + " region inside the field")


func test_route_avoids_what_some_carrier_is_not_immune_to() -> void:
	var w := _world()
	var o: Entities.WorldObject = w.spawn_object("pellet_5", Vector3(0.0, 0.0, 20.0), "", "tide")
	for i: int in 3:
		CarrySystem.join(w, w.spawn_sprig("tide", o.pos + Vector3(0.3 * float(i), 0.0, 0.6), Entities.Sprig.State.IDLE), o)
	var r: Dictionary = CarrySystem.route_for(w, o)
	assert_false((r["avoid"] as PackedStringArray).has("water"), "an all-Tide crew wades")
	assert_true((r["avoid"] as PackedStringArray).has("fire"))
	assert_false(bool(r["fly"]))
	CarrySystem.join(w, w.spawn_sprig("ember", o.pos + Vector3(-0.6, 0.0, 0.6), Entities.Sprig.State.IDLE), o)
	r = CarrySystem.route_for(w, o)
	assert_true((r["avoid"] as PackedStringArray).has("water"), "one Ember carrier and the trip goes round")
	var m: Entities.WorldObject = w.spawn_object("pellet_1", Vector3(10.0, 0.0, 20.0), "", "moth")
	for i: int in 2:
		CarrySystem.join(w, w.spawn_sprig("moth", m.pos + Vector3(0.3 * float(i), 0.0, 0.6), Entities.Sprig.State.IDLE), m)
	assert_true(bool(CarrySystem.route_for(w, m)["fly"]), "all Moths fly it")


func test_tide_and_moth_keep_dry_and_ember_drowns() -> void:
	var w := _world()
	var pool: Entities.HazardZone = null
	for z: Entities.HazardZone in w.hazards:
		if z.hazard_id == "water":
			pool = z
			break
	w.knight.pos = pool.pos + Vector3(30.0, 0.0, 0.0)
	var tide: Entities.Sprig = w.spawn_sprig("tide", pool.pos, Entities.Sprig.State.IDLE)
	var moth: Entities.Sprig = w.spawn_sprig("moth", pool.pos + Vector3(0.3, 0.0, 0.0), Entities.Sprig.State.IDLE)
	var ember: Entities.Sprig = w.spawn_sprig("ember", pool.pos + Vector3(-0.3, 0.0, 0.0), Entities.Sprig.State.IDLE)
	for s: Entities.Sprig in [tide, moth, ember]:
		s.stun = 999.0
	_run(w, Commands.new(), 6.0)
	assert_ne(tide.state, Entities.Sprig.State.DEAD)
	assert_ne(moth.state, Entities.Sprig.State.DEAD)
	assert_eq(ember.state, Entities.Sprig.State.DEAD)


func test_spark_crosses_the_fence_others_are_shocked() -> void:
	var w := _world()
	var z: Entities.HazardZone = null
	for h: Entities.HazardZone in w.hazards:
		if h.hazard_id == "shock":
			z = h
			break
	w.knight.pos = z.pos + Vector3(30.0, 0.0, 0.0)
	var spark: Entities.Sprig = w.spawn_sprig("spark", z.pos, Entities.Sprig.State.IDLE)
	var stone: Entities.Sprig = w.spawn_sprig("stone", z.pos, Entities.Sprig.State.IDLE)
	_run(w, Commands.new(), 0.3)
	assert_eq(spark.status, "")
	assert_eq(stone.status, "shocked")


func test_frost_slaps_freeze_a_grub_solid() -> void:
	var w := _world()
	w.enemies.clear()
	var e: Entities.Enemy = w.spawn_enemy("grub", Vector3(0.0, 0.0, 30.0))
	e.state = Entities.Enemy.State.IDLE
	w.knight.pos = Vector3(0.0, 0.0, -30.0)
	for i: int in 6:
		var s: Entities.Sprig = w.spawn_sprig("frost", e.pos, Entities.Sprig.State.ATTACK)
		s.enemy_id = e.id
		s.latched = true
		s.anchor = i * 2
	var froze: bool = false
	var cmd := Commands.new()
	for i: int in 300:
		w.step(cmd, SimWorld.FIXED_DT)
		for ev: Dictionary in w.events.drain():
			if ev["kind"] == "frozen":
				froze = true
	assert_true(froze)
	assert_eq(e.state, Entities.Enemy.State.FROZEN)
	var p0: Vector3 = e.pos
	_run(w, cmd, 1.0)
	assert_eq(e.pos, p0, "frozen things do not move")


func test_a_grub_that_eats_thorns_is_poisoned() -> void:
	var w := _world()
	w.enemies.clear()
	var e: Entities.Enemy = w.spawn_enemy("grub", Vector3(0.0, 0.0, 30.0))
	e.state = Entities.Enemy.State.IDLE
	e.yaw = 0.0
	w.knight.pos = Vector3(0.0, 0.0, -40.0)
	for i: int in 3:
		var s: Entities.Sprig = w.spawn_sprig("thorn", e.pos + Vector3(float(i) * 0.25 - 0.25, 0.0, 1.5), Entities.Sprig.State.IDLE)
		s.stun = 999.0
	var poison: float = 0.0
	var cmd := Commands.new()
	for i: int in 240:
		w.step(cmd, SimWorld.FIXED_DT)
		for ev: Dictionary in w.events.drain():
			if ev["kind"] == "damage" and ev["cause"] == "Thorn poison":
				poison += float(ev["amount"])
	assert_almost_eq(poison, 3.0 * tables.wn("thorn", "poison_damage", 150.0), 0.01)


func test_walking_into_a_region_finds_it_and_the_save_keeps_it() -> void:
	var w := _world()
	var r: Dictionary = w.regions[0]
	w.knight.pos = w.ground(r["pos"])
	var found: String = ""
	var cmd := Commands.new()
	for i: int in 20:
		w.step(cmd, SimWorld.FIXED_DT)
		for ev: Dictionary in w.events.drain():
			if ev["kind"] == "region_found":
				found = ev["id"]
	assert_eq(found, r["id"])
	assert_true(w.discovered.has(r["id"]))
	var back: SimWorld = Serialize.from_doc(tables, Serialize.to_doc(w, 1000))
	assert_true(back.discovered.has(r["id"]))


class NoPath:
	extends PathProvider

	func path(_from: Vector3, _to: Vector3, _avoid: PackedStringArray = PackedStringArray(), _fly: bool = false) -> PackedVector3Array:
		return PackedVector3Array()


func test_a_load_with_no_way_home_stays_put_and_says_so() -> void:
	var w := _world()
	w.paths = NoPath.new()
	var o: Entities.WorldObject = w.spawn_object("pellet_1", Vector3(0.0, 0.0, 30.0), "", "ember")
	for i: int in 2:
		CarrySystem.join(w, w.spawn_sprig("ember", o.pos + Vector3(0.3 * float(i), 0.0, 0.6), Entities.Sprig.State.IDLE), o)
	var p0: Vector3 = o.pos
	var said: bool = false
	var cmd := Commands.new()
	for i: int in 400:
		w.step(cmd, SimWorld.FIXED_DT)
		for ev: Dictionary in w.events.drain():
			if ev["kind"] == "stuck":
				said = true
	assert_lt(SimWorld.flat_dist(o.pos, p0), 0.01)
	assert_false(o.taken)
	assert_true(said)


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
