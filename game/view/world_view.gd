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
	_build_scenery(w)
	_build_scenery2(w)
	_build_plants(w)
	_build_grass(w)
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
	_build_camps(w)
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
	var stones: Array[Dictionary] = []
	for ob: Dictionary in w.obstacles:
		if str(ob.get("kind", "stone")) == "stone":
			stones.append(ob)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var rock := SphereMesh.new()
	rock.radius = 1.0
	rock.height = 2.0
	rock.radial_segments = 11
	rock.rings = 6
	mm.mesh = rock
	mm.instance_count = stones.size()
	var base: Color = pal.col("scatter_stone")
	for i: int in stones.size():
		var ob: Dictionary = stones[i]
		var c: Vector3 = ob["pos"]
		var r: float = float(ob["r"])
		var h: float = float(ob["h"])
		var b := Basis.from_euler(Vector3(0.2 * float(i % 3), float(i) * 0.7, 0.15 * float(i % 2))).scaled(Vector3(r * 1.15, h, r * 1.05))
		mm.set_instance_transform(i, Transform3D(b, c + Vector3(0.0, h * 0.35, 0.0)))
		# a little variety: some warmer, some mossier, some paler; then the climate's own look
		var v: float = float((i * 37) % 11) / 10.0
		var tint: Color = base.lerp(pal.col("terrain_moss"), 0.25 * v) if i % 3 == 0 else base.lightened(0.12 * v)
		var cl: Vector3 = w.field.climate(c.x, c.z)
		tint = tint.lerp(pal.col("ice") if h > 3.0 else pal.col("snow"), cl.x * 0.7)
		tint = tint.lerp(pal.col("sandstone"), cl.y * 0.85)
		tint = tint.lerp(pal.col("terrain_moss").darkened(0.15), cl.z * 0.45)
		mm.set_instance_color(i, tint.srgb_to_linear())
	_stones = MultiMeshInstance3D.new()
	_stones.multimesh = mm
	_stones.material_override = Cutout.mat_vc(0.95, 3.0)
	_stones.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_stones)


## The bigger furniture from w.scenery. Tall tops (mushroom caps, daisy heads) dither away when
## the camera comes close so they never hide the gnome.
func _build_scenery(w: SimWorld) -> void:
	var bark := _mat(pal.col("bark"), 1.0, 0.0)
	var wood := _mat(pal.col("fallen_log"), 0.95, 0.0)
	var ring_c := _mat(pal.col("terrain_dry").lightened(0.15), 0.9, 0.0)
	var moss := _mat(pal.col("terrain_moss").darkened(0.05), 1.0, 0.0)
	var ruin := _mat(pal.col("ruin_stone"), 0.95, 0.0)
	var ruin_dark := _mat(pal.col("ruin_stone").darkened(0.18), 0.95, 0.0)
	var stalk_m := _mat(pal.col("mushroom_stalk"), 0.8, 0.0)
	var cap_m := _fade(_mat(pal.col("mushroom_cap"), 0.6, 0.0))
	var spot_m := _fade(_mat(pal.col("mushroom_spot"), 0.7, 0.0))
	var stem_m := _mat(pal.col("posy_stalk"), 0.9, 0.0)
	var petal_m := _fade(_mat(Color(0.97, 0.96, 0.92), 0.7, 0.0))
	var heart_m: Array[StandardMaterial3D] = [
		_fade(_mat(pal.col("flower_a"), 0.6, 0.0, pal.col("flower_a"), 0.15)),
		_fade(_mat(pal.col("flower_b"), 0.6, 0.0, pal.col("flower_b"), 0.15)),
		_fade(_mat(pal.col("flower_c"), 0.6, 0.0, pal.col("flower_c"), 0.15)),
	]
	for sc: Dictionary in w.scenery:
		var kind: String = sc["kind"]
		match kind:
			"stump":
				var n := Node3D.new()
				n.position = sc["pos"]
				n.rotation.y = float(sc["rot"])
				add_child(n)
				var rad: float = float(sc["r"])
				var h: float = float(sc["h"])
				var trunk := CylinderMesh.new()
				trunk.top_radius = rad * 0.92
				trunk.bottom_radius = rad * 1.08
				trunk.height = h + 0.6
				trunk.radial_segments = 14
				var tm := _mesh(trunk, bark)
				tm.position.y = (h + 0.6) * 0.5 - 0.6
				n.add_child(tm)
				var top := _mesh(_cyl(rad * 0.86, 0.06), ring_c)
				top.position.y = h + 0.02
				n.add_child(top)
				for k: int in 3:
					var ring := TorusMesh.new()
					ring.inner_radius = rad * (0.2 + 0.2 * float(k))
					ring.outer_radius = ring.inner_radius + 0.05
					ring.rings = 20
					ring.ring_segments = 3
					var rm := _mesh(ring, bark)
					rm.position.y = h + 0.05
					rm.scale.y = 0.3
					n.add_child(rm)
				for k: int in 5:
					var a: float = float(k) / 5.0 * TAU + 0.3
					var root := _mesh(_capsule(rad * 0.28, rad * 1.6), bark)
					root.position = Vector3(sin(a) * rad * 1.05, 0.15, cos(a) * rad * 1.05)
					root.rotation = Vector3(cos(a) * 1.25, 0.0, -sin(a) * 1.25)
					n.add_child(root)
				var mp := _mesh(_ico(rad * 0.35), moss)
				mp.scale = Vector3(1.4, 0.35, 1.0)
				mp.position = Vector3(rad * 0.3, h + 0.05, -rad * 0.2)
				n.add_child(mp)
			"log":
				var a: Vector3 = sc["a"]
				var b: Vector3 = sc["b"]
				var rad: float = float(sc["r"])
				var length: float = a.distance_to(b)
				var dir: Vector3 = (b - a).normalized()
				var n := Node3D.new()
				n.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), (a + b) * 0.5 + Vector3(0.0, rad * 0.8, 0.0))
				add_child(n)
				var cm := CylinderMesh.new()
				cm.top_radius = rad * 0.9
				cm.bottom_radius = rad
				cm.height = length
				cm.radial_segments = 12
				var lm := _mesh(cm, wood)
				lm.rotation.x = PI * 0.5
				n.add_child(lm)
				for end: float in [-0.5, 0.5]:
					var face := _mesh(_cyl(rad * 0.88, 0.04), ring_c)
					face.rotation.x = PI * 0.5
					face.position.z = end * length
					n.add_child(face)
				var stub := _mesh(_cyl(rad * 0.3, rad * 1.6), wood)
				stub.position = Vector3(0.0, rad * 0.9, length * 0.15)
				stub.rotation.z = 0.6
				n.add_child(stub)
				for k: int in 3:
					var mp := _mesh(_ico(rad * 0.5), moss)
					mp.scale = Vector3(1.0, 0.35, 1.6)
					mp.position = Vector3(0.0, rad * 0.85, length * (-0.3 + 0.3 * float(k)))
					n.add_child(mp)
			"column":
				var n := Node3D.new()
				n.position = sc["pos"]
				n.rotation.y = float(sc["rot"])
				add_child(n)
				var rad: float = float(sc["r"])
				var h: float = float(sc["h"])
				var base := _mesh(_box(rad * 2.6, 0.35, rad * 2.6), ruin_dark)
				base.position.y = 0.1
				n.add_child(base)
				var shaft := CylinderMesh.new()
				shaft.top_radius = rad * 0.92
				shaft.bottom_radius = rad
				shaft.height = h
				shaft.radial_segments = 10
				var sm := _mesh(shaft, ruin)
				sm.position.y = h * 0.5
				if bool(sc["broken"]):
					sm.rotation.z = 0.04
				n.add_child(sm)
				if bool(sc["broken"]):
					var chunk := _mesh(_ico(rad * 0.9), ruin)
					chunk.scale = Vector3(1.0, 0.5, 1.0)
					chunk.position.y = h
					chunk.rotation = Vector3(0.4, 0.0, 0.3)
					n.add_child(chunk)
				else:
					var capital := _mesh(_box(rad * 2.5, 0.35, rad * 2.5), ruin_dark)
					capital.position.y = h + 0.12
					n.add_child(capital)
				var mp := _mesh(_ico(rad * 1.05), moss)
				mp.scale = Vector3(1.0, 0.3, 1.0)
				mp.position.y = h + (0.3 if not bool(sc["broken"]) else 0.15)
				n.add_child(mp)
				var vine := _mesh(_box(0.12, h * 0.7, 0.05), moss)
				vine.position = Vector3(0.0, h * 0.4, rad * 0.95)
				n.add_child(vine)
			"wall":
				var a: Vector3 = sc["a"]
				var b: Vector3 = sc["b"]
				var h: float = float(sc["h"])
				var length: float = Vector2(b.x - a.x, b.z - a.z).length()
				var dir: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
				var n := Node3D.new()
				n.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), (a + b) * 0.5)
				add_child(n)
				# courses of blocks, the top course broken in steps
				var courses: int = maxi(2, int(h / 0.45))
				for k: int in courses:
					var top_course: bool = k == courses - 1
					var cl: float = length * (0.7 if top_course else 1.0)
					var blk := _mesh(_box(float(sc["t"]) - 0.04 * float(k % 2), 0.43, cl), ruin if k % 2 == 0 else ruin_dark)
					blk.position = Vector3(0.0, 0.22 + 0.45 * float(k), (length - cl) * 0.5 * (1.0 if k % 2 == 0 else -1.0) * (1.0 if top_course else 0.0))
					n.add_child(blk)
				var mp := _mesh(_box(float(sc["t"]) + 0.08, 0.1, length * 0.6), moss)
				mp.position.y = 0.45 * float(courses) + 0.02
				n.add_child(mp)
			"block":
				var s: float = float(sc["s"])
				var blk := _mesh(_box(s * 1.6, s * 1.1, s * 1.3), ruin)
				blk.position = sc["pos"] + Vector3(0.0, s * 0.45, 0.0)
				blk.rotation = Vector3(0.12, float(sc["rot"]), 0.08)
				add_child(blk)
			"mushroom":
				var n := Node3D.new()
				n.position = sc["pos"]
				n.rotation = Vector3(float(sc["tilt"]), float(sc["rot"]), float(sc["tilt"]) * 0.5)
				add_child(n)
				var h: float = float(sc["h"])
				var stalk: float = float(sc["stalk"])
				var cap: float = float(sc["cap"])
				var st := CylinderMesh.new()
				st.top_radius = stalk * 0.8
				st.bottom_radius = stalk * 1.15
				st.height = h
				st.radial_segments = 10
				var stm := _mesh(st, stalk_m)
				stm.position.y = h * 0.5
				n.add_child(stm)
				var skirt := _mesh(_cyl(stalk * 1.6, 0.06), stalk_m)
				skirt.position.y = h * 0.72
				n.add_child(skirt)
				var dome := SphereMesh.new()
				dome.radius = cap
				dome.height = cap * 1.1
				dome.radial_segments = 16
				dome.rings = 8
				dome.is_hemisphere = true
				var cm := _mesh(dome, cap_m)
				cm.position.y = h - cap * 0.08
				n.add_child(cm)
				var under := _mesh(_cyl(cap * 0.97, 0.05), stalk_m)
				under.position.y = h - cap * 0.08
				n.add_child(under)
				for k: int in 6:
					var a: float = float(k) / 6.0 * TAU + float(k) * 0.4
					var rr: float = cap * (0.35 + 0.35 * float(k % 2))
					var spot := _mesh(_ico(cap * 0.11), spot_m)
					var up: float = sqrt(maxf(0.0, cap * cap - rr * rr)) * 0.55
					spot.position = Vector3(sin(a) * rr, h - cap * 0.08 + up, cos(a) * rr)
					spot.scale = Vector3(1.0, 0.35, 1.0)
					n.add_child(spot)
			"daisy":
				var n := Node3D.new()
				n.position = sc["pos"]
				add_child(n)
				var h: float = float(sc["h"])
				var lean: Vector2 = sc["lean"]
				var stem := _mesh(_cyl(0.07, h), stem_m)
				stem.position.y = h * 0.5
				n.add_child(stem)
				n.rotation = Vector3(lean.x, float(sc["rot"]), lean.y)
				for k: int in 2:
					var leaf := _mesh(_ico(0.3), stem_m)
					leaf.scale = Vector3(0.35, 0.12, 1.4)
					var a: float = float(k) * PI + 0.6
					leaf.position = Vector3(sin(a) * 0.35, h * (0.25 + 0.2 * float(k)), cos(a) * 0.35)
					leaf.rotation.y = a
					n.add_child(leaf)
				var bloom: float = float(sc["bloom"])
				var head := Node3D.new()
				head.position.y = h
				head.rotation.x = 0.35
				n.add_child(head)
				for k: int in 12:
					var a: float = float(k) / 12.0 * TAU
					var petal := _mesh(_ico(bloom * 0.28), petal_m)
					petal.scale = Vector3(0.45, 0.12, 1.5)
					petal.position = Vector3(sin(a) * bloom * 0.55, 0.0, cos(a) * bloom * 0.55)
					petal.rotation.y = a
					head.add_child(petal)
				var heart := _mesh(_ico(bloom * 0.3), heart_m[int(sc["c"]) % 3])
				heart.scale = Vector3(1.0, 0.5, 1.0)
				heart.position.y = 0.05
				head.add_child(heart)


