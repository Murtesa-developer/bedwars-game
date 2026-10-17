extends Node3D
# Match: 8 team islands in a ring around a middle island with a stone tower and emeralds.
# Each team has 4 fighters (you + 3 bots on your team, 4 bots on every other team), a big house with unbreakable
# obsidian corner pillars, and a realistic bed (mattress + pillow) outside the house in the middle of its island.
# Bed destroyed -> no more respawns for that team. Last team with a bed or living members wins.

const GD = preload("res://scripts/game_data.gd")
const Settings = preload("res://scripts/settings.gd")
const Sfx = preload("res://scripts/sfx.gd")
const VoxelWorld = preload("res://scripts/voxel_world.gd")
const Player = preload("res://scripts/player.gd")
const Bot = preload("res://scripts/bot.gd")
const PauseMenu = preload("res://scripts/pause_menu.gd")
const ShopMenu = preload("res://scripts/shop_menu.gd")
const InventoryMenu = preload("res://scripts/inventory_menu.gd")
const RING := 46            # distance of team islands from the middle island
const OUTER_RADIUS := 12
const CENTER_RADIUS := 7
const HOUSE_HALF := 4       # house is 9x9
const HOUSE_OFFSET := 7     # house sits this far behind the island centre (the bed stays in the middle)
const WALL_TOP := 6         # walls fill y = 3..6, roof at y = 7
const ROOF_Y := 7
const TEAM_SIZE := 4
const MAX_COINS_PER_HOUSE := 30
const MAX_EMERALDS := 10
const TEAM_DEFS := [
	{"name": "RED", "color": Color(0.90, 0.15, 0.15)},
	{"name": "GREEN", "color": Color(0.20, 0.75, 0.25)},
	{"name": "BLUE", "color": Color(0.20, 0.35, 0.90)},
	{"name": "YELLOW", "color": Color(0.95, 0.80, 0.15)},
	{"name": "ORANGE", "color": Color(1.00, 0.55, 0.10)},
	{"name": "PURPLE", "color": Color(0.60, 0.25, 0.80)},
	{"name": "CYAN", "color": Color(0.10, 0.80, 0.85)},
	{"name": "PINK", "color": Color(1.00, 0.50, 0.70)},
]
const SPAWN_OFFSETS := [Vector3(-2, 0, -2), Vector3(2, 0, 2), Vector3(-2, 0, 2), Vector3(2, 0, -2)]

var world
var teams: Array = []
var player_ref
var player_team := 0
var match_over := false
var coin_accum := 0.0
var emerald_accum := 0.0
var hud_accum := 0.0

func _make_loading() -> Dictionary:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.14)
	layer.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	layer.add_child(box)
	if ResourceLoader.exists("res://assets/logo.png"):
		var logo := TextureRect.new()
		logo.texture = load("res://assets/logo.png")
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.custom_minimum_size = Vector2(220, 220)
		box.add_child(logo)
	else:
		var title := Label.new()
		title.text = "BEDWARS"
		title.add_theme_font_size_override("font_size", 56)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(title)
	var label := Label.new()
	label.text = "Loading..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(520, 24)
	bar.max_value = 100.0
	box.add_child(bar)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	return {"layer": layer, "label": label, "bar": bar}

func _loading_step(label: Label, bar: ProgressBar, text: String, v: float) -> void:
	label.text = text
	bar.value = v * 100.0
	await get_tree().process_frame

