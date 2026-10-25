# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
class_name Avatar
extends Node3D
## A blocky player character sitting in a car seat (long cream arms like in the video).
## - the driver keeps both hands on the wheel, the right hand can punch
## - the co-driver holds the map clipboard in the LEFT hand and points / warns with the RIGHT hand
## The origin of this node is the seat position (car space). -Z is forward.

enum Gesture { REST, LEFT, FORWARD, RIGHT, STOP }

const UPPER := 0.42
const FORE := 0.46
const SKIN := Color(0.93, 0.84, 0.7)
const WOOD := Color(0.62, 0.4, 0.17)
const SHOULDER := {"L": Vector3(-0.3, 0.5, 0.1), "R": Vector3(0.3, 0.5, 0.1)}
const POLE := {"L": Vector3(-0.5, -1.0, 0.25), "R": Vector3(0.5, -1.0, 0.25)}
const CLIP_POS := Vector3(0.0, 0.12, -0.42)
const CLIP_HAND := Vector3(-0.34, 0.05, -0.3)
const EMOTE_LEN := 2.6

var peer_id := 0
var role := "driver"
var shirt_color := Color(0.8, 0.2, 0.25)
var helmet_color := Color(0.1, 0.25, 0.9)
var is_local := false
var seat_dx := 0.0        # x offset of the teammate's seat relative to mine (0 = no teammate)
var look_yaw := 0.0
var look_pitch := 0.0
var gesture: int = Gesture.REST
var punch_t := -1.0
var hit_kick := 0.0
var cam: Camera3D
# working outside the car (putting out an engine fire)
var outside := false
var work := 0              # 0 none, 1 reaching for the hood, 2 holding the extinguisher
var reach_t := 0.0         # 0 hood closed .. 1 hood fully up
var cover_hand := false    # left hand on the engine cover
var _ext: Node3D
var _hose: MeshInstance3D       # rubber hose from the extinguisher valve to the left hand
var _nozzle: MeshInstance3D     # nozzle held in the left hand
var _seat_pos := Vector3.ZERO
var map_screen: MapScreen
var ipad_tex: Texture2D     # live map texture (local co-driver only)
var outfit := {}            # slot -> item id (see Catalog), empty = defaults
var standing := false       # preview / outside the car: legs straight
var emote := ""
var emote_t := -1.0
var blast_t := -1.0         # >= 0 : thrown by an explosion
var blast_vel := Vector3.ZERO
var blast_ground := 0.0
var _legs: Array = []
var _look: Node3D           # hat / glasses / face (hidden for the local player)
var _bx: Node3D             # legs / shoes / shirt details (hidden for the local player)
var _arm_up: Array = []
var _base_yaw := 0.0
var _base_y := 0.0
var _sparks: CPUParticles3D
# --- podium ceremony ("podium" role): cup lift for 1st, medals for 2nd / 3rd
var podium_kind := ""          # "cup" | "silver" | "bronze" | "cheer"
var podium_t := -1.0           # seconds since the award started (-1 = not yet)
var podium_base_y := 0.0
var podium_phase := 0.0        # desynchronises two people on the same block
var _medal: Node3D
var _cup: Node3D
var _hop := 0.0

var _head: Node3D
var _torso: MeshInstance3D
var _helmet: MeshInstance3D
var _visor: MeshInstance3D
var _palm: MeshInstance3D
var _finger: MeshInstance3D
var _limbs := {}
var _cur := {"L": Vector3(-0.3, 0.1, -0.3), "R": Vector3(0.3, 0.1, -0.3)}
var _wheel_l := Vector3(-0.2, 0.1, -0.6)
var _wheel_r := Vector3(0.2, 0.1, -0.6)
var _shift_r := Vector3.ZERO
var _shift_k := 0.0


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


func _box(parent: Node, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _ready() -> void:
	_torso = _box(self, Vector3(0.52, 0.68, 0.3), Vector3(0, 0.31, 0.12), shirt_color)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.8 if not is_local else 0.72, 0.05)
	add_child(_head)
	_helmet = _box(_head, Vector3(0.36, 0.36, 0.36), Vector3.ZERO, helmet_color)
	_visor = _box(_head, Vector3(0.3, 0.12, 0.04), Vector3(0, 0.03, -0.19), Color(0.03, 0.03, 0.05))
	for s in ["L", "R"]:
		_limbs[s] = {
			"up": _box(self, Vector3(0.14, 0.14, 1.0), Vector3.ZERO, SKIN),
			"fore": _box(self, Vector3(0.14, 0.14, 1.0), Vector3.ZERO, SKIN),
			"hand": _box(self, Vector3(0.17, 0.17, 0.17), Vector3.ZERO, SKIN.darkened(0.08)),
		}
	_palm = _box(self, Vector3(0.3, 0.3, 0.05), Vector3.ZERO, Color(0.92, 0.15, 0.15))
	_palm.visible = false
	_finger = _box(self, Vector3(0.05, 0.05, 1.0), Vector3.ZERO, SKIN)
	_finger.visible = false
	if role == "navigator":
		_build_clipboard()
	_build_look()
	if is_local:
		_torso.visible = false
		_helmet.visible = false
		_visor.visible = false
		_look.visible = false
		_bx.visible = false
		# first-person: slimmer arms and hands so they never hide the gauges
		for sd2 in ["L", "R"]:
			((_limbs[sd2]["up"] as MeshInstance3D).mesh as BoxMesh).size = Vector3(0.08, 0.08, 1.0)
			((_limbs[sd2]["fore"] as MeshInstance3D).mesh as BoxMesh).size = Vector3(0.07, 0.07, 1.0)
			((_limbs[sd2]["hand"] as MeshInstance3D).mesh as BoxMesh).size = Vector3(0.1, 0.1, 0.1)
		cam = Camera3D.new()
		cam.fov = 82.0
		cam.near = 0.05
		cam.far = Gfx.far_clip()
		_head.add_child(cam)
		cam.position = Vector3(0, 0, -0.12)
		cam.current = true


