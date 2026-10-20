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
	mat.set_shader_parameter("nose", 1.0 if tables.sprig(type_id).feature == "nose" else 0.0)
	mat.set_shader_parameter("ears", 1.0 if tables.sprig(type_id).feature == "ears" else 0.0)
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


## A sprig. Owner verdicts: 2026-09-02 "cuter, like the real thing"; 2026-10-16 "leaves more
## leafy"; 2026-10-20 "look and feel more like these" (reference images of the genre). The
## proportions of the genre, made from our own primitives: a slim body on thin legs, thin arms,
## a big teardrop head that tapers up into a long stem, large eyes with dark pupils, and at the
## stem's tip a leaf, a bud, or a bloom by maturity. Some types carry a feature of their own:
## Embers a pointed nose, Sparks big swept ears (sprigs.json "feature"). Part ids ride UV.x;
## UV.y carries "distance from the midrib" on leaves and petals.
## Parts: 0 body/head, 1 stem, 2 leaf, 3 bud, 4 petals, 5 bloom centre, 6 pupils, 7 limbs,
## 8 wings, 9 eye whites and highlights, 10 (unused), 11 nose, 12 ears.
const CROWN := Vector3(0.03, 1.5, 0.0)
const HEAD_Y0: float = 0.47
const HEAD_Y1: float = 1.0


static func _head_r(u: float) -> float:
	return 0.18 * pow(sin(PI * pow(clampf(u, 0.0, 1.0), 0.62)), 0.85)


static func _make_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# legs: thin, with small round feet a little forward
	for sx: float in [-1.0, 1.0]:
		_cyl(st, Vector3(0.055 * sx, 0.03, 0.0), Vector3(0.05 * sx, 0.28, 0.0), 0.021, 6, 7)
		_ellip(st, Vector3(0.056 * sx, 0.025, 0.02), Vector3(0.032, 0.022, 0.048), 7, 4, 7)
	# body: slim, a little pear
	_ellip(st, Vector3(0.0, 0.37, 0.0), Vector3(0.085, 0.13, 0.08), 12, 7, 0)
	# arms: thin, hanging a little forward, tiny hands
	for sx: float in [-1.0, 1.0]:
		_cyl(st, Vector3(0.072 * sx, 0.45, 0.0), Vector3(0.165 * sx, 0.27, 0.045), 0.017, 5, 7)
		_sphere(st, Vector3(0.168 * sx, 0.262, 0.048), 0.024, 6, 4, 7)
	# head: a teardrop, round at the chin, widest low, tapering up into the stem
	_lathe(st, HEAD_Y0, HEAD_Y1, 16, 16, 0.92, 0)
	# eyes: big whites, dark pupils, one highlight each (+z is forward)
	for sx: float in [-1.0, 1.0]:
		_ellip(st, Vector3(0.07 * sx, 0.71, 0.138), Vector3(0.058, 0.072, 0.032), 10, 6, 9)
		_ellip(st, Vector3(0.067 * sx, 0.702, 0.163), Vector3(0.039, 0.05, 0.02), 8, 5, 6)
		_sphere(st, Vector3(0.067 * sx + 0.014, 0.726, 0.178), 0.013, 6, 3, 9)
	# Ember's nose: a short point forward from the middle of the face
	_cone(st, Vector3(0.0, 0.655, 0.14), Vector3(0.0, 0.67, 0.245), 0.034, 8, 11)
	# Spark's ears: big flat points swept back from the sides of the head
	for sx: float in [-1.0, 1.0]:
		var root := Vector3(0.15 * sx, 0.75, -0.01)
		var tip := Vector3(0.34 * sx, 0.88, -0.07)
		var up := Vector3(0.0, 0.07, 0.0)
		_tri_uv(st, root - up, tip, root + up, 0.0, 0.0, 0.0, 12)
	# stem: long and thin, a gentle curve from the head's point to the crown
	_cyl(st, Vector3(0.0, 0.98, 0.0), Vector3(0.0, 1.22, -0.015), 0.016, 6, 1)
	_cyl(st, Vector3(0.0, 1.22, -0.015), CROWN, 0.014, 6, 1)
	# leaf (maturity 0)
	_leaf(st, CROWN, 0.34, 0.12, 2)
	# bud (maturity 1): a pale teardrop with two small leaves under it
	_ellip(st, CROWN + Vector3(0.0, 0.075, 0.0), Vector3(0.058, 0.09, 0.058), 9, 6, 3)
	_ellip(st, CROWN + Vector3(0.0, 0.14, 0.0), Vector3(0.028, 0.038, 0.028), 6, 3, 3)
	_small_leaf(st, CROWN + Vector3(0.0, 0.02, 0.0), Vector3(0.11, 0.05, 0.02), 2)
	_small_leaf(st, CROWN + Vector3(0.0, 0.02, 0.0), Vector3(-0.11, 0.05, -0.02), 2)
	# bloom (maturity 2): five round petals and a centre
	for k: int in 5:
		var a: float = float(k) / 5.0 * TAU
		_petal(st, CROWN + Vector3(0.0, 0.04, 0.0), a, 0.16, 0.075, 4)
	_ellip(st, CROWN + Vector3(0.0, 0.055, 0.0), Vector3(0.05, 0.034, 0.05), 8, 4, 5)
	# wings (part 8): two thin panes on the back, shown only for flyers
	for sx: float in [-1.0, 1.0]:
		_quad(st, Vector3(0.04 * sx, 0.5, -0.07), Vector3(0.3 * sx, 0.6, -0.14), Vector3(0.27 * sx, 0.3, -0.15), Vector3(0.04 * sx, 0.32, -0.07), 8)
	st.generate_normals()
	return st.commit()


