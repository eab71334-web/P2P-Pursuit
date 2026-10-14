extends Node3D
## The race. Server = authority (runs every car's physics). Clients send input and show the state.
## Each team = 1 car with 2 players: the DRIVER steers, the CO-DRIVER (map holder) reads the map,
## points with the right hand, warns about closed roads and can drop a signal beacon.
## Both can look around and punch each other.

enum State { WAITING, COUNTDOWN, RUNNING, ENDED }

# name, max time (seconds), colour
const MEDALS := [
	["GOLD", 115.0, Color(1.0, 0.82, 0.25)],
	["SILVER", 140.0, Color(0.82, 0.84, 0.9)],
	["BRONZE", 180.0, Color(0.85, 0.52, 0.25)],
]
const TEAM_COLORS := [Color(0.82, 0.1, 0.1), Color(0.15, 0.4, 0.95), Color(0.15, 0.7, 0.3), Color(0.95, 0.72, 0.1)]
const PLACES := ["1st", "2nd", "3rd", "4th"]
const GESTURE_TEXT := ["", "<  CO-DRIVER SAYS: LEFT", "^  CO-DRIVER SAYS: STRAIGHT", "CO-DRIVER SAYS: RIGHT  >", "!!  STOP / WARNING  !!"]


const THEMES := {
	"snow": {"top": Color(0.42, 0.58, 0.85), "hor": Color(0.8, 0.86, 0.93), "fog": 0.0035, "ground": Color(0.88, 0.92, 0.97),
		"bank": Color(0.97, 0.98, 1.0), "road": Color(0.2, 0.21, 0.25), "trunk": Color(0.35, 0.22, 0.12),
		"l1": Color(0.14, 0.4, 0.2), "l2": Color(0.2, 0.5, 0.28), "mount": Color(0.8, 0.85, 0.93)},
	"autumn": {"top": Color(0.5, 0.62, 0.8), "hor": Color(0.95, 0.85, 0.7), "fog": 0.004, "ground": Color(0.5, 0.36, 0.18),
		"bank": Color(0.55, 0.42, 0.25), "road": Color(0.3, 0.26, 0.22), "trunk": Color(0.3, 0.18, 0.1),
		"l1": Color(0.85, 0.4, 0.1), "l2": Color(0.9, 0.62, 0.15), "mount": Color(0.6, 0.45, 0.35)},
	"mountain": {"top": Color(0.3, 0.45, 0.75), "hor": Color(0.75, 0.82, 0.9), "fog": 0.0028, "ground": Color(0.22, 0.3, 0.25),
		"bank": Color(0.6, 0.6, 0.64), "road": Color(0.22, 0.22, 0.25), "trunk": Color(0.3, 0.2, 0.12),
		"l1": Color(0.1, 0.3, 0.18), "l2": Color(0.14, 0.38, 0.22), "mount": Color(0.55, 0.57, 0.62), "pillar": Color(0.42, 0.4, 0.4)},
}


class TeamState extends RefCounted:
	var idx := 0
	var color := Color.RED
	var car: Car
	var driver_id := 0
	var nav_id := 0
	var prog := 3
	var finished := false
	var dnf := false
	var finish_time := 0.0
	var flip := 0.0
	var wrong := false
	var input := Vector3.ZERO
	var disturb := 0.0
	var disturb_dir := 1.0
	var beacon_ms := 0
	var target := Transform3D.IDENTITY
	var have_net := false
	var speed := 0.0
	var penalty := 0.0


var track: Track
var th: Dictionary
var blind_mode := false
var ipad_vp: SubViewport
var map_mode := false
var _pillars: Array[Transform3D] = []
var _road_body: StaticBody3D
var teams: Array[TeamState] = []
var avatars := {}                  # peer id -> Avatar
var local_avatar: Avatar
var my_id := 1
var my_role := "driver"
var my_team := 0
var solo := false
var state := State.WAITING
var race_time := 0.0
var countdown_left := 3.5
var ready_peers := {}
var results: Array[int] = []       # team indices in finishing order
var net_tick := 0
var last_punch := {}
var look_yaw := 0.0
var look_pitch := 0.0
var look_idle := 0.0
var look_touch := -1
var look_send_ms := 0
var shake := 0.0
var flash := 0.0
var my_gesture := 0
var mate_gesture := 0
var beacon_node: Node3D
var beacon_timer := 0.0
var touches := {}
var zone_touch := {}
var zones := {}
var tap_zones := {}
var show_touch := false
var msg_timer := 0.0

var hud: CanvasLayer
var hud_root: Control
var timer_label: Label
var medal_label: Label
var speed_label: Label
var role_label: Label
var rank_label: Label
var center_label: Label
var msg_label: Label
var gesture_label: Label
var alert_label: Label
var flash_rect: ColorRect
var clipboard: Clipboard
var result_panel: PanelContainer
var result_standings: Label


func _ready() -> void:
	if Net.roles.is_empty():   # started directly from the editor (F6) for testing
		Net.roles = {1: "driver"}
		Net.team_of = {1: 0}
		Net.team_count = 1
		Net.players = {1: "Test"}
		Net.required_players = 1
		Net.stage = Track.design_stage(randi())
		Net.track_seed = int(Net.stage["seed"])
		Net.blind = false
	my_id = multiplayer.get_unique_id()
	my_role = Net.roles.get(my_id, "driver")
	my_team = Net.team_of.get(my_id, 0)
	solo = Net.players.size() == 1
	show_touch = DisplayServer.is_touchscreen_available() and my_role == "driver"
	if Net.stage.is_empty():
		Net.stage = {"seed": Net.track_seed}
	track = Track.from_stage(Net.stage)
	th = THEMES[track.theme]
	blind_mode = Net.blind and my_role == "driver" and not solo
	if my_role == "navigator" and not solo:
		_build_ipad()
	_build_environment()
	_build_track()
	_build_obstacles()
	_build_teams()
	_build_hud()
	Net.peer_left.connect(_on_peer_left)
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()
	if multiplayer.is_server():
		ready_peers[1] = true
		_check_all_ready()
	else:
		_send_ready()


