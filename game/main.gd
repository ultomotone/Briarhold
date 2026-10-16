## The driver. Owns the one SimWorld, turns Input into Commands, steps the sim at the physics
## rate, and lets the views read it. The only place Input is read; the only place the sim is
## stepped; the only place the wall clock is consulted.
class_name Main
extends Node3D

enum Mode { TITLE, PLAY, PAUSE }

var tables: ContentTables
var pal: PaletteData
var sim: SimWorld
var mode: int = Mode.TITLE
var slot: String = ""
var cmd: Commands = Commands.new()
var cursor: Vector3 = Vector3.INF

var sky: SkyEnv
var terrain: TerrainView
var rig: CameraRig
var knight_view: KnightView
var sprig_view: SprigView
var world_view: WorldView
var fx: FxView
var nav: NavPaths
var hud: Hud
var title: Title
var pause: Pause
var settings: SettingsStore
var world_root: Node3D
var _elapsed: float = 0.0
var _shot_mode: bool = false
var _shot_whistle: bool = false
var _orbiting: bool = false # middle mouse button held: drag turns and tilts the camera


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	tables = Content.tables
	pal = Palette.data
	settings = SettingsStore.new()
	settings.load_from_disk()
	settings.apply_window()
	sky = SkyEnv.new()
	sky.build(pal)
	add_child(sky)
	rig = CameraRig.new()
	add_child(rig)
	world_root = Node3D.new()
	add_child(world_root)
	hud = Hud.new()
	hud.build(pal, tables)
	add_child(hud)
	pause = Pause.new()
	pause.build(pal, self)
	add_child(pause)
	title = Title.new()
	title.build(pal, self)
	add_child(title)
	hud.visible = false
	pause.visible = false
	if not _shot_mode:
		title.open()


# ---- world lifecycle --------------------------------------------------------------------------

func new_game() -> void:
	var seed: int = int(Time.get_unix_time_from_system()) & 0x7FFFFFFF
	var w := SimWorld.new(tables, seed)
	Worldgen.populate(w)
	slot = _fresh_slot()
	_mount(w)


func continue_game() -> void:
	var slots: Array[Dictionary] = SaveStore.list_slots()
	if slots.is_empty():
		new_game()
		return
	var best: Dictionary = slots[0]
	for s: Dictionary in slots:
		if int(s["saved_at"]) > int(best["saved_at"]):
			best = s
	load_slot(str(best["slot"]))


func load_slot(name: String) -> void:
	var doc: Dictionary = SaveStore.read(name)
	if doc.is_empty():
		new_game()
		return
	var w: SimWorld = Serialize.from_doc(tables, doc)
	slot = name
	var elapsed: float = float(int(Time.get_unix_time_from_system()) - int(Migrate.run(doc)["saved_at"]))
	if elapsed > 30.0:
		HoldSystem.apply_offline(w, elapsed)
	_mount(w)


func save_game(reason: String = "") -> void:
	if sim == null or slot.is_empty():
		return
	var doc: Dictionary = Serialize.to_doc(sim, int(Time.get_unix_time_from_system()))
	var err: Error = SaveStore.write(slot, doc)
	if err != OK:
		push_error("save failed: %d" % err)
	elif not reason.is_empty():
		fx._note("Saved (%s)" % reason)


func quit_to_title() -> void:
	save_game("leaving")
	_unmount()
	mode = Mode.TITLE
	hud.visible = false
	pause.visible = false
	title.open()


func _fresh_slot() -> String:
	var used: Dictionary = {}
	for s: Dictionary in SaveStore.list_slots():
		used[str(s["slot"])] = true
	for i: int in range(1, 100):
		var n: String = "hold-%02d" % i
		if not used.has(n):
			return n
	return "hold-99"


func _mount(w: SimWorld) -> void:
	_unmount()
	sim = w
	terrain = TerrainView.new()
	terrain.build(sim.field, pal)
	world_root.add_child(terrain)
	nav = NavPaths.new(get_world_3d().navigation_map)
	sim.paths = nav
	world_view = WorldView.new()
	world_view.build(pal, tables, sim)
	world_root.add_child(world_view)
	sprig_view = SprigView.new()
	sprig_view.build(pal, tables)
	world_root.add_child(sprig_view)
	knight_view = KnightView.new()
	knight_view.build(pal)
	world_root.add_child(knight_view)
	fx = FxView.new()
	fx.build(pal)
	fx.reduced_motion = settings.reduced_motion
	world_root.add_child(fx)
	rig.reduced_motion = settings.reduced_motion
	rig.focus = sim.knight.pos
	rig.follow(sim.knight.pos, 1.0)
	sim.nav_dirty = true
	mode = Mode.PLAY
	title.visible = false
	hud.visible = true
	pause.visible = false
	hud.reset()
	fx._note("Day %d. The Hold is yours." % sim.clock.day)


func _unmount() -> void:
	if nav != null:
		nav.dispose()
	for c: Node in world_root.get_children():
		c.queue_free()
	sim = null
	terrain = null
	world_view = null
	sprig_view = null
	knight_view = null
	fx = null
	nav = null


