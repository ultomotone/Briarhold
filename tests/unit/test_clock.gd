extends GutTest


func test_day_then_night_then_dawn() -> void:
	var c := Clock.new(100.0, 40.0, 10.0)
	var seen: PackedStringArray = []
	for i: int in 150:
		for ev: String in c.advance(1.0):
			seen.append(ev)
	assert_eq(seen, PackedStringArray(["dusk_warning", "night", "dawn"]))
	assert_eq(c.day, 2)
	assert_false(c.is_night())


func test_sun_t_clamps() -> void:
	var c := Clock.new(100.0, 40.0, 10.0)
	c.time = 50.0
	assert_almost_eq(c.sun_t(), 0.5, 0.0001)
	c.time = 120.0
	assert_almost_eq(c.sun_t(), 1.0, 0.0001)
	assert_almost_eq(c.night_t(), 0.5, 0.0001)


func test_offline_is_capped() -> void:
	var c := Clock.new(100.0, 40.0, 10.0)
	var nights: int = c.advance_offline(1000000.0, 3)
	assert_eq(nights, 3)
	assert_eq(c.day, 4)
	assert_almost_eq(c.time, 0.0, 0.0001)


func test_offline_partial_counts_entering_night() -> void:
	var c := Clock.new(100.0, 40.0, 10.0)
	c.time = 90.0
	assert_eq(c.advance_offline(30.0, 7), 1)
	assert_true(c.is_night())
	assert_eq(c.day, 1)
