class_name CarStyle
extends RefCounted
## Builds the exterior details of every car model (blocky but race-car looking).
## Car space: -Z is forward, the cabin / collision stay identical for all models.

const CHROME := Color(0.82, 0.85, 0.9)
const CARBON := Color(0.07, 0.07, 0.09)


static func mat(c: Color, metal := 0.0, rough := 0.6, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


static func box(parent: Node, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


static func cyl(parent: Node, radius: float, height: float, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 14
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


## a tube between two points
static func beam(parent: Node, a: Vector3, b: Vector3, th: float, m: Material) -> MeshInstance3D:
	var d := b - a
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(th, th, d.length())
	mi.mesh = bm
	mi.material_override = m
	var up := Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.97 else Vector3.RIGHT
	mi.transform = Transform3D(Basis.looking_at(d, up), (a + b) * 0.5)
	parent.add_child(mi)
	return mi


## wheel with tyre, rim and spokes. The axle is the local X axis.
static func make_wheel(parent: Node, rim_col: Color, model: String) -> void:
	var width := 0.34
	if model == "buggy" or model == "muscle" or model == "hyper":
		width = 0.42
	if model == "pickup":
		width = 0.38
	var gear := Node3D.new()
	gear.rotation_degrees = Vector3(0, 0, 90)
	parent.add_child(gear)
	var tyre_m := mat(Color(0.04, 0.04, 0.05), 0.0, 0.9)
	cyl(gear, 0.4, width, Vector3.ZERO, tyre_m)
	var rim_m := mat(rim_col, 0.85, 0.25)
	var rim_r := 0.27 if model != "pickup" else 0.24
	cyl(gear, rim_r, width + 0.02, Vector3.ZERO, rim_m)
	var dark := mat(Color(0.06, 0.06, 0.08), 0.0, 0.8)
	cyl(gear, rim_r * 0.82, width + 0.025, Vector3.ZERO, dark)
	for k in 5:
		var s := box(gear, Vector3(rim_r * 1.7, width + 0.03, 0.055), Vector3.ZERO, rim_m)
		s.rotation_degrees.y = k * 36.0
	cyl(gear, 0.06, width + 0.05, Vector3.ZERO, mat(CHROME, 0.9, 0.2))
	if model == "pickup" or model == "buggy":    # chunky tread blocks
		for k in 10:
			var a := TAU * k / 10.0
			box(gear, Vector3(0.1, width * 0.96, 0.06), Vector3(cos(a) * 0.4, 0.0, sin(a) * 0.4), tyre_m, Vector3(0, -rad_to_deg(a), 0))


static func decorate(car: Node3D, model: String, lo: Dictionary, body_mat: StandardMaterial3D, team_col: Color) -> void:
	var dark := mat(CARBON, 0.3, 0.5)
	var chrome := mat(CHROME, 0.95, 0.15)
	var glass := mat(Color(0.35, 0.55, 0.75, 0.22), 0.0, 0.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var head := mat(Color(1.0, 0.97, 0.8), 0.0, 0.3, 2.5)
	var tail := mat(Color(1.0, 0.1, 0.08), 0.0, 0.3, 2.2)
	var accent_col: Color = Catalog.STRIPES.get(lo.get("stripe", "none"), Catalog.STRIPES["none"])["c"]
	var hood: Node3D = car.get("_hood_pivot")

	# --- glass: slanted windshield, rear window, side windows
	box(car, Vector3(1.74, 0.03, 0.9), Vector3(0, 1.58, -0.9), glass, Vector3(-33.7, 0, 0))
	box(car, Vector3(1.74, 0.02, 0.62), Vector3(0, 1.64, 1.38), glass, Vector3(80, 0, 0))
	for sx in [-0.93, 0.93]:
		box(car, Vector3(0.02, 0.5, 1.9), Vector3(sx, 1.58, 0.35), glass)
	# slanted A pillars + C pillars (body colour)
	for sx in [-0.9, 0.9]:
		beam(car, Vector3(sx, 1.2, -1.15), Vector3(sx, 1.95, -0.65), 0.12, body_mat)
		beam(car, Vector3(sx, 1.33, 1.4), Vector3(sx, 1.95, 1.3), 0.14, body_mat)
	# --- lights, grille, handles, mirrors, exhaust
	for sx in [-0.68, 0.68]:
		box(car, Vector3(0.4, 0.17, 0.07), Vector3(sx, 0.95, -2.06), head)
		box(car, Vector3(0.5, 0.15, 0.06), Vector3(sx, 0.8, 2.04), tail)
	box(car, Vector3(0.75, 0.16, 0.06), Vector3(0, 0.9, -2.06), dark)
	box(car, Vector3(0.75, 0.025, 0.07), Vector3(0, 0.9, -2.07), chrome)
	for sx in [-1.0, 1.0]:
		box(car, Vector3(0.06, 0.06, 0.28), Vector3(sx * 0.98, 1.2, 0.2), chrome)               # door handles
		box(car, Vector3(0.1, 0.12, 0.2), Vector3(sx * 1.08, 1.5, -0.7), body_mat)               # mirrors
		box(car, Vector3(0.14, 0.03, 0.03), Vector3(sx * 1.0, 1.45, -0.7), dark)
		cyl(car, 0.07, 0.3, Vector3(sx * 0.5, 0.4, 2.15), chrome, Vector3(90, 0, 0))                 # exhaust
		box(car, Vector3(0.05, 0.22, 2.2 if model != "coupe" and model != "hyper" else 2.4), Vector3(sx * 0.98, 0.42, 0.0), dark)   # side skirt
	# team plate on the roof and doors (the paint can be anything, the team stays recognisable)
	var tm := mat(team_col, 0.0, 0.6, 0.6)
	box(car, Vector3(0.9, 0.012, 0.9), Vector3(0, 1.962, 0.35), tm)
	for sx in [-1.0, 1.0]:
		box(car, Vector3(0.03, 0.34, 0.34), Vector3(sx * 1.01, 1.1, 0.4), tm)
	# --- stripes
	if lo.get("stripe", "none") != "none":
		var sm := mat(accent_col, 0.2, 0.4, 0.15)
		for sx in [-0.14, 0.14]:
			if hood:
				box(hood, Vector3(0.16, 0.012, 0.98), Vector3(sx, 0.012, -0.49), sm)
			box(car, Vector3(0.16, 0.012, 2.0), Vector3(sx, 1.97, 0.35), sm)
			box(car, Vector3(0.16, 0.012, 0.6), Vector3(sx, 0.885, 1.7), sm)
		for sx in [-1.0, 1.0]:
			box(car, Vector3(0.03, 0.05, 3.7), Vector3(sx * 0.96, 0.7, 0.0), sm)
	# --- underglow
	var gc: Color = Catalog.GLOWS.get(lo.get("glow", "none"), Catalog.GLOWS["none"])["c"]
	if lo.get("glow", "none") != "none":
		box(car, Vector3(1.7, 0.02, 3.7), Vector3(0, 0.2, 0), mat(gc, 0.0, 0.5, 4.0))
		var ol := OmniLight3D.new()
		ol.position = Vector3(0, 0.25, 0)
		ol.omni_range = 5.5
		ol.light_energy = 1.4
		ol.light_color = gc
		car.add_child(ol)

	# --- model specific parts
	match model:
		"hatch":
			box(car, Vector3(0.4, 0.1, 0.5), Vector3(0, 2.03, -0.25), dark)                          # roof intake
			for sx in [-0.7, 0.7]:
				box(car, Vector3(0.08, 0.5, 0.1), Vector3(sx, 1.15, 1.9), dark)
			box(car, Vector3(1.9, 0.06, 0.5), Vector3(0, 1.45, 1.92), body_mat)                      # rally wing
			for sx in [-0.78, 0.78]:
				box(car, Vector3(0.04, 0.2, 0.5), Vector3(sx + (0.1 if sx < 0 else -0.1) * 0 + (-0.1 if sx < 0 else 0.1), 1.5, 1.92), dark)
			for sx in [-0.45, -0.15, 0.15, 0.45]:                                                    # rally lights
				cyl(car, 0.1, 0.08, Vector3(sx, 0.62, -2.12), head, Vector3(90, 0, 0))
			for sx in [-1.0, 1.0]:
				box(car, Vector3(0.04, 0.2, 0.3), Vector3(sx * 0.95, 0.35, 1.7), dark)               # mud flaps
		"buggy":
			var tube := mat(Color(0.12, 0.12, 0.14), 0.7, 0.35)
			for sx in [-0.9, 0.9]:
				beam(car, Vector3(sx, 1.95, -0.65), Vector3(sx, 2.35, 0.35), 0.07, tube)
				beam(car, Vector3(sx, 2.35, 0.35), Vector3(sx, 1.95, 1.35), 0.07, tube)
			box(car, Vector3(1.8, 0.07, 0.07), Vector3(0, 2.35, 0.35), tube)
			box(car, Vector3(1.6, 0.1, 0.12), Vector3(0, 2.45, 0.1), mat(Color(1, 1, 0.9), 0.0, 0.3, 3.0))   # light bar
			cyl(car, 0.4, 0.32, Vector3(0, 1.0, 2.3), mat(Color(0.04, 0.04, 0.05), 0.0, 0.9), Vector3(90, 0, 0))   # spare tyre
			cyl(car, 0.22, 0.34, Vector3(0, 1.0, 2.3), mat(CHROME, 0.9, 0.3), Vector3(90, 0, 0))
			for sx in [-1.06, 1.06]:
				for sz in [-1.3, 1.3]:
					box(car, Vector3(0.2, 0.1, 1.0), Vector3(sx, 0.9, sz), body_mat)
			box(car, Vector3(1.9, 0.14, 0.3), Vector3(0, 0.45, -2.25), dark)                        # skid plate
		"muscle":
			if hood:
				box(hood, Vector3(0.6, 0.14, 0.55), Vector3(0, 0.1, -0.45), dark)
				for k in 4:
					box(hood, Vector3(0.5, 0.02, 0.04), Vector3(0, 0.18, -0.3 - k * 0.1), chrome)
			box(car, Vector3(1.95, 0.22, 0.14), Vector3(0, 0.5, -2.13), chrome)                      # chrome bumpers
			box(car, Vector3(1.95, 0.22, 0.14), Vector3(0, 0.5, 2.13), chrome)
			box(car, Vector3(1.7, 0.1, 0.4), Vector3(0, 0.97, 1.9), body_mat)                        # ducktail
			for sx in [-1.06, 1.06]:
				for sz in [-1.3, 1.3]:
					box(car, Vector3(0.16, 0.1, 0.95), Vector3(sx, 0.86, sz), body_mat)
				cyl(car, 0.06, 1.0, Vector3(sx * 1.0, 0.3, 0.5), chrome, Vector3(90, 0, 0))          # side pipes
		"pickup":
			for sx in [-0.55, 0.55]:
				box(car, Vector3(0.08, 0.6, 0.08), Vector3(sx, 0.85, -2.2), chrome)
			box(car, Vector3(1.5, 0.08, 0.08), Vector3(0, 1.1, -2.2), chrome)                        # bull bar
			box(car, Vector3(1.5, 0.08, 0.08), Vector3(0, 0.62, -2.2), chrome)
			box(car, Vector3(1.4, 0.1, 0.14), Vector3(0, 2.05, -0.5), mat(Color(1, 1, 0.9), 0.0, 0.3, 3.0))   # roof lights
			for sx in [-0.92, 0.92]:
				box(car, Vector3(0.07, 0.3, 0.65), Vector3(sx, 1.05, 1.7), body_mat)                 # bed rails
				box(car, Vector3(0.12, 0.06, 0.05), Vector3(sx, 1.2, 1.45), dark)
			box(car, Vector3(1.9, 0.3, 0.07), Vector3(0, 1.05, 2.03), body_mat)                      # tailgate
			box(car, Vector3(1.75, 0.07, 0.07), Vector3(0, 1.5, 1.45), chrome)                       # roll bar
			cyl(car, 0.05, 0.9, Vector3(0.97, 1.45, -0.9), dark)                                     # snorkel
			for sx in [-1.04, 1.04]:
				for sz in [-1.3, 1.3]:
					box(car, Vector3(0.14, 0.1, 0.95), Vector3(sx, 0.9, sz), dark)
		"coupe":
			box(car, Vector3(1.95, 0.05, 0.4), Vector3(0, 0.36, -2.18), dark)                        # splitter
			box(car, Vector3(1.9, 0.05, 0.4), Vector3(0, 0.38, 2.18), dark)                          # diffuser
			for sx in [-0.6, -0.3, 0, 0.3, 0.6]:
				box(car, Vector3(0.03, 0.2, 0.4), Vector3(sx, 0.45, 2.18), dark)
			for sx in [-0.7, 0.7]:
				box(car, Vector3(0.07, 0.45, 0.1), Vector3(sx, 1.12, 1.9), body_mat)
			box(car, Vector3(1.9, 0.05, 0.5), Vector3(0, 1.38, 1.95), dark)                          # GT wing
			for sx in [-0.95, 0.95]:
				box(car, Vector3(0.05, 0.2, 0.5), Vector3(sx, 1.42, 1.95), dark)
			box(car, Vector3(1.8, 0.02, 2.0), Vector3(0, 1.975, 0.35), mat(CARBON, 0.6, 0.3))        # carbon roof
			if hood:
				for k in 3:
					box(hood, Vector3(0.35, 0.02, 0.05), Vector3(sx_of(k), 0.06, -0.6), dark)
		"hyper":
			for sx in [-1.08, 1.08]:
				for sz in [-1.3, 1.3]:
					box(car, Vector3(0.22, 0.12, 1.05), Vector3(sx, 0.85, sz), mat(CARBON, 0.5, 0.3))   # wide-body
			box(car, Vector3(0.05, 0.3, 1.2), Vector3(0, 2.1, 0.8), body_mat)                       # shark fin
			for sx in [-0.7, 0.7]:
				box(car, Vector3(0.08, 0.6, 0.1), Vector3(sx, 1.2, 1.95), dark)
			box(car, Vector3(2.0, 0.06, 0.65), Vector3(0, 1.55, 1.95), mat(CARBON, 0.6, 0.3))       # big wing
			for sx in [-1.0, 1.0]:
				box(car, Vector3(0.04, 0.35, 0.7), Vector3(sx, 1.55, 1.95), body_mat)               # end plates
				box(car, Vector3(0.35, 0.04, 0.25), Vector3(sx * 0.85, 0.5, -2.25), dark)          # canards
			box(car, Vector3(1.95, 0.05, 0.45), Vector3(0, 0.36, -2.22), mat(CARBON, 0.6, 0.3))
			box(car, Vector3(0.03, 0.02, 3.6), Vector3(0, 1.975, 0.0), mat(Color(1.0, 0.8, 0.2), 0.9, 0.2))   # gold line
			if hood:
				for k in 3:
					box(hood, Vector3(0.3, 0.02, 0.06), Vector3(-0.5 + k * 0.5 - 0.0, 0.06, -0.55), dark)


static func sx_of(k: int) -> float:
	return -0.5 + k * 0.5