func _ready() -> void:
	Settings.load_settings()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var ui := _make_loading()
	var label: Label = ui["label"]
	var bar: ProgressBar = ui["bar"]
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)

	world = VoxelWorld.new()
	world.name = "VoxelWorld"
	add_child(world)
	world.block_broken.connect(_on_block_broken)

	await _loading_step(label, bar, "Building the middle island...", 0.05)
	_make_island(Vector2i(0, 0), CENTER_RADIUS)
	_make_ziggurat()
	for i in TEAM_DEFS.size():
		await _loading_step(label, bar, "Building island %d of %d..." % [i + 1, TEAM_DEFS.size()], 0.1 + 0.55 * float(i) / float(TEAM_DEFS.size()))
		var c := _island_center(i)
		var door := _door_dir(c)
		var back := -door
		var h := c + back * HOUSE_OFFSET
		var block := GD.BED_BASE + i
		_make_island(c, OUTER_RADIUS)
		_make_house(h, door, block)
		# realistic bed outside the house: team-colored blanket + white pillow, half-height
		var side := Vector2i(door.y, door.x)
		var cells := [Vector3i(c.x, 3, c.y), Vector3i(c.x + side.x, 3, c.y + side.y)]
		world.set_block(cells[0], block)
		world.set_block(cells[1], GD.PILLOW)
		world.bed_owner[cells[0]] = i
		world.bed_owner[cells[1]] = i
		teams.append({
			"name": TEAM_DEFS[i]["name"], "color": TEAM_DEFS[i]["color"], "block": block,
			"bed_cells": cells, "bed_alive": true, "alive_count": TEAM_SIZE, "eliminated": false,
			"house": Vector3(h.x + 0.5, 3.05, h.y + 0.5),
		})
	await _loading_step(label, bar, "Finishing the world...", 0.68)
	world.flush()
	await get_tree().physics_frame

	await _loading_step(label, bar, "Spawning you...", 0.75)
	player_team = randi() % TEAM_DEFS.size()
	var player := Player.new()
	player.world = world
	player.main = self
	player.team = player_team
	player.home = teams[player_team]["house"]
	add_child(player)
	player_ref = player
	player.set_team(teams[player_team]["name"], teams[player_team]["color"])
	for k in teams.size():
		await _loading_step(label, bar, "Spawning team %s..." % teams[k]["name"], 0.78 + 0.2 * float(k) / float(teams.size()))
		var n := TEAM_SIZE - 1 if k == player_team else TEAM_SIZE
		for j in n:
			var bot := Bot.new()
			bot.world = world
			bot.main = self
			bot.team = k
			bot.role = "defender" if j == 0 else "raider"
			bot.house = teams[k]["house"]
			bot.home = teams[k]["house"] + SPAWN_OFFSETS[j]
			bot.team_color = teams[k]["color"]
			add_child(bot)
	player.set_team_status(_status_list())
	add_child(PauseMenu.new())
	var shop := ShopMenu.new()
	shop.player = player
	add_child(shop)
	var inv := InventoryMenu.new()
	inv.player = player
	add_child(inv)
	Sfx.start_music(self)
	var layer: CanvasLayer = ui["layer"]
	layer.queue_free()

# ---------------------------------------------------------------- map building
func _island_center(i: int) -> Vector2i:
	var a := TAU * float(i) / float(TEAM_DEFS.size())
	return Vector2i(roundi(cos(a) * RING), roundi(sin(a) * RING))

func _door_dir(c: Vector2i) -> Vector2i:
	if absi(c.x) >= absi(c.y):
		return Vector2i(-signi(c.x), 0)
	return Vector2i(0, -signi(c.y))

func _make_island(center: Vector2i, radius: int) -> void:
	for x in range(center.x - radius, center.x + radius + 1):
		for z in range(center.y - radius, center.y + radius + 1):
			var d := Vector2(x - center.x, z - center.y).length()
			if d <= radius + 0.5:
				world.set_block(Vector3i(x, 0, z), 6)
				world.set_block(Vector3i(x, 1, z), 6)
				world.set_block(Vector3i(x, 2, z), 5)

# Stepped stone tower in the middle, every step 1 block high (climb it by jumping). Emeralds appear on top.
func _make_ziggurat() -> void:
	var halves := [5, 4, 3, 2, 1, 0]
	for i in halves.size():
		var y := 3 + i
		var half: int = halves[i]
		var t := 2 if y <= 6 else 4
		for x in range(-half, half + 1):
			for z in range(-half, half + 1):
				world.set_block(Vector3i(x, y, z), t)

# 9x9 wooden house with a 3-wide doorway facing the middle island, a roof skylight (coins fall in),
# team-colored roof corners and unbreakable obsidian corner pillars.
func _make_house(h: Vector2i, door: Vector2i, team_block: int) -> void:
	var hh := HOUSE_HALF
	for x in range(-hh, hh + 1):
		for z in range(-hh, hh + 1):
			var edge: bool = absi(x) == hh or absi(z) == hh
			var corner: bool = absi(x) == hh and absi(z) == hh
			if not (x == 0 and z == 0):
				world.set_block(Vector3i(h.x + x, ROOF_Y, h.y + z), team_block if corner else 3)
			if not edge:
				continue
			var is_door := false
			if door.x != 0 and x == door.x * hh and absi(z) <= 1:
				is_door = true
			elif door.y != 0 and z == door.y * hh and absi(x) <= 1:
				is_door = true
			for y in range(3, WALL_TOP + 1):
				if is_door and y < 6:
					continue
				world.set_block(Vector3i(h.x + x, y, h.y + z), GD.OBSIDIAN if corner else 3)

# ---------------------------------------------------------------- queries used by bots
func _bed_center(c: Vector3i) -> Vector3:
	return Vector3(c) + Vector3(0.5, 0.5, 0.5)

func nearest_enemy_bed(my_team: int, from: Vector3):
	var best = null
	var bd := 1e9
	for i in teams.size():
		if i == my_team or not teams[i]["bed_alive"]:
			continue
		for c in teams[i]["bed_cells"]:
			if world.get_block(c) == 0:
				continue
			var pos := _bed_center(c)
			var d := from.distance_to(pos)
			if d < bd:
				bd = d
				best = pos
	return best

func own_bed_pos(team: int):
	if not teams[team]["bed_alive"]:
		return null
	for c in teams[team]["bed_cells"]:
		if world.get_block(c) != 0:
			return _bed_center(c)
	return null

