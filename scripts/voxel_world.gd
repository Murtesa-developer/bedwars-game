extends Node3D
# Sparse voxel storage + per-chunk mesh (hidden faces culled, procedural block textures) + per-chunk trimesh collision.
# Only chunks touched by a change are rebuilt. Bed blocks are half-height (mattress + pillow).

signal block_broken(pos: Vector3i, type: int, breaker_team: int, bed_team: int)
const UNBREAKABLE := [5, 6, 15]   # island ground and house corner pillars
const BLAST_PROOF := [4]          # reinforced blocks survive TNT and fireballs
const CHUNK := 16
const MIN_Y := -20
const MAX_Y := 60
# Block ids: 0 air, 1 wool, 2 stone, 3 wood, 4 reinforced, 5 grass, 6 dirt, 7..14 team beds, 15 obsidian, 16 pillow
const COLORS := {
	1: Color(0.90, 0.25, 0.25), 2: Color(0.55, 0.55, 0.58), 3: Color(0.55, 0.38, 0.20),
	4: Color(0.20, 0.30, 0.55), 5: Color(0.30, 0.70, 0.30), 6: Color(0.45, 0.32, 0.20),
	7: Color(0.90, 0.15, 0.15), 8: Color(0.20, 0.75, 0.25), 9: Color(0.20, 0.35, 0.90), 10: Color(0.95, 0.80, 0.15),
	11: Color(1.0, 0.55, 0.10), 12: Color(0.60, 0.25, 0.80), 13: Color(0.10, 0.80, 0.85), 14: Color(1.0, 0.50, 0.70),
	15: Color(0.12, 0.08, 0.20), 16: Color(0.97, 0.97, 0.97),
}
const BREAK_TIME := {1: 0.4, 2: 1.0, 3: 0.7, 4: 2.5, 5: 0.5, 6: 0.4, 7: 2.0, 8: 2.0, 9: 2.0, 10: 2.0,
	11: 2.0, 12: 2.0, 13: 2.0, 14: 2.0, 16: 2.0}
const HEIGHT := {7: 0.56, 8: 0.56, 9: 0.56, 10: 0.56, 11: 0.56, 12: 0.56, 13: 0.56, 14: 0.56, 16: 0.56}
const SHADE := [0.8, 0.8, 1.0, 0.5, 0.9, 0.9]
const FACES := [
	[Vector3i(1, 0, 0), [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)]],
	[Vector3i(-1, 0, 0), [Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 0)]],
	[Vector3i(0, 1, 0), [Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)]],
	[Vector3i(0, -1, 0), [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]],
	[Vector3i(0, 0, 1), [Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1), Vector3(0, 0, 1)]],
	[Vector3i(0, 0, -1), [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)]],
]

var blocks := {}        # Vector3i -> int
var chunk_blocks := {}  # chunk coord -> {Vector3i: true}
var chunk_nodes := {}   # chunk coord -> MeshInstance3D (child StaticBody3D holds collision)
var dirty := {}
var placed := {}        # blocks placed by fighters (return themselves when broken by the player)
var bed_owner := {}     # Vector3i -> team index for both bed cells
var material: StandardMaterial3D

func _ready() -> void:
	material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _make_atlas()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.9

# Procedural 16x16 textures (one tile per block id, tile = id - 1): weave, stone cracks, planks, riveted plate, etc.
func _make_atlas() -> ImageTexture:
	var img := Image.create(16 * 16, 16, false, Image.FORMAT_RGBA8)
	for id in COLORS.keys():
		var tile: int = id - 1
		var base: Color = COLORS[id]
		var rng := RandomNumberGenerator.new()
		rng.seed = 7919 * id
		for y in 16:
			for x in 16:
				var f := 1.0 + rng.randf_range(-0.07, 0.07)
				if id == 1 or (id >= 7 and id <= 14) or id == 16:
					f += 0.07 if (x + y) % 2 == 0 else -0.05
					if x % 4 == 0 or y % 4 == 0:
						f -= 0.04
				elif id == 2:
					if (x * 7 + y * 13) % 23 == 0:
						f -= 0.25
					if rng.randf() < 0.08:
						f -= 0.12
				elif id == 3:
					var row := floori(y / 4.0)
					if y % 4 == 0:
						f -= 0.22
					elif (x + row * 5) % 8 == 0:
						f -= 0.14
					f += sin(float(x) * 0.7 + float(row)) * 0.04
				elif id == 4:
					if x == 0 or y == 0 or x == 15 or y == 15:
						f -= 0.3
					elif x == 1 or y == 1 or x == 14 or y == 14:
						f += 0.14
					if (x == 3 or x == 12) and (y == 3 or y == 12):
						f += 0.35
				elif id == 5:
					f += rng.randf_range(-0.1, 0.1)
					if rng.randf() < 0.12:
						f += 0.18
				elif id == 6:
					if rng.randf() < 0.08:
						f -= 0.3
				elif id == 15:
					if (x + y * 2) % 9 == 0:
						f += 0.9
				img.set_pixel(tile * 16 + x, y, Color(clampf(base.r * f, 0.0, 1.0), clampf(base.g * f, 0.0, 1.0), clampf(base.b * f, 0.0, 1.0), 1.0))
	return ImageTexture.create_from_image(img)

