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
var _eyaw: Dictionary = {} # enemy id -> displayed facing
var _last_t: float = 0.0
var _flicker: Array[Node3D] = [] # shock fences and gas vents that pulse
var _hold_ring: MeshInstance3D
var _safe_ring: MeshInstance3D


func build(p: PaletteData, t: ContentTables, w: SimWorld) -> void:
	pal = p
	tables = t
	_build_hold(w)
	_build_stones(w)
	_build_plants(w)
	for z: Entities.HazardZone in w.hazards:
		if z.hazard_id == "fire":
			_vents.append(_build_vent(z))
		elif z.hazard_id == "water":
			_build_pool(z)
		elif z.hazard_id == "shock":
			_flicker.append(_build_shock(z))
		elif z.hazard_id == "poison":
			_flicker.append(_build_gas(z))
		elif z.hazard_id == "freeze":
			_build_frost(z)
	for lm: Dictionary in w.landmarks:
		_build_landmark(lm)
	_build_wires(w)
	for po: Entities.Posy in w.posies:
		_build_posy(po)


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


func _build_pool(z: Entities.HazardZone) -> void:
	var n := Node3D.new()
	n.position = z.pos
	add_child(n)
	var water := _mesh(_cyl(z.radius, 0.12), _mat(pal.col("pool_water"), 0.15, 0.1, pal.col("pool_water"), 0.15))
	water.position.y = Heightfield.BASIN_DEPTH - 0.1
	var wm: StandardMaterial3D = water.material_override
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.albedo_color.a = 0.82
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(water)
	var rim := TorusMesh.new()
	rim.inner_radius = z.radius - 0.1
	rim.outer_radius = z.radius + 0.35
	rim.rings = 28
	rim.ring_segments = 5
	var bank := _mesh(rim, _mat(pal.col("pool_rim"), 1.0, 0.0))
	bank.position.y = Heightfield.BASIN_DEPTH
	n.add_child(bank)


func _build_shock(z: Entities.HazardZone) -> Node3D:
	var n := Node3D.new()
	n.position = z.pos
	add_child(n)
	var c: Color = pal.col("sprig_spark")
	var post := _mesh(_cyl(0.09, 1.6), _mat(pal.col("scatter_stalk").darkened(0.4), 0.8, 0.3))
	post.position.y = 0.8
	n.add_child(post)
	var cap_ := _mesh(_ico(0.16), _mat(c, 0.4, 0.2, c, 2.5))
	cap_.position.y = 1.65
	n.add_child(cap_)
	var disc := _mesh(_cyl(z.radius * 0.8, 0.02), _mat(c, 0.5, 0.0, c, 0.5))
	disc.name = "glow"
	var dm: StandardMaterial3D = disc.material_override
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color.a = 0.12
	disc.position.y = 0.04
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(disc)
	return n


## Live wires strung between neighbouring fence posts, two strands each.
func _build_wires(w: SimWorld) -> void:
	var posts: Array[Vector3] = []
	for z: Entities.HazardZone in w.hazards:
		if z.hazard_id == "shock":
			posts.append(z.pos)
	var c: Color = pal.col("sprig_spark")
	var mat := _mat(c, 0.4, 0.3, c, 1.6)
	for i: int in posts.size():
		for j: int in range(i + 1, posts.size()):
			var a: Vector3 = posts[i]
			var b: Vector3 = posts[j]
			var d: float = SimWorld.flat_dist(a, b)
			if d > 4.2:
				continue
			for hgt: float in [0.7, 1.3]:
				var wire := _mesh(_box(0.035, 0.035, d), mat)
				wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				# oriented by basis, not look_at: this runs before the view is in the tree
				var dir: Vector3 = (b - a).normalized()
				wire.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), (a + b) * 0.5 + Vector3(0.0, hgt, 0.0))
				add_child(wire)


