extends GutTest


func test_same_seed_same_ground() -> void:
	var a := Heightfield.new(7)
	var b := Heightfield.new(7)
	for i: int in 50:
		var x: float = float(i) * 3.1 - 70.0
		assert_almost_eq(a.height_at(x, -x * 0.5), b.height_at(x, -x * 0.5), 0.000001)


func test_different_seed_different_ground() -> void:
	var a := Heightfield.new(1)
	var b := Heightfield.new(2)
	var diff: float = 0.0
	for i: int in 50:
		var x: float = float(i) * 3.1 - 70.0
		diff += absf(a.height_at(x, 20.0) - b.height_at(x, 20.0))
	assert_gt(diff, 1.0)


func test_hold_clearing_is_flat() -> void:
	var h := Heightfield.new(3)
	for i: int in 24:
		var ang: float = float(i) * 0.26
		var r: float = h.hold_radius * 0.9
		assert_almost_eq(h.height_at(cos(ang) * r, sin(ang) * r), 0.0, 0.0001)


func test_height_within_amplitude() -> void:
	var h := Heightfield.new(11)
	for i: int in 400:
		var x: float = float(i % 20) * 7.0 - 70.0
		var z: float = float(i / 20) * 7.0 - 70.0
		var y: float = h.height_at(x, z)
		# rough country scales relief up to 1.65x in the hills
		assert_true(absf(y) <= h.amplitude * 1.7, "height %f within amplitude" % y)


func test_raycast_hits_ground() -> void:
	var h := Heightfield.new(5)
	var origin := Vector3(10.0, 30.0, 10.0)
	var hit: Vector3 = h.raycast(origin, Vector3(0.2, -1.0, 0.1), 100.0)
	assert_ne(hit, Vector3.INF)
	assert_almost_eq(hit.y, h.height_at(hit.x, hit.z), 0.05)


func test_raycast_misses_sky() -> void:
	var h := Heightfield.new(5)
	assert_eq(h.raycast(Vector3(0, 10, 0), Vector3(0, 1, 0), 50.0), Vector3.INF)
