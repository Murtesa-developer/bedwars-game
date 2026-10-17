extends CharacterBody3D
# First-person player: move, sneak, sprint, 9-slot hotbar (64 per stack), build / break, sword / axe / bow /
# TNT / fireball / golden apple, health + hunger, fall damage, sounds. Match rules live in main.gd.

const GD = preload("res://scripts/game_data.gd")
const Settings = preload("res://scripts/settings.gd")
const Sfx = preload("res://scripts/sfx.gd")
const ItemModels = preload("res://scripts/item_models.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const ArrowScript = preload("res://scripts/arrow.gd")
const FireballScript = preload("res://scripts/fireball.gd")
const TntScript = preload("res://scripts/tnt.gd")
const ItemIcon = preload("res://scripts/item_icon.gd")
const Minimap = preload("res://scripts/minimap.gd")
const SLOTS := 9
const REACH := 5.0
const ATTACK_REACH := 3.2
const HAND_POSE := {
	20: [Vector3(0.0, 0.02, -0.22), Vector3(55, 0, 0)],
	21: [Vector3(0.0, 0.0, -0.22), Vector3(40, 0, 0)],
	22: [Vector3(0.0, 0.0, -0.25), Vector3.ZERO],
	23: [Vector3(0.0, 0.0, -0.25), Vector3.ZERO],
	24: [Vector3(-0.03, 0.05, -0.3), Vector3.ZERO],
	25: [Vector3(0.0, 0.0, -0.3), Vector3(70, 0, 0)],
	26: [Vector3(0.0, 0.0, -0.3), Vector3.ZERO],
}

var world
var main
var team := 0
var home := Vector3.ZERO
var alive := true
var hp := 10.0
var hunger := 10.0
var hunger_t := 0.0
var starve_t := 0.0
var regen_t := 0.0
var flash := 0.0
var notif_t := 0.0
var warn_cd := 0.0
var last_attacker = null
var knock_t := 0.0
var peak_y := 0.0
var was_floor := true
var attack_cd := 0.0
var attack_anim := 0.0
var place_anim := 0.0
var place_cd := 0.0
var bow_cd := 0.0
var fb_cd := 0.0
var bob_t := 0.0
var step_acc := 0.0
var play_time := 0.0
var drawing := false
var draw_t := 0.0
var invis_t := 0.0
var jump_t := 0.0
var strength_t := 0.0
var poison_weapon_t := 0.0
var poison_t := 0.0
var poison_tick := 0.0
var water_t := 0.0
var bucket_cd := 0.0
var axe_charge := 0.0
var effects_label: Label
var charge_bar: ProgressBar
var aim_node: Node3D
var aim_dots: Array = []
var aim_marker: MeshInstance3D
var aim_marker_mat: StandardMaterial3D
var minimap
var col_shape: CollisionShape3D
var head: Node3D
var cam: Camera3D
var preview: MeshInstance3D
var preview_mat: StandardMaterial3D
var hand_pivot: Node3D
var held_type := -1
var held_model: Node3D = null
var bow_string: Node3D = null
var bow_arrow: Node3D = null
var flash_rect: ColorRect
var item_title: Label
var hp_bar: ProgressBar
var hunger_bar: ProgressBar
var hp_text: Label
var hunger_text: Label
var notif_label: Label
var coin_label: Label
var emerald_label: Label
var team_label: Label
var right_box: VBoxContainer
var team_rows: Array = []
var slot_types: Array = []
var slot_counts: Array = []
var slot_icons: Array = []
var slot_labels: Array = []
var slot_styles: Array = []
var selected := 0
var coins := 5
var emeralds := 0
var sword_level := 0
var sneaking := false
var has_break_target := false
var break_target := Vector3i.ZERO
var break_progress := 0.0

# Coin drop interval for the house dispensers: 3.0s, minus 0.1s every 5 minutes of play (min 0.5s).
func coin_interval() -> float:
	return maxf(0.5, 3.0 - 0.1 * floorf(play_time / 300.0))

func _ready() -> void:
	add_to_group("collectors")
	add_to_group("fighters")
	floor_max_angle = deg_to_rad(60.0)  # rounded capsule bottom stays 'on floor' while hanging over an edge
	collision_layer = 2   # fighters don't block each other, they only collide with the world
	collision_mask = 1
	col_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.8
	col_shape.shape = cap
	col_shape.position.y = 0.9
	add_child(col_shape)
	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 75.0
	head.add_child(cam)
	cam.current = true

	hand_pivot = Node3D.new()
	hand_pivot.position = Vector3(0.3, -0.3, -0.5)
	cam.add_child(hand_pivot)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.95, 0.75, 0.6)
	var arm := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(0.12, 0.12, 0.45)
	arm.mesh = am
	arm.material_override = skin
	arm.position = Vector3(0.05, -0.1, 0.1)
	hand_pivot.add_child(arm)

	preview_mat = StandardMaterial3D.new()
	preview_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	preview_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	preview_mat.albedo_color = Color(0.2, 1, 0.2, 0.35)
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 1.01
	preview = MeshInstance3D.new()
	preview.mesh = bm
	preview.material_override = preview_mat
	preview.top_level = true
	preview.visible = false
	add_child(preview)

	# bow aim preview: dotted flight path + landing marker
	aim_node = Node3D.new()
	aim_node.top_level = true
	aim_node.visible = false
	add_child(aim_node)
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.06
	dot_mesh.height = 0.12
	var dot_mat := StandardMaterial3D.new()
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_mat.albedo_color = Color(1, 1, 1, 0.9)
	for i in 28:
		var dm := MeshInstance3D.new()
		dm.mesh = dot_mesh
		dm.material_override = dot_mat
		aim_node.add_child(dm)
		aim_dots.append(dm)
	var mk := SphereMesh.new()
	mk.radius = 0.25
	mk.height = 0.5
	aim_marker_mat = StandardMaterial3D.new()
	aim_marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aim_marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aim_marker_mat.albedo_color = Color(1, 0.9, 0.2, 0.75)
	aim_marker = MeshInstance3D.new()
	aim_marker.mesh = mk
	aim_marker.material_override = aim_marker_mat
	aim_node.add_child(aim_marker)

	for i in SLOTS:
		slot_types.append(0)
		slot_counts.append(0)
	_build_hud()
	add_item(1, 32)
	add_item(2, 16)
	add_item(3, 16)
	global_position = home
	peak_y = home.y
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	refresh_hud()

