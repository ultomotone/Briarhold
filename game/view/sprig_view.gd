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
var _yaw: Dictionary = {} # id -> displayed facing (eased toward the sim's)
var _born: Dictionary = {} # id -> time first drawn (the pluck pop)
var _primed: bool = false


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
	mat.set_shader_parameter("wings", 1.0 if tables.sprig(type_id).wings else 0.0)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	return mi


## Called per frame. alpha interpolates prev->pos; delta and now drive the easing and the pops.
func update(w: SimWorld, alpha: float, selected: String, delta: float, now: float) -> void:
	var counts: Dictionary = {}
	var xf := Transform3D.IDENTITY
	var turn: float = clampf(delta * 14.0, 0.0, 1.0)
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
		var t: Types.SprigType = tables.sprig(s.type_id)
		var p: Vector3 = s.prev.lerp(s.pos, alpha)
		# facing eases instead of snapping
		var yaw: float = s.yaw
		if _yaw.has(s.id):
			yaw = lerp_angle(float(_yaw[s.id]), s.yaw, turn)
		_yaw[s.id] = yaw
		# a plucked sprig rises out of the ground with a little overshoot
		if not _born.has(s.id):
			_born[s.id] = now if _primed else -10.0
		var u: float = clampf((now - float(_born[s.id])) / 0.3, 0.0, 1.0)
		var pop_y: float = -0.5 * (1.0 - u) * (1.0 - u)
		var pop_s: float = 1.0 + 0.18 * sin(u * PI)
		var sc: float = t.scale * pop_s
		var b := Basis(Vector3.UP, yaw).scaled(Vector3(sc, sc, sc))
		xf = Transform3D(b, p + Vector3(0.0, pop_y, 0.0))
		if s.state == Entities.Sprig.State.THROWN:
			# one forward flip over the arc
			var fu: float = clampf(s.fl_t / maxf(0.01, s.fl_total), 0.0, 1.0)
			xf.basis = xf.basis * Basis(Vector3.RIGHT, -fu * TAU)
		var mm: MultiMesh = mi.multimesh
		mm.set_instance_transform(i, xf)
		var col := Color(1.0, 1.0, 1.0, 1.0)
		if s.status == "burning":
			col = Color(2.2, 0.8, 0.3, 1.0)
		elif s.status == "poisoned":
			col = Color(1.3, 0.8, 1.6, 1.0)
		elif s.status == "frozen":
			col = Color(0.7, 1.2, 1.8, 1.0)
		elif s.status == "shocked":
			col = Color(1.8, 1.7, 0.6, 1.0)
		elif s.status == "drowning":
			col = Color(0.6, 0.8, 1.5, 1.0)
		elif s.state == Entities.Sprig.State.FOLLOW and s.type_id == selected:
			col = Color(1.2, 1.2, 1.2, 1.0)
		elif s.state == Entities.Sprig.State.IDLE:
			col = Color(0.88, 0.88, 0.88, 1.0)
		mm.set_instance_color(i, col)
		# walk cycle strength from how fast it actually moved this tick, not from its state
		var d: Vector3 = s.pos - s.prev
		d.y = 0.0
		var spd: float = d.length() / SimWorld.FIXED_DT
		var walk: float = 0.0 if (s.latched or s.state == Entities.Sprig.State.THROWN) else clampf(spd / maxf(0.5, t.speed), 0.0, 1.0)
		mm.set_instance_custom_data(i, Color(s.phase, float(s.maturity), walk, 1.0 if s.latched else 0.0))
	if not _primed:
		_primed = true
	# forget the gone, now and then
	if _yaw.size() > w.sprigs.size() * 2 + 32:
		var keep: Dictionary = {}
		var keep_b: Dictionary = {}
		for s: Entities.Sprig in w.sprigs:
			if _yaw.has(s.id):
				keep[s.id] = _yaw[s.id]
			if _born.has(s.id):
				keep_b[s.id] = _born[s.id]
		_yaw = keep
		_born = keep_b
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
		var scale: float = 1.0
		if sp.fl_t >= 0.0:
			p = Throw.point_at(sp.fl_start, sp.pos, sp.fl_total, g, sp.fl_t)
			scale = 0.6
		var b := Basis(Vector3.UP, float(sp.id) * 0.7).scaled(Vector3(scale, scale, scale))
		mi.multimesh.set_instance_transform(i, Transform3D(b, p))
		mi.multimesh.set_instance_color(i, Color(0.9, 0.9, 0.9, 1.0))
		mi.multimesh.set_instance_custom_data(i, Color(float(sp.id) * 0.37, float(sp.maturity), 0.0, 1.0 if sp.fl_t >= 0.0 else 0.0))
	for id: String in _sprout_mm.keys():
		var mi: MultiMeshInstance3D = _sprout_mm[id]
		mi.multimesh.visible_instance_count = int(scounts.get(id, 0))


