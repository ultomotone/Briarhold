extends GutTest


func test_query_finds_neighbours_sorted() -> void:
	var h := SpatialHash.new(1.0)
	h.insert(5, Vector3(0.2, 0, 0.2))
	h.insert(2, Vector3(0.9, 0, -0.4))
	h.insert(9, Vector3(4.0, 0, 4.0))
	var r: PackedInt32Array = h.query(Vector3.ZERO, 1.5)
	assert_eq(r, PackedInt32Array([2, 5]))


func test_query_radius_is_exact_not_cell() -> void:
	var h := SpatialHash.new(2.0)
	h.insert(1, Vector3(1.9, 0, 0))
	assert_eq(h.query(Vector3.ZERO, 1.0).size(), 0)
	assert_eq(h.query(Vector3.ZERO, 2.0).size(), 1)


func test_clear() -> void:
	var h := SpatialHash.new(1.0)
	h.insert(1, Vector3.ZERO)
	h.clear()
	assert_eq(h.query(Vector3.ZERO, 5.0).size(), 0)