# ---------------------------------------------------------------- HUD
func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _bar(color: Color) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.max_value = 10.0
	pb.value = 10.0
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(288, 22)
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	pb.add_theme_stylebox_override("fill", fill)
	pb.add_theme_stylebox_override("background", bg)
	var l := _label(15, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pb.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return pb

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 0, 0, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash_rect)
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cross := Label.new()
	cross.text = "+"
	layer.add_child(cross)
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	# bottom: item title, health + hunger bars, hotbar
	var bottom := VBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 6)
	layer.add_child(bottom)
	item_title = _label(20, Color.WHITE)
	item_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(item_title)
	var stat_row := HBoxContainer.new()
	stat_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stat_row.add_theme_constant_override("separation", 12)
	bottom.add_child(stat_row)
	hp_bar = _bar(Color(0.85, 0.15, 0.15))
	hunger_bar = _bar(Color(0.9, 0.55, 0.1))
	stat_row.add_child(hp_bar)
	stat_row.add_child(hunger_bar)
	hp_text = hp_bar.get_child(0)
	hunger_text = hunger_bar.get_child(0)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(bar)
	for i in SLOTS:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(60, 60)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.5)
		sb.set_border_width_all(3)
		slot.add_theme_stylebox_override("panel", sb)
		var icon := ItemIcon.new()
		icon.setup(0, Color.WHITE, 40.0)
		icon.position = Vector2(10, 6)
		slot.add_child(icon)
		var num := Label.new()
		num.text = str(i + 1)
		num.position = Vector2(5, 0)
		num.add_theme_font_size_override("font_size", 12)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(num)
		var cnt := _label(16, Color.WHITE)
		cnt.position = Vector2(34, 40)
		slot.add_child(cnt)
		bar.add_child(slot)
		slot_styles.append(sb)
		slot_icons.append(icon)
		slot_labels.append(cnt)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_bottom = -12

	# right side: coins, emeralds, every team's bed status
	right_box = VBoxContainer.new()
	right_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(right_box)
	coin_label = _label(22, Color(1, 0.85, 0.2))
	emerald_label = _label(22, Color(0.3, 1, 0.5))
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	emerald_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_box.add_child(coin_label)
	right_box.add_child(emerald_label)
	var th := _label(16, Color.WHITE)
	th.text = "TEAMS / BEDS"
	th.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_box.add_child(th)
	right_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right_box.offset_right = -12
	right_box.offset_top = 10

	team_label = _label(22, Color.WHITE)
	layer.add_child(team_label)
	team_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	team_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	team_label.offset_top = 8

	notif_label = _label(28, Color.WHITE)
	notif_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(notif_label)
	notif_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notif_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	notif_label.offset_top = 70

	charge_bar = ProgressBar.new()
	charge_bar.max_value = 100.0
	charge_bar.show_percentage = false
	charge_bar.custom_minimum_size = Vector2(120, 8)
	charge_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cfill := StyleBoxFlat.new()
	cfill.bg_color = Color(1.0, 0.7, 0.1)
	charge_bar.add_theme_stylebox_override("fill", cfill)
	layer.add_child(charge_bar)
	charge_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	charge_bar.offset_left = -60.0
	charge_bar.offset_right = 60.0
	charge_bar.offset_top = 24.0
	charge_bar.offset_bottom = 32.0
	charge_bar.visible = false
	effects_label = _label(16, Color(0.7, 1.0, 0.8))
	effects_label.position = Vector2(10, 272)
	layer.add_child(effects_label)
	minimap = Minimap.new()
	minimap.player = self
	minimap.world = world
	layer.add_child(minimap)

	var help := Label.new()
	help.text = "LMB attack/break | RMB place / eat / throw / hold to draw bow | E shop | B hotbar manager | Q drop | Shift sneak | Esc pause + settings"
	help.position = Vector2(10, 34)
	layer.add_child(help)

