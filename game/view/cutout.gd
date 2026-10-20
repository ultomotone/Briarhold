## Materials for tall things (tree crowns, hollow logs, tipped pots, crags): wherever one stands
## between the camera and the gnome, a round window is dithered through it so he and his squad
## stay in sight. The gnome's position is the global shader parameter focus_pos, set each frame
## by Main. Everything else is an ordinary lit surface.
class_name Cutout
extends RefCounted

static var _shader: Shader
static var _shader_vc: Shader

const CODE: String = """
shader_type spatial;
render_mode cull_disabled;
global uniform vec3 focus_pos;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness = 0.9;
uniform float hole = 3.2;
uniform float use_vc = 0.0;
uniform float sheen = 0.0;
varying vec3 wpos;
varying vec3 wnrm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
float bayer4(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int idx = i.x + i.y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[idx] + 0.5) / 16.0;
}
void fragment() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 to_f = focus_pos - cam;
	float df = length(to_f);
	vec3 dir = to_f / max(df, 0.001);
	vec3 to_p = wpos - cam;
	float along = dot(to_p, dir);
	if (along < df - 0.6 && along > 0.0) {
		float off = length(to_p - dir * along);
		float r = hole * (0.45 + 0.55 * along / df);
		float keep = smoothstep(r * 0.65, r, off);
		if (keep < bayer4(FRAGCOORD.xy)) {
			discard;
		}
	}
	vec3 c = albedo.rgb;
	if (use_vc > 0.5) {
		c *= COLOR.rgb;
	}
	// a soft sky light from above, so the tops of things read brighter than their flanks
	c *= 0.82 + 0.18 * clamp(wnrm.y, 0.0, 1.0);
	ALBEDO = c;
	ROUGHNESS = roughness;
	SPECULAR = 0.25 + sheen;
}
"""


static func mat(c: Color, rough: float = 0.9, hole: float = 3.2) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODE
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("albedo", c)
	m.set_shader_parameter("roughness", rough)
	m.set_shader_parameter("hole", hole)
	return m


## For MultiMesh instances that carry their colour per instance.
static func mat_vc(rough: float = 0.95, hole: float = 3.2) -> ShaderMaterial:
	var m: ShaderMaterial = mat(Color.WHITE, rough, hole)
	m.set_shader_parameter("use_vc", 1.0)
	return m
