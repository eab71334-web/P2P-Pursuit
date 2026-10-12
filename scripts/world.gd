extends Node3D
## The race: builds the stage, the car, the HUD and runs the race flow.
## Server = authority (runs the car physics). Clients only send input and display the state.
## Roles: "driver" steers (sees the road only) / "navigator" reads the map + pace notes aloud.

enum State { WAITING, COUNTDOWN, RUNNING, FINISHED }

# name, max time (seconds), colour
const MEDALS := [
	["GOLD", 115.0, Color(1.0, 0.82, 0.25)],
	["SILVER", 140.0, Color(0.82, 0.84, 0.9)],
	["BRONZE", 180.0, Color(0.85, 0.52, 0.25)],
]

var track: Track
var car: Car
var cam: Camera3D
var state := State.WAITING
var race_time := 0.0
var prog_idx := 3
var my_role := "passenger"
var ready_peers := {}
var countdown_left := 3.5
var local_input := Vector3.ZERO     # steer, throttle, brake
var remote_input := Vector3.ZERO
var flip_timer := 0.0
var msg_timer := 0.0
var net_tick := 0
var have_net_state := false
var net_target := Transform3D.IDENTITY
var net_speed := 0.0
var touches := {}
var zones := {}
var show_touch := false

var hud: CanvasLayer
var hud_root: Control
var timer_label: Label
var medal_label: Label
var speed_label: Label
var role_label: Label
var center_label: Label
var msg_label: Label
var clipboard: Clipboard
var result_panel: PanelContainer


func _ready() -> void:
	if Net.roles.is_empty():   # started directly from the editor (F6) for testing
		Net.roles = {1: "driver"}
		Net.players = {1: "Test"}
		Net.required_players = 1
		Net.track_seed = randi()
	my_role = Net.roles.get(multiplayer.get_unique_id(), "passenger")
	show_touch = DisplayServer.is_touchscreen_available() and my_role == "driver"
	track = Track.generate(Net.track_seed)
	_build_environment()
	_build_track()
	_spawn_car()
	_build_hud()
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()
	if multiplayer.is_server():
		ready_peers[1] = true
		_check_all_ready()
	else:
		_send_ready()


# ====================================================================== networking

func _driver_id() -> int:
	for id in Net.roles:
		if Net.roles[id] == "driver":
			return id
	return 1


func _send_ready() -> void:
	while state == State.WAITING and is_inside_tree():
		client_ready.rpc_id(1)
		await get_tree().create_timer(0.5).timeout


@rpc("any_peer", "reliable")
func client_ready() -> void:
	if not multiplayer.is_server():
		return
	ready_peers[multiplayer.get_remote_sender_id()] = true
	_check_all_ready()


func _check_all_ready() -> void:
	if state != State.WAITING:
		return
	for id in Net.players:
		if not ready_peers.has(id):
			return
	begin_countdown.rpc()


@rpc("authority", "call_local", "reliable")
func begin_countdown() -> void:
	state = State.COUNTDOWN
	countdown_left = 3.5


@rpc("authority", "call_local", "reliable")
func race_started() -> void:
	state = State.RUNNING
	race_time = 0.0


@rpc("authority", "call_local", "reliable")
func race_finished(t: float) -> void:
	state = State.FINISHED
	race_time = t
	Net.race_over = true
	_show_result()


@rpc("authority", "call_local", "reliable")
func flash_message(text: String) -> void:
	msg_label.text = text
	msg_timer = 2.0


@rpc("any_peer", "unreliable_ordered")
func send_input(s: float, t: float, b: float) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == _driver_id():
		remote_input = Vector3(s, t, b)


@rpc("any_peer", "reliable")
func request_reset() -> void:
	if multiplayer.is_server():
		_do_reset()


@rpc("authority", "call_remote", "unreliable_ordered")
func net_state(p: Vector3, q: Quaternion, spd: float, steer: float, prog: int, t: float) -> void:
	net_target = Transform3D(Basis(q), p)
	net_speed = spd
	car.steer_visual = steer
	prog_idx = prog
	if state == State.RUNNING:
		race_time = t
	if not have_net_state:
		have_net_state = true
		car.global_transform = net_target


