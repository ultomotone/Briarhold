## Type-Objects for content rows. An entity references a type record; promotion or a new type
## is a new row, never a subclass. Loaded by ContentTables from content/*.json.
class_name Types
extends RefCounted


static func _f(d: Dictionary, k: String, dflt: float = 0.0) -> float:
	return float(d.get(k, dflt))


static func _i(d: Dictionary, k: String, dflt: int = 0) -> int:
	return int(d.get(k, dflt))


static func _s(d: Dictionary, k: String, dflt: String = "") -> String:
	return str(d.get(k, dflt))


static func _b(d: Dictionary, k: String, dflt: bool = false) -> bool:
	return bool(d.get(k, dflt))


static func _sa(d: Dictionary, k: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var arr: Variant = d.get(k, [])
	if arr is Array:
		for v: Variant in arr:
			out.append(str(v))
	return out


class SprigType:
	extends RefCounted
	var id: String
	var name: String
	var colour_key: String
	var speed: float
	var strength: int
	var throw_range: float
	var throw_height: float
	var damage: float
	var attack: String # "latch" | "impact"
	var immune: PackedStringArray
	var lag_bias: float
	var dig_mult: float
	var can_fly: bool
	var scale: float
	var wings: bool
	var line: String

	static func from_dict(d: Dictionary) -> SprigType:
		var t := SprigType.new()
		t.id = Types._s(d, "id")
		t.name = Types._s(d, "name")
		t.colour_key = Types._s(d, "colour_key")
		t.speed = Types._f(d, "speed", 4.5)
		t.strength = Types._i(d, "strength", 1)
		t.throw_range = Types._f(d, "throw_range", 7.0)
		t.throw_height = Types._f(d, "throw_height", 1.5)
		t.damage = Types._f(d, "damage", 10.0)
		t.attack = Types._s(d, "attack", "latch")
		t.immune = Types._sa(d, "immune")
		t.lag_bias = Types._f(d, "lag_bias")
		t.dig_mult = Types._f(d, "dig_mult", 1.0)
		t.can_fly = Types._b(d, "can_fly")
		t.scale = Types._f(d, "scale", 1.0)
		t.wings = Types._b(d, "wings")
		t.line = Types._s(d, "line")
		return t


class ObjectType:
	extends RefCounted
	var id: String
	var name: String
	var kind: String # pellet | relic | heartroot | corpse
	var weight: int
	var max_carriers: int
	var seeds_match: int
	var seeds_other: int
	var value: int
	var radius: float
	var set_id: String

	static func from_dict(d: Dictionary) -> ObjectType:
		var t := ObjectType.new()
		t.id = Types._s(d, "id")
		t.name = Types._s(d, "name")
		t.kind = Types._s(d, "kind", "pellet")
		t.weight = Types._i(d, "weight", 1)
		t.max_carriers = Types._i(d, "max_carriers", 2)
		t.seeds_match = Types._i(d, "seeds_match")
		t.seeds_other = Types._i(d, "seeds_other")
		t.value = Types._i(d, "value")
		t.radius = Types._f(d, "radius", 0.4)
		t.set_id = Types._s(d, "set")
		return t


class EnemyType:
	extends RefCounted
	var id: String
	var name: String
	var colour_key: String
	var hp: float
	var speed: float
	var radius: float
	var height: float
	var attack: String
	var bite_count: int
	var bite_reach: float
	var damage_to_knight: float
	var telegraph_seconds: float
	var attack_cooldown: float
	var itch_damage: float
	var itch_time: float
	var back_multiplier: float
	var shake_stun_seconds: float
	var wake_radius: float
	var leash_radius: float
	var sleeps_by_day: bool
	var night: bool
	var roams: bool
	var prey: bool
	var weight: int
	var max_carriers: int
	var seeds: int
	var value: int
	var line: String
	# abilities (see enemies.json _doc)
	var attack_range: float
	var cone_deg: float
	var breath_hazard: String
	var gust_push: float
	var leap_radius: float
	var leap_seconds: float
	var charge_speed: float
	var charge_distance: float
	var daze_seconds: float
	var front_multiplier: float
	var surface_seconds: float

	static func from_dict(d: Dictionary) -> EnemyType:
		var t := EnemyType.new()
		t.id = Types._s(d, "id")
		t.name = Types._s(d, "name")
		t.colour_key = Types._s(d, "colour_key")
		t.hp = Types._f(d, "hp", 200.0)
		t.speed = Types._f(d, "speed", 2.0)
		t.radius = Types._f(d, "radius", 0.8)
		t.height = Types._f(d, "height", 1.0)
		t.attack = Types._s(d, "attack", "bite")
		t.bite_count = Types._i(d, "bite_count", 1)
		t.bite_reach = Types._f(d, "bite_reach", 1.2)
		t.damage_to_knight = Types._f(d, "damage_to_knight", 10.0)
		t.telegraph_seconds = Types._f(d, "telegraph_seconds", 0.6)
		t.attack_cooldown = Types._f(d, "attack_cooldown", 1.5)
		t.itch_damage = Types._f(d, "itch_damage", 100.0)
		t.itch_time = Types._f(d, "itch_time", 3.0)
		t.back_multiplier = Types._f(d, "back_multiplier", 1.0)
		t.shake_stun_seconds = Types._f(d, "shake_stun_seconds", 0.5)
		t.wake_radius = Types._f(d, "wake_radius", 6.0)
		t.leash_radius = Types._f(d, "leash_radius", 14.0)
		t.sleeps_by_day = Types._b(d, "sleeps_by_day", true)
		t.night = Types._b(d, "night")
		t.roams = Types._b(d, "roams")
		t.prey = Types._b(d, "prey")
		t.weight = Types._i(d, "weight", 5)
		t.max_carriers = Types._i(d, "max_carriers", 10)
		t.seeds = Types._i(d, "seeds", 5)
		t.value = Types._i(d, "value")
		t.line = Types._s(d, "line")
		t.attack_range = Types._f(d, "attack_range", t.bite_reach + t.radius)
		t.cone_deg = Types._f(d, "cone_deg", 50.0)
		t.breath_hazard = Types._s(d, "breath_hazard", "fire")
		t.gust_push = Types._f(d, "gust_push", 4.0)
		t.leap_radius = Types._f(d, "leap_radius", 1.6)
		t.leap_seconds = Types._f(d, "leap_seconds", 0.8)
		t.charge_speed = Types._f(d, "charge_speed", 9.0)
		t.charge_distance = Types._f(d, "charge_distance", 12.0)
		t.daze_seconds = Types._f(d, "daze_seconds", 2.0)
		t.front_multiplier = Types._f(d, "front_multiplier", 1.0)
		t.surface_seconds = Types._f(d, "surface_seconds", 6.0)
		return t


class HazardType:
	extends RefCounted
	var id: String
	var name: String
	var status: String
	var kill_after: float
	var whistle_cures: bool
	var flee: bool
	var knight_damage_per_sec: float
	var colour_key: String
	var speed_mult: float
	var hazard_leave_cures: bool
	var disables_attack: bool

	static func from_dict(d: Dictionary) -> HazardType:
		var t := HazardType.new()
		t.id = Types._s(d, "id")
		t.name = Types._s(d, "name")
		t.status = Types._s(d, "status")
		t.kill_after = Types._f(d, "kill_after", -1.0)
		t.whistle_cures = Types._b(d, "whistle_cures")
		t.flee = Types._b(d, "flee")
		t.knight_damage_per_sec = Types._f(d, "knight_damage_per_sec")
		t.colour_key = Types._s(d, "colour_key")
		t.speed_mult = Types._f(d, "speed_mult", 1.0)
		t.hazard_leave_cures = Types._b(d, "hazard_leave_cures")
		t.disables_attack = Types._b(d, "disables_attack")
		return t
