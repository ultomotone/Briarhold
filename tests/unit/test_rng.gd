extends GutTest


func test_fnv1a_empty_is_offset_basis() -> void:
	assert_eq(Rng.fnv1a(""), 2166136261)


func test_fnv1a_matches_reference_vectors() -> void:
	# Published FNV-1a 32-bit vectors; identical to the TypeScript seedNum for ASCII names.
	assert_eq(Rng.fnv1a("a"), 0xE40C292C)
	assert_eq(Rng.fnv1a("foobar"), 0xBF9CF968)


func test_stream_is_reproducible() -> void:
	var a := Rng.stream("world:1:test")
	var b := Rng.stream("world:1:test")
	for i: int in 100:
		assert_eq(a.next_u32(), b.next_u32())


func test_first_draw_is_pinned() -> void:
	# If this value changes, every seeded world changes. Bump only with a save migration.
	assert_eq(Rng.stream("pin").next_u32(), 219992754)


func test_streams_diverge() -> void:
	var a := Rng.stream("world:1:sprouts")
	var b := Rng.stream("world:1:raids")
	var same: int = 0
	for i: int in 1000:
		if a.next_u32() == b.next_u32():
			same += 1
	assert_lt(same, 3)


func test_randf_in_unit_interval() -> void:
	var r := Rng.stream("unit")
	for i: int in 2000:
		var f: float = r.randf()
		assert_true(f >= 0.0 and f < 1.0)


func test_randi_range_inclusive() -> void:
	var r := Rng.stream("range")
	var seen := {}
	for i: int in 500:
		var v: int = r.randi_range(3, 5)
		assert_true(v >= 3 and v <= 5)
		seen[v] = true
	assert_eq(seen.size(), 3)


## Regression (2026-10-16): randi_range, randf_range and pick_weighted called a bare randf(),
## which inside this class is the engine's global randf(). Same name, same sequence, always.
func test_every_draw_kind_is_reproducible() -> void:
	var a := Rng.stream("repro")
	var b := Rng.stream("repro")
	for i: int in 64:
		assert_eq(a.randi_range(0, 9), b.randi_range(0, 9))
		assert_eq(a.randf_range(-2.0, 2.0), b.randf_range(-2.0, 2.0))
		assert_eq(a.pick_weighted(PackedFloat32Array([1.0, 2.0, 3.0])), b.pick_weighted(PackedFloat32Array([1.0, 2.0, 3.0])))
	assert_eq(a._a, b._a)


func test_pick_weighted_respects_zero() -> void:
	var r := Rng.stream("weights")
	for i: int in 200:
		assert_eq(r.pick_weighted(PackedFloat32Array([0.0, 5.0, 0.0])), 1)
