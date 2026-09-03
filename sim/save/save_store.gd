## Slots on disk under user://saves/. Writes are atomic: temp file, then rename over the slot,
## keeping the previous version as .prev.json; reads fall back to .prev on a corrupt file.
## base_dir is swappable so tests never touch the real saves.
class_name SaveStore
extends RefCounted

static var base_dir: String = "user://saves"


static func slot_path(slot: String) -> String:
	return base_dir.path_join(slot + ".json")


static func write(slot: String, doc: Dictionary) -> Error:
	var err: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir))
	if err != OK and err != ERR_ALREADY_EXISTS:
		return err
	var final: String = slot_path(slot)
	var tmp: String = final + ".tmp"
	var prev: String = base_dir.path_join(slot + ".prev.json")
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(doc, "\t"))
	f.close()
	var g_final: String = ProjectSettings.globalize_path(final)
	var g_tmp: String = ProjectSettings.globalize_path(tmp)
	var g_prev: String = ProjectSettings.globalize_path(prev)
	if FileAccess.file_exists(final):
		DirAccess.rename_absolute(g_final, g_prev)
	return DirAccess.rename_absolute(g_tmp, g_final)


## Empty dictionary when the slot does not exist or neither copy parses.
static func read(slot: String) -> Dictionary:
	var d: Dictionary = _parse(slot_path(slot))
	if d.is_empty():
		d = _parse(base_dir.path_join(slot + ".prev.json"))
	return d


static func exists(slot: String) -> bool:
	return FileAccess.file_exists(slot_path(slot))


static func _parse(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	# a JSON instance reports the error as a code, not an engine error line; a corrupt slot is
	# an expected condition here, not a fault
	var j := JSON.new()
	if j.parse(text) != OK:
		return {}
	var v: Variant = j.data
	if v is Dictionary:
		return v
	return {}


## One line per slot for the title screen: slot, name, day, total, saved_at.
static func list_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var d := DirAccess.open(base_dir)
	if d == null:
		return out
	d.list_dir_begin()
	var name: String = d.get_next()
	var names: PackedStringArray = []
	while name != "":
		if name.ends_with(".json") and not name.ends_with(".prev.json") and not name.ends_with(".tmp"):
			names.append(name.get_basename())
		name = d.get_next()
	d.list_dir_end()
	names.sort()
	for slot: String in names:
		var doc: Dictionary = read(slot)
		if doc.is_empty():
			continue
		var m: Dictionary = Migrate.run(doc)
		var h: Dictionary = m["hold"]
		out.append({"slot": slot, "name": str(m["name"]), "day": int(m["day"]), "saved_at": int(m["saved_at"]), "sprigs": (m["sprigs"] as Array).size(), "value": int(h["value"])})
	return out