func _build_gas(z: Entities.HazardZone) -> Node3D:
	var n := Node3D.new()
	n.position = z.pos
	add_child(n)
	var c: Color = pal.col("hazard_poison")
	var mound := _mesh(_ico(0.7), _mat(pal.col("terrain_loam").darkened(0.3), 1.0, 0.0))
	mound.scale = Vector3(1.0, 0.45, 1.0)
	n.add_child(mound)
	var cloud := _mesh(_ico(z.radius * 0.85), _mat(c, 1.0, 0.0, c, 0.4))
	cloud.name = "glow"
	var cm: StandardMaterial3D = cloud.material_override
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.albedo_color.a = 0.28
	cloud.scale = Vector3(1.0, 0.35, 1.0)
	cloud.position.y = 0.5
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(cloud)
	return n


func _build_frost(z: Entities.HazardZone) -> void:
	var n := Node3D.new()
	n.position = z.pos
	add_child(n)
	var c: Color = pal.col("sprig_frost")
	var sheet := _mesh(_cyl(z.radius, 0.05), _mat(c.lightened(0.3), 0.15, 0.1, c, 0.25))
	sheet.position.y = 0.03
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(sheet)
	for k: int in 5:
		var a: float = float(k) / 5.0 * TAU + float(z.id)
		var spike := CylinderMesh.new()
		spike.top_radius = 0.0
		spike.bottom_radius = 0.14
		spike.height = 0.7 + 0.3 * float(k % 2)
		spike.radial_segments = 5
		var m := _mesh(spike, _mat(c, 0.2, 0.1, c, 0.4))
		m.position = Vector3(sin(a) * z.radius * 0.6, 0.35, cos(a) * z.radius * 0.6)
		m.rotation = Vector3(cos(a) * 0.3, 0.0, -sin(a) * 0.3)
		n.add_child(m)


## A tall marker stone with a glowing cap in the territory's colour: seen from far off.
func _build_landmark(lm: Dictionary) -> void:
	var n := Node3D.new()
	n.position = lm["pos"]
	add_child(n)
	var tint: Color = pal.col(tables.sprig(str(lm["type"])).colour_key)
	var stone := _mesh(_cyl(0.55, 5.0), _mat(pal.col("landmark_stone"), 1.0, 0.0))
	stone.position.y = 2.5
	n.add_child(stone)
	var band := TorusMesh.new()
	band.inner_radius = 0.55
	band.outer_radius = 0.72
	band.rings = 16
	band.ring_segments = 5
	var ring := _mesh(band, _mat(tint, 0.6, 0.0, tint, 1.2))
	ring.position.y = 3.6
	n.add_child(ring)
	var top := _mesh(_ico(0.6), _mat(tint, 0.5, 0.0, tint, 2.2))
	top.position.y = 5.4
	n.add_child(top)
	var light := OmniLight3D.new()
	light.light_color = tint
	light.light_energy = 2.5
	light.omni_range = 9.0
	light.position.y = 5.0
	light.shadow_enabled = false
	n.add_child(light)


func _build_posy(po: Entities.Posy) -> void:
	var n := Node3D.new()
	n.position = po.pos
	add_child(n)
	var tint: Color = pal.col(tables.sprig(po.pellet_type).colour_key)
	for i: int in 3:
		var ang: float = float(i) / 3.0 * TAU + float(po.index)
		var stalk := _mesh(_cyl(0.035, 1.1), _mat(pal.col("posy_stalk"), 0.9, 0.0))
		stalk.position = Vector3(sin(ang) * 0.25, 0.55, cos(ang) * 0.25)
		stalk.rotation = Vector3(cos(ang) * 0.18, 0.0, -sin(ang) * 0.18)
		n.add_child(stalk)
		var head := _mesh(_ico(0.16), _mat(tint, 0.7, 0.0, tint, 0.35))
		head.position = Vector3(sin(ang) * 0.35, 1.12, cos(ang) * 0.35)
		n.add_child(head)


# ---- per-frame ----------------------------------------------------------------------------------

