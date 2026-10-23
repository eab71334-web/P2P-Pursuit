# Copyright (c) 2026 AVF. All rights reserved. See LICENSE.
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
static func make_wheel(parent: Node, rim_col: Color, model: String, style := "") -> void:
	if style == "":
		style = Catalog.wheel_style(model, "stock")
	var width := 0.34
	if model in ["buggy","muscle","hyper","gt3","charger","m4"]:
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
	_wheel_face(gear, style, rim_r, width, rim_m, dark)
	if model == "pickup" or model == "buggy":    # chunky tread blocks
		for k in 10:
			var a := TAU * k / 10.0
			box(gear, Vector3(0.1, width * 0.96, 0.06), Vector3(cos(a) * 0.4, 0.0, sin(a) * 0.4), tyre_m, Vector3(0, -rad_to_deg(a), 0))


## the wheel face: every design is a different real-world pattern
static func _wheel_face(gear: Node3D, style: String, rim_r: float, width: float, rim_m: StandardMaterial3D, dark: StandardMaterial3D) -> void:
	var hub_m := mat(CHROME, 0.9, 0.2)
	var h := width + 0.03
	match style:
		"steel":     # plain pressed-steel dish with lug nuts and a centre cap
			cyl(gear, rim_r * 0.8, h, Vector3.ZERO, rim_m)
			for k in 5:
				var a := TAU * k / 5.0
				for sy in [-1.0, 1.0]:
					cyl(gear, 0.025, 0.02, Vector3(cos(a) * rim_r * 0.5, sy * (width * 0.5 + 0.02), sin(a) * rim_r * 0.5), hub_m)
			cyl(gear, 0.08, width + 0.05, Vector3.ZERO, mat(Color(0.2, 0.2, 0.22), 0.6, 0.4))
		"mesh":      # BBS-style cross-spoke mesh
			for k in 9:
				box(gear, Vector3(rim_r * 1.75, h, 0.028), Vector3.ZERO, rim_m).rotation_degrees.y = k * 20.0 + 6.0
				box(gear, Vector3(rim_r * 1.75, h - 0.01, 0.028), Vector3.ZERO, rim_m).rotation_degrees.y = k * 20.0 - 6.0
			cyl(gear, rim_r * 0.3, h + 0.01, Vector3.ZERO, rim_m)
			cyl(gear, 0.05, width + 0.05, Vector3.ZERO, hub_m)
		"multi":     # ten slim spokes
			for k in 10:
				box(gear, Vector3(rim_r * 1.7, h, 0.04), Vector3.ZERO, rim_m).rotation_degrees.y = k * 18.0
			cyl(gear, rim_r * 0.22, h + 0.01, Vector3.ZERO, rim_m)
			cyl(gear, 0.045, width + 0.05, Vector3.ZERO, hub_m)
		"turbine":   # fan-blade turbine, blades swept
			for k in 14:
				var b := box(gear, Vector3(rim_r * 0.9, h, 0.045), Vector3(cos(TAU * k / 14.0) * rim_r * 0.45, 0, sin(TAU * k / 14.0) * rim_r * 0.45), rim_m)
				b.rotation_degrees.y = -rad_to_deg(TAU * k / 14.0) + 28.0
			cyl(gear, rim_r * 0.2, h + 0.01, Vector3.ZERO, rim_m)
			cyl(gear, 0.04, width + 0.05, Vector3.ZERO, hub_m)
		"beadlock":  # off-road: six heavy spokes and a ring of bolts
			for k in 6:
				box(gear, Vector3(rim_r * 1.7, h, 0.09), Vector3.ZERO, rim_m).rotation_degrees.y = k * 30.0
			for k in 16:
				var a := TAU * k / 16.0
				for sy in [-1.0, 1.0]:
					cyl(gear, 0.018, 0.02, Vector3(cos(a) * rim_r * 0.93, sy * (width * 0.5 + 0.02), sin(a) * rim_r * 0.93), hub_m)
			cyl(gear, 0.07, width + 0.05, Vector3.ZERO, hub_m)
		"classic":   # muscle-car slotted 8-spoke with a polished lip and centre cap
			for k in 8:
				box(gear, Vector3(rim_r * 1.7, h, 0.075), Vector3.ZERO, rim_m).rotation_degrees.y = k * 22.5
			cyl(gear, 0.09, width + 0.05, Vector3.ZERO, mat(Color(0.8, 0.1, 0.1), 0.6, 0.3))
		"centre":    # race forged: five twin spokes and a single centre-lock nut
			for k in 5:
				for d in [-5.0, 5.0]:
					box(gear, Vector3(rim_r * 1.75, h, 0.04), Vector3.ZERO, rim_m).rotation_degrees.y = k * 72.0 + d
			cyl(gear, 0.075, width + 0.06, Vector3.ZERO, mat(Color(1.0, 0.75, 0.2), 0.9, 0.25))
		_:           # five-spoke
			for k in 5:
				box(gear, Vector3(rim_r * 1.7, h, 0.055), Vector3.ZERO, rim_m).rotation_degrees.y = k * 36.0
			cyl(gear, 0.06, width + 0.05, Vector3.ZERO, hub_m)


