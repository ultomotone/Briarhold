## The knight, built from primitives so his silhouette is honest at play distance: a squat armored
## body, a helm with a slit, a sword in the right hand, a round shield on the left arm.
class_name KnightView
extends Node3D

var body: Node3D
var sword_pivot: Node3D
var shield: Node3D
var _walk_phase: float = 0.0
var _mat_armor: StandardMaterial3D
var _mat_cloth: StandardMaterial3D
var _mat_steel: StandardMaterial3D


func build(pal: PaletteData) -> void:
	_mat_armor = _mat(pal.col("knight_armor"), 0.55, 0.35)
	_mat_cloth = _mat(pal.col("knight_cloth"), 0.95, 0.0)
	_mat_steel = _mat(pal.col("knight_steel"), 0.3, 0.7)
	body = Node3D.new()
	add_child(body)
	# torso
	var torso := _mesh(_capsule(0.28, 0.62), _mat_armor)
	torso.position = Vector3(0.0, 0.62, 0.0)
	body.add_child(torso)
	# tabard
	var tab := _mesh(_box(0.36, 0.42, 0.16), _mat_cloth)
	tab.position = Vector3(0.0, 0.5, 0.2)
	body.add_child(tab)
	# helm
	var helm := _mesh(_cyl(0.2, 0.26), _mat_steel)
	helm.position = Vector3(0.0, 1.1, 0.0)
	body.add_child(helm)
	var crest := _mesh(_box(0.05, 0.22, 0.3), _mat_cloth)
	crest.position = Vector3(0.0, 1.3, 0.0)
	body.add_child(crest)
	# legs
	for sx: float in [-0.12, 0.12]:
		var leg := _mesh(_capsule(0.09, 0.34), _mat_armor)
		leg.position = Vector3(sx, 0.2, 0.0)
		body.add_child(leg)
	# sword arm
	sword_pivot = Node3D.new()
	sword_pivot.position = Vector3(0.36, 0.86, 0.0)
	body.add_child(sword_pivot)
	var arm := _mesh(_capsule(0.07, 0.3), _mat_armor)
	arm.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	arm.position = Vector3(0.0, 0.0, 0.16)
	sword_pivot.add_child(arm)
	var blade := _mesh(_box(0.06, 0.02, 0.95), _mat_steel)
	blade.position = Vector3(0.0, 0.0, 0.78)
	sword_pivot.add_child(blade)
	var guard := _mesh(_box(0.26, 0.04, 0.05), _mat_steel)
	guard.position = Vector3(0.0, 0.0, 0.32)
	sword_pivot.add_child(guard)
	# shield
	shield = _mesh(_cyl(0.3, 0.05), _mat_cloth)
	shield.position = Vector3(-0.4, 0.78, 0.1)
	shield.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	body.add_child(shield)
	var boss := _mesh(_cyl(0.08, 0.06), _mat_steel)
	boss.position = Vector3(-0.4, 0.78, 0.14)
	boss.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	body.add_child(boss)
	sword_pivot.rotation_degrees = Vector3(-35.0, 0.0, 0.0)


## Called per frame with interpolated position, yaw, the swing phase (0..1 or -1) and speed.
func pose(p: Vector3, yaw: float, swing: float, moving: bool, down: float, delta: float) -> void:
	global_position = p
	rotation.y = yaw
	if down >= 0.0:
		body.rotation.x = lerpf(body.rotation.x, -PI * 0.5, clampf(delta * 6.0, 0.0, 1.0))
		body.position.y = 0.35
		return
	body.rotation.x = 0.0
	if moving:
		_walk_phase += delta * 11.0
		body.position.y = absf(sin(_walk_phase)) * 0.06
		body.rotation.z = sin(_walk_phase) * 0.04
	else:
		body.position.y = lerpf(body.position.y, 0.0, clampf(delta * 8.0, 0.0, 1.0))
		body.rotation.z = 0.0
	if swing >= 0.0:
		# wind back, then the cut: fast through the contact window, easing out
		var t: float = swing
		var ang: float
		if t < 0.3:
			ang = lerpf(-35.0, -95.0, t / 0.3)
		elif t < 0.55:
			ang = lerpf(-95.0, 40.0, (t - 0.3) / 0.25)
		else:
			ang = lerpf(40.0, -35.0, (t - 0.55) / 0.45)
		sword_pivot.rotation_degrees = Vector3(ang, 0.0, 0.0)
		body.rotation.y = lerpf(0.0, -0.5, clampf((t - 0.3) / 0.25, 0.0, 1.0)) * (1.0 - clampf((t - 0.55) / 0.45, 0.0, 1.0))
	else:
		sword_pivot.rotation_degrees = Vector3(-35.0, 0.0, 0.0)
		body.rotation.y = 0.0


static func _mat(c: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func _mesh(m: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 10
	c.rings = 4
	return c


static func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


static func _cyl(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 10
	return c
