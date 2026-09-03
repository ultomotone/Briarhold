## Ring of things the view should show or play: damage numbers, a sprig lost, dusk, a delivery.
## The sim pushes; the view drains once per frame. Never read by the sim.
class_name SimEvents
extends RefCounted

var list: Array[Dictionary] = []


func push(kind: String, data: Dictionary = {}) -> void:
	data["kind"] = kind
	list.append(data)
	if list.size() > 512:
		list.pop_front()


func drain() -> Array[Dictionary]:
	var out: Array[Dictionary] = list
	list = []
	return out
