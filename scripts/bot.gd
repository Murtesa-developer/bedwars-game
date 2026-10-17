extends CharacterBody3D
# AI fighter using the same mechanics as the player. It collects coins at its house, buys gear (sword, wool,
# axe, bow, TNT, fireballs, apples, sword upgrades), bridges gaps block by block, mines through blocks in its way,
# fights enemies (melee, bow, fireballs), fortifies and defends its bed (defender role), raids enemy beds with TNT
# (raider role), retreats when hurt and gives up impossible destinations.
# States: collect, fight, raid, fortify, emerald, retreat.

const GD = preload("res://scripts/game_data.gd")
const Sfx = preload("res://scripts/sfx.gd")
const ItemModels = preload("res://scripts/item_models.gd")
const ArrowScript = preload("res://scripts/arrow.gd")
const FireballScript = preload("res://scripts/fireball.gd")
const TntScript = preload("res://scripts/tnt.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const SPEED := 3.4

var world
var main
var team := 0
var role := "raider"           # "defender" stays home and fortifies the bed, "raider" attacks beds
var house := Vector3.ZERO      # centre of the team house (coin pile area)
var home := Vector3.ZERO       # this bot's own spawn point inside the house
var team_color := Color.WHITE
var alive := true
var hp := 10.0
var blocks := 0
var coins := 0
var emeralds := 0
var apples := 0
var arrows := 0
var tnt := 0
var fireballs := 0
var sword_level := 0
var has_sword := false
var has_axe := false
var has_bow := false
var invis_t := 0.0
var poison_t := 0.0
var poison_tick := 0.0
var tag: Label3D
var greedy := false            # sometimes goes for emeralds on the middle tower
var state := "collect"
var think_t := 0.0
var place_cd := 0.0
var atk_cd := 0.0
var bow_cd := 0.0
var fb_cd := 0.0
var attack_anim := 0.0
var knock_t := 0.0
var walk_t := 0.0
var regen_t := 0.0
var flee_t := 0.0
var flee_from := Vector3.ZERO
var goal := Vector3.ZERO
var goal_node = null
var mine_cell := Vector3i.ZERO
var mine_prog := 0.0
var mining_timer := 0.0
var stuck_t := 0.0
var stuck_count := 0
var last_pos := Vector3.ZERO
var detour_t := 0.0
var detour_dir := Vector3.ZERO
var giveup_t := 0.0
var axis_x := true
var peak_y := 0.0
var was_floor := true
var last_attacker = null
var col_shape: CollisionShape3D
var visual: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var sword_vis: Node3D

func _ready() -> void:
	add_to_group("collectors")
	add_to_group("fighters")
	floor_max_angle = deg_to_rad(60.0)
	collision_layer = 2
	collision_mask = 1
	col_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.8
	col_shape.shape = cap
	col_shape.position.y = 0.9
	add_child(col_shape)
	visual = Node3D.new()
	add_child(visual)
	var shirt := StandardMaterial3D.new()
	shirt.albedo_color = team_color
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.95, 0.75, 0.6)
	var pants := StandardMaterial3D.new()
	pants.albedo_color = Color(0.2, 0.2, 0.25)
	_box(Vector3(0.5, 0.7, 0.3), Vector3(0, 1.15, 0), shirt)
	_box(Vector3(0.36, 0.36, 0.36), Vector3(0, 1.65, 0), skin)
	arm_l = _limb(Vector3(-0.35, 1.45, 0), Vector3(0.18, 0.6, 0.18), shirt)
	arm_r = _limb(Vector3(0.35, 1.45, 0), Vector3(0.18, 0.6, 0.18), shirt)
	leg_l = _limb(Vector3(-0.12, 0.8, 0), Vector3(0.2, 0.8, 0.2), pants)
	leg_r = _limb(Vector3(0.12, 0.8, 0), Vector3(0.2, 0.8, 0.2), pants)
	sword_vis = ItemModels.make(20, {})
	sword_vis.position = Vector3(0, -0.55, -0.05)
	sword_vis.visible = false
	arm_r.add_child(sword_vis)
	global_position = home
	last_pos = home
	peak_y = home.y
	goal = house
	think_t = randf() * 0.3
	greedy = randf() < 0.35
	tag = Label3D.new()   # floating name tag: team, ally marker and health
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0, 2.3, 0)
	tag.pixel_size = 0.006
	tag.font_size = 40
	tag.outline_size = 10
	tag.modulate = team_color
	add_child(tag)
	_update_tag()

