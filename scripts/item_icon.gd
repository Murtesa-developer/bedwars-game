extends Control
# Draws a crisp 2D icon for every item (blocks as shaded isometric cubes, tools, potions...). Scales to any size.

var type := 0
var tint := Color.WHITE

func setup(t: int, c: Color, px: float = 40.0) -> void:
	type = t
	tint = c
	custom_minimum_size = Vector2(px, px)
	size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func set_item(t: int, c: Color) -> void:
	type = t
	tint = c
	queue_redraw()

static func _shade(c: Color, f: float) -> Color:
	return Color(clampf(c.r * f, 0.0, 1.0), clampf(c.g * f, 0.0, 1.0), clampf(c.b * f, 0.0, 1.0), c.a)

func _draw() -> void:
	if type == 0:
		return
	var s := maxf(size.x, custom_minimum_size.x) / 32.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	if type >= 1 and type <= 16:
		_cube(tint)
	elif type == 20:
		_sword()
	elif type == 21:
		_axe()
	elif type == 22:
		_apple()
	elif type == 23:
		_tnt()
	elif type == 24:
		_bow()
	elif type == 25:
		_arrow()
	elif type == 26:
		_fireball()
	elif type == 27:
		_bucket()
	elif type >= 28 and type <= 31:
		_potion()

func _cube(c: Color) -> void:
	var top := PackedVector2Array([Vector2(16, 3), Vector2(29, 10), Vector2(16, 17), Vector2(3, 10)])
	var left := PackedVector2Array([Vector2(3, 10), Vector2(16, 17), Vector2(16, 30), Vector2(3, 23)])
	var right := PackedVector2Array([Vector2(16, 17), Vector2(29, 10), Vector2(29, 23), Vector2(16, 30)])
	draw_colored_polygon(top, _shade(c, 1.18))
	draw_colored_polygon(left, _shade(c, 0.86))
	draw_colored_polygon(right, _shade(c, 0.62))
	var dark := _shade(c, 0.5)
	var light := _shade(c, 1.35)
	if type == 1 or type == 16 or (type >= 7 and type <= 14):   # wool weave
		for p in [Vector2(12, 8), Vector2(18, 10), Vector2(14, 12), Vector2(21, 8)]:
			draw_rect(Rect2(p, Vector2(2, 2)), light)
		for p2 in [Vector2(6, 15), Vector2(10, 20), Vector2(7, 22)]:
			draw_rect(Rect2(p2, Vector2(2, 2)), dark)
	elif type == 2:   # stone cracks
		draw_line(Vector2(5, 14), Vector2(11, 20), dark, 1.0)
		draw_line(Vector2(11, 20), Vector2(9, 26), dark, 1.0)
		draw_line(Vector2(20, 23), Vector2(25, 18), dark, 1.0)
	elif type == 3:   # planks
		draw_line(Vector2(3, 15), Vector2(16, 22), dark, 1.0)
		draw_line(Vector2(3, 19), Vector2(16, 26), dark, 1.0)
		draw_line(Vector2(16, 22), Vector2(29, 15), dark, 1.0)
		draw_line(Vector2(16, 26), Vector2(29, 19), dark, 1.0)
	elif type == 4:   # riveted plate
		for p3 in [Vector2(5, 13), Vector2(12, 17), Vector2(5, 22), Vector2(12, 26)]:
			draw_rect(Rect2(p3, Vector2(2, 2)), light)
	var edge := _shade(c, 0.35)
	draw_polyline(PackedVector2Array([Vector2(16, 3), Vector2(29, 10), Vector2(29, 23), Vector2(16, 30), Vector2(3, 23), Vector2(3, 10), Vector2(16, 3)]), edge, 1.0)
	draw_line(Vector2(16, 17), Vector2(16, 30), edge, 1.0)
	draw_line(Vector2(3, 10), Vector2(16, 17), edge, 1.0)
	draw_line(Vector2(29, 10), Vector2(16, 17), edge, 1.0)

func _sword() -> void:
	var gold := Color(0.95, 0.75, 0.2)
	var leather := Color(0.4, 0.25, 0.12)
	draw_line(Vector2(6, 26), Vector2(26, 6), Color(0.3, 0.35, 0.45), 5.0)
	draw_line(Vector2(6, 26), Vector2(26, 6), Color(0.85, 0.9, 0.97), 3.0)
	draw_line(Vector2(9, 23), Vector2(23, 9), Color(1, 1, 1, 0.8), 1.0)
	draw_line(Vector2(26, 6), Vector2(29, 3), Color(0.85, 0.9, 0.97), 2.0)
	draw_line(Vector2(5, 20), Vector2(12, 27), gold, 3.0)
	draw_line(Vector2(5, 27), Vector2(2, 30), leather, 3.0)
	draw_circle(Vector2(2, 30), 2.0, gold)

func _axe() -> void:
	draw_line(Vector2(5, 28), Vector2(22, 11), Color(0.5, 0.33, 0.17), 3.5)
	var head := PackedVector2Array([Vector2(16, 3), Vector2(28, 8), Vector2(27, 19), Vector2(19, 15), Vector2(18, 9)])
	draw_colored_polygon(head, Color(0.62, 0.66, 0.74))
	draw_line(Vector2(28, 8), Vector2(27, 19), Color(0.95, 0.97, 1.0), 2.0)
	draw_line(Vector2(18, 6), Vector2(25, 9), Color(1, 1, 1, 0.6), 1.0)

