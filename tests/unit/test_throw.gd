extends GutTest


func test_endpoints_are_exact() -> void:
	var a := Vector3(0, 1, 0)
	var b := Vector3(6, 0.5, 2)
	assert_eq(Throw.point_at(a, b, 0.6, 22.0, 0.0), a)
	assert_almost_eq(Throw.point_at(a, b, 0.6, 22.0, 0.6).distance_to(b), 0.0, 0.0001)


func test_peak_is_midway_and_above_chord() -> void:
	var a := Vector3(0, 0, 0)
	var b := Vector3(4, 0, 0)
	var mid: Vector3 = Throw.point_at(a, b, 0.6, 22.0, 0.3)
	assert_almost_eq(mid.y, Throw.peak_height(0.6, 22.0), 0.0001)
	assert_gt(mid.y, 0.5)


func test_arc_points_count() -> void:
	assert_eq(Throw.arc_points(Vector3.ZERO, Vector3.ONE, 0.6, 22.0, 24).size(), 25)


func test_clamp_target_respects_range() -> void:
	var from := Vector3(0, 0, 0)
	var far := Vector3(30, 0, 40)
	var c: Vector3 = Throw.clamp_target(from, far, 7.0)
	assert_almost_eq(Vector2(c.x, c.z).length(), 7.0, 0.001)
	var near := Vector3(2, 0, 1)
	assert_eq(Throw.clamp_target(from, near, 7.0), near)
