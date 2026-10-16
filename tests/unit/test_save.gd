extends GutTest

var tables: ContentTables


func before_all() -> void:
	tables = ContentTables.load_all()
	SaveStore.base_dir = "user://test-saves"


func after_all() -> void:
	SaveStore.base_dir = "user://saves"


func test_migrate_is_idempotent_on_current() -> void:
	var doc: Dictionary = _fixture()
	var once: Dictionary = Migrate.run(doc)
	var twice: Dictionary = Migrate.run(once)
	assert_eq(JSON.stringify(once), JSON.stringify(twice))
	assert_eq(int(once["schemaVersion"]), Migrate.CURRENT)
	assert_eq(str(once["key"]), Migrate.KEY)


func test_migrate_fills_a_bare_document() -> void:
	var m: Dictionary = Migrate.run({"seed": 12})
	assert_eq(int(m["seed"]), 12)
	assert_true(m.has("hold"))
	assert_true(m.has("deltas"))
	var h: Dictionary = m["hold"]
	assert_eq(int(h["cap"]), 20)


func test_fixture_v1_loads_and_deltas_apply() -> void:
	var w: SimWorld = Serialize.from_doc(tables, _fixture())
	assert_eq(w.seed, 7)
	assert_eq(w.clock.day, 2)
	assert_eq(w.sprigs.size(), 3)
	assert_eq(w.sprouts.size(), 2)
	assert_eq(w.shrines.size(), 2)
	assert_eq(w.hold.cap, 30)
	assert_eq(int(w.hold.stock.get("relic_button", 0)), 1)
	assert_true(w.gates[0].open)
	for o: Entities.WorldObject in w.objects:
		assert_ne(o.seed_id, "pellet:0")
		assert_ne(o.seed_id, "relic:button")
		if o.kind == "shrine":
			assert_ne(o.shrine_type, "stone", "the rooted Stone shrine is not also in the field")
	for e: Entities.Enemy in w.enemies:
		assert_ne(e.seed_id, "grub:1")
	assert_almost_eq(w.knight.hp, 88.0, 0.01)


func test_v1_migrates_to_v2_with_nothing_discovered() -> void:
	var m: Dictionary = Migrate.run(_fixture())
	assert_eq(int(m["schemaVersion"]), 2)
	assert_eq((m["discovered"] as Array).size(), 0)


func test_fixture_v2_loads_discovered() -> void:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/save-v2.json"))
	assert_true(v is Dictionary)
	var doc: Dictionary = v
	assert_eq(JSON.stringify(Migrate.run(doc)), JSON.stringify(Migrate.run(Migrate.run(doc))))
	var w: SimWorld = Serialize.from_doc(tables, doc)
	assert_true(w.discovered.has("mere"))
	assert_eq(w.sprigs.size(), 4)


func test_round_trip_is_stable() -> void:
	var w := SimWorld.new(tables, 5)
	Worldgen.populate(w)
	var cmd := Commands.new()
	w.knight.pos = w.shrines[0].pos + Vector3(1.5, 0.0, 0.0)
	cmd.pluck_held = true
	for i: int in 120:
		w.step(cmd, SimWorld.FIXED_DT)
	var a: Dictionary = Serialize.to_doc(w, 1000)
	var w2: SimWorld = Serialize.from_doc(tables, a)
	var b: Dictionary = Serialize.to_doc(w2, 1000)
	assert_eq(JSON.stringify(a), JSON.stringify(b))
	assert_gt((a["sprigs"] as Array).size(), 0)


func test_store_writes_atomically_and_reads_back() -> void:
	var doc: Dictionary = _fixture()
	assert_eq(SaveStore.write("t1", doc), OK)
	var back: Dictionary = SaveStore.read("t1")
	assert_eq(int(back["seed"]), 7)
	doc["day"] = 9
	assert_eq(SaveStore.write("t1", doc), OK)
	assert_eq(int(SaveStore.read("t1")["day"]), 9)
	# a corrupt slot falls back to the previous version
	var f := FileAccess.open(SaveStore.slot_path("t1"), FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	assert_eq(int(SaveStore.read("t1")["day"]), 2)
	var slots: Array[Dictionary] = SaveStore.list_slots()
	assert_gt(slots.size(), 0)


func _fixture() -> Dictionary:
	var text: String = FileAccess.get_file_as_string("res://tests/fixtures/save-v1.json")
	var v: Variant = JSON.parse_string(text)
	assert_true(v is Dictionary, "fixture parses")
	return v
