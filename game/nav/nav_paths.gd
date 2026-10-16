## PathProvider over NavigationServer3D. Two navmeshes from the same ground, stones, and closed
## gates: map A also walls off every hazard zone, map B does not. A carrier group that is immune
## to every hazard its B route crosses takes the B route (Tide sprigs through the pools); any
## other group takes A, around the hazards. A group that all flies goes straight over everything.
## Rebakes when the sim says the walkable set changed. The sim only ever sees path().
class_name NavPaths
extends PathProvider

var map: RID # A: hazards walled off (the world's own navigation map)
var map_b: RID # B: hazards open
var region: RID
var region_b: RID
var baked: bool = false
var _zones: Array[Dictionary] = [] # {"pos", "r", "id"}
var _queued: bool = false # a bake was asked for while one was running
var _w: SimWorld
var _arrays: Array = []

## Navmesh grid in metres. 0.35 is fine against a 0.3 m agent and about half the work of 0.25.
const CELL: float = 0.35


func _init(nav_map: RID) -> void:
	map = nav_map
	map_b = NavigationServer3D.map_create()
	for m: RID in [map, map_b]:
		NavigationServer3D.map_set_cell_size(m, CELL)
		NavigationServer3D.map_set_cell_height(m, CELL)
	NavigationServer3D.map_set_active(map_b, true)


## background: bake on a worker thread and swap the new navmesh in when it is done; the old one
## keeps serving until then (a gate falling must not freeze play). The first bake is in place.
func bake(w: SimWorld, terrain_arrays: Array, background: bool = false) -> void:
	_w = w
	_arrays = terrain_arrays
	if _pending > 0:
		_queued = true # finish the running bake first, then bake again with what changed
		return
	var src_a := NavigationMeshSourceGeometryData3D.new()
	var src_b := NavigationMeshSourceGeometryData3D.new()
	# the terrain is non-indexed triangles; add_faces takes them as they are
	var verts: PackedVector3Array = terrain_arrays[Mesh.ARRAY_VERTEX]
	src_a.add_faces(verts, Transform3D.IDENTITY)
	src_b.add_faces(verts, Transform3D.IDENTITY)
	for ob: Dictionary in w.obstacles:
		var c: Vector3 = ob["pos"]
		var faces: PackedVector3Array = _cylinder_faces(c, float(ob["r"]), float(ob["h"]))
		src_a.add_faces(faces, Transform3D.IDENTITY)
		src_b.add_faces(faces, Transform3D.IDENTITY)
	for g: Entities.Gate in w.gates:
		if g.open:
			continue
		var faces: PackedVector3Array = _box_faces(g.pos, g.yaw, g.width, 1.1, 2.4)
		src_a.add_faces(faces, Transform3D.IDENTITY)
		src_b.add_faces(faces, Transform3D.IDENTITY)
	_zones.clear()
	for z: Entities.HazardZone in w.hazards:
		_zones.append({"pos": z.pos, "r": z.radius, "id": z.hazard_id})
		src_a.add_faces(_cylinder_faces(z.pos, z.radius + 0.4, 1.5, 14), Transform3D.IDENTITY)
	if not region.is_valid():
		region = NavigationServer3D.region_create()
		NavigationServer3D.region_set_map(region, map)
		region_b = NavigationServer3D.region_create()
		NavigationServer3D.region_set_map(region_b, map_b)
	var nm_a: NavigationMesh = _new_mesh()
	var nm_b: NavigationMesh = _new_mesh()
	if not background:
		NavigationServer3D.bake_from_source_geometry_data(nm_a, src_a)
		NavigationServer3D.bake_from_source_geometry_data(nm_b, src_b)
		NavigationServer3D.region_set_navigation_mesh(region, nm_a)
		NavigationServer3D.region_set_navigation_mesh(region_b, nm_b)
		baked = true
		generation += 1
		return
	_pending = 2
	NavigationServer3D.bake_from_source_geometry_data_async(nm_a, src_a, func() -> void: _swap_in.call_deferred(region, nm_a))
	NavigationServer3D.bake_from_source_geometry_data_async(nm_b, src_b, func() -> void: _swap_in.call_deferred(region_b, nm_b))


var _pending: int = 0


func _swap_in(r: RID, nm: NavigationMesh) -> void:
	if not r.is_valid():
		return # disposed while baking
	NavigationServer3D.region_set_navigation_mesh(r, nm)
	_pending -= 1
	if _pending <= 0:
		baked = true
		generation += 1 # both swapped: carriers ask again
		if _queued:
			_queued = false
			bake(_w, _arrays, true)


