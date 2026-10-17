extends Node3D
# Arrow projectile: gravity, flies along its velocity, hits one enemy (damage set by bow charge) or sticks in a block.

const Sfx = preload("res://scripts/sfx.gd")
const ItemModels = preload("res://scripts/item_models.gd")

var world
var shooter = null
var team := -1
var vel := Vector3.ZERO
var damage := 3.0
var age := 0.0
var stuck := false

func _ready() -> void:
	add_child(ItemModels.make_arrow())
	_orient()

func _orient() -> void:
	if vel.length() < 0.1:
		return
	var d := vel.normalized()
	var up := Vector3.UP if absf(d.y) < 0.99 else Vector3.RIGHT
	look_at(global_position + d, up)

func _physics_process(delta: float) -> void:
	age += delta
	if stuck:
		if age > 10.0:
			queue_free()
		return
	if global_position.y < -40.0 or age > 12.0:
		queue_free()
		return
	vel.y -= 14.0 * delta
	var step := vel * delta
	var dist := step.length()
	if dist < 0.0001:
		return
	var dir := step / dist
	var block_t := dist + 1.0
	var hit: Dictionary = world.raycast(global_position, dir, dist)
	if not hit.is_empty():
		block_t = hit["t"]
	var target = null
	var best := dist
	for f in get_tree().get_nodes_in_group("fighters"):
		if not f.alive or f.team == team:
			continue
		var c: Vector3 = f.global_position + Vector3(0, 1.0, 0)
		var u := clampf((c - global_position).dot(dir), 0.0, dist)
		if (global_position + dir * u).distance_to(c) < 0.65 and u < block_t and u <= best:
			target = f
			best = u
	if target != null:
		target.take_damage(damage, global_position - dir * 1.5, shooter, 6.0)
		Sfx.play3d(get_parent(), "arrow_hit", global_position)
		queue_free()
		return
	if not hit.is_empty():
		global_position += dir * maxf(block_t - 0.02, 0.0)
		stuck = true
		age = 0.0
		Sfx.play3d(get_parent(), "arrow_hit", global_position, -4.0)
		return
	global_position += step
	_orient()
