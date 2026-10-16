## The ground: a seeded fBm value-noise heightfield, flattened around the Hold at the origin.
## Pure RefCounted; the view builds a mesh from it, the sim samples it, the navmesh bakes from it.
## Never store heights: the field is a function of the seed and regenerates on load.
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


func _init(seed_value: int = 1, world: Dictionary = {}) -> void:
	seed_n = seed_value & 0x7FFFFFFF
	if not world.is_empty():
		size = float(world.get("size", size))
		bound = float(world.get("bound", bound))
		amplitude = float(world.get("terrain_amplitude", amplitude))
		frequency = float(world.get("terrain_frequency", frequency))
		hold_radius = float(world.get("hold_radius", hold_radius))


func _hash2(x: int, y: int) -> float:
	var h: int = ((x * 374761393) ^ (y * 668265263) ^ (seed_n * 1274126177)) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return float((h ^ (h >> 16)) & 0xFFFFFFFF) / 4294967295.0


func noise2(x: float, y: float) -> float:
	var xi: int = int(floorf(x))
	var yi: int = int(floorf(y))
	var xf: float = x - float(xi)
	var yf: float = y - float(yi)
	var u: float = xf * xf * (3.0 - 2.0 * xf)
	var v: float = yf * yf * (3.0 - 2.0 * yf)
	var a: float = _hash2(xi, yi)
	var b: float = _hash2(xi + 1, yi)
	var c: float = _hash2(xi, yi + 1)
	var d: float = _hash2(xi + 1, yi + 1)
	return (a * (1.0 - u) + b * u) * (1.0 - v) + (c * (1.0 - u) + d * u) * v


## Rolling overgrown ground with a level clearing for the Hold.
func height_at(x: float, z: float) -> float:
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
	h = clampf(h, -amplitude * 1.65, amplitude * 1.65)
	# the clearing: flat within hold_radius, blending out over the same distance again
	var r: float = sqrt(x * x + z * z)
	var t: float = clampf((r - hold_radius) / hold_radius, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	h *= t
	for b: Vector4 in basins:
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


## Sink a pool into the ground here: level is the natural height at the centre.
func add_basin(x: float, z: float, radius: float) -> float:
	var level: float = height_at(x, z)
	basins.append(Vector4(x, z, radius, level))
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
