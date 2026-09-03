## The typecheck gate. Run headless:
##   godot --headless --path . -s res://tools/check.gd
## Loads and reloads every script under sim/, game/, tools/, tests/ with the project's
## warnings-as-errors settings; any script that fails to parse, compile, or instantiate fails
## the gate. Exit 0 clean, 1 failures.
extends SceneTree

const ROOTS: PackedStringArray = ["res://sim", "res://game", "res://tools", "res://tests"]


var _ran: bool = false


func _process(_delta: float) -> bool:
	# First frame, not _init: autoload singletons only exist once the tree has started, and
	# any script that names Content or Palette must see them to compile.
	if _ran:
		return true
	_ran = true
	_check()
	return true


func _check() -> void:
	var failures: PackedStringArray = []
	var count: int = 0
	for root: String in ROOTS:
		for p: String in _walk(root):
			count += 1
			# CACHE_MODE_REUSE: the autoloads already hold instances of their scripts, and a
			# replaced script would be a second class identity. Loading compiles; that is the check.
			var s: Variant = ResourceLoader.load(p, "GDScript", ResourceLoader.CACHE_MODE_REUSE)
			if s == null or not s is GDScript:
				failures.append(p + " (load failed)")
				continue
			var gs: GDScript = s
			if not gs.can_instantiate():
				failures.append(p + " (cannot instantiate)")
	print("CHECK scripts=%d failures=%d" % [count, failures.size()])
	for f: String in failures:
		print("CHECK FAIL " + f)
	quit(0 if failures.is_empty() else 1)


func _walk(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var name: String = d.get_next()
	while name != "":
		if name.begins_with("."):
			name = d.get_next()
			continue
		var full: String = dir.path_join(name)
		if d.current_is_dir():
			out.append_array(_walk(full))
		elif name.ends_with(".gd"):
			out.append(full)
		name = d.get_next()
	d.list_dir_end()
	return out
