## The world: every record the game runs on, stepped by exactly one call site at a fixed rate.
## Pure RefCounted. No Node, no Input, no wall clock (the driver passes unix time in), no engine
## randomness. Systems are static functions over this state, run in a fixed order in step().
class_name SimWorld
extends RefCounted

const FIXED_DT: float = 1.0 / 60.0

var content: ContentTables
var seed: int = 1
var tick: int = 0
var clock: Clock
var field: Heightfield
var paths: PathProvider
var events: SimEvents
var knight: Entities.Knight
var hold: Hold
var sprigs: Array[Entities.Sprig] = []
var sprouts: Array[Entities.Sprout] = []
var shrines: Array[Entities.Shrine] = []
var objects: Array[Entities.WorldObject] = []
var enemies: Array[Entities.Enemy] = []
var hazards: Array[Entities.HazardZone] = []
var gates: Array[Entities.Gate] = []
var jobs: Array[Entities.CarryJob] = []
var obstacles: Array[Dictionary] = [] # {"pos": Vector3, "r": float, "h": float}
var nav_blockers: Array[Dictionary] = [] # {"pos", "r"}: routed around by carriers, walkable by feet (pools)
var posies: Array[Entities.Posy] = []
## The outer territories: {"id", "name", "type", "pos", "radius", "line"}. Rolled from the seed.
var regions: Array[Dictionary] = []
## Ground set aside for the regions so the field's scatter stays out of them: {"pos", "r"}.
var reserved: Array[Dictionary] = []
## Tall marker stones, one per region, view-only: {"pos", "type"}.
var landmarks: Array[Dictionary] = []
## Region ids he has walked into. Saved.
var discovered: PackedStringArray = []
var plants: Array[Dictionary] = [] # view-only scatter {"pos", "s", "kind"}
## The larger furniture of the field, for the view: stumps, fallen branches, ruins, giant
## mushrooms and daisies. Each also put obstacles in `obstacles` (kind tagged) for the sim.
var scenery: Array[Dictionary] = []
## Campsites the Hold can move to: {"id", "name", "pos"}. The first is "home", the Hold's own
## clearing at the origin. Rolled from the seed; which one is the Hold now is saved (camp_id).
var camps: Array[Dictionary] = []
var camp_id: String = "home"
var camp_t: float = 0.0 # seconds T has been held at a campsite
## Boss arenas: {"id", "name", "pos", "radius", "boss"}. Rolled from the seed.
var arenas: Array[Dictionary] = []
var hash: SpatialHash
var next_id: int = 1
var deltas: Dictionary = {"taken": PackedStringArray(), "felled": PackedStringArray(), "opened": PackedStringArray(), "rooted": PackedStringArray()}
## The squad's formation anchor (SquadSystem): trails him, settles when he stops.
var anchor: Vector3 = Vector3.INF
var anchor_yaw: float = 0.0
var lost_tonight: int = 0
var lost_total: int = 0
var last_night_report: Dictionary = {}
var nav_dirty: bool = true


func _init(tables: ContentTables, world_seed: int) -> void:
	content = tables
	seed = world_seed
	clock = Clock.new(tables.w("day_seconds", 900.0), tables.w("night_seconds", 360.0), tables.w("dusk_warning_seconds", 90.0))
	field = Heightfield.new(world_seed, tables.world)
	paths = PathProvider.new()
	events = SimEvents.new()
	hash = SpatialHash.new(3.0)
	knight = Entities.Knight.new()
	knight.max_hp = tables.wn("knight", "hp", 100.0)
	knight.hp = knight.max_hp
	hold = Hold.new()
	hold.radius = tables.w("hold_radius", 9.0)
	hold.safe_radius = tables.w("hold_safe_radius", 14.0)
	hold.cap = tables.wi("field_cap_start", 20)
	hold.cap_per_heartroot = tables.wi("field_cap_per_heartroot", 10)
	knight.pos = Vector3(0.0, 0.0, 3.0)
	knight.prev = knight.pos