static func _new_mesh() -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.3
	nm.agent_height = 0.6
	nm.agent_max_climb = 0.6
	nm.agent_max_slope = 60.0
	nm.cell_size = CELL
	nm.cell_height = CELL
	nm.region_min_size = 4.0
	nm.edge_max_error = 1.0
	return nm


func is_ready() -> bool:
	return baked


func path(from: Vector3, to: Vector3, avoid: PackedStringArray = PackedStringArray(), fly: bool = false) -> PackedVector3Array:
	if fly:
		return PackedVector3Array([from, to])
	if not baked:
		return PackedVector3Array() # still working the routes out
	var pb: PackedVector3Array = _query(map_b, from, to)
	if pb.is_empty():
		return pb # walled off even ignoring hazards: no way from here
	if avoid.is_empty() or not _crosses(pb, avoid):
		return pb
	return _query(map, from, to)


func _query(m: RID, from: Vector3, to: Vector3) -> PackedVector3Array:
	var p: PackedVector3Array = NavigationServer3D.map_get_path(m, from + Vector3(0.0, 0.3, 0.0), to + Vector3(0.0, 0.3, 0.0), true)
	if p.size() < 2:
		return PackedVector3Array()
	# the server returns a path to the nearest reachable point; short of the goal is no path
	var end: Vector3 = p[p.size() - 1]
	if Vector2(end.x - to.x, end.z - to.z).length() > 2.5:
		return PackedVector3Array()
	p[0] = from
	p[p.size() - 1] = to
	return p


func _crosses(p: PackedVector3Array, avoid: PackedStringArray) -> bool:
	for z: Dictionary in _zones:
		if not avoid.has(str(z["id"])):
			continue
		var c: Vector3 = z["pos"]
		var r: float = float(z["r"])
		for i: int in p.size() - 1:
			if _seg_dist(Vector2(c.x, c.z), Vector2(p[i].x, p[i].z), Vector2(p[i + 1].x, p[i + 1].z)) < r:
				return true
	return false


static func _seg_dist(c: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = 0.0
	if ab.length_squared() > 0.000001:
		t = clampf((c - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return c.distance_to(a + ab * t)


## Free the server objects; the old world's navmesh must not linger under the next one.
func dispose() -> void:
	if region.is_valid():
		NavigationServer3D.free_rid(region)
	if region_b.is_valid():
		NavigationServer3D.free_rid(region_b)
	if map_b.is_valid():
		NavigationServer3D.free_rid(map_b)
	region = RID()
	region_b = RID()
	map_b = RID()
	baked = false


static func _cylinder_faces(c: Vector3, r: float, h: float, n: int = 10) -> PackedVector3Array:
	var out: PackedVector3Array = []
	var top: float = c.y + h
	var bot: float = c.y - 1.0
	for i: int in n:
		var a0: float = float(i) / float(n) * TAU
		var a1: float = float(i + 1) / float(n) * TAU
		var p0 := Vector3(c.x + sin(a0) * r, bot, c.z + cos(a0) * r)
		var p1 := Vector3(c.x + sin(a1) * r, bot, c.z + cos(a1) * r)
		var p2 := Vector3(c.x + sin(a1) * r, top, c.z + cos(a1) * r)
		var p3 := Vector3(c.x + sin(a0) * r, top, c.z + cos(a0) * r)
		out.append_array(PackedVector3Array([p0, p2, p1, p0, p3, p2]))
		# cap
		out.append_array(PackedVector3Array([Vector3(c.x, top, c.z), p3, p2]))
	return out


static func _box_faces(c: Vector3, yaw: float, w: float, d: float, h: float) -> PackedVector3Array:
	var ax := Vector3(cos(yaw), 0.0, -sin(yaw)) * (w * 0.5)
	var az := Vector3(sin(yaw), 0.0, cos(yaw)) * (d * 0.5)
	var lo: float = c.y - 1.0
	var hi: float = c.y + h
	var corners: Array[Vector3] = [c - ax - az, c + ax - az, c + ax + az, c - ax + az]
	var out: PackedVector3Array = []
	for i: int in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var a0 := Vector3(a.x, lo, a.z)
		var b0 := Vector3(b.x, lo, b.z)
		var a1 := Vector3(a.x, hi, a.z)
		var b1 := Vector3(b.x, hi, b.z)
		out.append_array(PackedVector3Array([a0, b1, b0, a0, a1, b1]))
	var t: Array[Vector3] = []
	for i: int in 4:
		t.append(Vector3(corners[i].x, hi, corners[i].z))
	out.append_array(PackedVector3Array([t[0], t[1], t[2], t[0], t[2], t[3]]))
	return out
