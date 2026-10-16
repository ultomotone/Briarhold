## The gnome (owner verdict 2026-09-02: a gnome, not a knight). Built from primitives so his
## silhouette is honest at play distance: boots, a round tunic with a belt, a big nose, a white
## beard, a tall red cap that leans, a sword in the right hand, a round shield on the left arm.
## The class keeps its old name so the sim's "knight" record and this view stay one thing.
class_name KnightView
extends Node3D

var body: Node3D
var sword_pivot: Node3D
var cap: Node3D
var _walk_phase: float = 0.0
var _legs: Array[Node3D] = []
var _yaw: float = 0.0
var _yaw_set: bool = false


func build(pal: PaletteData) -> void:
	var m_cap := _mat(pal.col("gnome_cap"), 0.9, 0.0)
	var m_tunic := _mat(pal.col("gnome_tunic"), 0.9, 0.0)
	var m_skin := _mat(pal.col("gnome_skin"), 0.8, 0.0)
	var m_beard := _mat(pal.col("gnome_beard"), 0.95, 0.0)
	var m_boot := _mat(pal.col("gnome_boot"), 0.9, 0.0)
	var m_belt := _mat(pal.col("gnome_belt"), 0.8, 0.0)
	var m_steel := _mat(pal.col("knight_steel"), 0.3, 0.7)
	body = Node3D.new()
	add_child(body)
	# legs on hip pivots, so they can stride
	for sx: float in [-0.13, 0.13]:
		var hip := Node3D.new()
		hip.position = Vector3(sx, 0.3, 0.0)
		body.add_child(hip)
		var boot := _mesh(_box(0.16, 0.12, 0.26), m_boot)
		boot.position = Vector3(0.0, -0.24, 0.04)
		hip.add_child(boot)
		var leg := _mesh(_cyl(0.07, 0.2), m_tunic)
		leg.position = Vector3(0.0, -0.1, 0.0)
		hip.add_child(leg)
		_legs.append(hip)
	# tunic: a round belly with a belt
	var belly := SphereMesh.new()
	belly.radius = 0.3
	belly.height = 0.6
	belly.radial_segments = 12
	belly.rings = 6
	var tunic := _mesh(belly, m_tunic)
	tunic.position = Vector3(0.0, 0.55, 0.0)
	tunic.scale = Vector3(1.0, 1.05, 0.9)
	body.add_child(tunic)
	var belt := _mesh(_cyl(0.305, 0.06), m_belt)
	belt.position = Vector3(0.0, 0.5, 0.0)
	body.add_child(belt)
	var buckle := _mesh(_box(0.08, 0.07, 0.03), m_steel)
	buckle.position = Vector3(0.0, 0.5, 0.29)
	body.add_child(buckle)
	# head, nose, beard
	var head := _mesh(_sphere(0.19), m_skin)
	head.position = Vector3(0.0, 0.95, 0.02)
	body.add_child(head)
	var nose := _mesh(_sphere(0.06), m_skin)
	nose.position = Vector3(0.0, 0.93, 0.21)
	body.add_child(nose)
	var beard := _mesh(_sphere(0.17), m_beard)
	beard.position = Vector3(0.0, 0.82, 0.12)
	beard.scale = Vector3(1.0, 1.25, 0.8)
	body.add_child(beard)
	for sx: float in [-0.07, 0.07]:
		var eye := _mesh(_sphere(0.025), m_belt)
		eye.position = Vector3(sx, 0.99, 0.19)
		body.add_child(eye)
	# the cap: tall, pointed, leaning back a touch
	cap = Node3D.new()
	cap.position = Vector3(0.0, 1.04, -0.02)
	cap.rotation_degrees = Vector3(-12.0, 0.0, 4.0)
	body.add_child(cap)
	var brim := _mesh(_cyl(0.22, 0.08), m_cap)
	brim.position = Vector3(0.0, 0.02, 0.0)
	cap.add_child(brim)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.2
	cone.height = 0.62
	cone.radial_segments = 10
	var point := _mesh(cone, m_cap)
	point.position = Vector3(0.0, 0.36, 0.0)
	cap.add_child(point)
	# sword arm
	sword_pivot = Node3D.new()
	sword_pivot.position = Vector3(0.34, 0.66, 0.0)
	body.add_child(sword_pivot)
	var arm := _mesh(_capsule(0.06, 0.26), m_tunic)
	arm.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	arm.position = Vector3(0.0, 0.0, 0.14)
	sword_pivot.add_child(arm)
	var hand := _mesh(_sphere(0.06), m_skin)
	hand.position = Vector3(0.0, 0.0, 0.28)
	sword_pivot.add_child(hand)
	var blade := _mesh(_box(0.06, 0.02, 0.8), m_steel)
	blade.position = Vector3(0.0, 0.0, 0.72)
	sword_pivot.add_child(blade)
	var guard := _mesh(_box(0.22, 0.04, 0.05), m_steel)
	guard.position = Vector3(0.0, 0.0, 0.32)
	sword_pivot.add_child(guard)
	# shield arm
	var arm2 := _mesh(_capsule(0.06, 0.24), m_tunic)
	arm2.rotation_degrees = Vector3(0.0, 0.0, 70.0)
	arm2.position = Vector3(-0.3, 0.6, 0.06)
	body.add_child(arm2)
	var shield := _mesh(_cyl(0.24, 0.05), m_boot)
	shield.position = Vector3(-0.42, 0.56, 0.1)
	shield.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	body.add_child(shield)
	var boss := _mesh(_cyl(0.07, 0.06), m_steel)
	boss.position = Vector3(-0.42, 0.56, 0.14)
	boss.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	body.add_child(boss)
	sword_pivot.rotation_degrees = Vector3(-35.0, 0.0, 0.0)


## Called per frame with interpolated position, yaw, the swing phase (0..1 or -1) and speed.
func pose(p: Vector3, yaw: float, swing: float, moving: bool, down: float, delta: float) -> void:
	global_position = p
	# facing eases instead of snapping
	if not _yaw_set:
		_yaw = yaw
		_yaw_set = true
	_yaw = lerp_angle(_yaw, yaw, clampf(delta * 14.0, 0.0, 1.0))
	rotation.y = _yaw
	if down >= 0.0:
		body.rotation.x = lerpf(body.rotation.x, -PI * 0.5, clampf(delta * 6.0, 0.0, 1.0))
		body.position.y = 0.35
		return
	body.rotation.x = 0.0
	if moving:
		_walk_phase += delta * 11.0
		body.position.y = absf(sin(_walk_phase)) * 0.05
		body.rotation.z = sin(_walk_phase) * 0.035
		cap.rotation_degrees.x = -12.0 - sin(_walk_phase) * 5.0
		for i: int in _legs.size():
			var sgn: float = 1.0 if i == 0 else -1.0
			_legs[i].rotation.x = sin(_walk_phase) * 0.6 * sgn
	else:
		body.position.y = lerpf(body.position.y, 0.0, clampf(delta * 8.0, 0.0, 1.0))
		body.rotation.z = lerpf(body.rotation.z, 0.0, clampf(delta * 8.0, 0.0, 1.0))
		cap.rotation_degrees.x = lerpf(cap.rotation_degrees.x, -12.0, clampf(delta * 6.0, 0.0, 1.0))
		for leg: Node3D in _legs:
			leg.rotation.x = lerpf(leg.rotation.x, 0.0, clampf(delta * 10.0, 0.0, 1.0))
	if swing >= 0.0:
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


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 6
	return s


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
