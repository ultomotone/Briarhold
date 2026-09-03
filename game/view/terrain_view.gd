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
	# Colour comes from a shader over world height and flat normal, with the palette as
	# source_color uniforms: vertex colours on an ArrayMesh did not survive Forward+ intact.
	var sh := Shader.new()
	sh.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("moss", pal.col("terrain_moss"))
	mat.set_shader_parameter("loam", pal.col("terrain_loam"))
	mat.set_shader_parameter("dry", pal.col("terrain_dry"))
	mat.set_shader_parameter("stone", pal.col("terrain_stone"))
	mat.set_shader_parameter("dry_start", pal.num("terrain_dry_height_start"))
	mat.set_shader_parameter("dry_end", pal.num("terrain_dry_height_end"))
	mat.set_shader_parameter("stone_start", pal.num("terrain_stone_slope_start"))
	mat.set_shader_parameter("stone_end", pal.num("terrain_stone_slope_end"))
	mat.set_shader_parameter("noise_v", pal.num("terrain_noise_v"))
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
	# Forward+ reads vertex colours as linear whatever the material flag says; convert here so
	# the palette's sRGB moss arrives as moss and not as pale olive
	var col: Color = pal.terrain(h, slope * 2.2, v).srgb_to_linear()
	# Godot front faces wind clockwise: emit a, c, b so the face points up
	verts.append(a)
	verts.append(c)
	verts.append(b)
	for i: int in 3:
		norms.append(n)
		cols.append(col)


const SHADER: String = """
shader_type spatial;
uniform vec4 moss : source_color;
uniform vec4 loam : source_color;
uniform vec4 dry : source_color;
uniform vec4 stone : source_color;
uniform float dry_start = 2.0;
uniform float dry_end = 7.0;
uniform float stone_start = 0.42;
uniform float stone_end = 0.75;
uniform float noise_v = 0.12;
varying vec3 wpos;
varying vec3 wnorm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
void fragment() {
	float h = wpos.y;
	float slope = (1.0 - wnorm.y) * 2.2;
	float dt = clamp((h - dry_start) / max(0.001, dry_end - dry_start), 0.0, 1.0);
	vec3 c = mix(moss.rgb, loam.rgb, dt * 0.6);
	c = mix(c, dry.rgb, dt * dt);
	float st = clamp((slope - stone_start) / max(0.001, stone_end - stone_start), 0.0, 1.0);
	c = mix(c, stone.rgb, st);
	// one shade per ground cell so the facets read as facets, not as a gradient
	float v = hash2(floor(wpos.xz));
	c *= (1.0 - noise_v * 0.5 + noise_v * v);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.08;
}
"""