# ====================================================================== frame loop

func _process(delta: float) -> void:
	if state == State.COUNTDOWN:
		countdown_left -= delta
	if my_role == "driver":
		_read_input()
	if not multiplayer.is_server() and have_net_state:
		car.global_transform = car.global_transform.interpolate_with(net_target, clampf(delta * 18.0, 0.0, 1.0))
	if car:
		cam.rotation.z = -car.steer_visual * 0.025
	if msg_timer > 0.0:
		msg_timer -= delta
		if msg_timer <= 0.0:
			msg_label.text = ""
	_update_hud()


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var inp := Vector3.ZERO
	car.hold = state != State.RUNNING
	if state == State.COUNTDOWN and countdown_left <= 0.0:
		race_started.rpc()
	if state == State.RUNNING:
		inp = local_input if _driver_id() == 1 else remote_input
		race_time += delta
		_update_progress()
		if car.global_transform.basis.y.y < 0.25:
			flip_timer += delta
			if flip_timer > 2.0:
				_do_reset()
		else:
			flip_timer = 0.0
		if prog_idx >= track.points.size() - 4:
			race_finished.rpc(race_time)
	car.set_controls(inp.x, inp.y, inp.z)
	net_tick += 1
	if net_tick % 2 == 0:
		net_state.rpc(car.global_position, Quaternion(car.global_basis.orthonormalized()), car.speed_kmh, car.steer_target, prog_idx, race_time)


func _update_progress() -> void:
	var p := car.global_position
	var best := prog_idx
	var best_d := INF
	for i in range(maxi(0, prog_idx - 6), mini(track.points.size(), prog_idx + 40)):
		var q := track.points[i]
		var d := (p.x - q.x) * (p.x - q.x) + (p.z - q.z) * (p.z - q.z)
		if d < best_d:
			best_d = d
			best = i
	prog_idx = best


func _do_reset() -> void:
	var idx := maxi(3, prog_idx - 8)
	var t := Transform3D(Basis(Vector3.UP, track.headings[idx]), track.points[idx] + Vector3(0, 0.8, 0))
	car.teleport(t)
	flip_timer = 0.0
	flash_message.rpc("Back on the road")


func _request_reset() -> void:
	if state != State.RUNNING:
		return
	if multiplayer.is_server():
		_do_reset()
	else:
		request_reset.rpc_id(1)


# ====================================================================== input

func _zone_pressed(zone_name: String) -> bool:
	if not zones.has(zone_name):
		return false
	var r: Rect2 = zones[zone_name].get_global_rect()
	for pos in touches.values():
		if r.has_point(pos):
			return true
	return false


func _read_input() -> void:
	var steer := Input.get_axis("steer_left", "steer_right")
	var thr := Input.get_action_strength("accel")
	var brk := Input.get_action_strength("brake")
	if show_touch:
		if _zone_pressed("left"):
			steer -= 1.0
		if _zone_pressed("right"):
			steer += 1.0
		if _zone_pressed("gas"):
			thr = 1.0
		if _zone_pressed("brake"):
			brk = 1.0
	local_input = Vector3(clampf(steer, -1.0, 1.0), thr, brk)
	if not multiplayer.is_server() and state == State.RUNNING:
		send_input.rpc_id(1, local_input.x, local_input.y, local_input.z)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			if zones.has("reset") and zones["reset"].get_global_rect().has_point(event.position):
				_request_reset()
		else:
			touches.erase(event.index)
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not DisplayServer.is_touchscreen_available() and zones.has("reset") and zones["reset"].get_global_rect().has_point(event.position):
			_request_reset()
	elif event.is_action_pressed("reset"):
		_request_reset()


# ====================================================================== scene building

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


func _multimesh(mesh: Mesh, mat: Material, xforms: Array[Transform3D]) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	add_child(mi)


