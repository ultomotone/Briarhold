## All content tables, loaded once from content/*.json into typed maps. Pure RefCounted so the
## sim and the tests take it by value; the Content autoload holds the live copy for the view.
class_name ContentTables
extends RefCounted

# Plain dictionaries on purpose: a typed Dictionary whose value type is an inner class breaks
# under script reload (the value validates against a second class identity). Use the typed
# getters below.
var sprigs: Dictionary = {}
var sprig_order: PackedStringArray = []
var objects: Dictionary = {}
var enemies: Dictionary = {}
var hazards: Dictionary = {}
var world: Dictionary = {}
var regions: Dictionary = {} # regions.json as read: ring_distance, radius, sprouts, regions[]
var errors: PackedStringArray = []


static func load_all(dir: String = "res://content/") -> ContentTables:
	var c := ContentTables.new()
	var s: Dictionary = c._read(dir + "sprigs.json")
	for row: Variant in s.get("types", []):
		var t := Types.SprigType.from_dict(row)
		c.sprigs[t.id] = t
		c.sprig_order.append(t.id)
	var o: Dictionary = c._read(dir + "objects.json")
	for row: Variant in o.get("objects", []):
		var t := Types.ObjectType.from_dict(row)
		c.objects[t.id] = t
	var e: Dictionary = c._read(dir + "enemies.json")
	for row: Variant in e.get("enemies", []):
		var t := Types.EnemyType.from_dict(row)
		c.enemies[t.id] = t
	var h: Dictionary = c._read(dir + "hazards.json")
	for row: Variant in h.get("hazards", []):
		var t := Types.HazardType.from_dict(row)
		c.hazards[t.id] = t
	c.world = c._read(dir + "world.json")
	c.regions = c._read(dir + "regions.json")
	c._validate()
	return c


func sprig(id: String) -> Types.SprigType:
	return sprigs.get(id) as Types.SprigType


func object(id: String) -> Types.ObjectType:
	return objects.get(id) as Types.ObjectType


func enemy(id: String) -> Types.EnemyType:
	return enemies.get(id) as Types.EnemyType


func hazard(id: String) -> Types.HazardType:
	return hazards.get(id) as Types.HazardType


func _read(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		errors.append("cannot read " + path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		errors.append("not a JSON object: " + path)
		return {}
	return parsed


func _validate() -> void:
	for id: String in sprigs.keys():
		var t: Types.SprigType = sprig(id)
		for hz: String in t.immune:
			if not hazards.has(hz):
				errors.append("sprig %s immune to unknown hazard %s" % [id, hz])
		if t.attack != "latch" and t.attack != "impact":
			errors.append("sprig %s has unknown attack %s" % [id, t.attack])
	# a load must be liftable by a full crew of the strongest type (the Brass Acorn is Oak work)
	var strongest: int = 1
	for id: String in sprigs.keys():
		strongest = maxi(strongest, sprig(id).strength)
	for id: String in objects.keys():
		var o: Types.ObjectType = object(id)
		if o.max_carriers * strongest < o.weight:
			errors.append("object %s cannot be lifted even by a full crew of the strongest sprigs" % id)
	for id: String in enemies.keys():
		var en: Types.EnemyType = enemy(id)
		if en.bite_count < 0 or en.hp <= 0.0 or (en.attack == "bite" and en.bite_count < 1):
			errors.append("enemy %s has a bad bite_count or hp" % id)
	if world.is_empty():
		errors.append("world.json empty")
	for row: Variant in regions.get("regions", []):
		var r: Dictionary = row
		if not sprigs.has(str(r.get("type", ""))):
			errors.append("region %s has unknown sprig type" % str(r.get("id", "?")))
		var hz: String = str(r.get("hazard", ""))
		if not hz.is_empty() and not hazards.has(hz):
			errors.append("region %s has unknown hazard %s" % [str(r.get("id", "?")), hz])
		if not objects.has(str(r.get("relic", ""))):
			errors.append("region %s has unknown relic" % str(r.get("id", "?")))


## Nested world number, e.g. wn("knight", "speed").
func wn(section: String, key: String, dflt: float = 0.0) -> float:
	var sec: Variant = world.get(section, {})
	if sec is Dictionary:
		var d: Dictionary = sec
		return float(d.get(key, dflt))
	return dflt


func wi_in(section: String, key: String, dflt: int = 0) -> int:
	return int(wn(section, key, float(dflt)))


## Top-level world number, e.g. w("day_seconds").
func w(key: String, dflt: float = 0.0) -> float:
	return float(world.get(key, dflt))


func wi(key: String, dflt: int = 0) -> int:
	return int(world.get(key, dflt))