func _o(slot: String) -> String:
	var d: Dictionary = Catalog.DEFAULT_OUTFIT
	var id := str(outfit.get(slot, d[slot]))
	return id if Catalog.entry(slot, id).size() > 0 else str(d[slot])


## (re)builds everything the player can customise: skin, shirt, pants, shoes, hat, glasses
func _build_look() -> void:
	if _look:
		_look.queue_free()
	if _bx:
		_bx.queue_free()
	_look = Node3D.new()
	_head.add_child(_look)
	_bx = Node3D.new()
	add_child(_bx)
	_legs.clear()
	var skin: Color = Catalog.SKINS[_o("skin")]["c"]
	var shirt: Dictionary = Catalog.SHIRTS[_o("shirt")]
	var sc: Color = shirt_color if shirt["c"] == Color.TRANSPARENT else shirt["c"]
	var hat := _o("hat")
	var pants: Dictionary = Catalog.PANTS[_o("pants")]
	var shoe: Color = Catalog.SHOES[_o("shoes")]["c"]
	(_torso.material_override as StandardMaterial3D).albedo_color = sc
	(_helmet.material_override as StandardMaterial3D).albedo_color = helmet_color if hat == "helmet" else skin
	_visor.visible = hat == "helmet" and not is_local
	(_palm.material_override as StandardMaterial3D).albedo_color = Color(0.92, 0.15, 0.15)
	for sd in ["L", "R"]:
		var lm: Dictionary = _limbs[sd]
		(lm["up"].material_override as StandardMaterial3D).albedo_color = sc if shirt.get("sleeve", false) else skin
		(lm["fore"].material_override as StandardMaterial3D).albedo_color = skin
		(lm["hand"].material_override as StandardMaterial3D).albedo_color = skin.darkened(0.08)
	(_finger.material_override as StandardMaterial3D).albedo_color = skin
	# shirt details
	if shirt.has("stripe"):
		var sm := Color(shirt["stripe"])
		_box(_bx, Vector3(0.54, 0.09, 0.32), Vector3(0, 0.3, 0.12), sm)
		_box(_bx, Vector3(0.54, 0.05, 0.32), Vector3(0, 0.12, 0.12), sm)
	if _o("shirt") in ["jacket", "hoodie"]:
		_box(_bx, Vector3(0.3, 0.06, 0.32), Vector3(0, 0.55, 0.1), sc.lightened(0.15))      # collar
	# legs (pivot at the hip; seated = thighs forward)
	for sx in [-0.14, 0.14]:
		var hip := Node3D.new()
		hip.position = Vector3(sx, -0.02, 0.12)
		_bx.add_child(hip)
		_box(hip, Vector3(0.19, 0.46, 0.19), Vector3(0, -0.23, 0), pants["c"])
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.46, 0)
		hip.add_child(knee)
		_box(knee, Vector3(0.18, 0.4, 0.18), Vector3(0, -0.2, 0), pants["c"])
		_box(knee, Vector3(0.2, 0.1, 0.32), Vector3(0, -0.45, -0.06), shoe)
		if pants.has("stripe"):
			_box(hip, Vector3(0.2, 0.12, 0.2), Vector3(0, -0.15, 0), Color(pants["stripe"]))
		_legs.append({"hip": hip, "knee": knee})
	# face for everything except the visor helmet
	if hat != "helmet":
		for ex in [-0.08, 0.08]:
			_box(_look, Vector3(0.05, 0.07, 0.02), Vector3(ex, 0.03, -0.182), Color(0.05, 0.05, 0.08))
		_box(_look, Vector3(0.1, 0.02, 0.02), Vector3(0, -0.08, -0.182), Color(0.45, 0.12, 0.12))
		if hat != "beanie" and hat != "tophat" and hat != "cowboy":
			_box(_look, Vector3(0.37, 0.07, 0.37), Vector3(0, 0.165, 0), Color(0.18, 0.1, 0.06))     # hair
	var hc := helmet_color
	match hat:
		"cap":
			_box(_look, Vector3(0.38, 0.1, 0.38), Vector3(0, 0.2, 0), hc)
			_box(_look, Vector3(0.36, 0.03, 0.2), Vector3(0, 0.16, -0.28), hc.darkened(0.2))
		"beanie":
			_box(_look, Vector3(0.39, 0.17, 0.39), Vector3(0, 0.2, 0), Color(0.25, 0.3, 0.55))
			_box(_look, Vector3(0.4, 0.05, 0.4), Vector3(0, 0.13, 0), Color(0.9, 0.9, 0.95))
			_box(_look, Vector3(0.1, 0.08, 0.1), Vector3(0, 0.32, 0), Color(0.9, 0.9, 0.95))
		"headset":
			_box(_look, Vector3(0.4, 0.04, 0.06), Vector3(0, 0.2, 0), Color(0.1, 0.1, 0.12))
			for ex in [-0.2, 0.2]:
				_box(_look, Vector3(0.08, 0.15, 0.15), Vector3(ex, 0.02, 0.0), Color(0.1, 0.1, 0.12))
				_box(_look, Vector3(0.05, 0.12, 0.04), Vector3(ex * 0.98, 0.12, 0.0), Color(0.1, 0.1, 0.12))
			_box(_look, Vector3(0.03, 0.03, 0.14), Vector3(0.2, -0.06, -0.1), Color(0.1, 0.1, 0.12))
			_box(_look, Vector3(0.05, 0.05, 0.05), Vector3(0.17, -0.06, -0.19), Color(0.9, 0.2, 0.2))
		"bandana":
			_box(_look, Vector3(0.385, 0.08, 0.385), Vector3(0, 0.12, 0), Color(0.85, 0.12, 0.15))
			_box(_look, Vector3(0.12, 0.1, 0.06), Vector3(0.0, 0.1, 0.2), Color(0.85, 0.12, 0.15))
		"cowboy":
			_box(_look, Vector3(0.7, 0.03, 0.7), Vector3(0, 0.19, 0), Color(0.5, 0.32, 0.15))
			_box(_look, Vector3(0.34, 0.16, 0.34), Vector3(0, 0.28, 0), Color(0.55, 0.36, 0.18))
			_box(_look, Vector3(0.35, 0.04, 0.35), Vector3(0, 0.22, 0), Color(0.2, 0.12, 0.06))
		"tophat":
			_box(_look, Vector3(0.52, 0.03, 0.52), Vector3(0, 0.19, 0), Color(0.06, 0.06, 0.08))
			_box(_look, Vector3(0.3, 0.32, 0.3), Vector3(0, 0.36, 0), Color(0.06, 0.06, 0.08))
			_box(_look, Vector3(0.31, 0.06, 0.31), Vector3(0, 0.25, 0), Color(0.8, 0.1, 0.15))
		"crown":
			var g := _box(_look, Vector3(0.38, 0.09, 0.38), Vector3(0, 0.22, 0), Color(1.0, 0.78, 0.15))
			var gm := g.material_override as StandardMaterial3D
			gm.metallic = 0.9
			gm.roughness = 0.25
			gm.emission_enabled = true
			gm.emission = Color(1.0, 0.7, 0.1)
			gm.emission_energy_multiplier = 0.5
			for p in [Vector3(-0.15, 0, -0.15), Vector3(0.15, 0, -0.15), Vector3(-0.15, 0, 0.15), Vector3(0.15, 0, 0.15), Vector3(0, 0.03, 0)]:
				_box(_look, Vector3(0.07, 0.13, 0.07), Vector3(p.x, 0.32 + p.y, p.z), Color(1.0, 0.78, 0.15))
			_box(_look, Vector3(0.06, 0.06, 0.02), Vector3(0, 0.22, -0.2), Color(0.9, 0.1, 0.2))
	match _o("glasses"):
		"round":
			for ex in [-0.085, 0.085]:
				_box(_look, Vector3(0.11, 0.11, 0.02), Vector3(ex, 0.03, -0.19), Color(0.1, 0.1, 0.12))
				_box(_look, Vector3(0.075, 0.075, 0.025), Vector3(ex, 0.03, -0.192), Color(0.7, 0.85, 1.0))
			_box(_look, Vector3(0.05, 0.02, 0.02), Vector3(0, 0.04, -0.19), Color(0.1, 0.1, 0.12))
		"sun":
			_box(_look, Vector3(0.32, 0.09, 0.03), Vector3(0, 0.03, -0.19), Color(0.02, 0.02, 0.03))
		"goggles":
			_box(_look, Vector3(0.34, 0.12, 0.05), Vector3(0, 0.04, -0.19), Color(0.9, 0.5, 0.1))
			_box(_look, Vector3(0.3, 0.08, 0.055), Vector3(0, 0.04, -0.195), Color(0.2, 0.7, 1.0))
			_box(_look, Vector3(0.375, 0.05, 0.375), Vector3(0, 0.05, 0.0), Color(0.15, 0.15, 0.18))
		"star":
			for ex in [-0.09, 0.09]:
				var a := _box(_look, Vector3(0.13, 0.04, 0.03), Vector3(ex, 0.03, -0.19), Color(1.0, 0.85, 0.2))
				var b := _box(_look, Vector3(0.04, 0.13, 0.03), Vector3(ex, 0.03, -0.19), Color(1.0, 0.85, 0.2))
				a.rotation_degrees.z = 20
				b.rotation_degrees.z = 20
		"visor":
			var v := _box(_look, Vector3(0.34, 0.08, 0.04), Vector3(0, 0.03, -0.19), Color(0.1, 0.95, 1.0))
			var vm := v.material_override as StandardMaterial3D
			vm.emission_enabled = true
			vm.emission = Color(0.1, 0.9, 1.0)
			vm.emission_energy_multiplier = 3.0