func set_team(team_name: String, color: Color) -> void:
	team_label.text = "Team: " + team_name
	team_label.add_theme_color_override("font_color", color)

# list of {name, color, bed_alive, alive_count, eliminated, is_me}
func set_team_status(list: Array) -> void:
	while team_rows.size() < list.size():
		var l := _label(15, Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right_box.add_child(l)
		team_rows.append(l)
	for i in list.size():
		var d: Dictionary = list[i]
		var l2: Label = team_rows[i]
		var me := " (YOU)" if d["is_me"] else ""
		if d["eliminated"]:
			l2.text = "%s%s  OUT" % [d["name"], me]
			l2.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		else:
			l2.text = "%s%s  %s  x%d" % [d["name"], me, "BED OK" if d["bed_alive"] else "NO BED", d["alive_count"]]
			l2.add_theme_color_override("font_color", d["color"])

func notify(msg: String) -> void:
	notif_label.text = msg
	notif_t = 3.0

func item_color(t: int) -> Color:
	if GD.ITEM_COLORS.has(t):
		return GD.ITEM_COLORS[t]
	return world.COLORS[t]

func _count_item(type: int) -> int:
	var n := 0
	for i in SLOTS:
		if slot_types[i] == type:
			n += slot_counts[i]
	return n

func _title_text(st: int) -> String:
	if st == 0:
		return ""
	var s: String = GD.NAMES[st]
	if st == 20:
		s += " (damage %d)" % int(GD.SWORD_BASE + sword_level)
	elif st == 24:
		s += " (arrows: %d)" % _count_item(25)
	return s

func _update_held() -> void:
	var st: int = slot_types[selected] if alive else 0
	if st == held_type and (held_model != null or st == 0):
		return
	held_type = st
	if held_model != null:
		held_model.queue_free()
		held_model = null
	bow_string = null
	bow_arrow = null
	if st == 0:
		return
	held_model = ItemModels.make(st, world.COLORS)
	var pose: Array = HAND_POSE.get(st, [Vector3(0.0, 0.0, -0.22), Vector3.ZERO])
	held_model.position = pose[0]
	held_model.rotation_degrees = pose[1]
	hand_pivot.add_child(held_model)
	bow_string = held_model.get_node_or_null("String")
	bow_arrow = held_model.get_node_or_null("Arrow")

func refresh_hud() -> void:
	for i in SLOTS:
		var t: int = slot_types[i]
		slot_icons[i].set_item(t, item_color(t) if t != 0 else Color.WHITE)
		slot_labels[i].text = str(slot_counts[i]) if (t != 0 and GD.STACK[t] > 1) else ""
		slot_styles[i].border_color = Color.WHITE if i == selected else Color(0.4, 0.4, 0.4)
	coin_label.text = "Coins: %d" % coins
	emerald_label.text = "Emeralds: %d" % emeralds
	hp_bar.value = hp
	hunger_bar.value = hunger
	hp_text.text = "Health %s/10" % str(snappedf(hp, 0.5))
	hunger_text.text = "Hunger %s/10" % str(snappedf(hunger, 0.5))
	item_title.text = _title_text(slot_types[selected])
	_update_held()

# ---------------------------------------------------------------- inventory
func has_item(type: int) -> bool:
	for i in SLOTS:
		if slot_types[i] == type:
			return true
	return false

func add_item(type: int, n: int) -> int:
	var cap: int = GD.STACK[type]
	if cap == 1 and has_item(type):
		return n   # only one sword / axe / bow at a time
	var left := n
	for i in SLOTS:
		if left <= 0:
			break
		if slot_types[i] == type and slot_counts[i] < cap:
			var add := mini(cap - slot_counts[i], left)
			slot_counts[i] += add
			left -= add
	for i in SLOTS:
		if left <= 0:
			break
		if slot_types[i] == 0:
			var add2 := mini(cap, left)
			slot_types[i] = type
			slot_counts[i] = add2
			left -= add2
	refresh_hud()
	return left

func space_for(type: int) -> int:
	var cap: int = GD.STACK[type]
	if cap == 1 and has_item(type):
		return 0
	var s := 0
	for i in SLOTS:
		if slot_types[i] == type:
			s += cap - slot_counts[i]
		elif slot_types[i] == 0:
			s += cap
	return s

func swap_slots(a: int, b: int) -> void:
	var t: int = slot_types[a]
	var c: int = slot_counts[a]
	slot_types[a] = slot_types[b]
	slot_counts[a] = slot_counts[b]
	slot_types[b] = t
	slot_counts[b] = c
	_cancel_draw()
	refresh_hud()

func _use_one(slot: int) -> void:
	slot_counts[slot] -= 1
	if slot_counts[slot] <= 0:
		slot_types[slot] = 0
		slot_counts[slot] = 0

func _consume_item(type: int) -> bool:
	for i in SLOTS:
		if slot_types[i] == type:
			_use_one(i)
			refresh_hud()
			return true
	return false

func add_coins(n: int) -> void:
	coins += n
	Sfx.play2d(self, "coin", -6.0)
	refresh_hud()

func add_emeralds(n: int) -> void:
	emeralds += n
	Sfx.play2d(self, "emerald", -4.0)
	refresh_hud()

func spend_coins(n: int) -> bool:
	if coins < n:
		return false
	coins -= n
	refresh_hud()
	return true

func drop_item() -> void:
	if slot_types[selected] == 0:
		return
	var t: int = slot_types[selected]
	_use_one(selected)
	var fwd := -cam.global_transform.basis.z
	spawn_pickup("block", t, 1, cam.global_position + fwd * 0.8 + Vector3(0, -0.3, 0), 1.5, fwd * 3.0 + Vector3(0, 2, 0))
	refresh_hud()

func spawn_pickup(kind: String, type: int, count: int, pos: Vector3, delay: float, vel: Vector3) -> void:
	var pk = PickupScript.new()
	pk.setup(world, self, kind, type, count, vel, delay)
	world.get_parent().add_child(pk)
	pk.global_position = pos

func _eat() -> void:
	if hunger >= 10.0 and hp >= 10.0:
		notify("You are already full")
		return
	_use_one(selected)
	hp = minf(10.0, hp + GD.APPLE_HEAL)
	hunger = minf(10.0, hunger + GD.APPLE_FOOD)
	Sfx.play2d(self, "eat")
	refresh_hud()

# ---------------------------------------------------------------- health / death
func take_damage(amount: float, from: Vector3, attacker = null, knock: float = 7.0) -> void:
	if not alive:
		return
	last_attacker = attacker
	var kb := global_position - from
	kb.y = 0.0
	if kb.length() > 0.01:
		kb = kb.normalized() * knock
		velocity.x = kb.x
		velocity.z = kb.z
	velocity.y = 4.0 + knock * 0.15
	knock_t = 0.3 + knock * 0.012
	_cancel_draw()
	Sfx.play2d(self, "hurt", -3.0)
	hurt(amount)

func hurt(amount: float) -> void:
	if not alive:
		return
	hp = maxf(0.0, hp - amount)
	flash = 1.0
	refresh_hud()
	if hp <= 0.0:
		main.fighter_died(self, last_attacker)

func go_dead() -> void:
	alive = false
	velocity = Vector3.ZERO
	col_shape.set_deferred("disabled", true)
	hand_pivot.visible = false
	preview.visible = false
	drawing = false
	for i in SLOTS:   # everything on your hotbar is lost when you die
		slot_types[i] = 0
		slot_counts[i] = 0
	sword_level = 0
	invis_t = 0.0
	jump_t = 0.0
	strength_t = 0.0
	poison_weapon_t = 0.0
	poison_t = 0.0
	water_t = 0.0
	axe_charge = 0.0
	Sfx.play2d(self, "death")
	refresh_hud()

func respawn() -> void:
	alive = true
	hp = 10.0
	hunger = 10.0
	last_attacker = null
	knock_t = 0.0
	global_position = home
	velocity = Vector3.ZERO
	peak_y = home.y
	was_floor = true
	col_shape.disabled = false
	hand_pivot.visible = true
	refresh_hud()
	notify("Respawned")

# ---------------------------------------------------------------- input
func _captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not alive:
		return
	if event is InputEventMouseMotion and _captured():
		rotate_y(-event.relative.x * Settings.sensitivity)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * Settings.sensitivity, -1.5, 1.5)
	elif event is InputEventMouseButton and event.pressed:
		if not _captured():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			var st: int = slot_types[selected]
			if st == 22:
				_eat()
			elif st == 26:
				_throw_fireball()
			elif st == 27:
				_use_bucket()
			elif st >= 28 and st <= 31:
				_drink(st)
			elif st != 24:
				_try_place()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_click_swing()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			selected = (selected + SLOTS - 1) % SLOTS
			_cancel_draw()
			refresh_hud()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			selected = (selected + 1) % SLOTS
			_cancel_draw()
			refresh_hud()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("drop"):
			drop_item()
		elif event.is_action_pressed("map"):
			minimap.toggle_big()
		else:
			for i in SLOTS:   # hotbar keys are rebindable actions (slot_1 .. slot_9)
				if event.is_action_pressed("slot_%d" % (i + 1)):
					selected = i
					_cancel_draw()
					refresh_hud()
					break

