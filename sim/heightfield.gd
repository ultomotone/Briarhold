## The ground: a seeded fBm value-noise heightfield, flattened around the Hold at the origin.
## Pure RefCounted; the view builds a mesh from it, the sim samples it, the navmesh bakes from it.
## Never store heights: the field is a function of the seed and regenerates on load (the baked
## grids below are a cache of that function, rebuilt every time).
class_name Heightfield
extends RefCounted

var size: float = 160.0
var bound: float = 74.0
var amplitude: float = 5.5
var frequency: float = 0.028
var hold_radius: float = 9.0
var seed_n: int = 1
## Pool basins: (x, z, radius, level). Flat bottom inside the radius, a bank blending back to the
## natural ground over 0.7 radius. Part of the field's shape, so the save regenerates them.
var basins: Array[Vector4] = []
const BASIN_DEPTH: float = 0.35
## Level clearings (campsites, boss arenas): (x, z, radius, level). Flat inside the radius,
## blending back to the natural ground by 1.8 radius. Seeded, so the save regenerates them.
var clearings: Array[Vector4] = []
## Biome noise, one slow field each. See biome().
const BIOME_FREQ: float = 0.0105
## Climate: the world has a cold side and a hot side, a wet side and a dry side, each a seeded
## direction (so no two worlds face the same way and nothing is symmetric) bent by slow noise.
## Owner verdict 2026-10-20: "biomes slowly transitioning, arctic, desert, jungle".
var cold_dir: Vector2 = Vector2(1.0, 0.0)
var wet_dir: Vector2 = Vector2(0.0, 1.0)


func _init(seed_value: int = 1, world: Dictionary = {}) -> void:
	seed_n = seed_value & 0x7FFFFFFF
	if not world.is_empty():
		size = float(world.get("size", size))
		bound = float(world.get("bound", bound))
		amplitude = float(world.get("terrain_amplitude", amplitude))
		frequency = float(world.get("terrain_frequency", frequency))
		hold_radius = float(world.get("hold_radius", hold_radius))
	var ca: float = _hash2(17, 991) * TAU
	cold_dir = Vector2(cos(ca), sin(ca))
	# the wet side is somewhere off the cold axis, never along it
	var wa: float = ca + PI * (0.3 + 0.4 * _hash2(53, 271)) * (1.0 if _hash2(7, 7) < 0.5 else -1.0)
	wet_dir = Vector2(cos(wa), sin(wa))
	_bake_maps()


func _hash2(x: int, y: int) -> float:
	var h: int = ((x * 374761393) ^ (y * 668265263) ^ (seed_n * 1274126177)) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return float((h ^ (h >> 16)) & 0xFFFFFFFF) / 4294967295.0


## Value noise, the hash written out in place (this is the hottest function in the game).
func noise2(x: float, y: float) -> float:
	var xi: int = int(floorf(x))
	var yi: int = int(floorf(y))
	var xf: float = x - float(xi)
	var yf: float = y - float(yi)
	var u: float = xf * xf * (3.0 - 2.0 * xf)
	var v: float = yf * yf * (3.0 - 2.0 * yf)
	var s: int = seed_n * 1274126177
	var hx0: int = xi * 374761393
	var hx1: int = hx0 + 374761393
	var hy0: int = yi * 668265263
	var hy1: int = hy0 + 668265263
	var h: int = (hx0 ^ hy0 ^ s) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	var a: float = float((h ^ (h >> 16)) & 0xFFFFFFFF)
	h = (hx1 ^ hy0 ^ s) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	var b: float = float((h ^ (h >> 16)) & 0xFFFFFFFF)
	h = (hx0 ^ hy1 ^ s) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	var c: float = float((h ^ (h >> 16)) & 0xFFFFFFFF)
	h = (hx1 ^ hy1 ^ s) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	var d: float = float((h ^ (h >> 16)) & 0xFFFFFFFF)
	return ((a * (1.0 - u) + b * u) * (1.0 - v) + (c * (1.0 - u) + d * u) * v) / 4294967295.0


# ---- baked maps --------------------------------------------------------------------------------
# The far climates and the temperate biomes change over hundreds of metres, so they are sampled
# once per seed on a 4 m grid (cached across worlds of the same seed and size) and read back
# bilinearly. Heights are sampled on a 2 m grid once the world's basins and clearings are all in
# (bake_heights(), called by Worldgen); before that, and in tests that never bake, height_at runs
# the noise directly. Everything is a function of the seed, so the bake is deterministic.

const MAP_STEP: float = 4.0
const H_STEP: float = 2.0
static var _map_cache: Dictionary = {}
var _mn: int = 0
var _map: PackedFloat32Array = [] # 7 per cell: arctic, desert, jungle, wood, rock, marsh, garden
var _hn: int = 0
var _hmap: PackedFloat32Array = []