func _pose_legs(delta: float) -> void:
	var up := standing or outside
	var ta := 0.0 if up else deg_to_rad(88.0)
	var tk := 0.0 if up else deg_to_rad(-88.0)
	var swing := 0.0
	if emote == "dance" and emote_t >= 0.0:
		swing = sin(emote_t * 9.0) * 0.5
	for i in _legs.size():
		var hip: Node3D = _legs[i]["hip"]
		var knee: Node3D = _legs[i]["knee"]
		var sg := 1.0 if i == 0 else -1.0
		hip.rotation.x = lerpf(hip.rotation.x, ta + swing * sg, clampf(delta * 12.0, 0.0, 1.0))
		knee.rotation.x = lerpf(knee.rotation.x, tk, clampf(delta * 12.0, 0.0, 1.0))


func play_emote(id: String) -> void:
	if emote != "":
		return
	emote = id
	emote_t = 0.0
	_base_yaw = rotation.y
	_base_y = position.y
	if id == "spin" or id == "hover":
		if _sparks == null:
			_sparks = CPUParticles3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(0.09, 0.09)
			var qm := StandardMaterial3D.new()
			qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			qm.vertex_color_use_as_albedo = true
			q.material = qm
			_sparks.mesh = q
			_sparks.amount = Gfx.particles(40)
			_sparks.lifetime = 1.0
			_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			_sparks.emission_sphere_radius = 0.5
			_sparks.direction = Vector3(0, 1, 0)
			_sparks.spread = 60.0
			_sparks.initial_velocity_min = 0.6
			_sparks.initial_velocity_max = 1.6
			_sparks.gravity = Vector3(0, -0.5, 0)
			var gr := Gradient.new()
			gr.colors = PackedColorArray([Color(1.0, 0.9, 0.4, 1.0), Color(1.0, 0.6, 0.1, 0.0)])
			_sparks.color_ramp = gr
			_sparks.position = Vector3(0, 0.3, 0.1)
			add_child(_sparks)
		_sparks.emitting = true