## A surface of revolution from y0 to y1 with radius _head_r, the cross-section squashed in z.
static func _lathe(st: SurfaceTool, y0: float, y1: float, rings: int, seg: int, zs: float, part: int) -> void:
	for i: int in rings:
		var u0: float = float(i) / float(rings)
		var u1: float = float(i + 1) / float(rings)
		var ya: float = lerpf(y0, y1, u0)
		var yb: float = lerpf(y0, y1, u1)
		var ra: float = _head_r(u0)
		var rb: float = _head_r(u1)
		for j: int in seg:
			var p0: float = TAU * float(j) / float(seg)
			var p1: float = TAU * float(j + 1) / float(seg)
			var a := Vector3(cos(p0) * ra, ya, sin(p0) * ra * zs)
			var b := Vector3(cos(p1) * ra, ya, sin(p1) * ra * zs)
			var c := Vector3(cos(p1) * rb, yb, sin(p1) * rb * zs)
			var d := Vector3(cos(p0) * rb, yb, sin(p0) * rb * zs)
			_quad(st, d, c, b, a, part)


static func _cone(st: SurfaceTool, base: Vector3, tip: Vector3, r: float, seg: int, part: int) -> void:
	var axis: Vector3 = (tip - base).normalized()
	var u: Vector3 = axis.cross(Vector3.UP).normalized()
	var v: Vector3 = axis.cross(u).normalized()
	for j: int in seg:
		var p0: float = TAU * float(j) / float(seg)
		var p1: float = TAU * float(j + 1) / float(seg)
		var a: Vector3 = base + (u * cos(p0) + v * sin(p0)) * r
		var b: Vector3 = base + (u * cos(p1) + v * sin(p1)) * r
		_tri_uv(st, a, b, tip, 0.0, 0.0, 0.0, part)


## A leaf from base along a curve rising and leaning forward. Strips across the midrib, edges a
## little lower than the rib so it reads folded; UV.y is 0 on the rib and 1 at the edge.
static func _leaf(st: SurfaceTool, base: Vector3, length: float, half_w: float, part: int) -> void:
	var n: int = 9
	var prev_c: Vector3 = base
	var prev_l: Vector3 = base
	var prev_r: Vector3 = base
	for i: int in range(1, n + 1):
		var t: float = float(i) / float(n)
		var c: Vector3 = base + Vector3(0.0, 0.62 * t - 0.12 * t * t, 0.42 * t + 0.32 * t * t) * length
		# wide near the middle, a soft round shoulder, a sharp tip
		var w: float = half_w * sin(PI * pow(t, 0.72)) * (1.0 - 0.15 * t)
		var tang: Vector3 = (c - prev_c).normalized()
		var nrm: Vector3 = tang.cross(Vector3.RIGHT).normalized()
		var droop: Vector3 = nrm * (w / half_w) * 0.028
		var l: Vector3 = c + Vector3(-w, 0.0, 0.0) + droop
		var r: Vector3 = c + Vector3(w, 0.0, 0.0) + droop
		_tri_uv(st, prev_c, prev_l, l, 0.0, 1.0, 1.0, part)
		_tri_uv(st, prev_c, l, c, 0.0, 1.0, 0.0, part)
		_tri_uv(st, prev_c, r, prev_r, 0.0, 1.0, 1.0, part)
		_tri_uv(st, prev_c, c, r, 0.0, 0.0, 1.0, part)
		prev_c = c
		prev_l = l
		prev_r = r