func _bake_maps() -> void:
	var key: String = "%d:%s:%s:%s" % [seed_n, size, bound, hold_radius]
	if _map_cache.has(key):
		var cached: Array = _map_cache[key]
		_mn = int(cached[0])
		_map = cached[1]
		return
	_mn = int(ceilf(size / MAP_STEP)) + 1
	var arr := PackedFloat32Array()
	arr.resize(_mn * _mn * 7)
	var half: float = size * 0.5
	for i: int in _mn:
		for j: int in _mn:
			var x: float = -half + float(i) * MAP_STEP
			var z: float = -half + float(j) * MAP_STEP
			var cl: Vector3 = _climate_raw(x, z)
			var tb: Vector4 = _temperate(x, z)
			var k: int = (i * _mn + j) * 7
			arr[k] = cl.x
			arr[k + 1] = cl.y
			arr[k + 2] = cl.z
			arr[k + 3] = tb.x
			arr[k + 4] = tb.y
			arr[k + 5] = tb.z
			arr[k + 6] = tb.w
	_map = arr
	_map_cache[key] = [_mn, _map]


func _map_at(x: float, z: float, ch: int) -> float:
	var half: float = size * 0.5
	var fx: float = clampf((x + half) / MAP_STEP, 0.0, float(_mn - 1) - 0.001)
	var fz: float = clampf((z + half) / MAP_STEP, 0.0, float(_mn - 1) - 0.001)
	var i: int = int(fx)
	var j: int = int(fz)
	var tx: float = fx - float(i)
	var tz: float = fz - float(j)
	var k00: int = (i * _mn + j) * 7 + ch
	var k10: int = k00 + _mn * 7
	return lerpf(lerpf(_map[k00], _map[k10], tx), lerpf(_map[k00 + 7], _map[k10 + 7], tx), tz)


## Sample every height once, now that the basins and clearings are in. Worldgen calls this.
func bake_heights() -> void:
	_hmap = PackedFloat32Array()
	_hn = 0
	var n: int = int(ceilf(size / H_STEP)) + 1
	var arr := PackedFloat32Array()
	arr.resize(n * n)
	var half: float = size * 0.5
	for i: int in n:
		for j: int in n:
			arr[i * n + j] = _height_raw(-half + float(i) * H_STEP, -half + float(j) * H_STEP)
	_hmap = arr
	_hn = n


func is_baked() -> bool:
	return _hn > 0


func height_at(x: float, z: float) -> float:
	if _hn == 0:
		return _height_raw(x, z)
	var half: float = size * 0.5
	var fx: float = clampf((x + half) / H_STEP, 0.0, float(_hn - 1) - 0.001)
	var fz: float = clampf((z + half) / H_STEP, 0.0, float(_hn - 1) - 0.001)
	var i: int = int(fx)
	var j: int = int(fz)
	var tx: float = fx - float(i)
	var tz: float = fz - float(j)
	var k00: int = i * _hn + j
	var k10: int = k00 + _hn
	return lerpf(lerpf(_hmap[k00], _hmap[k10], tx), lerpf(_hmap[k00 + 1], _hmap[k10 + 1], tx), tz)


## Basins and clearings, bucketed by 32 m cell so a height sample checks only the few near it.
const FEAT_CELL: float = 32.0
var _feat: Dictionary = {}
var _feat_n: int = -1


func _feat_index() -> void:
	var n: int = basins.size() * 1000 + clearings.size()
	if n == _feat_n:
		return
	_feat.clear()
	for kind: int in 2:
		var list: Array[Vector4] = clearings if kind == 0 else basins
		for idx: int in list.size():
			var f: Vector4 = list[idx]
			var reach: float = f.z * (1.8 if kind == 0 else 1.7)
			for gx: int in range(floori((f.x - reach) / FEAT_CELL), floori((f.x + reach) / FEAT_CELL) + 1):
				for gz: int in range(floori((f.y - reach) / FEAT_CELL), floori((f.y + reach) / FEAT_CELL) + 1):
					var key := Vector3i(gx, gz, kind)
					var arr: PackedInt32Array = PackedInt32Array(_feat[key]) if _feat.has(key) else PackedInt32Array()
					arr = arr.duplicate()
					arr.append(idx)
					_feat[key] = arr
	_feat_n = n