func _emote_targets(dl: Vector3, dr: Vector3) -> Array:
	var t := emote_t
	match emote:
		"wave":
			dr = Vector3(0.38 + sin(t * 11.0) * 0.14, 0.95, -0.05)
		"thumbs":
			dr = Vector3(0.3, 0.45 + sin(t * 8.0) * 0.06, -0.78)
		"salute":
			dr = Vector3(0.14, 0.82, -0.25)
		"flex":
			var f := 0.82 + sin(t * 9.0) * 0.06
			dl = Vector3(-0.5, f, -0.08)
			dr = Vector3(0.5, f, -0.08)
		"dance":
			dl = Vector3(-0.42, 0.8 + sin(t * 9.0) * 0.28, -0.1)
			dr = Vector3(0.42, 0.8 + sin(t * 9.0 + PI) * 0.28, -0.1)
		"spin":
			dl = Vector3(-0.3, 1.1, -0.05)
			dr = Vector3(0.3, 1.1, -0.05)
		"hover":
			dl = Vector3(-0.95, 0.5, -0.15)
			dr = Vector3(0.95, 0.5, -0.15)
	return [dl, dr]


func _emote_body(delta: float) -> void:
	if emote == "":
		return
	emote_t += delta
	var k := clampf(emote_t / 0.25, 0.0, 1.0) * clampf((EMOTE_LEN - emote_t) / 0.25, 0.0, 1.0)
	match emote:
		"dance":
			rotation.z = sin(emote_t * 9.0) * 0.14 * k
		"spin":
			if not is_local:
				rotation.y = _base_yaw + smoothstep(0.0, 1.0, clampf(emote_t / (EMOTE_LEN - 0.3), 0.0, 1.0)) * TAU * 2.0
		"hover":
			position.y = _base_y + 0.4 * k + sin(emote_t * 6.0) * 0.04 * k
	if emote_t >= EMOTE_LEN:
		emote = ""
		emote_t = -1.0
		rotation.z = 0.0
		rotation.y = _base_yaw
		position.y = _base_y
		if _sparks:
			_sparks.emitting = false


## thrown away by the car explosion (world space)
func blast(vel: Vector3, ground_y: float) -> void:
	blast_t = 0.0
	blast_vel = vel
	blast_ground = ground_y


func _build_clipboard() -> void:
	# the map "TV" in the co-driver's lap: flips open, 3 sizes, can be pulled close
	map_screen = MapScreen.new()
	map_screen.tex = ipad_tex
	map_screen.position = CLIP_POS
	map_screen.open_angle = -52.0
	map_screen.closed_angle = -88.0
	map_screen.near_offset = Vector3(0, 0.3, -0.3)
	add_child(map_screen)
	if ipad_tex == null:
		map_screen.set_open(true)


## the driver's right hand goes to the gear lever (k = 0 on the wheel .. 1 on the knob); car space
func set_shift_hand(car_pos: Vector3, k: float) -> void:
	_shift_r = car_pos - position
	_shift_k = k


