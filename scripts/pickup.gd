extends Node3D
# Dropped coin / green coin / item pile. Draws at most 10 small items but holds the full count.
# Resting piles of the same kind merge. Any alive "collector" (player or bot) walking close takes the whole pile.

const GD = preload("res://scripts/game_data.gd")
const MAX_VISIBLE := 10
var world
var kind := "coin"    # "coin", "emerald" (green, used for sword upgrades) or "block" (any inventory item id in `type`)
var type := 0
var count := 1
var vel := Vector3.ZERO
var age := 0.0
var delay := 0.5
var resting := false
var pile: Node3D
var item_mesh: Mesh
var item_mat: StandardMaterial3D

func setup(w, _pl, k: String, t: int, c: int, v: Vector3, d: float) -> void:
	world = w
	kind = k
	type = t
	count = c
	vel = v
	delay = d

func _ready() -> void:
	add_to_group("pickup")
	item_mat = StandardMaterial3D.new()
	if kind == "block":
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * 0.25
		item_mesh = bm
		if GD.ITEM_COLORS.has(type):
			item_mat.albedo_color = GD.ITEM_COLORS[type]
		else:
			item_mat.albedo_color = world.COLORS[type]
	else:
		add_to_group("coin_pickup" if kind == "coin" else "green_pickup")
		var cm := CylinderMesh.new()
		cm.top_radius = 0.16
		cm.bottom_radius = 0.16
		cm.height = 0.05
		item_mesh = cm
		item_mat.metallic = 0.6
		item_mat.emission_enabled = true
		if kind == "coin":
			item_mat.albedo_color = Color(1.0, 0.82, 0.1)
			item_mat.emission = Color(0.6, 0.45, 0.0)
		else:
			item_mat.albedo_color = Color(0.1, 0.9, 0.3)
			item_mat.emission = Color(0.0, 0.6, 0.15)
	pile = Node3D.new()
	add_child(pile)
	_build_visual()

func _build_visual() -> void:
	for c in pile.get_children():
		c.queue_free()
	var n := mini(count, MAX_VISIBLE)
	for i in n:
		var mi := MeshInstance3D.new()
		mi.mesh = item_mesh
		mi.material_override = item_mat
		var a := i * 2.4
		var r := 0.0 if n == 1 else 0.12 + 0.03 * (i % 3)
		mi.position = Vector3(cos(a) * r, floorf(i / 3.0) * 0.06, sin(a) * r)
		if kind != "block":
			mi.rotation_degrees.x = 90.0
		pile.add_child(mi)

func add_count(n: int, new_delay: float = 0.0) -> void:
	count += n
	if new_delay > 0.0:
		age = 0.0
		delay = new_delay
	_build_visual()

func _merge() -> void:
	for o in get_tree().get_nodes_in_group("pickup"):
		if o == self or o.kind != kind or o.type != type or not o.resting or o.is_queued_for_deletion():
			continue
		if absf(o.global_position.x - global_position.x) < 1.2 and absf(o.global_position.z - global_position.z) < 1.2 and absf(o.global_position.y - global_position.y) < 0.5:
			o.add_count(count, delay if delay >= 1.0 else 0.0)
			queue_free()
			return

func _physics_process(delta: float) -> void:
	age += delta
	rotate_y(2.5 * delta)
	if global_position.y < -30.0:
		queue_free()
		return
	var landed := false
	if not resting:
		vel.y -= 20.0 * delta
		var np := global_position + vel * delta
		if world.get_block(Vector3i(floori(np.x), floori(global_position.y), floori(np.z))) != 0:
			vel.x = 0.0
			vel.z = 0.0
			np.x = global_position.x
			np.z = global_position.z
		var below := Vector3i(floori(np.x), floori(np.y - 0.2), floori(np.z))
		if vel.y <= 0.0 and world.get_block(below) != 0:
			np.y = below.y + 1.2
			resting = true
			landed = true
			vel = Vector3.ZERO
		global_position = np
		vel.x *= 0.97
		vel.z *= 0.97
	else:
		var b := Vector3i(floori(global_position.x), floori(global_position.y - 0.3), floori(global_position.z))
		if world.get_block(b) == 0:
			resting = false
		pile.position.y = sin(age * 3.0) * 0.05
	if landed:
		_merge()
		if is_queued_for_deletion():
			return
	if age > delay:
		for col in get_tree().get_nodes_in_group("collectors"):
			if not col.alive:
				continue
			var d: Vector3 = col.global_position + Vector3(0, 0.9, 0) - global_position
			if d.length() < 1.6:
				if kind == "coin":
					col.add_coins(count)
					queue_free()
				elif kind == "emerald":
					col.add_emeralds(count)
					queue_free()
				else:
					var left: int = col.add_item(type, count)
					if left <= 0:
						queue_free()
					elif left < count:
						count = left
						_build_visual()
				return
