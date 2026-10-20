## The ground drawn from the heightfield. Smooth normals (soft rolling ground, not facets), and a
## ground colour per vertex from the biome and the climate there, blended, so meadow shades into
## woodland floor, marsh, rock, snow, sand or jungle floor over tens of metres. The colour rides
## UV/UV2 as linear floats (vertex colours on an ArrayMesh did not survive Forward+ intact); the
## shader adds slope rock, clover and bare patches, snow sparkle and sand ripples. The same vertex
## arrays feed the navmesh bake.
class_name TerrainView
extends MeshInstance3D

var arrays: Array = []


func build(field: Heightfield, pal: PaletteData) -> void:
	var size: float = field.size
	var seg: int = int(ceilf(size / Heightfield.H_STEP)) # one quad per baked height sample
	var half: float = size * 0.5
	var step: float = size / float(seg)
	var n1: int = seg + 1
	# every height and every ground colour once per grid vertex
	var hs := PackedFloat32Array()
	hs.resize(n1 * n1)
	var cols := PackedColorArray()
	cols.resize(n1 * n1)
	var snow_sand := PackedFloat32Array()
	snow_sand.resize(n1 * n1)
	var c_meadow: Color = pal.col("terrain_moss").srgb_to_linear()
	var c_wood: Color = pal.col("terrain_wood").srgb_to_linear()
	var c_rock: Color = pal.col("terrain_rock").srgb_to_linear()
	var c_marsh: Color = pal.col("terrain_marsh").srgb_to_linear()
	var c_garden: Color = pal.col("terrain_garden").srgb_to_linear()
	var c_snow: Color = pal.col("snow").srgb_to_linear()
	var c_sand: Color = pal.col("sand").srgb_to_linear()
	var c_jungle: Color = pal.col("jungle_canopy").darkened(0.1).srgb_to_linear()
	for i: int in n1:
		for j: int in n1:
			var x: float = -half + float(i) * step
			var z: float = -half + float(j) * step
			var idx: int = i * n1 + j
			hs[idx] = field.height_at(x, z)
			var cl: Vector3 = field.climate(x, z)
			var bw: Vector4 = field.biome(x, z)
			var meadow: float = clampf(1.0 - bw.x - bw.y - bw.z - bw.w - cl.x - cl.y - cl.z, 0.0, 1.0)
			var c: Color = c_meadow * meadow + c_wood * bw.x + c_rock * bw.y + c_marsh * bw.z + c_garden * bw.w
			c += c_snow * cl.x + c_sand * cl.y + c_jungle * cl.z
			cols[idx] = c
			snow_sand[idx] = cl.x - cl.y
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var count: int = seg * seg * 6
	verts.resize(count)
	norms.resize(count)
	uv.resize(count)
	uv2.resize(count)
	var k: int = 0
	for i: int in seg:
		for j: int in seg:
			var q: Array[int] = [i * n1 + j, (i + 1) * n1 + j, i * n1 + j + 1, (i + 1) * n1 + j + 1]
			var tris: Array[int]
			# alternate the diagonal so the ground does not all lean one way
			if ((i + j) % 2) == 0:
				tris = [q[0], q[3], q[2], q[0], q[1], q[3]]
			else:
				tris = [q[0], q[1], q[2], q[1], q[3], q[2]]
			for t: int in tris:
				var gi: int = t / n1
				var gj: int = t % n1
				verts[k] = Vector3(-half + float(gi) * step, hs[t], -half + float(gj) * step)
				norms[k] = _normal(hs, n1, gi, gj, step)
				var c: Color = cols[t]
				uv[k] = Vector2(c.r, c.g)
				uv2[k] = Vector2(c.b, snow_sand[t])
				k += 1
	arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var sh := Shader.new()
	sh.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("loam", pal.col("terrain_loam"))
	mat.set_shader_parameter("stone", pal.col("terrain_stone"))
	mat.set_shader_parameter("sandstone", pal.col("sandstone"))
	mat.set_shader_parameter("stone_start", pal.num("terrain_stone_slope_start"))
	mat.set_shader_parameter("stone_end", pal.num("terrain_stone_slope_end"))
	mat.set_shader_parameter("clover", pal.col("terrain_clover"))
	mat.set_shader_parameter("path", pal.col("terrain_path"))
	m.surface_set_material(0, mat)
	mesh = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Winding: the triangles above are listed so Godot's clockwise front face points up.
static func _normal(hs: PackedFloat32Array, n1: int, i: int, j: int, step: float) -> Vector3:
	var i0: int = maxi(i - 1, 0)
	var i1: int = mini(i + 1, n1 - 1)
	var j0: int = maxi(j - 1, 0)
	var j1: int = mini(j + 1, n1 - 1)
	var dx: float = (hs[i1 * n1 + j] - hs[i0 * n1 + j]) / (float(i1 - i0) * step)
	var dz: float = (hs[i * n1 + j1] - hs[i * n1 + j0]) / (float(j1 - j0) * step)
	return Vector3(-dx, 1.0, -dz).normalized()


const SHADER: String = """
shader_type spatial;
uniform vec4 loam : source_color;
uniform vec4 stone : source_color;
uniform vec4 sandstone : source_color;
uniform float stone_start = 0.42;
uniform float stone_end = 0.75;
uniform vec4 clover : source_color;
uniform vec4 path : source_color;
varying vec3 wpos;
varying vec3 wnorm;
varying vec3 ground;
varying float snow;
varying float sand;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	ground = vec3(UV.x, UV.y, UV2.x);
	snow = max(0.0, UV2.y);
	sand = max(0.0, -UV2.y);
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
	vec3 c = ground;
	float green = clamp(1.0 - snow - sand, 0.0, 1.0);
	float slope = (1.0 - wnorm.y) * 2.2;
	float st = clamp((slope - stone_start) / max(0.001, stone_end - stone_start), 0.0, 1.0);
	// patches: clover in the low ground, worn bare earth here and there (on green ground only)
	float patch_n = vnoise(wpos.xz * 0.055) * 0.65 + vnoise(wpos.xz * 0.16 + 9.0) * 0.35;
	c = mix(c, clover.rgb, smoothstep(0.56, 0.72, patch_n) * 0.55 * green);
	float bare = vnoise(wpos.xz * 0.035 + 17.0) * 0.7 + vnoise(wpos.xz * 0.2 - 4.0) * 0.3;
	c = mix(c, path.rgb, smoothstep(0.68, 0.8, bare) * 0.5 * green);
	// the sand ripples; the snow lies thinner on steep ground
	c *= 1.0 - sand * 0.06 * sin(wpos.x * 1.7 + wpos.z * 0.9 + vnoise(wpos.xz * 0.3) * 6.0);
	vec3 rock = mix(stone.rgb, sandstone.rgb, sand);
	c = mix(c, rock, st * (1.0 - snow * 0.6));
	// fine grain so close ground is never one flat colour: blades and pebbles at a glance
	float grain = vnoise(wpos.xz * 2.3) * 0.6 + vnoise(wpos.xz * 7.1) * 0.4;
	c *= 0.9 + 0.2 * grain * (green + sand * 0.5);
	c = mix(c, loam.rgb, smoothstep(0.82, 0.95, vnoise(wpos.xz * 0.9 + 3.0)) * 0.25 * green);
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.55, snow);
	SPECULAR = mix(0.12, 0.4, snow);
}
"""