## livery layout per model: stripe count/width/gap, which panels carry it, and the side treatment (0 none, 1 belt, 2 rocker band, 3 pin-stripes)
const STRIPE_KIND := {
	"hatch": {"n": 2, "w": 0.09, "gap": 0.12, "hood": true, "roof": true, "deck": false, "side": 1},
	"buggy": {"n": 1, "w": 0.4, "gap": 0.0, "hood": true, "roof": false, "deck": false, "side": 2},
	"muscle": {"n": 2, "w": 0.24, "gap": 0.2, "hood": true, "roof": true, "deck": true, "side": 0},
	"sierra": {"n": 2, "w": 0.1, "gap": 0.14, "hood": true, "roof": true, "deck": true, "side": 3},
	"pickup": {"n": 1, "w": 0.3, "gap": 0.0, "hood": true, "roof": false, "deck": false, "side": 2},
	"charger": {"n": 2, "w": 0.2, "gap": 0.17, "hood": true, "roof": true, "deck": true, "side": 0},
	"coupe": {"n": 1, "w": 0.3, "gap": 0.0, "hood": true, "roof": true, "deck": true, "side": 1},
	"m4": {"n": 2, "w": 0.05, "gap": 0.1, "hood": true, "roof": false, "deck": true, "side": 3},
	"gt3": {"n": 1, "w": 0.26, "gap": 0.0, "hood": true, "roof": true, "deck": true, "side": 2},
	"hyper": {"n": 2, "w": 0.04, "gap": 0.1, "hood": true, "roof": true, "deck": true, "side": 1},
}


# cabin shape per model: windshield top z, rear window base z / top z, roof half width (smaller = more tumblehome)
const GREENHOUSE := {
	"hatch": {"zf1": -0.7, "zr0": 1.4, "zr1": 1.25, "hwt": 0.84},
	"buggy": {"zf1": -0.65, "zr0": 1.4, "zr1": 1.3, "hwt": 0.88},
	"muscle": {"zf1": -0.4, "zr0": 1.4, "zr1": 0.95, "hwt": 0.8},
	"sierra": {"zf1": -0.55, "zr0": 1.4, "zr1": 1.0, "hwt": 0.84},
	"pickup": {"zf1": -0.6, "zr0": 1.1, "zr1": 1.0, "hwt": 0.86},
	"charger": {"zf1": -0.45, "zr0": 1.4, "zr1": 1.05, "hwt": 0.82},
	"m4": {"zf1": -0.3, "zr0": 1.4, "zr1": 0.85, "hwt": 0.78},
	"coupe": {"zf1": -0.3, "zr0": 1.4, "zr1": 0.9, "hwt": 0.78},
	"gt3": {"zf1": -0.2, "zr0": 1.4, "zr1": 0.8, "hwt": 0.74},
	"hyper": {"zf1": -0.15, "zr0": 1.4, "zr1": 0.85, "hwt": 0.72},
}