## The second set of furniture (2026-10-20): great trees, snowy pines, jungle trees with vines,
## hollow logs and tipped pots you walk through, upright pots, bricks, lily pads, reeds, cacti,
## the ribs of something huge, giant leaves. Anything tall uses a Cutout material.
func _build_scenery2(w: SimWorld) -> void:
	var bark := Cutout.mat(pal.col("bark"), 0.95)
	var bark_dark := Cutout.mat(pal.col("bark").darkened(0.25), 0.95)
	var crown_a := Cutout.mat(pal.col("canopy"), 0.85, 5.0)
	var crown_b := Cutout.mat(pal.col("canopy_light"), 0.85, 5.0)
	var pine_m := Cutout.mat(pal.col("pine"), 0.9, 4.0)
	var snow_m := Cutout.mat(pal.col("snow"), 0.5, 4.0)
	var jcrown := Cutout.mat(pal.col("jungle_canopy"), 0.8, 5.5)
	var jcrown_b := Cutout.mat(pal.col("jungle_canopy").lightened(0.15), 0.8, 5.5)
	var vine_m := Cutout.mat(pal.col("vine"), 0.9, 3.0)
	var wood := Cutout.mat(pal.col("fallen_log"), 0.95)
	var ring_m := Cutout.mat(pal.col("terrain_dry").lightened(0.15), 0.9)
	var moss := Cutout.mat(pal.col("terrain_moss").darkened(0.05), 1.0)
	var terra := Cutout.mat(pal.col("terracotta"), 0.8)
	var terra_dark := Cutout.mat(pal.col("terracotta").darkened(0.3), 0.9)
	var soil := _mat(pal.col("terrain_loam").darkened(0.3), 1.0, 0.0)
	var brick_m := _mat(pal.col("brick"), 0.9, 0.0)
	var lily_m := _mat(pal.col("lily"), 0.6, 0.0)
	var lily_f := _mat(pal.col("lily_flower"), 0.6, 0.0, pal.col("lily_flower"), 0.15)
	var reed_m := _mat(pal.col("reed"), 0.9, 0.0)
	var cattail_m := _mat(pal.col("cattail"), 0.95, 0.0)
	var cactus_m := Cutout.mat(pal.col("cactus"), 0.7, 2.6)
	var cactus_f := _mat(pal.col("flower_b"), 0.6, 0.0, pal.col("flower_b"), 0.2)
	var bone_m := Cutout.mat(pal.col("bone"), 0.7, 3.5)
	var socket_m := _mat(Color(0.12, 0.1, 0.08), 1.0, 0.0)
	var leaf_m := Cutout.mat(pal.col("jungle_leaf"), 0.6, 3.0)
	for sc: Dictionary in w.scenery:
		match str(sc["kind"]):
			"tree":
				_tree_view(sc, bark, bark_dark, [crown_a, crown_b], false)
			"jungle_tree":
				_tree_view(sc, bark_dark, bark, [jcrown, jcrown_b], true)
				var n: Node3D = get_child(get_child_count() - 1)
				var h: float = float(sc["h"])
				var crown: float = float(sc["crown"])
				for k: int in int(sc["vines"]):
					var a: float = float(k) * 2.3 + float(sc["rot"])
					var length: float = h * (0.55 + 0.1 * float(k % 3))
					var vine := _mesh(_cyl(0.07, length), vine_m)
					vine.position = Vector3(sin(a) * crown * 0.7, h - length * 0.5, cos(a) * crown * 0.7)
					vine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					n.add_child(vine)
			"pine":
				var n := Node3D.new()
				n.position = sc["pos"]
				n.rotation.y = float(sc["rot"])
				add_child(n)
				var h: float = float(sc["h"])
				var rad: float = float(sc["r"])
				var trunk := _mesh(_cyl(rad * 0.55, h * 0.4), bark_dark)
				trunk.position.y = h * 0.2
				n.add_child(trunk)
				for k: int in 4:
					var u: float = float(k) / 4.0
					var tier := CylinderMesh.new()
					tier.top_radius = 0.0
					tier.bottom_radius = rad * (3.4 - 2.2 * u)
					tier.height = h * 0.38
					tier.radial_segments = 12
					var tm := _mesh(tier, pine_m)
					tm.position.y = h * (0.28 + 0.2 * u) + h * 0.19
					n.add_child(tm)
					var cap := CylinderMesh.new()
					cap.top_radius = 0.0
					cap.bottom_radius = rad * (3.4 - 2.2 * u) * 0.62
					cap.height = h * 0.2
					cap.radial_segments = 12
					var cm := _mesh(cap, snow_m)
					cm.position.y = tm.position.y + h * 0.1
					n.add_child(cm)
			"hollow", "pot_tipped":
				_tube_view(sc, wood if sc["kind"] == "hollow" else terra, ring_m if sc["kind"] == "hollow" else terra_dark, moss, str(sc["kind"]) == "pot_tipped")
			"pot":
				var n := Node3D.new()
				n.position = sc["pos"]
				n.rotation.y = float(sc["rot"])
				add_child(n)
				var rad: float = float(sc["r"])
				var h: float = float(sc["h"])
				var body := CylinderMesh.new()
				body.top_radius = rad
				body.bottom_radius = rad * 0.78
				body.height = h
				body.radial_segments = 20
				var bm := _mesh(body, terra)
				bm.position.y = h * 0.5
				n.add_child(bm)
				var rim := TorusMesh.new()
				rim.inner_radius = rad * 0.92
				rim.outer_radius = rad * 1.12
				rim.rings = 24
				rim.ring_segments = 8
				var rm := _mesh(rim, terra_dark)
				rm.position.y = h
				n.add_child(rm)
				var dirt := _mesh(_cyl(rad * 0.9, 0.05), soil)
				dirt.position.y = h - 0.15
				n.add_child(dirt)
				var shoot := _mesh(_ico(rad * 0.35), moss)
				shoot.scale = Vector3(1.0, 1.6, 1.0)
				shoot.position.y = h + rad * 0.3
				n.add_child(shoot)
			"bricks":
				var n := Node3D.new()
				n.position = sc["pos"]
				n.rotation.y = float(sc["rot"])
				add_child(n)
				for k: int in int(sc["n"]):
					var b := _mesh(_box(1.5, 0.7, 0.75), brick_m)
					b.position = Vector3((float(k % 3) - 1.0) * 1.0, 0.35 + 0.72 * float(k / 3), 0.0)
					b.rotation.y = 0.12 * float((k * 7) % 5 - 2)
					n.add_child(b)
			"lily":
				var n := Node3D.new()
				n.position = sc["pos"] + Vector3(0.0, Heightfield.BASIN_DEPTH * 0.0 - 0.02, 0.0)
				add_child(n)
				var rad: float = float(sc["r"])
				var r := Rng.stream("lily:%s" % str(sc["pos"]))
				for k: int in 4 + int(rad):
					var a: float = r.randf() * TAU
					var d: float = r.randf() * rad * 0.8
					var pad := _mesh(_cyl(0.45 + r.randf() * 0.4, 0.04), lily_m)
					pad.position = Vector3(sin(a) * d, 0.02, cos(a) * d)
					n.add_child(pad)
					if k % 3 == 0:
						var fl := _mesh(_ico(0.18), lily_f)
						fl.scale = Vector3(1.0, 0.6, 1.0)
						fl.position = pad.position + Vector3(0.1, 0.1, 0.0)
						n.add_child(fl)
			"reeds":
				var n := Node3D.new()
				n.position = sc["pos"]
				n.rotation.y = float(sc["rot"])
				add_child(n)
				var h: float = float(sc["h"])
				for k: int in int(sc["n"]):
					var a: float = float(k) * 2.4
					var d: float = 0.15 + 0.12 * float(k % 4)
					var hh: float = h * (0.75 + 0.25 * float((k * 3) % 4) / 3.0)
					var stalk := _mesh(_cyl(0.035, hh), reed_m)
					stalk.position = Vector3(sin(a) * d, hh * 0.5, cos(a) * d)
					stalk.rotation = Vector3(cos(a) * 0.08, 0.0, -sin(a) * 0.08)
					n.add_child(stalk)
					if k % 2 == 0:
						var tail := _mesh(_capsule(0.08, 0.4), cattail_m)
						tail.position = stalk.position + Vector3(0.0, hh * 0.38, 0.0)
						n.add_child(tail)
			"cactus":
				var n := Node3D.new()
				n.position = sc["pos"]
				n.rotation.y = float(sc["rot"])
				add_child(n)
				var rad: float = float(sc["r"])
				var h: float = float(sc["h"])
				var col := _mesh(_capsule(rad, h), cactus_m)
				col.position.y = h * 0.5
				n.add_child(col)
				for k: int in int(sc["arms"]):
					var a: float = float(k) * 2.1
					var arm := _mesh(_capsule(rad * 0.6, h * 0.35), cactus_m)
					arm.position = Vector3(sin(a) * rad * 1.6, h * (0.45 + 0.12 * float(k)), cos(a) * rad * 1.6)
					n.add_child(arm)
					var elbow := _mesh(_capsule(rad * 0.55, rad * 1.9), cactus_m)
					elbow.position = Vector3(sin(a) * rad * 0.9, arm.position.y - h * 0.15, cos(a) * rad * 0.9)
					elbow.rotation = Vector3(cos(a) * PI * 0.5, 0.0, -sin(a) * PI * 0.5)
					n.add_child(elbow)
				if int(sc["arms"]) % 2 == 1:
					var fl := _mesh(_ico(rad * 0.45), cactus_f)
					fl.position.y = h + rad * 0.2
					n.add_child(fl)
			"ribs":
				var a: Vector3 = sc["a"]
				var b: Vector3 = sc["b"]
				var half: float = float(sc["half"])
				var dir: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
				var length: float = Vector2(b.x - a.x, b.z - a.z).length()
				var n := Node3D.new()
				n.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), a)
				add_child(n)
				var count: int = int(sc["n"])
				for k: int in count:
					var u: float = (float(k) + 0.5) / float(count)
					var rib := TorusMesh.new()
					rib.inner_radius = half - 0.18
					rib.outer_radius = half + 0.18
					rib.rings = 24
					rib.ring_segments = 6
					var rm := _mesh(rib, bone_m)
					# a vertical hoop across the spine, half of it under the ground
					rm.rotation.x = PI * 0.5
					rm.position = Vector3(0.0, 0.2 - 0.3 * absf(u - 0.5), -length * u)
					rm.scale = Vector3(1.0 - 0.35 * absf(u - 0.45), 1.0, 1.0 - 0.35 * absf(u - 0.45))
					n.add_child(rm)
				var spine := _mesh(_cyl(0.22, length), bone_m)
				spine.rotation.x = PI * 0.5
				spine.position = Vector3(0.0, half * 0.92, -length * 0.5)
				n.add_child(spine)
				var skull := _mesh(_ico(1.6), bone_m)
				skull.scale = Vector3(1.0, 0.75, 1.4)
				skull.position = Vector3(0.0, 0.9, 1.8)
				n.add_child(skull)
				for sx: float in [-1.0, 1.0]:
					var socket := _mesh(_ico(0.38), socket_m)
					socket.position = Vector3(0.6 * sx, 1.25, 2.9)
					n.add_child(socket)
			"bigleaf":
				var n := Node3D.new()
				n.position = sc["pos"]
				n.rotation.y = float(sc["rot"])
				add_child(n)
				var s: float = float(sc["s"])
				var stalk := _mesh(_cyl(0.12, s * 0.6), _mat(pal.col("vine"), 0.9, 0.0))
				stalk.position.y = s * 0.3
				n.add_child(stalk)
				for k: int in int(sc["n"]):
					var a: float = float(k) / float(sc["n"]) * TAU
					var leaf := _mesh(_ico(s * 0.5), leaf_m)
					leaf.scale = Vector3(0.55, 0.07, 1.5)
					leaf.position = Vector3(sin(a) * s * 0.55, s * 0.55 + 0.1 * float(k % 2), cos(a) * s * 0.55)
					leaf.rotation = Vector3(-0.35, a, 0.0)
					n.add_child(leaf)


