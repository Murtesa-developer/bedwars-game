extends Node3D
# Fireball: flies straight where you aim, leaves a dark smoke trail. Direct hit = 4 damage + knockback.
# Hitting a block explodes: breaks nearby blocks and hurts / knocks back anyone about one block from the impact.

const GD = preload("res://scripts/game_data.gd")
const FX = preload("res://scripts/fx.gd")
const Sfx = preload("res://scripts/sfx.gd")
const ItemModels = preload("res://scripts/item_models.gd")

var world
var shooter = null
var team := -1
var dir := Vector3.FORWARD
var speed := 17.0
var age := 0.0

func _ready() -> void:
	var m := ItemModels.make(26, {})
	m.scale = Vector3.ONE * 1.6
	add_child(m)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.15)
	light.light_energy = 2.5
	light.omni_range = 7.0
	add_child(light)
	# smoke trail left behind the fireball
	var tr := CPUParticles3D.new()
	tr.amount = 40
	tr.lifetime = 0.8
	tr.local_coords = false
	tr.direction = Vector3.UP
	tr.spread = 180.0
	tr.initial_velocity_min = 0.1
	tr.initial_velocity_max = 0.6
	tr.gravity = Vector3(0, 0.8, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.13
	sm.height = 0.26
	var tm := StandardMaterial3D.new()
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.albedo_color = Color(0.12, 0.1, 0.1, 0.55)
	sm.material = tm
	tr.mesh = sm
	tr.emitting = true
	add_child(tr)
	Sfx.play3d(get_parent(), "fireball", global_position)

func _physics_process(delta: float) -> void:
	age += delta
	if age > 6.0 or global_position.y < -40.0:
		queue_free()
		return
	var dist := speed * delta
	var hit: Dictionary = world.raycast(global_position, dir, dist)
	var block_t := dist + 1.0
	if not hit.is_empty():
		block_t = hit["t"]
	var target = null
	var best := dist
	for f in get_tree().get_nodes_in_group("fighters"):
		if not f.alive:
			continue
		if f == shooter and age < 0.3:
			continue
		var c: Vector3 = f.global_position + Vector3(0, 1.0, 0)
		var u := clampf((c - global_position).dot(dir), 0.0, dist)
		if (global_position + dir * u).distance_to(c) < 0.8 and u < block_t and u <= best:
			target = f
			best = u
	if target != null:
		var p := global_position + dir * best
		target.take_damage(4.0, p - dir * 1.0, shooter, 10.0)   # direct hit
		FX.blast(world, p, 1.6, 2.4, 3.0, 9.0, shooter, false, target)
		queue_free()
		return
	if not hit.is_empty():
		var p2 := global_position + dir * maxf(block_t - 0.05, 0.0)
		FX.blast(world, p2, 1.6, 2.4, 3.0, 9.0, shooter, false)
		queue_free()
		return
	global_position += dir * dist