# ====================================================================== networking

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
func team_finished(team: int, t: float, place: int) -> void:
	var ts := teams[team]
	ts.finished = true
	ts.finish_time = t
	if not results.has(team):
		results.append(team)
	if team == my_team:
		Net.race_over = true
		_show_result(place, t)
	_refresh_result()


@rpc("authority", "call_local", "reliable")
func team_dnf(team: int) -> void:
	teams[team].dnf = true
	flash_message("Team %s is out" % char(65 + team))
	_refresh_result()


@rpc("authority", "call_local", "reliable")
func all_done() -> void:
	state = State.ENDED
	Net.race_over = true


@rpc("authority", "call_local", "reliable")
func show_message(text: String) -> void:
	flash_message(text)


func flash_message(text: String) -> void:
	msg_label.text = text
	msg_timer = 2.0


@rpc("any_peer", "unreliable_ordered")
func send_input(s: float, t: float, b: float) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if Net.roles.get(sender, "") == "driver":
		teams[Net.team_of[sender]].input = Vector3(s, t, b)


@rpc("any_peer", "reliable")
func request_reset() -> void:
	if multiplayer.is_server():
		_server_reset(multiplayer.get_remote_sender_id())


@rpc("authority", "call_remote", "unreliable_ordered")
func net_state(arr: PackedFloat32Array, t: float) -> void:
	if arr.size() != teams.size() * 12:
		return
	for i in teams.size():
		var b := i * 12
		var ts := teams[i]
		ts.target = Transform3D(Basis(Quaternion(arr[b + 3], arr[b + 4], arr[b + 5], arr[b + 6])), Vector3(arr[b], arr[b + 1], arr[b + 2]))
		ts.speed = arr[b + 7]
		ts.car.steer_visual = arr[b + 8]
		ts.prog = int(arr[b + 9])
		var flags := int(arr[b + 10])
		ts.wrong = (flags & 1) != 0
		if not ts.have_net:
			ts.have_net = true
			ts.car.global_transform = ts.target
	if state == State.RUNNING:
		race_time = t


# --- look / gestures / punches / beacon (everything is relayed through the server)

@rpc("any_peer", "unreliable_ordered")
func send_look(yaw: float, pitch: float) -> void:
	if not multiplayer.is_server():
		return
	var s := multiplayer.get_remote_sender_id()
	if avatars.has(s):
		(avatars[s] as Avatar).set_look(yaw, pitch)
	look_sync.rpc(s, yaw, pitch)


@rpc("authority", "call_remote", "unreliable_ordered")
func look_sync(peer: int, yaw: float, pitch: float) -> void:
	if peer != my_id and avatars.has(peer):
		(avatars[peer] as Avatar).set_look(yaw, pitch)


@rpc("any_peer", "reliable")
func request_gesture(g: int) -> void:
	if multiplayer.is_server():
		_server_gesture(multiplayer.get_remote_sender_id(), g)


func _server_gesture(peer: int, g: int) -> void:
	if Net.roles.get(peer, "") != "navigator" and not solo:
		return
	gesture_sync.rpc(peer, g)


@rpc("authority", "call_local", "reliable")
func gesture_sync(peer: int, g: int) -> void:
	if not avatars.has(peer):
		return
	(avatars[peer] as Avatar).gesture = g
	if peer == my_id:
		my_gesture = g
	if Net.team_of.get(peer, -1) == my_team and peer != my_id:
		mate_gesture = g


@rpc("any_peer", "reliable")
func request_punch() -> void:
	if multiplayer.is_server():
		_server_punch(multiplayer.get_remote_sender_id())


func _mate_of(peer: int) -> int:
	var ts := teams[Net.team_of.get(peer, 0)]
	var m := ts.nav_id if peer == ts.driver_id else ts.driver_id
	return m if avatars.has(m) else -1


func _server_punch(peer: int) -> void:
	var now := Time.get_ticks_msec()
	if now - int(last_punch.get(peer, 0)) < 600 or not avatars.has(peer):
		return
	last_punch[peer] = now
	var mate := _mate_of(peer)
	var hit := false
	if mate != -1:
		var a: Avatar = avatars[peer]
		var to_mate: Vector3 = (avatars[mate] as Avatar).position - a.position
		to_mate.y = 0.0
		to_mate = to_mate.normalized()
		var look_dir := Basis(Vector3.UP, a.look_yaw) * Vector3(0, 0, -1)
		hit = look_dir.dot(to_mate) > 0.5
	punch_fx.rpc(peer)
	if hit:
		var ts := teams[Net.team_of[mate]]
		if mate == ts.driver_id:   # the driver gets knocked: the wheel jerks for a moment
			ts.disturb = 0.5
			ts.disturb_dir = 1.0 if randf() < 0.5 else -1.0
		hit_fx.rpc(mate)


@rpc("authority", "call_local", "reliable")
func punch_fx(peer: int) -> void:
	if avatars.has(peer):
		(avatars[peer] as Avatar).punch()


@rpc("authority", "call_local", "reliable")
func hit_fx(victim: int) -> void:
	if avatars.has(victim):
		(avatars[victim] as Avatar).play_hit()
	if victim == my_id:
		shake = 1.0
		flash = 0.55
		Input.vibrate_handheld(250)
		for d in Input.get_connected_joypads():
			Input.start_joy_vibration(d, 0.8, 1.0, 0.3)


@rpc("any_peer", "reliable")
func request_beacon() -> void:
	if multiplayer.is_server():
		_server_beacon(multiplayer.get_remote_sender_id())


