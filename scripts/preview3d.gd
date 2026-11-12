# Copyright (c) 2026 KRG Studios. All rights reserved. See LICENSE.
class_name Preview3D
extends SubViewportContainer
## A little 3D showroom (turntable) for cars and characters, used by the garage / workshop / character screens.

var vp: SubViewport
var pivot: Node3D
var cam: Camera3D
var car: Car
var avatar: Avatar
var spin := true
var zoom := 1.0
var hero := false             # big menu background showroom
var yaw := 0.4
var view := "car"             # "car" (turntable), "engine" (hood open, looking into the bay), "wheel" (close on a front wheel)
var _tpos := Vector3.ZERO
var _tlook := Vector3(0, 0.9, 0)
var _clook := Vector3(0, 0.9, 0)
var _tfov := 38.0
var _tyaw := 0.0
var _cam_ready := false
var _painter: Avatar
var _gun: Node3D
var _mist: CPUParticles3D
var _spray_t := -1.0
var _spray_final := ""
var _spray_done := Callable()
var _spray_old := Color.WHITE
var _drag := false
var _t := 0.0
var _flash := 0.0
var _ring: MeshInstance3D


func _init() -> void:
	stretch = true
	custom_minimum_size = Vector2(340, 300)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	resized.connect(func(): if view != "car" and _cam_ready: _apply_view())
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Gfx.subviewport_msaa()
	if Gfx.scale < 0.7:
		stretch_shrink = 2
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(440, 360)
	add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.055, 0.07)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.84, 0.92)
	e.ambient_light_energy = 0.85
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 150, 0)
	rim.light_energy = 0.6
	rim.light_color = Color(1.0, 0.6, 0.35)
	vp.add_child(rim)
	cam = Camera3D.new()
	cam.fov = 38.0
	vp.add_child(cam)
	# podium
	var pod := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 3.3
	cm.bottom_radius = 3.5
	cm.height = 0.2
	cm.radial_segments = 40
	pod.mesh = cm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.1, 0.105, 0.125)
	pm.roughness = 0.5
	pod.material_override = pm
	pod.position.y = -0.1
	vp.add_child(pod)
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 3.25
	tm.outer_radius = 3.4
	tm.rings = 40
	tm.ring_segments = 6
	_ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(1.0, 0.8, 0.2)
	rm.emission_enabled = true
	rm.emission = Color(1.0, 0.7, 0.1)
	rm.emission_energy_multiplier = 1.5
	_ring.material_override = rm
	_ring.position.y = 0.02
	vp.add_child(_ring)
	pivot = Node3D.new()
	vp.add_child(pivot)
	if hero:
		var fog_e := e
		fog_e.fog_enabled = true
		fog_e.fog_light_color = Color(0.05, 0.055, 0.07)
		fog_e.fog_density = 0.012
		var side := -1.0 if L.is_ar() else 1.0
		pod.mesh.set("top_radius", 3.9)
		pod.mesh.set("bottom_radius", 4.1)
		(_ring.mesh as TorusMesh).inner_radius = 3.86
		(_ring.mesh as TorusMesh).outer_radius = 3.93
		pod.position.x = 3.0 * side
		_ring.position.x = 3.0 * side
		pivot.position.x = 3.0 * side
		var spot := SpotLight3D.new()
		spot.position = Vector3(0, 9, 3)
		spot.rotation_degrees = Vector3(-90, 0, 0)
		spot.spot_range = 20.0
		spot.spot_angle = 38.0
		spot.light_energy = 2.4
		vp.add_child(spot)
	_frame_car()


func _frame_car() -> void:
	if hero:
		cam.position = Vector3(0, 3.5, 13.6)
		cam.look_at(Vector3(0, 0.9, 0))
		return
	_apply_view()
	if not _cam_ready:       # first frame: no sliding in from nowhere
		cam.position = _tpos
		cam.fov = _tfov
		cam.look_at(_tlook)
		_clook = _tlook
		_cam_ready = true


## garage sections move the camera: the engine tab opens the hood and looks into the bay, the wheels tab goes in close on a wheel
func set_view(v: String) -> void:
	if v == view:
		return
	view = v
	if not hero:
		spin = (v == "car")
	if car:
		car.hood_up = (v == "engine")
	_apply_view()
	_kick()


