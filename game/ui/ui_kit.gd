## Shared UI construction: one glass style, one type register, plain names. Interface words are
## machinery and say what they are; invented names belong to content, never to a button.
class_name UiKit
extends RefCounted


static func glass(pal: PaletteData, alpha: float = -1.0, radius: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var c: Color = pal.col("hud_glass")
	c.a = pal.num("hud_glass_alpha") if alpha < 0.0 else alpha
	sb.bg_color = c
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	sb.border_width_bottom = 1
	sb.border_width_top = 1
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_color = Color(1.0, 1.0, 1.0, 0.07)
	return sb


static func panel(pal: PaletteData, alpha: float = -1.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", glass(pal, alpha))
	return p


static func label(pal: PaletteData, text: String, size: int = 15, dim: float = 1.0, upper: bool = false) -> Label:
	var l := Label.new()
	l.text = text.to_upper() if upper else text
	l.add_theme_font_size_override("font_size", size)
	var c: Color = pal.col("hud_ink")
	c.a = dim
	l.add_theme_color_override("font_color", c)
	return l


static func button(pal: PaletteData, text: String, size: int = 16) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", pal.col("hud_ink"))
	b.add_theme_color_override("font_hover_color", pal.col("hud_accent"))
	b.add_theme_color_override("font_pressed_color", pal.col("hud_accent"))
	b.add_theme_color_override("font_focus_color", pal.col("hud_accent"))
	var normal := glass(pal, 0.55, 4)
	b.add_theme_stylebox_override("normal", normal)
	var hover := glass(pal, 0.75, 4)
	hover.border_color = pal.col("hud_accent")
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.custom_minimum_size = Vector2(240.0, 44.0)
	b.focus_mode = Control.FOCUS_ALL
	return b


static func bar(pal: PaletteData, fill: Color, height: float = 8.0) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(200.0, height)
	pb.max_value = 1.0
	pb.value = 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	pb.add_theme_stylebox_override("background", bg)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.corner_radius_top_left = 3
	fg.corner_radius_top_right = 3
	fg.corner_radius_bottom_left = 3
	fg.corner_radius_bottom_right = 3
	pb.add_theme_stylebox_override("fill", fg)
	return pb


static func spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, h)
	return c


static func clock_text(c: Clock) -> String:
	if c.is_night():
		var left: float = c.night_seconds - (c.time - c.day_seconds)
		return "NIGHT · dawn in %d:%02d" % [int(left) / 60, int(left) % 60]
	var t: float = c.sun_t()
	var word: String = "DAWN" if t < 0.15 else ("MORNING" if t < 0.4 else ("NOON" if t < 0.6 else ("AFTERNOON" if t < 0.85 else "DUSK")))
	var left: float = c.seconds_to_dusk()
	return "%s · dusk in %d:%02d" % [word, int(left) / 60, int(left) % 60]


static func ago(unix: int) -> String:
	var d: int = int(Time.get_unix_time_from_system()) - unix
	if d < 90:
		return "just now"
	if d < 3600:
		return "%d min ago" % (d / 60)
	if d < 86400:
		return "%d h ago" % (d / 3600)
	return "%d d ago" % (d / 86400)