static func _small_leaf(st: SurfaceTool, base: Vector3, tip_off: Vector3, part: int) -> void:
	var tip: Vector3 = base + tip_off
	var mid: Vector3 = base + tip_off * 0.5
	var side: Vector3 = tip_off.cross(Vector3.UP).normalized() * 0.03
	_tri_uv(st, base, mid + side, tip, 0.0, 1.0, 0.0, part)
	_tri_uv(st, base, tip, mid - side, 0.0, 0.0, 1.0, part)


## One round petal as a fan, tilted up a little; UV.y 0 at the centre, 1 at the rim.
static func _petal(st: SurfaceTool, c: Vector3, ang: float, length: float, half_w: float, part: int) -> void:
	var dir := Vector3(sin(ang), 0.28, cos(ang)).normalized()
	var side := Vector3(cos(ang), 0.0, -sin(ang))
	var pts: Array[Vector3] = []
	for k: int in 7:
		var a: float = -PI * 0.5 + PI * float(k) / 6.0
		var along: float = (0.55 + 0.45 * cos(a)) * length
		var across: float = sin(a) * half_w
		pts.append(c + dir * along + side * across)
	for k: int in 6:
		_tri_uv(st, c, pts[k], pts[k + 1], 0.0, 1.0, 1.0, part)


static func _tri_uv(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: float, ub: float, uc: float, part: int) -> void:
	st.set_uv(Vector2(float(part), ua))
	st.add_vertex(a)
	st.set_uv(Vector2(float(part), uc))
	st.add_vertex(c)
	st.set_uv(Vector2(float(part), ub))
	st.add_vertex(b)


