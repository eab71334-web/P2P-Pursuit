class_name CarInterior
extends RefCounted
## Cabin of every car: dash, console, bucket seats, door cards, head-liner, steering wheel and the radio head unit.
## Each model has its own trim colours / seat type / wheel. Car space: -Z forward, seats at x = +-0.45.

const THEMES := {
	"hatch": {"trim": Color(0.16, 0.16, 0.19), "seat": Color(0.22, 0.23, 0.27), "stitch": Color(0.9, 0.25, 0.15), "carpet": Color(0.09, 0.09, 0.1), "lining": Color(0.55, 0.56, 0.6), "seat_kind": "sport", "wheel": "three", "cage": true},
	"buggy": {"trim": Color(0.12, 0.13, 0.11), "seat": Color(0.18, 0.2, 0.14), "stitch": Color(1.0, 0.8, 0.1), "carpet": Color(0.08, 0.08, 0.07), "lining": Color(0.2, 0.22, 0.18), "seat_kind": "bucket", "wheel": "three", "cage": true},
	"muscle": {"trim": Color(0.05, 0.05, 0.06), "seat": Color(0.07, 0.07, 0.08), "stitch": Color(1.0, 0.8, 0.1), "carpet": Color(0.06, 0.06, 0.07), "lining": Color(0.12, 0.12, 0.14), "seat_kind": "sport", "wheel": "classic", "cage": false},
	"sierra": {"trim": Color(0.2, 0.2, 0.23), "seat": Color(0.3, 0.3, 0.34), "stitch": Color(0.75, 0.75, 0.8), "carpet": Color(0.12, 0.12, 0.14), "lining": Color(0.62, 0.62, 0.66), "seat_kind": "sport", "wheel": "classic", "cage": false},
	"pickup": {"trim": Color(0.2, 0.17, 0.13), "seat": Color(0.38, 0.3, 0.2), "stitch": Color(0.85, 0.75, 0.55), "carpet": Color(0.1, 0.09, 0.08), "lining": Color(0.6, 0.55, 0.45), "seat_kind": "bench", "wheel": "three", "cage": false},
	"charger": {"trim": Color(0.04, 0.04, 0.05), "seat": Color(0.06, 0.06, 0.07), "stitch": Color(0.9, 0.1, 0.1), "carpet": Color(0.05, 0.05, 0.06), "lining": Color(0.1, 0.1, 0.11), "seat_kind": "sport", "wheel": "classic", "cage": false},
	"coupe": {"trim": Color(0.06, 0.06, 0.08), "seat": Color(0.08, 0.08, 0.1), "stitch": Color(0.7, 0.7, 0.75), "carpet": Color(0.05, 0.05, 0.06), "lining": Color(0.1, 0.1, 0.12), "seat_kind": "sport", "wheel": "sport", "cage": false},
	"m4": {"trim": Color(0.05, 0.05, 0.07), "seat": Color(0.07, 0.08, 0.14), "stitch": Color(0.3, 0.55, 1.0), "carpet": Color(0.04, 0.04, 0.06), "lining": Color(0.08, 0.08, 0.1), "seat_kind": "sport", "wheel": "sport", "cage": false},
	"gt3": {"trim": Color(0.03, 0.03, 0.04), "seat": Color(0.04, 0.04, 0.05), "stitch": Color(0.95, 0.1, 0.1), "carpet": Color(0.03, 0.03, 0.04), "lining": Color(0.05, 0.05, 0.06), "seat_kind": "race", "wheel": "race", "cage": true},
	"hyper": {"trim": Color(0.05, 0.04, 0.04), "seat": Color(0.07, 0.05, 0.04), "stitch": Color(1.0, 0.5, 0.08), "carpet": Color(0.04, 0.035, 0.03), "lining": Color(0.07, 0.06, 0.05), "seat_kind": "race", "wheel": "race", "cage": false},
}


static func theme(model: String) -> Dictionary:
	return THEMES.get(model, THEMES["hatch"])


static func _m(c: Color, metal := 0.0, rough := 0.7, emit := 0.0) -> StandardMaterial3D:
	return CarStyle.mat(c, metal, rough, emit)