func _server_beacon(peer: int) -> void:
	if Net.roles.get(peer, "") != "navigator" and not solo:
		return
	var ts := teams[Net.team_of.get(peer, 0)]
	var now := Time.get_ticks_msec()
	if now - ts.beacon_ms < 4000 or ts.finished:
		return
	ts.beacon_ms = now
	beacon_fx.rpc(ts.idx, mini(ts.prog + 10, track.points.size() - 1))


@rpc("authority", "call_local", "reliable")
func beacon_fx(team: int, idx: int) -> void:
	if team == my_team:
		_spawn_beacon(idx)


func _on_peer_left(id: int) -> void:
	if not multiplayer.is_server():
		return
	var team: int = Net.team_of.get(id, -1)
	if team < 0:
		return
	var ts := teams[team]
	if ts.finished:
		return
	if id == ts.driver_id:
		ts.dnf = true
		team_dnf.rpc(team)
		_check_all_done()
	else:
		show_message.rpc("Team %s: the co-driver left" % char(65 + team))


func _check_all_done() -> void:
	if state == State.ENDED:
		return
	for ts in teams:
		if not ts.finished and not ts.dnf:
			return
	all_done.rpc()


# ====================================================================== server simulation

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if state == State.COUNTDOWN and countdown_left <= 0.0:
		race_started.rpc()
	if state == State.RUNNING:
		race_time += delta
	for ts in teams:
		var inp := Vector3.ZERO
		var active := state == State.RUNNING and not ts.finished and not ts.dnf
		ts.car.hold = not active
		if active:
			inp = ts.input
			if ts.disturb > 0.0:
				ts.disturb -= delta
				inp.x = clampf(inp.x + ts.disturb_dir * 0.9, -1.0, 1.0)
			_update_progress(ts)
			ts.car.set_grip(0.28 if (track.ice_at(ts.prog) and not ts.wrong) else 1.0)
			if ts.car.global_position.y < track.y_at(ts.prog) - 7.0:
				ts.penalty += 5.0
				_reset_team(ts)
				show_message.rpc("Team %s FELL!  +5s" % char(65 + ts.idx))
			if ts.car.global_transform.basis.y.y < 0.25:
				ts.flip += delta
				if ts.flip > 2.0:
					_reset_team(ts)
			else:
				ts.flip = 0.0
		ts.car.set_controls(inp.x, inp.y, inp.z)
		ts.speed = ts.car.speed_kmh
	net_tick += 1
	if net_tick % 2 == 0:
		var arr := PackedFloat32Array()
		for ts in teams:
			var q := Quaternion(ts.car.global_basis.orthonormalized())
			var p := ts.car.global_position
			var flags := (1 if ts.wrong else 0) | (2 if ts.finished else 0)
			arr.append_array([p.x, p.y, p.z, q.x, q.y, q.z, q.w, ts.car.speed_kmh, ts.car.steer_target, float(ts.prog), float(flags), 0.0])
		net_state.rpc(arr, race_time)


func _update_progress(ts: TeamState) -> void:
	var p := ts.car.global_position
	var best := ts.prog
	var best_d := INF
	for i in range(maxi(0, ts.prog - 6), mini(track.points.size(), ts.prog + 40)):
		var q := track.points[i]
		var d := (p.x - q.x) * (p.x - q.x) + (p.z - q.z) * (p.z - q.z)
		if d < best_d:
			best_d = d
			best = i
	ts.prog = best
	ts.wrong = best_d > 13.0 * 13.0     # far from the real road = on a closed side road
	if best >= track.points.size() - 4 and not ts.finished:
		ts.finished = true
		ts.finish_time = race_time + ts.penalty
		results.append(ts.idx)
		team_finished.rpc(ts.idx, ts.finish_time, results.size())
		_check_all_done()


func _reset_team(ts: TeamState) -> void:
	var idx := maxi(3, ts.prog - 8)
	var t := Transform3D(Basis(Vector3.UP, track.headings[idx]), track.points[idx] + Vector3(0, 0.8, 0))
	ts.car.teleport(t)
	ts.flip = 0.0
	ts.wrong = false


func _server_reset(peer: int) -> void:
	if state != State.RUNNING:
		return
	var ts := teams[Net.team_of.get(peer, 0)]
	if ts.finished or ts.dnf:
		return
	_reset_team(ts)
	show_message.rpc("Team %s: back on the road" % char(65 + ts.idx))


# ====================================================================== local frame loop

func _process(delta: float) -> void:
	if state == State.COUNTDOWN:
		countdown_left -= delta
	if my_role == "driver":
		_read_driving_input()
	_update_look(delta)
	# smooth the other cars on clients
	if not multiplayer.is_server():
		for ts in teams:
			if ts.have_net:
				ts.car.global_transform = ts.car.global_transform.interpolate_with(ts.target, clampf(delta * 18.0, 0.0, 1.0))
	if beacon_node:
		beacon_timer -= delta
		if beacon_timer <= 0.0:
			beacon_node.queue_free()
			beacon_node = null
	if msg_timer > 0.0:
		msg_timer -= delta
		if msg_timer <= 0.0:
			msg_label.text = ""
	# hit feedback
	shake = move_toward(shake, 0.0, delta * 2.0)
	flash = move_toward(flash, 0.0, delta * 1.2)
	flash_rect.color.a = flash
	if local_avatar and local_avatar.cam:
		local_avatar.cam.h_offset = randf_range(-1.0, 1.0) * shake * 0.08
		local_avatar.cam.v_offset = randf_range(-1.0, 1.0) * shake * 0.08
	_update_hud()


func _zone_pressed(zone_name: String) -> bool:
	if not zones.has(zone_name):
		return false
	var r: Rect2 = zones[zone_name].get_global_rect()
	for pos in touches.values():
		if r.has_point(pos):
			return true
	return false


func _read_driving_input() -> void:
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
	var v := Vector3(clampf(steer, -1.0, 1.0), thr, brk)
	if multiplayer.is_server():
		teams[my_team].input = v
	elif state == State.RUNNING:
		send_input.rpc_id(1, v.x, v.y, v.z)


