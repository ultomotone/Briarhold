## The ground drawn from the heightfield: non-indexed triangles with a face colour each, so it
## reads faceted with no shader work. The same vertex arrays feed the navmesh bake.
class_name TerrainView
extends MeshInstance3D

var arrays: Array = []


func build(field: Heightfield, pal: PaletteData) -> void:
	var size: float = field.size
	var seg: int = int(size) # one-unit quads
	var half: float = size * 0.5
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var step: float = size / float(seg)
	for i: int in seg:
		for j: int in seg:
			var x0: float = -half + float(i) * step
			var z0: float = -half + float(j) * step
			var x1: float = x0 + step
			var z1: float = z0 + step
			var p00 := Vector3(x0, field.height_at(x0, z0), z0)
			var p10 := Vector3(x1, field.height_at(x1, z0), z0)
			var p01 := Vector3(x0, field.height_at(x0, z1), z1)
			var p11 := Vector3(x1, field.height_at(x1, z1), z1)
			# alternate the diagonal so the facets do not all lean one way
			var flip: bool = ((i + j) % 2) == 0
			if flip:
				_tri(verts, norms, cols, field, pal, p00, p01, p11)
				_tri(verts, norms, cols, field, pal, p00, p11, p10)
			else:
				_tri(verts, norms, cols, field, pal, p00, p01, p10)
				_tri(verts, norms, cols, field, pal, p10, p01, p11)
	arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true # palette colours are sRGB; read as linear they grey out
	mat.roughness = 1.0
	mat.metallic = 0.0
	m.surface_set_material(0, mat)
	mesh = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _tri(verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, field: Heightfield, pal: PaletteData, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n: Vector3 = (b - a).cross(c - a).normalized()
	if n.y < 0.0:
		n = -n
	var cx: float = (a.x + b.x + c.x) / 3.0
	var cz: float = (a.z + b.z + c.z) / 3.0
	var h: float = (a.y + b.y + c.y) / 3.0
	var slope: float = 1.0 - n.y
	var v: float = field.noise2(cx * 0.35 + 11.0, cz * 0.35 - 7.0)
	var col: Color = pal.terrain(h, slope * 2.2, v)
	verts.append(a)
	verts.append(b)
	verts.append(c)
	for i: int in 3:
		norms.append(n)
		cols.append(col)
