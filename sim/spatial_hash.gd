## Uniform-grid neighbour lookup on the XZ plane. Rebuilt each tick; query results come back
## sorted by id so iteration order is deterministic.
class_name SpatialHash
extends RefCounted

var cell: float = 1.0
var _cells: Dictionary = {} # Vector2i -> PackedInt32Array
var _pos: Dictionary = {} # id -> Vector3


func _init(cell_size: float = 1.0) -> void:
	cell = cell_size


## The box round everything inserted this tick: a query that cannot reach it returns at once
## (a beast asleep far across the field costs nothing).
var _lo: Vector2 = Vector2(INF, INF)
var _hi: Vector2 = Vector2(-INF, -INF)


func clear() -> void:
	_cells.clear()
	_pos.clear()
	_lo = Vector2(INF, INF)
	_hi = Vector2(-INF, -INF)


func insert(id: int, p: Vector3) -> void:
	_lo = Vector2(minf(_lo.x, p.x), minf(_lo.y, p.z))
	_hi = Vector2(maxf(_hi.x, p.x), maxf(_hi.y, p.z))
	var k := Vector2i(int(floorf(p.x / cell)), int(floorf(p.z / cell)))
	if not _cells.has(k):
		_cells[k] = PackedInt32Array()
	var arr: PackedInt32Array = _cells[k]
	arr.append(id)
	_cells[k] = arr
	_pos[id] = p


func query(p: Vector3, r: float) -> PackedInt32Array:
	var out: PackedInt32Array = []
	if p.x < _lo.x - r or p.x > _hi.x + r or p.z < _lo.y - r or p.z > _hi.y + r:
		return out
	var r2: float = r * r
	var cx: int = int(floorf(p.x / cell))
	var cz: int = int(floorf(p.z / cell))
	var span: int = int(ceilf(r / cell))
	for dx: int in range(-span, span + 1):
		for dz: int in range(-span, span + 1):
			var k := Vector2i(cx + dx, cz + dz)
			if not _cells.has(k):
				continue
			var arr: PackedInt32Array = _cells[k]
			for id: int in arr:
				var q: Vector3 = _pos[id]
				var ddx: float = q.x - p.x
				var ddz: float = q.z - p.z
				if ddx * ddx + ddz * ddz <= r2:
					out.append(id)
	out.sort()
	return out


func position_of(id: int) -> Vector3:
	return _pos.get(id, Vector3.INF)