func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	visual.add_child(mi)

func _limb(pos: Vector3, size: Vector3, mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = Vector3(0, -size.y * 0.5, 0)
	pivot.add_child(mi)
	visual.add_child(pivot)
	return pivot

func _give_sword() -> void:
	has_sword = true
	sword_vis.visible = true

# ---- collector API used by pickups
func add_coins(n: int) -> void:
	coins += n

func add_emeralds(n: int) -> void:
	emeralds += n

func add_item(type: int, n: int) -> int:
	if type >= 1 and type <= 4:
		var take := mini(n, 64 - blocks)
		blocks += take
		return n - take
	if type == 20:
		if has_sword:
			return n
		_give_sword()
		return n - 1
	if type == 21:
		if has_axe:
			return n
		has_axe = true
		return n - 1
	if type == 24:
		if has_bow:
			return n
		has_bow = true
		return n - 1
	if type == 22:
		var t2 := mini(n, 16 - apples)
		apples += t2
		return n - t2
	if type == 25:
		var t3 := mini(n, 64 - arrows)
		arrows += t3
		return n - t3
	if type == 23:
		var t4 := mini(n, 16 - tnt)
		tnt += t4
		return n - t4
	if type == 26:
		var t5 := mini(n, 16 - fireballs)
		fireballs += t5
		return n - t5
	return n

# ---- health / death
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
	hurt(amount)

func hurt(amount: float) -> void:
	if not alive:
		return
	hp = maxf(0.0, hp - amount)
	_update_tag()
	if hp <= 0.0:
		main.fighter_died(self, last_attacker)

func _update_tag() -> void:
	var nm: String = main.teams[team]["name"]
	var ally := "  (ally)" if team == main.player_team else ""
	tag.text = "%s%s\n%s" % [nm, ally, str(snappedf(hp, 0.5))]

func apply_poison(duration: float, attacker = null) -> void:
	if not alive:
		return
	poison_t = maxf(poison_t, duration)
	poison_tick = 0.0
	last_attacker = attacker

func go_dead() -> void:
	alive = false
	visible = false
	velocity = Vector3.ZERO
	col_shape.set_deferred("disabled", true)
	_drop_loot()   # everything the bot carried drops where it died - walk over it to take it
	coins = 0
	emeralds = 0
	blocks = 0
	apples = 0
	arrows = 0
	tnt = 0
	fireballs = 0
	sword_level = 0
	has_sword = false
	has_axe = false
	has_bow = false
	sword_vis.visible = false

func _drop_loot() -> void:
	var pos := global_position + Vector3(0, 0.5, 0)
	var loot := [["coin", 0, coins], ["emerald", 0, emeralds], ["block", 1, blocks], ["block", 22, apples],
		["block", 25, arrows], ["block", 23, tnt], ["block", 26, fireballs]]
	if has_sword:
		loot.append(["block", 20, 1])
	if has_axe:
		loot.append(["block", 21, 1])
	if has_bow:
		loot.append(["block", 24, 1])
	for l in loot:
		if int(l[2]) <= 0:
			continue
		var pk = PickupScript.new()
		pk.setup(world, null, l[0], l[1], l[2], Vector3(randf_range(-2.0, 2.0), 4.0, randf_range(-2.0, 2.0)), 0.8)
		main.add_child(pk)
		pk.global_position = pos

func respawn() -> void:
	alive = true
	visible = true
	hp = 10.0
	last_attacker = null
	knock_t = 0.0
	flee_t = 0.0
	global_position = home
	velocity = Vector3.ZERO
	peak_y = home.y
	was_floor = true
	state = "collect"
	col_shape.disabled = false

# ---- brain (runs every ~0.3s)
func _think() -> void:
	_update_tag()
	var moved := global_position.distance_to(last_pos)
	last_pos = global_position
	if moved < 0.15 and goal.distance_to(global_position) > 1.5 and mining_timer <= 0.0 and flee_t <= 0.0:
		stuck_t += 0.3
	else:
		stuck_t = 0.0
	if stuck_t >= 1.8:   # recover from failed navigation
		stuck_t = 0.0
		stuck_count += 1
		_start_detour(Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized())
		if stuck_count >= 4:   # stop trying an impossible destination
			stuck_count = 0
			giveup_t = 8.0
	giveup_t = maxf(0.0, giveup_t - 0.3)
	_shop()
	if hp <= 5.0 and apples > 0:
		apples -= 1
		hp = minf(10.0, hp + GD.APPLE_HEAL)
	var enemy = _nearest_enemy(global_position, 12.0)
	if enemy == null:
		var bp = main.own_bed_pos(team)
		if bp != null:
			enemy = _nearest_enemy(bp, 14.0)   # intruder near our bed
	var edist := 999.0
	if enemy != null:
		edist = global_position.distance_to(enemy.global_position)
	if hp <= 3.0 and apples == 0 and edist > 3.5:
		state = "retreat"
		goal = house
	elif enemy != null and (giveup_t <= 0.0 or edist < 5.0):
		state = "fight"
		goal_node = enemy
		goal = enemy.global_position
	elif role == "defender" and blocks >= 6 and giveup_t <= 0.0 and _fortify_cell() != null:
		state = "fortify"
	elif blocks >= (12 if role == "raider" else 24) and giveup_t <= 0.0 and main.nearest_enemy_bed(team, global_position) != null:
		state = "raid"
		goal = main.nearest_enemy_bed(team, global_position)
	elif greedy and has_sword and blocks >= 32 and emeralds < 12 and giveup_t <= 0.0 and _nearest_emerald() != null:
		state = "emerald"
		goal = _nearest_emerald()
	else:
		state = "collect"
		goal = _nearest_coin()

func _shop() -> void:
	if not has_sword:
		if coins >= 10:
			coins -= 10
			_give_sword()
		elif blocks < 8 and coins >= 2:
			coins -= 2
			blocks = mini(64, blocks + 8)
		return
	if blocks < 32 and coins >= 2:
		coins -= 2
		blocks = mini(64, blocks + 8)
	elif tnt < 2 and role == "raider" and coins >= 6:
		coins -= 6
		tnt += 1
	elif sword_level < GD.SWORD_UPGRADE_COST.size() and emeralds >= GD.SWORD_UPGRADE_COST[sword_level]:
		emeralds -= GD.SWORD_UPGRADE_COST[sword_level]
		sword_level += 1
	elif not has_axe and coins >= 6:
		coins -= 6
		has_axe = true
	elif apples < 2 and coins >= 5:
		coins -= 5
		apples += 1
	elif not has_bow and coins >= 12:
		coins -= 12
		has_bow = true
	elif has_bow and arrows < 8 and coins >= 4:
		coins -= 4
		arrows += 8
	elif fireballs < 2 and coins >= 10:
		coins -= 10
		fireballs += 1

func _nearest_enemy(from: Vector3, r: float):
	var best = null
	var bd := r
	for f in get_tree().get_nodes_in_group("fighters"):
		if f == self or not f.alive or f.team == team:
			continue
		var d := from.distance_to(f.global_position)
		if f.invis_t > 0.0 and d > 4.0:
			continue   # invisible players are only noticed up close
		if d < bd:
			bd = d
			best = f
	return best

func _nearest_coin() -> Vector3:
	var best := house
	var bd := 1e9
	for c in get_tree().get_nodes_in_group("coin_pickup"):
		var hd := Vector2(c.global_position.x - house.x, c.global_position.z - house.z).length()
		if hd < 6.0:
			var d := global_position.distance_to(c.global_position)
			if d < bd:
				bd = d
				best = c.global_position
	return best

func _nearest_emerald():
	var best = null
	var bd := 1e9
	for c in get_tree().get_nodes_in_group("green_pickup"):
		var d := global_position.distance_to(c.global_position)
		if d < bd:
			bd = d
			best = c.global_position
	return best

# Next empty cell around our own bed that still needs a protective block.
func _fortify_cell():
	var cells = main.own_bed_cells(team)
	if cells == null:
		return null
	var best = null
	var bd := 1e9
	for c in cells:
		for off in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i(0, 1, 0)]:
			var n: Vector3i = c + off
			if cells.has(n) or world.get_block(n) != 0:
				continue
			var d := global_position.distance_to(Vector3(n) + Vector3(0.5, 0.5, 0.5))
			if d < bd:
				bd = d
				best = n
	return best