## Rolling overgrown ground with a level clearing for the Hold: the noise itself.
func _height_raw(x: float, z: float) -> float:
	var h: float = 0.0
	var amp: float = 1.0
	var f: float = frequency
	var tot: float = 0.0
	for i: int in 4:
		h += noise2(x * f + float(i) * 31.7, z * f - float(i) * 17.3) * amp
		tot += amp
		amp *= 0.5
		f *= 2.13
	h = (h / tot - 0.5) * 2.0 * amplitude
	# rough country: a slow noise scales the relief, so there are downs and there are hills
	var rough: float = 0.55 + noise2(x * frequency * 0.22 + 101.0, z * frequency * 0.22 - 57.0) * 1.1
	h *= rough * 0.85
	# ridges: sharp-crested folds where the country is roughest, so the hills have spines
	var rn: float = noise2(x * frequency * 0.75 + 55.0, z * frequency * 0.75 - 23.0)
	var ridge: float = 1.0 - absf(rn * 2.0 - 1.0)
	h += ridge * ridge * ridge * amplitude * 0.5 * clampf((rough - 0.75) * 1.6, 0.0, 1.0)
	# rocky country stands up in crags; marsh country sinks low and flat
	var cl: Vector3 = climate(x, z)
	var temperate: float = clampf(1.0 - cl.x - cl.y - cl.z, 0.0, 1.0)
	var rock: float = _map_at(x, z, 4) * temperate
	h += rock * (0.4 + ridge * ridge) * amplitude * 0.55
	var marsh: float = _map_at(x, z, 5) * temperate
	h = lerpf(h, h * 0.25 - amplitude * 0.18, marsh)
	# the far climates shape the ground too: dunes in the desert, rounded drifts in the arctic,
	# lumpy close country in the jungle
	if cl.y > 0.001:
		var along: float = x * wet_dir.y - z * wet_dir.x
		var dune: float = 0.5 + 0.5 * sin(along * 0.085 + noise2(x * 0.02 + 33.0, z * 0.02 - 71.0) * 5.0)
		h = lerpf(h, h * 0.35 + dune * dune * amplitude * 0.75, cl.y)
	if cl.x > 0.001:
		h = lerpf(h, h * 0.7 + amplitude * 0.25, cl.x)
	if cl.z > 0.001:
		h += cl.z * (noise2(x * 0.06 - 11.0, z * 0.06 + 29.0) - 0.4) * amplitude * 0.5
	h = clampf(h, -amplitude * 1.65, amplitude * 1.65)
	# the clearing: flat within hold_radius, blending out over the same distance again
	var r: float = sqrt(x * x + z * z)
	var t: float = clampf((r - hold_radius) / hold_radius, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	h *= t
	_feat_index()
	var cell_x: int = floori(x / FEAT_CELL)
	var cell_z: int = floori(z / FEAT_CELL)
	for ci: int in _feat.get(Vector3i(cell_x, cell_z, 0), PackedInt32Array()):
		var clr: Vector4 = clearings[ci]
		var cx: float = x - clr.x
		var cz: float = z - clr.y
		var creach: float = clr.z * 1.8
		if absf(cx) > creach or absf(cz) > creach:
			continue
		var cd: float = sqrt(cx * cx + cz * cz)
		if cd <= clr.z:
			h = clr.w
		elif cd < creach:
			var cu: float = (cd - clr.z) / (creach - clr.z)
			cu = cu * cu * (3.0 - 2.0 * cu)
			h = lerpf(clr.w, h, cu)
	for bi: int in _feat.get(Vector3i(cell_x, cell_z, 1), PackedInt32Array()):
		var b: Vector4 = basins[bi]
		var dx: float = x - b.x
		var dz: float = z - b.y
		var reach: float = b.z * 1.7
		if absf(dx) > reach or absf(dz) > reach:
			continue
		var d: float = sqrt(dx * dx + dz * dz)
		if d <= b.z:
			return b.w - BASIN_DEPTH
		if d < reach:
			var u: float = (d - b.z) / (reach - b.z)
			u = u * u * (3.0 - 2.0 * u)
			h = lerpf(b.w, h, u)
	return h


## Level a clearing here at the natural height of its centre.
func add_clearing(x: float, z: float, radius: float) -> float:
	var level: float = height_at(x, z)
	clearings.append(Vector4(x, z, radius, level))
	_hn = 0
	return level


func _fade_home(x: float, z: float) -> float:
	var r: float = sqrt(x * x + z * z)
	return clampf((r - hold_radius * 2.5) / (hold_radius * 2.5), 0.0, 1.0)


func _rock_w(x: float, z: float) -> float:
	var n: float = noise2(x * BIOME_FREQ - 150.0, z * BIOME_FREQ + 40.0)
	return smoothstep(0.6, 0.72, n) * (1.0 - _wood_raw(x, z)) * _fade_home(x, z)


func _marsh_w(x: float, z: float) -> float:
	var n: float = noise2(x * BIOME_FREQ * 1.2 + 90.0, z * BIOME_FREQ * 1.2 + 310.0)
	return smoothstep(0.62, 0.74, n) * (1.0 - _wood_raw(x, z)) * _fade_home(x, z)


func _wood_raw(x: float, z: float) -> float:
	return smoothstep(0.52, 0.64, noise2(x * BIOME_FREQ + 200.0, z * BIOME_FREQ - 80.0))


## The far climates here, 0..1 each: x arctic, y desert, z jungle. Temperature runs along the
## world's cold direction, moisture along its wet direction, both bent by very slow noise, so a
## walk outward changes the climate gradually and the bands are never straight. The country
## round the Hold is temperate.
func climate(x: float, z: float) -> Vector3:
	return Vector3(_map_at(x, z, 0), _map_at(x, z, 1), _map_at(x, z, 2))


func _climate_raw(x: float, z: float) -> Vector3:
	var r: float = sqrt(x * x + z * z)
	var near: float = clampf((r - 45.0) / 70.0, 0.0, 1.0)
	if near <= 0.0:
		return Vector3.ZERO
	var p := Vector2(x, z)
	var temp: float = -p.dot(cold_dir) / maxf(1.0, bound) * 0.9 + (noise2(x * 0.0055 + 500.0, z * 0.0055 - 300.0) - 0.5) * 0.9
	var wet: float = p.dot(wet_dir) / maxf(1.0, bound) * 0.7 + (noise2(x * 0.007 - 700.0, z * 0.007 + 120.0) - 0.5) * 1.0
	temp *= near
	var arctic: float = 1.0 - smoothstep(-0.58, -0.3, temp)
	var hot: float = smoothstep(0.28, 0.55, temp)
	var damp: float = smoothstep(-0.18, 0.18, wet)
	return Vector3(arctic, hot * (1.0 - damp), hot * damp)


## How much of each temperate biome is here, 0..1 each: x woodland, y rocky, z marsh, w garden.
## Whatever is left of the temperate share is meadow; the far climates (climate()) take the rest.
## Slow noise, so each biome is a region you walk into and out of; the Hold's surroundings are
## meadow.
func biome(x: float, z: float) -> Vector4:
	var cl: Vector3 = climate(x, z)
	var temperate: float = clampf(1.0 - cl.x - cl.y - cl.z, 0.0, 1.0)
	return Vector4(_map_at(x, z, 3), _map_at(x, z, 4), _map_at(x, z, 5), _map_at(x, z, 6)) * temperate


func _temperate(x: float, z: float) -> Vector4:
	var home: float = _fade_home(x, z)
	var wood: float = _wood_raw(x, z) * home
	var rock: float = _rock_w(x, z)
	var marsh: float = _marsh_w(x, z) * (1.0 - rock)
	var garden: float = smoothstep(0.6, 0.72, noise2(x * BIOME_FREQ * 0.9 - 260.0, z * BIOME_FREQ * 0.9 - 190.0))
	garden *= (1.0 - wood) * (1.0 - rock) * (1.0 - marsh) * home
	return Vector4(wood, rock, marsh, garden)


## Sink a pool into the ground here: level is the natural height at the centre.
func add_basin(x: float, z: float, radius: float) -> float:
	var level: float = height_at(x, z)
	basins.append(Vector4(x, z, radius, level))
	_hn = 0
	return level


## 0..1 steepness.
func slope_at(x: float, z: float) -> float:
	var e: float = 0.6
	var hx: float = height_at(x + e, z) - height_at(x - e, z)
	var hz: float = height_at(x, z + e) - height_at(x, z - e)
	return minf(1.0, sqrt(hx * hx + hz * hz) / (2.0 * e))


func normal_at(x: float, z: float) -> Vector3:
	var e: float = 0.5
	var hx: float = height_at(x + e, z) - height_at(x - e, z)
	var hz: float = height_at(x, z + e) - height_at(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()


func clamp_bound(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, -bound, bound), p.y, clampf(p.z, -bound, bound))


func ground(p: Vector3) -> Vector3:
	return Vector3(p.x, height_at(p.x, p.z), p.z)


## Ray against the field: march then bisect. Returns Vector3.INF on a miss.
func raycast(origin: Vector3, dir: Vector3, max_dist: float = 200.0) -> Vector3:
	var d: Vector3 = dir.normalized()
	var step: float = 0.35
	var t: float = 0.0
	var prev: Vector3 = origin
	while t < max_dist:
		t += step
		var p: Vector3 = origin + d * t
		if p.y <= height_at(p.x, p.z):
			var lo: Vector3 = prev
			var hi: Vector3 = p
			for i: int in 10:
				var mid: Vector3 = (lo + hi) * 0.5
				if mid.y <= height_at(mid.x, mid.z):
					hi = mid
				else:
					lo = mid
			return ground(hi)
		prev = p
	return Vector3.INF