# ---------------------------------------------------------------- per-frame
func _tick_timers(delta: float) -> void:
	play_time += delta
	place_cd = maxf(0.0, place_cd - delta)
	attack_cd = maxf(0.0, attack_cd - delta)
	bow_cd = maxf(0.0, bow_cd - delta)
	fb_cd = maxf(0.0, fb_cd - delta)
	warn_cd = maxf(0.0, warn_cd - delta)
	bucket_cd = maxf(0.0, bucket_cd - delta)
	water_t = maxf(0.0, water_t - delta)
	invis_t = maxf(0.0, invis_t - delta)
	jump_t = maxf(0.0, jump_t - delta)
	strength_t = maxf(0.0, strength_t - delta)
	poison_weapon_t = maxf(0.0, poison_weapon_t - delta)
	if poison_t > 0.0:
		poison_t -= delta
		poison_tick += delta
		if poison_tick >= 1.0:
			poison_tick = 0.0
			hurt(GD.POISON_DAMAGE)
	effects_label.text = effects_text()
	if notif_t > 0.0:
		notif_t -= delta
		if notif_t <= 0.0:
			notif_label.text = ""
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 3.0)
		flash_rect.color.a = flash * 0.35
	hunger_t += delta
	if hunger_t >= 25.0:
		hunger_t = 0.0
		hunger = maxf(0.0, hunger - 1.0)
		refresh_hud()
	if hunger <= 0.0:
		starve_t += delta
		if starve_t >= 4.0:
			starve_t = 0.0
			if hp > 1.0:
				hurt(1.0)
	elif hunger >= 8.0 and hp < 10.0:
		regen_t += delta
		if regen_t >= 5.0:
			regen_t = 0.0
			hp = minf(10.0, hp + 1.0)
			refresh_hud()

