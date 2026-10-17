extends CanvasLayer
# Settings: mouse sensitivity, volumes, fullscreen, and rebindable keys. Saved to user://settings.cfg.

const Settings = preload("res://scripts/settings.gd")
const Sfx = preload("res://scripts/sfx.gd")
signal closed
var panel: PanelContainer
var key_buttons := {}
var waiting := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 13
	panel = PanelContainer.new()
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_slider(box, "Mouse sensitivity", 0.0005, 0.008, 0.0001, Settings.sensitivity, _on_sens)
	_slider(box, "Master volume", 0.0, 1.0, 0.05, Settings.master_vol, _on_master)
	_slider(box, "Music volume", 0.0, 1.0, 0.05, Settings.music_vol, _on_music)
	var fs := CheckButton.new()
	fs.text = "Fullscreen"
	fs.button_pressed = Settings.fullscreen
	fs.toggled.connect(_on_fullscreen)
	box.add_child(fs)
	var ff := CheckButton.new()
	ff.text = "Friendly fire (hurt your own teammates)"
	ff.button_pressed = Settings.friendly_fire
	ff.toggled.connect(_on_friendly_fire)
	box.add_child(ff)
	var ctl := Label.new()
	ctl.text = "Controls (click, then press a key)"
	box.add_child(ctl)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(520, 230)
	box.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 2
	sc.add_child(grid)
	for a in Settings.ACTIONS:
		var l := Label.new()
		l.text = a[1]
		l.custom_minimum_size = Vector2(240, 0)
		grid.add_child(l)
		var b := Button.new()
		b.custom_minimum_size = Vector2(160, 30)
		b.pressed.connect(_start_rebind.bind(a[0]))
		grid.add_child(b)
		key_buttons[a[0]] = b
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(200, 40)
	back.pressed.connect(hide_menu)
	box.add_child(back)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.visible = false
	_refresh_keys()

func _on_sens(v: float) -> void:
	Settings.sensitivity = v

func _on_master(v: float) -> void:
	Settings.master_vol = v
	Settings.apply()

func _on_music(v: float) -> void:
	Settings.music_vol = v
	Sfx.update_music_volume()

func _on_friendly_fire(on: bool) -> void:
	Settings.friendly_fire = on

func _on_fullscreen(on: bool) -> void:
	Settings.fullscreen = on
	Settings.apply()

func _slider(parent: Control, text: String, lo: float, hi: float, step: float, value: float, cb: Callable) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(240, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(240, 24)
	s.value_changed.connect(cb)
	row.add_child(s)
	parent.add_child(row)

func _refresh_keys() -> void:
	for a in Settings.ACTIONS:
		var b: Button = key_buttons[a[0]]
		b.text = "press a key..." if waiting == a[0] else OS.get_keycode_string(Settings.keys[a[0]])

func _start_rebind(action: String) -> void:
	waiting = action
	_refresh_keys()

func show_menu() -> void:
	panel.visible = true
	waiting = ""
	_refresh_keys()

func hide_menu() -> void:
	panel.visible = false
	waiting = ""
	Settings.save_settings()
	closed.emit()

func _input(event: InputEvent) -> void:
	if not panel.visible or waiting == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode != KEY_ESCAPE:
			var new_key: int = event.physical_keycode
			for a in Settings.ACTIONS:   # swap if another action already uses this key
				if a[0] != waiting and Settings.keys[a[0]] == new_key:
					Settings.keys[a[0]] = Settings.keys[waiting]
			Settings.keys[waiting] = new_key
			Settings.apply()
		waiting = ""
		_refresh_keys()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if panel.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		hide_menu()
		get_viewport().set_input_as_handled()
