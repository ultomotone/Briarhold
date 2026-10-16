## The ground drawn from the heightfield: non-indexed triangles with a flat normal each, so it
## reads faceted; the colour comes from the shader below (height and slope against the palette). The same vertex arrays feed the navmesh bake.
class_name TerrainView
extends MeshInstance3D

var arrays: Array = []


func build(field: Heightfield, pal: PaletteData) -> void:
	var size: float = field.size
	var seg: int = mini(int(size), 256) # about one-metre quads, capped so a wider field costs the same
	var half: float = size * 0.5
	var step: float = size / float(seg)
	# every height once: a grid vertex is shared by four quads
	var hs := PackedFloat32Array()
	hs.resize((seg + 1) * (seg + 1))
	for i: int in seg + 1:
		for j: int in seg + 1:
			hs[i * (seg + 1) + j] = field.height_at(-half + float(i) * step, -half + float(j) * step)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	verts.resize(seg * seg * 6)
	norms.resize(seg * seg * 6)
	var k: int = 0
	for i: int in seg:
		for j: int in seg:
			var x0: float = -half + float(i) * step
			var z0: float = -half + float(j) * step
			var x1: float = x0 + step
			var z1: float = z0 + step
			var p00 := Vector3(x0, hs[i * (seg + 1) + j], z0)
			var p10 := Vector3(x1, hs[(i + 1) * (seg + 1) + j], z0)
			var p01 := Vector3(x0, hs[i * (seg + 1) + j + 1], z1)
			var p11 := Vector3(x1, hs[(i + 1) * (seg + 1) + j + 1], z1)
			# alternate the diagonal so the facets do not all lean one way
			if ((i + j) % 2) == 0:
				k = _tri(verts, norms, k, p00, p01, p11)
				k = _tri(verts, norms, k, p00, p11, p10)
			else:
				k = _tri(verts, norms, k, p00, p01, p10)
				k = _tri(verts, norms, k, p10, p01, p11)
	arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
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
	mat.set_shader_parameter("clover", pal.col("terrain_clover"))
	mat.set_shader_parameter("path", pal.col("terrain_path"))
	m.surface_set_material(0, mat)
	mesh = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Godot front faces wind clockwise: emit a, c, b so the face points up. Returns the next index.
func _tri(verts: PackedVector3Array, norms: PackedVector3Array, k: int, a: Vector3, b: Vector3, c: Vector3) -> int:
	var n: Vector3 = (b - a).cross(c - a).normalized()
	if n.y < 0.0:
		n = -n
	verts[k] = a
	verts[k + 1] = c
	verts[k + 2] = b
	norms[k] = n
	norms[k + 1] = n
	norms[k + 2] = n
	return k + 3


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
uniform vec4 clover : source_color;
uniform vec4 path : source_color;
varying vec3 wpos;
varying vec3 wnorm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float cc = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(cc, d, f.x), f.y);
}
void fragment() {
	float h = wpos.y;
	float slope = (1.0 - wnorm.y) * 2.2;
	float dt = clamp((h - dry_start) / max(0.001, dry_end - dry_start), 0.0, 1.0);
	vec3 c = mix(moss.rgb, loam.rgb, dt * 0.6);
	c = mix(c, dry.rgb, dt * dt);
	float st = clamp((slope - stone_start) / max(0.001, stone_end - stone_start), 0.0, 1.0);
	// patches: clover in the low ground, worn bare earth here and there
	float patch_n = vnoise(wpos.xz * 0.055) * 0.65 + vnoise(wpos.xz * 0.16 + 9.0) * 0.35;
	c = mix(c, clover.rgb, smoothstep(0.56, 0.72, patch_n) * 0.75 * (1.0 - dt));
	float bare = vnoise(wpos.xz * 0.035 + 17.0) * 0.7 + vnoise(wpos.xz * 0.2 - 4.0) * 0.3;
	c = mix(c, path.rgb, smoothstep(0.66, 0.78, bare) * 0.6);
	c = mix(c, stone.rgb, st);
	// one shade per ground cell so the facets read as facets, not as a gradient
	float v = hash2(floor(wpos.xz));
	c *= (1.0 - noise_v * 0.5 + noise_v * v);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.08;
}
"""
