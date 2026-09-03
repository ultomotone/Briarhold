## Plain-data records the sim moves. No behaviour here beyond tiny helpers; systems do the work.
## Every mover keeps prev so the view can interpolate between ticks.
class_name Entities
extends RefCounted


class Knight:
	extends RefCounted
	var pos: Vector3 = Vector3.ZERO
	var prev: Vector3 = Vector3.ZERO
	var yaw: float = 0.0
	var hp: float = 100.0
	var max_hp: float = 100.0
	var swing_t: float = -1.0 # <0 idle, else seconds into the swing
	var swing_hit: bool = false
	var walk_target: Vector3 = Vector3.INF
	var since_hit: float = 99.0
	var invuln: float = 0.0 # seconds of post-hit invulnerability left
	var throw_held: float = -1.0 # <0 not held; seconds Space has been held (auto-throw ramp)
	var throw_repeat: float = 0.0
	var down_t: float = -1.0 # >=0 while defeated (blackout)
	var selected_type: String = "ember"
	var whistle_t: float = 0.0 # seconds the whistle has been held
	var pluck_t: float = 0.0


class Sprig:
	extends RefCounted
	enum State { FOLLOW, IDLE, THROWN, CARRY, ATTACK, CHARGE, DEAD }
	var id: int = 0
	var type_id: String = "ember"
	var pos: Vector3 = Vector3.ZERO
	var prev: Vector3 = Vector3.ZERO
	var yaw: float = 0.0
	var state: int = State.IDLE
	var maturity: int = 0 # 0 leaf, 1 bud, 2 bloom
	var lag: float = 0.2
	var slot: int = 0
	var smooth_target: Vector3 = Vector3.ZERO
	var phase: float = 0.0
	# flight
	var fl_start: Vector3 = Vector3.ZERO
	var fl_end: Vector3 = Vector3.ZERO
	var fl_t: float = 0.0
	var fl_total: float = 0.6
	# work
	var job_id: int = -1
	var anchor: int = 0
	var enemy_id: int = -1
	var gate_id: int = -1
	var latched: bool = false
	var slap_t: float = 0.0
	var charge_target: Vector3 = Vector3.INF
	# harm
	var status: String = "" # hazard status id
	var status_t: float = 0.0
	var hazard_id: String = ""
	var stun: float = 0.0
	var idle_scan: int = 0


class Sprout:
	extends RefCounted
	var id: int = 0
	var type_id: String = "ember"
	var pos: Vector3 = Vector3.ZERO
	var age: float = 0.0
	var maturity: int = 0
	# seeds in flight from the shrine before rooting
	var fl_start: Vector3 = Vector3.ZERO
	var fl_t: float = -1.0 # <0 rooted
	var fl_total: float = 0.9


class Shrine:
	extends RefCounted
	var id: int = 0
	var type_id: String = "ember"
	var pos: Vector3 = Vector3.ZERO
	var rooted: bool = true # false while it still sits in the field, waiting to be carried home


class WorldObject:
	extends RefCounted
	var id: int = 0
	var type_id: String = "pellet_1"
	var kind: String = "pellet" # pellet | relic | heartroot | corpse | shrine
	var name: String = ""
	var pos: Vector3 = Vector3.ZERO
	var prev: Vector3 = Vector3.ZERO
	var yaw: float = 0.0
	var weight: int = 1
	var max_carriers: int = 2
	var seeds_match: int = 0
	var seeds_other: int = 0
	var value: int = 0
	var radius: float = 0.4
	var pellet_type: String = "" # pellets are tinted to a type; matching carriers double the yield
	var shrine_type: String = "" # kind == shrine
	var carriers: PackedInt32Array = []
	## carrier spot slots around the load: index = spot, value = sprig id or -1. The ring is
	## rotated so spot 0 faces the first claimant; each arrival takes the nearest free spot.
	var slots: PackedInt32Array = []
	var path: PackedVector3Array = []
	var path_i: int = 0
	var path_gen: int = -1
	var taken: bool = false
	var seed_id: String = "" # world-gen identity for the save's deltas; "" = spawned in play


class Enemy:
	extends RefCounted
	enum State { SLEEP, IDLE, CHASE, TELEGRAPH, RECOVER, SHAKE, DEAD, RETREAT }
	var id: int = 0
	var type_id: String = "grub"
	var pos: Vector3 = Vector3.ZERO
	var prev: Vector3 = Vector3.ZERO
	var yaw: float = 0.0
	var home: Vector3 = Vector3.ZERO
	var hp: float = 100.0
	var max_hp: float = 100.0
	var state: int = State.SLEEP
	var timer: float = 0.0
	var cooldown: float = 0.0
	var itch: float = 0.0
	var itch_t: float = 99.0 # seconds since the last shake
	var target_pos: Vector3 = Vector3.INF
	var target_kind: String = "" # "knight" | "sprig" | "hold"
	var target_id: int = -1
	var wind: float = 0.0 # telegraph 0..1 for the view
	var seed_id: String = ""
	var night: bool = false


class HazardZone:
	extends RefCounted
	var id: int = 0
	var hazard_id: String = "fire"
	var pos: Vector3 = Vector3.ZERO
	var radius: float = 1.6
	var pulse: float = 0.0 # 0..1 visual


class Gate:
	extends RefCounted
	var id: int = 0
	var pos: Vector3 = Vector3.ZERO
	var yaw: float = 0.0
	var width: float = 4.0
	var hp: float = 400.0
	var max_hp: float = 400.0
	var open: bool = false
	var seed_id: String = ""


class CarryJob:
	extends RefCounted
	var id: int = 0
	var object_id: int = 0
	var carriers: PackedInt32Array = []
	var progress: float = 0.0 # distance along the current segment
	var moving: bool = false