func _unit_box() -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3.ONE
	return b


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.42, 0.58, 0.85)
	sm.sky_horizon_color = Color(0.8, 0.86, 0.93)
	sm.ground_horizon_color = Color(0.8, 0.86, 0.93)
	sm.ground_bottom_color = Color(0.85, 0.9, 0.95)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.8, 0.86, 0.93)
	env.fog_density = 0.0035
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.0
	add_child(sun)


func _build_track() -> void:
	# ground
	var ground := StaticBody3D.new()
	var gs := CollisionShape3D.new()
	var gb := BoxShape3D.new()
	gb.size = Vector3(8000, 2, 8000)
	gs.shape = gb
	gs.position = Vector3(0, -1, 0)
	ground.add_child(gs)
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8000, 8000)
	gm.mesh = pm
	gm.material_override = _mat(Color(0.88, 0.92, 0.97))
	ground.add_child(gm)
	add_child(ground)

	var banks := StaticBody3D.new()
	add_child(banks)
	var road: Array[Transform3D] = []
	var dashes: Array[Transform3D] = []
	var bank_vis: Array[Transform3D] = []
	var W := Track.ROAD_WIDTH
	var n := track.points.size()
	for i in n - 1:
		var a := track.points[i]
		var b := track.points[i + 1]
		var d := b - a
		var yaw := atan2(-d.x, -d.z)
		var basis := Basis(Vector3.UP, yaw)
		var mid := (a + b) * 0.5
		var left := basis * Vector3(-1, 0, 0)
		road.append(Transform3D((basis * Basis.from_scale(Vector3(W, 0.2, Track.STEP * 1.12))), mid + Vector3(0, -0.07, 0)))
		if i % 2 == 0:
			dashes.append(Transform3D((basis * Basis.from_scale(Vector3(0.3, 0.02, 2.2))), mid + Vector3(0, 0.04, 0)))
		for side in [-1.0, 1.0]:
			var pos: Vector3 = mid + left * side * (W * 0.5 + 1.5) + Vector3(0, 0.7, 0)
			bank_vis.append(Transform3D((basis * Basis.from_scale(Vector3(3.0, 1.4, Track.STEP * 1.2))), pos))
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(3.0, 1.4, Track.STEP * 1.2)
			cs.shape = bs
			cs.transform = Transform3D(basis, pos)
			banks.add_child(cs)
	_multimesh(_unit_box(), _mat(Color(0.2, 0.21, 0.25)), road)
	_multimesh(_unit_box(), _mat(Color(0.95, 0.95, 0.95)), dashes)
	_multimesh(_unit_box(), _mat(Color(0.97, 0.98, 1.0)), bank_vis)

	_build_gate(3, Color(0.2, 0.8, 0.3))
	_build_gate(n - 4, Color(0.95, 0.95, 0.95))
	_build_trees()
	_build_mountains()


func _build_gate(idx: int, c: Color) -> void:
	var p := track.points[idx]
	var h := track.headings[idx]
	var basis := Basis(Vector3.UP, h)
	var left := basis * Vector3(-1, 0, 0)
	var half := Track.ROAD_WIDTH * 0.5 + 0.8
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.6, 6.0, 0.6)
		post.mesh = bm
		post.material_override = _mat(Color(0.8, 0.1, 0.1))
		post.position = p + left * side * half + Vector3(0, 3, 0)
		add_child(post)
	var beam := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(half * 2.0 + 0.6, 1.2, 0.5)
	beam.mesh = bb
	beam.material_override = _mat(c)
	beam.transform = Transform3D(basis, p + Vector3(0, 6.0, 0))
	add_child(beam)