## Car space -> avatar space (the avatar only has a translation).
func set_wheel_hands(left_car: Vector3, right_car: Vector3) -> void:
	_wheel_l = left_car - position
	_wheel_r = right_car - position


func _blast_step(delta: float) -> void:
	blast_t += delta
	if global_position.y > blast_ground + 0.05 and blast_t < 3.0:
		blast_vel.y -= 14.0 * delta
		global_position += blast_vel * delta
		rotate_x(-7.0 * delta)
		rotate_z(4.0 * delta)
		_cur["L"] = Vector3(-0.5, 0.9, -0.2)
		_cur["R"] = Vector3(0.5, 0.9, -0.2)
	else:
		global_position.y = blast_ground + 0.12
		var tw := basis.orthonormalized()
		basis = tw.slerp(Basis(Vector3.RIGHT, -PI * 0.5), clampf(delta * 6.0, 0.0, 1.0))
		_cur["L"] = Vector3(-0.4, 0.1, -0.5)
		_cur["R"] = Vector3(0.4, 0.1, -0.5)
	_solve("L")
	_solve("R")


func go_outside(pos: Vector3) -> void:
	if not outside:
		_seat_pos = position
	outside = true
	standing = true
	position = pos
	rotation.y = PI
	if _ext == null:
		_ext = Node3D.new()
		add_child(_ext)
		_box(_ext, Vector3(0.13, 0.4, 0.13), Vector3(0, 0, 0), Color(0.85, 0.08, 0.08))
		_box(_ext, Vector3(0.1, 0.06, 0.1), Vector3(0, 0.23, 0), Color(0.1, 0.1, 0.1))
		_box(_ext, Vector3(0.04, 0.04, 0.22), Vector3(0, 0.2, -0.1), Color(0.1, 0.1, 0.1))
	if _hose == null:
		_hose = _box(self, Vector3(0.028, 0.028, 1.0), Vector3.ZERO, Color(0.08, 0.08, 0.09))
		_nozzle = _box(self, Vector3(0.06, 0.06, 1.0), Vector3.ZERO, Color(0.85, 0.08, 0.08))
		_hose.visible = false
		_nozzle.visible = false
	_ext.visible = false


func reseat() -> void:
	blast_t = -1.0
	rotation = Vector3.ZERO
	position = _seat_pos
	outside = false
	standing = false
	work = 0
	if _ext:
		_ext.visible = false
	if _hose:
		_hose.visible = false
		_nozzle.visible = false


func go_inside() -> void:
	if blast_t >= 0.0:
		reseat()
		return
	if outside:
		outside = false
		standing = false
		position = _seat_pos
		rotation.y = 0.0
		work = 0
		if _ext:
			_ext.visible = false


func set_look(yaw: float, pitch: float) -> void:
	look_yaw = yaw
	look_pitch = pitch


func punch() -> void:
	punch_t = 0.0


func play_hit() -> void:
	hit_kick = 1.0


func _gesture_target() -> Vector3:
	var s: Vector3 = SHOULDER["R"]
	match gesture:
		Gesture.LEFT:
			return s + Vector3(-0.88, 0.1, -0.3)
		Gesture.RIGHT:
			return s + Vector3(0.88, 0.1, -0.3)
		Gesture.FORWARD:
			return s + Vector3(0.05, 0.12, -0.88)
		Gesture.STOP:
			return s + Vector3(0.1, 0.45, -0.7)
	return Vector3(0.32, 0.12, -0.2)