# A bed is "covered" when none of its open sides (4 sides + top) is empty.
func _bed_covered(cell: Vector3i) -> bool:
	for off in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i(0, 1, 0)]:
		var n: Vector3i = cell + off
		if world.bed_owner.has(n):
			continue
		if world.get_block(n) == 0:
			return false
	return true

# Nearest breakable block protecting the bed.
func _cover_cell(cell: Vector3i):
	var best = null
	var bd := 1e9
	for off in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i(0, 1, 0)]:
		var n: Vector3i = cell + off
		if world.get_block(n) == 0 or world.bed_owner.has(n) or not world.can_break(n, team):
			continue
		var d := global_position.distance_to(Vector3(n) + Vector3(0.5, 0.5, 0.5))
		if d < bd:
			bd = d
			best = n
	return best

func _los(target) -> bool:
	var eye := global_position + Vector3(0, 1.5, 0)
	var to: Vector3 = target.global_position + Vector3(0, 1.0, 0) - eye
	var dist := to.length()
	if dist < 0.01:
		return true
	return world.raycast(eye, to.normalized(), dist).is_empty()   # no attacking through walls

func _hit(target) -> void:
	atk_cd = 0.8
	attack_anim = 1.0
	var dmg := GD.FIST_DAMAGE
	if has_sword:
		dmg = GD.SWORD_BASE + float(sword_level)
	elif has_axe:
		dmg = GD.AXE_DAMAGE
	target.take_damage(dmg, global_position, self, 7.0)
	Sfx.play3d(main, "hit", target.global_position + Vector3(0, 1, 0))

