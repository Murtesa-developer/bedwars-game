extends Control
# Top-down map rendered by an orthographic camera, with fighter / bed markers on top.
# Small corner map follows you; the map key (M) opens a big map of the whole world.

var player
var world
var big := false
var vp: SubViewport
var cam: Camera3D
var container: SubViewportContainer
const SMALL_SIZE := 200.0
const SMALL_VIEW := 70.0
const BIG_SIZE := 620.0
const BIG_VIEW := 150.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	container = SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	vp = SubViewport.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(vp)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = SMALL_VIEW
	cam.near = 1.0
	cam.far = 300.0
	cam.rotation_degrees = Vector3(-90, 0, 0)
	vp.add_child(cam)
	cam.current = true
	_apply_size()

func toggle_big() -> void:
	big = not big
	_apply_size()

func _apply_size() -> void:
	var px := BIG_SIZE if big else SMALL_SIZE
	size = Vector2(px, px)
	container.position = Vector2.ZERO
	container.size = size
	cam.size = BIG_VIEW if big else SMALL_VIEW
	if big:
		position = (get_viewport_rect().size - size) * 0.5
	else:
		position = Vector2(10, 64)

func _process(_d: float) -> void:
	var center: Vector3 = Vector3.ZERO if big else player.global_position
	cam.global_position = Vector3(center.x, 120.0, center.z)
	queue_redraw()

func _to_map(p: Vector3) -> Vector2:
	var c := cam.global_position
	var px := size.x
	return Vector2((p.x - c.x) / cam.size * px + px * 0.5, (p.z - c.z) / cam.size * px + px * 0.5)

func _draw() -> void:
	var px := size.x
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.9), false, 2.0)
	var main = player.main
	for t in main.teams:
		if not t["bed_alive"]:
			continue
		for c in t["bed_cells"]:
			var mp := _to_map(Vector3(c) + Vector3(0.5, 0.5, 0.5))
			if mp.x > 0.0 and mp.y > 0.0 and mp.x < px and mp.y < px:
				draw_rect(Rect2(mp - Vector2(3, 3), Vector2(6, 6)), t["color"])
				draw_rect(Rect2(mp - Vector2(3, 3), Vector2(6, 6)), Color.WHITE, false, 1.0)
	for f in get_tree().get_nodes_in_group("fighters"):
		if not f.alive:
			continue
		if f != player and f.invis_t > 0.0:
			continue
		var m := _to_map(f.global_position)
		if m.x < 0.0 or m.y < 0.0 or m.x > px or m.y > px:
			continue
		var col: Color = main.teams[f.team]["color"]
		if f == player:
			draw_circle(m, 6.0, Color.WHITE)
			draw_circle(m, 4.0, col)
			var yaw: float = player.rotation.y
			draw_line(m, m + Vector2(-sin(yaw), -cos(yaw)) * 14.0, Color.WHITE, 2.0)
		else:
			draw_circle(m, 3.5, col)
			draw_arc(m, 3.5, 0.0, TAU, 10, Color(0, 0, 0, 0.8), 1.0)
	if big:
		draw_string(ThemeDB.fallback_font, Vector2(10, 22), "MAP - press the map key to close (colored squares = beds, dots = players)", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color.WHITE)