func _update_look(delta: float) -> void:
	if local_avatar == null:
		return
	var dragging := look_touch != -1 or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if local_avatar.cam:
		local_avatar.cam.fov = move_toward(local_avatar.cam.fov, 40.0 if map_mode else 82.0, delta * 160.0)
	if map_mode and not dragging:
		look_yaw = move_toward(look_yaw, 0.0, delta * 5.0)
		look_pitch = move_toward(look_pitch, -1.03, delta * 4.0)
		look_idle = 0.0
	elif Input.is_action_pressed("look_mate") and local_avatar.seat_dx != 0.0:
		var target_yaw := -signf(local_avatar.seat_dx) * 1.45
		look_yaw = move_toward(look_yaw, target_yaw, delta * 7.0)
		look_pitch = move_toward(look_pitch, 0.1, delta * 3.0)
		look_idle = 0.0
	elif dragging:
		look_idle = 0.0
	else:
		look_idle += delta
		if look_idle > 2.5:    # spring back to looking at the road
			look_yaw = move_toward(look_yaw, 0.0, delta * 3.0)
			look_pitch = move_toward(look_pitch, 0.0, delta * 3.0)
	local_avatar.set_look(look_yaw, look_pitch)
	var now := Time.get_ticks_msec()
	if now - look_send_ms > 70:
		look_send_ms = now
		if multiplayer.is_server():
			look_sync.rpc(my_id, look_yaw, look_pitch)
		else:
			send_look.rpc_id(1, look_yaw, look_pitch)


func _look_delta(rel: Vector2) -> void:
	look_yaw = clampf(look_yaw - rel.x * 0.006, -2.6, 2.6)
	look_pitch = clampf(look_pitch - rel.y * 0.006, -1.2, 0.75)
	look_idle = 0.0
	map_mode = false


# ====================================================================== player actions

func _request_reset() -> void:
	if multiplayer.is_server():
		_server_reset(my_id)
	else:
		request_reset.rpc_id(1)


func _do_punch() -> void:
	look_idle = 0.0
	if multiplayer.is_server():
		_server_punch(my_id)
	else:
		request_punch.rpc_id(1)


func _set_gesture(g: int) -> void:
	if my_role != "navigator" and not solo:
		return
	var ng := 0 if my_gesture == g else g    # tapping the same gesture again returns the hand to rest
	if multiplayer.is_server():
		_server_gesture(my_id, ng)
	else:
		request_gesture.rpc_id(1, ng)


func _do_beacon() -> void:
	if my_role != "navigator" and not solo:
		return
	if multiplayer.is_server():
		_server_beacon(my_id)
	else:
		request_beacon.rpc_id(1)


func _toggle_map() -> void:
	if ipad_vp:
		map_mode = not map_mode
	elif clipboard:
		clipboard.visible = not clipboard.visible


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_press(event.index, event.position)
		else:
			touches.erase(event.index)
			zone_touch.erase(event.index)
			if event.index == look_touch:
				look_touch = -1
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
		if event.index == look_touch:
			_look_delta(event.relative)
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_look_delta(event.relative)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not DisplayServer.is_touchscreen_available():
			_click_zone(event.position)
	if event.is_action_pressed("reset"):
		_request_reset()
	elif event.is_action_pressed("punch"):
		_do_punch()
	elif event.is_action_pressed("g_left"):
		_set_gesture(1)
	elif event.is_action_pressed("g_fwd"):
		_set_gesture(2)
	elif event.is_action_pressed("g_right"):
		_set_gesture(3)
	elif event.is_action_pressed("g_stop"):
		_set_gesture(4)
	elif event.is_action_pressed("beacon"):
		_do_beacon()
	elif event.is_action_pressed("map_toggle"):
		_toggle_map()


func _touch_press(index: int, pos: Vector2) -> void:
	touches[index] = pos
	for zn in zones:
		if (zones[zn] as Control).get_global_rect().has_point(pos):
			zone_touch[index] = zn
			if tap_zones.has(zn):
				(tap_zones[zn] as Callable).call()
			return
	if look_touch == -1:
		look_touch = index   # a touch outside every button = look around


func _click_zone(pos: Vector2) -> void:
	for zn in zones:
		if (zones[zn] as Control).get_global_rect().has_point(pos) and tap_zones.has(zn):
			(tap_zones[zn] as Callable).call()
			return


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
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	if blind_mode:
		# nearly blind driver: black world, dim grey road, headlights only
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color.BLACK
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.5, 0.52, 0.6)
		env.ambient_light_energy = 0.22
		env.fog_enabled = true
		env.fog_light_color = Color.BLACK
		env.fog_density = 0.011
		sun.light_energy = 0.12
	else:
		env.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		var sm := ProceduralSkyMaterial.new()
		sm.sky_top_color = th["top"]
		sm.sky_horizon_color = th["hor"]
		sm.ground_horizon_color = th["hor"]
		sm.ground_bottom_color = th["hor"]
		sky.sky_material = sm
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.9
		env.fog_enabled = true
		env.fog_light_color = th["hor"]
		env.fog_density = th["fog"]
		sun.light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	add_child(sun)