func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Net.track_seed
	var trunks: Array[Transform3D] = []
	var leaves1: Array[Transform3D] = []
	var leaves2: Array[Transform3D] = []
	var n := track.points.size()
	var min_d2 := pow(Track.ROAD_WIDTH * 0.5 + 6.0, 2.0)
	for i in range(4, n - 2, 2):
		for side in [-1.0, 1.0]:
			if rng.randf() > 0.8:
				continue
			var left := Track.left_of(track.headings[i])
			var off := Track.ROAD_WIDTH * 0.5 + 6.0 + rng.randf_range(0.0, 30.0)
			var pos: Vector3 = track.points[i] + left * side * off + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
			var ok := true
			for q in track.points:
				var dx: float = q.x - pos.x
				var dz: float = q.z - pos.z
				if dx * dx + dz * dz < min_d2:
					ok = false
					break
			if not ok:
				continue
			var s := rng.randf_range(0.8, 1.7)
			var yaw := rng.randf() * TAU
			var b := Basis(Vector3.UP, yaw)
			trunks.append(Transform3D((b * Basis.from_scale(Vector3(0.5, 2.0 * s, 0.5))), pos + Vector3(0, s, 0)))
			leaves1.append(Transform3D((b * Basis.from_scale(Vector3(3.2 * s, 2.0 * s, 3.2 * s))), pos + Vector3(0, 2.8 * s, 0)))
			leaves2.append(Transform3D((b * Basis.from_scale(Vector3(2.0 * s, 1.8 * s, 2.0 * s))), pos + Vector3(0, 4.5 * s, 0)))
	_multimesh(_unit_box(), _mat(Color(0.35, 0.22, 0.12)), trunks)
	_multimesh(_unit_box(), _mat(Color(0.14, 0.4, 0.2)), leaves1)
	_multimesh(_unit_box(), _mat(Color(0.2, 0.5, 0.28)), leaves2)


func _build_mountains() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Net.track_seed + 1
	var xs: Array[Transform3D] = []
	var mid := track.points[track.points.size() / 2]
	for i in 26:
		var a := TAU * i / 26.0 + rng.randf_range(-0.1, 0.1)
		var dist := rng.randf_range(1500.0, 1900.0)
		var h := rng.randf_range(120.0, 320.0)
		var w := rng.randf_range(160.0, 320.0)
		var b := Basis(Vector3.UP, rng.randf() * TAU)
		xs.append(Transform3D((b * Basis.from_scale(Vector3(w, h, w))), mid + Vector3(cos(a) * dist, h * 0.4, sin(a) * dist)))
	_multimesh(_unit_box(), _mat(Color(0.8, 0.85, 0.93)), xs)


func _spawn_car() -> void:
	car = Car.new()
	car.name = "Car"
	car.setup(my_role, not multiplayer.is_server())
	var start := 3
	car.transform = Transform3D(Basis(Vector3.UP, track.headings[start]), track.points[start] + Vector3(0, 0.8, 0))
	add_child(car)
	cam = Camera3D.new()
	cam.fov = 80.0
	cam.near = 0.05
	cam.far = 2500.0
	car.add_child(cam)
	cam.position = car.seat_camera_position(my_role)
	cam.current = true
	# show the OTHER players' blocky characters
	for id in Net.roles:
		var role: String = Net.roles[id]
		if role != my_role and (role == "driver" or role == "navigator"):
			car.show_character(role, true)


# ====================================================================== HUD

func _style_label(l: Label, fs: int) -> void:
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _full_label(top: float, height: float, fs: int) -> Label:
	var l := Label.new()
	l.anchor_right = 1.0
	l.offset_top = top
	l.offset_bottom = top + height
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(l, fs)
	hud_root.add_child(l)
	return l


func _make_zone(zone_name: String, text: String, a_l: float, a_t: float, o_l: float, o_t: float, o_r: float, o_b: float) -> void:
	var p := Panel.new()
	p.anchor_left = a_l
	p.anchor_right = a_l
	p.anchor_top = a_t
	p.anchor_bottom = a_t
	p.offset_left = o_l
	p.offset_top = o_t
	p.offset_right = o_r
	p.offset_bottom = o_b
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.18)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(1, 1, 1, 0.5)
	sb.set_border_width_all(3)
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(l, 26)
	p.add_child(l)
	hud_root.add_child(p)
	zones[zone_name] = p