func _process(delta: float) -> void:
	if _head == null:
		return
	hit_kick = move_toward(hit_kick, 0.0, delta * 2.5)
	_head.rotation = Vector3(look_pitch, look_yaw, hit_kick * 0.35 * sin(Time.get_ticks_msec() * 0.06))

	if blast_t >= 0.0:
		_blast_step(delta)
		return
	var dl := Vector3(-0.3, 0.1, -0.15)
	var dr := Vector3(0.3, 0.1, -0.15)
	match role:
		"driver":
			dl = _wheel_l
			dr = _wheel_r.lerp(_shift_r, _shift_k) if _shift_k > 0.001 else _wheel_r
		"navigator":
			dl = CLIP_HAND
			dr = _gesture_target()
		"preview":
			dl = Vector3(-0.4, -0.2, 0.1)
			dr = Vector3(0.4, -0.2, 0.1)
		"podium":
			var pt := _podium_targets()
			dl = pt[0]
			dr = pt[1]
	if emote != "" and not outside:
		var et := _emote_targets(dl, dr)
		dl = et[0]
		dr = et[1]
	if outside:
		var a := Vector3(0.3, -0.25, -0.8)
		var b := Vector3(0.3, 0.6, -0.55)
		if work == 2:
			dr = Vector3(0.22, 0.12, -0.6)
			dl = Vector3(-0.1, -0.2, -0.65) if cover_hand else Vector3(-0.14, 0.34, -0.74)    # free hand holds the nozzle
		else:
			dr = a.lerp(b, reach_t)
			dl = Vector3(-a.x, a.y, a.z).lerp(Vector3(-b.x, b.y, b.z), reach_t)
	_emote_body(delta)
	if role == "podium":
		_podium_body(delta)
	_pose_legs(delta)
	var k := 12.0
	if punch_t >= 0.0:
		punch_t += delta / 0.4
		var f := sin(PI * clampf(punch_t, 0.0, 1.0))
		var tgt := Vector3(0.35, 0.55, -0.75)
		if seat_dx != 0.0:
			tgt = Vector3(seat_dx * 0.74, 0.72, -0.08)
		dr = dr.lerp(tgt, f)
		k = 34.0
		if punch_t >= 1.0:
			punch_t = -1.0
	_cur["L"] = (_cur["L"] as Vector3).lerp(dl, clampf(delta * k, 0.0, 1.0))
	_cur["R"] = (_cur["R"] as Vector3).lerp(dr, clampf(delta * k, 0.0, 1.0))
	_solve("L")
	var elbow_r := _solve("R")
	# pointing finger / stop palm on the right hand
	var h: Vector3 = _limbs["R"]["hand"].position
	var dir := (h - elbow_r).normalized()
	var pointing := role == "navigator" and punch_t < 0.0 and gesture in [Gesture.LEFT, Gesture.RIGHT, Gesture.FORWARD]
	pointing = pointing and not outside
	_finger.visible = pointing
	if _ext:
		_ext.visible = outside and work == 2
		_ext.position = h + Vector3(0.0, 0.1, 0.0)
		_ext.rotation.x = deg_to_rad(-75.0)
	if _hose:
		var holding := outside and work == 2 and not cover_hand
		_hose.visible = holding
		_nozzle.visible = holding
		if holding:
			var lh: Vector3 = _limbs["L"]["hand"].position
			var valve := _ext.position + _ext.transform.basis * Vector3(0, 0.25, 0)
			var nd := (lh - valve).normalized()
			_place(_hose, valve, lh - nd * 0.02)
			_place(_nozzle, lh - nd * 0.04, lh + nd * 0.1)
	if pointing:
		_place(_finger, h, h + dir * 0.24)
	_palm.visible = role == "navigator" and punch_t < 0.0 and gesture == Gesture.STOP and not outside
	if _palm.visible:
		_palm.position = h + Vector3(0, 0.1, -0.06)


## 2-bone IK. Returns the elbow position.
func _solve(side: String) -> Vector3:
	var s: Vector3 = SHOULDER[side]
	var v: Vector3 = (_cur[side] as Vector3) - s
	var d := clampf(v.length(), 0.08, UPPER + FORE - 0.01)
	var u := v.normalized() if v.length() > 0.001 else Vector3(0, 0, -1)
	var x := (UPPER * UPPER + d * d - FORE * FORE) / (2.0 * UPPER * d)
	var hgt := UPPER * sqrt(maxf(0.0, 1.0 - x * x))
	var pole: Vector3 = POLE[side]
	var perp := pole - u * pole.dot(u)
	if perp.length() < 0.01:
		perp = Vector3.DOWN
	perp = perp.normalized()
	var elbow := s + u * (UPPER * x) + perp * hgt
	var hand := s + u * d
	_place(_limbs[side]["up"], s, elbow)
	_place(_limbs[side]["fore"], elbow, hand)
	(_limbs[side]["hand"] as MeshInstance3D).position = hand
	return elbow