## A great tree: a tapering trunk with root flares, a crown of overlapping masses up high.
func _tree_view(sc: Dictionary, bark: Material, bark2: Material, crowns: Array, flat: bool) -> void:
	var n := Node3D.new()
	n.position = sc["pos"]
	n.rotation.y = float(sc["rot"])
	add_child(n)
	var rad: float = float(sc["r"])
	var h: float = float(sc["h"])
	var crown: float = float(sc["crown"])
	var trunk := CylinderMesh.new()
	trunk.top_radius = rad * 0.55
	trunk.bottom_radius = rad
	trunk.height = h
	trunk.radial_segments = 14
	var tm := _mesh(trunk, bark)
	tm.position.y = h * 0.5
	n.add_child(tm)
	for k: int in 5:
		var a: float = float(k) / 5.0 * TAU + 0.4
		var root := _mesh(_capsule(rad * 0.38, rad * 2.4), bark2)
		root.position = Vector3(sin(a) * rad * 1.1, rad * 0.25, cos(a) * rad * 1.1)
		root.rotation = Vector3(cos(a) * 1.15, 0.0, -sin(a) * 1.15)
		n.add_child(root)
	# two low boughs
	for k: int in 2:
		var a: float = float(k) * 2.6 + 0.8
		var bough := _mesh(_capsule(rad * 0.22, crown * 0.9), bark)
		bough.position = Vector3(sin(a) * crown * 0.3, h * 0.78, cos(a) * crown * 0.3)
		bough.rotation = Vector3(cos(a) * 0.9, 0.0, -sin(a) * 0.9)
		n.add_child(bough)
	var masses: int = 7
	for k: int in masses:
		var a: float = float(k) / float(masses) * TAU
		var d: float = crown * (0.15 if k == 0 else 0.55)
		var mr: float = crown * (0.55 + 0.1 * float(k % 3))
		var mass := _mesh(_ico(mr), crowns[k % crowns.size()])
		mass.scale = Vector3(1.0, 0.42 if flat else 0.68, 1.0)
		mass.position = Vector3(sin(a) * d, h + (0.0 if flat else crown * 0.2) + 0.4 * float(k % 2), cos(a) * d)
		n.add_child(mass)


## A tube lying on the ground: hollow log (open both ends, bark, moss on top) or a tipped flower
## pot (one end closed, a rim at the mouth).
func _tube_view(sc: Dictionary, body: Material, end_m: Material, moss: Material, pot: bool) -> void:
	var a: Vector3 = sc["a"]
	var b: Vector3 = sc["b"]
	var rad: float = float(sc["r"])
	var y: float = float(sc["y"])
	var dir: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	var length: float = Vector2(b.x - a.x, b.z - a.z).length()
	var mid := Vector3((a.x + b.x) * 0.5, y + rad * 0.55, (a.z + b.z) * 0.5)
	var n := Node3D.new()
	n.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), mid)
	add_child(n)
	var cm := CylinderMesh.new()
	cm.top_radius = rad * (1.12 if pot else 0.95)
	cm.bottom_radius = rad * (0.85 if pot else 1.0)
	cm.height = length
	cm.radial_segments = 22
	cm.cap_top = false
	cm.cap_bottom = false
	var tube := _mesh(cm, body)
	tube.rotation.x = -PI * 0.5 # the cylinder's top end at the mouth (a), bottom at b
	n.add_child(tube)
	var lip := TorusMesh.new()
	lip.inner_radius = rad * (1.05 if pot else 0.85)
	lip.outer_radius = rad * (1.22 if pot else 1.02)
	lip.rings = 26
	lip.ring_segments = 6
	var mouth := _mesh(lip, end_m)
	mouth.rotation.x = PI * 0.5
	mouth.position.z = length * 0.5
	n.add_child(mouth)
	if pot:
		var back := _mesh(_cyl(rad * 0.86, 0.12), end_m)
		back.rotation.x = PI * 0.5
		back.position.z = -length * 0.5
		n.add_child(back)
	else:
		var tail := _mesh(lip, end_m)
		tail.rotation.x = PI * 0.5
		tail.position.z = -length * 0.5
		n.add_child(tail)
		for k: int in 3:
			var mp := _mesh(_ico(rad * 0.5), moss)
			mp.scale = Vector3(1.0, 0.3, 1.8)
			mp.position = Vector3(0.0, rad * 0.92, length * (-0.3 + 0.3 * float(k)))
			n.add_child(mp)


