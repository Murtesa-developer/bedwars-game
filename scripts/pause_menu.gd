extends CanvasLayer
# Esc toggles pause (works while the tree is paused). Resume / Settings / Restart / Quit.

const SettingsMenu = preload("res://scripts/settings_menu.gd")

var panel: PanelContainer
var dim: ColorRect
var settings: Node
var _is_open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20                       # above shop (11) and HUD so clicks land on us

	# Full-screen dim + mouse blocker. This is what actually stops clicks from
	# reaching the game world / shop / HUD while the pause menu is open.
	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.name = "Dim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	add_child(dim)

	panel = PanelContainer.new()
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)

	var buttons := [
		["Resume", _resume],
		["Settings", _open_settings],
		["Restart", _restart],
		["main menu", _main_menu]
	]
	for item in buttons:
		var b := Button.new()
		b.text = item[0]
		b.custom_minimum_size = Vector2(240, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(item[1])
		box.add_child(b)

	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.visible = false

	settings = SettingsMenu.new()
	add_child(settings)
	settings.closed.connect(_on_settings_closed)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		return
	# If another modal (settings, shop, inventory) is already handling Esc, let it.
	if settings != null and is_instance_valid(settings) and settings.has_method("is_open") and settings.is_open():
		return
	if _is_open:
		_resume()
		get_viewport().set_input_as_handled()
	elif not get_tree().paused:
		_open()
		get_viewport().set_input_as_handled()
	# If tree is paused by a *different* menu, do nothing — that menu handles Esc.

func _open() -> void:
	_is_open = true
	dim.visible = true
	panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Focus the first button so keyboard (Enter / arrows) also works.
	_focus_first_button()

func _resume() -> void:
	_is_open = false
	dim.visible = false
	panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _focus_first_button() -> void:
	for c in panel.get_children():
		if c is VBoxContainer:
			for cc in c.get_children():
				if cc is Button:
					cc.grab_focus()
					return

func _on_settings_closed() -> void:
	# Settings closed: bring the pause panel back (still paused).
	panel.visible = true
	dim.visible = true
	_is_open = true

func _open_settings() -> void:
	panel.visible = false
	dim.visible = false
	settings.show_menu()

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")
