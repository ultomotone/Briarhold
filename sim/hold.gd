## The Hold: the safe place at the origin. What is banked here is safe; what is in the field is at
## risk. It owns the seed economy (what comes in becomes sprouts), the field cap, the relic
## stock, and the Hold total, the one number that shows what his time bought.
class_name Hold
extends RefCounted

var pos: Vector3 = Vector3.ZERO
var radius: float = 9.0
var safe_radius: float = 14.0
var cap: int = 20
var cap_per_heartroot: int = 10
var stored: Dictionary = {} # type_id -> int, sprigs kept inside when the field is full
var queue: Array[Dictionary] = [] # {"type": String, "count": int}
var stock: Dictionary = {} # relic type_id -> int
var value: int = 0
var seeds_grown: int = 0
var felled: int = 0
var relics_banked: int = 0
var gates_opened: int = 0
var heartroots: int = 0
var seed_timer: float = 0.0


func queue_seeds(type_id: String, n: int) -> void:
	if n <= 0:
		return
	queue.append({"type": type_id, "count": n})


func pop_seed() -> String:
	if queue.is_empty():
		return ""
	var head: Dictionary = queue[0]
	var t: String = head["type"]
	var c: int = int(head["count"]) - 1
	if c <= 0:
		queue.pop_front()
	else:
		head["count"] = c
	return t


func queued() -> int:
	var n: int = 0
	for q: Dictionary in queue:
		n += int(q["count"])
	return n


func stored_total() -> int:
	var n: int = 0
	for k: String in stored.keys():
		n += int(stored[k])
	return n


func store(type_id: String, n: int = 1) -> void:
	stored[type_id] = int(stored.get(type_id, 0)) + n


## Take one from storage of any type (sorted so the pick is deterministic). "" if none.
func take_stored() -> String:
	var keys: Array = stored.keys()
	keys.sort()
	for k: Variant in keys:
		var id: String = str(k)
		if int(stored[id]) > 0:
			stored[id] = int(stored[id]) - 1
			return id
	return ""


func bank_relic(type_id: String, v: int) -> void:
	stock[type_id] = int(stock.get(type_id, 0)) + 1
	value += v
	relics_banked += 1


## The Hold total: monotonic, never spent, never reset.
func total() -> int:
	return seeds_grown + value + felled * 5 + gates_opened * 25 + heartroots * 50


func in_safe(p: Vector3) -> bool:
	var d: Vector3 = p - pos
	d.y = 0.0
	return d.length() <= safe_radius


func in_hold(p: Vector3) -> bool:
	var d: Vector3 = p - pos
	d.y = 0.0
	return d.length() <= radius