static func _ellip(st: SurfaceTool, c: Vector3, rad: Vector3, seg: int, rings: int, part: int) -> void:
	for i: int in rings:
		var t0: float = PI * float(i) / float(rings)
		var t1: float = PI * float(i + 1) / float(rings)
		for j: int in seg:
			var p0: float = TAU * float(j) / float(seg)
			var p1: float = TAU * float(j + 1) / float(seg)
			var a: Vector3 = c + Vector3(sin(t0) * cos(p0), cos(t0), sin(t0) * sin(p0)) * rad
			var b: Vector3 = c + Vector3(sin(t0) * cos(p1), cos(t0), sin(t0) * sin(p1)) * rad
			var cc: Vector3 = c + Vector3(sin(t1) * cos(p1), cos(t1), sin(t1) * sin(p1)) * rad
			var d: Vector3 = c + Vector3(sin(t1) * cos(p0), cos(t1), sin(t1) * sin(p0)) * rad
			_quad(st, a, b, cc, d, part)


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
uniform float nose = 0.0;
uniform float ears = 0.0;
varying float part;
varying float across;
varying vec4 icol;
void vertex() {
	float phase = INSTANCE_CUSTOM.x;
	float maturity = INSTANCE_CUSTOM.y;
	float moving = INSTANCE_CUSTOM.z;
	part = floor(UV.x + 0.5);
	across = UV.y;
	vec3 crown = vec3(0.03, 1.5, 0.0);
	// only the top that matches maturity exists; the others collapse into the stem tip
	bool hide = (part == 2.0 && maturity > 0.5) || (part == 3.0 && (maturity < 0.5 || maturity > 1.5)) || ((part == 4.0 || part == 5.0) && maturity < 1.5);
	if (buried > 0.5 && (part == 0.0 || part == 6.0 || part == 7.0 || part == 8.0 || part == 9.0 || part == 10.0 || part == 11.0 || part == 12.0)) {
		hide = true;
	}
	if (part == 8.0 && wings < 0.5) {
		hide = true;
	}
	if ((part == 11.0 && nose < 0.5) || (part == 12.0 && ears < 0.5) || part == 10.0) {
		hide = true;
	}
	if (hide) {
		VERTEX = crown;
	}
	// a blink now and then, each on its own phase: the eyes close to a line
	if (part == 6.0 || part == 9.0) {
		float b = 1.0 - smoothstep(0.0, 0.03, abs(fract(TIME * 0.21 + phase * 0.37) - 0.5));
		VERTEX.y = mix(VERTEX.y, 0.71, b * 0.92);
	}
	// breathing: the body swells a hair on its own rhythm
	if (part == 0.0 && VERTEX.y < 0.48) {
		VERTEX.xz *= 1.0 + 0.025 * sin(TIME * 2.4 + phase * 6.283);
	}
	// the stem and its top sway; the leaf tip most of all
	float w = clamp((VERTEX.y - 0.98) * 1.8, 0.0, 1.3);
	VERTEX.x += sin(TIME * 2.2 + phase * 6.283) * 0.05 * w;
	VERTEX.z += sin(TIME * 1.7 + phase * 4.1) * 0.035 * w;
	float step_ = sin(TIME * 11.0 + phase * 6.283);
	// limbs swing from hip and shoulder: legs (near the centre line) forward and back, arms against them
	if (part == 7.0) {
		float side = VERTEX.x < 0.0 ? -1.0 : 1.0;
		if (VERTEX.y < 0.3 && abs(VERTEX.x) < 0.09) {
			VERTEX.z += step_ * side * moving * (0.3 - VERTEX.y) * 1.6;
			VERTEX.y += max(0.0, step_ * side) * moving * 0.04 * (0.3 - VERTEX.y) * 4.0;
		} else {
			VERTEX.z -= step_ * side * moving * (0.46 - VERTEX.y) * 1.5;
		}
	}
	// wings beat fast whether walking or not
	if (part == 8.0) {
		float f = sin(TIME * 30.0 + phase * 6.283) * 0.5 + 0.5;
		VERTEX.x *= mix(1.0, 0.35, f);
		VERTEX.z -= abs(VERTEX.x) * 0.5 * f;
	}
	VERTEX.y += moving * abs(step_) * 0.045;
	if (buried > 0.5) {
		// a sprout is the stem and its top, out of the ground
		VERTEX.y -= 1.0;
	}
	icol = INSTANCE_CUSTOM;
}
void fragment() {
	vec3 col = tint.rgb;
	float rough = 0.75;
	float spec = 0.3;
	if (part == 1.0) { col = stalk.rgb * 1.1; }
	else if (part == 2.0) {
		// a fresh leaf: dark along the rib, bright across the blade, faint veins, the
		// underside a shade darker
		vec3 rib = vec3(0.2, 0.45, 0.15);
		vec3 blade = vec3(0.42, 0.76, 0.27);
		col = mix(rib, blade, smoothstep(0.0, 0.3, across));
		col *= 1.0 - 0.1 * smoothstep(0.88, 1.0, across);
		col *= 1.0 - 0.07 * step(0.82, fract(across * 3.0));
		if (!FRONT_FACING) { col *= 0.78; }
		rough = 0.55;
		spec = 0.45;
	}
	else if (part == 3.0) { col = mix(vec3(0.98, 0.95, 0.96), tint.rgb, 0.12); rough = 0.5; }
	else if (part == 11.0 || part == 12.0) { col = tint.rgb * (part == 12.0 ? 0.92 : 1.0); rough = 0.6; }
	else if (part == 4.0) { col = mix(vec3(1.0, 0.99, 0.95), mix(vec3(1.0), tint.rgb, 0.35), across * 0.6); rough = 0.6; }
	else if (part == 5.0) { col = vec3(1.0, 0.82, 0.25); }
	else if (part == 6.0) { col = vec3(0.05, 0.05, 0.08); rough = 0.2; spec = 0.8; }
	else if (part == 9.0) { col = vec3(0.98, 0.98, 0.96); rough = 0.3; spec = 0.6; }
	else if (part == 10.0) { col = mix(tint.rgb, vec3(1.0, 0.45, 0.5), 0.65); }
	else if (part == 8.0) { col = mix(tint.rgb, vec3(1.0), 0.55); }
	else if (part == 0.0) { rough = 0.6; }
	ALBEDO = col * COLOR.rgb;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
"""