func _apply_view() -> void:
	match view:
		"engine":
			_tyaw = PI + 0.95
			var bay := Vector3(0.0, 1.0, -1.7).rotated(Vector3.UP, _tyaw)
			_tlook = bay + Vector3(0, 0.3, 0)
			_tpos = bay + Vector3(0.0, 2.4, 4.0) * zoom * 1.2
			_tfov = 38.0
		"wheel":
			_tyaw = -PI * 0.5
			var wh := Vector3(0.95, 0.45, -1.3).rotated(Vector3.UP, _tyaw)
			_tlook = wh + Vector3(0, -0.2, 0)
			_tpos = wh + Vector3(0.3, 0.45, 3.3) * zoom * 1.7
			_tfov = 30.0
		"stick_side":
			_tyaw = -PI * 0.5
			_tlook = Vector3(0, 0.95, 0)
			_tpos = Vector3(0.0, 1.5, 7.0) * zoom * 1.35
			_tfov = 38.0
		"spray":
			_tyaw = -PI * 0.5
			_tlook = Vector3(1.0, 1.0, 0.0)
			_tpos = Vector3(0.9, 1.8, 8.0) * zoom * 1.5
			_tfov = 38.0
		"stick_hood":
			_tyaw = PI
			var hc := Vector3(0.0, 1.2, -1.65).rotated(Vector3.UP, _tyaw)
			_tlook = hc
			_tpos = hc + Vector3(0.0, 2.6, 2.4) * zoom * 1.3
			_tfov = 38.0
		_:
			_tlook = Vector3(0, 0.9, 0)
			_tpos = Vector3(0, 3.8 * zoom, 10.6 * zoom)
			_tfov = 38.0
	if view != "car":
		# short screens (wide phones): pull the camera back so the car is not cut off
		var k := 1.0
		if size.y > 10.0:
			k = clampf(400.0 / size.y, 1.0, 1.55)
		_tpos = _tlook + (_tpos - _tlook) * k


func _frame_avatar() -> void:
	cam.position = Vector3(0, 1.3, 5.6)
	cam.look_at(Vector3(0, 1.0, 0))


func _clear() -> void:
	# remove right now (not at end of frame) so the old and the new model are never drawn together
	if car:
		pivot.remove_child(car)
		car.free()
		car = null
	if avatar:
		pivot.remove_child(avatar)
		avatar.free()
		avatar = null


func show_car(lo: Dictionary) -> void:
	_clear()
	car = Car.new()
	car.setup(0, Color(0.2, 0.8, 0.3), false, lo, true)
	pivot.add_child(car)
	car.set_plate_text(Profile.pname)
	var rar := int(Catalog.CARS.get(lo.get("car", "hatch"), Catalog.CARS["hatch"])["r"])
	((_ring.material_override) as StandardMaterial3D).albedo_color = Catalog.RARITY_COLOR[rar]
	((_ring.material_override) as StandardMaterial3D).emission = Catalog.RARITY_COLOR[rar]
	car.hood_up = (view == "engine")
	_frame_car()
	_flash = 1.0
	_kick()


func show_avatar(outfit: Dictionary) -> void:
	_clear()
	avatar = Avatar.new()
	avatar.role = "preview"
	avatar.standing = true
	avatar.helmet_color = Color(0.85, 0.12, 0.14)
	avatar.shirt_color = Color(0.7, 0.12, 0.15)
	avatar.outfit = outfit
	avatar.position = Vector3(0, 0.97, 0)
	pivot.add_child(avatar)
	_frame_avatar()
	_flash = 1.0
	_kick()


## weak-device mode: no continuous 3D rendering in menus, only a refresh when something changes
func _kick() -> void:
	if vp == null:
		return
	if hero and not Gfx.hero:
		spin = false
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		get_tree().create_timer(0.35).timeout.connect(func():
			if is_instance_valid(vp):
				vp.render_target_update_mode = SubViewport.UPDATE_ONCE)


func play_emote(id: String) -> void:
	if avatar:
		avatar.play_emote(id)


func _process(d: float) -> void:
	_t += d
	if _spray_t >= 0.0 and _painter and _gun:
		_spray_step(d)
	if spin and not _drag:
		yaw += d * (0.3 if hero else 0.55)
	if view != "car" and not hero:
		yaw = lerp_angle(yaw, _tyaw, clampf(d * 3.5, 0.0, 1.0))
	pivot.rotation.y = yaw
	if not hero and avatar == null and _cam_ready:
		var k := clampf(d * 4.0, 0.0, 1.0)
		cam.position = cam.position.lerp(_tpos, k)
		cam.fov = lerpf(cam.fov, _tfov, k)
		_clook = _clook.lerp(_tlook, k)
		cam.look_at(_clook)
	if hero:
		pivot.position.y = sin(_t * 1.6) * 0.025
		cam.position.x = sin(_t * 0.35) * 0.8
		cam.look_at(Vector3(0, 0.9, 0))
	if avatar and avatar.emote == "spin":
		pass
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - d * 2.0)
		pivot.scale = Vector3.ONE * (1.0 + sin(_flash * PI) * 0.04)


