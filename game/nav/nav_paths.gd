## PathProvider over NavigationServer3D. Bakes one navmesh from the terrain triangles plus the
## stones and every closed gate; rebakes when the sim says the walkable set changed. The sim
## only ever sees path(): a list of ground points.
class_name NavPaths
extends PathProvider

var map: RID
var region: RID
var baked: bool = false


func _init(nav_map: RID) -> void:
	map = nav_map


func bake(w: SimWorld, terrain_arrays: Array) -> void:
	var src := NavigationMeshSourceGeometryData3D.new()
	# the terrain is non-indexed triangles; add_faces takes them as they are
	var verts: PackedVector3Array = terrain_arrays[Mesh.ARRAY_VERTEX]
	src.add_faces(verts, Transform3D.IDENTITY)
	for ob: Dictionary in w.obstacles:
		var c: Vector3 = ob["pos"]
		var r: float = float(ob["r"])
		var h: float = float(ob["h"])
		src.add_faces(_cylinder_faces(c, r, h), Transform3D.IDENTITY)
	for nb: Dictionary in w.nav_blockers:
		var c: Vector3 = nb["pos"]
		src.add_faces(_cylinder_faces(c, float(nb["r"]), 1.5, 14), Transform3D.IDENTITY)
	for g: Entities.Gate in w.gates:
		if g.open:
			continue
		src.add_faces(_box_faces(g.pos, g.yaw, g.width, 1.1, 2.4), Transform3D.IDENTITY)
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.3
	nm.agent_height = 0.6
	nm.agent_max_climb = 0.6
	nm.agent_max_slope = 60.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.region_min_size = 4.0
	nm.edge_max_error = 1.0
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	if not region.is_valid():
		region = NavigationServer3D.region_create()
		NavigationServer3D.region_set_map(region, map)
	NavigationServer3D.region_set_navigation_mesh(region, nm)
	baked = true
	generation += 1


func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	if not baked:
		return PackedVector3Array([from, to])
	var p: PackedVector3Array = NavigationServer3D.map_get_path(map, from + Vector3(0.0, 0.3, 0.0), to + Vector3(0.0, 0.3, 0.0), true)
	if p.size() < 2:
		return PackedVector3Array([from, to])
	p[0] = from
	p[p.size() - 1] = to
	return p


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