func new_id() -> int:
	var id: int = next_id
	next_id += 1
	return id


func seed_str() -> String:
	return "world:%d" % seed


func ground(p: Vector3) -> Vector3:
	return field.ground(p)


# ---- stepping -------------------------------------------------------------------------------

func step(cmd: Commands, dt: float) -> void:
	tick += 1
	_begin_tick()
	for ev: String in clock.advance(dt):
		events.push(ev, {"day": clock.day})
		if ev == "night":
			EnemySystem.on_night(self)
		elif ev == "dawn":
			EnemySystem.on_dawn(self)
	KnightSystem.step(self, cmd, dt)
	SquadSystem.step(self, cmd, dt)
	CarrySystem.step(self, dt)
	EnemySystem.step(self, dt)
	HazardSystem.step(self, dt)
	HoldSystem.step(self, dt)
	FieldSystem.step(self, dt)
	CampSystem.step(self, cmd, dt)
	if tick % 15 == 0:
		_discover()
	_end_tick()


## Walking into a region names it on the map, once.
func _discover() -> void:
	for r: Dictionary in regions:
		var id: String = r["id"]
		if discovered.has(id):
			continue
		var c: Vector3 = r["pos"]
		if flat_dist(knight.pos, c) <= float(r["radius"]):
			discovered.append(id)
			events.push("region_found", {"id": id, "name": r["name"], "type": r["type"], "line": r["line"], "pos": c})
	for cp: Dictionary in camps:
		var cid: String = cp["id"]
		if cid == "home" or discovered.has(cid):
			continue
		if flat_dist(knight.pos, cp["pos"]) <= 22.0:
			discovered.append(cid)
			events.push("camp_found", {"id": cid, "name": cp["name"], "pos": cp["pos"]})
	for ar: Dictionary in arenas:
		var aid: String = ar["id"]
		if discovered.has(aid):
			continue
		if flat_dist(knight.pos, ar["pos"]) <= float(ar["radius"]) + 14.0:
			discovered.append(aid)
			var bt: Types.EnemyType = content.enemy(str(ar["boss"]))
			events.push("arena_found", {"id": aid, "name": ar["name"], "boss": bt.name if bt != null else "", "line": bt.line if bt != null else "", "pos": ar["pos"]})


func _begin_tick() -> void:
	knight.prev = knight.pos
	hash.clear()
	for s: Entities.Sprig in sprigs:
		s.prev = s.pos
		if s.state != Entities.Sprig.State.THROWN:
			hash.insert(s.id, s.pos)
	for e: Entities.Enemy in enemies:
		e.prev = e.pos
	for o: Entities.WorldObject in objects:
		o.prev = o.pos


func _end_tick() -> void:
	# the dead leave the list here, never mid-system, so no system sees a half-removed record
	var alive: Array[Entities.Sprig] = []
	for s: Entities.Sprig in sprigs:
		if s.state != Entities.Sprig.State.DEAD:
			alive.append(s)
	sprigs = alive
	var standing: Array[Entities.Enemy] = []
	for e: Entities.Enemy in enemies:
		if e.state != Entities.Enemy.State.DEAD:
			standing.append(e)
	enemies = standing
	var here: Array[Entities.WorldObject] = []
	for o: Entities.WorldObject in objects:
		if not o.taken:
			here.append(o)
	objects = here
	var open_jobs: Array[Entities.CarryJob] = []
	for j: Entities.CarryJob in jobs:
		if object_by_id(j.object_id) != null:
			open_jobs.append(j)
	jobs = open_jobs


# ---- lookups --------------------------------------------------------------------------------

func sprig_by_id(id: int) -> Entities.Sprig:
	for s: Entities.Sprig in sprigs:
		if s.id == id:
			return s
	return null


func object_by_id(id: int) -> Entities.WorldObject:
	for o: Entities.WorldObject in objects:
		if o.id == id and not o.taken:
			return o
	return null


