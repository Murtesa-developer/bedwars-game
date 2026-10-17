extends Control
# Lobby / main menu with logo, drifting clouds, floating islands, styled buttons, tips and a How to Play panel.
# "PLAY" loads the match (loading bar), then the world is built behind a second loading screen.

const Settings = preload("res://scripts/settings.gd")
const Sfx = preload("res://scripts/sfx.gd")
const SettingsMenu = preload("res://scripts/settings_menu.gd")
const ItemIcon = preload("res://scripts/item_icon.gd")
const GAME_SCENE := "res://scenes/main.tscn"
const LOGO_PATH := "res://assets/logo.png"
const GAME_VERSION := "1.0.0"
const TEAM_COLORS := [Color(0.90, 0.15, 0.15), Color(0.20, 0.75, 0.25), Color(0.20, 0.35, 0.90), Color(0.95, 0.80, 0.15),
	Color(1.00, 0.55, 0.10), Color(0.60, 0.25, 0.80), Color(0.10, 0.80, 0.85), Color(1.00, 0.50, 0.70)]
const TIPS := [
	"Protect your bed first - then go break theirs.",
	"Reinforced blocks survive TNT. Great for guarding your bed.",
	"Hold the bow string longer for faster, stronger arrows.",
	"Emeralds from the middle tower buy sword upgrades and potions.",
	"Land in a water bucket to take no fall damage.",
	"Your 3 bot teammates defend and raid with you.",
	"Dying deletes everything on your hotbar - spend your coins!",
	"Press M to open the big map of the world.",
]
const PRIVACY_TEXT := "Effective date: 17 October 2026\nDeveloper contact: murtesa.developer@proton.me\n\nSUMMARY\nBedWars is an offline game. It does not collect, send, sell or share any personal information.\n\nINFORMATION WE COLLECT\nNone. The game does not ask you to create an account, and does not ask for your name, email, location or any other personal data. It contains no advertising, analytics, tracking or crash-reporting tools.\n\nDATA STORED ON YOUR DEVICE\nThe game saves only your game settings (mouse sensitivity, volume, fullscreen option and key bindings) in a small local file named settings.cfg in the game's own user data folder on your PC. This file stays on your device and is never uploaded. It is removed when you uninstall the game.\n\nINTERNET AND THIRD PARTIES\nBedWars does not connect to the internet and does not use any third-party services. Because no data leaves your device, no data is shared with third parties.\n\nPERMISSIONS\nThe game runs as a desktop app on Windows 10 and Windows 11. It does not access your camera, microphone, contacts, location, or files outside its own data folder.\n\nCHILDREN\nThe game does not knowingly collect information from anyone, including children under 13. It has cartoon-style block combat with no gore.\n\nMICROSOFT STORE\nDownloading the game through the Microsoft Store is covered by Microsoft's own privacy statement. Microsoft, not the developer, handles purchase and download information.\n\nCHANGES TO THIS POLICY\nIf the game ever adds online features, this policy will be updated before that version is released, and the effective date above will change.\n\nCONTACT\nQuestions about this policy: murtesa.developer@proton.me"
const HELP_TEXT := "GOAL\nBreak enemy beds, then eliminate every fighter. Keep your own bed safe!\n\nCONTROLS\nWASD move  |  Space jump  |  Shift sneak  |  Ctrl sprint\nLeft click attack / break  |  Right click place / use\n1-9 or mouse wheel: hotbar  |  Q drop  |  E shop  |  B hotbar manager\nM map  |  Esc pause and settings\n\nMATCH\n8 teams of 4. You and 3 bots form one team.\nGenerators drop coins on your island and emeralds in the middle."

