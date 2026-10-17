extends Node3D
# Primed TNT: falls like a block, flashes red/white faster and faster while it swells, then explodes.

const GD = preload("res://scripts/game_data.gd")
const FX = preload("res://scripts/fx.gd")
const Sfx = preload("res://scripts/sfx.gd")

var world
var owner_f = null
var fuse := GD.TNT_FUSE
var vy := 0.0
var flash_t := 0.0
var white := false
var done := false
var body_mat: StandardMaterial3D
var band_mat: StandardMaterial3D

func setup(w, o) -> void:
	world = w
	owner_f = o

func _ready() -> void:
	add_to_group("tnt")
	body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.8, 0.1, 0.1)
	band_mat = StandardMaterial3D.new()
	band_mat.albedo_color = Color(0.95, 0.95, 0.95)
	var b := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 0.98
	b.mesh = bm
	b.material_override = body_mat
	add_child(b)
	var band := MeshInstance3D.new()
	var bm2 := BoxMesh.new()
	bm2.size = Vector3(1.0, 0.3, 1.0)
	band.mesh = bm2
	band.material_override = band_mat
	add_child(band)
	Sfx.play3d(get_parent(), "fuse", global_position, -6.0)

func _apply_flash() -> void:
	if white:
		body_mat.albedo_color = Color(1, 1, 1)
		body_mat.emission_enabled = true
		body_mat.emission = Color(1, 1, 1) * 0.9
		band_mat.albedo_color = Color(0.85, 0.1, 0.1)
	else:
		body_mat.albedo_color = Color(0.8, 0.1, 0.1)
		body_mat.emission_enabled = false
		band_mat.albedo_color = Color(0.95, 0.95, 0.95)

func _physics_process(delta: float) -> void:
	if done:
		return
	fuse -= delta
	var below := Vector3i(floori(global_position.x), floori(global_position.y - 0.52), floori(global_position.z))
	if world.get_block(below) == 0:
		vy -= 20.0 * delta
		global_position.y += vy * delta
		if global_position.y < -30.0:
			queue_free()
			return
	elif vy != 0.0:
		vy = 0.0
		global_position.y = below.y + 1.5
	var prog := clampf(1.0 - fuse / GD.TNT_FUSE, 0.0, 1.0)
	flash_t += delta
	if flash_t >= lerpf(0.4, 0.08, prog) * 0.5:
		flash_t = 0.0
		white = not white
		_apply_flash()
	scale = Vector3.ONE * (1.0 + 0.2 * prog * prog)
	if fuse <= 0.0:
		done = true
		FX.blast(world, global_position, 3.5, 5.0, 8.0, 14.0, owner_f, true, null, true)
		queue_free()