func _add_road(pts: PackedVector3Array, avoid: PackedVector3Array, road: Array[Transform3D], dashes: Array[Transform3D], bank_vis: Array[Transform3D], banks: StaticBody3D, main := false) -> void:
	var W := Track.ROAD_WIDTH
	var avoid_d2 := pow(W * 0.5 + 2.6, 2.0)
	var mountain := track.theme == "mountain"
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var d := b - a
		var yaw := atan2(-d.x, -d.z)
		var pitch := atan2(d.y, Vector2(d.x, d.z).length())
		var flat := Basis(Vector3.UP, yaw)
		var basis := flat * Basis(Vector3.RIGHT, pitch)
		var mid := (a + b) * 0.5
		var left := flat * Vector3(-1, 0, 0)
		var seg := d.length()
		var open := main and track.is_open(i)
		road.append(Transform3D(basis * Basis.from_scale(Vector3(W, 0.2, seg * 1.12)), mid + Vector3(0, -0.07, 0)))
		if i % 2 == 0:
			dashes.append(Transform3D(basis * Basis.from_scale(Vector3(0.3, 0.02, 2.2)), mid + basis.y * 0.04))
		if mountain:
			var rc := CollisionShape3D.new()
			var rs := BoxShape3D.new()
			rs.size = Vector3(W + 1.0, 1.0, seg * 1.3)
			rc.shape = rs
			rc.transform = Transform3D(basis, mid + basis.y * (0.03 - 0.5))
			_road_body.add_child(rc)
			var ph := mid.y - track.floor_y - 0.4
			var pw := W if open else W + 12.0
			_pillars.append(Transform3D(flat * Basis.from_scale(Vector3(pw, ph, seg * 1.06)), Vector3(mid.x, track.floor_y + ph * 0.5, mid.z)))
		if open:
			continue
		for side in [-1.0, 1.0]:
			var pos: Vector3 = mid + left * side * (W * 0.5 + 1.5) + Vector3(0, 0.7, 0)
			var skip := false
			for q in avoid:
				var dx: float = q.x - pos.x
				var dz: float = q.z - pos.z
				if dx * dx + dz * dz < avoid_d2:
					skip = true
					break
			if skip:
				continue
			bank_vis.append(Transform3D(flat * Basis.from_scale(Vector3(3.0, 1.4, Track.STEP * 1.2)), pos))
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(3.0, 1.4, Track.STEP * 1.2)
			cs.shape = bs
			cs.transform = Transform3D(flat, pos)
			banks.add_child(cs)


func _build_track() -> void:
	var ground := StaticBody3D.new()
	var gs := CollisionShape3D.new()
	var gb := BoxShape3D.new()
	gb.size = Vector3(8000, 2, 8000)
	gs.shape = gb
	gs.position = Vector3(0, track.floor_y - 1.0, 0)
	ground.add_child(gs)
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8000, 8000)
	gm.mesh = pm
	gm.material_override = _mat(th["ground"])
	gm.position.y = track.floor_y
	ground.add_child(gm)
	add_child(ground)

	var banks := StaticBody3D.new()
	add_child(banks)
	_road_body = StaticBody3D.new()
	add_child(_road_body)
	var road: Array[Transform3D] = []
	var dashes: Array[Transform3D] = []
	var bank_vis: Array[Transform3D] = []
	var avoid_main := PackedVector3Array()
	for b in track.branches:
		var bp: PackedVector3Array = b["points"]
		for k in 14:
			avoid_main.append(bp[k])
	_add_road(track.points, avoid_main, road, dashes, bank_vis, banks, true)
	for b in track.branches:
		var f: int = b["fork"]
		var avoid_branch := PackedVector3Array()
		for j in range(maxi(0, f - 8), mini(track.points.size(), f + 16)):
			avoid_branch.append(track.points[j])
		_add_road(b["points"], avoid_branch, road, dashes, bank_vis, banks)
		_build_dead_end(b)
	_multimesh(_unit_box(), _mat(th["road"]), road)
	_multimesh(_unit_box(), _mat(Color(0.95, 0.95, 0.95)), dashes)
	_multimesh(_unit_box(), _mat(th["bank"]), bank_vis)
	_multimesh(_unit_box(), _mat(th.get("pillar", Color(0.4, 0.4, 0.4))), _pillars)
	var ice_x: Array[Transform3D] = []
	for e in track.ices:
		for i in range(int(e["from"]), int(e["to"])):
			var d := track.points[i + 1] - track.points[i]
			var yaw := atan2(-d.x, -d.z)
			var pitch := atan2(d.y, Vector2(d.x, d.z).length())
			var bs := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
			ice_x.append(Transform3D(bs * Basis.from_scale(Vector3(Track.ROAD_WIDTH, 0.05, Track.STEP * 1.05)), (track.points[i] + track.points[i + 1]) * 0.5 + bs.y * 0.06))
	var ice_mat := _mat(Color(0.7, 0.88, 1.0))
	ice_mat.roughness = 0.1
	_multimesh(_unit_box(), ice_mat, ice_x)

	_build_gate(6, Color(0.2, 0.8, 0.3), "START")
	_build_gate(track.points.size() - 4, Color(0.95, 0.95, 0.95), "FINISH")
	_build_trees()
	_build_mountains()


func _build_dead_end(b: Dictionary) -> void:
	var pts: PackedVector3Array = b["points"]
	var hs: PackedFloat32Array = b["headings"]
	var e := pts[pts.size() - 1]
	var h := hs[hs.size() - 1]
	var basis := Basis(Vector3.UP, h)
	var width := Track.ROAD_WIDTH + 4.0
	var body := StaticBody3D.new()
	body.transform = Transform3D(basis, e + Vector3(0, 0.8, 0))
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(width, 1.6, 0.8)
	cs.shape = bs
	body.add_child(cs)
	add_child(body)
	var n := 6
	for i in n:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(width / n, 1.6, 0.8)
		mi.mesh = bm
		mi.material_override = _mat(Color(0.9, 0.15, 0.15) if i % 2 == 0 else Color(0.95, 0.95, 0.95))
		mi.position = Vector3(-width * 0.5 + width / n * (i + 0.5), 0, 0)
		body.add_child(mi)
	var sign_label := Label3D.new()
	sign_label.text = "ROAD CLOSED"
	sign_label.font_size = 96
	sign_label.pixel_size = 0.012
	sign_label.modulate = Color(1, 0.25, 0.2)
	sign_label.outline_modulate = Color.BLACK
	sign_label.position = Vector3(0, 2.4, 0)
	body.add_child(sign_label)