func _shoot_arrow(target) -> void:
	arrows -= 1
	bow_cd = 2.2
	attack_anim = 1.0
	var from := global_position + Vector3(0, 1.5, 0)
	var tpos: Vector3 = target.global_position + Vector3(0, 1.0, 0)
	var speed := 30.0
	var tt := from.distance_to(tpos) / speed
	var aim := tpos + Vector3(0, 0.5 * 14.0 * tt * tt, 0)   # compensate arrow drop
	var dir := (aim - from).normalized() + Vector3(randf_range(-0.03, 0.03), randf_range(-0.03, 0.03), randf_range(-0.03, 0.03))
	dir = dir.normalized()
	var ar := ArrowScript.new()
	ar.world = world
	ar.shooter = self
	ar.team = team
	ar.vel = dir * speed
	ar.damage = 4.5
	ar.position = from + dir * 0.7
	main.add_child(ar)
	Sfx.play3d(main, "shot", from)

func _throw_fireball(target) -> void:
	fireballs -= 1
	fb_cd = 3.0
	attack_anim = 1.0
	var from := global_position + Vector3(0, 1.4, 0)
	var f := FireballScript.new()
	f.world = world
	f.shooter = self
	f.team = team
	f.dir = (target.global_position + Vector3(0, 1.0, 0) - from).normalized()
	f.position = from + f.dir * 0.9
	main.add_child(f)

func _place_tnt_toward(target_pos: Vector3) -> void:
	tnt -= 1
	var d := target_pos - global_position
	d.y = 0.0
	d = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	var p := global_position + d * 1.2
	var t := TntScript.new()
	t.setup(world, self)
	t.position = Vector3(floorf(p.x) + 0.5, floorf(global_position.y + 0.05) + 0.5, floorf(p.z) + 0.5)
	main.add_child(t)
	flee_t = 5.0
	flee_from = t.position
	attack_anim = 1.0

# ---- movement
func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0

func _start_detour(dir: Vector3) -> void:
	detour_dir = dir
	detour_t = 1.2

func _mine_cell(cell: Vector3i, delta: float) -> void:
	_stop()
	var t: int = world.get_block(cell)
	if t == 0:
		return
	if mine_cell != cell:
		mine_cell = cell
		mine_prog = 0.0
	mine_prog += delta
	mining_timer = 0.5
	attack_anim = maxf(attack_anim, 0.6)
	var need: float = world.break_time(t) * 1.4 / (GD.AXE_SPEED if has_axe else 1.0)
	if mine_prog >= need:
		world.try_break(cell, team)
		Sfx.play3d(main, "break", Vector3(cell) + Vector3(0.5, 0.5, 0.5), -4.0)
		mine_prog = 0.0

