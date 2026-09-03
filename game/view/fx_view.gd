## Transient effects driven by SimEvents: damage numbers with their cause, the whistle ring, the
## throw arc, a puff where a sprig was lost, the telegraph flash. Pools, no allocation per frame.
class_name FxView
extends Node3D

var pal: PaletteData
var _numbers: Array[Label3D] = []
var _number_life: PackedFloat32Array = []
var _whistle: MeshInstance3D
var _arc: MeshInstance3D
var _arc_mesh: ImmediateMesh
var _arc_disc: MeshInstance3D
var _puffs: Array[MeshInstance3D] = []
var _puff_life: PackedFloat32Array = []
var _log: Array[String] = []
var reduced_motion: bool = false


func build(p: PaletteData) -> void:
	pal = p
	for i: int in 24:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.font_size = 42
		l.outline_size = 8
		l.pixel_size = 0.006
		l.visible = false
		add_child(l)
		_numbers.append(l)
		_number_life.append(0.0)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.94
	ring.outer_radius = 1.0
	ring.rings = 48
	ring.ring_segments = 4
	_whistle = MeshInstance3D.new()
	_whistle.mesh = ring
	var wm := StandardMaterial3D.new()
	wm.albedo_color = pal.col("whistle_ring")
	wm.emission_enabled = true
	wm.emission = pal.col("whistle_ring")
	wm.emission_energy_multiplier = 2.0
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.albedo_color.a = 0.8
	_whistle.material_override = wm
	_whistle.visible = false
	_whistle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_whistle)
	_arc_mesh = ImmediateMesh.new()
	_arc = MeshInstance3D.new()
	_arc.mesh = _arc_mesh
	var am := StandardMaterial3D.new()
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	am.albedo_color = pal.col("arc_line")
	am.no_depth_test = true
	_arc.material_override = am
	_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_arc)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.42
	disc.bottom_radius = 0.42
	disc.height = 0.03
	disc.radial_segments = 16
	_arc_disc = MeshInstance3D.new()
	_arc_disc.mesh = disc
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = pal.col("arc_line")
	dm.albedo_color.a = 0.7
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_arc_disc.material_override = dm
	_arc_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_arc_disc)
	for i: int in 12:
		var m := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.3
		s.height = 0.6
		s.radial_segments = 6
		s.rings = 3
		m.mesh = s
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.9, 0.9, 0.8, 0.8)
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.material_override = pm
		m.visible = false
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		_puffs.append(m)
		_puff_life.append(0.0)


func handle(ev: Dictionary) -> void:
	var kind: String = ev["kind"]
	match kind:
		"damage":
			var amount: float = float(ev["amount"])
			var cause: String = str(ev["cause"])
			var target: String = str(ev["target"])
			if target == "knight":
				_number(ev["pos"] + Vector3(0.0, 1.6, 0.0), "-%d  %s" % [int(roundf(amount)), cause], pal.col("hud_warn"))
			elif amount >= 1.0:
				var col: Color = pal.col("damage_number_backstrike") if cause == "Backstrike" else pal.col("damage_number")
				_number(ev["pos"] + Vector3(0.0, 0.4, 0.0), "%d  %s" % [int(roundf(amount)), cause], col)
		"sprig_lost":
			_puff(ev["pos"] + Vector3(0.0, 0.4, 0.0), Color(0.3, 0.3, 0.3, 0.85))
			_note("%s sprig %s" % [_cap(str(ev["type"])), str(ev["cause"])])
		"delivered":
			_note(str(ev["text"]))
			_puff(ev["pos"] + Vector3(0.0, 0.6, 0.0), Color(1.0, 0.95, 0.7, 0.9))
		"absorb":
			_puff(ev["to"], pal.col("shrine_glow"))
		"seed":
			_puff(ev["pos"] + Vector3(0.0, 2.3, 0.0), pal.col("sprig_" + str(ev["type"])).lightened(0.4))
		"stored":
			_note("Field full (%d). Seed kept inside; a Heartroot widens the field." % int(ev["cap"]))
		"enemy_felled":
			_note("Felled: " + _cap(str(ev["type"]).replace("_", " ")))
		"gate_opened":
			_note("The bramble gate falls")
		"dusk_warning":
			_note("Dusk soon. The Hold's ring is safe ground.")
		"night":
			_note("Night. Something is out there.")
		"morning":
			_note("Morning. Lost in the night: %d" % int(ev["lost"]))
		"raid":
			_note("%d stalkers at the rim" % int(ev["count"]))
		"knight_down":
			_note("Down. The Hold takes you back.")
		"shrine_rooted":
			_note(_cap(str(ev["type"])) + " shrine rooted at the Hold")
		"offline":
			_note("While away: %d nights, %d lost, %d matured" % [int(ev["nights"]), int(ev["lost"]), int(ev["matured"])])
		"pluck", "throw", "whistle", "rooted", "matured", "status", "telegraph", "shake", "bite", "dismiss", "charge", "enemy_woke", "lost_follow", "knight_up", "dawn":
			pass