## A sprig (owner verdict 2026-09-02: cuter, closer to the reference creature's proportions):
## a big round head on a small body, two dark eyes, stick arms and legs, one stem out of the
## head with a leaf, a bud, or a bloom on it. Part ids ride UV.x so the shader can pick colours
## and show only the top that matches maturity. Parts: 0 body/head, 1 stem, 2 leaf, 3 bud,
## 4 petals, 5 bloom centre, 6 eyes, 7 limbs.
static func _make_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# legs
	_cyl(st, Vector3(-0.06, 0.0, 0.0), Vector3(-0.06, 0.2, 0.0), 0.025, 5, 7)
	_cyl(st, Vector3(0.06, 0.0, 0.0), Vector3(0.06, 0.2, 0.0), 0.025, 5, 7)
	_sphere(st, Vector3(-0.06, 0.02, 0.02), 0.035, 6, 3, 7)
	_sphere(st, Vector3(0.06, 0.02, 0.02), 0.035, 6, 3, 7)
	# body: a small bulb
	_sphere(st, Vector3(0.0, 0.3, 0.0), 0.14, 10, 6, 0)
	# arms: thin, angled down and a little forward
	_cyl(st, Vector3(-0.12, 0.36, 0.0), Vector3(-0.21, 0.22, 0.05), 0.02, 5, 7)
	_cyl(st, Vector3(0.12, 0.36, 0.0), Vector3(0.21, 0.22, 0.05), 0.02, 5, 7)
	# head: big and round, the whole character
	_sphere(st, Vector3(0.0, 0.58, 0.0), 0.21, 12, 8, 0)
	# eyes: two dark beads, forward (+z is the way it faces)
	_sphere(st, Vector3(-0.085, 0.6, 0.175), 0.045, 7, 4, 6)
	_sphere(st, Vector3(0.085, 0.6, 0.175), 0.045, 7, 4, 6)
	# stem from the crown
	_cyl(st, Vector3(0.0, 0.76, 0.0), Vector3(0.0, 1.02, 0.0), 0.018, 5, 1)
	# leaf (maturity 0)
	var l0 := Vector3(0.0, 1.0, 0.0)
	var l1 := Vector3(0.13, 1.06, 0.12)
	var l2 := Vector3(0.0, 1.2, 0.26)
	var l3 := Vector3(-0.13, 1.06, 0.12)
	_quad(st, l0, l1, l2, l3, 2)
	# bud (maturity 1)
	_sphere(st, Vector3(0.0, 1.07, 0.0), 0.075, 7, 4, 3)
	# bloom (maturity 2): five petals and a centre
	for i: int in 5:
		var a: float = float(i) / 5.0 * TAU
		var dir := Vector3(sin(a), 0.0, cos(a))
		var side := Vector3(cos(a), 0.0, -sin(a))
		var c := Vector3(0.0, 1.05, 0.0)
		_quad(st, c, c + dir * 0.09 + side * 0.07 + Vector3(0.0, 0.03, 0.0), c + dir * 0.19 + Vector3(0.0, 0.05, 0.0), c + dir * 0.09 - side * 0.07 + Vector3(0.0, 0.03, 0.0), 4)
	_sphere(st, Vector3(0.0, 1.06, 0.0), 0.05, 7, 4, 5)
	# wings (part 8): two thin panes on the back, shown only for flyers
	for sx: float in [-1.0, 1.0]:
		_quad(st, Vector3(0.04 * sx, 0.52, -0.1), Vector3(0.3 * sx, 0.6, -0.17), Vector3(0.27 * sx, 0.3, -0.18), Vector3(0.04 * sx, 0.32, -0.1), 8)
	st.generate_normals()
	return st.commit()


static func _sphere(st: SurfaceTool, c: Vector3, r: float, seg: int, rings: int, part: int) -> void:
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
			_quad(st, a, b, cc, d, part)


