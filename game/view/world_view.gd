## Everything in the field that is not a sprig or the knight: the Hold, shrines, stones and
## plants (instanced), loads, enemies, the gate, the vent. Node per thing where counts are small;
## MultiMesh where they are not.
class_name WorldView
extends Node3D

var pal: PaletteData
var tables: ContentTables
var _objects: Dictionary = {} # id -> Node3D
var _enemies: Dictionary = {} # id -> Node3D
var _gates: Dictionary = {} # id -> Node3D
var _shrines: Dictionary = {} # id -> Node3D
var _vents: Array[Node3D] = []
var _stones: MultiMeshInstance3D
var _plants: MultiMeshInstance3D
var _hold_ring: MeshInstance3D
var _safe_ring: MeshInstance3D


func build(p: PaletteData, t: ContentTables, w: SimWorld) -> void:
	pal = p
	tables = t
	_build_hold(w)
	_build_stones(w)
	_build_plants(w)
	for z: Entities.HazardZone in w.hazards:
		_vents.append(_build_vent(z))


func _build_hold(w: SimWorld) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = w.hold.radius - 0.12
	ring.outer_radius = w.hold.radius + 0.12
	ring.rings = 48
	ring.ring_segments = 6
	_hold_ring = _mesh(ring, _mat(pal.col("hold_ring"), 0.6, 0.3, pal.col("hold_ring"), 0.9))
	_hold_ring.position = w.ground(w.hold.pos) + Vector3(0.0, 0.08, 0.0)
	_hold_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hold_ring)
	var safe := TorusMesh.new()
	safe.inner_radius = w.hold.safe_radius - 0.05
	safe.outer_radius = w.hold.safe_radius + 0.05
	safe.rings = 64
	safe.ring_segments = 4
	_safe_ring = _mesh(safe, _mat(pal.col("hold_ring").darkened(0.3), 0.9, 0.0, pal.col("hold_ring"), 0.35))
	_safe_ring.position = w.ground(w.hold.pos) + Vector3(0.0, 0.05, 0.0)
	_safe_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_safe_ring)
	# the cairn at the centre: three stacked stones and a banked ember
	var cairn := Node3D.new()
	cairn.position = w.ground(w.hold.pos)
	add_child(cairn)
	var stone_mat := _mat(pal.col("scatter_stone"), 1.0, 0.0)
	for i: int in 3:
		var s := _mesh(_ico(0.9 - float(i) * 0.22), stone_mat)
		s.position = Vector3(0.0, 0.5 + float(i) * 0.75, 0.0)
		s.rotation = Vector3(0.3 * float(i), 0.9 * float(i), 0.1)
		cairn.add_child(s)
	var ember := _mesh(_ico(0.22), _mat(pal.col("vent_fire"), 0.5, 0.0, pal.col("vent_fire"), 2.5))
	ember.position = Vector3(0.0, 2.7, 0.0)
	cairn.add_child(ember)
	var light := OmniLight3D.new()
	light.light_color = pal.col("hold_ring")
	light.light_energy = 3.0
	light.omni_range = 12.0
	light.position = Vector3(0.0, 3.0, 0.0)
	light.shadow_enabled = false
	cairn.add_child(light)


func _build_stones(w: SimWorld) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _ico(1.0)
	mm.instance_count = w.obstacles.size()
	for i: int in w.obstacles.size():
		var ob: Dictionary = w.obstacles[i]
		var c: Vector3 = ob["pos"]
		var r: float = float(ob["r"])
		var h: float = float(ob["h"])
		var b := Basis.from_euler(Vector3(0.2 * float(i % 3), float(i) * 0.7, 0.15 * float(i % 2))).scaled(Vector3(r * 1.15, h, r * 1.05))
		mm.set_instance_transform(i, Transform3D(b, c + Vector3(0.0, h * 0.35, 0.0)))
	_stones = MultiMeshInstance3D.new()
	_stones.multimesh = mm
	_stones.material_override = _mat(pal.col("scatter_stone"), 1.0, 0.0)
	_stones.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_stones)