func _physics_process(delta: float) -> void:
	if not alive:
		return
	_tick_timers(delta)
	if not alive:
		return
	var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(iv.x, 0.0, iv.y)).normalized()
	sneaking = Input.is_action_pressed("sneak")
	var speed := 4.3
	if sneaking:
		speed = 1.6
	elif Input.is_action_pressed("sprint"):
		speed = 6.0
	if drawing:
		speed *= 0.6   # drawing a bow slows you down
	if knock_t > 0.0:
		knock_t -= delta
		velocity.x *= 0.94
		velocity.z *= 0.94
	else:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		# Sneak = edge safety: never walk off a block edge into empty space.
		if sneaking and is_on_floor():
			var fy := floori(global_position.y - 0.05)
			var nx := global_position.x + velocity.x * delta
			var nz := global_position.z + velocity.z * delta
			if not _supported(nx, global_position.z, fy):
				velocity.x = 0.0
			if not _supported(global_position.x, nz, fy):
				velocity.z = 0.0
	if is_on_floor() and velocity.y <= 0.0:
		velocity.y = 0.0
		if knock_t <= 0.0 and Input.is_action_pressed("jump"):
			velocity.y = GD.JUMP_SPEED if jump_t > 0.0 else 8.0
	else:
		velocity.y -= 25.0 * delta
	move_and_slide()
	# Fall damage: more than 3 blocks hurts, starting at half a heart and +half a heart per extra block.
	if is_on_floor():
		if not was_floor:
			var dist := peak_y - global_position.y
			if dist > GD.FALL_FREE:
				if water_t > 0.0:   # landed in the water bucket's water: no damage
					water_t = 0.0
					Sfx.play2d(self, "splash", -4.0)
					notify("Splash! No fall damage")
				else:
					hurt(0.5 * ceilf(dist - GD.FALL_FREE))
					Sfx.play2d(self, "hurt", -3.0)
					if not alive:
						return
		peak_y = global_position.y
	else:
		peak_y = maxf(peak_y, global_position.y)
	was_floor = is_on_floor()
	if global_position.y < -30.0:
		hurt(999.0)
		return
	var moving := is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.5
	if moving:
		bob_t += delta * (speed * 2.2)
		if not sneaking:
			step_acc += Vector2(velocity.x, velocity.z).length() * delta
			if step_acc > 2.3:
				step_acc = 0.0
				Sfx.play2d(self, "step", -14.0)
	head.position.y = lerpf(head.position.y, (1.35 if sneaking else 1.6) + (sin(bob_t * 2.0) * 0.025 if moving else 0.0), 0.3)
	_update_bow(delta)
	_update_aim()
	_update_target(delta)
	_animate_hand(delta, moving)

func effects_text() -> String:
	var parts := []
	if invis_t > 0.0:
		parts.append("Invisible %ds" % ceili(invis_t))
	if jump_t > 0.0:
		parts.append("High jump %ds" % ceili(jump_t))
	if strength_t > 0.0:
		parts.append("Strength %ds" % ceili(strength_t))
	if poison_weapon_t > 0.0:
		parts.append("Poison weapon %ds" % ceili(poison_weapon_t))
	if poison_t > 0.0:
		parts.append("POISONED %ds" % ceili(poison_t))
	if water_t > 0.0:
		parts.append("Water ready")
	return "  ".join(parts)

func apply_poison(duration: float, attacker = null) -> void:
	if not alive:
		return
	poison_t = maxf(poison_t, duration)
	poison_tick = 0.0
	last_attacker = attacker
	notify("You are poisoned!")

func _drink(st: int) -> void:
	if st == 28:
		invis_t = GD.INVIS_TIME
		notify("Invisible for %ds - bots only notice you up close" % int(GD.INVIS_TIME))
	elif st == 29:
		jump_t = GD.JUMP_TIME
		notify("High jump for %ds" % int(GD.JUMP_TIME))
	elif st == 30:
		strength_t = GD.STRENGTH_TIME
		notify("Strength: +%.1f melee damage for %ds" % [GD.STRENGTH_BONUS, int(GD.STRENGTH_TIME)])
	elif st == 31:
		poison_weapon_t = GD.POISON_WEAPON_TIME
		notify("Your weapon is poisoned for %ds" % int(GD.POISON_WEAPON_TIME))
	_use_one(selected)
	Sfx.play2d(self, "eat")
	refresh_hud()

