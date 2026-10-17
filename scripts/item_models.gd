extends RefCounted
# Small multi-part 3D models for held items (tip points toward -Z). Built from boxes/spheres, no assets.

const GD = preload("res://scripts/game_data.gd")

static func _mat(c: Color, metallic: float = 0.0, emissive: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = 0.55
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = c * emissive
	return m

static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, nm: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	if nm != "":
		mi.name = nm
	parent.add_child(mi)
	return mi

static func _ball(parent: Node3D, r: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _seg(parent: Node3D, a: Vector3, b: Vector3, thick: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(thick, thick, a.distance_to(b))
	mi.mesh = bm
	mi.material_override = mat
	mi.position = (a + b) * 0.5
	mi.basis = Basis.looking_at((b - a).normalized(), Vector3.RIGHT)
	parent.add_child(mi)

static func make_arrow() -> Node3D:
	var r := Node3D.new()
	var wood := _mat(Color(0.6, 0.45, 0.25))
	var steel := _mat(Color(0.75, 0.78, 0.82), 0.9)
	var feather := _mat(Color(0.9, 0.9, 0.9))
	_box(r, Vector3(0.014, 0.014, 0.6), Vector3(0, 0, 0), wood)
	_box(r, Vector3(0.035, 0.035, 0.07), Vector3(0, 0, -0.33), steel)
	_box(r, Vector3(0.06, 0.004, 0.1), Vector3(0, 0, 0.26), feather)
	_box(r, Vector3(0.004, 0.06, 0.1), Vector3(0, 0, 0.26), feather)
	return r

static func make(type: int, colors: Dictionary) -> Node3D:
	var root := Node3D.new()
	match type:
		20:   # sword: fuller blade, crossguard, leather grip, pommel
			var blade := _mat(Color(0.82, 0.86, 0.92), 0.95)
			var edge := _mat(Color(0.95, 0.97, 1.0), 0.95)
			var gold := _mat(Color(0.9, 0.72, 0.2), 0.9)
			var leather := _mat(Color(0.35, 0.22, 0.12))
			_box(root, Vector3(0.07, 0.014, 0.5), Vector3(0, 0, -0.36), blade)
			_box(root, Vector3(0.022, 0.02, 0.46), Vector3(0, 0.006, -0.36), edge)
			_box(root, Vector3(0.04, 0.012, 0.07), Vector3(0, 0, -0.64), blade)
			_box(root, Vector3(0.21, 0.035, 0.035), Vector3(0, 0, -0.09), gold)
			_box(root, Vector3(0.03, 0.03, 0.14), Vector3(0, 0, 0.0), leather)
			_box(root, Vector3(0.055, 0.055, 0.04), Vector3(0, 0, 0.09), gold)
		21:   # axe: wooden haft, steel head with bevelled edge
			var wood := _mat(Color(0.5, 0.33, 0.17))
			var steel := _mat(Color(0.7, 0.74, 0.8), 0.9)
			var edge2 := _mat(Color(0.93, 0.95, 1.0), 0.95)
			_box(root, Vector3(0.035, 0.035, 0.62), Vector3(0, 0, -0.2), wood)
			_box(root, Vector3(0.03, 0.2, 0.14), Vector3(0, 0.04, -0.46), steel)
			_box(root, Vector3(0.018, 0.25, 0.04), Vector3(0, 0.04, -0.56), edge2)
			_box(root, Vector3(0.03, 0.07, 0.08), Vector3(0, -0.02, -0.36), steel)
		22:   # golden apple
			var gold2 := _mat(Color(1.0, 0.84, 0.15), 0.8, 0.35)
			_ball(root, 0.09, Vector3.ZERO, gold2)
			_box(root, Vector3(0.012, 0.05, 0.012), Vector3(0, 0.1, 0), _mat(Color(0.35, 0.22, 0.1)))
			_box(root, Vector3(0.05, 0.008, 0.03), Vector3(0.03, 0.115, 0), _mat(Color(0.2, 0.7, 0.2)))
		23:   # TNT
			_box(root, Vector3(0.2, 0.2, 0.2), Vector3.ZERO, _mat(Color(0.82, 0.1, 0.1)))
			_box(root, Vector3(0.212, 0.07, 0.212), Vector3.ZERO, _mat(Color(0.95, 0.95, 0.95)))
			_box(root, Vector3(0.012, 0.05, 0.012), Vector3(0, 0.12, 0), _mat(Color(0.1, 0.1, 0.1)))
		24:   # bow: curved limbs built from segments, taut string, nocked arrow (hidden until drawing)
			var wood2 := _mat(Color(0.5, 0.32, 0.15))
			var pts := [Vector2(0.0, -0.1), Vector2(0.13, -0.085), Vector2(0.26, -0.04), Vector2(0.36, 0.04)]
			for i in range(pts.size() - 1):
				var a: Vector2 = pts[i]
				var b: Vector2 = pts[i + 1]
				_seg(root, Vector3(0, a.x, a.y), Vector3(0, b.x, b.y), 0.03, wood2)
				_seg(root, Vector3(0, -a.x, a.y), Vector3(0, -b.x, b.y), 0.03, wood2)
			_box(root, Vector3(0.04, 0.1, 0.04), Vector3(0, 0, -0.1), _mat(Color(0.25, 0.15, 0.08)))
			_box(root, Vector3(0.006, 0.72, 0.006), Vector3(0, 0, 0.04), _mat(Color(0.95, 0.95, 0.9)), "String")
			var ar := make_arrow()
			ar.name = "Arrow"
			ar.position = Vector3(0, 0, -0.2)
			ar.visible = false
			root.add_child(ar)
		25:   # arrows (bundle)
			for i in 3:
				var a2 := make_arrow()
				a2.position = Vector3((i - 1) * 0.03, 0, 0)
				root.add_child(a2)
		26:   # fireball
			_ball(root, 0.12, Vector3.ZERO, _mat(Color(1.0, 0.45, 0.05), 0.0, 1.2))
			_ball(root, 0.075, Vector3.ZERO, _mat(Color(1.0, 0.9, 0.3), 0.0, 2.0))
		27:   # water bucket
			var steel2 := _mat(Color(0.65, 0.68, 0.75), 0.9)
			_box(root, Vector3(0.16, 0.18, 0.16), Vector3.ZERO, steel2)
			_box(root, Vector3(0.13, 0.02, 0.13), Vector3(0, 0.095, 0), _mat(Color(0.2, 0.5, 1.0), 0.0, 0.6))
			_box(root, Vector3(0.17, 0.012, 0.012), Vector3(0, 0.14, 0), steel2)
		28, 29, 30, 31:   # potion bottles
			var pc: Color = GD.ITEM_COLORS[type]
			_ball(root, 0.07, Vector3(0, -0.03, 0), _mat(pc, 0.1, 0.5))
			_box(root, Vector3(0.04, 0.07, 0.04), Vector3(0, 0.06, 0), _mat(Color(0.85, 0.9, 1.0)))
			_box(root, Vector3(0.05, 0.03, 0.05), Vector3(0, 0.11, 0), _mat(Color(0.5, 0.35, 0.2)))
		_:
			var c: Color = colors.get(type, GD.ITEM_COLORS.get(type, Color.WHITE))
			_box(root, Vector3.ONE * 0.22, Vector3.ZERO, _mat(c))
	return root