# ---------------------------------------------------------------- spray-paint reveal (random paint)

## a painter walks up with a spray gun and re-sprays the car; the colour flickers through random paints and settles on the winner
func play_spray(final_paint: String, on_done: Callable) -> void:
	if car == null:
		return
	end_spray()
	set_view("spray")
	_spray_final = final_paint
	_spray_done = on_done
	_spray_t = 0.0
	_spray_old = car.body_color
	_painter = Avatar.new()
	_painter.role = "preview"
	_painter.helmet_color = Color(0.85, 0.12, 0.14)
	_painter.shirt_color = Color(0.9, 0.9, 0.95)
	_painter.outfit = Profile.outfit
	_painter.position = Vector3(3.5, 0.97, 0.2)
	vp.add_child(_painter)
	_painter.go_outside(Vector3(3.5, 0.97, 0.2))
	_painter.work = 3
	_painter.rotation.y = PI * 0.5
	_gun = Node3D.new()
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.15, 0.15, 0.18)
	gm.metallic = 0.6
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.9, 0.9, 0.95)
	cm.metallic = 0.8
	cm.roughness = 0.3
	for part in [[Vector3(0.07, 0.1, 0.26), Vector3(0, 0, 0), gm], [Vector3(0.04, 0.04, 0.16), Vector3(0, 0.02, -0.2), cm], [Vector3(0.1, 0.14, 0.1), Vector3(0, 0.12, 0.02), cm]]:
		var mi := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = part[0]
		mi.mesh = bx
		mi.material_override = part[2]
		mi.position = part[1]
		_gun.add_child(mi)
	vp.add_child(_gun)
	_mist = CPUParticles3D.new()
	_mist.emitting = false
	_mist.amount = 90
	_mist.lifetime = 0.55
	_mist.direction = Vector3(0, 0, -1)
	_mist.spread = 9.0
	_mist.initial_velocity_min = 3.2
	_mist.initial_velocity_max = 4.4
	_mist.gravity = Vector3(0, -0.6, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	_mist.mesh = sm
	_mist.scale_amount_min = 0.5
	_mist.scale_amount_max = 1.6
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.vertex_color_use_as_albedo = true
	mm.albedo_color = Color.WHITE
	_mist.material_override = mm
	_mist.color = Color.WHITE
	_gun.add_child(_mist)
	_mist.position = Vector3(0, 0.02, -0.3)


func end_spray() -> void:
	_spray_t = -1.0
	for n in [_painter, _gun]:
		if n and is_instance_valid(n):
			n.queue_free()
	_painter = null
	_gun = null
	_mist = null


func _spray_step(d: float) -> void:
	_spray_t += d
	var t := _spray_t
	var tgt: Color = Catalog.PAINTS[_spray_final]["c"]
	# the gun follows the painter's right hand and sweeps over the front of the car
	var hand := _painter.hand_world("r")
	var aim := Vector3(2.0, 0.95 + 0.35 * sin(t * 3.1), sin(t * 1.7) * 0.9)
	_gun.global_position = hand
	_gun.look_at(aim, Vector3.UP)
	var spraying := t > 0.7 and t < 4.6
	_mist.emitting = spraying
	var shown: Color
	if t < 0.7:
		shown = _spray_old
	elif t < 3.6:
		var pal: Array = Catalog.PAINT_ORDER
		shown = Catalog.PAINTS[pal[int(t * 9.0) % pal.size()]]["c"]        # the colour flickers through the paints
	else:
		shown = (Catalog.PAINTS[Catalog.PAINT_ORDER[int(3.6 * 9.0) % Catalog.PAINT_ORDER.size()]]["c"] as Color).lerp(tgt, clampf((t - 3.6) / 1.0, 0.0, 1.0))
	_mist.color = shown
	if car and car.body_mat:
		car.body_mat.albedo_color = shown
		if t > 4.6:
			car.body_mat.metallic = float(Catalog.PAINTS[_spray_final]["m"])
			car.body_mat.roughness = float(Catalog.PAINTS[_spray_final]["ro"])
	if t > 5.0:
		var cb := _spray_done
		end_spray()
		set_view("car")
		if cb.is_valid():
			cb.call()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag = event.pressed
	elif event is InputEventMouseMotion and _drag:
		yaw += event.relative.x * 0.012
	elif event is InputEventScreenDrag:
		yaw += event.relative.x * 0.012