func update(w: SimWorld, alpha: float, t: float) -> void:
	var dt: float = clampf(t - _last_t, 0.0, 0.1)
	_last_t = t
	for f: Node3D in _flicker:
		var g: MeshInstance3D = f.get_node_or_null("glow")
		if g != null:
			var m: StandardMaterial3D = g.material_override
			m.albedo_color.a = 0.08 + 0.14 * absf(sin(t * 9.0 + f.position.x)) * (0.6 + 0.4 * sin(t * 23.0 + f.position.z))
			g.scale.y = 1.0 + 0.15 * sin(t * 2.0 + f.position.x)
	_sync_shrines(w)
	_sync_objects(w, alpha)
	_sync_enemies(w, alpha, t, dt)
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
		if o.absorb_t >= 0.0:
			# drawn up into the shrine: rises, spins, shrinks
			var u: float = clampf(o.absorb_t / 0.9, 0.0, 1.0)
			n.position = p
			n.rotation.y = o.yaw + u * 9.0
			n.scale = Vector3.ONE * maxf(0.05, 1.0 - u * u)
			continue
		n.scale = Vector3.ONE
		var lift: float = 0.0
		if o.carriers.size() > 0:
			lift = 0.18
			if o.prev.distance_squared_to(o.pos) > 0.0000001:
				lift += absf(sin(_last_t * 10.0 + float(o.id))) * 0.05 # bobbing on many small shoulders
		n.position = p + Vector3(0.0, lift, 0.0)
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


func _sync_enemies(w: SimWorld, alpha: float, t: float, dt: float) -> void:
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
		var ey: float = e.yaw
		if _eyaw.has(e.id):
			ey = lerp_angle(float(_eyaw[e.id]), e.yaw, clampf(dt * 10.0, 0.0, 1.0))
		_eyaw[e.id] = ey
		n.rotation.y = ey
		var body: Node3D = n.get_node("body")
		var ice: Node3D = n.get_node_or_null("ice")
		if ice != null:
			ice.visible = e.state == Entities.Enemy.State.FROZEN
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
		elif e.state == Entities.Enemy.State.FROZEN:
			body.rotation.z = 0.0
			body.position.y = 0.0
			body.scale = Vector3.ONE
		elif e.state == Entities.Enemy.State.SLEEP:
			body.rotation.x = 0.0
			body.rotation.z = 0.0
			body.position.y = -0.08 + sin(t * 1.3 + float(e.id)) * 0.03
			body.scale = Vector3(1.0, 0.92 + sin(t * 1.3 + float(e.id)) * 0.03, 1.0)
		else:
			body.rotation.x = 0.0
			var mv: float = Vector2(e.pos.x - e.prev.x, e.pos.z - e.prev.z).length() / SimWorld.FIXED_DT
			var gait: float = clampf(mv / maxf(0.5, et.speed), 0.0, 1.0)
			body.rotation.z = sin(t * 12.0 + float(e.id)) * 0.08 * gait
			body.position.y = absf(sin(t * 12.0 + float(e.id))) * 0.06 * gait
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
	if e.type_id == "field_beetle":
		var shell := _mesh(_ico(et.radius), _mat(pal.col("enemy_beetle_shell"), 0.5, 0.1))
		shell.scale = Vector3(1.0, 0.55, 1.3)
		shell.position.y = et.height * 0.6
		body.add_child(shell)
		var under := _mesh(_ico(et.radius * 0.8), _mat(tint, 0.9, 0.0))
		under.scale = Vector3(1.0, 0.5, 1.2)
		under.position.y = et.height * 0.4
		body.add_child(under)
		var head := _mesh(_ico(et.radius * 0.45), _mat(tint, 0.9, 0.0))
		head.position = Vector3(0.0, et.height * 0.5, et.radius * 1.15)
		body.add_child(head)
		for i: int in 6:
			var leg := _mesh(_cyl(0.025, 0.4), _mat(tint, 0.9, 0.0))
			var side: float = -1.0 if i % 2 == 0 else 1.0
			leg.position = Vector3(side * et.radius * 0.9, 0.15, -0.25 + 0.25 * float(i / 2))
			leg.rotation.z = side * 0.7
			body.add_child(leg)
	elif e.type_id == "night_stalker":
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
	# frozen solid: a pale shell, shown only while frozen
	var ice_c: Color = pal.col("sprig_frost")
	var ice := _mesh(_ico(et.radius * 1.3), _mat(ice_c, 0.1, 0.2, ice_c, 0.6))
	ice.name = "ice"
	var im: StandardMaterial3D = ice.material_override
	im.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	im.albedo_color.a = 0.45
	ice.scale = Vector3(1.0, 0.85, 1.25)
	ice.position.y = et.height * 0.55
	ice.visible = false
	n.add_child(ice)
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