# Water bucket: use it while falling to land in water (no fall damage). Reusable, 3s cooldown.
func _use_bucket() -> void:
	if bucket_cd > 0.0:
		return
	if is_on_floor() or velocity.y > -1.0:
		notify("Use the water bucket while you are falling")
		return
	bucket_cd = 3.0
	water_t = 3.0
	var hit: Dictionary = world.raycast(global_position, Vector3.DOWN, 14.0)
	if not hit.is_empty():
		var cell: Vector3i = hit["pos"]
		_spawn_water(Vector3(cell) + Vector3(0.5, 1.45, 0.5))
	notify("Water bucket!")
	Sfx.play2d(self, "splash", -6.0)

func _spawn_water(pos: Vector3) -> void:
	var w := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.98, 0.9, 0.98)
	w.mesh = bm
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.2, 0.5, 1.0, 0.55)
	w.material_override = m
	world.get_parent().add_child(w)
	w.global_position = pos
	var tw := w.create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(m, "albedo_color:a", 0.0, 1.5)
	tw.tween_callback(w.queue_free)

# Left click with a sword or empty hand always plays the swing animation, and hits whatever you are aiming at.
func _click_swing() -> void:
	var st: int = slot_types[selected]
	if (st != 20 and st != 0) or attack_cd > 0.0:
		return
	attack_cd = 0.5
	attack_anim = 1.0
	Sfx.play2d(self, "swing", -8.0)
	var victim = _find_victim()
	if victim != null:
		_deal_melee(victim, st, 0.0)
	else:
		var tm = _find_victim(true)
		if tm != null and tm.team == team and not Settings.friendly_fire and warn_cd <= 0.0:
			warn_cd = 1.5
			notify("That's your teammate! (friendly fire is off - see Settings)")

func _deal_melee(victim, st: int, charge: float) -> void:
	var dmg := GD.FIST_DAMAGE
	if st == 20:
		dmg = GD.SWORD_BASE + float(sword_level)
	elif st == 21:
		dmg = lerpf(GD.AXE_MIN, GD.AXE_MAX, charge)
	if strength_t > 0.0:
		dmg += GD.STRENGTH_BONUS
	var knock := GD.KNOCK + (5.0 * charge if st == 21 else 0.0)
	victim.take_damage(dmg, global_position, self, knock)
	if poison_weapon_t > 0.0:
		victim.apply_poison(GD.POISON_SECONDS, self)
	Sfx.play3d(world.get_parent(), "hit", victim.global_position + Vector3(0, 1, 0))

# Bow aim preview: simulate the arrow with the same speed and gravity and show the path + where it will land.
func _update_aim() -> void:
	if not drawing or draw_t < 0.2:
		aim_node.visible = false
		return
	aim_node.visible = true
	var dir := -cam.global_transform.basis.z
	var pos := cam.global_position + dir * 0.7 + Vector3(0, -0.1, 0)
	var vel := dir * (14.0 + 24.0 * draw_t)
	var dt := 0.05
	var dot_i := 0
	var end_pos := pos
	var hit_enemy := false
	var enemies := []
	for f in get_tree().get_nodes_in_group("fighters"):
		if f.alive and f.team != team and f != self:
			enemies.append(f)
	for i in 50:
		vel.y -= 14.0 * dt
		var step := vel * dt
		var dist := step.length()
		var d := step / dist
		var bh: Dictionary = world.raycast(pos, d, dist)
		var block_t := dist + 1.0
		if not bh.is_empty():
			block_t = bh["t"]
		for e in enemies:
			var c: Vector3 = e.global_position + Vector3(0, 1.0, 0)
			var u := clampf((c - pos).dot(d), 0.0, dist)
			if (pos + d * u).distance_to(c) < 0.65 and u < block_t:
				hit_enemy = true
				end_pos = pos + d * u
				break
		if hit_enemy:
			break
		if not bh.is_empty():
			end_pos = pos + d * block_t
			break
		pos += step
		end_pos = pos
		if i % 2 == 0 and dot_i < aim_dots.size():
			aim_dots[dot_i].global_position = pos
			aim_dots[dot_i].visible = true
			dot_i += 1
	for j in range(dot_i, aim_dots.size()):
		aim_dots[j].visible = false
	aim_marker.global_position = end_pos
	aim_marker_mat.albedo_color = Color(1, 0.15, 0.15, 0.8) if hit_enemy else Color(1, 0.9, 0.2, 0.75)

func _cancel_draw() -> void:
	drawing = false
	draw_t = 0.0
	axe_charge = 0.0