func enemy_by_id(id: int) -> Entities.Enemy:
	for e: Entities.Enemy in enemies:
		if e.id == id:
			return e
	return null


func gate_by_id(id: int) -> Entities.Gate:
	for g: Entities.Gate in gates:
		if g.id == id:
			return g
	return null


func job_by_id(id: int) -> Entities.CarryJob:
	for j: Entities.CarryJob in jobs:
		if j.id == id:
			return j
	return null


func job_for_object(object_id: int) -> Entities.CarryJob:
	for j: Entities.CarryJob in jobs:
		if j.object_id == object_id:
			return j
	return null


func shrine_for(type_id: String) -> Entities.Shrine:
	for sh: Entities.Shrine in shrines:
		if sh.type_id == type_id and sh.rooted:
			return sh
	return null


func sprig_type(s: Entities.Sprig) -> Types.SprigType:
	return content.sprig(s.type_id)


func enemy_type(e: Entities.Enemy) -> Types.EnemyType:
	return content.enemy(e.type_id)


## Sprigs standing in the field plus sprouts still in the ground: what counts against the cap.
func field_count() -> int:
	var n: int = 0
	for s: Entities.Sprig in sprigs:
		if s.state != Entities.Sprig.State.DEAD:
			n += 1
	return n + sprouts.size()


func squad_count(type_id: String = "") -> int:
	var n: int = 0
	for s: Entities.Sprig in sprigs:
		if s.state == Entities.Sprig.State.FOLLOW and (type_id.is_empty() or s.type_id == type_id):
			n += 1
	return n


func census() -> Dictionary:
	var out: Dictionary = {}
	for s: Entities.Sprig in sprigs:
		out[s.type_id] = int(out.get(s.type_id, 0)) + 1
	return out


func squad_types() -> PackedStringArray:
	var out: PackedStringArray = []
	for id: String in content.sprig_order:
		if squad_count(id) > 0:
			out.append(id)
	return out


func maturity_mult(s: Entities.Sprig) -> float:
	if s.maturity >= 2:
		return content.wn("sprout", "bloom_speed_mult", 1.2)
	if s.maturity == 1:
		return content.wn("sprout", "bud_speed_mult", 1.1)
	return 1.0


# ---- spawning -------------------------------------------------------------------------------

func spawn_sprig(type_id: String, p: Vector3, state: int, maturity: int = 0) -> Entities.Sprig:
	var s := Entities.Sprig.new()
	s.id = new_id()
	s.type_id = type_id
	s.pos = ground(p)
	s.prev = s.pos
	s.smooth_target = s.pos
	s.state = state
	s.maturity = maturity
	var r := Rng.stream("%s:sprig:%d" % [seed_str(), s.id])
	var t: Types.SprigType = content.sprig(type_id)
	s.lag = 0.12 + r.randf() * 0.22 + (t.lag_bias if t != null else 0.0)
	s.phase = r.randf() * TAU
	s.yaw = r.randf() * TAU
	sprigs.append(s)
	return s


func kill_sprig(s: Entities.Sprig, cause: String) -> void:
	if s.state == Entities.Sprig.State.DEAD:
		return
	_detach(s)
	s.state = Entities.Sprig.State.DEAD
	lost_tonight += 1
	lost_total += 1
	events.push("sprig_lost", {"pos": s.pos, "type": s.type_id, "cause": cause})


## Pull a sprig off whatever it was doing (a job, an enemy, a gate) without changing its state.
func _detach(s: Entities.Sprig) -> void:
	if s.job_id >= 0:
		var j: Entities.CarryJob = job_by_id(s.job_id)
		if j != null:
			var idx: int = j.carriers.find(s.id)
			if idx >= 0:
				j.carriers.remove_at(idx)
			var o: Entities.WorldObject = object_by_id(j.object_id)
			if o != null:
				var oi: int = o.carriers.find(s.id)
				if oi >= 0:
					o.carriers.remove_at(oi)
				var si: int = o.slots.find(s.id)
				if si >= 0:
					o.slots[si] = -1
		s.job_id = -1
	s.enemy_id = -1
	s.gate_id = -1
	s.latched = false
	s.charge_target = Vector3.INF


