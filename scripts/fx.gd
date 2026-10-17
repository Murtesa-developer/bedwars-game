extends RefCounted
# Explosion logic shared by TNT and fireballs: shielded damage + knockback, block destruction, chain reaction, effects.

const Sfx = preload("res://scripts/sfx.gd")

# strong = TNT: also destroys unbreakable (ground, obsidian) and reinforced blocks. Beds are immune to every explosion.
static func blast(world, center: Vector3, block_r: float, dmg_r: float, dmg_max: float, knock_max: float, owner_f, big: bool, exclude = null, strong: bool = false) -> void:
	var parent: Node = world.get_parent()
	var tree := parent.get_tree()
	# 1) work out damage first (blocks in between shield people)
	var victims := []
	for f in tree.get_nodes_in_group("fighters"):
		if f == exclude or not f.alive:
			continue
		var target: Vector3 = f.global_position + Vector3(0, 0.9, 0)
		var d := target.distance_to(center)
		if d >= dmg_r:
			continue
		var k := 1.0 - d / dmg_r
		var dmg := dmg_max * k
		if d > 0.3 and not world.raycast(center, (target - center).normalized(), d).is_empty():
			dmg *= 0.4
		victims.append([f, dmg, knock_max * k + 2.0])
	# 2) destroy blocks (reinforced blocks resist, unbreakable ones stay)
	var ci := Vector3i(floori(center.x), floori(center.y), floori(center.z))
	var rr := int(ceil(block_r)) + 1
	for x in range(-rr, rr + 1):
		for y in range(-rr, rr + 1):
			for z in range(-rr, rr + 1):
				var cell := ci + Vector3i(x, y, z)
				var bt: int = world.get_block(cell)
				if bt == 0 or world.bed_owner.has(cell):
					continue   # explosions never destroy beds
				if not strong and world.BLAST_PROOF.has(bt):
					continue
				var d2 := (Vector3(cell) + Vector3(0.5, 0.5, 0.5)).distance_to(center)
				if d2 > block_r:
					continue
				if d2 > block_r * 0.7 and randf() > 0.6:
					continue
				if strong:
					world.set_block(cell, 0)   # TNT breaks even unbreakable blocks
				else:
					world.try_break(cell, -1)
	# 3) chain reaction
	for tn in tree.get_nodes_in_group("tnt"):
		if tn.global_position.distance_to(center) < block_r + 1.0:
			tn.fuse = minf(tn.fuse, 0.25)
	# 4) hurt people
	for v in victims:
		v[0].take_damage(v[1], center, owner_f, v[2])
	_effects(parent, center, big)
	Sfx.play3d(parent, "explosion" if big else "fireball_hit", center, 4.0 if big else 0.0)

static func _effects(parent: Node, center: Vector3, big: bool) -> void:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.55, 0.1, 0.9)
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	var s := MeshInstance3D.new()
	s.mesh = sm
	s.material_override = mat
	parent.add_child(s)
	s.global_position = center
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector3.ONE * (7.0 if big else 3.5), 0.45).from(Vector3.ONE * 0.4)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tw.tween_callback(s.queue_free)
	var p := CPUParticles3D.new()
	p.amount = 60 if big else 25
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 11.0 if big else 7.0
	p.gravity = Vector3(0, -14, 0)
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 0.22
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.25, 0.2, 0.18)
	pm.emission_enabled = true
	pm.emission = Color(1.0, 0.4, 0.05) * 0.6
	bm.material = pm
	p.mesh = bm
	parent.add_child(p)
	p.global_position = center
	p.emitting = true
	parent.get_tree().create_timer(1.6).timeout.connect(p.queue_free)