# Bow: hold right mouse to draw (up to 1s), release to shoot. More draw = faster arrow + more damage.
func _update_bow(delta: float) -> void:
	var st: int = slot_types[selected]
	if st != 24:
		if drawing:
			_cancel_draw()
		return
	var rmb := _captured() and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if rmb and not drawing and bow_cd <= 0.0:
		if has_item(25):
			drawing = true
			draw_t = 0.0
			Sfx.play2d(self, "draw", -6.0)
		elif warn_cd <= 0.0:
			warn_cd = 1.5
			notify("No arrows! Buy some in the shop")
	if drawing:
		if rmb:
			draw_t = minf(draw_t + delta, 1.0)
		else:
			if draw_t >= 0.2:
				_fire_arrow(draw_t)
			_cancel_draw()
			bow_cd = 0.4

func _fire_arrow(power: float) -> void:
	if not _consume_item(25):
		return
	var ar := ArrowScript.new()
	ar.world = world
	ar.shooter = self
	ar.team = team
	var dir := -cam.global_transform.basis.z
	ar.vel = dir * (14.0 + 24.0 * power)
	ar.damage = 2.0 + 5.0 * power
	ar.position = cam.global_position + dir * 0.7 + Vector3(0, -0.1, 0)
	world.get_parent().add_child(ar)
	Sfx.play2d(self, "shot", -4.0)

func _throw_fireball() -> void:
	if fb_cd > 0.0:
		return
	var f := FireballScript.new()
	f.world = world
	f.shooter = self
	f.team = team
	f.dir = -cam.global_transform.basis.z
	f.position = cam.global_position + f.dir * 0.9 + Vector3(0, -0.15, 0)
	world.get_parent().add_child(f)
	_use_one(selected)
	fb_cd = 0.7
	attack_anim = 1.0
	refresh_hud()

func _animate_hand(delta: float, moving: bool) -> void:
	attack_anim = maxf(0.0, attack_anim - delta * 4.0)
	place_anim = maxf(0.0, place_anim - delta * 6.0)
	var mining := _captured() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and has_break_target
	var k := 0.4 if sneaking else 1.0   # smaller placing animation while sneaking
	var swing := sin(attack_anim * PI)
	var d := draw_t if drawing else 0.0
	var target_rot := sin(Time.get_ticks_msec() * 0.02) * 0.5 if mining else 0.0
	target_rot -= swing * 1.3 + sin(place_anim * PI) * 0.7 * k
	target_rot += axe_charge * 0.9   # axe raised while charging
	hand_pivot.rotation.x = lerpf(hand_pivot.rotation.x, target_rot, 0.5)
	hand_pivot.rotation.z = lerpf(hand_pivot.rotation.z, swing * 0.5, 0.5)
	hand_pivot.rotation.y = lerpf(hand_pivot.rotation.y, -swing * 0.35 + d * 0.12, 0.4)
	var bx := sin(bob_t) * 0.02 if moving else 0.0
	var by := absf(sin(bob_t)) * 0.025 if moving else 0.0
	hand_pivot.position = Vector3(0.3 + bx - 0.12 * d, -0.3 + by - swing * 0.05 + 0.04 * d, -0.5 - sin(place_anim * PI) * 0.12 * k - swing * 0.15 - 0.08 * d)
	if bow_string != null:
		bow_string.position.z = 0.04 + d * 0.24
	if bow_arrow != null:
		bow_arrow.visible = d > 0.0
		bow_arrow.position.z = -0.2 + d * 0.24
	cam.fov = lerpf(cam.fov, 75.0 - d * 12.0, 0.2)
	var cv := d if drawing else axe_charge
	charge_bar.visible = cv > 0.0
	charge_bar.value = cv * 100.0

# Body footprint is +-0.3 wide. Supported while at least ~0.1 of it still overlaps a block below.
func _supported(px: float, pz: float, fy: int) -> bool:
	for o in [Vector2(-0.2, 0.0), Vector2(0.2, 0.0), Vector2(0.0, -0.2), Vector2(0.0, 0.2)]:
		if world.get_block(Vector3i(floori(px + o.x), fy, floori(pz + o.y))) != 0:
			return true
	return false

func _find_victim(allow_team: bool = false):
	var origin := cam.global_position
	var look := -cam.global_transform.basis.z
	var best = null
	var bd := ATTACK_REACH
	for f in get_tree().get_nodes_in_group("fighters"):
		if f == self or not f.alive or (f.team == team and not allow_team and not Settings.friendly_fire):
			continue
		var to: Vector3 = f.global_position + Vector3(0, 1.0, 0) - origin
		var dist := to.length()
		if dist > bd or dist < 0.01:
			continue
		if to.normalized().dot(look) < 0.9:
			continue
		if not world.raycast(origin, to.normalized(), dist).is_empty():
			continue   # no attacking through walls
		best = f
		bd = dist
	return best