## A carpet of short grass tufts and clover, thick on green ground, thin on rock and sand, none
## on snow or water, in 64 m patches that each draw only within reach of the camera.
func _build_grass(w: SimWorld) -> void:
	var tuft := _tuft_mesh()
	var clover := _clover_mesh()
	var b: float = w.field.bound
	var chunk: float = 64.0
	var nc: int = int(ceilf(b * 2.0 / chunk))
	var green: Color = pal.col("scatter_leaf").lightened(0.12)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for cx: int in nc:
		for cz: int in nc:
			var r := Rng.stream("grass:%d:%d:%d" % [w.seed, cx, cz])
			var tufts: Array = []
			var clovers: Array = []
			var x0: float = -b + float(cx) * chunk
			var z0: float = -b + float(cz) * chunk
			for i: int in 900:
				var p := Vector3(x0 + r.randf() * chunk, 0.0, z0 + r.randf() * chunk)
				var roll: float = r.randf()
				var s: float = 0.6 + r.randf() * 0.8
				var rot: float = r.randf() * TAU
				if absf(p.x) > b or absf(p.z) > b:
					continue
				var cl: Vector3 = w.field.climate(p.x, p.z)
				var bw: Vector4 = w.field.biome(p.x, p.z)
				# thin where it is cold, dry, or rock; none on snow
				if roll < cl.x * 0.95 + cl.y * 0.8 + bw.y * 0.6:
					continue
				if w.blocked(p, 0.1):
					continue
				var wet: bool = false
				for nb: Dictionary in w.nav_blockers:
					if SimWorld.flat_dist(p, nb["pos"]) < float(nb["r"]) - 0.2:
						wet = true
						break
				if wet:
					continue
				var g: Vector3 = w.ground(p)
				var tint: Color = green.lerp(pal.col("terrain_dry"), cl.y * 0.8).lerp(pal.col("jungle_leaf"), cl.z * 0.6).lerp(pal.col("snow"), cl.x * 0.4)
				tint = tint.lerp(pal.col("terrain_wood"), bw.x * 0.4).darkened(0.08 * float(i % 3))
				var xf := Transform3D(Basis(Vector3.UP, rot).scaled(Vector3(s, s * (1.0 + cl.z * 0.8), s)), g)
				if cl.x > 0.4:
					tint = tint.lerp(pal.col("snow"), 0.35)
				if roll > 0.82 and cl.y < 0.3 and cl.x < 0.4:
					clovers.append([xf, tint.lightened(0.05).srgb_to_linear()])
				else:
					tufts.append([xf, tint.srgb_to_linear()])
			for pair: Array in [[tuft, tufts], [clover, clovers]]:
				var rows: Array = pair[1]
				if rows.is_empty():
					continue
				var mi: MultiMeshInstance3D = _instanced(pair[0], rows)
				mi.material_override = mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.visibility_range_end = 95.0
				mi.visibility_range_end_margin = 15.0
				mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


## Five thin blades from one root, leaning out.
static func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k: int in 5:
		var a: float = float(k) / 5.0 * TAU + 0.3
		var out := Vector3(sin(a), 0.0, cos(a))
		var side := Vector3(cos(a), 0.0, -sin(a)) * 0.025
		var tip: Vector3 = out * 0.12 + Vector3(0.0, 0.32 + 0.06 * float(k % 2), 0.0)
		_tri(st, -side, tip, side)
	st.generate_normals()
	return st.commit()


## Dither the material away close to the camera (tall tops never hide the gnome).
static func _fade(m: StandardMaterial3D) -> StandardMaterial3D:
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	m.distance_fade_min_distance = 3.5
	m.distance_fade_max_distance = 8.0
	return m


func _build_plants(w: SimWorld) -> void:
	# one instanced mesh per shape; colour per instance
	var blade := _blade_mesh()
	var clover := _clover_mesh()
	var bloom := _bloom_mesh()
	var blades: Array = []
	var clovers: Array = []
	var blooms: Array = []
	var leaf: Color = pal.col("scatter_leaf").srgb_to_linear()
	var stalk: Color = pal.col("scatter_stalk").srgb_to_linear()
	var fern: Color = pal.col("fern").srgb_to_linear()
	var clov: Color = pal.col("terrain_clover").lightened(0.08).srgb_to_linear()
	var flowers: Array[Color] = [pal.col("flower_a").srgb_to_linear(), pal.col("flower_b").srgb_to_linear(), pal.col("flower_c").srgb_to_linear()]
	var frosty: Color = pal.col("snow").srgb_to_linear()
	var dry: Color = pal.col("terrain_dry").srgb_to_linear()
	var lush: Color = pal.col("jungle_leaf").srgb_to_linear()
	for pl: Dictionary in w.plants:
		var c: Vector3 = pl["pos"]
		var s: float = float(pl["s"])
		var kind: String = str(pl["kind"])
		var clp: Vector3 = w.field.climate(c.x, c.z)
		leaf = pal.col("scatter_leaf").srgb_to_linear().lerp(frosty, clp.x * 0.45).lerp(dry, clp.y * 0.75).lerp(lush, clp.z * 0.6)
		stalk = pal.col("scatter_stalk").srgb_to_linear().lerp(frosty, clp.x * 0.35).lerp(dry, clp.y * 0.8).lerp(lush, clp.z * 0.5)
		if clp.z > 0.5:
			s *= 1.6
		var rot: float = float(pl["rot"])
		var b := Basis(Vector3.UP, rot)
		match kind:
			"leaf":
				blades.append([Transform3D(b.scaled(Vector3(s * 2.0, s * 0.6, s * 1.8)), c), leaf])
			"stalk":
				blades.append([Transform3D(b.scaled(Vector3(s * 0.8, s * 0.9, s * 0.8)), c), stalk])
			"tuft":
				# three thin blades fanned out
				for k: int in 3:
					var bk := Basis(Vector3.UP, rot + float(k) * 2.1).scaled(Vector3(s * 0.45, s * (0.55 + 0.15 * float(k)), s * 0.45))
					blades.append([Transform3D(bk, c), leaf.lerp(stalk, 0.3 * float(k))])
			"fern":
				for k: int in 5:
					var bk := (Basis(Vector3.UP, rot + float(k) * 1.257) * Basis(Vector3.RIGHT, 0.5)).scaled(Vector3(s * 0.9, s * 0.5, s * 1.4))
					blades.append([Transform3D(bk, c), fern])
			"clover":
				clovers.append([Transform3D(b.scaled(Vector3.ONE * s * 0.9), c), clov])
			"flower":
				blades.append([Transform3D(b.scaled(Vector3(s * 0.35, s * 0.7, s * 0.35)), c), stalk])
				var top: Vector3 = c + b * Vector3(0.0, s * 0.7 * 1.5, s * 0.35 * 0.55)
				blooms.append([Transform3D(b.scaled(Vector3.ONE * s * 0.7), top), flowers[int(pl.get("c", 0)) % 3]])
	_plants = _instanced(blade, blades)
	_instanced(clover, clovers)
	_instanced(bloom, blooms)