func _build_gate(idx: int, c: Color, text: String) -> void:
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
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = 90
	lab.pixel_size = 0.01
	lab.modulate = Color.BLACK
	lab.position = Vector3(0, 0, 0.3)
	beam.add_child(lab)


func _obst_box(body: StaticBody3D, size: Vector3, xf: Transform3D, c: Color, solid := true) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.transform = xf
	body.add_child(mi)
	if solid:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.transform = xf
		body.add_child(cs)


func _build_obstacles() -> void:
	var body := StaticBody3D.new()
	add_child(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = Net.track_seed + 7
	for o in track.obstacles:
		var i: int = o["index"]
		var p := track.points[i]
		var h := track.headings[i]
		var left := Track.left_of(h)
		var side: float = o["side"]
		match o["kind"]:
			"rock":
				var lat := side * rng.randf_range(1.2, 3.2)
				var basis := Basis(Vector3.UP, rng.randf() * TAU)
				var pos := p + left * lat + Vector3(0, 0.75, 0)
				_obst_box(body, Vector3(2.4, 1.5, 2.2), Transform3D(basis, pos), Color(0.45, 0.47, 0.52))
				_obst_box(body, Vector3(1.3, 0.9, 1.3), Transform3D(basis, pos + Vector3(0.2, 1.1, 0.1)), Color(0.55, 0.57, 0.62), false)
			"log":
				var pos := p + left * side * 2.5 + Vector3(0, 0.45, 0)
				_obst_box(body, Vector3(6.4, 0.9, 1.0), Transform3D(Basis(Vector3.UP, h), pos), Color(0.4, 0.26, 0.13))
			"rockfall":
				for k in 7:
					var lat := side * rng.randf_range(-1.0, 4.6)
					var sz := rng.randf_range(1.6, 3.0)
					var basis := Basis(Vector3.UP, rng.randf() * TAU)
					var pos := p + left * lat + Track.forward(h) * rng.randf_range(-4.0, 4.0) + Vector3(0, sz * 0.45, 0)
					_obst_box(body, Vector3(sz, sz * 0.9, sz * 0.9), Transform3D(basis, pos), Color(0.36, 0.36, 0.4))
			"bump":
				var basis := Basis(Vector3.UP, h) * Basis(Vector3.RIGHT, deg_to_rad(7.5))
				_obst_box(body, Vector3(10.6, 0.6, 6.5), Transform3D(basis, p), Color(0.82, 0.86, 0.9))


func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Net.track_seed
	var trunks: Array[Transform3D] = []
	var leaves1: Array[Transform3D] = []
	var leaves2: Array[Transform3D] = []
	var avoid := PackedVector3Array(track.points)
	for b in track.branches:
		avoid.append_array(b["points"])
	var n := track.points.size()
	var mountain := track.theme == "mountain"
	var min_d2 := pow(Track.ROAD_WIDTH * 0.5 + (3.4 if mountain else 6.0), 2.0)
	for i in range(4, n - 2, 2):
		if mountain and track.is_open(i):
			continue
		for side in [-1.0, 1.0]:
			if rng.randf() > (0.55 if mountain else 0.8):
				continue
			var left := Track.left_of(track.headings[i])
			var off := Track.ROAD_WIDTH * 0.5 + 6.0 + rng.randf_range(0.0, 30.0)
			if mountain:
				off = Track.ROAD_WIDTH * 0.5 + 3.9 + rng.randf_range(0.0, 1.3)
			var pos: Vector3 = track.points[i] + left * side * off + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
			var ok := true
			for q in avoid:
				var dx: float = q.x - pos.x
				var dz: float = q.z - pos.z
				if dx * dx + dz * dz < min_d2:
					ok = false
					break
			if not ok:
				continue
			var s := rng.randf_range(0.8, 1.7)
			pos.y = track.points[i].y
			var b := Basis(Vector3.UP, rng.randf() * TAU)
			trunks.append(Transform3D(b * Basis.from_scale(Vector3(0.5, 2.0 * s, 0.5)), pos + Vector3(0, s, 0)))
			leaves1.append(Transform3D(b * Basis.from_scale(Vector3(3.2 * s, 2.0 * s, 3.2 * s)), pos + Vector3(0, 2.8 * s, 0)))
			leaves2.append(Transform3D(b * Basis.from_scale(Vector3(2.0 * s, 1.8 * s, 2.0 * s)), pos + Vector3(0, 4.5 * s, 0)))
	_multimesh(_unit_box(), _mat(th["trunk"]), trunks)
	_multimesh(_unit_box(), _mat(th["l1"]), leaves1)
	_multimesh(_unit_box(), _mat(th["l2"]), leaves2)


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
		xs.append(Transform3D(b * Basis.from_scale(Vector3(w, h, w)), Vector3(mid.x + cos(a) * dist, track.floor_y + h * 0.4, mid.z + sin(a) * dist)))
	_multimesh(_unit_box(), _mat(th["mount"]), xs)


func _spawn_beacon(idx: int) -> void:
	if beacon_node:
		beacon_node.queue_free()
	var n := Node3D.new()
	n.position = track.points[idx]
	n.rotation.y = track.headings[idx]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 1.0, 0.5, 0.85)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var parts := [
		[Vector3(0.5, 18.0, 0.5), Vector3(0, 9.0, 0), 0.0],            # light pillar
		[Vector3(1.3, 0.12, 6.0), Vector3(0, 0.14, 0), 0.0],           # arrow stem
		[Vector3(3.6, 0.12, 1.1), Vector3(-1.45, 0.14, -3.3), 38.0],   # arrow head
		[Vector3(3.6, 0.12, 1.1), Vector3(1.45, 0.14, -3.3), -38.0],
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[0]
		mi.mesh = bm
		mi.material_override = m
		mi.position = p[1]
		mi.rotation_degrees.y = p[2]
		n.add_child(mi)
	add_child(n)
	beacon_node = n
	beacon_timer = 7.0


# ====================================================================== cars + players

func _grid_transform(t: int) -> Transform3D:
	var i := 3
	var count := Net.team_count
	var lat := (t - (count - 1) * 0.5) * 3.0
	var back := float(t % 2) * 4.0
	var left := Track.left_of(track.headings[i])
	var fwd := Track.forward(track.headings[i])
	var pos := track.points[i] + left * lat - fwd * back + Vector3(0, 0.8, 0)
	return Transform3D(Basis(Vector3.UP, track.headings[i]), pos)


func _build_teams() -> void:
	for t in Net.team_count:
		var ts := TeamState.new()
		ts.idx = t
		ts.color = TEAM_COLORS[t]
		for id in Net.roles:
			if Net.team_of.get(id, -1) == t:
				if Net.roles[id] == "driver":
					ts.driver_id = id
				else:
					ts.nav_id = id
		var car := Car.new()
		car.name = "Car%d" % t
		car.setup(t, ts.color, not multiplayer.is_server())
		car.transform = _grid_transform(t)
		add_child(car)
		if Net.blind and not solo:
			car.add_lights()
		ts.car = car
		ts.target = car.transform
		teams.append(ts)
		for id in [ts.driver_id, ts.nav_id]:
			if id != 0:
				_make_avatar(ts, id)


func _make_avatar(ts: TeamState, id: int) -> void:
	var role: String = Net.roles[id]
	var av := Avatar.new()
	av.name = "Avatar%d" % id
	av.peer_id = id
	av.role = role
	av.helmet_color = ts.color
	av.shirt_color = ts.color.darkened(0.2)
	av.is_local = (id == my_id)
	if av.is_local and ipad_vp:
		av.ipad_tex = ipad_vp.get_texture()
	av.position = ts.car.seat_origin(role)
	var mate := ts.nav_id if role == "driver" else ts.driver_id
	if mate != 0:
		av.seat_dx = ts.car.seat_origin(Net.roles[mate]).x - av.position.x
	ts.car.add_child(av)
	avatars[id] = av
	if role == "driver":
		ts.car.driver_avatar = av
	if av.is_local:
		local_avatar = av


# ====================================================================== HUD

func _style_label(l: Label, fs: int) -> void:
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _full_label(top: float, height: float, fs: int, anchor_y := 0.0) -> Label:
	var l := Label.new()
	l.anchor_right = 1.0
	l.anchor_top = anchor_y
	l.anchor_bottom = anchor_y
	l.offset_top = top
	l.offset_bottom = top + height
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(l, fs)
	hud_root.add_child(l)
	return l


func _make_zone(zone_name: String, text: String, ax: float, ay: float, o_l: float, o_t: float, o_r: float, o_b: float, fs := 24, tap := Callable()) -> void:
	var p := Panel.new()
	p.anchor_left = ax
	p.anchor_right = ax
	p.anchor_top = ay
	p.anchor_bottom = ay
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
	_style_label(l, fs)
	p.add_child(l)
	hud_root.add_child(p)
	zones[zone_name] = p
	if tap.is_valid():
		tap_zones[zone_name] = tap


func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	hud_root = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hud_root)
	flash_rect = ColorRect.new()
	flash_rect.color = Color(0.9, 0.1, 0.1, 0.0)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(flash_rect)

	timer_label = _full_label(8, 56, 46)
	medal_label = _full_label(62, 34, 24)
	gesture_label = _full_label(100, 50, 34)
	center_label = _full_label(0, 160, 120, 0.2)
	msg_label = _full_label(0, 50, 28, 0.42)
	alert_label = _full_label(0, 60, 32, 0.55)
	alert_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	role_label = Label.new()
	role_label.position = Vector2(14, 8)
	var tname := "TEAM %s  -  " % char(65 + my_team) if Net.team_count > 1 else ""
	role_label.text = tname + ("DRIVER" if my_role == "driver" else "CO-DRIVER")
	_style_label(role_label, 22)
	hud_root.add_child(role_label)
	speed_label = Label.new()
	speed_label.position = Vector2(14, 36)
	_style_label(speed_label, 22)
	hud_root.add_child(speed_label)
	rank_label = Label.new()
	rank_label.position = Vector2(14, 66)
	_style_label(rank_label, 20)
	hud_root.add_child(rank_label)

	_make_zone("reset", "RESET (R)", 1.0, 0.0, -150, 14, -14, 64, 22, _request_reset)
	_make_zone("punch", "PUNCH\n(F)", 1.0, 0.5, -140, -45, -14, 45, 22, _do_punch)
	if show_touch:
		_make_zone("left", "<", 0.0, 1.0, 20, -170, 160, -40, 40)
		_make_zone("right", ">", 0.0, 1.0, 180, -170, 320, -40, 40)
		_make_zone("gas", "GAS", 1.0, 1.0, -170, -190, -20, -40)
		_make_zone("brake", "BRAKE", 1.0, 1.0, -340, -170, -190, -40)
	if my_role == "navigator" or solo:
		var by := -130.0 - (140.0 if show_touch else 0.0)
		_make_zone("g_left", "< LEFT\n(1)", 0.0, 1.0, 20, by, 120, by + 90, 18, _set_gesture.bind(1))
		_make_zone("g_fwd", "^ GO\n(2)", 0.0, 1.0, 130, by, 230, by + 90, 18, _set_gesture.bind(2))
		_make_zone("g_right", "RIGHT >\n(3)", 0.0, 1.0, 240, by, 340, by + 90, 18, _set_gesture.bind(3))
		_make_zone("g_stop", "STOP!\n(4)", 0.0, 1.0, 350, by, 450, by + 90, 18, _set_gesture.bind(4))
		_make_zone("beacon", "SIGNAL\n(G)", 1.0, 1.0, -330, by, -180, by + 90, 20, _do_beacon)
		_make_zone("map", "MAP\n(M)", 1.0, 1.0, -170, by, -20, by + 90, 20, _toggle_map)
		if ipad_vp == null:
			clipboard = Clipboard.new()
			clipboard.mouse_filter = Control.MOUSE_FILTER_IGNORE
			clipboard.my_color = teams[my_team].color
			clipboard.set_track(track)
			hud_root.add_child(clipboard)