func _update_target(delta: float) -> void:
	var st: int = slot_types[selected]
	var lmb := _captured() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var victim = _find_victim() if (lmb or axe_charge > 0.0) else null
	if st == 21:
		# axe: hold left click near an enemy to charge, release for a heavy chop
		if lmb and victim != null:
			axe_charge = minf(axe_charge + delta / GD.AXE_CHARGE_TIME, 1.0)
			has_break_target = false
			break_progress = 0.0
		elif not lmb and axe_charge > 0.0:
			if axe_charge >= 0.25 and attack_cd <= 0.0:
				attack_cd = 0.8
				attack_anim = 1.0
				Sfx.play2d(self, "swing", -6.0)
				if victim != null:
					_deal_melee(victim, st, axe_charge)
			axe_charge = 0.0
		elif lmb and victim == null:
			axe_charge = 0.0
	elif lmb and victim != null:
		has_break_target = false
		break_progress = 0.0
		if attack_cd <= 0.0:
			attack_cd = 0.5
			attack_anim = 1.0
			Sfx.play2d(self, "swing", -8.0)
			_deal_melee(victim, st, 0.0)
	var hit: Dictionary = world.raycast(cam.global_position, -cam.global_transform.basis.z, REACH)
	preview.visible = false
	if hit.is_empty():
		has_break_target = false
		break_progress = 0.0
		return
	var n: Vector3i = hit.normal
	if n != Vector3i.ZERO and (GD.is_block(st) or st == 23):
		var pp: Vector3i = hit.pos + n
		preview.visible = true
		preview.global_position = Vector3(pp) + Vector3(0.5, 0.5, 0.5)
		var valid := _cell_free(pp)
		preview_mat.albedo_color = Color(0.2, 1, 0.2, 0.35) if valid else Color(1, 0.2, 0.2, 0.35)
		# Hold right mouse: blocks place automatically the moment the preview turns green (never TNT).
		if valid and st != 23 and _captured() and place_cd <= 0.0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_place_at(pp)
	if lmb and victim == null:
		if has_break_target and hit.pos == break_target:
			break_progress += delta
		else:
			has_break_target = true
			break_target = hit.pos
			break_progress = 0.0
		if world.can_break(break_target, team):
			var t: int = world.get_block(break_target)
			var need: float = world.break_time(t) / (GD.AXE_SPEED if st == 21 else 1.0)
			if break_progress >= need:
				var p := break_target
				var r: int = world.try_break(p, team)
				if r == 1:
					spawn_pickup("block", t, 1, Vector3(p) + Vector3(0.5, 0.5, 0.5), 0.3, Vector3(0, 2, 0))
				Sfx.play3d(world.get_parent(), "break", Vector3(p) + Vector3(0.5, 0.5, 0.5))
				has_break_target = false
				break_progress = 0.0
		elif warn_cd <= 0.0:
			warn_cd = 1.5
			notify("You can't break that")
	elif not lmb:
		has_break_target = false
		break_progress = 0.0

# A cell is free for a block / TNT when it is empty, inside the world and not overlapping your body.
func _cell_free(pp: Vector3i) -> bool:
	if world.get_block(pp) != 0:
		return false
	if pp.y < world.MIN_Y or pp.y > world.MAX_Y:
		return false
	var bmin := Vector3(pp)
	var bmax := bmin + Vector3.ONE
	var pmin := global_position + Vector3(-0.3, 0.0, -0.3)
	var pmax := global_position + Vector3(0.3, 1.8, 0.3)
	var overlap := bmin.x < pmax.x and bmax.x > pmin.x and bmin.y < pmax.y and bmax.y > pmin.y + 0.3 and bmin.z < pmax.z and bmax.z > pmin.z
	return not overlap

func _try_place() -> void:
	var st: int = slot_types[selected]
	if not (GD.is_block(st) or st == 23):
		return
	var hit: Dictionary = world.raycast(cam.global_position, -cam.global_transform.basis.z, REACH)
	if hit.is_empty() or hit.normal == Vector3i.ZERO:
		return
	var pp: Vector3i = hit.pos + hit.normal
	if place_cd > 0.0 or not _cell_free(pp):
		return
	if st == 23:
		_place_tnt(pp)
	else:
		_place_at(pp)

func _place_tnt(pp: Vector3i) -> void:
	var t := TntScript.new()
	t.setup(world, self)
	t.position = Vector3(pp) + Vector3(0.5, 0.5, 0.5)
	world.get_parent().add_child(t)
	_use_one(selected)
	place_cd = 0.3
	place_anim = 1.0
	notify("TNT primed! Run!")
	refresh_hud()

func _place_at(pp: Vector3i) -> void:
	var t: int = slot_types[selected]
	world.set_block(pp, t)
	world.placed[pp] = true
	_use_one(selected)
	place_cd = 0.12
	place_anim = 1.0
	_place_fx(pp)
	Sfx.play3d(world.get_parent(), "place", Vector3(pp) + Vector3(0.5, 0.5, 0.5), -4.0)
	refresh_hud()

# Pop animation: a bright box slightly larger than the block shrinks into it and fades out (smaller when sneaking).
func _place_fx(pp: Vector3i) -> void:
	var g := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 1.02
	g.mesh = bm
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 1, 1, 0.3 if sneaking else 0.6)
	g.material_override = m
	world.get_parent().add_child(g)
	g.global_position = Vector3(pp) + Vector3(0.5, 0.5, 0.5)
	g.scale = Vector3.ONE * (1.08 if sneaking else 1.3)
	var tw := g.create_tween()
	tw.tween_property(g, "scale", Vector3.ONE, 0.15 if sneaking else 0.2)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.15 if sneaking else 0.2)
	tw.tween_callback(g.queue_free)