static func _cyl(st: SurfaceTool, a: Vector3, b: Vector3, r: float, seg: int, part: int) -> void:
	var axis: Vector3 = (b - a).normalized()
	var ref: Vector3 = Vector3.RIGHT if absf(axis.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var u: Vector3 = axis.cross(ref).normalized()
	var v: Vector3 = axis.cross(u).normalized()
	for j: int in seg:
		var p0: float = TAU * float(j) / float(seg)
		var p1: float = TAU * float(j + 1) / float(seg)
		var o0: Vector3 = (u * cos(p0) + v * sin(p0)) * r
		var o1: Vector3 = (u * cos(p1) + v * sin(p1)) * r
		_quad(st, a + o0, a + o1, b + o1, b + o0, part)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, part: int) -> void:
	var uv := Vector2(float(part), 0.0)
	st.set_uv(uv)
	st.add_vertex(a)
	st.set_uv(uv)
	st.add_vertex(c)
	st.set_uv(uv)
	st.add_vertex(b)
	st.set_uv(uv)
	st.add_vertex(a)
	st.set_uv(uv)
	st.add_vertex(d)
	st.set_uv(uv)
	st.add_vertex(c)


const SHADER: String = """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 stalk : source_color = vec4(0.5, 0.45, 0.3, 1.0);
uniform float buried = 0.0;
uniform float wings = 0.0;
varying float part;
varying vec4 icol;
void vertex() {
	float phase = INSTANCE_CUSTOM.x;
	float maturity = INSTANCE_CUSTOM.y;
	float moving = INSTANCE_CUSTOM.z;
	part = floor(UV.x + 0.5);
	vec3 crown = vec3(0.0, 1.0, 0.0);
	// only the top that matches maturity exists; the others collapse into the stem tip
	bool hide = (part == 2.0 && maturity > 0.5) || (part == 3.0 && (maturity < 0.5 || maturity > 1.5)) || ((part == 4.0 || part == 5.0) && maturity < 1.5);
	if (buried > 0.5 && (part == 0.0 || part == 6.0 || part == 7.0 || part == 8.0)) {
		hide = true;
	}
	if (part == 8.0 && wings < 0.5) {
		hide = true;
	}
	if (hide) {
		VERTEX = crown;
	}
	// the top sways; the body hops when walking; the head tilts a little with the step
	float w = clamp((VERTEX.y - 0.75) * 2.0, 0.0, 1.0);
	VERTEX.x += sin(TIME * 2.2 + phase * 6.283) * 0.05 * w;
	VERTEX.z += sin(TIME * 1.7 + phase * 4.1) * 0.035 * w;
	float step_ = sin(TIME * 11.0 + phase * 6.283);
	// limbs swing from hip and shoulder: legs (near the centre line) forward and back, arms against them
	if (part == 7.0) {
		float side = VERTEX.x < 0.0 ? -1.0 : 1.0;
		if (abs(VERTEX.x) < 0.1) {
			VERTEX.z += step_ * side * moving * (0.2 - VERTEX.y) * 1.8;
			VERTEX.y += max(0.0, step_ * side) * moving * 0.03 * (0.2 - VERTEX.y) * 5.0;
		} else {
			VERTEX.z -= step_ * side * moving * (0.36 - VERTEX.y) * 1.6;
		}
	}
	// wings beat fast whether walking or not
	if (part == 8.0) {
		float f = sin(TIME * 30.0 + phase * 6.283) * 0.5 + 0.5;
		VERTEX.x *= mix(1.0, 0.35, f);
		VERTEX.z -= abs(VERTEX.x) * 0.5 * f;
	}
	VERTEX.y += moving * abs(step_) * 0.04;
	if (buried > 0.5) {
		// a sprout is the stem and its top, out of the ground
		VERTEX.y -= 0.72;
	}
	icol = INSTANCE_CUSTOM;
}
void fragment() {
	vec3 leaf = vec3(0.4, 0.66, 0.26);
	vec3 col = tint.rgb;
	if (part == 1.0) { col = stalk.rgb; }
	else if (part == 2.0) { col = leaf; }
	else if (part == 3.0) { col = leaf * 0.85; }
	else if (part == 4.0) { col = vec3(0.98, 0.97, 0.9); }
	else if (part == 5.0) { col = vec3(1.0, 0.82, 0.25); }
	else if (part == 6.0) { col = vec3(0.06, 0.07, 0.1); }
	else if (part == 8.0) { col = mix(tint.rgb, vec3(1.0), 0.55); }
	ALBEDO = col * COLOR.rgb;
	ROUGHNESS = part == 6.0 ? 0.25 : 0.8;
	SPECULAR = part == 6.0 ? 0.6 : 0.25;
}
"""
