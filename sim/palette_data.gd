## The palette as data: every colour and light number, loaded from content/palette.json.
## Pure RefCounted so the invariant tests can load it without the scene tree; the Palette
## autoload holds one instance for the view.
class_name PaletteData
extends RefCounted

var colors: Dictionary[String, Color] = {}
var numbers: Dictionary[String, float] = {}
var missing: PackedStringArray = []


static func load_from(path: String) -> PaletteData:
	var p := PaletteData.new()
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("palette: cannot read " + path)
		return p
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("palette: not a JSON object: " + path)
		return p
	var doc: Dictionary = parsed
	var cols: Dictionary = doc.get("colors", {})
	for k: String in cols.keys():
		p.colors[k] = Color.html(str(cols[k]))
	var nums: Dictionary = doc.get("numbers", {})
	for k: String in nums.keys():
		p.numbers[k] = float(nums[k])
	return p


func col(key: String) -> Color:
	if colors.has(key):
		return colors[key]
	if not missing.has(key):
		missing.append(key)
		push_warning("palette: missing colour " + key)
	return Color.MAGENTA


func num(key: String) -> float:
	if numbers.has(key):
		return numbers[key]
	if not missing.has(key):
		missing.append(key)
		push_warning("palette: missing number " + key)
	return 0.0


## Ground colour from height and steepness: moss in the hollows, loam then dry grass as it
## rises, stone breaking through where the slope steepens. Deliberately desaturated; the colour
## interest comes from light and shadow, not pigment.
func terrain(h: float, slope: float, v: float) -> Color:
	var c: Color = col("terrain_moss")
	var dry_t: float = clampf(
		(h - num("terrain_dry_height_start")) / maxf(0.001, num("terrain_dry_height_end") - num("terrain_dry_height_start")),
		0.0, 1.0)
	c = c.lerp(col("terrain_loam"), dry_t * 0.6)
	c = c.lerp(col("terrain_dry"), dry_t * dry_t)
	var st: float = clampf(
		(slope - num("terrain_stone_slope_start")) / maxf(0.001, num("terrain_stone_slope_end") - num("terrain_stone_slope_start")),
		0.0, 1.0)
	c = c.lerp(col("terrain_stone"), st)
	return c * (1.0 - num("terrain_noise_v") * 0.5 + num("terrain_noise_v") * v)


## Relative luminance, for contrast invariants.
static func luminance(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