func set_state(s: Entities.Sprig, state: int) -> void:
	if s.state == state:
		return
	_detach(s)
	s.state = state
	s.idle_scan = 0


func spawn_object(type_id: String, p: Vector3, seed_id: String = "", pellet_type: String = "") -> Entities.WorldObject:
	var t: Types.ObjectType = content.object(type_id)
	var o := Entities.WorldObject.new()
	o.id = new_id()
	o.type_id = type_id
	o.kind = t.kind
	o.name = t.name
	o.pos = ground(p)
	o.prev = o.pos
	o.weight = t.weight
	o.max_carriers = t.max_carriers
	o.seeds_match = t.seeds_match
	o.seeds_other = t.seeds_other
	o.value = t.value
	o.radius = t.radius
	o.pellet_type = pellet_type
	o.seed_id = seed_id
	objects.append(o)
	return o


func spawn_shrine_object(type_id: String, p: Vector3, seed_id: String) -> Entities.WorldObject:
	var o := Entities.WorldObject.new()
	o.id = new_id()
	o.type_id = "shrine_" + type_id
	o.kind = "shrine"
	var t: Types.SprigType = content.sprig(type_id)
	o.name = (t.name if t != null else type_id) + " Shrine"
	o.pos = ground(p)
	o.prev = o.pos
	o.weight = 12
	o.max_carriers = 24
	o.radius = 1.1
	o.shrine_type = type_id
	o.seed_id = seed_id
	objects.append(o)
	return o


func spawn_corpse(e: Entities.Enemy) -> Entities.WorldObject:
	var t: Types.EnemyType = enemy_type(e)
	var o := Entities.WorldObject.new()
	o.id = new_id()
	o.type_id = "corpse_" + e.type_id
	o.kind = "corpse"
	o.name = t.name
	o.pos = ground(e.pos)
	o.prev = o.pos
	o.weight = t.weight
	o.max_carriers = t.max_carriers
	o.seeds_match = t.seeds
	o.seeds_other = t.seeds
	o.value = t.value
	o.radius = t.radius
	objects.append(o)
	return o


func spawn_enemy(type_id: String, p: Vector3, seed_id: String = "") -> Entities.Enemy:
	var t: Types.EnemyType = content.enemy(type_id)
	var e := Entities.Enemy.new()
	e.id = new_id()
	e.type_id = type_id
	e.pos = ground(p)
	e.prev = e.pos
	e.home = e.pos
	e.hp = t.hp
	e.max_hp = t.hp
	e.state = Entities.Enemy.State.SLEEP if t.sleeps_by_day else Entities.Enemy.State.IDLE
	e.night = t.night
	e.seed_id = seed_id
	var r := Rng.stream("%s:enemy:%d" % [seed_str(), e.id])
	e.yaw = r.randf() * TAU
	enemies.append(e)
	return e


func spawn_posy(p: Vector3, pellet_type: String, index: int) -> Entities.Posy:
	var po := Entities.Posy.new()
	po.id = new_id()
	po.index = index
	po.pos = ground(p)
	po.pellet_type = pellet_type
	posies.append(po)
	return po


func spawn_sprout(type_id: String, p: Vector3, from: Vector3 = Vector3.INF, maturity: int = 0) -> Entities.Sprout:
	var sp := Entities.Sprout.new()
	sp.id = new_id()
	sp.type_id = type_id
	sp.pos = ground(p)
	sp.maturity = maturity
	if from != Vector3.INF:
		sp.fl_start = from
		sp.fl_t = 0.0
		sp.fl_total = content.wn("sprout", "seed_flight_seconds", 0.9)
	sprouts.append(sp)
	return sp


