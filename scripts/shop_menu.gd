extends CanvasLayer
# Shop (key E by default, rebindable). Tabs, item cards with icons + descriptions. Coins buy gear, emeralds buy
# potions and sword upgrades. The game is paused while it is open.
#
# Layout rules:
#  - ONE outer vertical-only ScrollContainer wraps the whole shop. Small window => scroll DOWN, never sideways.
#  - Inside a tab, the GridContainer grows naturally (no inner ScrollContainer, so it can't collapse to 0 height).
#  - The grid switches from 2 columns to 1 column if the available width is too small for two cards.

const GD = preload("res://scripts/game_data.gd")
const Sfx = preload("res://scripts/sfx.gd")
const ItemIcon = preload("res://scripts/item_icon.gd")
const ITEMS := [
	{"tab": "Blocks", "type": 1, "amount": 8, "price": 2, "cur": "coins"},
	{"tab": "Blocks", "type": 2, "amount": 8, "price": 4, "cur": "coins"},
	{"tab": "Blocks", "type": 3, "amount": 8, "price": 3, "cur": "coins"},
	{"tab": "Blocks", "type": 4, "amount": 4, "price": 8, "cur": "coins"},
	{"tab": "Combat", "type": 20, "amount": 1, "price": 10, "cur": "coins"},
	{"tab": "Combat", "type": 21, "amount": 1, "price": 6, "cur": "coins"},
	{"tab": "Combat", "type": 24, "amount": 1, "price": 12, "cur": "coins"},
	{"tab": "Combat", "type": 25, "amount": 8, "price": 4, "cur": "coins"},
	{"tab": "Combat", "type": 26, "amount": 1, "price": 10, "cur": "coins"},
	{"tab": "Combat", "type": 23, "amount": 1, "price": 6, "cur": "coins"},
	{"tab": "Utility", "type": 22, "amount": 1, "price": 5, "cur": "coins"},
	{"tab": "Utility", "type": 27, "amount": 1, "price": 8, "cur": "coins"},
	{"tab": "Potions", "type": 28, "amount": 1, "price": 2, "cur": "emeralds"},
	{"tab": "Potions", "type": 29, "amount": 1, "price": 2, "cur": "emeralds"},
	{"tab": "Potions", "type": 30, "amount": 1, "price": 3, "cur": "emeralds"},
	{"tab": "Potions", "type": 31, "amount": 1, "price": 3, "cur": "emeralds"},
]
const GOLD := Color(1.0, 0.85, 0.2)
const GREEN := Color(0.35, 1.0, 0.55)
const TWO_COL_MIN_WIDTH := 900.0   # below this, drop to 1 column so cards don't overflow

var player
var panel: PanelContainer
var coins_label: Label
var emerald_label: Label
var msg_label: Label
var tabs: TabContainer
var cards: Array = []     # [{btn, item}]
var upgrade_btn: Button
var upgrade_title: Label
var upgrade_desc: Label

var _grids: Dictionary = {}       # tab name -> GridContainer
var _tab_names: Array = ["Blocks", "Combat", "Utility", "Potions"]