func _goto(t: Vector3, delta: float, axis_mode: bool) -> void:
	var d := t - global_position
	d.y = 0.0
	if d.length() < 0.7:
		_stop()
		return
	var dir := Vector3.ZERO
	var move := Vector3.ZERO
	if detour_t > 0.0:
		detour_t -= delta
		dir = detour_dir
		move = dir
	elif axis_mode:
		# 4-connected route (L shape) so bridges are always walkable
		if axis_x and absf(d.x) < 0.8 and absf(d.z) >= 0.8:
			axis_x = false
		elif not axis_x and absf(d.z) < 0.8 and absf(d.x) >= 0.8:
			axis_x = true
		if axis_x:
			dir = Vector3(signf(d.x), 0, 0)
			move = dir + Vector3(0, 0, clampf((floorf(global_position.z) + 0.5 - global_position.z) * 3.0, -1.0, 1.0))
		else:
			dir = Vector3(0, 0, signf(d.z))
			move = dir + Vector3(clampf((floorf(global_position.x) + 0.5 - global_position.x) * 3.0, -1.0, 1.0), 0, 0)
	else:
		dir = d.normalized()
		move = dir
	if dir == Vector3.ZERO:
		dir = d.normalized()
		move = dir
	_step(dir, move, delta, axis_mode)

func _step(dir: Vector3, move: Vector3, delta: float, allow_bridge: bool) -> void:
	visual.rotation.y = atan2(-dir.x, -dir.z)
	if not is_on_floor():
		var airv := move.normalized() * SPEED
		velocity.x = airv.x
		velocity.z = airv.z
		return
	var fy := floori(global_position.y - 0.1)
	var p := global_position + dir * 0.75
	var g := Vector3i(floori(p.x), fy, floori(p.z))
	var f1 := g + Vector3i(0, 1, 0)
	var f2 := g + Vector3i(0, 2, 0)
	var f3 := g + Vector3i(0, 3, 0)
	var b1: int = world.get_block(f1)
	var b2: int = world.get_block(f2)
	if b1 != 0:
		if b2 == 0 and world.get_block(f3) == 0:
			if knock_t <= 0.0:
				velocity.y = 8.0   # hop onto a one-block step
		else:
			# blocked by a wall: break it if it's breakable, otherwise walk around
			if world.can_break(f1, team):
				_mine_cell(f1, delta)
			else:
				_start_detour(dir.rotated(Vector3.UP, PI * 0.5 * (1.0 if randf() < 0.5 else -1.0)))
				_stop()
			return
	elif b2 != 0:
		if world.can_break(f2, team):
			_mine_cell(f2, delta)
		else:
			_start_detour(dir.rotated(Vector3.UP, PI * 0.5 * (1.0 if randf() < 0.5 else -1.0)))
			_stop()
		return
	if b1 == 0 and world.get_block(g) == 0:   # no ground ahead
		_stop()
		if allow_bridge and blocks > 0 and place_cd <= 0.0:
			world.set_block(g, 1)
			world.placed[g] = true
			blocks -= 1
			place_cd = 0.35
			attack_anim = maxf(attack_anim, 0.5)
			Sfx.play3d(main, "place", Vector3(g) + Vector3(0.5, 0.5, 0.5), -8.0)
		return
	var mv := move.normalized() * SPEED
	velocity.x = mv.x
	velocity.z = mv.z