func notes() -> Array[String]:
	return _log


func _note(s: String) -> void:
	_log.append(s)
	if _log.size() > 6:
		_log.pop_front()


func _cap(s: String) -> String:
	if s.is_empty():
		return s
	return s.substr(0, 1).to_upper() + s.substr(1)


func _number(p: Vector3, text: String, col: Color) -> void:
	var best: int = 0
	var best_life: float = 1e9
	for i: int in _numbers.size():
		if _number_life[i] < best_life:
			best_life = _number_life[i]
			best = i
	var l: Label3D = _numbers[best]
	l.text = text
	l.modulate = col
	l.outline_modulate = Color(0.05, 0.05, 0.05, 0.9)
	l.global_position = p + Vector3(float(best % 3) * 0.25 - 0.25, 0.0, 0.0)
	l.visible = true
	_number_life[best] = 1.4


func _puff(p: Vector3, col: Color) -> void:
	for i: int in _puffs.size():
		if _puff_life[i] <= 0.0:
			var m: MeshInstance3D = _puffs[i]
			m.global_position = p
			var mat: StandardMaterial3D = m.material_override
			mat.albedo_color = col
			m.scale = Vector3.ONE * 0.4
			m.visible = true
			_puff_life[i] = 0.7
			return


func whistle(pos: Vector3, radius: float, on: bool) -> void:
	_whistle.visible = on
	if on:
		_whistle.global_position = pos + Vector3(0.0, 0.12, 0.0)
		_whistle.scale = Vector3(radius, 1.0, radius)


func arc(points: PackedVector3Array, on: bool) -> void:
	_arc.visible = on
	_arc_disc.visible = on
	_arc_mesh.clear_surfaces()
	if not on or points.size() < 2:
		return
	_arc_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p: Vector3 in points:
		_arc_mesh.surface_add_vertex(p)
	_arc_mesh.surface_end()
	_arc_disc.global_position = points[points.size() - 1] + Vector3(0.0, 0.04, 0.0)


func tick(delta: float) -> void:
	for i: int in _numbers.size():
		if _number_life[i] <= 0.0:
			continue
		_number_life[i] -= delta
		var l: Label3D = _numbers[i]
		if not reduced_motion:
			l.global_position.y += delta * 0.9
		l.modulate.a = clampf(_number_life[i] / 0.5, 0.0, 1.0)
		if _number_life[i] <= 0.0:
			l.visible = false
	for i: int in _puffs.size():
		if _puff_life[i] <= 0.0:
			continue
		_puff_life[i] -= delta
		var m: MeshInstance3D = _puffs[i]
		m.scale += Vector3.ONE * delta * 2.2
		var mat: StandardMaterial3D = m.material_override
		mat.albedo_color.a = clampf(_puff_life[i] / 0.7, 0.0, 1.0) * 0.8
		if _puff_life[i] <= 0.0:
			m.visible = false