# ---- input -> commands ----------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.TITLE:
		return
	if event.is_action_pressed("pause"):
		if mode == Mode.PLAY:
			mode = Mode.PAUSE
			pause.open()
		else:
			mode = Mode.PLAY
			pause.close()
		get_viewport().set_input_as_handled()
		return
	if mode != Mode.PLAY:
		_orbiting = false
		return
	if event.is_action_pressed("strike"):
		cmd.strike = true
	if event.is_action_pressed("walk_here") and cursor != Vector3.INF:
		cmd.walk_target = cursor
	if event.is_action_pressed("throw"):
		cmd.throw_pressed = true
	if event.is_action_pressed("dismiss"):
		cmd.dismiss_pressed = true
	if event.is_action_pressed("charge"):
		cmd.charge_pressed = true
	if event.is_action_pressed("select_prev"):
		cmd.select_delta -= 1
	if event.is_action_pressed("select_next"):
		cmd.select_delta += 1
	if event.is_action_pressed("cam_left"):
		rig.turn(1)
	if event.is_action_pressed("cam_right"):
		rig.turn(-1)
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			rig.zoom(-1.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			rig.zoom(1.0)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_orbiting = mb.pressed
	elif event is InputEventMouseMotion and _orbiting:
		# the pointer stays visible and free; only the drag distance is read
		var mm: InputEventMouseMotion = event
		rig.orbit(mm.relative)


func _physics_process(delta: float) -> void:
	if mode != Mode.PLAY or sim == null:
		return
	# held inputs, read fresh each tick; pulses were set by _unhandled_input since the last tick
	var f: float = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var r: float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var dir: Vector3 = rig.forward() * f + rig.right() * r
	cmd.move_dir = dir.normalized() if dir.length_squared() > 0.001 else Vector3.ZERO
	cmd.whistle_held = Input.is_action_pressed("whistle") or _shot_whistle
	cmd.throw_held = Input.is_action_pressed("throw")
	cmd.swarm_held = Input.is_action_pressed("swarm")
	cmd.pluck_held = Input.is_action_pressed("pluck")
	cmd.store_held = Input.is_action_pressed("store")
	cmd.cursor = cursor
	if sim.nav_dirty and nav != null:
		nav.bake(sim, terrain.arrays, true)
		sim.nav_dirty = false
	sim.step(cmd, delta)
	cmd.clear_pulses()
	for ev: Dictionary in sim.events.drain():
		fx.handle(ev)
		hud.handle(ev)
		if ev["kind"] == "dawn" or ev["kind"] == "night":
			save_game("autosave")


func _process(delta: float) -> void:
	_elapsed += delta
	if sim == null:
		return
	var alpha: float = Engine.get_physics_interpolation_fraction() if mode == Mode.PLAY else 1.0
	var k: Entities.Knight = sim.knight
	var kp: Vector3 = k.prev.lerp(k.pos, alpha)
	if mode == Mode.PLAY:
		rig.follow(kp, delta)
		_update_cursor()
	sky.apply(sim.clock.time, sim.clock.day_seconds, sim.clock.night_seconds)
	var swing: float = -1.0
	if k.swing_t >= 0.0:
		swing = k.swing_t / maxf(0.01, tables.wn("knight", "swing_seconds", 0.44))
	var moving: bool = k.prev.distance_squared_to(k.pos) > 0.00001
	knight_view.pose(kp, k.yaw, swing, moving, k.down_t, delta)
	sprig_view.update(sim, alpha, k.selected_type, delta, _elapsed)
	world_view.update(sim, alpha, _elapsed)
	fx.tick(delta)
	# whistle ring and throw arc follow the cursor
	var whistling: bool = mode == Mode.PLAY and cmd.whistle_held and k.down_t < 0.0
	fx.whistle(SquadSystem.whistle_centre(sim, cmd), SquadSystem.whistle_radius(sim), whistling)
	var can_throw: bool = mode == Mode.PLAY and cursor != Vector3.INF and sim.squad_count(k.selected_type) > 0 and k.down_t < 0.0
	if can_throw:
		var t: Types.SprigType = tables.sprig(k.selected_type)
		var target: Vector3 = sim.ground(Throw.clamp_target(kp, cursor, t.throw_range))
		var total: float = SquadSystem.flight_time(sim, t)
		fx.arc(Throw.arc_points(kp + Vector3(0.0, 1.0, 0.0), target, total, tables.wn("squad", "throw_gravity", 22.0)), true)
	else:
		fx.arc(PackedVector3Array(), false)
	hud.update(sim, fx.notes(), cursor)


func _update_cursor() -> void:
	var vp: Viewport = get_viewport()
	var m: Vector2 = vp.get_mouse_position()
	var cam: Camera3D = rig.cam
	var origin: Vector3 = cam.project_ray_origin(m)
	var dir: Vector3 = cam.project_ray_normal(m)
	var hit: Vector3 = sim.field.raycast(origin, dir, 220.0)
	if hit == Vector3.INF or absf(hit.x) > sim.field.bound or absf(hit.z) > sim.field.bound:
		cursor = Vector3.INF
	else:
		cursor = hit


# ---- the screenshot seam ------------------------------------------------------------------------

## Boot straight into a fixture world, no title, for tools/shot.gd.
func boot_for_shot(fixture_path: String) -> void:
	_shot_mode = true
	title.visible = false
	var text: String = FileAccess.get_file_as_string(fixture_path)
	var v: Variant = JSON.parse_string(text)
	var w: SimWorld
	if v is Dictionary:
		w = Serialize.from_doc(tables, v)
	else:
		w = SimWorld.new(tables, 7)
		Worldgen.populate(w)
	slot = ""
	_mount(w)
	# a squad at his heels so the shot shows the game, not an empty clearing
	for i: int in 14:
		var ang: float = float(i) / 14.0 * TAU
		w.spawn_sprig("ember" if i % 3 != 0 else "stone", w.knight.pos + Vector3(sin(ang), 0.0, cos(ang)) * 1.6, Entities.Sprig.State.FOLLOW, i % 3)
	cursor = w.ground(w.knight.pos + Vector3(4.0, 0.0, -3.0))


## Deterministic poses for the shot harness: "throw" arcs one sprig; "night" jumps to dusk.
func shot_pose(name: String) -> void:
	match name:
		"throw":
			cmd.throw_pressed = true
		"night":
			sim.clock.time = sim.clock.day_seconds + 10.0
		"whistle":
			_shot_whistle = true
		"bestiary":
			_shot_bestiary()
		"far":
			_shot_far()
		_:
			if name.begins_with("region:"):
				_shot_whistle = false
				_shot_to_region(name.substr(7))


## Shot seam: one of each beast in a row in front of him, asleep or idle, the mole underground.
func _shot_bestiary() -> void:
	_shot_whistle = false
	var at: Vector3 = sim.ground(Vector3(0.0, 0.0, 30.0))
	sim.knight.pos = at
	sim.knight.prev = at
	sim.enemies.clear()
	for s: Entities.Sprig in sim.sprigs:
		if s.state == Entities.Sprig.State.FOLLOW:
			s.pos = sim.ground(at + Vector3(float(s.id % 5) * 0.4 - 0.8, 0.0, 1.2 + float(s.id % 3) * 0.4))
			s.prev = s.pos
			s.smooth_target = s.pos
	sim.anchor = Vector3.INF
	var kinds: PackedStringArray = ["cinder_hog", "pounce_toad", "shellback", "gale_puff", "mire_hog", "hollow_mole"]
	for i: int in kinds.size():
		var p: Vector3 = sim.push_out(at + Vector3(-7.5 + 3.0 * float(i), 0.0, -6.0 - 1.5 * float(i % 2)), 1.0)
		var e: Entities.Enemy = sim.spawn_enemy(kinds[i], p)
		e.state = Entities.Enemy.State.SLEEP if kinds[i] != "hollow_mole" else Entities.Enemy.State.BURROW
		e.yaw = PI * 0.15 * float(i - 3) + PI
		e.surface_t = 99.0
	rig.focus = at
	rig.yaw_target = 0.0
	rig.yaw = 0.0
	rig.dist_target = 15.0
	rig.dist = 15.0
	cursor = sim.ground(at + Vector3(0.0, 0.0, -6.0))


## Shot seam: zoomed far out over a ruin, to see the lie of the land.
func _shot_far() -> void:
	var at: Vector3 = sim.knight.pos
	for sc: Dictionary in sim.scenery:
		if sc["kind"] == "column":
			at = sim.ground(sc["pos"] + Vector3(4.0, 0.0, 6.0))
			break
	sim.knight.pos = at
	sim.knight.prev = at
	sim.enemies.clear()
	rig.focus = at
	rig.dist_target = CameraRig.DIST_MAX
	rig.dist = CameraRig.DIST_MAX
	rig.pitch_target = 40.0
	rig.pitch_deg = 40.0


## Shot seam: stand him on the Hold side of a territory with the squad around him.
func _shot_to_region(id: String) -> void:
	for r: Dictionary in sim.regions:
		if r["id"] != id:
			continue
		var c: Vector3 = r["pos"]
		var toward: Vector3 = (sim.hold.pos - c)
		toward.y = 0.0
		toward = toward.normalized()
		var at: Vector3 = sim.ground(c + toward * 4.0)
		sim.knight.pos = at
		sim.knight.prev = at
		sim.knight.yaw = atan2(-toward.x, -toward.z)
		for s: Entities.Sprig in sim.sprigs:
			if s.state == Entities.Sprig.State.FOLLOW:
				s.pos = sim.ground(at + toward * 1.5 + Vector3(float(s.id % 5) * 0.4 - 0.8, 0.0, float(s.id % 3) * 0.4))
				s.prev = s.pos
				s.smooth_target = s.pos
		sim.anchor = Vector3.INF
		rig.focus = at
		rig.yaw_target = atan2(toward.x, toward.z)
		rig.yaw = rig.yaw_target
		cursor = sim.ground(c)
		return
