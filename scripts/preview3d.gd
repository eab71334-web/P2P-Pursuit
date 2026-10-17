class_name Preview3D
extends SubViewportContainer
## A little 3D showroom (turntable) for cars and characters, used by the garage / workshop / character screens.

var vp: SubViewport
var pivot: Node3D
var cam: Camera3D
var car: Car
var avatar: Avatar
var spin := true
var hero := false             # big menu background showroom
var yaw := 0.4
var _drag := false
var _t := 0.0
var _flash := 0.0
var _ring: MeshInstance3D


func _init() -> void:
	stretch = true
	custom_minimum_size = Vector2(340, 300)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
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
	cam.position = Vector3(0, 3.8, 10.6)
	cam.look_at(Vector3(0, 0.9, 0))


func _frame_avatar() -> void:
	cam.position = Vector3(0, 1.3, 5.6)
	cam.look_at(Vector3(0, 1.0, 0))


func _clear() -> void:
	if car:
		car.queue_free()
		car = null
	if avatar:
		avatar.queue_free()
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
	_frame_car()
	_flash = 1.0


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


func play_emote(id: String) -> void:
	if avatar:
		avatar.play_emote(id)


func _process(d: float) -> void:
	_t += d
	if spin and not _drag:
		yaw += d * (0.3 if hero else 0.55)
	pivot.rotation.y = yaw
	if hero:
		pivot.position.y = sin(_t * 1.6) * 0.025
		cam.position.x = sin(_t * 0.35) * 0.8
		cam.look_at(Vector3(0, 0.9, 0))
	if avatar and avatar.emote == "spin":
		pass
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - d * 2.0)
		pivot.scale = Vector3.ONE * (1.0 + sin(_flash * PI) * 0.04)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag = event.pressed
	elif event is InputEventMouseMotion and _drag:
		yaw += event.relative.x * 0.012
	elif event is InputEventScreenDrag:
		yaw += event.relative.x * 0.012