func own_bed_cells(team: int):
	if not teams[team]["bed_alive"]:
		return null
	return teams[team]["bed_cells"]

# ---------------------------------------------------------------- match rules
func _status_list() -> Array:
	var list := []
	for i in teams.size():
		var t: Dictionary = teams[i]
		list.append({"name": t["name"], "color": t["color"], "bed_alive": t["bed_alive"],
			"alive_count": t["alive_count"], "eliminated": t["eliminated"], "is_me": i == player_team})
	return list

func _on_block_broken(pos: Vector3i, _type: int, _breaker_team: int, bed_team: int) -> void:
	if bed_team < 0:
		return
	var t: Dictionary = teams[bed_team]
	if not t["bed_alive"]:
		return
	t["bed_alive"] = false
	for c in t["bed_cells"]:
		if world.get_block(c) != 0:
			world.set_block(c, 0)
	Sfx.play3d(self, "bed", Vector3(pos) + Vector3(0.5, 0.5, 0.5), 6.0)
	if bed_team == player_team:
		player_ref.notify("YOUR BED WAS DESTROYED! You can't respawn anymore")
		Sfx.play2d(self, "bed")
	else:
		player_ref.notify("%s bed destroyed!" % t["name"])
	player_ref.set_team_status(_status_list())
	_check_win()

func fighter_died(f, killer) -> void:
	var t: Dictionary = teams[f.team]
	if killer != null and is_instance_valid(killer) and killer != f:
		killer.add_coins(GD.KILL_COINS)
	f.go_dead()
	if t["bed_alive"]:
		if f == player_ref:
			player_ref.notify("You died - respawning in 3s (you lose your items)")
		get_tree().create_timer(3.0, false).timeout.connect(_respawn.bind(f))
	else:
		_eliminate(f)

func _respawn(f) -> void:
	if match_over or not is_instance_valid(f):
		return
	if teams[f.team]["bed_alive"]:
		f.respawn()
	else:
		_eliminate(f)

func _eliminate(f) -> void:
	teams[f.team]["alive_count"] -= 1
	if f == player_ref:
		_end_match(false)
		return
	f.queue_free()
	player_ref.set_team_status(_status_list())
	_check_win()

func _teams_left() -> Array:
	var left := []
	for i in teams.size():
		var t: Dictionary = teams[i]
		t["eliminated"] = (not t["bed_alive"]) and t["alive_count"] <= 0
		if not t["eliminated"]:
			left.append(i)
	return left

func _check_win() -> void:
	if match_over:
		return
	var left := _teams_left()
	if left.size() == 1 and left[0] == player_team:
		_end_match(true)
	elif left.size() <= 1:
		_end_match(false)

func _end_match(win: bool) -> void:
	if match_over:
		return
	match_over = true
	_teams_left()
	player_ref.set_team_status(_status_list())
	Sfx.play2d(self, "win" if win else "lose")
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var panel := PanelContainer.new()
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "VICTORY!" if win else "DEFEAT"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Your team is the last one standing. Game over." if win else "Your team can no longer respawn. Game over."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var b1 := Button.new()
	b1.text = "Play again"
	b1.custom_minimum_size = Vector2(260, 48)
	b1.pressed.connect(_restart)
	box.add_child(b1)
	var b3 := Button.new()
	b3.text = "Main menu"
	b3.custom_minimum_size = Vector2(260, 48)
	b3.pressed.connect(_main_menu)
	box.add_child(b3)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

# ---------------------------------------------------------------- coins and emeralds
# Coins appear only at the houses (they fall through the roof skylight). Emeralds appear on top of the middle tower.
func _physics_process(delta: float) -> void:
	if player_ref == null or match_over:
		return
	hud_accum += delta
	if hud_accum >= 0.5:
		hud_accum = 0.0
		_teams_left()
		player_ref.set_team_status(_status_list())
	coin_accum += delta
	var iv: float = player_ref.coin_interval()
	if coin_accum >= iv:
		coin_accum -= iv
		var piles := get_tree().get_nodes_in_group("coin_pickup")
		for t in teams:
			var hp: Vector3 = t["house"]
			var n := 0
			for c in piles:
				if absf(c.global_position.x - hp.x) < 4.0 and absf(c.global_position.z - hp.z) < 4.0:
					n += int(c.count)
			if n < MAX_COINS_PER_HOUSE:
				player_ref.spawn_pickup("coin", 0, 1, Vector3(hp.x, ROOF_Y + 1.5, hp.z), 0.0, Vector3.ZERO)
	emerald_accum += delta
	if emerald_accum >= 8.0:
		emerald_accum = 0.0
		var total := 0
		for c in get_tree().get_nodes_in_group("green_pickup"):
			total += int(c.count)
		if total < MAX_EMERALDS:
			player_ref.spawn_pickup("emerald", 0, 1, Vector3(0.5, 10.0, 0.5), 0.0, Vector3.ZERO)