func chunk_of(p: Vector3i) -> Vector3i:
	return Vector3i(floori(p.x / float(CHUNK)), floori(p.y / float(CHUNK)), floori(p.z / float(CHUNK)))

func get_block(p: Vector3i) -> int:
	return blocks.get(p, 0)

func set_block(p: Vector3i, t: int) -> void:
	if p.y < MIN_Y or p.y > MAX_Y:
		return
	var c := chunk_of(p)
	if t == 0:
		if not blocks.has(p):
			return
		blocks.erase(p)
		placed.erase(p)
		bed_owner.erase(p)
		if chunk_blocks.has(c):
			chunk_blocks[c].erase(p)
	else:
		blocks[p] = t
		if not chunk_blocks.has(c):
			chunk_blocks[c] = {}
		chunk_blocks[c][p] = true
	dirty[c] = true
	for n in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		var nc := chunk_of(p + n)
		if nc != c:
			dirty[nc] = true

func break_time(t: int) -> float:
	return BREAK_TIME.get(t, 1.0)

func can_break(p: Vector3i, team: int) -> bool:
	var t := get_block(p)
	if t == 0 or UNBREAKABLE.has(t):
		return false
	if bed_owner.has(p) and bed_owner[p] == team:
		return false   # you can't break your own team's bed
	return true

# Returns -1 if not breakable, 0 if a map block was broken, 1 if a fighter-placed block was broken.
func try_break(p: Vector3i, team: int) -> int:
	if not can_break(p, team):
		return -1
	var t := get_block(p)
	var was_placed := placed.has(p)
	var bed_team: int = bed_owner.get(p, -1)
	set_block(p, 0)
	block_broken.emit(p, t, team, bed_team)
	return 1 if was_placed else 0

func _process(_d: float) -> void:
	if not dirty.is_empty():
		flush()

func flush() -> void:
	for c in dirty.keys():
		_rebuild(c)
	dirty.clear()

func _rebuild(c: Vector3i) -> void:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var tris := PackedVector3Array()
	for p in chunk_blocks.get(c, {}):
		var tid: int = blocks[p]
		var hgt: float = HEIGHT.get(tid, 1.0)
		var tile := tid - 1
		var u0 := (tile * 16 + 0.5) / 256.0
		var u1 := (tile * 16 + 15.5) / 256.0
		for fi in 6:
			var n: Vector3i = FACES[fi][0]
			if blocks.has(p + n):
				var nh: float = HEIGHT.get(blocks[p + n], 1.0)
				if nh >= hgt:
					continue
			var base := verts.size()
			var s: float = SHADE[fi]
			var k := 0
			for v in FACES[fi][1]:
				verts.append(Vector3(p) + Vector3(v.x, v.y * hgt, v.z))
				norms.append(Vector3(n))
				cols.append(Color(s, s, s))
				uvs.append(Vector2(u0 if (k == 0 or k == 1) else u1, 0.97 if (k == 0 or k == 3) else 0.03))
				k += 1
			for q in [0, 2, 1, 0, 3, 2]:
				idx.append(base + q)
			for q2 in [0, 2, 1, 0, 3, 2]:
				tris.append(verts[base + q2])
	if chunk_nodes.has(c):
		chunk_nodes[c].queue_free()
		chunk_nodes.erase(c)
	if verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(tris)
	cs.shape = shape
	body.add_child(cs)
	mi.add_child(body)
	add_child(mi)
	chunk_nodes[c] = mi

# Voxel DDA raycast. Returns {} or {pos: Vector3i, normal: Vector3i, t: entry distance}.
func raycast(o: Vector3, d: Vector3, max_dist: float) -> Dictionary:
	var p := Vector3i(floori(o.x), floori(o.y), floori(o.z))
	var step := Vector3i.ZERO
	var tmax := Vector3(INF, INF, INF)
	var tdelta := Vector3(INF, INF, INF)
	for a in 3:
		if d[a] > 0.0:
			step[a] = 1
			tdelta[a] = 1.0 / d[a]
			tmax[a] = (p[a] + 1 - o[a]) / d[a]
		elif d[a] < 0.0:
			step[a] = -1
			tdelta[a] = -1.0 / d[a]
			tmax[a] = (p[a] - o[a]) / d[a]
	var n := Vector3i.ZERO
	var t_enter := 0.0
	while true:
		if get_block(p) != 0:
			return {"pos": p, "normal": n, "t": t_enter}
		var a := 0
		if tmax.y < tmax[a]:
			a = 1
		if tmax.z < tmax[a]:
			a = 2
		if tmax[a] > max_dist:
			return {}
		t_enter = tmax[a]
		p[a] += step[a]
		n = Vector3i.ZERO
		n[a] = -step[a]
		tmax[a] += tdelta[a]
	return {}