func _build_plants(w: SimWorld) -> void:
	# stalks and leaves as one instanced mesh: a tall thin blade, scaled per instance
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = [Vector3(-0.08, 0.0, 0.0), Vector3(0.08, 0.0, 0.0), Vector3(0.05, 1.0, 0.25), Vector3(-0.05, 1.0, 0.25), Vector3(0.0, 1.5, 0.55)]
	_tri(st, pts[0], pts[2], pts[1])
	_tri(st, pts[0], pts[3], pts[2])
	_tri(st, pts[3], pts[4], pts[2])
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = w.plants.size()
	var leaf: Color = pal.col("scatter_leaf").srgb_to_linear()
	var stalk: Color = pal.col("scatter_stalk").srgb_to_linear()
	for i: int in w.plants.size():
		var pl: Dictionary = w.plants[i]
		var c: Vector3 = pl["pos"]
		var s: float = float(pl["s"])
		var kind: String = str(pl["kind"])
		var b := Basis(Vector3.UP, float(pl["rot"]))
		if kind == "leaf":
			b = b.scaled(Vector3(s * 2.0, s * 0.6, s * 1.8))
		else:
			b = b.scaled(Vector3(s * 0.8, s * 0.9, s * 0.8))
		mm.set_instance_transform(i, Transform3D(b, c))
		mm.set_instance_color(i, leaf if kind == "leaf" else stalk)
	_plants = MultiMeshInstance3D.new()
	_plants.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_plants.material_override = mat
	_plants.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_plants)


func _build_vent(z: Entities.HazardZone) -> Node3D:
	var n := Node3D.new()
	n.position = z.pos
	add_child(n)
	var rim := TorusMesh.new()
	rim.inner_radius = z.radius - 0.3
	rim.outer_radius = z.radius + 0.1
	rim.rings = 24
	rim.ring_segments = 6
	var rock := _mesh(rim, _mat(pal.col("scatter_stone").darkened(0.35), 1.0, 0.0))
	rock.position.y = 0.05
	n.add_child(rock)
	var fire := _mesh(_ico(z.radius * 0.55), _mat(pal.col("vent_fire"), 0.4, 0.0, pal.col("vent_fire"), 3.0))
	fire.name = "fire"
	fire.position.y = 0.2
	fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(fire)
	var light := OmniLight3D.new()
	light.name = "light"
	light.light_color = pal.col("vent_fire")
	light.light_energy = 6.0
	light.omni_range = 9.0
	light.position.y = 1.2
	light.shadow_enabled = false
	n.add_child(light)
	return n


# ---- per-frame ----------------------------------------------------------------------------------

func update(w: SimWorld, alpha: float, t: float) -> void:
	_sync_shrines(w)
	_sync_objects(w, alpha)
	_sync_enemies(w, alpha, t)
	_sync_gates(w)
	for i: int in w.hazards.size():
		if i >= _vents.size():
			break
		var z: Entities.HazardZone = w.hazards[i]
		var n: Node3D = _vents[i]
		var fire: Node3D = n.get_node("fire")
		var s: float = 0.85 + 0.25 * sin(t * 7.0 + z.pulse * TAU) + 0.1 * sin(t * 13.0)
		fire.scale = Vector3(s, 0.6 + 0.5 * s, s)
		var light: OmniLight3D = n.get_node("light")
		light.light_energy = 4.5 + 2.5 * s


func _sync_shrines(w: SimWorld) -> void:
	for sh: Entities.Shrine in w.shrines:
		if _shrines.has(sh.id):
			continue
		var n := Node3D.new()
		n.position = sh.pos
		add_child(n)
		var tint: Color = pal.col(tables.sprig(sh.type_id).colour_key)
		var dome := SphereMesh.new()
		dome.radius = 1.05
		dome.height = 1.9
		dome.radial_segments = 10
		dome.rings = 6
		var body := _mesh(dome, _mat(pal.col("shrine_body"), 0.8, 0.0))
		body.position.y = 1.55
		n.add_child(body)
		for i: int in 3:
			var leg := _mesh(_cyl(0.11, 1.2), _mat(pal.col("scatter_stalk"), 0.9, 0.0))
			var ang: float = float(i) / 3.0 * TAU
			leg.position = Vector3(sin(ang) * 0.7, 0.55, cos(ang) * 0.7)
			leg.rotation = Vector3(cos(ang) * 0.25, 0.0, -sin(ang) * 0.25)
			n.add_child(leg)
		var cap := _mesh(_ico(0.42), _mat(tint, 0.5, 0.0, tint, 1.6))
		cap.position.y = 2.75
		n.add_child(cap)
		var band := TorusMesh.new()
		band.inner_radius = 0.95
		band.outer_radius = 1.12
		band.rings = 24
		band.ring_segments = 5
		var ring := _mesh(band, _mat(tint, 0.6, 0.0, tint, 0.9))
		ring.position.y = 1.35
		n.add_child(ring)
		var light := OmniLight3D.new()
		light.light_color = tint
		light.light_energy = 2.2
		light.omni_range = 7.0
		light.position.y = 3.0
		light.shadow_enabled = false
		n.add_child(light)
		_shrines[sh.id] = n