func _place(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var len_m := d.length()
	if len_m < 0.001:
		return
	var up := Vector3.UP
	if absf(d.normalized().dot(Vector3.UP)) > 0.97:
		up = Vector3.RIGHT
	var basis := Basis.looking_at(d, up)
	mi.transform = Transform3D(basis * Basis.from_scale(Vector3(1, 1, len_m)), (a + b) * 0.5)


# ====================================================================== podium ceremony

func _gold_mat(c: Color, glow := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.7
	m.roughness = 0.3
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = glow
	return m


func _pbox(parent: Node, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


## hang a medal around the neck (kind "silver" | "bronze" | "gold"); pops in with a little bounce
func give_medal(kind: String) -> void:
	if _medal:
		_medal.queue_free()
	var col := Color(0.82, 0.85, 0.9) if kind == "silver" else (Color(0.8, 0.5, 0.22) if kind == "bronze" else Color(1.0, 0.8, 0.2))
	var rib := StandardMaterial3D.new()
	rib.albedo_color = Color(0.1, 0.2, 0.55) if kind == "silver" else (Color(0.55, 0.1, 0.12) if kind == "bronze" else Color(0.7, 0.1, 0.12))
	_medal = Node3D.new()
	add_child(_medal)
	_pbox(_medal, Vector3(0.05, 0.62, 0.025), Vector3(-0.1, 0.27, -0.18), rib, Vector3(0, 0, -14))
	_pbox(_medal, Vector3(0.05, 0.62, 0.025), Vector3(0.1, 0.27, -0.18), rib, Vector3(0, 0, 14))
	_pbox(_medal, Vector3(0.22, 0.04, 0.05), Vector3(0, 0.6, 0.08), rib)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.11
	cm.bottom_radius = 0.11
	cm.height = 0.035
	cm.radial_segments = 16
	disc.mesh = cm
	disc.material_override = _gold_mat(col, 0.7)
	disc.rotation_degrees = Vector3(90, 0, 0)
	disc.position = Vector3(0, -0.03, -0.2)
	_medal.add_child(disc)
	var inner := MeshInstance3D.new()
	var cm2 := CylinderMesh.new()
	cm2.top_radius = 0.07
	cm2.bottom_radius = 0.07
	cm2.height = 0.045
	cm2.radial_segments = 16
	inner.mesh = cm2
	inner.material_override = _gold_mat(col.lightened(0.25), 0.9)
	inner.rotation_degrees = Vector3(90, 0, 0)
	inner.position = Vector3(0, -0.03, -0.2)
	_medal.add_child(inner)
	_medal.scale = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(_medal, "scale", Vector3.ONE * 1.25, 0.18)
	tw.tween_property(_medal, "scale", Vector3.ONE, 0.14)


## the cup is handed over: appears between the hands
func give_cup() -> void:
	if _cup:
		_cup.queue_free()
	_cup = Node3D.new()
	add_child(_cup)
	var g := _gold_mat(Color(1.0, 0.8, 0.2), 0.8)
	var dk := _gold_mat(Color(0.25, 0.2, 0.08), 0.1)
	_pbox(_cup, Vector3(0.26, 0.06, 0.26), Vector3(0, -0.2, 0), dk)
	_pbox(_cup, Vector3(0.2, 0.06, 0.2), Vector3(0, -0.14, 0), g)
	_pbox(_cup, Vector3(0.07, 0.2, 0.07), Vector3(0, -0.03, 0), g)
	_pbox(_cup, Vector3(0.14, 0.05, 0.14), Vector3(0, 0.08, 0), g)
	_pbox(_cup, Vector3(0.3, 0.2, 0.3), Vector3(0, 0.2, 0), g)             # bowl
	_pbox(_cup, Vector3(0.34, 0.04, 0.34), Vector3(0, 0.31, 0), g)         # rim
	for sx in [-1.0, 1.0]:                                                  # handles
		_pbox(_cup, Vector3(0.06, 0.16, 0.06), Vector3(sx * 0.2, 0.2, 0), g)
		_pbox(_cup, Vector3(0.1, 0.05, 0.06), Vector3(sx * 0.17, 0.3, 0), g)
		_pbox(_cup, Vector3(0.1, 0.05, 0.06), Vector3(sx * 0.17, 0.12, 0), g)
	_pbox(_cup, Vector3(0.08, 0.1, 0.01), Vector3(0, 0.2, -0.155), _gold_mat(Color(1.0, 0.95, 0.7), 1.2))   # shine plate
	_cup.scale = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(_cup, "scale", Vector3.ONE * 1.3, 0.22)
	tw.tween_property(_cup, "scale", Vector3.ONE, 0.15)


func start_podium() -> void:
	podium_t = 0.0


func _podium_targets() -> Array:
	var rest_l := Vector3(-0.34, -0.12, 0.05)
	var rest_r := Vector3(0.34, -0.12, 0.05)
	if podium_t < 0.0:
		return [rest_l, rest_r]
	var t := podium_t + podium_phase
	var pt := podium_t
	var dl := rest_l
	var dr := rest_r
	match podium_kind:
		"cup":
			var recv_l := Vector3(-0.17, 0.0, -0.42)
			var recv_r := Vector3(0.17, 0.0, -0.42)
			var up_l := Vector3(-0.16, 1.25, -0.1)
			var up_r := Vector3(0.16, 1.25, -0.1)
			if pt < 0.9:
				var k := smoothstep(0.0, 0.5, pt)
				dl = rest_l.lerp(recv_l, k)
				dr = rest_r.lerp(recv_r, k)
			elif pt < 1.9:
				var k2 := smoothstep(0.9, 1.9, pt)
				dl = recv_l.lerp(up_l, k2)
				dr = recv_r.lerp(up_r, k2)
			else:
				var p := sin((pt - 1.9) * 5.2)
				dl = up_l + Vector3(0, 0.05 * p, 0)
				dr = up_r + Vector3(0, 0.05 * p, 0)
		"silver":
			var chest_l := Vector3(-0.07, 0.1, -0.3)
			var chest_r := Vector3(0.07, 0.1, -0.3)
			var cyc := fmod(maxf(pt - 0.9, 0.0), 5.6)
			if pt < 0.9:
				var k := smoothstep(0.0, 0.5, pt)
				dl = rest_l.lerp(chest_l, k)
				dr = rest_r.lerp(chest_r, k)
			elif cyc < 1.2:                                  # kiss the medal
				var k2 := sin(clampf(cyc / 1.2, 0.0, 1.0) * PI)
				dr = chest_r.lerp(Vector3(0.05, 0.62, -0.28), k2)
				dl = chest_l.lerp(Vector3(-0.36, 0.0, -0.15), smoothstep(0.0, 0.4, cyc))
			elif cyc < 2.3:                                  # show it to the cameras
				var k3 := smoothstep(1.2, 1.6, cyc)
				dr = chest_r.lerp(Vector3(0.18, 0.72, -0.58), k3) + Vector3(0, sin(cyc * 9.0) * 0.02, 0)
				dl = Vector3(-0.36, 0.0, -0.15)
			elif cyc >= 3.6:                                 # Messi: both arms up, pointing to the sky
				var k5 := smoothstep(3.6, 4.1, cyc)
				var fl := sin((cyc - 3.6) * 6.0) * 0.03
				dr = Vector3(0.32, 0.95, -0.12).lerp(Vector3(0.2, 1.3 + fl, -0.06), k5)
				dl = Vector3(-0.32, 0.4, -0.4).lerp(Vector3(-0.2, 1.3 - fl, -0.06), k5)
			else:                                            # fist pumps
				var k4 := smoothstep(2.3, 2.6, cyc)
				var pump := absf(sin((cyc - 2.3) * 7.0)) * 0.22
				dr = chest_r.lerp(Vector3(0.32, 0.95 + pump, -0.12), k4)
				dl = Vector3(-0.36, 0.0, -0.15).lerp(Vector3(-0.32, 0.4, -0.4), k4 * 0.5)
		"bronze":
			var show_l := Vector3(-0.2, 0.32, -0.42)
			var show_r := Vector3(0.2, 0.32, -0.42)
			var cyc2 := fmod(maxf(pt - 0.8, 0.0), 4.2)
			if pt < 0.8:
				var k := smoothstep(0.0, 0.5, pt)
				dl = rest_l.lerp(show_l, k)
				dr = rest_r.lerp(show_r, k)
			elif cyc2 < 1.2:                                 # hold the ribbon out, look at the medal
				dl = show_l
				dr = show_r
			elif cyc2 < 2.6:                                 # arms wide "yeah!"
				var k2 := smoothstep(1.2, 1.6, cyc2)
				var shake := sin(cyc2 * 14.0) * 0.04
				dl = show_l.lerp(Vector3(-0.72, 0.9 + shake, -0.12), k2)
				dr = show_r.lerp(Vector3(0.72, 0.9 - shake, -0.12), k2)
			else:                                            # clap clap clap
				var k3 := smoothstep(2.6, 2.9, cyc2)
				var cl := 0.03 + 0.15 * absf(sin((cyc2 - 2.6) * 8.0))
				dl = Vector3(-0.72, 0.9, -0.12).lerp(Vector3(-cl, 0.55, -0.42), k3)
				dr = Vector3(0.72, 0.9, -0.12).lerp(Vector3(cl, 0.55, -0.42), k3)
		"cheer":
			var w := sin(t * 8.0) * 0.1
			dl = Vector3(-0.5 - w, 1.05 + w, -0.1)
			dr = Vector3(0.5 + w, 1.05 - w, -0.1)
	return [dl, dr]


func _podium_body(delta: float) -> void:
	var pt := podium_t
	if podium_t >= 0.0:
		podium_t += delta
	var t := podium_t + podium_phase
	var hop := 0.0
	var lean := 0.0
	var twist := 0.0
	var head_pitch := 0.0
	match podium_kind:
		"cup":
			if pt > 1.9:
				hop = absf(sin((pt - 1.9) * 2.6)) * 0.16
				lean = -0.14
				twist = sin((pt - 1.9) * 1.3) * 0.4
				head_pitch = 0.5
			elif pt > 0.0:
				head_pitch = -0.2 + clampf((pt - 0.9) / 1.0, 0.0, 1.0) * 0.7
		"silver":
			if pt > 0.9:
				var cyc := fmod(pt - 0.9, 5.6)
				head_pitch = -0.35 if cyc < 1.2 else (0.6 if cyc >= 3.6 else 0.0)
				if cyc > 2.3 and cyc < 3.6:
					hop = absf(sin((cyc - 2.3) * 7.0)) * 0.1
				elif cyc >= 3.6:
					hop = absf(sin((cyc - 3.6) * 3.0)) * 0.06
				twist = sin(cyc * 1.7) * 0.18
			elif pt > 0.0:
				head_pitch = -0.4
		"bronze":
			if pt > 0.8:
				var c2 := fmod(pt - 0.8, 4.2)
				head_pitch = -0.4 if c2 < 1.2 else (0.35 if c2 < 2.6 else 0.0)
				if c2 > 1.2 and c2 < 2.6:
					hop = absf(sin((c2 - 1.2) * 5.0)) * 0.12
				elif c2 >= 2.6:
					hop = absf(sin((c2 - 2.6) * 8.0)) * 0.05
			elif pt > 0.0:
				head_pitch = -0.4
		"cheer":
			if pt >= 0.0:
				hop = absf(sin(t * 5.5)) * 0.14
				twist = sin(t * 2.0) * 0.25
	_hop = lerpf(_hop, hop, clampf(delta * 18.0, 0.0, 1.0))
	position.y = podium_base_y + _hop
	rotation.x = lerpf(rotation.x, lean, clampf(delta * 6.0, 0.0, 1.0))
	rotation.y = lerpf(rotation.y, PI + twist, clampf(delta * 6.0, 0.0, 1.0))
	look_pitch = lerpf(look_pitch, head_pitch, clampf(delta * 8.0, 0.0, 1.0))
	# the cup stays glued between the hands (and spins a little for the shine)
	if _cup and is_instance_valid(_cup):
		var hl: Vector3 = _limbs["L"]["hand"].position
		var hr: Vector3 = _limbs["R"]["hand"].position
		_cup.position = (hl + hr) * 0.5 + Vector3(0, 0.16, 0)