func _update_layout() -> void:
	if clipboard == null or ipad_vp != null:
		return
	var vs := get_viewport().get_visible_rect().size
	if vs.y > vs.x:
		var w := vs.x * 0.9
		var h := vs.y * 0.4
		clipboard.position = Vector2((vs.x - w) * 0.5, 150.0)
		clipboard.size = Vector2(w, h)
	else:
		var h := vs.y * (0.5 if show_touch else 0.62)
		var w := minf(vs.x * 0.34, h * 0.8)
		clipboard.position = Vector2(vs.x - w - 20.0, 76.0)
		clipboard.size = Vector2(w, h)
	clipboard.queue_redraw()


## The co-driver's map lives on an iPad in the lap: only visible by looking down at it.
func _build_ipad() -> void:
	ipad_vp = SubViewport.new()
	ipad_vp.size = Vector2i(640, 440)
	ipad_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	ipad_vp.gui_disable_input = true
	add_child(ipad_vp)
	clipboard = Clipboard.new()
	clipboard.tablet = true
	clipboard.my_color = TEAM_COLORS[my_team]
	clipboard.position = Vector2.ZERO
	clipboard.size = Vector2(640, 440)
	ipad_vp.add_child(clipboard)
	clipboard.set_track(track)


func _fmt(t: float) -> String:
	return "%d:%04.1f" % [int(t / 60.0), fmod(t, 60.0)]