static func _bx(p: Node, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	return CarStyle.box(p, size, pos, m, rot)


## everything except the steering wheel and the radio (those have their own builders)
static func build(car: Node3D, model: String, sd: float, drop: float) -> void:
	var th := theme(model)
	var trim := _m(th["trim"], 0.0, 0.85)
	var soft := _m((th["trim"] as Color).lightened(0.08), 0.0, 0.95)
	var seat := _m(th["seat"], 0.0, 0.9)
	var stitch := _m(th["stitch"], 0.0, 0.7, 0.25)
	var chrome := _m(Color(0.82, 0.85, 0.9), 0.95, 0.2)
	var dark := _m(Color(0.02, 0.02, 0.03), 0.3, 0.6)
	var rt := 1.95 - drop

	# ---- dashboard: soft pad, binnacle hood, vents, glove box, accent stitching
	_bx(car, Vector3(1.86, 0.06, 0.88), Vector3(0, 1.17, -1.2), soft)
	_bx(car, Vector3(1.84, 0.02, 0.02), Vector3(0, 1.205, -0.78), stitch)
	_bx(car, Vector3(0.66, 0.03, 0.26), Vector3(-0.45, 1.53, -1.06), trim, Vector3(-18, 0, 0))   # visor over the gauges
	for sx in [-0.78, -0.12]:
		_bx(car, Vector3(0.03, 0.2, 0.22), Vector3(sx, 1.4, -1.04), trim, Vector3(-18, 0, 0))   # binnacle cheeks
	for sx in [-0.02, 0.5, 0.82]:
		_bx(car, Vector3(0.18, 0.06, 0.02), Vector3(sx, 1.1, -0.755), dark)
		for k in 3:
			_bx(car, Vector3(0.17, 0.004, 0.022), Vector3(sx, 1.085 + k * 0.02, -0.757), chrome)
	_bx(car, Vector3(0.5, 0.2, 0.03), Vector3(0.62, 0.99, -0.745), soft)                          # glove box lid
	_bx(car, Vector3(0.08, 0.02, 0.035), Vector3(0.62, 1.07, -0.74), chrome)
	# ---- centre console + shifter + handbrake
	_bx(car, Vector3(0.3, 0.2, 1.2), Vector3(0, 0.98 - sd * 0.2, 0.0 + 0.1), trim)
	_bx(car, Vector3(0.28, 0.02, 1.0), Vector3(0, 1.09 - sd * 0.2, 0.1), soft)
	_bx(car, Vector3(0.012, 0.02, 1.0), Vector3(0.12, 1.1 - sd * 0.2, 0.1), stitch)
	_bx(car, Vector3(0.012, 0.02, 1.0), Vector3(-0.12, 1.1 - sd * 0.2, 0.1), stitch)
	var shift_y := 1.1 - sd * 0.2
	if th["seat_kind"] == "race":
		_bx(car, Vector3(0.12, 0.03, 0.18), Vector3(0, shift_y, 0.05), dark)                    # sequential gate
		_bx(car, Vector3(0.03, 0.18, 0.03), Vector3(0, shift_y + 0.09, 0.05), chrome, Vector3(-15, 0, 0))
		_bx(car, Vector3(0.05, 0.04, 0.05), Vector3(0, shift_y + 0.19, 0.03), _m(th["stitch"], 0.0, 0.6, 0.4))
	else:
		CarStyle.cyl(car, 0.012, 0.2, Vector3(0, shift_y + 0.1, 0.0), chrome)
		var kn := CarStyle.cyl(car, 0.032, 0.06, Vector3(0, shift_y + 0.22, 0.0), _m(Color(0.05, 0.05, 0.06), 0.2, 0.5))
		kn.scale = Vector3(1, 1, 1)
		_bx(car, Vector3(0.1, 0.012, 0.1), Vector3(0, shift_y + 0.005, 0.0), dark)
	_bx(car, Vector3(0.05, 0.05, 0.3), Vector3(0.0, shift_y + 0.04, 0.42), chrome, Vector3(-12, 0, 0))   # handbrake
	_bx(car, Vector3(0.07, 0.05, 0.08), Vector3(0.0, shift_y + 0.08, 0.55), dark)
	# ---- floor carpet + mats + pedals
	_bx(car, Vector3(1.8, 0.04, 2.0), Vector3(0, 0.915, -0.1), _m(th["carpet"], 0.0, 1.0))
	for sx in [-0.45]:
		_bx(car, Vector3(0.12, 0.06, 0.02), Vector3(sx - 0.16, 1.0, -0.74), dark, Vector3(-25, 0, 0))   # brake
		_bx(car, Vector3(0.09, 0.07, 0.02), Vector3(sx + 0.0, 1.0, -0.74), dark, Vector3(-25, 0, 0))    # clutch / dead pedal
		_bx(car, Vector3(0.1, 0.1, 0.02), Vector3(sx + 0.17, 1.02, -0.74), chrome, Vector3(-25, 0, 0))  # throttle
	# ---- seats
	for x in [-0.45, 0.45]:
		_seat(car, th, Vector3(x, 0.0, 0.0), sd, drop, seat, stitch, dark)
	# rear bench (visible from outside / through the back window)
	_bx(car, Vector3(1.6, 0.12, 0.5), Vector3(0, 0.98 - sd, 1.05), seat)
	_bx(car, Vector3(1.6, 0.45, 0.1), Vector3(0, 1.25 - sd, 1.3), seat)
	# ---- door cards (inner side of the doors), armrest, handle, speaker, window switches
	for sx in [-1.0, 1.0]:
		var x: float = sx * 0.885
		_bx(car, Vector3(0.04, 0.46, 1.9), Vector3(x, 1.12, 0.35), trim)
		_bx(car, Vector3(0.05, 0.015, 1.9), Vector3(x, 1.34, 0.35), stitch)
		_bx(car, Vector3(0.09, 0.07, 0.8), Vector3(sx * 0.84, 1.14, 0.1), soft)                    # armrest
		_bx(car, Vector3(0.05, 0.04, 0.24), Vector3(sx * 0.85, 1.24, 0.75), chrome)                # door pull
		_bx(car, Vector3(0.012, 0.16, 0.3), Vector3(sx * 0.862, 1.16, 0.88), dark)                 # speaker grille
		for k in 3:
			_bx(car, Vector3(0.02, 0.025, 0.05), Vector3(sx * 0.845, 1.185, -0.28 + k * 0.07), chrome)
		# pillar trims
		_bx(car, Vector3(0.05, 0.05, 0.05), Vector3(sx * 0.85, 1.36, -1.1), trim)
	# ---- head-liner, visors, grab handle
	var lin := _m(th["lining"], 0.0, 1.0)
	var gh: Dictionary = CarStyle.GREENHOUSE.get(model, CarStyle.GREENHOUSE["hatch"])
	var zf: float = gh["zf1"] - drop * 0.3
	var zr: float = gh["zr1"] + drop * 0.2
	var hw: float = gh["hwt"] - 0.04
	_bx(car, Vector3(hw * 2.0, 0.025, zr - zf), Vector3(0, rt - 0.03, (zf + zr) * 0.5), lin)
	for sx in [-0.45, 0.45]:
		_bx(car, Vector3(0.4, 0.015, 0.2), Vector3(sx, rt - 0.06, zf + 0.12), trim)               # sun visors
	_bx(car, Vector3(0.04, 0.04, 0.2), Vector3(0.78 if hw > 0.74 else 0.7, rt - 0.08, 0.2), trim)    # grab handle
	# ---- cage / bars
	if th["cage"]:
		var tube := _m(Color(0.1, 0.1, 0.12), 0.6, 0.4)
		var top := rt - 0.1
		for sx in [-0.78, 0.78]:
			CarStyle.beam(car, Vector3(sx, 1.25, 0.75), Vector3(sx, top, 0.45), 0.05, tube)
			CarStyle.beam(car, Vector3(sx, top, 0.45), Vector3(sx, top, -0.35), 0.05, tube)
			CarStyle.beam(car, Vector3(sx, 1.0, 1.2), Vector3(sx, top, 0.5), 0.045, tube)
		CarStyle.beam(car, Vector3(-0.78, top, 0.45), Vector3(0.78, top, 0.45), 0.05, tube)
		CarStyle.beam(car, Vector3(-0.78, top, -0.35), Vector3(0.78, top, -0.35), 0.05, tube)


static func _seat(car: Node3D, th: Dictionary, o: Vector3, sd: float, drop: float, seat: Material, stitch: Material, dark: Material) -> void:
	var kind: String = th["seat_kind"]
	var x := o.x
	var base_y := 0.98 - sd
	var back_y := 1.3 - sd
	var shell: Material = _m(Color(0.04, 0.04, 0.05), 0.5, 0.35) if kind == "race" else seat
	var wing := 0.08 if kind == "bench" else (0.16 if kind == "race" else 0.12)
	# cushion + bolsters
	_bx(car, Vector3(0.46, 0.12, 0.55), Vector3(x, base_y, 0.3), seat)
	for sx in [-1.0, 1.0]:
		_bx(car, Vector3(0.07, 0.16, 0.5), Vector3(x + sx * 0.24, base_y + 0.04, 0.3), shell)
	_bx(car, Vector3(0.1, 0.012, 0.5), Vector3(x, base_y + 0.065, 0.3), stitch)
	# back + side wings
	_bx(car, Vector3(0.46, 0.75, 0.1), Vector3(x, back_y, 0.68), seat)
	for sx in [-1.0, 1.0]:
		_bx(car, Vector3(0.08, 0.55, 0.2 + wing), Vector3(x + sx * 0.25, back_y - 0.05, 0.6 - wing * 0.3), shell)
	_bx(car, Vector3(0.1, 0.6, 0.012), Vector3(x, back_y, 0.628), stitch)
	# headrest (integrated for race seats)
	if kind == "race":
		_bx(car, Vector3(0.38, 0.2, 0.1), Vector3(x, back_y + 0.44, 0.7), shell)
		for sx in [-1.0, 1.0]:
			_bx(car, Vector3(0.07, 0.22, 0.2), Vector3(x + sx * 0.2, back_y + 0.42, 0.62), shell)
		# 4-point harness
		var red := _m(Color(0.85, 0.08, 0.08), 0.0, 0.8, 0.2)
		for sx in [-1.0, 1.0]:
			CarStyle.beam(car, Vector3(x + sx * 0.13, back_y + 0.36, 0.64), Vector3(x + sx * 0.1, back_y + 0.0, 0.58), 0.045, red)
		_bx(car, Vector3(0.28, 0.04, 0.03), Vector3(x, base_y + 0.1, 0.12), red)
	else:
		_bx(car, Vector3(0.28, 0.17, 0.1), Vector3(x, back_y + 0.47, 0.72), seat)
		_bx(car, Vector3(0.12, 0.012, 0.1), Vector3(x, back_y + 0.47, 0.67), stitch)
		for sx in [-0.09, 0.09]:
			_bx(car, Vector3(0.02, 0.12, 0.02), Vector3(x + sx, back_y + 0.35, 0.72), _m(Color(0.7, 0.72, 0.78), 0.9, 0.3))


## the steering wheel, built into the car's existing wheel pivot (same hand radius)
static func wheel(mesh_root: Node3D, model: String) -> void:
	for c in mesh_root.get_children():
		c.queue_free()
	var th := theme(model)
	var grip := _m(Color(0.03, 0.03, 0.04), 0.0, 0.8)
	var acc := _m(th["stitch"], 0.0, 0.6, 0.35)
	var chrome := _m(Color(0.8, 0.82, 0.88), 0.95, 0.2)
	var wood := _m(Color(0.35, 0.22, 0.1), 0.2, 0.5)
	match th["wheel"]:
		"classic":
			_ring(mesh_root, 0.15, 0.022, wood if model == "sierra" else grip)
			_ring(mesh_root, 0.115, 0.007, chrome)                                              # horn ring
			_bx(mesh_root, Vector3(0.28, 0.025, 0.03), Vector3.ZERO, chrome)
			_bx(mesh_root, Vector3(0.03, 0.025, 0.14), Vector3(0, 0, 0.07), chrome)
			CarStyle.cyl(mesh_root, 0.045, 0.03, Vector3.ZERO, _m(Color(0.04, 0.04, 0.05), 0.5, 0.3))
		"three":
			_ring(mesh_root, 0.15, 0.024, grip)
			_bx(mesh_root, Vector3(0.28, 0.028, 0.035), Vector3(0, 0, 0.0), grip)
			_bx(mesh_root, Vector3(0.035, 0.028, 0.14), Vector3(0, 0, 0.07), grip)
			CarStyle.cyl(mesh_root, 0.05, 0.034, Vector3.ZERO, _m(Color(0.05, 0.05, 0.06), 0.4, 0.4))
			_bx(mesh_root, Vector3(0.04, 0.03, 0.012), Vector3(0, 0, -0.15), acc)
		"sport":
			_ring(mesh_root, 0.15, 0.026, grip)
			_bx(mesh_root, Vector3(0.34, 0.035, 0.05), Vector3(0, 0, 0.1), grip)                 # flat bottom
			_bx(mesh_root, Vector3(0.3, 0.03, 0.045), Vector3(0, 0, 0.0), grip)
			_bx(mesh_root, Vector3(0.045, 0.03, 0.04), Vector3(0, 0, -0.15), acc)                # 12 o'clock marker
			CarStyle.cyl(mesh_root, 0.05, 0.034, Vector3.ZERO, _m(Color(0.04, 0.04, 0.05), 0.5, 0.3))
			for sx in [-0.17, 0.17]:
				_bx(mesh_root, Vector3(0.012, 0.05, 0.1), Vector3(sx, -0.045, 0.0), chrome)       # paddles behind the rim
		_:   # race wheel: rectangular, LED strip, buttons
			_bx(mesh_root, Vector3(0.32, 0.035, 0.2), Vector3(0, 0, 0.0), _m(Color(0.04, 0.04, 0.05), 0.3, 0.5))
			for sx in [-1.0, 1.0]:
				_bx(mesh_root, Vector3(0.05, 0.04, 0.24), Vector3(sx * 0.17, 0, 0.0), grip)
			_bx(mesh_root, Vector3(0.18, 0.04, 0.09), Vector3(0, 0, -0.01), _m(Color(0.02, 0.03, 0.05), 0.0, 0.3, 0.6))   # screen
			for k in 7:
				var cc := Color(0.1, 1.0, 0.3) if k < 3 else (Color(1.0, 0.8, 0.1) if k < 5 else Color(1.0, 0.1, 0.1))
				_bx(mesh_root, Vector3(0.018, 0.045, 0.012), Vector3(-0.06 + k * 0.02, 0, -0.095), _m(cc, 0.0, 0.4, 1.0))
			for sx in [-0.1, 0.1]:
				for sz in [-0.02, 0.05]:
					CarStyle.cyl(mesh_root, 0.012, 0.045, Vector3(sx, 0, sz + 0.0), _m(Color(0.1, 0.4, 1.0) if sx < 0 else Color(1.0, 0.3, 0.1), 0.0, 0.5, 0.4))
			for sx in [-0.17, 0.17]:
				_bx(mesh_root, Vector3(0.012, 0.05, 0.12), Vector3(sx * 1.1, -0.05, 0.0), chrome)


static func _ring(parent: Node3D, outer: float, thick: float, m: Material) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = outer - thick
	torus.outer_radius = outer
	torus.rings = 16
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = m
	parent.add_child(ring)


## radio head unit on the console. Returns [station label, sub label]
static func radio(car: Node3D, model: String) -> Array:
	var th := theme(model)
	var accent: Color = th["stitch"]
	var amb := Color(1.0, 0.6, 0.15)
	if model in ["coupe", "m4", "gt3"]:
		amb = Color(0.5, 0.8, 1.0)
	elif model == "charger":
		amb = Color(1.0, 0.2, 0.2)
	var body := _m(Color(0.03, 0.03, 0.04), 0.5, 0.35)
	var chrome := _m(Color(0.78, 0.8, 0.86), 0.95, 0.2)
	var u := Node3D.new()
	u.position = Vector3(0.0, 1.03, -0.28)
	u.rotation_degrees.x = -22.0
	car.add_child(u)
	_bx(u, Vector3(0.3, 0.06, 0.14), Vector3.ZERO, body)                                       # housing
	_bx(u, Vector3(0.31, 0.008, 0.15), Vector3(0, 0.032, 0), chrome)                           # bezel
	_bx(u, Vector3(0.18, 0.004, 0.07), Vector3(0, 0.036, -0.02), _m(Color(0.01, 0.02, 0.03), 0.0, 0.2))   # glass screen
	_bx(u, Vector3(0.185, 0.003, 0.0015), Vector3(0, 0.037, 0.016), _m(amb, 0.0, 0.5, 1.2))      # accent line under the screen
	for sx in [-0.115, 0.115]:                                                                 # volume / tuning knobs (knurled look)
		CarStyle.cyl(u, 0.024, 0.02, Vector3(sx, 0.04, -0.02), chrome)
		CarStyle.cyl(u, 0.017, 0.022, Vector3(sx, 0.041, -0.02), _m(Color(0.05, 0.05, 0.06), 0.4, 0.4))
		_bx(u, Vector3(0.003, 0.004, 0.012), Vector3(sx, 0.053, -0.03), _m(amb, 0.0, 0.5, 1.0))
	for k in 6:                                                                                # preset buttons
		_bx(u, Vector3(0.022, 0.006, 0.014), Vector3(-0.0625 + k * 0.025, 0.036, 0.05), _m(Color(0.12, 0.12, 0.14), 0.4, 0.4))
	var lab := Label3D.new()
	lab.text = "FM"
	lab.font_size = 44
	lab.pixel_size = 0.0019
	lab.modulate = amb
	lab.shaded = false
	lab.rotation_degrees.x = -90.0
	lab.position = Vector3(0, 0.0385, -0.034)
	u.add_child(lab)
	var sub := Label3D.new()
	sub.text = ""
	sub.font_size = 28
	sub.pixel_size = 0.0014
	sub.modulate = amb.lightened(0.4)
	sub.shaded = false
	sub.rotation_degrees.x = -90.0
	sub.position = Vector3(0, 0.0385, -0.004)
	u.add_child(sub)
	return [lab, sub]