func _sync_objects(w: SimWorld, alpha: float) -> void:
	var seen: Dictionary = {}
	for o: Entities.WorldObject in w.objects:
		if o.taken:
			continue
		seen[o.id] = true
		var n: Node3D = _objects.get(o.id)
		if n == null:
			n = _make_object(o)
			_objects[o.id] = n
		var p: Vector3 = o.prev.lerp(o.pos, alpha)
		n.position = p + Vector3(0.0, 0.18 if o.carriers.size() > 0 else 0.0, 0.0)
		n.rotation.y = o.yaw
	for id: Variant in _objects.keys():
		if not seen.has(id):
			var n: Node3D = _objects[id]
			n.queue_free()
			_objects.erase(id)


func _make_object(o: Entities.WorldObject) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	match o.kind:
		"pellet":
			var tint: Color = pal.col(tables.sprig(o.pellet_type).colour_key) if not o.pellet_type.is_empty() else pal.col("pellet_body")
			var disc := _mesh(_cyl(o.radius, 0.22), _mat(pal.col("pellet_body"), 0.7, 0.0))
			disc.position.y = 0.11
			n.add_child(disc)
			var pip := _mesh(_cyl(o.radius * 0.45, 0.06), _mat(tint, 0.6, 0.0, tint, 0.5))
			pip.position.y = 0.26
			n.add_child(pip)
			var stem := _mesh(_cyl(0.03, 0.5), _mat(pal.col("scatter_stalk"), 0.9, 0.0))
			stem.position = Vector3(0.0, 0.5, 0.0)
			stem.rotation.z = 0.35
			n.add_child(stem)
		"relic":
			var tint: Color = pal.col("relic")
			var box := _mesh(_box(o.radius * 1.4, o.radius * 0.9, o.radius * 1.1), _mat(tint, 0.35, 0.8, tint, 0.25))
			box.position.y = o.radius * 0.5
			box.rotation.y = 0.5
			n.add_child(box)
		"heartroot":
			var tint: Color = pal.col("hud_warn")
			var bulb := _mesh(_ico(o.radius), _mat(tint, 0.5, 0.0, tint, 1.2))
			bulb.position.y = o.radius * 0.7
			n.add_child(bulb)
			for i: int in 3:
				var root := _mesh(_cyl(0.05, 0.9), _mat(pal.col("scatter_stalk"), 0.9, 0.0))
				var ang: float = float(i) / 3.0 * TAU
				root.position = Vector3(sin(ang) * 0.4, 0.2, cos(ang) * 0.4)
				root.rotation = Vector3(cos(ang) * 0.9, 0.0, -sin(ang) * 0.9)
				n.add_child(root)
		"corpse":
			var body := _mesh(_ico(o.radius * 0.9), _mat(pal.col("enemy_grub").darkened(0.35), 1.0, 0.0))
			body.position.y = o.radius * 0.45
			body.scale = Vector3(1.2, 0.6, 1.0)
			n.add_child(body)
		"shrine":
			var tint: Color = pal.col(tables.sprig(o.shrine_type).colour_key)
			var dome := SphereMesh.new()
			dome.radius = 0.85
			dome.height = 1.5
			dome.radial_segments = 10
			dome.rings = 6
			var body := _mesh(dome, _mat(pal.col("shrine_body").darkened(0.2), 0.8, 0.0))
			body.position.y = 0.7
			n.add_child(body)
			var cap := _mesh(_ico(0.34), _mat(tint, 0.5, 0.0, tint, 1.2))
			cap.position.y = 1.6
			n.add_child(cap)
		_:
			var box := _mesh(_box(o.radius, o.radius, o.radius), _mat(pal.col("pellet_body"), 0.7, 0.0))
			box.position.y = o.radius * 0.5
			n.add_child(box)
	return n