func _instanced(mesh: Mesh, rows: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = rows.size()
	for i: int in rows.size():
		var row: Array = rows[i]
		mm.set_instance_transform(i, row[0])
		mm.set_instance_color(i, row[1])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	return mi


## A tall thin blade that curls forward at the top.
static func _blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = [Vector3(-0.08, 0.0, 0.0), Vector3(0.08, 0.0, 0.0), Vector3(0.05, 1.0, 0.25), Vector3(-0.05, 1.0, 0.25), Vector3(0.0, 1.5, 0.55)]
	_tri(st, pts[0], pts[2], pts[1])
	_tri(st, pts[0], pts[3], pts[2])
	_tri(st, pts[3], pts[4], pts[2])
	st.generate_normals()
	return st.commit()


## Three round leaves on short stalks, lying almost flat.
static func _clover_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k: int in 3:
		var a: float = float(k) / 3.0 * TAU
		var c := Vector3(sin(a) * 0.16, 0.12, cos(a) * 0.16)
		var prev: Vector3 = c + Vector3(0.14, 0.0, 0.0)
		for j: int in range(1, 9):
			var t: float = float(j) / 8.0 * TAU
			var p: Vector3 = c + Vector3(cos(t) * 0.14, sin(t) * 0.02, sin(t) * 0.14)
			_tri(st, c, p, prev)
			prev = p
	st.generate_normals()
	return st.commit()


## A small five-petal flower head.
static func _bloom_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Vector3.ZERO
	for k: int in 5:
		var a: float = float(k) / 5.0 * TAU
		var dir := Vector3(sin(a), 0.15, cos(a))
		var side := Vector3(cos(a), 0.0, -sin(a)) * 0.07
		_tri(st, c, c + dir * 0.12 + side, c + dir * 0.2)
		_tri(st, c, c + dir * 0.2, c + dir * 0.12 - side)
	st.generate_normals()
	return st.commit()


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
	_sync_shrines(w, dt)
	_sync_camps(w, t)
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


func _sync_shrines(w: SimWorld, dt: float) -> void:
	for sh: Entities.Shrine in w.shrines:
		var n: Node3D = _shrines.get(sh.id)
		if n == null:
			n = _build_shrine(sh.type_id, sh.pos, true)
			_shrines[sh.id] = n
		n.position = sh.pos
		var em: Node3D = n.get_node("emblem")
		em.rotation.y += dt * 0.9
		em.position.y = 3.25 + sin(_last_t * 1.6 + float(sh.id)) * 0.08
		var label: Label3D = n.get_node("label")
		var t: Types.SprigType = tables.sprig(sh.type_id)
		var inside: int = int(w.hold.stored.get(sh.type_id, 0))
		var text: String = "%s\n%d inside" % [(t.name if t != null else sh.type_id).to_upper(), inside]
		if label.text != text:
			label.text = text


## A shrine, rooted at the Hold or still waiting in the field. Owner verdict 2026-10-16: "more
## clear which one goes which". The body is the type's colour, a ring on the ground marks it,
## and an emblem with a shape of its own turns over the top (flame, block, bolt, drop, thorn
## star, wings, snowflake, acorn), so two shrines never read alike even in poor light.
func _build_shrine(type_id: String, at: Vector3, rooted: bool) -> Node3D:
	var n := Node3D.new()
	n.position = at
	add_child(n)
	var tint: Color = pal.col(tables.sprig(type_id).colour_key)
	var sc: float = 1.0 if rooted else 0.8
	var holder := Node3D.new()
	holder.scale = Vector3.ONE * sc
	n.add_child(holder)
	var disc := _mesh(_cyl(1.75, 0.03), _mat(tint, 0.8, 0.0, tint, 0.6))
	var dm: StandardMaterial3D = disc.material_override
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color.a = 0.35
	disc.position.y = 0.03
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(disc)
	var dome := SphereMesh.new()
	dome.radius = 1.05
	dome.height = 1.9
	dome.radial_segments = 14
	dome.rings = 8
	var body_c: Color = tint.lerp(pal.col("shrine_body"), 0.28)
	var body := _mesh(dome, _mat(body_c, 0.55, 0.05, tint, 0.18))
	body.position.y = 1.55
	holder.add_child(body)
	for i: int in 3:
		var leg := _mesh(_cyl(0.11, 1.2), _mat(pal.col("scatter_stalk").darkened(0.2), 0.9, 0.0))
		var ang: float = float(i) / 3.0 * TAU
		leg.position = Vector3(sin(ang) * 0.7, 0.55, cos(ang) * 0.7)
		leg.rotation = Vector3(cos(ang) * 0.25, 0.0, -sin(ang) * 0.25)
		holder.add_child(leg)
	var band := TorusMesh.new()
	band.inner_radius = 0.98
	band.outer_radius = 1.12
	band.rings = 28
	band.ring_segments = 6
	var ring := _mesh(band, _mat(pal.col("shrine_glow"), 0.4, 0.3, pal.col("shrine_glow"), 0.7))
	ring.position.y = 1.35
	holder.add_child(ring)
	var em := _emblem(type_id, tint)
	em.name = "emblem"
	em.position.y = 3.25 * sc
	n.add_child(em)
	var light := OmniLight3D.new()
	light.light_color = tint
	light.light_energy = 2.4
	light.omni_range = 8.0
	light.position.y = 3.0
	light.shadow_enabled = false
	n.add_child(light)
	var label := Label3D.new()
	label.name = "label"
	var t: Types.SprigType = tables.sprig(type_id)
	label.text = (t.name if t != null else type_id).to_upper()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# the same size on screen at any zoom: readable far off, never a wall of text up close
	label.fixed_size = true
	label.font_size = 40
	label.pixel_size = 0.00072
	label.outline_size = 10
	label.modulate = tint.lightened(0.25)
	label.outline_modulate = Color(0.04, 0.05, 0.06, 0.9)
	label.position.y = 4.35 * sc
	label.no_depth_test = true # a name is never hidden behind a stone
	label.render_priority = 2
	label.line_spacing = -6.0
	n.add_child(label)
	return n


## The type's emblem: a small glowing shape of its own, about 0.9 m across.
func _emblem(type_id: String, tint: Color) -> Node3D:
	var e := Node3D.new()
	var glow := _mat(tint, 0.35, 0.1, tint, 1.8)
	var pale := _mat(tint.lightened(0.45), 0.35, 0.1, tint, 1.2)
	match type_id:
		"ember": # a flame: three stacked teardrops leaning together
			for k: int in 3:
				var f := CylinderMesh.new()
				f.top_radius = 0.0
				f.bottom_radius = 0.3 - 0.07 * float(k)
				f.height = 0.9 - 0.18 * float(k)
				f.radial_segments = 8
				var m := _mesh(f, glow if k != 1 else pale)
				m.position = Vector3(0.12 * float(k - 1), 0.45 - 0.05 * float(k), 0.0)
				m.rotation.z = -0.25 * float(k - 1)
				e.add_child(m)
			var base := _mesh(_ico(0.3), glow)
			base.position.y = 0.12
			e.add_child(base)
		"stone": # a heavy block on its corner
			var b := _mesh(_box(0.55, 0.55, 0.55), _mat(tint.lightened(0.15), 0.8, 0.0, tint, 0.6))
			b.rotation = Vector3(0.62, 0.0, 0.62)
			b.position.y = 0.4
			e.add_child(b)
		"spark": # a bolt: two slanted bars and a point
			for k: int in 2:
				var bar := _mesh(_box(0.16, 0.5, 0.12), glow)
				bar.position = Vector3(0.1 - 0.2 * float(k), 0.62 - 0.4 * float(k), 0.0)
				bar.rotation.z = 0.5
				e.add_child(bar)
			var mid := _mesh(_box(0.45, 0.12, 0.12), glow)
			mid.position.y = 0.42
			mid.rotation.z = 0.2
			e.add_child(mid)
		"tide": # a drop: a ball with a point on top
			var ball := _mesh(_ico(0.3), glow)
			ball.position.y = 0.3
			e.add_child(ball)
			var tip := CylinderMesh.new()
			tip.top_radius = 0.0
			tip.bottom_radius = 0.27
			tip.height = 0.45
			tip.radial_segments = 8
			var tm := _mesh(tip, glow)
			tm.position.y = 0.66
			e.add_child(tm)
		"thorn": # a star of spikes
			for k: int in 6:
				var a: float = float(k) / 6.0 * TAU
				var sp := CylinderMesh.new()
				sp.top_radius = 0.0
				sp.bottom_radius = 0.09
				sp.height = 0.5
				sp.radial_segments = 5
				var m := _mesh(sp, pale)
				m.position = Vector3(sin(a) * 0.22, 0.42 + cos(a) * 0.22, 0.0)
				m.rotation.z = -a
				e.add_child(m)
			var core := _mesh(_ico(0.16), glow)
			core.position.y = 0.42
			e.add_child(core)
		"moth": # a pair of wings
			for sx: float in [-1.0, 1.0]:
				var wing := _mesh(_ico(0.3), pale)
				wing.scale = Vector3(1.0, 0.75, 0.18)
				wing.position = Vector3(0.26 * sx, 0.5, 0.0)
				wing.rotation.z = 0.35 * sx
				e.add_child(wing)
			var body := _mesh(_capsule(0.07, 0.45), glow)
			body.position.y = 0.45
			e.add_child(body)
		"frost": # a snowflake: three crossed bars
			for k: int in 3:
				var bar := _mesh(_box(0.85, 0.09, 0.09), pale)
				bar.position.y = 0.45
				bar.rotation.z = float(k) / 3.0 * PI
				e.add_child(bar)
			var core := _mesh(_ico(0.12), glow)
			core.position.y = 0.45
			e.add_child(core)
		"oak": # an acorn: a nut and its cap
			var nut := _mesh(_ico(0.28), glow)
			nut.scale = Vector3(1.0, 1.25, 1.0)
			nut.position.y = 0.32
			e.add_child(nut)
			var cap := _mesh(_ico(0.31), _mat(tint.darkened(0.35), 0.9, 0.0))
			cap.scale = Vector3(1.0, 0.5, 1.0)
			cap.position.y = 0.6
			e.add_child(cap)
			var stem := _mesh(_cyl(0.035, 0.18), _mat(tint.darkened(0.45), 0.9, 0.0))
			stem.position.y = 0.76
			e.add_child(stem)
		_:
			var orb := _mesh(_ico(0.36), glow)
			orb.position.y = 0.4
			e.add_child(orb)
	return e


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
			n.queue_free()
			n = _build_shrine(o.shrine_type, Vector3.ZERO, false)
			var lb: Label3D = n.get_node("label")
			lb.text = (tables.sprig(o.shrine_type).name + " shrine").to_upper()
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
		var under: bool = e.state == Entities.Enemy.State.BURROW
		body.visible = not under
		var mound: Node3D = n.get_node_or_null("mound")
		if mound != null:
			mound.visible = under
			if under:
				var shake: float = e.wind
				mound.scale = Vector3.ONE * (1.0 + shake * 0.35)
				mound.rotation.z = sin(t * 30.0) * 0.12 * shake
				mound.position.y = -0.05 + absf(sin(t * 9.0 + float(e.id))) * 0.04
		body.rotation = Vector3.ZERO
		body.position = Vector3.ZERO
		body.scale = Vector3.ONE
		var swell: Node3D = body.get_node_or_null("swell")
		if swell != null:
			swell.scale = Vector3.ONE
		match e.state:
			Entities.Enemy.State.TELEGRAPH:
				match e.attack_now:
					"breath", "gust":
						# it swells, drawing breath
						var s: float = 1.0 + e.wind * 0.22
						if swell != null:
							swell.scale = Vector3(s, s, s)
						else:
							body.scale = Vector3(s, s, s)
						body.rotation.x = -e.wind * 0.12
					"leap":
						# a deep crouch before the jump
						body.scale = Vector3(1.0 + e.wind * 0.15, 1.0 - e.wind * 0.3, 1.0 + e.wind * 0.1)
					"stomp":
						# it rears high before it comes down
						body.rotation.x = -e.wind * 0.55
						body.position.y = e.wind * et.height * 0.45
						body.position.z = -e.wind * 0.3
					"charge":
						# head down, pawing the ground
						body.rotation.x = e.wind * 0.22
						body.position.z = -e.wind * 0.15
						body.rotation.z = sin(t * 26.0) * 0.06 * e.wind
					_:
						# the bite: it rears and pales, then snaps forward
						body.rotation.x = -e.wind * 0.45
						body.position.y = e.wind * 0.25
						body.scale = Vector3(1.0 + e.wind * 0.08, 1.0 + e.wind * 0.12, 1.0 - e.wind * 0.05)
			Entities.Enemy.State.LEAP:
				body.scale = Vector3(0.9, 1.2, 0.95)
				body.rotation.x = -0.25
			Entities.Enemy.State.RUSH:
				body.rotation.x = 0.18
				body.position.y = absf(sin(t * 22.0)) * 0.1
			Entities.Enemy.State.RECOVER:
				if e.dazed:
					# dizzy: a slow wobble, wide open
					body.rotation.z = sin(t * 7.0) * 0.16
					body.rotation.x = cos(t * 5.0) * 0.08
				elif e.attack_now == "bite":
					body.rotation.x = 0.35 * e.wind * 3.0
			Entities.Enemy.State.SHAKE:
				body.rotation.z = sin(t * 40.0) * 0.25
				body.position.y = absf(sin(t * 30.0)) * 0.12
			Entities.Enemy.State.SLEEP:
				body.position.y = -0.08 + sin(t * 1.3 + float(e.id)) * 0.03
				body.scale = Vector3(1.0, 0.92 + sin(t * 1.3 + float(e.id)) * 0.03, 1.0)
			Entities.Enemy.State.FROZEN, Entities.Enemy.State.BURROW:
				pass
			_:
				var mv: float = Vector2(e.pos.x - e.prev.x, e.pos.z - e.prev.z).length() / SimWorld.FIXED_DT
				var gait: float = clampf(mv / maxf(0.5, et.speed), 0.0, 1.0)
				if et.has_attack("leap"):
					# toads hop
					body.position.y = absf(sin(t * 7.0 + float(e.id))) * 0.35 * gait
				else:
					body.rotation.z = sin(t * 12.0 + float(e.id)) * 0.08 * gait
					body.position.y = absf(sin(t * 12.0 + float(e.id))) * 0.06 * gait
		# the glowing part (grub back plate, hog snout, shellback brow) burns brighter with the wind-up
		var plate: MeshInstance3D = n.get_node_or_null("body/plate")
		if plate != null:
			var m: StandardMaterial3D = plate.material_override
			m.emission_energy_multiplier = e.wind * 2.5 + (0.3 if et.has_attack("breath") else 0.0)
		# breath and gust: a cone that hangs in the air for a moment after the strike
		var cone: MeshInstance3D = n.get_node_or_null("cone")
		if cone != null:
			var life: float = 0.65
			var on: bool = e.strike_t < life and e.state != Entities.Enemy.State.BURROW and (e.attack_now == "breath" or e.attack_now == "gust")
			cone.visible = on
			if on:
				var cm: StandardMaterial3D = cone.material_override
				cm.albedo_color.a = 0.45 * (1.0 - e.strike_t / life)
				var g: float = 0.6 + 0.4 * (e.strike_t / life)
				cone.scale = Vector3(g, 1.0, g)
		# where the strike will land: the toad's shadow ring, the mole's rumble, the charge lane
		var mark: MeshInstance3D = n.get_node_or_null("mark")
		if mark != null:
			var show_mark: bool = false
			if e.attack_now == "leap" and (e.state == Entities.Enemy.State.TELEGRAPH or e.state == Entities.Enemy.State.LEAP):
				show_mark = true
				mark.global_position = e.aim + Vector3(0.0, 0.06, 0.0)
				var k: float = 0.75 + 0.25 * sin(t * 14.0)
				mark.scale = Vector3(et.leap_radius * k, 1.0, et.leap_radius * k)
			elif e.attack_now == "stomp" and e.state == Entities.Enemy.State.TELEGRAPH:
				show_mark = true
				mark.global_position = e.pos + Vector3(0.0, 0.06, 0.0)
				var k3: float = e.reach_now * (0.8 + 0.2 * sin(t * 16.0))
				mark.scale = Vector3(k3, 1.0, k3)
			elif et.attack == "burrow" and under and e.emerge >= 0.0:
				show_mark = true
				mark.global_position = e.pos + Vector3(0.0, 0.06, 0.0)
				var k2: float = (et.radius + 0.5) * (0.6 + 0.4 * e.wind)
				mark.scale = Vector3(k2, 1.0, k2)
			mark.visible = show_mark
		var lane: MeshInstance3D = n.get_node_or_null("lane")
		if lane != null:
			lane.visible = e.state == Entities.Enemy.State.TELEGRAPH and e.attack_now == "charge"
			if lane.visible:
				var lm: StandardMaterial3D = lane.material_override
				lm.albedo_color.a = 0.15 + 0.3 * e.wind
		var bar: MeshInstance3D = n.get_node("hp")
		var frac: float = e.hp / maxf(1.0, e.max_hp)
		bar.scale.x = maxf(0.02, frac)
		bar.visible = frac < 0.999 and e.state != Entities.Enemy.State.SLEEP and not under
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
	match e.type_id:
		"field_beetle":
			_beetle(body, et, tint)
		"night_stalker":
			_stalker(body, et, tint)
		"cinder_hog", "mire_hog":
			_hog(body, et, tint, pal.col("hazard_poison") if et.breath_hazard == "poison" else pal.col("vent_fire"))
		"pounce_toad":
			_toad(body, et, tint)
		"shellback":
			_shellback(body, et, tint)
		"gale_puff":
			_puff_body(body, et, tint)
		"hollow_mole":
			_mole(n, body, et, tint)
		"thornback_behemoth":
			_grub(body, et, tint)
			_spikes(body, et, pal.col("pellet_body").darkened(0.1), 9)
		"hollow_queen":
			_mole(n, body, et, tint)
			_spikes(body, et, pal.col("enemy_mole_nose"), 5)
		"cinder_matriarch":
			_hog(body, et, tint, pal.col("vent_fire"))
			_spikes(body, et, pal.col("vent_fire").darkened(0.2), 7)
		_:
			_grub(body, et, tint)
	if et.has_attack("breath") or et.has_attack("gust"):
		var reach: float = maxf(et.range_of("breath"), et.range_of("gust")) + 0.4
		var cm := CylinderMesh.new()
		cm.top_radius = reach * tan(deg_to_rad(et.cone_deg * 0.5))
		cm.bottom_radius = 0.15
		cm.height = reach
		cm.radial_segments = 14
		cm.cap_top = false
		cm.cap_bottom = false
		var c: Color = Color(0.95, 0.97, 1.0)
		if et.has_attack("breath"):
			c = pal.col("hazard_poison") if et.breath_hazard == "poison" else pal.col("vent_fire")
		var mat := _mat(c, 1.0, 0.0, c, 1.4)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var cone := _mesh(cm, mat)
		cone.name = "cone"
		cone.rotation.x = PI * 0.5
		cone.position = Vector3(0.0, et.height * 0.5, et.radius * 0.6 + reach * 0.5)
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cone.visible = false
		n.add_child(cone)
	if et.has_attack("leap") or et.has_attack("stomp") or et.attack == "burrow":
		var ring := TorusMesh.new()
		ring.inner_radius = 0.86
		ring.outer_radius = 1.0
		ring.rings = 32
		ring.ring_segments = 4
		var rc: Color = pal.col("hud_warn")
		var rmat := _mat(rc, 1.0, 0.0, rc, 2.0)
		rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var mark := _mesh(ring, rmat)
		mark.name = "mark"
		mark.top_level = true
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mark.visible = false
		n.add_child(mark)
	if et.has_attack("charge"):
		var lc: Color = pal.col("hud_warn")
		var lmat := _mat(lc, 1.0, 0.0, lc, 1.5)
		lmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var lane := _mesh(_box(et.radius * 2.0, 0.03, et.charge_distance), lmat)
		lane.name = "lane"
		lane.position = Vector3(0.0, 0.06, et.charge_distance * 0.5)
		lane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lane.visible = false
		n.add_child(lane)
	var bar := _mesh(_box(1.6 if not et.boss else et.radius * 1.6, 0.08, 0.08), _mat(pal.col("hud_warn"), 0.5, 0.0, pal.col("hud_warn"), 1.5))
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


func _eyes(body: Node3D, at: Vector3, spread: float, r: float) -> void:
	for sx: float in [-1.0, 1.0]:
		var white := _mesh(_ico(r), _mat(Color(0.95, 0.94, 0.88), 0.4, 0.0))
		white.position = at + Vector3(spread * sx, 0.0, 0.0)
		body.add_child(white)
		var pupil := _mesh(_ico(r * 0.55), _mat(Color(0.06, 0.05, 0.05), 0.2, 0.0))
		pupil.position = at + Vector3(spread * sx, 0.0, r * 0.62)
		body.add_child(pupil)


func _legs(body: Node3D, et: Types.EnemyType, c: Color, count: int, len: float, splay: float, rad: float = 0.05) -> void:
	for i: int in count:
		var leg := _mesh(_cyl(rad, len), _mat(c, 0.9, 0.0))
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var row: int = i / 2
		var rows: int = maxi(1, count / 2)
		var z: float = -et.radius * 0.6 + et.radius * 1.2 * (float(row) / float(maxi(1, rows - 1)) if rows > 1 else 0.5)
		leg.position = Vector3(side * et.radius * 0.85, len * 0.4, z)
		leg.rotation.z = side * splay
		body.add_child(leg)


func _beetle(body: Node3D, et: Types.EnemyType, tint: Color) -> void:
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
	_legs(body, et, tint, 6, 0.4, 0.7, 0.025)


func _stalker(body: Node3D, et: Types.EnemyType, tint: Color) -> void:
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


func _grub(body: Node3D, et: Types.EnemyType, tint: Color) -> void:
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
	_legs(body, et, tint.darkened(0.3), 6, 0.5, 0.6)


## Campsites: a tent, a fire ring, and a beacon post with a lantern. The lantern and the fire are
## lit at whichever camp holds the Hold now; the Hold's rings stand round that camp.
var _camp_nodes: Dictionary = {} # camp id -> Node3D (its beacon root)


func _build_camps(w: SimWorld) -> void:
	var tent_m := _mat(pal.col("tent"), 0.9, 0.0)
	var pole_m := _mat(pal.col("bark"), 0.9, 0.0)
	var stone_m := _mat(pal.col("scatter_stone"), 1.0, 0.0)
	var ash_m := _mat(pal.col("terrain_loam").darkened(0.5), 1.0, 0.0)
	for cp: Dictionary in w.camps:
		var id: String = cp["id"]
		var c: Vector3 = cp["pos"]
		var root := Node3D.new()
		root.position = CampSystem.beacon(w, cp)
		add_child(root)
		var post := _mesh(_cyl(0.09, 2.8), pole_m)
		post.position.y = 1.4
		root.add_child(post)
		var arm := _mesh(_cyl(0.05, 0.7), pole_m)
		arm.rotation.z = PI * 0.5
		arm.position = Vector3(0.3, 2.75, 0.0)
		root.add_child(arm)
		var lamp := _mesh(_ico(0.22), _mat(pal.col("camp_fire"), 0.4, 0.0, pal.col("camp_fire"), 0.0))
		lamp.name = "lamp"
		lamp.position = Vector3(0.62, 2.45, 0.0)
		root.add_child(lamp)
		var light := OmniLight3D.new()
		light.name = "light"
		light.light_color = pal.col("camp_fire")
		light.omni_range = 10.0
		light.light_energy = 0.0
		light.shadow_enabled = false
		light.position = lamp.position
		root.add_child(light)
		var label := Label3D.new()
		label.name = "label"
		label.text = str(cp["name"]).to_upper()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.fixed_size = true
		label.font_size = 36
		label.pixel_size = 0.0007
		label.outline_size = 10
		label.modulate = pal.col("camp_fire").lightened(0.3)
		label.outline_modulate = Color(0.04, 0.05, 0.06, 0.9)
		label.position.y = 3.6
		root.add_child(label)
		_camp_nodes[id] = root
		if id == "home":
			continue # the Hold's own cairn stands at home
		# the tent: a ridge tent, two slopes and a ridge pole
		var tent := Node3D.new()
		tent.position = w.ground(c + Vector3(4.0, 0.0, 2.0))
		tent.rotation.y = 0.7
		add_child(tent)
		# a three-sided prism lying along z, one face flat on the ground, the ridge on top
		var prism := CylinderMesh.new()
		prism.top_radius = 1.3
		prism.bottom_radius = 1.3
		prism.height = 3.2
		prism.radial_segments = 3
		prism.rings = 1
		var body := _mesh(prism, tent_m)
		body.rotation.x = -PI * 0.5
		body.position.y = 0.65
		tent.add_child(body)
		var door := _mesh(_box(0.9, 1.2, 0.05), _mat(pal.col("tent").darkened(0.45), 1.0, 0.0))
		door.position = Vector3(0.0, 0.6, 1.62)
		tent.add_child(door)
		var ridge := _mesh(_cyl(0.05, 3.5), pole_m)
		ridge.rotation.x = PI * 0.5
		ridge.position.y = 1.97
		tent.add_child(ridge)
		# the fire ring
		var fire := Node3D.new()
		fire.position = w.ground(c + Vector3(-2.5, 0.0, 1.5))
		add_child(fire)
		for k: int in 7:
			var a: float = float(k) / 7.0 * TAU
			var st := _mesh(_ico(0.22), stone_m)
			st.position = Vector3(sin(a) * 0.6, 0.1, cos(a) * 0.6)
			fire.add_child(st)
		var ash := _mesh(_cyl(0.5, 0.05), ash_m)
		fire.add_child(ash)
		var flame := _mesh(_ico(0.32), _mat(pal.col("vent_fire"), 0.4, 0.0, pal.col("vent_fire"), 3.0))
		flame.name = "flame"
		flame.position.y = 0.3
		flame.scale = Vector3(1.0, 1.6, 1.0)
		root.set_meta("flame", flame)
		fire.add_child(flame)


func _sync_camps(w: SimWorld, t: float) -> void:
	var hp: Vector3 = w.ground(w.hold.pos)
	_hold_ring.position = hp + Vector3(0.0, 0.08, 0.0)
	_safe_ring.position = hp + Vector3(0.0, 0.05, 0.0)
	for id: Variant in _camp_nodes.keys():
		var root: Node3D = _camp_nodes[id]
		var here: bool = str(id) == w.camp_id
		var light: OmniLight3D = root.get_node("light")
		light.light_energy = (2.6 + 0.4 * sin(t * 9.0)) if here else 0.0
		var lamp: MeshInstance3D = root.get_node("lamp")
		var lm: StandardMaterial3D = lamp.material_override
		lm.emission_enabled = true
		lm.emission = pal.col("camp_fire")
		lm.emission_energy_multiplier = 3.0 if here else 0.05
		if root.has_meta("flame"):
			var flame: MeshInstance3D = root.get_meta("flame")
			flame.visible = here
			flame.scale = Vector3(1.0, 1.4 + 0.3 * sin(t * 11.0), 1.0)


## A boss's crown: a ridge of great horns along its back, glowing faintly.
func _spikes(body: Node3D, et: Types.EnemyType, c: Color, n: int) -> void:
	var m := _mat(c, 0.5, 0.1, c, 0.35)
	for k: int in n:
		var u: float = float(k) / float(maxi(1, n - 1))
		var horn := CylinderMesh.new()
		horn.top_radius = 0.0
		horn.bottom_radius = et.radius * (0.16 + 0.08 * sin(u * PI))
		horn.height = et.height * (0.4 + 0.35 * sin(u * PI))
		horn.radial_segments = 7
		var hm := _mesh(horn, m)
		hm.position = Vector3(0.0, et.height * (0.95 + 0.1 * sin(u * PI)), et.radius * (0.9 - 1.8 * u))
		hm.rotation.x = -0.35
		body.add_child(hm)
	for sx: float in [-1.0, 1.0]:
		var eye_c: Color = pal.col("enemy_night_eye")
		var glow := _mesh(_ico(et.radius * 0.07), _mat(eye_c, 0.3, 0.0, eye_c, 3.0))
		glow.position = Vector3(et.radius * 0.22 * sx, et.height * 0.62, et.radius * 1.32)
		body.add_child(glow)


## A hog with a bellows chest: it swells, then breathes its hazard out of a glowing snout.
func _hog(body: Node3D, et: Types.EnemyType, tint: Color, glow: Color) -> void:
	var swell := Node3D.new()
	swell.name = "swell"
	swell.position.y = et.height * 0.55
	body.add_child(swell)
	var trunk := _mesh(_ico(et.radius), _mat(tint, 0.85, 0.0))
	trunk.scale = Vector3(1.0, 0.82, 1.3)
	swell.add_child(trunk)
	var chest := _mesh(_ico(et.radius * 0.7), _mat(glow.darkened(0.25), 0.7, 0.0, glow, 0.4))
	chest.scale = Vector3(1.0, 0.75, 0.6)
	chest.position = Vector3(0.0, -et.height * 0.12, et.radius * 0.55)
	swell.add_child(chest)
	for k: int in 5:
		var bristle := CylinderMesh.new()
		bristle.top_radius = 0.0
		bristle.bottom_radius = 0.09
		bristle.height = 0.32
		bristle.radial_segments = 5
		var b := _mesh(bristle, _mat(tint.darkened(0.45), 0.9, 0.0))
		b.position = Vector3(0.0, et.radius * 0.78, -et.radius * 0.7 + et.radius * 0.35 * float(k))
		b.rotation.x = -0.35
		swell.add_child(b)
	var head := _mesh(_ico(et.radius * 0.58), _mat(tint.lightened(0.08), 0.85, 0.0))
	head.position = Vector3(0.0, et.height * 0.62, et.radius * 1.2)
	body.add_child(head)
	var snout := _mesh(_cyl(et.radius * 0.24, et.radius * 0.36), _mat(glow, 0.5, 0.0, glow, 0.3))
	snout.name = "plate"
	snout.rotation.x = PI * 0.5
	snout.position = Vector3(0.0, et.height * 0.55, et.radius * 1.72)
	body.add_child(snout)
	for sx: float in [-1.0, 1.0]:
		var ear := CylinderMesh.new()
		ear.top_radius = 0.0
		ear.bottom_radius = 0.13
		ear.height = 0.3
		ear.radial_segments = 5
		var em := _mesh(ear, _mat(tint.darkened(0.2), 0.9, 0.0))
		em.position = Vector3(0.24 * sx, et.height * 0.92, et.radius * 1.05)
		em.rotation.z = -0.4 * sx
		body.add_child(em)
	_eyes(body, Vector3(0.0, et.height * 0.76, et.radius * 1.55), 0.17, 0.075)
	_legs(body, et, tint.darkened(0.35), 4, 0.55, 0.15, 0.09)


## A squat toad with big eyes on top and folded back legs.
func _toad(body: Node3D, et: Types.EnemyType, tint: Color) -> void:
	var trunk := _mesh(_ico(et.radius), _mat(tint, 0.6, 0.0))
	trunk.scale = Vector3(1.25, 0.62, 1.05)
	trunk.position.y = et.height * 0.45
	body.add_child(trunk)
	var belly := _mesh(_ico(et.radius * 0.9), _mat(pal.col("enemy_toad_belly"), 0.7, 0.0))
	belly.scale = Vector3(1.15, 0.45, 1.0)
	belly.position = Vector3(0.0, et.height * 0.3, et.radius * 0.12)
	body.add_child(belly)
	for k: int in 6:
		var wart := _mesh(_ico(0.07), _mat(tint.darkened(0.3), 0.8, 0.0))
		wart.position = Vector3((float(k % 3) - 1.0) * 0.35, et.height * 0.72, -0.2 + 0.3 * float(k / 3))
		body.add_child(wart)
	for sx: float in [-1.0, 1.0]:
		var bump := _mesh(_ico(0.2), _mat(tint, 0.6, 0.0))
		bump.position = Vector3(0.36 * sx, et.height * 0.82, et.radius * 0.45)
		body.add_child(bump)
		var thigh := _mesh(_ico(et.radius * 0.45), _mat(tint.darkened(0.12), 0.6, 0.0))
		thigh.scale = Vector3(0.7, 0.6, 1.3)
		thigh.position = Vector3(et.radius * 1.05 * sx, et.height * 0.25, -et.radius * 0.35)
		body.add_child(thigh)
		var hand := _mesh(_cyl(0.06, 0.35), _mat(tint.darkened(0.1), 0.6, 0.0))
		hand.position = Vector3(et.radius * 0.6 * sx, 0.15, et.radius * 0.75)
		hand.rotation.z = 0.3 * sx
		body.add_child(hand)
	_eyes(body, Vector3(0.0, et.height * 0.95, et.radius * 0.55), 0.36, 0.13)
	var mouth := _mesh(_box(et.radius * 1.3, 0.03, 0.05), _mat(Color(0.12, 0.1, 0.08), 0.8, 0.0))
	mouth.position = Vector3(0.0, et.height * 0.45, et.radius * 1.02)
	body.add_child(mouth)


## Armoured in front (the brow plate glows as it winds up), soft and pale behind: hit it there.
func _shellback(body: Node3D, et: Types.EnemyType, tint: Color) -> void:
	var shell := _mesh(_ico(et.radius * 1.05), _mat(tint, 0.45, 0.25))
	shell.scale = Vector3(1.0, 0.72, 1.2)
	shell.position.y = et.height * 0.62
	body.add_child(shell)
	for k: int in 4:
		var ridge := _mesh(_box(et.radius * 1.2 - 0.12 * float(k), 0.1, 0.18), _mat(tint.lightened(0.25), 0.4, 0.3))
		ridge.position = Vector3(0.0, et.height * 1.03 - 0.06 * float(absi(k - 1)), -et.radius * 0.5 + et.radius * 0.38 * float(k))
		body.add_child(ridge)
	var brow := _mesh(_box(et.radius * 1.5, et.height * 0.6, 0.22), _mat(tint.lightened(0.35), 0.35, 0.4, pal.col("hud_warn"), 0.0))
	brow.name = "plate"
	brow.position = Vector3(0.0, et.height * 0.5, et.radius * 1.12)
	brow.rotation.x = -0.25
	body.add_child(brow)
	var horn := CylinderMesh.new()
	horn.top_radius = 0.0
	horn.bottom_radius = 0.12
	horn.height = 0.5
	horn.radial_segments = 6
	var hm := _mesh(horn, _mat(pal.col("pellet_body"), 0.4, 0.2))
	hm.rotation.x = PI * 0.5 - 0.3
	hm.position = Vector3(0.0, et.height * 0.6, et.radius * 1.4)
	body.add_child(hm)
	var soft := _mesh(_ico(et.radius * 0.55), _mat(pal.col("enemy_shellback_soft"), 0.8, 0.0, pal.col("enemy_shellback_soft"), 0.25))
	soft.scale = Vector3(1.1, 0.8, 0.8)
	soft.position = Vector3(0.0, et.height * 0.45, -et.radius * 1.05)
	body.add_child(soft)
	_eyes(body, Vector3(0.0, et.height * 0.38, et.radius * 1.22), 0.22, 0.06)
	_legs(body, et, tint.darkened(0.4), 6, 0.55, 0.55, 0.07)


## A round puff with a ring mouth and a leafy tuft. It inflates, then blows.
func _puff_body(body: Node3D, et: Types.EnemyType, tint: Color) -> void:
	var swell := Node3D.new()
	swell.name = "swell"
	swell.position.y = et.height * 0.55
	body.add_child(swell)
	var ball := _mesh(_ico(et.radius), _mat(tint, 0.8, 0.0))
	ball.scale = Vector3(1.0, 0.95, 1.0)
	swell.add_child(ball)
	var lip := TorusMesh.new()
	lip.inner_radius = et.radius * 0.22
	lip.outer_radius = et.radius * 0.36
	lip.rings = 16
	lip.ring_segments = 6
	var lm := _mesh(lip, _mat(tint.darkened(0.3), 0.7, 0.0))
	lm.rotation.x = PI * 0.5
	lm.position = Vector3(0.0, -et.radius * 0.1, et.radius * 0.92)
	swell.add_child(lm)
	var hole := _mesh(_cyl(et.radius * 0.22, 0.05), _mat(Color(0.12, 0.1, 0.1), 0.9, 0.0))
	hole.rotation.x = PI * 0.5
	hole.position = Vector3(0.0, -et.radius * 0.1, et.radius * 0.9)
	swell.add_child(hole)
	_eyes(swell, Vector3(0.0, et.radius * 0.35, et.radius * 0.8), 0.2, 0.08)
	for k: int in 3:
		var a: float = float(k) / 3.0 * TAU
		var leaf := _mesh(_ico(0.16), _mat(pal.col("scatter_leaf"), 0.8, 0.0))
		leaf.scale = Vector3(0.5, 1.4, 0.25)
		leaf.position = Vector3(sin(a) * 0.12, et.radius * 1.05, cos(a) * 0.12)
		leaf.rotation = Vector3(cos(a) * 0.5, a, -sin(a) * 0.5)
		swell.add_child(leaf)
	for sx: float in [-1.0, 1.0]:
		var foot := _mesh(_ico(0.14), _mat(tint.darkened(0.25), 0.8, 0.0))
		foot.scale = Vector3(1.0, 0.6, 1.3)
		foot.position = Vector3(0.28 * sx, 0.07, 0.1)
		body.add_child(foot)


## A mole: dark fur, a pink star nose, broad digging paws. Underground it is a dirt mound.
func _mole(n: Node3D, body: Node3D, et: Types.EnemyType, tint: Color) -> void:
	var fur := _mesh(_ico(et.radius), _mat(tint, 0.95, 0.0))
	fur.scale = Vector3(1.0, 0.85, 1.35)
	fur.position.y = et.height * 0.5
	body.add_child(fur)
	var nose_c: Color = pal.col("enemy_mole_nose")
	var nose := _mesh(_ico(et.radius * 0.22), _mat(nose_c, 0.6, 0.0))
	nose.position = Vector3(0.0, et.height * 0.45, et.radius * 1.35)
	body.add_child(nose)
	for k: int in 6:
		var a: float = float(k) / 6.0 * TAU
		var feeler := _mesh(_cyl(0.025, 0.12), _mat(nose_c, 0.6, 0.0))
		feeler.rotation = Vector3(PI * 0.5, 0.0, a)
		feeler.position = Vector3(sin(a) * 0.1, et.height * 0.45 + cos(a) * 0.1, et.radius * 1.45)
		body.add_child(feeler)
	for sx: float in [-1.0, 1.0]:
		var paw := _mesh(_box(0.3, 0.08, 0.26), _mat(nose_c.darkened(0.1), 0.7, 0.0))
		paw.position = Vector3(et.radius * 0.85 * sx, 0.12, et.radius * 0.75)
		paw.rotation = Vector3(0.0, 0.3 * sx, 0.5 * sx)
		body.add_child(paw)
		var eye := _mesh(_ico(0.035), _mat(Color(0.05, 0.05, 0.05), 0.2, 0.0))
		eye.position = Vector3(0.13 * sx, et.height * 0.66, et.radius * 1.12)
		body.add_child(eye)
	var mound := Node3D.new()
	mound.name = "mound"
	mound.visible = false
	n.add_child(mound)
	var dirt := _mesh(_ico(et.radius * 1.1), _mat(pal.col("terrain_loam"), 1.0, 0.0))
	dirt.scale = Vector3(1.2, 0.45, 1.5)
	mound.add_child(dirt)
	for k: int in 5:
		var a2: float = float(k) / 5.0 * TAU
		var clod := _mesh(_ico(0.12), _mat(pal.col("terrain_loam").darkened(0.2), 1.0, 0.0))
		clod.position = Vector3(sin(a2) * et.radius * 1.2, 0.05, cos(a2) * et.radius * 1.5)
		mound.add_child(clod)


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