func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	hud_root = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hud_root)
	timer_label = _full_label(8, 56, 46)
	medal_label = _full_label(62, 34, 24)
	center_label = _full_label(0, 160, 120)
	center_label.anchor_top = 0.2
	center_label.anchor_bottom = 0.2
	center_label.offset_top = 0
	center_label.offset_bottom = 160
	msg_label = _full_label(0, 50, 30)
	msg_label.anchor_top = 0.42
	msg_label.anchor_bottom = 0.42
	msg_label.offset_top = 0
	msg_label.offset_bottom = 50
	role_label = Label.new()
	role_label.position = Vector2(14, 8)
	role_label.text = "DRIVER" if my_role == "driver" else ("CO-DRIVER" if my_role == "navigator" else "PASSENGER")
	_style_label(role_label, 22)
	hud_root.add_child(role_label)
	speed_label = Label.new()
	speed_label.position = Vector2(14, 36)
	_style_label(speed_label, 22)
	hud_root.add_child(speed_label)

	_make_zone("reset", "RESET (R)", 1.0, 0.0, -150, 14, -14, 64)
	if show_touch:
		_make_zone("left", "<", 0.0, 1.0, 20, -170, 160, -40)
		_make_zone("right", ">", 0.0, 1.0, 180, -170, 320, -40)
		_make_zone("gas", "GAS", 1.0, 1.0, -170, -190, -20, -40)
		_make_zone("brake", "BRAKE", 1.0, 1.0, -340, -170, -190, -40)

	# only the co-driver (and solo practice) sees the map + pace notes
	if my_role != "driver" or Net.required_players == 1:
		clipboard = Clipboard.new()
		clipboard.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clipboard.set_track(track)
		hud_root.add_child(clipboard)


func _update_layout() -> void:
	if clipboard == null:
		return
	var vs := get_viewport().get_visible_rect().size
	if vs.y > vs.x:
		var w := vs.x * 0.9
		var h := vs.y * (0.36 if show_touch else 0.46)
		var y := 110.0 if show_touch else vs.y - h - 20.0
		clipboard.position = Vector2((vs.x - w) * 0.5, y)
		clipboard.size = Vector2(w, h)
	else:
		var h := vs.y * (0.5 if show_touch else 0.8)
		var w := minf(vs.x * 0.34, h * 0.8)
		clipboard.position = Vector2(vs.x - w - 20.0, 76.0)
		clipboard.size = Vector2(w, h)
	clipboard.queue_redraw()


func _fmt(t: float) -> String:
	return "%d:%04.1f" % [int(t / 60.0), fmod(t, 60.0)]


func _update_hud() -> void:
	timer_label.text = _fmt(maxf(race_time, 0.0))
	var spd := car.speed_kmh if multiplayer.is_server() else net_speed
	speed_label.text = "%d km/h" % int(spd)
	var shown := false
	for m in MEDALS:
		if race_time <= m[1]:
			medal_label.text = "%s  %s" % [m[0], _fmt(m[1])]
			medal_label.add_theme_color_override("font_color", m[2])
			shown = true
			break
	if not shown:
		medal_label.text = "NO MEDAL"
		medal_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	match state:
		State.WAITING:
			center_label.text = ""
			msg_label.text = "Waiting for all players to load..."
			msg_timer = 0.1
		State.COUNTDOWN:
			center_label.text = str(ceili(countdown_left)) if countdown_left > 0.0 else "GO!"
		State.RUNNING:
			center_label.text = "GO!" if race_time < 1.0 else ""
		State.FINISHED:
			center_label.text = ""
	if clipboard:
		clipboard.set_progress(prog_idx)


func _show_result() -> void:
	var medal := "No medal"
	for m in MEDALS:
		if race_time <= m[1]:
			medal = m[0]
			break
	result_panel = PanelContainer.new()
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	result_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	result_panel.add_child(vb)
	var title := Label.new()
	title.text = "FINISH!"
	title.add_theme_font_size_override("font_size", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var res := Label.new()
	res.text = "Time  %s\nMedal  %s" % [_fmt(race_time), medal]
	res.add_theme_font_size_override("font_size", 34)
	res.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(res)
	var btn := Button.new()
	btn.text = "Back to menu"
	btn.custom_minimum_size = Vector2(320, 70)
	btn.add_theme_font_size_override("font_size", 28)
	btn.pressed.connect(Net.return_to_menu)
	vb.add_child(btn)
	hud_root.add_child(result_panel)