func _apple() -> void:
	draw_circle(Vector2(16, 19), 10.0, Color(0.75, 0.55, 0.05))
	draw_circle(Vector2(16, 19), 9.0, Color(1.0, 0.84, 0.15))
	draw_circle(Vector2(12, 15), 3.0, Color(1, 1, 0.7, 0.8))
	draw_line(Vector2(16, 10), Vector2(17, 4), Color(0.35, 0.22, 0.1), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(17, 6), Vector2(24, 4), Vector2(21, 9)]), Color(0.25, 0.7, 0.25))

func _tnt() -> void:
	draw_rect(Rect2(6, 8, 20, 20), Color(0.82, 0.1, 0.1))
	draw_rect(Rect2(6, 14, 20, 8), Color(0.95, 0.95, 0.95))
	draw_rect(Rect2(6, 8, 20, 20), Color(0.35, 0.03, 0.03), false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(7, 21), "TNT", HORIZONTAL_ALIGNMENT_CENTER, 18.0, 8, Color(0.1, 0.1, 0.1))
	draw_line(Vector2(16, 8), Vector2(19, 3), Color(0.15, 0.15, 0.15), 1.5)
	draw_circle(Vector2(19, 3), 2.0, Color(1.0, 0.6, 0.1))

func _bow() -> void:
	var c := Vector2(20, 16)
	var p1 := c + Vector2.from_angle(deg_to_rad(100.0)) * 13.0
	var p2 := c + Vector2.from_angle(deg_to_rad(260.0)) * 13.0
	draw_arc(c, 13.0, deg_to_rad(100.0), deg_to_rad(260.0), 20, Color(0.5, 0.32, 0.15), 3.0)
	draw_line(p1, p2, Color(0.95, 0.95, 0.9), 1.0)
	draw_line(Vector2(9, 16), Vector2(28, 16), Color(0.6, 0.45, 0.25), 1.5)
	draw_colored_polygon(PackedVector2Array([Vector2(30, 16), Vector2(25, 13), Vector2(25, 19)]), Color(0.75, 0.78, 0.82))
	draw_line(Vector2(9, 16), Vector2(6, 13), Color(0.9, 0.9, 0.9), 1.5)
	draw_line(Vector2(9, 16), Vector2(6, 19), Color(0.9, 0.9, 0.9), 1.5)

func _arrow() -> void:
	draw_line(Vector2(6, 26), Vector2(25, 7), Color(0.6, 0.45, 0.25), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(29, 3), Vector2(22, 5), Vector2(27, 10)]), Color(0.75, 0.78, 0.82))
	draw_line(Vector2(6, 26), Vector2(3, 23), Color(0.95, 0.95, 0.95), 2.0)
	draw_line(Vector2(6, 26), Vector2(9, 29), Color(0.95, 0.95, 0.95), 2.0)
	draw_line(Vector2(9, 23), Vector2(6, 20), Color(0.95, 0.95, 0.95), 2.0)
	draw_line(Vector2(9, 23), Vector2(12, 26), Color(0.95, 0.95, 0.95), 2.0)

func _fireball() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(2, 4), Vector2(14, 10), Vector2(8, 16)]), Color(0.9, 0.25, 0.05))
	draw_colored_polygon(PackedVector2Array([Vector2(4, 12), Vector2(14, 14), Vector2(6, 20)]), Color(0.95, 0.4, 0.05))
	draw_circle(Vector2(18, 17), 11.0, Color(1.0, 0.4, 0.05))
	draw_circle(Vector2(18, 17), 8.0, Color(1.0, 0.65, 0.1))
	draw_circle(Vector2(18, 17), 4.5, Color(1.0, 0.95, 0.5))

func _bucket() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(7, 11), Vector2(25, 11), Vector2(22, 28), Vector2(10, 28)]), Color(0.6, 0.63, 0.7))
	draw_colored_polygon(PackedVector2Array([Vector2(24, 11), Vector2(25, 11), Vector2(22, 28), Vector2(20, 28)]), Color(0.45, 0.48, 0.55))
	draw_rect(Rect2(8, 11, 16, 4), Color(0.2, 0.5, 1.0))
	draw_line(Vector2(7, 11), Vector2(25, 11), Color(0.9, 0.92, 0.97), 1.5)
	draw_arc(Vector2(16, 11), 9.0, deg_to_rad(180.0), deg_to_rad(360.0), 14, Color(0.3, 0.3, 0.35), 1.5)

func _potion() -> void:
	draw_circle(Vector2(16, 21), 9.0, Color(0.2, 0.2, 0.25))
	draw_circle(Vector2(16, 21), 8.0, tint)
	draw_rect(Rect2(13, 8, 6, 8), Color(0.85, 0.9, 1.0, 0.85))
	draw_rect(Rect2(12, 4, 8, 4), Color(0.5, 0.35, 0.2))
	draw_circle(Vector2(12, 18), 2.0, Color(1, 1, 1, 0.7))
	if type == 29:   # jump: up arrow
		draw_colored_polygon(PackedVector2Array([Vector2(16, 17), Vector2(12, 23), Vector2(20, 23)]), Color(1, 1, 1, 0.9))
	elif type == 30:   # strength: plus
		draw_line(Vector2(16, 17), Vector2(16, 25), Color(1, 1, 1, 0.9), 2.0)
		draw_line(Vector2(12, 21), Vector2(20, 21), Color(1, 1, 1, 0.9), 2.0)
	elif type == 31:   # poison: droplet + dots
		draw_circle(Vector2(13, 22), 1.5, Color(1, 1, 1, 0.9))
		draw_circle(Vector2(19, 22), 1.5, Color(1, 1, 1, 0.9))
		draw_line(Vector2(16, 25), Vector2(16, 27), Color(1, 1, 1, 0.9), 1.5)
	else:   # invisibility: faint dashed ring
		draw_arc(Vector2(16, 21), 5.0, 0.0, TAU, 12, Color(1, 1, 1, 0.5), 1.0)
