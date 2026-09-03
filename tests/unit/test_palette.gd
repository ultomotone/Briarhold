extends GutTest

var p: PaletteData


func before_all() -> void:
	p = PaletteData.load_from("res://content/palette.json")


func test_loads() -> void:
	assert_gt(p.colors.size(), 10)
	assert_gt(p.numbers.size(), 3)


func test_fog_and_sky_share_a_seam() -> void:
	# The fog colour must sit near the horizon colour so air and sky read as one.
	assert_lt(_dist(p.col("fog_day"), p.col("sky_horizon_day")), 0.12)
	assert_lt(_dist(p.col("fog_night"), p.col("sky_horizon_night")), 0.12)


func test_night_is_darker_than_day() -> void:
	assert_lt(p.num("sun_energy_night"), p.num("sun_energy_day"))
	assert_lt(p.num("ambient_energy_night"), p.num("ambient_energy_day"))
	assert_lt(PaletteData.luminance(p.col("sky_zenith_night")), PaletteData.luminance(p.col("sky_zenith_day")))


func test_sprig_types_are_distinguishable() -> void:
	var keys: PackedStringArray = []
	for k: String in p.colors.keys():
		if k.begins_with("sprig_"):
			keys.append(k)
	assert_gt(keys.size(), 7)
	for i: int in keys.size():
		for j: int in keys.size():
			if j <= i:
				continue
			var a: Color = p.col(keys[i])
			var b: Color = p.col(keys[j])
			assert_gt(_dist(a, b), 0.18, "%s vs %s" % [keys[i], keys[j]])


func test_sprigs_read_against_the_ground() -> void:
	# No sprig may vanish into the moss: hue or luminance must separate them.
	var moss: Color = p.col("terrain_moss")
	for k: String in p.colors.keys():
		if k.begins_with("sprig_"):
			assert_gt(_dist(p.col(k), moss), 0.2, k)


func test_hud_ink_on_glass_contrast() -> void:
	assert_gt(PaletteData.luminance(p.col("hud_ink")) - PaletteData.luminance(p.col("hud_glass")), 0.6)


func _dist(a: Color, b: Color) -> float:
	return sqrt(pow(a.r - b.r, 2.0) + pow(a.g - b.g, 2.0) + pow(a.b - b.b, 2.0))
