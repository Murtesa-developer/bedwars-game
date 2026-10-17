extends CanvasLayer
# Hotbar manager (key B by default, rebindable): click one slot, then another, to swap them.
# Shows an icon, name and count for every slot, a description of the picked item and your active effects.

const GD = preload("res://scripts/game_data.gd")
const ItemIcon = preload("res://scripts/item_icon.gd")
var player
var panel: PanelContainer
var slots: Array = []     # [{btn, icon, name, count}]
var first := -1
var info: Label
var equip: Label

func _style(bg: Color, border: Color, bw: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 12
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.name = "Dim"
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.1, 0.15, 0.97), Color(0.35, 0.55, 0.9)))
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "HOTBAR"
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Click a slot, then another slot to swap them. Close with the hotbar key or Esc."
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	box.add_child(sub)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for i in 9:
		var b := Button.new()
		b.custom_minimum_size = Vector2(98, 124)
		b.pressed.connect(_on_slot.bind(i))
		b.mouse_entered.connect(_hover.bind(i))
		row.add_child(b)
		var num := Label.new()
		num.text = str(i + 1)
		num.position = Vector2(6, 2)
		num.add_theme_font_size_override("font_size", 12)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(num)
		var icon := ItemIcon.new()
		icon.setup(0, Color.WHITE, 52.0)
		icon.position = Vector2(23, 16)
		b.add_child(icon)
		var nm := Label.new()
		nm.position = Vector2(2, 74)
		nm.size = Vector2(94, 20)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_font_size_override("font_size", 12)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(nm)
		var cnt := Label.new()
		cnt.position = Vector2(2, 100)
		cnt.size = Vector2(94, 20)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cnt.add_theme_font_size_override("font_size", 14)
		cnt.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
		cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(cnt)
		slots.append({"btn": b, "icon": icon, "name": nm, "count": cnt})
	info = Label.new()
	info.add_theme_font_size_override("font_size", 15)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(880, 44)
	box.add_child(info)
	equip = Label.new()
	equip.add_theme_font_size_override("font_size", 14)
	equip.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	equip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(equip)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.visible = false
	dim.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.is_action_pressed("inventory"):
		if panel.visible:
			_close()
		elif not get_tree().paused:
			_open()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and panel.visible:
		_close()
		get_viewport().set_input_as_handled()

func _open() -> void:
	first = -1
	panel.visible = true
	get_node("Dim").visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()

func _close() -> void:
	panel.visible = false
	get_node("Dim").visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_slot(i: int) -> void:
	if first < 0:
		first = i
	else:
		if first != i:
			player.swap_slots(first, i)
		first = -1
	_refresh()

func _hover(i: int) -> void:
	var t: int = player.slot_types[i]
	if t != 0:
		info.text = "%s: %s" % [GD.NAMES[t], GD.DESC[t]]

func _refresh() -> void:
	for i in 9:
		var t: int = player.slot_types[i]
		var s: Dictionary = slots[i]
		s["icon"].set_item(t, player.item_color(t) if t != 0 else Color.WHITE)
		s["name"].text = GD.NAMES[t] if t != 0 else ""
		s["count"].text = ("x%d" % player.slot_counts[i]) if (t != 0 and GD.STACK[t] > 1) else ""
		var picked := i == first
		var sb := _style(Color(0.35, 0.3, 0.1) if picked else Color(0.14, 0.17, 0.23), Color(1, 0.9, 0.3) if picked else Color(0.3, 0.36, 0.5), 3 if picked else 2)
		s["btn"].add_theme_stylebox_override("normal", sb)
		s["btn"].add_theme_stylebox_override("hover", _style(Color(0.2, 0.24, 0.32), Color(0.6, 0.75, 1.0)))
		s["btn"].add_theme_stylebox_override("pressed", sb)
	if first >= 0:
		info.text = "Slot %d picked. Click another slot to swap." % (first + 1)
	var lines := []
	if player.has_item(20):
		lines.append("Sword damage %d" % int(GD.SWORD_BASE + player.sword_level))
	var fx: String = player.effects_text()
	if fx != "":
		lines.append("Active effects: " + fx)
	lines.append("Coins %d   Emeralds %d" % [player.coins, player.emeralds])
	equip.text = "   |   ".join(lines)