func _sync_enemies(w: SimWorld, alpha: float, t: float) -> void:
	var seen: Dictionary = {}
	for e: Entities.Enemy in w.enemies:
		if e.state == Entities.Enemy.State.DEAD:
			continue
		seen[e.id] = true
		var n: Node3D = _enemies.get(e.id)
		if n == null:
			n = _make_enemy(e)
			_enemies[e.id] = n
		var p: Vector3 = e.prev.lerp(e.pos, alpha)
		n.position = p
		n.rotation.y = e.yaw
		var body: Node3D = n.get_node("body")
		var et: Types.EnemyType = w.enemy_type(e)
		# the wind-up is on the body: it rears and pales, then snaps forward
		if e.state == Entities.Enemy.State.TELEGRAPH:
			body.rotation.x = -e.wind * 0.45
			body.position.y = e.wind * 0.25
			body.scale = Vector3(1.0 + e.wind * 0.08, 1.0 + e.wind * 0.12, 1.0 - e.wind * 0.05)
		elif e.state == Entities.Enemy.State.RECOVER:
			body.rotation.x = 0.35 * e.wind * 3.0
			body.position.y = 0.0
			body.scale = Vector3.ONE
		elif e.state == Entities.Enemy.State.SHAKE:
			body.rotation.x = 0.0
			body.rotation.z = sin(t * 40.0) * 0.25
			body.position.y = absf(sin(t * 30.0)) * 0.12
			body.scale = Vector3.ONE
		elif e.state == Entities.Enemy.State.SLEEP:
			body.rotation.x = 0.0
			body.rotation.z = 0.0
			body.position.y = -0.08 + sin(t * 1.3 + float(e.id)) * 0.03
			body.scale = Vector3(1.0, 0.92 + sin(t * 1.3 + float(e.id)) * 0.03, 1.0)
		else:
			body.rotation.x = 0.0
			body.rotation.z = 0.0
			body.position.y = absf(sin(t * 6.0 + float(e.id))) * 0.05 if e.state == Entities.Enemy.State.CHASE else 0.0
			body.scale = Vector3.ONE
		var plate: MeshInstance3D = n.get_node_or_null("body/plate")
		if plate != null:
			var m: StandardMaterial3D = plate.material_override
			m.emission_energy_multiplier = e.wind * 2.5
		var bar: MeshInstance3D = n.get_node("hp")
		var frac: float = e.hp / maxf(1.0, e.max_hp)
		bar.scale.x = maxf(0.02, frac)
		bar.visible = frac < 0.999 and e.state != Entities.Enemy.State.SLEEP
		bar.position.y = et.height + 0.55
	for id: Variant in _enemies.keys():
		if not seen.has(id):
			var n: Node3D = _enemies[id]
			n.queue_free()
			_enemies.erase(id)


