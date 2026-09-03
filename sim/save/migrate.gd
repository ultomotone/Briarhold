## The save contract. Fields are added, never removed or renamed. Every structural change bumps
## CURRENT and adds a pure, idempotent, field-by-field step to MIGRATIONS in the same commit as
## a new golden fixture under tests/fixtures/. run() on a current document is a no-op.
class_name Migrate
extends RefCounted

const CURRENT: int = 1
const KEY: String = "briarhold:save" # the slot file's identity line; never changes


static func run(doc: Dictionary) -> Dictionary:
	var d: Dictionary = doc.duplicate(true)
	var v: int = int(d.get("schemaVersion", 0))
	if v < 1:
		d = _to_v1(d)
	d["schemaVersion"] = CURRENT
	d["key"] = KEY
	return d


## v1: the first shape. Applied to any pre-versioned document; fills what is missing.
static func _to_v1(d: Dictionary) -> Dictionary:
	_default(d, "seed", 1)
	_default(d, "saved_at", 0)
	_default(d, "day", 1)
	_default(d, "clock_time", 0.0)
	_default(d, "knight", {})
	var k: Dictionary = d["knight"]
	_default(k, "x", 0.0)
	_default(k, "z", 3.0)
	_default(k, "yaw", 0.0)
	_default(k, "hp", 100.0)
	_default(k, "selected", "ember")
	_default(d, "hold", {})
	var h: Dictionary = d["hold"]
	_default(h, "cap", 20)
	_default(h, "value", 0)
	_default(h, "stock", {})
	_default(h, "stored", {})
	_default(h, "queue", [])
	_default(h, "seeds_grown", 0)
	_default(h, "felled", 0)
	_default(h, "relics_banked", 0)
	_default(h, "gates_opened", 0)
	_default(h, "heartroots", 0)
	_default(d, "sprigs", [])
	_default(d, "sprouts", [])
	_default(d, "shrines", [])
	_default(d, "deltas", {})
	var dl: Dictionary = d["deltas"]
	_default(dl, "taken", [])
	_default(dl, "felled", [])
	_default(dl, "opened", [])
	_default(dl, "rooted", [])
	_default(d, "lost_total", 0)
	_default(d, "name", "Briarhold")
	return d


static func _default(d: Dictionary, k: String, v: Variant) -> void:
	if not d.has(k):
		d[k] = v
