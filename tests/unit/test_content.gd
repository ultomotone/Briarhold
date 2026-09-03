extends GutTest

var tables: ContentTables


func before_all() -> void:
	tables = ContentTables.load_all()


func test_loads_without_errors() -> void:
	assert_eq(tables.errors.size(), 0, ", ".join(tables.errors))


func test_sprig_table_shape() -> void:
	assert_true(tables.sprigs.has("ember"))
	assert_true(tables.sprigs.has("stone"))
	assert_eq(tables.sprig_order.size(), tables.sprigs.size())
	for id: String in tables.sprigs.keys():
		var t: Types.SprigType = tables.sprig(id)
		assert_eq(t.id, id)
		assert_gt(t.speed, 0.0)
		assert_gt(t.damage, 0.0)
		assert_true(t.name.length() > 0)


func test_every_colour_key_exists_in_palette() -> void:
	var p := PaletteData.load_from("res://content/palette.json")
	for id: String in tables.sprigs.keys():
		assert_true(p.colors.has(tables.sprig(id).colour_key), "sprig colour " + id)
	for id: String in tables.enemies.keys():
		assert_true(p.colors.has(tables.enemy(id).colour_key), "enemy colour " + id)
	for id: String in tables.hazards.keys():
		assert_true(p.colors.has(tables.hazard(id).colour_key), "hazard colour " + id)


func test_pellet_seed_rule() -> void:
	for id: String in tables.objects.keys():
		var o: Types.ObjectType = tables.object(id)
		if o.kind == "pellet":
			assert_true(o.max_carriers >= o.weight * 2, id)
			assert_true(o.seeds_match >= o.seeds_other, id)


func test_world_numbers() -> void:
	assert_gt(tables.w("day_seconds"), tables.w("night_seconds"))
	assert_gt(tables.wn("knight", "speed"), 0.0)
	assert_lt(tables.wn("knight", "contact_at"), tables.wn("knight", "swing_seconds"))
	assert_gt(tables.wi("field_cap_start"), 0)
