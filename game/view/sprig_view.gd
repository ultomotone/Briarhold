## Every sprig on screen: one MultiMesh per type (one draw call each), instance colour for the
## type tint and state (burning, selected type), custom data for the idle bob phase. Sprouts use
## the same mesh, half-buried, scaled by maturity.
class_name SprigView
extends Node3D

const MAX_PER_TYPE: int = 128

var pal: PaletteData
var tables: ContentTables
var _mm: Dictionary = {} # type_id -> MultiMeshInstance3D
var _sprout_mm: Dictionary = {} # type_id -> MultiMeshInstance3D
var _mesh: ArrayMesh
var _shader: Shader


func build(p: PaletteData, t: ContentTables) -> void:
	pal = p
	tables = t
	_mesh = _make_mesh()
	_shader = Shader.new()
	_shader.code = SHADER
	for id: String in tables.sprig_order:
		_mm[id] = _make_mm(id, false)
		_sprout_mm[id] = _make_mm(id, true)


func _make_mm(type_id: String, sprout: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.instance_count = MAX_PER_TYPE
	mm.visible_instance_count = 0
	mm.mesh = _mesh
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("tint", pal.col(tables.sprig(type_id).colour_key))
	mat.set_shader_parameter("stalk", pal.col("scatter_stalk"))
	mat.set_shader_parameter("buried", 1.0 if sprout else 0.0)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	return mi


## Called per frame. alpha interpolates prev->pos.
func update(w: SimWorld, alpha: float, selected: String) -> void:
	var counts: Dictionary = {}
	var xf := Transform3D.IDENTITY
	for s: Entities.Sprig in w.sprigs:
		if s.state == Entities.Sprig.State.DEAD:
			continue
		var mi: MultiMeshInstance3D = _mm.get(s.type_id)
		if mi == null:
			continue
		var i: int = int(counts.get(s.type_id, 0))
		if i >= MAX_PER_TYPE:
			continue
		counts[s.type_id] = i + 1
		var p: Vector3 = s.prev.lerp(s.pos, alpha)
		var flying: bool = s.state == Entities.Sprig.State.THROWN
		xf = Transform3D(Basis(Vector3.UP, s.yaw), p)
		if flying:
			xf = xf.rotated_local(Vector3.RIGHT, -0.6)
		var mm: MultiMesh = mi.multimesh
		mm.set_instance_transform(i, xf)
		var col := Color(1.0, 1.0, 1.0, 1.0)
		if s.status == "burning":
			col = Color(2.2, 0.8, 0.3, 1.0)
		elif s.status == "poisoned":
			col = Color(0.8, 1.6, 0.6, 1.0)
		elif s.status == "frozen":
			col = Color(0.7, 1.2, 1.8, 1.0)
		elif s.state == Entities.Sprig.State.FOLLOW and s.type_id == selected:
			col = Color(1.25, 1.25, 1.25, 1.0)
		elif s.state == Entities.Sprig.State.IDLE:
			col = Color(0.85, 0.85, 0.85, 1.0)
		mm.set_instance_color(i, col)
		var moving: float = 1.0 if (s.state == Entities.Sprig.State.FOLLOW or s.state == Entities.Sprig.State.CHARGE or s.state == Entities.Sprig.State.CARRY) else 0.0
		mm.set_instance_custom_data(i, Color(s.phase, float(s.maturity), moving, 1.0 if s.latched else 0.0))
	for id: String in _mm.keys():
		var mi: MultiMeshInstance3D = _mm[id]
		mi.multimesh.visible_instance_count = int(counts.get(id, 0))
	# sprouts: half-buried, growing with maturity; a seed in flight arcs from the shrine
	var scounts: Dictionary = {}
	var g: float = 14.0
	for sp: Entities.Sprout in w.sprouts:
		var mi: MultiMeshInstance3D = _sprout_mm.get(sp.type_id)
		if mi == null:
			continue
		var i: int = int(scounts.get(sp.type_id, 0))
		if i >= MAX_PER_TYPE:
			continue
		scounts[sp.type_id] = i + 1
		var p: Vector3 = sp.pos
		var scale: float = 0.7 + 0.25 * float(sp.maturity)
		if sp.fl_t >= 0.0:
			p = Throw.point_at(sp.fl_start, sp.pos, sp.fl_total, g, sp.fl_t)
			scale = 0.5
		var b := Basis(Vector3.UP, float(sp.id) * 0.7).scaled(Vector3(scale, scale, scale))
		mi.multimesh.set_instance_transform(i, Transform3D(b, p))
		mi.multimesh.set_instance_color(i, Color(0.9, 0.9, 0.9, 1.0))
		mi.multimesh.set_instance_custom_data(i, Color(float(sp.id) * 0.37, float(sp.maturity), 0.0, 1.0 if sp.fl_t >= 0.0 else 0.0))
	for id: String in _sprout_mm.keys():
		var mi: MultiMeshInstance3D = _sprout_mm[id]
		mi.multimesh.visible_instance_count = int(scounts.get(id, 0))


## A sprig: a bulb body, a thin stalk, a leaf on top. Vertex colour picks tint vs stalk in the shader.
static func _make_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# body: low-poly sphere
	_sphere(st, Vector3(0.0, 0.22, 0.0), 0.2, 8, 5, Color(1.0, 0.0, 0.0))
	# head
	_sphere(st, Vector3(0.0, 0.5, 0.0), 0.15, 8, 5, Color(1.0, 0.0, 0.0))
	# stalk
	_cyl(st, Vector3(0.0, 0.62, 0.0), Vector3(0.0, 0.95, 0.0), 0.02, 5, Color(0.0, 1.0, 0.0))
	# leaf: two triangles, double-sided by cull_disabled
	var l0 := Vector3(0.0, 0.95, 0.0)
	var l1 := Vector3(0.12, 1.02, 0.1)
	var l2 := Vector3(0.0, 1.16, 0.22)
	var l3 := Vector3(-0.12, 1.02, 0.1)
	_quad(st, l0, l1, l2, l3, Color(0.0, 0.0, 1.0))
	# feet
	_sphere(st, Vector3(0.09, 0.05, 0.05), 0.06, 6, 3, Color(1.0, 0.0, 0.0))
	_sphere(st, Vector3(-0.09, 0.05, 0.05), 0.06, 6, 3, Color(1.0, 0.0, 0.0))
	st.generate_normals()
	return st.commit()


static func _sphere(st: SurfaceTool, c: Vector3, r: float, seg: int, rings: int, col: Color) -> void:
	for i: int in rings:
		var t0: float = PI * float(i) / float(rings)
		var t1: float = PI * float(i + 1) / float(rings)
		for j: int in seg:
			var p0: float = TAU * float(j) / float(seg)
			var p1: float = TAU * float(j + 1) / float(seg)
			var a: Vector3 = c + Vector3(sin(t0) * cos(p0), cos(t0), sin(t0) * sin(p0)) * r
			var b: Vector3 = c + Vector3(sin(t0) * cos(p1), cos(t0), sin(t0) * sin(p1)) * r
			var cc: Vector3 = c + Vector3(sin(t1) * cos(p1), cos(t1), sin(t1) * sin(p1)) * r
			var d: Vector3 = c + Vector3(sin(t1) * cos(p0), cos(t1), sin(t1) * sin(p0)) * r
			_quad(st, a, b, cc, d, col)


static func _cyl(st: SurfaceTool, a: Vector3, b: Vector3, r: float, seg: int, col: Color) -> void:
	for j: int in seg:
		var p0: float = TAU * float(j) / float(seg)
		var p1: float = TAU * float(j + 1) / float(seg)
		var o0 := Vector3(cos(p0), 0.0, sin(p0)) * r
		var o1 := Vector3(cos(p1), 0.0, sin(p1)) * r
		_quad(st, a + o0, a + o1, b + o1, b + o0, col)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, _col: Color) -> void:
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)
	st.add_vertex(a)
	st.add_vertex(d)
	st.add_vertex(c)