func _make_enemy(e: Entities.Enemy) -> Node3D:
	var et: Types.EnemyType = tables.enemy(e.type_id)
	var n := Node3D.new()
	add_child(n)
	var body := Node3D.new()
	body.name = "body"
	n.add_child(body)
	var tint: Color = pal.col(et.colour_key)
	if e.type_id == "night_stalker":
		var torso := _mesh(_capsule(et.radius * 0.7, et.height * 1.2), _mat(tint, 0.9, 0.0))
		torso.rotation.x = PI * 0.5
		torso.position.y = et.height * 0.55
		body.add_child(torso)
		for sx: float in [-0.2, 0.2]:
			var eye := _mesh(_ico(0.07), _mat(pal.col("enemy_night_eye"), 0.3, 0.0, pal.col("enemy_night_eye"), 4.0))
			eye.position = Vector3(sx, et.height * 0.7, et.radius * 0.7)
			body.add_child(eye)
		for i: int in 4:
			var leg := _mesh(_cyl(0.04, 0.7), _mat(tint, 0.9, 0.0))
			leg.position = Vector3(-0.3 + 0.2 * float(i), 0.3, -0.3 + 0.2 * float(i % 2))
			leg.rotation.z = 0.5 if i % 2 == 0 else -0.5
			body.add_child(leg)
	else:
		var belly := _mesh(_ico(et.radius), _mat(pal.col("enemy_grub_belly"), 0.9, 0.0))
		belly.scale = Vector3(1.0, 0.75, 1.25)
		belly.position.y = et.height * 0.5
		body.add_child(belly)
		var back := _mesh(_ico(et.radius * 0.95), _mat(tint, 0.85, 0.0))
		back.scale = Vector3(1.0, 0.6, 1.2)
		back.position.y = et.height * 0.68
		body.add_child(back)
		var plate := _mesh(_box(et.radius * 0.9, 0.12, et.radius * 1.3), _mat(pal.col("pellet_body"), 0.7, 0.0, pal.col("pellet_body"), 0.0))
		plate.name = "plate"
		plate.position.y = et.height * 0.98
		body.add_child(plate)
		var head := _mesh(_ico(et.radius * 0.62), _mat(pal.col("enemy_grub_belly"), 0.9, 0.0))
		head.position = Vector3(0.0, et.height * 0.45, et.radius * 1.05)
		body.add_child(head)
		for sx: float in [-0.28, 0.28]:
			var eye := _mesh(_ico(0.12), _mat(Color(0.1, 0.08, 0.08), 0.3, 0.0))
			eye.position = Vector3(sx, et.height * 0.7, et.radius * 1.45)
			body.add_child(eye)
		for i: int in 6:
			var leg := _mesh(_cyl(0.05, 0.5), _mat(tint.darkened(0.3), 0.9, 0.0))
			var side: float = -1.0 if i % 2 == 0 else 1.0
			leg.position = Vector3(side * et.radius * 0.9, 0.22, -0.5 + 0.5 * float(i / 2))
			leg.rotation.z = side * 0.6
			body.add_child(leg)
	var bar := _mesh(_box(1.6, 0.08, 0.08), _mat(pal.col("hud_warn"), 0.5, 0.0, pal.col("hud_warn"), 1.5))
	bar.name = "hp"
	bar.position.y = et.height + 0.55
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(bar)
	return n


func _sync_gates(w: SimWorld) -> void:
	for g: Entities.Gate in w.gates:
		var n: Node3D = _gates.get(g.id)
		if n == null:
			n = Node3D.new()
			n.position = g.pos
			n.rotation.y = -g.yaw
			add_child(n)
			var mat := _mat(pal.col("gate_bramble"), 1.0, 0.0)
			var wall := _mesh(_box(g.width, 2.2, 0.9), mat)
			wall.name = "wall"
			wall.position.y = 1.1
			n.add_child(wall)
			var r := Rng.stream("gate-thorns:%d" % g.id)
			for i: int in 14:
				var thorn := _mesh(_cyl(0.05, 0.7), _mat(pal.col("scatter_stalk").darkened(0.4), 1.0, 0.0))
				thorn.position = Vector3((r.randf() - 0.5) * g.width, 0.6 + r.randf() * 1.6, (r.randf() - 0.5) * 0.9)
				thorn.rotation = Vector3(r.randf() * 2.0 - 1.0, r.randf() * TAU, r.randf() * 2.0 - 1.0)
				thorn.name = "thorn%d" % i
				n.add_child(thorn)
			var bar := _mesh(_box(g.width, 0.08, 0.08), _mat(pal.col("hud_warn"), 0.5, 0.0, pal.col("hud_warn"), 1.5))
			bar.name = "hp"
			bar.position.y = 2.7
			n.add_child(bar)
			_gates[g.id] = n
		var bar: MeshInstance3D = n.get_node("hp")
		var frac: float = g.hp / maxf(1.0, g.max_hp)
		bar.scale.x = maxf(0.02, frac)
		bar.visible = not g.open and frac < 0.999
		if g.open and n.visible:
			# it falls: sinks into the ground over half a second, then goes
			var tw: Tween = create_tween()
			tw.tween_property(n, "position:y", g.pos.y - 2.6, 0.5).set_ease(Tween.EASE_IN)
			tw.tween_callback(n.hide)


# ---- helpers ----------------------------------------------------------------------------------

static func _mat(c: Color, rough: float, metal: float, emis: Color = Color.BLACK, emis_energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emis_energy > 0.0:
		m.emission_enabled = true
		m.emission = emis
		m.emission_energy_multiplier = emis_energy
	return m


static func _mesh(m: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


static func _ico(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 7
	s.rings = 4
	return s


static func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


static func _cyl(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 8
	return c


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 8
	c.rings = 3
	return c


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