func _style(bg: Color, border: Color, radius: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 11

	# Dim background
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.name = "Dim"
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# One outer vertical-only scroll for the whole shop.
	var outer_scroll := ScrollContainer.new()
	outer_scroll.name = "OuterScroll"
	outer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	outer_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(outer_scroll)

	# Shop panel inside the scroll.
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.1, 0.15, 0.97), Color(0.35, 0.55, 0.9)))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_scroll.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(box)

	# Header
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = "ITEM SHOP"
	title.add_theme_font_size_override("font_size", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	coins_label = Label.new()
	coins_label.add_theme_font_size_override("font_size", 20)
	coins_label.add_theme_color_override("font_color", GOLD)
	header.add_child(coins_label)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(24, 0)
	header.add_child(gap)
	emerald_label = Label.new()
	emerald_label.add_theme_font_size_override("font_size", 20)
	emerald_label.add_theme_color_override("font_color", GREEN)
	header.add_child(emerald_label)

	# Tabs
	tabs = TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.custom_minimum_size = Vector2(0, 360)   # ensures tabs area is visible even inside the outer scroll
	box.add_child(tabs)

	# Per tab: a plain GridContainer (NO inner ScrollContainer -> cannot collapse to 0 height).
	for tab_name in _tab_names:
		var sc := MarginContainer.new()
		sc.name = tab_name if tab_name != "Potions" else "Potions (emeralds)"
		sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.add_theme_constant_override("margin_left", 4)
		sc.add_theme_constant_override("margin_right", 4)
		sc.add_theme_constant_override("margin_top", 4)
		sc.add_theme_constant_override("margin_bottom", 4)

		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Do NOT set SIZE_EXPAND_FILL on vertical here; let the grid hug its content so rows are always drawn.
		sc.add_child(grid)
		tabs.add_child(sc)
		_grids[tab_name] = grid

	for item in ITEMS:
		_grids[item["tab"]].add_child(_card(item))
	_upgrade_card(_grids["Combat"])

	msg_label = Label.new()
	msg_label.text = " "
	msg_label.add_theme_font_size_override("font_size", 16)
	box.add_child(msg_label)

	var close := Button.new()
	close.text = "Close (shop key or Esc)"
	close.custom_minimum_size = Vector2(240, 36)
	close.pressed.connect(_close)
	box.add_child(close)

	# React to viewport size so grids drop to 1 column on narrow screens.
	get_viewport().size_changed.connect(_apply_column_count)
	_apply_column_count()

	panel.visible = false
	dim.visible = false

func _apply_column_count() -> void:
	var vw := float(get_viewport().get_visible_rect().size.x)
	var cols := 1 if vw < TWO_COL_MIN_WIDTH else 2
	for tab_name in _tab_names:
		var g: GridContainer = _grids.get(tab_name)
		if g != null:
			g.columns = cols

func _card(item: Dictionary) -> Control:
	var type: int = item["type"]
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", _style(Color(0.13, 0.16, 0.22), Color(0.25, 0.3, 0.4), 6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	pc.add_child(row)
	var icon := ItemIcon.new()
	icon.setup(type, player.item_color(type), 56.0)
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var nm := Label.new()
	var txt: String = GD.NAMES[type]
	if item["amount"] > 1:
		txt += " x%d" % item["amount"]
	nm.text = txt
	nm.add_theme_font_size_override("font_size", 18)
	col.add_child(nm)
	var ds := Label.new()
	ds.text = GD.DESC[type]
	ds.add_theme_font_size_override("font_size", 12)
	ds.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(ds)
	var pr := Label.new()
	pr.text = "%d %s" % [item["price"], item["cur"]]
	pr.add_theme_color_override("font_color", GOLD if item["cur"] == "coins" else GREEN)
	col.add_child(pr)
	var b := Button.new()
	b.text = "Buy"
	b.custom_minimum_size = Vector2(84, 40)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(_buy.bind(item))
	row.add_child(b)
	cards.append({"btn": b, "item": item})
	return pc

func _upgrade_card(grid: GridContainer) -> void:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", _style(Color(0.13, 0.2, 0.17), Color(0.25, 0.5, 0.35), 6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	pc.add_child(row)
	var icon := ItemIcon.new()
	icon.setup(20, Color.WHITE, 56.0)
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	upgrade_title = Label.new()
	upgrade_title.add_theme_font_size_override("font_size", 18)
	col.add_child(upgrade_title)
	upgrade_desc = Label.new()
	upgrade_desc.add_theme_font_size_override("font_size", 12)
	upgrade_desc.add_theme_color_override("font_color", GREEN)
	upgrade_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upgrade_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(upgrade_desc)
	upgrade_btn = Button.new()
	upgrade_btn.text = "Upgrade"
	upgrade_btn.custom_minimum_size = Vector2(84, 40)
	upgrade_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	upgrade_btn.pressed.connect(_upgrade)
	row.add_child(upgrade_btn)
	grid.add_child(pc)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.is_action_pressed("shop"):
		if panel.visible:
			_close()
		elif not get_tree().paused:
			_open()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and panel.visible:
		_close()
		get_viewport().set_input_as_handled()

func _open() -> void:
	panel.visible = true
	get_node("Dim").visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	msg_label.text = "Hover the cards to read what each item does."
	_apply_column_count()
	_refresh()

func _close() -> void:
	panel.visible = false
	get_node("Dim").visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _wallet(cur: String) -> int:
	return player.coins if cur == "coins" else player.emeralds

func _refresh() -> void:
	coins_label.text = "Coins: %d" % player.coins
	emerald_label.text = "Emeralds: %d" % player.emeralds
	for c in cards:
		var item: Dictionary = c["item"]
		var b: Button = c["btn"]
		if GD.STACK[item["type"]] == 1 and player.has_item(item["type"]):
			b.text = "Owned"
			b.disabled = true
		else:
			b.text = "Buy"
			b.disabled = _wallet(item["cur"]) < item["price"]
	var lvl: int = player.sword_level
	if not player.has_item(20):
		upgrade_title.text = "Sword upgrade"
		upgrade_desc.text = "Buy a sword first (Combat tab)."
		upgrade_btn.disabled = true
	elif lvl >= GD.SWORD_UPGRADE_COST.size():
		upgrade_title.text = "Sword fully upgraded"
		upgrade_desc.text = "Damage %d" % int(GD.SWORD_BASE + lvl)
		upgrade_btn.disabled = true
	else:
		upgrade_title.text = "Upgrade sword to damage %d" % int(GD.SWORD_BASE + lvl + 1)
		upgrade_desc.text = "%d emeralds (emeralds drop on top of the middle tower)" % GD.SWORD_UPGRADE_COST[lvl]
		upgrade_btn.disabled = player.emeralds < GD.SWORD_UPGRADE_COST[lvl]

func _buy(item: Dictionary) -> void:
	var type: int = item["type"]
	var item_name: String = GD.NAMES[type]
	if GD.STACK[type] == 1 and player.has_item(type):
		msg_label.text = "You already have a %s" % item_name
	elif _wallet(item["cur"]) < item["price"]:
		msg_label.text = "Not enough %s!" % item["cur"]
	elif player.space_for(type) < item["amount"]:
		msg_label.text = "Inventory full!"
	else:
		if item["cur"] == "coins":
			player.spend_coins(item["price"])
		else:
			player.emeralds -= item["price"]
		player.add_item(type, item["amount"])
		msg_label.text = "Bought %s" % item_name
		Sfx.play2d(self, "click")
	_refresh()

func _upgrade() -> void:
	var lvl: int = player.sword_level
	if lvl >= GD.SWORD_UPGRADE_COST.size() or not player.has_item(20):
		return
	var cost: int = GD.SWORD_UPGRADE_COST[lvl]
	if player.emeralds < cost:
		msg_label.text = "Not enough emeralds!"
	else:
		player.emeralds -= cost
		player.sword_level += 1
		player.refresh_hud()
		msg_label.text = "Sword upgraded! Damage %d" % int(GD.SWORD_BASE + player.sword_level)
		Sfx.play2d(self, "emerald")
	_refresh()