const SHADER: String = """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 stalk : source_color = vec4(0.5, 0.45, 0.3, 1.0);
uniform float buried = 0.0;
varying float part; // 0 body, 1 stalk, 2 leaf
varying vec4 icol;
void vertex() {
	float phase = INSTANCE_CUSTOM.x;
	float maturity = INSTANCE_CUSTOM.y;
	float moving = INSTANCE_CUSTOM.z;
	part = VERTEX.y < 0.61 ? 0.0 : (VERTEX.y < 0.945 ? 1.0 : 2.0);
	float w = clamp(VERTEX.y - 0.5, 0.0, 1.0);
	VERTEX.x += sin(TIME * 2.2 + phase * 6.283) * 0.04 * w;
	VERTEX.z += sin(TIME * 1.7 + phase * 4.1) * 0.03 * w;
	VERTEX.y += moving * abs(sin(TIME * 9.0 + phase * 6.283)) * 0.05;
	if (part > 1.5) {
		vec3 tip = vec3(0.0, 0.95, 0.0);
		VERTEX = tip + (VERTEX - tip) * (1.0 + maturity * 0.55);
	}
	if (buried > 0.5) {
		VERTEX.y -= 0.42;
	}
	icol = INSTANCE_CUSTOM;
}
void fragment() {
	vec3 leaf = mix(vec3(0.38, 0.62, 0.24), vec3(0.96, 0.84, 0.5), clamp(icol.y - 1.0, 0.0, 1.0));
	vec3 body = part < 0.5 ? tint.rgb : (part < 1.5 ? stalk.rgb : leaf);
	ALBEDO = body * COLOR.rgb;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}
"""