func root_shrine(type_id: String, p: Vector3) -> Entities.Shrine:
	var sh := Entities.Shrine.new()
	sh.id = new_id()
	sh.type_id = type_id
	sh.pos = ground(p)
	sh.rooted = true
	shrines.append(sh)
	return sh


# ---- callbacks from the damage sink -----------------------------------------------------------

func on_enemy_felled(e: Entities.Enemy, cause: String) -> void:
	hold.felled += 1
	if not e.seed_id.is_empty():
		var f: PackedStringArray = deltas["felled"]
		f.append(e.seed_id)
		deltas["felled"] = f
	# whoever was hanging on lets go
	for s: Entities.Sprig in sprigs:
		if s.enemy_id == e.id:
			set_state(s, Entities.Sprig.State.IDLE)
	if not e.night:
		spawn_corpse(e)
	events.push("enemy_felled", {"pos": e.pos, "type": e.type_id, "cause": cause})


func on_knight_down(cause: String) -> void:
	knight.down_t = 0.0
	knight.swing_t = -1.0
	for s: Entities.Sprig in sprigs:
		if s.state == Entities.Sprig.State.FOLLOW:
			set_state(s, Entities.Sprig.State.IDLE)
	events.push("knight_down", {"pos": knight.pos, "cause": cause})


func on_gate_opened(g: Entities.Gate) -> void:
	hold.gates_opened += 1
	nav_dirty = true
	paths.generation += 1
	if not g.seed_id.is_empty():
		var o: PackedStringArray = deltas["opened"]
		o.append(g.seed_id)
		deltas["opened"] = o
	for s: Entities.Sprig in sprigs:
		if s.gate_id == g.id:
			set_state(s, Entities.Sprig.State.IDLE)
	events.push("gate_opened", {"pos": g.pos})


# ---- shared movement helpers -----------------------------------------------------------------

## Obstacles bucketed on a coarse grid so a point only checks the few near it. Each obstacle is
## filed under every cell its circle plus OB_MARGIN touches, so one cell answers for any body up
## to OB_MARGIN wide. Rebuilt whenever the obstacle count changes (worldgen only adds).
const OB_CELL: float = 6.0
const OB_MARGIN: float = 1.6
var _ob_grid: Dictionary = {} # Vector2i -> PackedInt32Array of obstacle indices
var _ob_grid_n: int = -1


func _ob_index() -> void:
	if _ob_grid_n == obstacles.size():
		return
	# worldgen only appends: file just the new ones. Anything else (a cleared list) rebuilds.
	var start: int = _ob_grid_n
	if start < 0 or start > obstacles.size():
		_ob_grid.clear()
		start = 0
	for i: int in range(start, obstacles.size()):
		var ob: Dictionary = obstacles[i]
		var c: Vector3 = ob["pos"]
		var r: float = float(ob["r"]) + OB_MARGIN
		for gx: int in range(floori((c.x - r) / OB_CELL), floori((c.x + r) / OB_CELL) + 1):
			for gz: int in range(floori((c.z - r) / OB_CELL), floori((c.z + r) / OB_CELL) + 1):
				var key := Vector2i(gx, gz)
				# copy, then append: a packed array taken from a default (or a constant) is shared,
				# and appending to it in place made every cell alias one growing list that outlived
				# the world it was built for (worldgen stopped being deterministic)
				var arr: PackedInt32Array = PackedInt32Array(_ob_grid[key]) if _ob_grid.has(key) else PackedInt32Array()
				arr = arr.duplicate()
				arr.append(i)
				_ob_grid[key] = arr
	_ob_grid_n = obstacles.size()


## Indices of the obstacles that could touch a body at p no wider than OB_MARGIN.
func obstacles_near(p: Vector3) -> PackedInt32Array:
	_ob_index()
	return _ob_grid.get(Vector2i(floori(p.x / OB_CELL), floori(p.z / OB_CELL)), PackedInt32Array())