var menu_box: VBoxContainer
var loading_box: VBoxContainer
var bar: ProgressBar
var status: Label
var tip_label: Label
var help_panel: PanelContainer
var privacy_panel: PanelContainer
var settings
var loading := false
var load_t := 0.0
var anim_t := 0.0
var tip_i := 0
var tip_t := 0.0
var clouds: Array = []     # {node, speed, fy}
var islands: Array = []    # {node, fx, fy, phase}
var bed_icons: Array = []
var logo_tex: Texture2D = null

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _rect(parent: Control, x: float, y: float, w: float, h: float, c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.position = Vector2(x, y)
	r.size = Vector2(w, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r

func _box(bg: Color, border: Color, bottom: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.border_width_bottom = bottom
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0 + float(bottom) * 0.5
	return sb

func _style_button(b: Button, base: Color, font_size: int) -> void:
	b.add_theme_stylebox_override("normal", _box(base, base.darkened(0.5)))
	b.add_theme_stylebox_override("hover", _box(base.lightened(0.18), base.darkened(0.35)))
	b.add_theme_stylebox_override("pressed", _box(base.darkened(0.15), base.darkened(0.5), 2))
	b.add_theme_stylebox_override("focus", _box(base.lightened(0.1), Color.WHITE))
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	b.add_theme_constant_override("outline_size", 6)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _make_button(text: String, base: Color, size: Vector2, font_size: int, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	_style_button(b, base, font_size)
	b.pressed.connect(cb)
	return b

func _logo_rect(h: float) -> Control:
	if logo_tex != null:
		var tr := TextureRect.new()
		tr.texture = logo_tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(h, h)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	return _label("BEDWARS", int(h * 0.3), Color.WHITE)

func _make_island(cols: int, team: Color) -> Control:
	var u := 14.0
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = Vector2(cols * u, 8 * u)
	var grass := Color(0.35, 0.68, 0.2)
	_rect(root, 0, 4 * u, cols * u, u, grass)
	_rect(root, 0, 4 * u + u * 0.7, cols * u, u * 0.3, grass.darkened(0.15))
	for r in range(1, 5):
		var n: int = maxi(cols - 2 * r, 1)
		var c := Color(0.45, 0.31, 0.18) if r <= 2 else Color(0.45, 0.47, 0.52).darkened(0.08 * float(r - 2))
		_rect(root, r * u, (4 + r) * u, n * u, u, c)
	# little castle
	var cw: int = maxi(cols / 2, 3)
	var cx := (cols - cw) * u * 0.5
	var stone := Color(0.55, 0.57, 0.6)
	_rect(root, cx, 2 * u, cw * u, 2 * u, stone)
	for i in range(0, cw, 2):
		_rect(root, cx + i * u, 1.4 * u, u, 0.7 * u, stone.darkened(0.1))
	_rect(root, cx + (cw * u - u * 1.2) * 0.5, 2.8 * u, u * 1.2, 1.2 * u, Color(0.12, 0.12, 0.15))
	_rect(root, cx + cw * u * 0.5 - 1.5, 0, 3, 1.5 * u, Color(0.25, 0.18, 0.12))
	_rect(root, cx + cw * u * 0.5 + 1.5, 0, u * 1.2, u * 0.8, team)
	return root

func _make_cloud(w: float) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := Color(1, 1, 1, 0.82)
	_rect(root, 0, 16, w, 18, c)
	_rect(root, w * 0.15, 4, w * 0.5, 14, c)
	_rect(root, w * 0.55, 10, w * 0.3, 10, Color(1, 1, 1, 0.7))
	root.size = Vector2(w, 36)
	return root

func _ready() -> void:
	Settings.load_settings()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(LOGO_PATH):
		logo_tex = load(LOGO_PATH)

	# sky gradient
	var grad := Gradient.new()
	grad.set_color(0, Color(0.17, 0.45, 0.88))
	grad.set_color(1, Color(0.70, 0.88, 1.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 256
	var sky := TextureRect.new()
	sky.texture = gt
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# clouds
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 7:
		var cl := _make_cloud(rng.randf_range(110.0, 220.0))
		add_child(cl)
		clouds.append({"node": cl, "speed": rng.randf_range(10.0, 28.0), "fy": rng.randf_range(0.04, 0.55), "x": rng.randf_range(0.0, 1400.0)})

	# floating islands
	var defs := [[0.11, 0.30, 9, 0], [0.89, 0.27, 9, 2], [0.24, 0.62, 7, 3], [0.77, 0.60, 7, 1]]
	for k in defs.size():
		var d: Array = defs[k]
		var isl := _make_island(d[2], TEAM_COLORS[d[3]])
		add_child(isl)
		islands.append({"node": isl, "fx": d[0], "fy": d[1], "phase": float(k) * 1.7})

	# ground and beds
	var grass_strip := ColorRect.new()
	grass_strip.color = Color(0.35, 0.68, 0.2)
	grass_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grass_strip)
	grass_strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	grass_strip.offset_top = -130.0
	grass_strip.offset_bottom = -108.0
	var dirt := ColorRect.new()
	dirt.color = Color(0.40, 0.28, 0.17)
	dirt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dirt)
	dirt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dirt.offset_top = -108.0
	var beds := HBoxContainer.new()
	beds.add_theme_constant_override("separation", 14)
	beds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(beds)
	for i in TEAM_COLORS.size():
		var ic := ItemIcon.new()
		ic.setup(7 + i, TEAM_COLORS[i], 72.0)
		ic.pivot_offset = Vector2(36, 72)
		beds.add_child(ic)
		bed_icons.append(ic)
	beds.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	beds.grow_horizontal = Control.GROW_DIRECTION_BOTH
	beds.grow_vertical = Control.GROW_DIRECTION_BEGIN
	beds.offset_bottom = -26.0

	# main menu
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 10)
	add_child(menu_box)
	var logo := _logo_rect(250.0)
	menu_box.add_child(logo)
	if logo_tex != null:
		logo.resized.connect(func(): logo.pivot_offset = logo.size * 0.5)
		var tw := logo.create_tween().set_loops()
		tw.tween_property(logo, "scale", Vector2(1.04, 1.04), 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(logo, "scale", Vector2(1.0, 1.0), 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	menu_box.add_child(_label("Protect your bed. Destroy theirs. Be the last team standing.", 18, Color(1, 1, 0.9)))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	menu_box.add_child(gap)
	menu_box.add_child(_make_button("PLAY", Color(0.25, 0.65, 0.22), Vector2(340, 62), 30, _start))
	menu_box.add_child(_make_button("How to Play", Color(0.85, 0.6, 0.15), Vector2(340, 42), 20, _toggle_help))
	menu_box.add_child(_make_button("Settings", Color(0.2, 0.45, 0.85), Vector2(340, 42), 20, _open_settings))
	menu_box.add_child(_make_button("Privacy Policy", Color(0.35, 0.4, 0.5), Vector2(340, 34), 16, _toggle_privacy))
	menu_box.add_child(_make_button("Quit", Color(0.75, 0.22, 0.22), Vector2(340, 42), 20, _quit))
	menu_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	menu_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	menu_box.offset_top -= 14.0

	# tips + version
	tip_label = _label(TIPS[0], 17, Color(1, 1, 1))
	add_child(tip_label)
	tip_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	tip_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tip_label.offset_top = 14.0
	var ver := _label("v" + GAME_VERSION, 14, Color(1, 1, 1, 0.8))
	ver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ver)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ver.offset_right = -12.0
	ver.offset_bottom = -6.0

	# loading screen
	loading_box = VBoxContainer.new()
	loading_box.add_theme_constant_override("separation", 14)
	loading_box.visible = false
	add_child(loading_box)
	loading_box.add_child(_logo_rect(220.0))
	loading_box.add_child(_label("Loading...", 40, Color.WHITE))
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(520, 26)
	bar.max_value = 100.0
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.3, 0.8, 0.25)
	fill.set_corner_radius_all(5)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.05, 0.1, 0.2, 0.85)
	back.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	loading_box.add_child(bar)
	status = _label("Getting the match ready", 18, Color.WHITE)
	loading_box.add_child(status)
	loading_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	loading_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	loading_box.grow_vertical = Control.GROW_DIRECTION_BOTH

	_build_help()
	settings = SettingsMenu.new()
	add_child(settings)
	settings.closed.connect(_on_settings_closed)
	Sfx.start_music(self)

func _build_panel(title: String, body: String, toggle: Callable) -> PanelContainer:
	var p := PanelContainer.new()
	p.visible = false
	var sb := _box(Color(0.06, 0.1, 0.2, 0.94), Color(0.3, 0.7, 1.0), 4)
	sb.content_margin_left = 28.0
	sb.content_margin_right = 28.0
	sb.content_margin_top = 22.0
	sb.content_margin_bottom = 22.0
	p.add_theme_stylebox_override("panel", sb)
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	v.add_child(_label(title, 30, Color(1, 0.9, 0.4)))
	var t := Label.new()
	t.text = body
	t.add_theme_font_size_override("font_size", 17)
	t.custom_minimum_size = Vector2(620, 0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(640, 380 if body.length() > 900 else 0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_child(t)
	v.add_child(sc)
	v.add_child(_make_button("Close", Color(0.2, 0.45, 0.85), Vector2(200, 42), 20, toggle))
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	return p

func _build_help() -> void:
	help_panel = _build_panel("HOW TO PLAY", HELP_TEXT, _toggle_help)
	privacy_panel = _build_panel("PRIVACY POLICY", PRIVACY_TEXT, _toggle_privacy)

func _toggle_privacy() -> void:
	Sfx.play2d(self, "click")
	privacy_panel.visible = not privacy_panel.visible
	menu_box.visible = not privacy_panel.visible

func _toggle_help() -> void:
	Sfx.play2d(self, "click")
	help_panel.visible = not help_panel.visible
	menu_box.visible = not help_panel.visible

func _quit() -> void:
	get_tree().quit()

func _open_settings() -> void:
	Sfx.play2d(self, "click")
	menu_box.visible = false
	settings.show_menu()

func _on_settings_closed() -> void:
	menu_box.visible = true

func _start() -> void:
	if loading:
		return
	loading = true
	load_t = 0.0
	Sfx.play2d(self, "click")
	menu_box.visible = false
	help_panel.visible = false
	privacy_panel.visible = false
	tip_label.visible = false
	loading_box.visible = true
	ResourceLoader.load_threaded_request(GAME_SCENE)

func _animate(delta: float) -> void:
	anim_t += delta
	var vp := get_viewport_rect().size
	for c in clouds:
		var n: Control = c["node"]
		c["x"] += float(c["speed"]) * delta
		if c["x"] > vp.x + 20.0:
			c["x"] = -n.size.x
		n.position = Vector2(c["x"], vp.y * float(c["fy"]))
	for isl in islands:
		var n2: Control = isl["node"]
		n2.position = Vector2(vp.x * float(isl["fx"]) - n2.size.x * 0.5, vp.y * float(isl["fy"]) + sin(anim_t * 1.1 + float(isl["phase"])) * 9.0)
	for i in bed_icons.size():
		bed_icons[i].rotation = sin(anim_t * 2.0 + float(i) * 0.7) * 0.07
	if tip_label != null and tip_label.visible:
		tip_t += delta
		if tip_t > 4.5:
			tip_t = 0.0
			tip_i = (tip_i + 1) % TIPS.size()
			tip_label.text = TIPS[tip_i]
			tip_label.modulate.a = 0.0
			create_tween().tween_property(tip_label, "modulate:a", 1.0, 0.5)

func _process(delta: float) -> void:
	_animate(delta)
	if not loading:
		return
	load_t += delta
	var prog := []
	var st := ResourceLoader.load_threaded_get_status(GAME_SCENE, prog)
	if prog.size() > 0:
		bar.value = minf(float(prog[0]) * 100.0, load_t * 160.0)
	if st == ResourceLoader.THREAD_LOAD_LOADED and load_t > 0.7:
		loading = false
		bar.value = 100.0
		var ps: PackedScene = ResourceLoader.load_threaded_get(GAME_SCENE)
		get_tree().change_scene_to_packed(ps)
	elif st == ResourceLoader.THREAD_LOAD_FAILED:
		loading = false
		status.text = "Could not load the game scene"
		loading_box.visible = false
		menu_box.visible = true
		tip_label.visible = true