func _act(delta: float) -> void:
	if flee_t > 0.0:   # run away from our own TNT
		flee_t -= delta
		var away := global_position - flee_from
		away.y = 0.0
		var dest := global_position + (away.normalized() if away.length() > 0.01 else Vector3.RIGHT) * 6.0
		_goto(dest, delta, false)
		return
	if state == "fight":
		if goal_node == null or not is_instance_valid(goal_node) or not goal_node.alive:
			state = "collect"
			_stop()
			return
		var to: Vector3 = goal_node.global_position - global_position
		var hd := Vector2(to.x, to.z).length()
		if hd > 0.01:
			visual.rotation.y = atan2(-to.x, -to.z)
		if hd <= 2.4 and absf(to.y) < 2.5:
			_stop()
			if atk_cd <= 0.0 and _los(goal_node):
				_hit(goal_node)
		else:
			if hd > 6.0 and hd < 22.0 and _los(goal_node):   # ranged attacks
				if has_bow and arrows > 0 and bow_cd <= 0.0:
					_shoot_arrow(goal_node)
				elif fireballs > 0 and fb_cd <= 0.0 and hd < 16.0:
					_throw_fireball(goal_node)
			goal = goal_node.global_position
			_goto(goal, delta, hd > 4.0)
	elif state == "raid":
		var to2 := goal - global_position
		var hd2 := Vector2(to2.x, to2.z).length()
		var bed_cell := Vector3i(floori(goal.x), floori(goal.y), floori(goal.z))
		if hd2 <= 5.0 and absf(to2.y) < 3.0 and _bed_covered(bed_cell):
			# the bed is walled in: TNT clears the defenses (beds survive explosions), otherwise chip them away by hand
			if tnt > 0 and flee_t <= 0.0 and hd2 > 2.5:
				_place_tnt_toward(goal)
			elif hd2 <= 3.6:
				var cover = _cover_cell(bed_cell)
				if cover != null:
					_mine_cell(cover, delta)
				else:
					_stop()
			else:
				_goto(goal, delta, true)
		elif hd2 <= 3.2 and absf(to2.y) < 3.0:
			_stop()
			_mine_cell(bed_cell, delta)   # break the bed by hand
		else:
			_goto(goal, delta, true)
	elif state == "fortify":
		var cell = _fortify_cell()
		if cell == null:
			state = "collect"
			_stop()
			return
		var cpos := Vector3(cell) + Vector3(0.5, 0.5, 0.5)
		var to3 := cpos - global_position
		var hd3 := Vector2(to3.x, to3.z).length()
		if hd3 <= 3.2 and absf(to3.y) < 3.0:
			_stop()
			visual.rotation.y = atan2(-to3.x, -to3.z)
			var inside := absf(to3.x) < 0.8 and absf(to3.z) < 0.8 and absf(to3.y) < 1.5
			if inside:
				_start_detour(Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized())
			elif place_cd <= 0.0 and blocks > 0:
				world.set_block(cell, 1)
				world.placed[cell] = true
				blocks -= 1
				place_cd = 0.4
				attack_anim = maxf(attack_anim, 0.6)
				Sfx.play3d(main, "place", cpos, -8.0)
		else:
			_goto(cpos, delta, false)
	elif state == "emerald":
		_goto(goal, delta, true)
	else:
		_goto(goal, delta, false)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	place_cd = maxf(0.0, place_cd - delta)
	atk_cd = maxf(0.0, atk_cd - delta)
	bow_cd = maxf(0.0, bow_cd - delta)
	fb_cd = maxf(0.0, fb_cd - delta)
	mining_timer = maxf(0.0, mining_timer - delta)
	attack_anim = maxf(0.0, attack_anim - delta * 4.0)
	regen_t += delta
	if regen_t >= 6.0:
		regen_t = 0.0
		hp = minf(10.0, hp + 0.5)
	if poison_t > 0.0:
		poison_t -= delta
		poison_tick += delta
		if poison_tick >= 1.0:
			poison_tick = 0.0
			hurt(GD.POISON_DAMAGE)
			if not alive:
				return
	if global_position.y < -30.0:
		hurt(999.0)
		return
	think_t -= delta
	if think_t <= 0.0:
		think_t = 0.3
		_think()
	if is_on_floor() and velocity.y <= 0.0:
		velocity.y = 0.0
	else:
		velocity.y -= 25.0 * delta
	if knock_t > 0.0:
		knock_t -= delta
		velocity.x *= 0.94
		velocity.z *= 0.94
	else:
		_act(delta)
	move_and_slide()
	# fall damage: more than 3 blocks hurts, half a heart per extra block
	if is_on_floor():
		if not was_floor:
			var dist := peak_y - global_position.y
			if dist > GD.FALL_FREE:
				hurt(0.5 * ceilf(dist - GD.FALL_FREE))
				if not alive:
					return
		peak_y = global_position.y
	else:
		peak_y = maxf(peak_y, global_position.y)
	was_floor = is_on_floor()
	_animate(delta)

func _animate(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var swing := 0.0
	if speed > 0.3 and is_on_floor():
		walk_t += delta * speed * 2.6
		swing = sin(walk_t) * 0.8
	leg_l.rotation.x = lerpf(leg_l.rotation.x, swing, 0.4)
	leg_r.rotation.x = lerpf(leg_r.rotation.x, -swing, 0.4)
	arm_l.rotation.x = lerpf(arm_l.rotation.x, -swing, 0.4)
	var arm_target := swing
	if attack_anim > 0.0:
		arm_target = -sin(attack_anim * PI) * 1.8   # sword swing
	arm_r.rotation.x = lerpf(arm_r.rotation.x, arm_target, 0.6)