## True if p is within margin of any obstacle (margin up to OB_MARGIN).
func blocked(p: Vector3, margin: float) -> bool:
	for i: int in obstacles_near(p):
		var ob: Dictionary = obstacles[i]
		var c: Vector3 = ob["pos"]
		if flat_dist(p, c) < float(ob["r"]) + margin:
			return true
	return false


## The ground's own conditions on a walker's pace: snow drags at everything but Frost sprigs,
## sand at everything but Embers, jungle undergrowth at everything but Thorns. Moths fly over
## it all. The gnome feels each a little ("knight"). Deterministic, from the climate there.
func ground_mult(p: Vector3, type_id: String) -> float:
	if type_id == "moth":
		return 1.0
	var cl: Vector3 = field.climate(p.x, p.z)
	if cl == Vector3.ZERO:
		return 1.0
	if type_id == "knight":
		return 1.0 - 0.12 * cl.x - 0.08 * cl.y - 0.06 * cl.z
	var m: float = 1.0
	if type_id != "frost":
		m -= 0.22 * cl.x
	if type_id != "ember":
		m -= 0.15 * cl.y
	if type_id != "thorn":
		m -= 0.12 * cl.z
	return m


## Like blocked(), for margins wider than OB_MARGIN (placing a big trunk or a hollow log): checks
## the 3x3 cells around p, good for margins up to OB_CELL + OB_MARGIN.
func blocked_wide(p: Vector3, margin: float) -> bool:
	_ob_index()
	var cx: int = floori(p.x / OB_CELL)
	var cz: int = floori(p.z / OB_CELL)
	for gx: int in range(cx - 1, cx + 2):
		for gz: int in range(cz - 1, cz + 2):
			var arr: PackedInt32Array = _ob_grid.get(Vector2i(gx, gz), PackedInt32Array())
			for i: int in arr:
				var ob: Dictionary = obstacles[i]
				if flat_dist(p, ob["pos"]) < float(ob["r"]) + margin:
					return true
	return false


## Push a point out of every stone and closed gate it overlaps.
func push_out(p: Vector3, body_r: float) -> Vector3:
	var q: Vector3 = p
	for oi: int in obstacles_near(p):
		var ob: Dictionary = obstacles[oi]
		var c: Vector3 = ob["pos"]
		var r: float = float(ob["r"]) + body_r
		var d: Vector3 = q - c
		d.y = 0.0
		var len: float = d.length()
		if len < r and len > 0.0001:
			q += d * ((r - len) / len)
		elif len <= 0.0001:
			q.x += r
	for g: Entities.Gate in gates:
		if g.open:
			continue
		# the gate is a thick line segment of length width across its yaw
		var axis := Vector3(cos(g.yaw), 0.0, -sin(g.yaw))
		var rel: Vector3 = q - g.pos
		rel.y = 0.0
		var along: float = clampf(rel.dot(axis), -g.width * 0.5, g.width * 0.5)
		var closest: Vector3 = g.pos + axis * along
		var d: Vector3 = q - closest
		d.y = 0.0
		var len: float = d.length()
		var r: float = 0.55 + body_r
		if len < r and len > 0.0001:
			q += d * ((r - len) / len)
	q = field.clamp_bound(q)
	return ground(q)


## Move toward a target on the ground at speed; returns the new position (pushed out of stones).
func step_toward(p: Vector3, target: Vector3, speed: float, dt: float, body_r: float = 0.25) -> Vector3:
	var d: Vector3 = target - p
	d.y = 0.0
	var len: float = d.length()
	if len < 0.0001:
		return push_out(p, body_r)
	var m: float = minf(len, speed * dt)
	return push_out(p + d * (m / len), body_r)


static func yaw_toward(from: Vector3, to: Vector3, current: float) -> float:
	var d: Vector3 = to - from
	if d.x * d.x + d.z * d.z < 0.000001:
		return current
	return atan2(d.x, d.z)


static func flat_dist(a: Vector3, b: Vector3) -> float:
	var dx: float = a.x - b.x
	var dz: float = a.z - b.z
	return sqrt(dx * dx + dz * dz)