func _ahead(a: TeamState, b: TeamState) -> bool:
	if a.finished and b.finished:
		return a.finish_time < b.finish_time
	if a.finished != b.finished:
		return a.finished
	if a.dnf != b.dnf:
		return b.dnf
	return a.prog > b.prog


func _update_hud() -> void:
	var my := teams[my_team]
	var shown_time := my.finish_time if my.finished else maxf(race_time, 0.0)
	timer_label.text = _fmt(shown_time)
	var spd := my.car.speed_kmh if multiplayer.is_server() else my.speed
	speed_label.text = "%d km/h" % int(spd)
	var shown := false
	for m in MEDALS:
		if shown_time <= m[1]:
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
			msg_label.text = "STAGE: %s  (%s)" % [track.stage_name.to_upper(), track.theme.to_upper()]
			msg_timer = 0.1
		State.RUNNING:
			center_label.text = "GO!" if race_time < 1.0 else ""
		State.ENDED:
			center_label.text = ""
	# standings
	if teams.size() > 1:
		var sorted := teams.duplicate()
		sorted.sort_custom(_ahead)
		var lines: Array[String] = []
		for i in sorted.size():
			var ts: TeamState = sorted[i]
			var tag: String = PLACES[i] + "  Team " + char(65 + ts.idx)
			if ts.dnf:
				tag += "  (out)"
			elif ts.finished:
				tag += "  " + _fmt(ts.finish_time)
			lines.append(("> " if ts.idx == my_team else "   ") + tag)
		rank_label.text = "\n".join(lines)
	# what the co-driver is signalling (the driver must notice it!)
	var g := my_gesture if solo else mate_gesture
	if (my_role == "driver" or solo) and g > 0 and not blind_mode:
		gesture_label.text = GESTURE_TEXT[g]
		var blink := g != 4 or int(Time.get_ticks_msec() / 200.0) % 2 == 0
		gesture_label.add_theme_color_override("font_color", Color(1, 0.3, 0.25) if g == 4 else Color(1, 0.9, 0.3))
		gesture_label.visible = blink
	else:
		gesture_label.visible = false
	# alerts about the closed side roads
	alert_label.text = ""
	if state == State.RUNNING and my.wrong and not my.finished:
		if my_role == "driver" and spd < 4.0 and not blind_mode:
			alert_label.text = "DEAD END!  Reverse (S) or press RESET"
		elif my_role == "navigator":
			alert_label.text = "THE DRIVER IS ON A CLOSED ROAD!"
	if clipboard:
		var others: Array = []
		for ts in teams:
			if ts.idx != my_team:
				others.append({"idx": ts.prog, "color": ts.color})
		clipboard.set_state(my.prog, my.wrong, others)


func _standings_text() -> String:
	var lines: Array[String] = []
	for i in results.size():
		var ts := teams[results[i]]
		lines.append("%s   Team %s   %s" % [PLACES[i], char(65 + ts.idx), _fmt(ts.finish_time)])
	for ts in teams:
		if not ts.finished:
			lines.append("-      Team %s   %s" % [char(65 + ts.idx), "out" if ts.dnf else "racing..."])
	return "\n".join(lines)


func _refresh_result() -> void:
	if result_standings:
		result_standings.text = _standings_text()


func _show_result(place: int, t: float) -> void:
	var medal := "No medal"
	for m in MEDALS:
		if t <= m[1]:
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
	title.text = "FINISH!  %s" % (PLACES[place - 1] if Net.team_count > 1 else "")
	title.add_theme_font_size_override("font_size", 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var res := Label.new()
	res.text = "Time  %s\nMedal  %s" % [_fmt(t), medal]
	res.add_theme_font_size_override("font_size", 32)
	res.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(res)
	if Net.team_count > 1:
		result_standings = Label.new()
		result_standings.add_theme_font_size_override("font_size", 24)
		result_standings.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(result_standings)
		_refresh_result()
	var btn := Button.new()
	btn.text = "Back to menu"
	btn.custom_minimum_size = Vector2(320, 70)
	btn.add_theme_font_size_override("font_size", 28)
	btn.pressed.connect(Net.return_to_menu)
	vb.add_child(btn)
	hud_root.add_child(result_panel)