## flat 4-point face. out = rough outward direction (fixes the winding). shrink < 1 insets it around its centre.
static func quad(parent: Node, pts: Array, m: Material, out: Vector3, two_sided := false, shrink := 1.0, lift := 0.0) -> MeshInstance3D:
	var c := Vector3.ZERO
	for p in pts:
		c += p
	c /= 4.0
	var v: Array = []
	for p in pts:
		v.append(c + (p - c) * shrink)
	var n := ((v[1] - v[0]) as Vector3).cross((v[2] - v[0]) as Vector3).normalized()
	if n.dot(out) > 0.0:
		v = [v[0], v[3], v[2], v[1]]            # Godot front faces are clockwise
		n = -n
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(-n)
	var off := -n * lift
	for i in [0, 1, 2, 0, 2, 3]:
		st.add_vertex((v[i] as Vector3) + off)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mm := m
	if two_sided:
		mm = m.duplicate()
		(mm as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mm
	parent.add_child(mi)
	return mi


static func decorate(car: Node3D, model: String, lo: Dictionary, body_mat: StandardMaterial3D, team_col: Color) -> void:
	var dark := mat(CARBON, 0.3, 0.5)
	var chrome := mat(CHROME, 0.95, 0.15)
	var glass := mat(Color(0.35, 0.55, 0.75, 0.22), 0.0, 0.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var head := mat(Color(1.0, 0.97, 0.8), 0.0, 0.3, 2.5)
	var tail := mat(Color(1.0, 0.1, 0.08), 0.0, 0.3, 2.2)
	var accent_col: Color = Catalog.STRIPES.get(lo.get("stripe", "none"), Catalog.STRIPES["none"])["c"]
	var hood: Node3D = car.get("_hood_pivot")

	# --- greenhouse: raked windshield, tapered sides (tumblehome), roof and rear window - every model has its own cabin shape
	var d: float = float(car.get("drop"))
	var gh: Dictionary = GREENHOUSE.get(model, GREENHOUSE["hatch"])
	var rt := 1.95 - d
	var zf1: float = gh["zf1"] - d * 0.3
	var zr1: float = gh["zr1"] + d * 0.2
	var zr0: float = gh["zr0"]
	var hwt: float = gh["hwt"]
	var rcz := (zf1 + zr1) * 0.5
	var rlen := zr1 - zf1
	var fbl := Vector3(-0.93, 1.2, -1.15)
	var fbr := Vector3(0.93, 1.2, -1.15)
	var rbl := Vector3(-0.93, 1.33, zr0)
	var rbr := Vector3(0.93, 1.33, zr0)
	var ftl := Vector3(-hwt, rt, zf1)
	var ftr := Vector3(hwt, rt, zf1)
	var rtl := Vector3(-hwt, rt, zr1)
	var rtr := Vector3(hwt, rt, zr1)
	var solid := mat(body_mat.albedo_color, body_mat.metallic, body_mat.roughness)
	quad(car, [fbl, fbr, ftr, ftl], glass, Vector3(0, 0.6, -0.8), false, 1.0, 0.0)
	quad(car, [rbr, rbl, rtl, rtr], glass, Vector3(0, 0.6, 0.8), false, 1.0, 0.0)
	quad(car, [ftl, ftr, rtr, rtl], solid, Vector3.UP, true)
	for sx in [-1.0, 1.0]:
		var f0 := Vector3(sx * 0.93, 1.2, -1.15)
		var r0 := Vector3(sx * 0.93, 1.33, zr0)
		var f1 := Vector3(sx * hwt, rt, zf1)
		var r1 := Vector3(sx * hwt, rt, zr1)
		quad(car, [f0, r0, r1, f1], glass, Vector3(sx, 0.4, 0), false, 1.0, 0.0)
		for pr in [[f0, f1, 0.12], [r0, r1, 0.14], [f1, r1, 0.08], [f0, r0, 0.06]]:
			beam(car, pr[0], pr[1], pr[2], body_mat)
	# --- lights, grille, handles, mirrors, exhaust
	for sx in [-0.68, 0.68]:
		box(car, Vector3(0.4, 0.17, 0.07), Vector3(sx, 0.95, -2.06), head)
		box(car, Vector3(0.5, 0.15, 0.06), Vector3(sx, 0.8, 2.04), tail)
	box(car, Vector3(0.75, 0.16, 0.06), Vector3(0, 0.9, -2.06), dark)
	box(car, Vector3(0.75, 0.025, 0.07), Vector3(0, 0.9, -2.07), chrome)
	for sx in [-1.0, 1.0]:
		box(car, Vector3(0.06, 0.06, 0.28), Vector3(sx * 0.98, 1.2, 0.2), chrome)               # door handles
		cyl(car, 0.07, 0.3, Vector3(sx * 0.5, 0.4, 2.15), chrome, Vector3(90, 0, 0))                 # exhaust
		box(car, Vector3(0.05, 0.22, 2.2 if not (model in ["coupe","hyper","gt3","m4"]) else 2.4), Vector3(sx * 0.98, 0.42, 0.0), dark)   # side skirt
	# team plate on the roof and doors (the paint can be anything, the team stays recognisable)
	var tm := mat(team_col, 0.0, 0.6, 0.6)
	box(car, Vector3(minf(0.9, rlen - 0.1), 0.012, minf(0.9, rlen - 0.1)), Vector3(0, rt + 0.012, rcz), tm)
	for sx in [-1.0, 1.0]:
		box(car, Vector3(0.03, 0.34, 0.34), Vector3(sx * 1.01, 1.1, 0.4), tm)
	# --- stripes: each model carries its own real livery layout
	if lo.get("stripe", "none") != "none":
		var sm := mat(accent_col, 0.2, 0.4, 0.15)
		var sk: Dictionary = STRIPE_KIND.get(model, STRIPE_KIND["hatch"])
		var sw: float = sk["w"]
		var offs: Array = [0.0] if int(sk["n"]) == 1 else [-float(sk["gap"]), float(sk["gap"])]
		for sx in offs:
			if hood and sk["hood"]:
				box(hood, Vector3(sw, 0.012, 0.98), Vector3(sx, 0.012, -0.49), sm)
			if sk["roof"]:
				box(car, Vector3(sw, 0.012, minf(rlen - 0.05, 1.9)), Vector3(sx, rt + 0.02, rcz), sm)
			if sk["deck"]:
				box(car, Vector3(sw, 0.012, 0.6), Vector3(sx, 0.885, 1.7), sm)
		var side: int = sk["side"]
		for sx in [-1.0, 1.0]:
			if side == 1:       # thin belt line
				box(car, Vector3(0.03, 0.05, 3.7), Vector3(sx * 0.96, 0.7, 0.0), sm)
			elif side == 2:     # broad lower rocker band
				box(car, Vector3(0.03, 0.13, 3.5), Vector3(sx * 0.965, 0.5, 0.0), sm)
			elif side == 3:     # double pin-stripes
				box(car, Vector3(0.03, 0.03, 3.6), Vector3(sx * 0.96, 0.74, 0.0), sm)
				box(car, Vector3(0.03, 0.02, 3.6), Vector3(sx * 0.96, 0.68, 0.0), sm)
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

	# --- stickers: round badge with text on both doors
	var dk: String = str(lo.get("decal", "none"))
	if dk != "none" and Catalog.DECALS.has(dk):
		var de: Dictionary = Catalog.DECALS[dk]
		for sx in [-1.0, 1.0]:
			cyl(car, 0.17, 0.012, Vector3(sx * 0.965, 0.86, 0.45), mat(de["bg"], 0.0, 0.5), Vector3(0, 0, 90))
			_number(car, str(de["t"]), Vector3(sx * 0.975, 0.86, 0.45), de["c"], 90.0 * sx, 0.2)

	# --- model specific parts
	match model:
		"hatch":
			box(car, Vector3(0.4, 0.1, 0.5), Vector3(0, 2.03 - d, -0.25), dark)                          # roof intake
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
		"muscle":   # Camaro-style: long hood, black twin stripes, split grille, wide haunches
			if hood:
				box(hood, Vector3(0.5, 0.1, 0.5), Vector3(0, 0.08, -0.5), dark)
				for sx in [-0.45, 0.45]:
					box(hood, Vector3(0.22, 0.03, 0.55), Vector3(sx, 0.07, -0.5), dark)
				for k in 4:
					box(hood, Vector3(0.44, 0.02, 0.03), Vector3(0, 0.14, -0.35 - k * 0.1), chrome)
			box(car, Vector3(1.5, 0.2, 0.06), Vector3(0, 0.62, -2.08), dark)                         # lower intake
			box(car, Vector3(1.95, 0.08, 0.5), Vector3(0, 0.36, -2.15), dark)                        # chin splitter
			box(car, Vector3(0.05, 0.16, 0.07), Vector3(0, 0.9, -2.1), chrome)
			box(car, Vector3(1.7, 0.1, 0.42), Vector3(0, 0.99, 1.9), body_mat)                       # ducktail
			box(car, Vector3(1.9, 0.07, 0.07), Vector3(0, 0.84, 2.08), tail)                         # full-width tail bar
			for sx in [-1.06, 1.06]:
				for sz in [-1.3, 1.3]:
					box(car, Vector3(0.16, 0.1, 0.95), Vector3(sx, 0.86, sz), body_mat)
			if lo.get("stripe", "none") == "none":
				for sx in [-0.16, 0.16]:
					box(car, Vector3(0.2, 0.012, rlen), Vector3(sx, rt + 0.017, rcz), dark)
					box(car, Vector3(0.2, 0.012, 0.6), Vector3(sx, 0.885, 1.7), dark)
					if hood:
						box(hood, Vector3(0.2, 0.012, 0.98), Vector3(sx, 0.014, -0.49), dark)
		"gt3":   # McLaren-GT3-style: huge wing, splitter, race number, scoop
			for sx in [-1.1, 1.1]:
				for sz in [-1.3, 1.3]:
					box(car, Vector3(0.24, 0.12, 1.1), Vector3(sx, 0.85, sz), body_mat)
			box(car, Vector3(2.1, 0.06, 0.5), Vector3(0, 0.34, -2.2), dark)                          # splitter
			box(car, Vector3(1.8, 0.2, 0.06), Vector3(0, 0.62, -2.08), dark)                         # big intake
			for sx in [-0.8, 0.8]:
				box(car, Vector3(0.07, 0.62, 0.12), Vector3(sx, 1.2, 1.95), dark)                    # wing stands
			box(car, Vector3(2.1, 0.07, 0.7), Vector3(0, 1.56, 1.98), dark)                          # GT wing
			box(car, Vector3(2.1, 0.04, 0.2), Vector3(0, 1.62, 1.78), body_mat)
			for sx in [-1.05, 1.05]:
				box(car, Vector3(0.04, 0.38, 0.8), Vector3(sx, 1.56, 1.98), body_mat)
			box(car, Vector3(0.4, 0.14, 0.5), Vector3(0, 2.05 - d, -0.1), dark)                          # roof scoop
			for sx in [-1.0, 1.0]:
				box(car, Vector3(0.03, 0.14, 2.6), Vector3(sx * 0.97, 0.7, 0.2), mat(Color(0.97, 0.97, 0.98), 0.0, 0.5))   # sponsor strip
				box(car, Vector3(0.12, 0.12, 0.5), Vector3(sx * 1.14, 0.8, 0.0), dark)               # side air outlets
				_number(car, "59", Vector3(sx * 1.012, 1.12, 0.4), Color.WHITE, 90.0 * sx, 0.3)
			if hood:
				box(hood, Vector3(0.9, 0.02, 0.5), Vector3(0, 0.07, -0.5), dark)
				_number(hood, "59", Vector3(0, 0.12, -0.5), Color.WHITE, 0.0, 0.34, true)
			cyl(car, 0.06, 0.1, Vector3(0, 0.9, 2.1), dark, Vector3(90, 0, 0))                       # centre exit exhaust
		"charger":   # Dodge-Charger-style: wide scoop, long slab sides, red tail bar, blacked grille
			if hood:
				box(hood, Vector3(0.8, 0.14, 0.6), Vector3(0, 0.1, -0.4), dark)
				box(hood, Vector3(0.7, 0.04, 0.5), Vector3(0, 0.19, -0.4), mat(Color(0.12, 0.12, 0.14), 0.3, 0.4))
			box(car, Vector3(1.8, 0.2, 0.06), Vector3(0, 0.62, -2.08), dark)
			box(car, Vector3(1.95, 0.07, 0.4), Vector3(0, 0.37, -2.16), dark)
			box(car, Vector3(1.4, 0.05, 0.08), Vector3(0, 0.92, -2.09), mat(Color(1.0, 0.1, 0.1), 0.0, 0.3, 3.0))   # light bar front
			box(car, Vector3(1.8, 0.07, 0.07), Vector3(0, 0.86, 2.07), tail)                          # full tail bar
			box(car, Vector3(1.8, 0.06, 0.4), Vector3(0, 1.0, 1.92), body_mat)                       # spoiler lip
			for sx in [-0.7, 0.7]:
				box(car, Vector3(0.06, 0.08, 0.3), Vector3(sx, 0.97, 1.94), body_mat)
			for sx in [-1.04, 1.04]:
				for sz in [-1.3, 1.3]:
					box(car, Vector3(0.14, 0.1, 0.95), Vector3(sx, 0.88, sz), body_mat)
			for sx in [-1.0, 1.0]:
				box(car, Vector3(0.03, 0.04, 3.4), Vector3(sx * 0.96, 0.92, 0.0), dark)               # shoulder line
			box(car, Vector3(1.0, 0.02, 0.1), Vector3(0, 1.0, -2.08), chrome)
		"sierra":   # Sierra-Cosworth-style: whale-tail wing, box arches, side skirts, square lamps
			for sx in [-0.62, 0.62]:
				box(car, Vector3(0.62, 0.2, 0.05), Vector3(sx, 0.98, -2.065), head)                  # big square lamps
			box(car, Vector3(0.12, 0.22, 0.05), Vector3(0, 0.95, -2.07), dark)
			for sx in [-1.04, 1.04]:
				for sz in [-1.3, 1.3]:
					box(car, Vector3(0.14, 0.14, 1.0), Vector3(sx, 0.86, sz), body_mat)
			box(car, Vector3(1.4, 0.18, 0.06), Vector3(0, 0.64, -2.08), dark)
			for sx in [-0.65, 0.65]:
				box(car, Vector3(0.08, 0.55, 0.12), Vector3(sx, 1.2, 1.95), dark)
			box(car, Vector3(2.0, 0.06, 0.85), Vector3(0, 1.45, 1.98), body_mat)                    # whale tail
			box(car, Vector3(2.0, 0.14, 0.06), Vector3(0, 1.52, 2.38), body_mat)
			box(car, Vector3(1.9, 0.1, 0.4), Vector3(0, 0.5, -2.16), dark)                           # deep front valance
			for sx in [-0.45, 0.45]:
				cyl(car, 0.1, 0.08, Vector3(sx, 0.64, -2.1), head, Vector3(90, 0, 0))
			box(car, Vector3(1.6, 0.04, 0.5), Vector3(0, 0.92, 2.04), mat(Color(0.7, 0.05, 0.05), 0.0, 0.5, 1.0))
		"pickup":
			for sx in [-0.55, 0.55]:
				box(car, Vector3(0.08, 0.6, 0.08), Vector3(sx, 0.85, -2.2), chrome)
			box(car, Vector3(1.5, 0.08, 0.08), Vector3(0, 1.1, -2.2), chrome)                        # bull bar
			box(car, Vector3(1.5, 0.08, 0.08), Vector3(0, 0.62, -2.2), chrome)
			box(car, Vector3(1.4, 0.1, 0.14), Vector3(0, 2.05 - d, -0.5), mat(Color(1, 1, 0.9), 0.0, 0.3, 3.0))   # roof lights
			for sx in [-0.92, 0.92]:
				box(car, Vector3(0.07, 0.3, 0.65), Vector3(sx, 1.05, 1.7), body_mat)                 # bed rails
				box(car, Vector3(0.12, 0.06, 0.05), Vector3(sx, 1.2, 1.45), dark)
			box(car, Vector3(1.9, 0.3, 0.07), Vector3(0, 1.05, 2.03), body_mat)                      # tailgate
			box(car, Vector3(1.75, 0.07, 0.07), Vector3(0, 1.5, 1.45), chrome)                       # roll bar
			cyl(car, 0.05, 0.9, Vector3(0.97, 1.45, -0.9), dark)                                     # snorkel
			for sx in [-1.04, 1.04]:
				for sz in [-1.3, 1.3]:
					box(car, Vector3(0.14, 0.1, 0.95), Vector3(sx, 0.9, sz), dark)
		"m4":   # twin kidney grille, hood power dome, three-colour side stripes, quad pipes, carbon roof, trunk lip
			var blk := mat(Color(0.03, 0.03, 0.04), 0.4, 0.4)
			for sx in [-0.2, 0.2]:
				box(car, Vector3(0.32, 0.24, 0.07), Vector3(sx, 0.94, -2.075), blk)                  # kidney grilles
				box(car, Vector3(0.34, 0.025, 0.075), Vector3(sx, 1.065, -2.08), chrome)
				box(car, Vector3(0.34, 0.025, 0.075), Vector3(sx, 0.815, -2.08), chrome)
				for k in 4:
					box(car, Vector3(0.025, 0.2, 0.075), Vector3(sx - 0.12 + k * 0.08, 0.94, -2.082), chrome)
			for sx in [-0.78, 0.78]:                                                                  # slim headlights with DRL ring
				box(car, Vector3(0.42, 0.11, 0.07), Vector3(sx, 0.98, -2.065), head)
				box(car, Vector3(0.42, 0.02, 0.075), Vector3(sx, 1.05, -2.07), mat(Color(0.5, 0.8, 1.0), 0.0, 0.3, 3.0))
			box(car, Vector3(1.95, 0.05, 0.4), Vector3(0, 0.36, -2.18), dark)
			box(car, Vector3(0.9, 0.2, 0.06), Vector3(0, 0.62, -2.08), dark)                         # centre intake
			for sx in [-0.8, 0.8]:
				box(car, Vector3(0.3, 0.14, 0.06), Vector3(sx, 0.6, -2.08), dark)
			box(car, Vector3(1.9, 0.05, 0.4), Vector3(0, 0.38, 2.18), dark)                          # diffuser
			for sx in [-0.6, -0.3, 0, 0.3, 0.6]:
				box(car, Vector3(0.03, 0.2, 0.4), Vector3(sx, 0.45, 2.18), dark)
			for sx in [-0.62, -0.42, 0.42, 0.62]:
				cyl(car, 0.065, 0.14, Vector3(sx, 0.5, 2.22), chrome, Vector3(90, 0, 0))             # quad pipes
			box(car, Vector3(1.7, 0.05, 0.28), Vector3(0, 1.0, 1.94), dark)                          # trunk lip
			box(car, Vector3(hwt * 2.0 - 0.1, 0.02, rlen), Vector3(0, rt + 0.012, rcz), mat(CARBON, 0.6, 0.3))   # carbon roof
			for sx in [-1.0, 1.0]:
				box(car, Vector3(0.03, 0.12, 0.35), Vector3(sx * 0.99, 0.86, -1.05), blk)             # gills
				for k in 3:                                                                           # three-colour sport stripe
					var sc: Color = [Color(0.45, 0.75, 1.0), Color(0.12, 0.2, 0.7), Color(0.85, 0.1, 0.12)][k]
					box(car, Vector3(0.025, 0.035, 3.3), Vector3(sx * 0.965, 0.58 + k * 0.045, 0.0), mat(sc, 0.3, 0.4, 0.2))
			for sx in [-0.62, 0.62]:                                                                  # L-shaped tail lights
				box(car, Vector3(0.5, 0.07, 0.06), Vector3(sx, 0.95, 2.06), tail)
				box(car, Vector3(0.07, 0.2, 0.06), Vector3(sx + (0.2 if sx > 0 else -0.2), 0.88, 2.06), tail)
			if hood:
				box(hood, Vector3(0.6, 0.06, 0.55), Vector3(0, 0.07, -0.55), body_mat)               # power dome
				for sx in [-0.28, 0.28]:
					box(hood, Vector3(0.04, 0.02, 0.6), Vector3(sx, 0.11, -0.55), dark)
		"coupe":   # wide-grille sport coupe, carbon roof, quad pipes
			var blk := mat(Color(0.03, 0.03, 0.04), 0.4, 0.4)
			box(car, Vector3(1.1, 0.16, 0.07), Vector3(0, 0.92, -2.075), blk)                           # wide grille
			box(car, Vector3(1.1, 0.02, 0.075), Vector3(0, 1.0, -2.08), chrome)
			box(car, Vector3(1.95, 0.05, 0.4), Vector3(0, 0.36, -2.18), dark)                        # splitter
			box(car, Vector3(1.9, 0.05, 0.4), Vector3(0, 0.38, 2.18), dark)                          # diffuser
			for sx in [-0.6, -0.3, 0, 0.3, 0.6]:
				box(car, Vector3(0.03, 0.2, 0.4), Vector3(sx, 0.45, 2.18), dark)
			for sx in [-0.62, -0.42, 0.42, 0.62]:
				cyl(car, 0.06, 0.12, Vector3(sx, 0.5, 2.2), chrome, Vector3(90, 0, 0))               # quad pipes
			box(car, Vector3(1.7, 0.05, 0.3), Vector3(0, 1.0, 1.94), dark)                           # duck-tail spoiler
			box(car, Vector3(hwt * 2.0 - 0.1, 0.02, rlen), Vector3(0, rt + 0.012, rcz), mat(CARBON, 0.6, 0.3))        # carbon roof
			for sx in [-1.0, 1.0]:
				box(car, Vector3(0.03, 0.12, 0.35), Vector3(sx * 0.99, 0.86, -1.05), blk)             # gill vents
			if hood:
				for sx in [-0.3, 0.3]:
					box(hood, Vector3(0.3, 0.02, 0.5), Vector3(sx, 0.06, -0.55), dark)
					box(hood, Vector3(0.3, 0.02, 0.05), Vector3(sx, 0.07, -0.3), body_mat)
		"hyper":   # Chiron-style: black body with orange accent C-line, horseshoe grille, huge wing
			var org := mat(Color(1.0, 0.45, 0.05), 0.3, 0.4, 0.2)
			for sx in [-1.08, 1.08]:
				for sz in [-1.3, 1.3]:
					box(car, Vector3(0.22, 0.12, 1.05), Vector3(sx, 0.85, sz), mat(CARBON, 0.5, 0.3))
			box(car, Vector3(0.5, 0.26, 0.07), Vector3(0, 0.9, -2.075), dark)                        # horseshoe grille
			box(car, Vector3(0.56, 0.03, 0.075), Vector3(0, 1.04, -2.08), chrome)
			for sx in [-0.28, 0.28]:
				box(car, Vector3(0.04, 0.26, 0.075), Vector3(sx, 0.9, -2.08), chrome)
			for sx in [-1.0, 1.0]:
				box(car, Vector3(0.03, 0.12, 2.0), Vector3(sx * 0.97, 1.0, 0.0), org)                # C-line accent
				box(car, Vector3(0.03, 0.4, 0.1), Vector3(sx * 0.97, 1.2, 0.9), org)
				box(car, Vector3(0.04, 0.3, 0.7), Vector3(sx, 1.55, 1.95), mat(CARBON, 0.5, 0.3))     # end plates
				box(car, Vector3(0.05, 0.05, 0.7), Vector3(sx, 1.7, 1.95), org)
				box(car, Vector3(0.35, 0.04, 0.25), Vector3(sx * 0.85, 0.5, -2.25), org)             # canards
			box(car, Vector3(0.05, 0.16, 1.0), Vector3(0, 2.04 - d, 0.8), org)                             # centre fin
			for sx in [-0.7, 0.7]:
				box(car, Vector3(0.08, 0.6, 0.1), Vector3(sx, 1.2, 1.95), dark)
			box(car, Vector3(2.0, 0.06, 0.65), Vector3(0, 1.55, 1.95), mat(CARBON, 0.6, 0.3))        # big wing
			box(car, Vector3(1.95, 0.05, 0.45), Vector3(0, 0.36, -2.22), mat(CARBON, 0.6, 0.3))
			box(car, Vector3(0.3, 0.02, rlen), Vector3(0, rt + 0.02, rcz), org)                          # orange roof band
			box(car, Vector3(1.3, 0.03, 0.05), Vector3(0, 0.82, 2.08), tail)
			for sx in [-0.4, 0.4]:
				cyl(car, 0.09, 0.1, Vector3(sx, 0.5, 2.2), chrome, Vector3(90, 0, 0))
			if hood:
				box(hood, Vector3(0.2, 0.02, 0.9), Vector3(0, 0.02, -0.49), org)

	_body_kit(car, model, lo, body_mat, hood, d)
	_fitted_parts(car, lo.get("up", {}), body_mat, hood, d)


## visible bolt-on parts (turbo scoop, exhaust tips, aero, suspension flares, armor)
static func _fitted_parts(car: Node3D, up: Dictionary, body_mat: StandardMaterial3D, hood: Node3D, d: float) -> void:
	var dark := mat(CARBON, 0.4, 0.4)
	var carbon := mat(CARBON, 0.6, 0.3)
	var tu := int(up.get("fit_turbo", 0))
	if tu > 0:
		if hood:
			box(hood, Vector3(0.5, 0.08 + 0.04 * tu, 0.4), Vector3(0, 0.1, -0.35), body_mat)         # power bulge
			box(hood, Vector3(0.42, 0.03, 0.3), Vector3(0, 0.15 + 0.04 * tu, -0.3), dark)           # intake
		var glow := mat(Color(1.0, 0.4, 0.05), 0.5, 0.3, 1.5 if tu >= 3 else 0.0)
		cyl(car, 0.11, 0.2, Vector3(0.45, 1.05, -1.5), mat(Color(0.6, 0.62, 0.68), 0.9, 0.3), Vector3(0, 0, 90))   # turbo snail in the bay
		cyl(car, 0.07, 0.24, Vector3(0.45, 1.05, -1.5), glow, Vector3(0, 0, 90))
	var ex := int(up.get("fit_exhaust", 0))
	if ex > 0:
		var ec: Color = [Color(0.75, 0.78, 0.85), Color(0.9, 0.92, 0.98), Color(0.35, 0.5, 0.95)][ex - 1]
		var em := mat(ec, 0.95, 0.2, 0.4 if ex == 3 else 0.0)
		for sx in [-0.3, 0.3]:
			cyl(car, 0.09 + 0.02 * ex, 0.3, Vector3(sx, 0.42, 2.25), em, Vector3(90, 0, 0))
			cyl(car, 0.06 + 0.015 * ex, 0.32, Vector3(sx, 0.42, 2.26), dark, Vector3(90, 0, 0))
	var ae := int(up.get("fit_aero", 0))
	if ae > 0:
		box(car, Vector3(2.0, 0.06, 0.35), Vector3(0, 0.34, -2.28), carbon)                           # front lip
		if ae >= 2:
			box(car, Vector3(1.9, 0.05, 0.45), Vector3(0, 1.02, 2.0), carbon)                        # spoiler
			for sx in [-0.8, 0.8]:
				box(car, Vector3(0.05, 0.14, 0.4), Vector3(sx, 0.95, 2.0), carbon)
		if ae >= 3:
			for sx in [-0.75, 0.75]:
				box(car, Vector3(0.07, 0.7, 0.1), Vector3(sx, 1.25, 2.0), carbon)
			box(car, Vector3(2.1, 0.07, 0.6), Vector3(0, 1.62, 2.02), carbon)                        # tall wing
			for sx in [-1.05, 1.05]:
				box(car, Vector3(0.04, 0.3, 0.65), Vector3(sx, 1.62, 2.02), body_mat)
	var su := int(up.get("fit_susp", 0))
	if su > 0:
		var gold := mat(Color(1.0, 0.75, 0.15), 0.8, 0.3)
		for sx in [-0.97, 0.97]:
			for sz in [-1.3, 1.3]:
				box(car, Vector3(0.05, 0.05, 0.4), Vector3(sx, 0.62, sz), gold)                      # coilover glimpse above the wheels
		if su >= 2:
			for sx in [-1.0, 1.0]:
				box(car, Vector3(0.06, 0.1, 2.0), Vector3(sx * 0.99, 0.5, 0.0), carbon)             # side skirts
		if su >= 3:
			for sx in [-1.1, 1.1]:
				for sz in [-1.3, 1.3]:
					box(car, Vector3(0.14, 0.12, 1.0), Vector3(sx, 0.88, sz), body_mat)               # fender flares
	var kt := int(up.get("fit_kit", 0))
	if kt > 0:
		box(car, Vector3(1.8, 0.06, 1.4), Vector3(0, 0.34, -1.4), mat(Color(0.5, 0.52, 0.56), 0.8, 0.4))   # skid plate
		if kt >= 2:
			var tube := mat(Color(0.12, 0.12, 0.14), 0.7, 0.35)
			for sx in [-0.7, 0.7]:
				beam(car, Vector3(sx, 1.0, 1.0), Vector3(sx, 1.8 - d, 0.2), 0.06, tube)               # visible roll hoops
		if kt >= 3:
			for sx in [-0.6, 0.6]:
				box(car, Vector3(0.07, 0.55, 0.08), Vector3(sx, 0.85, -2.22), mat(CHROME, 0.9, 0.2))   # bull bar
			box(car, Vector3(1.4, 0.07, 0.08), Vector3(0, 1.12, -2.22), mat(CHROME, 0.9, 0.2))


## race number as Label3D; rot_y turns it to face the side, flat lays it on a horizontal surface
static func _number(parent: Node, txt: String, pos: Vector3, col: Color, rot_y := 0.0, size := 0.3, flat := false) -> void:
	var lab := Label3D.new()
	lab.text = txt
	lab.font_size = 96
	lab.pixel_size = size / 70.0
	lab.modulate = col
	lab.outline_size = 0
	lab.double_sided = true
	lab.position = pos
	if flat:
		lab.rotation_degrees = Vector3(-90, 0, 0)
	else:
		lab.rotation_degrees = Vector3(0, rot_y, 0)
	parent.add_child(lab)


static func sx_of(k: int) -> float:
	return -0.5 + k * 0.5


## shape changes picked in the garage (spoiler / front / hood / sides). Each car only accepts its own options.
static func _body_kit(car: Node3D, model: String, lo: Dictionary, body_mat: StandardMaterial3D, hood: Node3D, d: float) -> void:
	var carbon := mat(CARBON, 0.55, 0.3)
	var dark := mat(Color(0.03, 0.03, 0.04), 0.3, 0.6)
	var chrome := mat(CHROME, 0.95, 0.15)
	var acc := mat(Color(0.9, 0.12, 0.1), 0.0, 0.5, 0.3)
	var sp := str(lo.get("spoiler", "none"))
	if sp != "none" and Catalog.body_opts(model, "spoiler").has(sp):
		var ry := 1.12 - d * 0.35
		match sp:
			"lip":
				box(car, Vector3(1.7, 0.035, 0.14), Vector3(0, ry - 0.04, 2.0), carbon)
			"duck":
				box(car, Vector3(1.8, 0.05, 0.38), Vector3(0, ry, 1.93), carbon, Vector3(-14, 0, 0))
				for sx in [-0.9, 0.9]:
					box(car, Vector3(0.04, 0.12, 0.38), Vector3(sx, ry + 0.02, 1.93), carbon)
			"gt":
				for sx in [-0.7, 0.7]:
					box(car, Vector3(0.06, 0.55, 0.09), Vector3(sx, ry + 0.25, 2.02), carbon)
				box(car, Vector3(2.0, 0.06, 0.5), Vector3(0, ry + 0.55, 2.04), carbon, Vector3(-6, 0, 0))
				for sx in [-1.0, 1.0]:
					box(car, Vector3(0.04, 0.26, 0.55), Vector3(sx, ry + 0.55, 2.04), body_mat)
			"twin":
				for sx in [-0.7, 0.7]:
					box(car, Vector3(0.06, 0.62, 0.09), Vector3(sx, ry + 0.28, 2.02), carbon)
				box(car, Vector3(2.0, 0.05, 0.42), Vector3(0, ry + 0.62, 2.04), carbon, Vector3(-6, 0, 0))
				box(car, Vector3(1.9, 0.05, 0.34), Vector3(0, ry + 0.36, 2.0), carbon, Vector3(-4, 0, 0))
				for sx in [-1.0, 1.0]:
					box(car, Vector3(0.04, 0.36, 0.5), Vector3(sx, ry + 0.5, 2.03), body_mat)
	var fr := str(lo.get("front", "none"))
	if fr != "none" and Catalog.body_opts(model, "front").has(fr):
		match fr:
			"splitter":
				box(car, Vector3(2.0, 0.04, 0.42), Vector3(0, 0.32, -2.2), carbon)
				for sx in [-0.8, 0.8]:
					box(car, Vector3(0.03, 0.1, 0.3), Vector3(sx, 0.36, -2.25), carbon)
			"canards":
				box(car, Vector3(2.0, 0.04, 0.4), Vector3(0, 0.32, -2.2), carbon)
				for sx in [-1.0, 1.0]:
					box(car, Vector3(0.28, 0.03, 0.2), Vector3(sx * 0.95, 0.58, -2.0), carbon, Vector3(0, -sx * 20.0, sx * 12.0))
					box(car, Vector3(0.22, 0.03, 0.16), Vector3(sx * 0.95, 0.74, -1.95), carbon, Vector3(0, -sx * 20.0, sx * 12.0))
			"bullbar":
				for sx in [-0.62, 0.62]:
					cyl(car, 0.04, 0.62, Vector3(sx, 0.62, -2.18), chrome)
				cyl(car, 0.045, 1.35, Vector3(0, 0.95, -2.18), chrome, Vector3(0, 0, 90))
				cyl(car, 0.04, 1.35, Vector3(0, 0.45, -2.18), chrome, Vector3(0, 0, 90))
				for sx in [-0.3, 0.3]:
					cyl(car, 0.03, 0.5, Vector3(sx, 0.7, -2.18), chrome)
	var hd := str(lo.get("hood", "none"))
	if hd != "none" and Catalog.body_opts(model, "hood").has(hd) and hood:
		match hd:
			"scoop":
				box(hood, Vector3(0.55, 0.13, 0.5), Vector3(0, 0.13, -0.5), body_mat)
				box(hood, Vector3(0.45, 0.09, 0.02), Vector3(0, 0.14, -0.76), dark)
			"vents":
				for sx in [-0.3, 0.3]:
					for k in 5:
						box(hood, Vector3(0.32, 0.015, 0.03), Vector3(sx, 0.075 + k * 0.0, -0.4 - k * 0.07), dark)
					box(hood, Vector3(0.34, 0.02, 0.4), Vector3(sx, 0.07, -0.55), dark)
			"carbon":
				box(hood, Vector3(0.96, 0.02, 0.96), Vector3(0, 0.085, -0.49), carbon)
				for sx in [-0.4, 0.4]:
					for sz in [-0.1, -0.88]:
						cyl(hood, 0.025, 0.03, Vector3(sx, 0.105, sz), chrome)
	var sk := str(lo.get("skirts", "none"))
	if sk != "none" and Catalog.body_opts(model, "skirts").has(sk):
		for sx in [-1.0, 1.0]:
			box(car, Vector3(0.1, 0.13, 2.3), Vector3(sx * 1.0, 0.3, 0.0), carbon)
			box(car, Vector3(0.02, 0.025, 2.3), Vector3(sx * 1.055, 0.34, 0.0), acc)
			if sk == "wide":
				for sz in [-1.35, 1.25]:
					box(car, Vector3(0.16, 0.34, 0.95), Vector3(sx * 1.0, 0.62, sz), body_mat)
					box(car, Vector3(0.05, 0.05, 0.95), Vector3(sx * 1.1, 0.48, sz), carbon)
					for rz in [-0.38, 0.38]:
						cyl(car, 0.02, 0.02, Vector3(sx * 1.09, 0.7, sz + rz), chrome, Vector3(0, 0, 90))
