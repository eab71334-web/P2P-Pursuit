# Copyright (c) 2026 KRG Studios. All rights reserved. See LICENSE.
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
const TEAM_COLORS := [Color(0.82, 0.1, 0.1), Color(0.15, 0.4, 0.95), Color(0.15, 0.7, 0.3), Color(0.95, 0.72, 0.1), Color(0.65, 0.25, 0.85), Color(0.1, 0.75, 0.8)]


const THEMES := {
	"snow": {"top": Color(0.42, 0.58, 0.85), "hor": Color(0.8, 0.86, 0.93), "fog": 0.0035, "ground": Color(0.88, 0.92, 0.97),
		"bank": Color(0.97, 0.98, 1.0), "road": Color(0.2, 0.21, 0.25), "trunk": Color(0.35, 0.22, 0.12),
		"l1": Color(0.14, 0.4, 0.2), "l2": Color(0.2, 0.5, 0.28), "mount": Color(0.8, 0.85, 0.93)},
	"autumn": {"top": Color(0.5, 0.62, 0.8), "hor": Color(0.95, 0.85, 0.7), "fog": 0.004, "ground": Color(0.5, 0.36, 0.18),
		"bank": Color(0.55, 0.42, 0.25), "road": Color(0.3, 0.26, 0.22), "trunk": Color(0.3, 0.18, 0.1),
		"l1": Color(0.85, 0.4, 0.1), "l2": Color(0.9, 0.62, 0.15), "mount": Color(0.6, 0.45, 0.35)},
	"desert": {"top": Color(0.28, 0.5, 0.86), "hor": Color(0.98, 0.88, 0.7), "fog": 0.0032, "ground": Color(0.86, 0.7, 0.42),
		"bank": Color(0.8, 0.62, 0.38), "road": Color(0.28, 0.27, 0.27), "trunk": Color(0.35, 0.25, 0.14),
		"l1": Color(0.45, 0.5, 0.25), "l2": Color(0.55, 0.58, 0.3), "mount": Color(0.78, 0.55, 0.34), "tree_p": 0.18},
	"beach": {"top": Color(0.15, 0.55, 0.9), "hor": Color(0.8, 0.93, 0.98), "fog": 0.0026, "ground": Color(0.95, 0.88, 0.68),
		"bank": Color(0.9, 0.82, 0.62), "road": Color(0.3, 0.3, 0.32), "trunk": Color(0.5, 0.36, 0.2),
		"l1": Color(0.1, 0.55, 0.25), "l2": Color(0.2, 0.68, 0.32), "mount": Color(0.35, 0.6, 0.5), "tree_p": 0.5},
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
	var damage := 0.0
	var fire := 0.0
	var inner := 0.0
	var phase := 0          # 0 driving, 1 hood released, 2 repairer outside, 3 hood up
	var cover := false
	var repairer := 0
	var spraying := false
	var aimed := false
	var burn_t := 0.0
	var last_imp := 0
	var spray_sent := false
	var warned := 0
	var boom_t := 0.0
	var alarm_i := -1
	var bot := false          # driven by the server (solo races with opponents)
	var bot_skill := 0.85
	var bot_name := ""
	var bot_lo := {}
	var stuck := 0.0
	var wob_t := 0.0          # bots: short steering mistakes
	var wob := 0.0
	var wob_wait := 4.0
	var resets := 0


var track: Track
var th: Dictionary
var weather := "clear"
var _rain: CPUParticles3D
var _wx_env: Environment
var _bolt_wait := 6.0
var _bolt: ColorRect
var _obst_at := {}
var blind_mode := false
var tutorial_done := false
var repair_label: Label
var lift_swipe := 0.0
var spray_ms := 0
var spray_last := false
var spray_aim_last := false
var last_count := 99
var fast_done := false
var rematch_btn: Button
var room_btn: Button
const OUT_POS := Vector3(-0.2, 1.0, -2.85)
var ipad_vp: SubViewport
var map_mode := false
var map_screen: MapScreen
var _pillars: Array[Transform3D] = []
var _edge_lines: Array[Transform3D] = []      # solid white lines along both road edges
var _patches: Array[Transform3D] = []         # darker repaired-tarmac patches
var _kerb_a: Array[Transform3D] = []          # red / white kerb stripes on top of the barriers
var _kerb_b: Array[Transform3D] = []
var _lamp_poles: Array[Transform3D] = []
var _lamp_heads: Array[Transform3D] = []
var _sun_node: Sprite3D
var _wave_flags: Array[MeshInstance3D] = []
var _birds: Array[Node3D] = []
var _sun_ref: DirectionalLight3D
var _cloud_root: Node3D
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
var final_order: Array = []        # all teams: finishers first, then the rest by progress
var final_pcts: Array = []
var grace_left := -1.0             # server: seconds until the race is closed after the first finisher
var grace_show := -1.0             # clients: the same countdown, for the HUD
var grace_label: Label
var skip_wait_btn: Button
var ceremony: Ceremony
var _rewarded := false
var my_coins := 0                    # coins of this race (the "double" ad button doubles them)
var my_reward_line := ""
const PTS := [12, 9, 7, 5, 4, 3, 2, 1]     # team race: points per place
var net_tick := 0
var last_punch := {}
var look_yaw := 0.0
var look_pitch := 0.0
var look_idle := 0.0
var look_touch := -1
var steer_mode := "buttons"
var wheel_ui: SteerUI.Wheel
var wheel_angle := 0.0
var wheel_touch := -1
var wheel_last := 0.0
var _picker: Control
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
var _map_tick := 0.0
var msg_timer := 0.0

var hud: CanvasLayer
var hud_root: Control
var timer_label: Label
var medal_label: Label
var speed_label: Label
var _fov_kick := 0.0
var _drive_shake := 0.0          # light camera shake when braking hard / at very high speed
var hint_layer: Control
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
	my_role = "" if Net.dedicated else Net.roles.get(my_id, "driver")
	my_team = Net.team_of.get(my_id, 0)
	solo = (Net.players.size() == 1 or Net.ffa) and not Net.dedicated
	show_touch = (DisplayServer.is_touchscreen_available() or OS.get_environment("FORCE_TOUCH") != "") and my_role == "driver" and Controls.touch_wanted()
	if Net.stage.is_empty():
		Net.stage = {"seed": Net.track_seed}
	track = Track.from_stage(Net.stage)
	th = THEMES[track.theme]
	weather = str(Net.stage.get("weather", "clear"))
	blind_mode = Net.blind and my_role == "driver" and not solo
	if my_role == "navigator" or solo:
		_build_ipad()
	_build_environment()
	_build_track()
	_build_obstacles()
	for o in track.obstacles:
		_obst_at[int(o["index"])] = o
	_build_teams()
	_build_hud()
	_build_weather_fx()
	if not Net.dedicated:
		director = ReplayDirector.new()
		add_child(director)
	Net.peer_left.connect(_on_peer_left)
	if not Net.dedicated:
		Radio.start_race()
	Backend.crumb("race start car=%s role=%s solo=%s server=%s" % [str(Profile.car), my_role, str(solo), str(multiplayer.is_server())])
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()
	if show_touch and Profile.steer_mode == "":
		_picker = SteerUI.Picker.new()
		hud_root.add_child(_picker)
		_picker.z_index = 120
		(_picker as SteerUI.Picker).picked.connect(func(m: String):
			Profile.steer_mode = m
			Profile.save()
			_picker.queue_free()
			_picker = null
			_apply_steer_mode()
			_flip_hud()
			HudLayout.apply_world(zones)
			_after_steer())
	else:
		_after_steer()


func _after_steer() -> void:
	if my_role == "driver" and not Net.dedicated and not HudLayout.is_intro_seen():
		HudEditor.intro(hud_root, _after_steer2)      # first time: tell the player the buttons can be customised
	else:
		_after_steer2()


func _after_steer2() -> void:
	if Net.dedicated:        # nobody plays at the server: wait for the clients' READY only
		tutorial_done = true
		_check_all_ready()
		return
	if L.tutorial_off:
		_im_ready()
	else:
		var tut := Tutorial.new()
		tut.pages = Tutorial.pages_for(my_role, solo, Net.ffa)
		tut.finished.connect(_im_ready)
		hud_root.add_child(tut)
		tut.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tut.z_index = 100


func _im_ready() -> void:
	tutorial_done = true
	if multiplayer.is_server():
		ready_peers[1] = true
		_check_all_ready()
	else:
		_send_ready()


func _tname(idx: int) -> String:
	if teams[idx].bot:
		return teams[idx].bot_name
	if not Net.bots.is_empty():
		return str(Net.players.get(teams[idx].driver_id, Profile.pname))
	if Net.ffa:
		var ts := teams[idx]
		return str(Net.players.get(ts.driver_id, "?"))
	return "%s %s" % [L.t("team"), char(65 + idx)]


func _place(i: int) -> String:
	return L.t("place%d" % (i + 1))


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
	Gfx.racing = true
	Score.start()
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
	flash_message(L.t("is_out") % _tname(team))
	_refresh_result()


@rpc("authority", "call_local", "reliable")
func all_done(order: Array, pcts: Array) -> void:
	Gfx.racing = false
	Score.stop()
	state = State.ENDED
	Net.race_over = true
	final_order = order
	final_pcts = pcts
	grace_show = -1.0
	if Net.dedicated:        # server: no ceremony, give the clients time, then reopen the room
		get_tree().create_timer(12.0).timeout.connect(Net.server_idle)
		return
	flash_message(UI.tx("RACE OVER!", "انتهى السباق!"))
	# players who did not cross the line still get paid for their place
	var my := teams[my_team]
	if not my.finished and not _rewarded:
		var place := order.find(my_team) + 1
		var rw := Profile.race_reward(place, Net.team_count, -1, track.theme == "mountain")
		_career_apply(place, rw)
		_rewarded = true
		my_reward_line = _reward_line(rw)
		my_coins = int(rw["coins"])
	if rematch_btn:
		rematch_btn.text = UI.tx("Rematch", "إعادة المباراة") if Net.required_players > 1 else UI.tx("Race again", "سباق جديد")
	_update_result_buttons()
	get_tree().create_timer(2.6).timeout.connect(_start_ceremony)


@rpc("authority", "call_local", "reliable")
func show_message(key: String, idx: int) -> void:
	flash_message(L.t(key) % _tname(idx))


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
	if arr.size() != teams.size() * 15:
		return
	for i in teams.size():
		var b := i * 15
		var ts := teams[i]
		ts.target = Transform3D(Basis(Quaternion(arr[b + 3], arr[b + 4], arr[b + 5], arr[b + 6])), Vector3(arr[b], arr[b + 1], arr[b + 2]))
		ts.speed = arr[b + 7]
		ts.car.steer_visual = arr[b + 8]
		ts.prog = int(arr[b + 9])
		var flags := int(arr[b + 10])
		ts.car.speed_kmh = ts.speed
		ts.damage = arr[b + 12]
		ts.fire = arr[b + 13]
		ts.inner = arr[b + 14]
		ts.car.apply_state(ts.damage, ts.fire, ts.inner, flags, arr[b + 11])
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
		if Gfx.haptics:
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
		show_message.rpc("codriver_left", team)


func _check_all_done() -> void:
	if state == State.ENDED or not multiplayer.is_server():
		return
	var open := 0
	for ts in teams:
		if not ts.finished and not ts.dnf:
			open += 1
	# the race is over when everybody is done, or when the podium (top 3) is complete
	if open == 0 or results.size() >= mini(3, teams.size()):
		_end_race()
		return
	if results.size() >= 1 and grace_left < 0.0 and teams.size() > 1:
		grace_left = 45.0
		grace_start.rpc(45.0)


@rpc("authority", "call_local", "reliable")
func grace_start(sec: float) -> void:
	grace_show = sec


## a player who already finished can skip the waiting time (ends the race for everybody)
@rpc("any_peer", "call_local", "reliable")
func request_skip() -> void:
	if not multiplayer.is_server() or state != State.RUNNING:
		return
	var who := multiplayer.get_remote_sender_id()
	if who == 0:
		who = 1
	for ts in teams:
		if (ts.driver_id == who or ts.nav_id == who) and ts.finished:
			_end_race()
			return


## server: close the race. Finishers keep their finishing order, the rest is ranked by progress along the road.
func _end_race() -> void:
	if state == State.ENDED:
		return
	var rest: Array = []
	for ts in teams:
		if not results.has(ts.idx):
			rest.append(ts)
	rest.sort_custom(func(a, b):
		if a.dnf != b.dnf:
			return b.dnf
		return a.prog > b.prog)
	var order: Array = results.duplicate()
	var pcts: Array = []
	pcts.resize(teams.size())
	for ts in rest:
		order.append(ts.idx)
	for ts in teams:
		pcts[ts.idx] = int(100.0 * float(ts.prog) / float(maxi(1, track.points.size() - 1)))
	grace_left = -1.0
	all_done.rpc(order, pcts)


# ====================================================================== server simulation

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if state == State.COUNTDOWN and countdown_left <= 0.0:
		race_started.rpc()
	if Net.dedicated and Engine.get_physics_frames() % 120 == 0:
		var dbg := []
		for tt in teams:
			dbg.append("%s in=%s spd=%.1f" % [tt.idx, tt.input, tt.speed])
		print("ROOM state=%d t=%.1f %s" % [state, race_time, dbg])
	if state == State.RUNNING:
		race_time += delta
		if grace_left > 0.0:
			grace_left -= delta
			if grace_left <= 0.0:
				_end_race()
	for ts in teams:
		var inp := Vector3.ZERO
		if ts.phase == 4:
			ts.boom_t += delta
			if ts.boom_t > 4.5:
				_wreck(ts)
		var active := state == State.RUNNING and not ts.finished and not ts.dnf
		ts.car.hold = not active or ts.phase >= 1
		if active and not ts.bot:
			_update_damage(ts, delta)
		if active and ts.phase == 0:
			inp = _bot_input(ts, delta) if ts.bot else ts.input
			if ts.disturb > 0.0:
				ts.disturb -= delta
				inp.x = clampf(inp.x + ts.disturb_dir * 0.9, -1.0, 1.0)
			_update_progress(ts)
			ts.car.set_grip(0.28 if (track.ice_at(ts.prog) and not ts.wrong) else _weather_grip())
			if ts.car.global_position.y < track.y_at(ts.prog) - 7.0:
				ts.penalty += 5.0
				_reset_team(ts)
				show_message.rpc("fell", ts.idx)
			if ts.car.global_transform.basis.y.y < 0.25 and ts.phase == 0:
				ts.flip += delta
				if ts.flip > 2.0:
					_reset_team(ts)
			else:
				ts.flip = 0.0
		ts.car.apply_state(ts.damage, ts.fire, ts.inner, _flags(ts), inp.y)
		ts.car.set_controls(inp.x, inp.y, inp.z)
		ts.speed = ts.car.speed_kmh
	net_tick += 1
	if net_tick % 2 == 0:
		var arr := PackedFloat32Array()
		for ts in teams:
			var q := Quaternion(ts.car.global_basis.orthonormalized())
			var p := ts.car.global_position
			arr.append_array([p.x, p.y, p.z, q.x, q.y, q.z, q.w, ts.car.speed_kmh, ts.car.steer_target, float(ts.prog), float(_flags(ts)), ts.car.throttle_in, ts.damage, ts.fire, ts.inner])
		net_state.rpc(arr, race_time)


func _flags(ts: TeamState) -> int:
	return (1 if ts.wrong else 0) | (2 if ts.finished else 0) | (4 if ts.phase >= 3 else 0) | (8 if ts.cover else 0) \
		| (32 if ts.spraying else 0) | (64 if ts.phase >= 1 else 0)


## server: crashes and speed hurt the engine -> smoke -> fire; the fix is the repair mini game
func _update_damage(ts: TeamState, delta: float) -> void:
	if ts.phase == 4:
		return
	var now := Time.get_ticks_msec()
	var dv := ts.car.take_impact()
	if dv > 3.5 and now - ts.last_imp > 350:
		ts.last_imp = now
		ts.damage = minf(100.0, ts.damage + minf(45.0, (dv - 3.0) * 4.0) * ts.car.armor)
		crash_fx.rpc(ts.idx, dv)
	if ts.car.speed_kmh > ts.car.overheat_kmh and ts.phase == 0:
		ts.damage = minf(100.0, ts.damage + (ts.car.speed_kmh - ts.car.overheat_kmh) * 0.12 * delta)
	elif ts.phase == 0 and ts.fire < 0.03 and ts.inner < 0.03:
		ts.damage = maxf(0.0, ts.damage - 0.35 * delta)
	# ignition
	if ts.damage >= 80.0 and ts.fire < 0.03 and ts.inner < 0.03 and ts.burn_t == 0.0:
		ts.fire = 0.45
		ts.inner = 0.9
		ts.burn_t = 0.001
	if ts.burn_t > 0.0:
		ts.burn_t += delta
		var feeding := ts.inner > 0.05
		if feeding:
			ts.fire = minf(1.0, ts.fire + (0.03 if ts.phase < 3 else 0.12) * delta)
			ts.damage = maxf(ts.damage, 80.0)
		var left: float = ts.car.burn_time - ts.burn_t
		if left < 10.0 and ts.alarm_i != int(left):
			if ts.alarm_i == -1:
				show_message.rpc("boom_soon", ts.idx)
			ts.alarm_i = int(left)
			repair_fx.rpc(ts.idx, "alarm")
		if ts.burn_t > ts.car.burn_time:
			_explode(ts)
			return
	# extinguisher
	if ts.spraying and ts.aimed and ts.phase >= 3:
		ts.fire = maxf(0.0, ts.fire - 0.45 * ts.car.ext_mult * delta)
		if ts.cover:
			ts.inner = maxf(0.0, ts.inner - 0.4 * ts.car.ext_mult * delta)
		if ts.burn_t > 0.0 and ts.fire < 0.03 and ts.inner < 0.03:
			ts.fire = 0.0
			ts.inner = 0.0
			ts.burn_t = 0.0
			ts.alarm_i = -1
			ts.damage = minf(ts.damage, 70.0)
			repair_fx.rpc(ts.idx, "out")
	# cooling while the hood is up
	if ts.phase >= 3 and ts.burn_t == 0.0:
		ts.damage = maxf(0.0, ts.damage - 12.0 * delta)


## the fire was not put out in time: the car blows up in the middle of the road and tumbles through the air
func _explode(ts: TeamState) -> void:
	var car := ts.car
	ts.spraying = false
	ts.boom_t = 0.0
	ts.fire = 1.0
	ts.inner = 0.0
	_set_phase(ts, 4, ts.repairer, false)
	car.hold = false
	car.angular_damp = 0.25
	car.linear_damp = 0.05
	var fwd := -car.global_basis.z
	var right := car.global_basis.x
	car.apply_central_impulse(Vector3(0, car.mass * 12.5, 0) + fwd * car.mass * 4.0)
	car.apply_torque_impulse(-right * car.mass * 6.5 + car.global_basis.z * car.mass * randf_range(-2.0, 2.0))
	explode_fx.rpc(ts.idx)


@rpc("authority", "call_local", "reliable")
func explode_fx(team: int) -> void:
	var ts := teams[team]
	var car := ts.car
	car.explode_fx()
	Sfx.play3d("boom", car, 10.0, 0.8)
	Sfx.play3d("crash_hard", car, 6.0, 0.7)
	var d := car.global_position.distance_to(local_avatar.global_position) if local_avatar else 0.0
	if team == my_team or d < 40.0:
		shake = 1.0
		flash = 1.0
		flash_rect.color = Color(1.0, 0.85, 0.5, 0.0)
		get_tree().create_timer(2.0).timeout.connect(func(): flash_rect.color = Color(0.9, 0.1, 0.1, 0.0))
	# whoever stood in front of the car is thrown away
	if ts.repairer != 0 and avatars.has(ts.repairer):
		var av: Avatar = avatars[ts.repairer]
		if av.outside:
			var gp := av.global_position
			var fwd := -car.global_basis.z
			av.get_parent().remove_child(av)
			add_child(av)
			av.global_position = gp
			av.blast(fwd * 7.0 + Vector3(0, 6.5, 0), gp.y - 0.95)


func _wreck(ts: TeamState) -> void:
	ts.penalty += 25.0
	ts.fire = 0.0
	ts.inner = 0.0
	ts.burn_t = 0.0
	ts.alarm_i = -1
	ts.damage = 30.0
	ts.spraying = false
	ts.car.angular_damp = 1.5
	ts.car.linear_damp = 0.12
	_set_phase(ts, 0, 0, false)
	_reset_team(ts)
	show_message.rpc("wreck", ts.idx)


func _set_phase(ts: TeamState, ph: int, who: int, cov: bool) -> void:
	ts.phase = ph
	ts.repairer = who
	ts.cover = cov
	repair_state.rpc(ts.idx, ph, who, cov)


@rpc("authority", "call_local", "reliable")
func repair_state(team: int, ph: int, who: int, cov: bool) -> void:
	var ts := teams[team]
	if ph == 4 and director:
		director.mark_boom(team)
	ts.phase = ph
	ts.repairer = who
	ts.cover = cov
	for id in [ts.driver_id, ts.nav_id]:
		if id == 0 or not avatars.has(id):
			continue
		var av: Avatar = avatars[id]
		if ph == 4:
			continue
		if av.get_parent() != ts.car:
			av.get_parent().remove_child(av)
			ts.car.add_child(av)
			av.reseat()
		if id == who and ph >= 2:
			av.go_outside(OUT_POS)
			av.work = 1
			if id == my_id:
				look_yaw = 0.0
				look_pitch = -0.35
				map_mode = false
		else:
			av.go_inside()
	if who == 0 and ts.car:
		ts.spraying = false


@rpc("authority", "call_local", "reliable")
func repair_fx(team: int, kind: String) -> void:
	var car := teams[team].car
	match kind:
		"lever":
			Sfx.play3d("click", car, 2.0)
		"exit":
			Sfx.play3d("thud", car, 0.0, 1.3)
		"lift":
			Sfx.play3d("clang", car, 0.0, 0.8)
			Sfx.play3d("thud", car, -3.0)
		"cover":
			Sfx.play3d("clang", car, 0.0, 1.2)
		"enter":
			Sfx.play3d("thud", car, 0.0)
		"out":
			Sfx.play3d("success", car, 2.0)
			if teams[team].repairer == my_id:
				Profile.event("fire_out")
				Profile.stats["fires"] = int(Profile.stats["fires"]) + 1
		"boom":
			Sfx.play3d("boom", car, 6.0)
		"alarm":
			Sfx.play3d("warn", car, 6.0, 1.4)


@rpc("authority", "call_local", "reliable")
func crash_fx(team: int, dv: float) -> void:
	var car := teams[team].car
	Sfx.play3d("crash_hard" if dv > 9.0 else "crash_soft", car, clampf(dv * 0.6 - 6.0, -6.0, 6.0), randf_range(0.9, 1.1))
	if team == my_team:
		shake = maxf(shake, clampf(dv / 14.0, 0.2, 0.9))
	if dv > 7.0 and not Net.dedicated and car != null:
		_crash_burst(car.global_position + Vector3(0, 0.8, 0), dv)


## a puff of dust and a spray of glittering glass where the cars hit
func _crash_burst(pos: Vector3, dv: float) -> void:
	for kind in 2:
		var p := CPUParticles3D.new()
		p.top_level = true
		p.global_position = pos
		p.one_shot = true
		p.emitting = true
		p.explosiveness = 0.95
		p.amount = Gfx.particles(24 if kind == 0 else 40)
		p.lifetime = 1.4 if kind == 0 else 1.1
		p.direction = Vector3.UP
		p.spread = 70.0
		p.initial_velocity_min = 2.0 if kind == 0 else 4.0
		p.initial_velocity_max = clampf(dv * 0.5, 4.0, 9.0)
		p.gravity = Vector3(0, 0.5 if kind == 0 else -9.0, 0)
		var q := QuadMesh.new()
		q.size = Vector2(1.3, 1.3) if kind == 0 else Vector2(0.09, 0.09)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		q.material = m
		p.mesh = q
		var g := Gradient.new()
		if kind == 0:
			g.colors = PackedColorArray([Color(0.6, 0.57, 0.52, 0.0), Color(0.6, 0.57, 0.52, 0.55), Color(0.5, 0.5, 0.5, 0.0)])
			g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
		else:
			g.colors = PackedColorArray([Color(0.85, 0.95, 1.0, 1.0), Color(0.75, 0.9, 1.0, 0.9), Color(0.7, 0.85, 1.0, 0.0)])
			g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
		p.color_ramp = g
		add_child(p)
		get_tree().create_timer(2.5).timeout.connect(p.queue_free)


# --- repair requests (any teammate may do the work; only one goes outside)

@rpc("any_peer", "reliable")
func request_repair(action: String) -> void:
	if multiplayer.is_server():
		_server_repair(multiplayer.get_remote_sender_id(), action)


@rpc("any_peer", "unreliable_ordered")
func request_spray(on: bool, aim: bool) -> void:
	if multiplayer.is_server():
		_server_spray(multiplayer.get_remote_sender_id(), on, aim)


func _server_spray(peer: int, on: bool, aim: bool) -> void:
	var ts := teams[Net.team_of.get(peer, 0)]
	if ts.repairer != peer or ts.phase != 3:
		ts.spraying = false
		return
	ts.spraying = on
	ts.aimed = aim


func _server_repair(peer: int, action: String) -> void:
	if state != State.RUNNING or not Net.team_of.has(peer):
		return
	var ts := teams[Net.team_of[peer]]
	if ts.finished or ts.dnf:
		return
	var spd := ts.car.speed_kmh
	match action:
		"lever":
			if ts.phase == 0 and ts.damage >= 40.0 and spd < 12.0:
				_set_phase(ts, 1, 0, false)
				repair_fx.rpc(ts.idx, "lever")
		"exit":
			if ts.phase == 1 and spd < 8.0:
				_set_phase(ts, 2, peer, false)
				repair_fx.rpc(ts.idx, "exit")
		"lift":
			if ts.phase == 2 and ts.repairer == peer:
				_set_phase(ts, 3, peer, false)
				repair_fx.rpc(ts.idx, "lift")
		"cover":
			if ts.phase == 3 and ts.repairer == peer and not ts.cover:
				_set_phase(ts, 3, peer, true)
				repair_fx.rpc(ts.idx, "cover")
		"enter":
			if ts.phase >= 3 and ts.repairer == peer and ts.fire < 0.03 and ts.inner < 0.03 and ts.damage < 25.0:
				ts.spraying = false
				_set_phase(ts, 0, 0, false)
				repair_fx.rpc(ts.idx, "enter")
				show_message.rpc("back_road", ts.idx)


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
	if ts.finished or ts.dnf or ts.phase >= 1:
		return
	_reset_team(ts)
	show_message.rpc("back_road", ts.idx)


# ====================================================================== local frame loop

var _hl_t := 0.0
var _hl_tilt := 0.0
var _hl_sent := false


## every few seconds remember where we are (a crash report then says what was going on); if the car lies on
## its side / nose in the sky for a few seconds, report it and put it back on the road
func _health(delta: float) -> void:
	if teams.is_empty() or my_team >= teams.size() or my_role != "driver":
		return
	var c = teams[my_team].car
	if c == null or not is_instance_valid(c):
		return
	var up: float = c.global_transform.basis.y.y
	var nose: float = -c.global_transform.basis.z.y
	_hl_t += delta
	if _hl_t >= 4.0:
		_hl_t = 0.0
		Backend.crumb("race car=%s spd=%d up=%.2f nose=%.2f y=%.1f look=%.2f" % [str(c.model), int(c.speed_kmh), up, nose, c.global_position.y, look_pitch])
	if (up < 0.45 or absf(nose) > 0.55) and c.speed_kmh < 25.0 and teams[my_team].phase == 0:
		_hl_tilt += delta
		if _hl_tilt > 3.0:
			_hl_tilt = 0.0
			if not _hl_sent:
				_hl_sent = true
				Backend.report("tilt", "Car stuck tilted car=%s up=%.2f nose=%.2f y=%.1f" % [str(c.model), up, nose, c.global_position.y])
			_request_reset()
	else:
		_hl_tilt = 0.0


func _process(delta: float) -> void:
	_hud_tick()
	_health(delta)
	_weather_process(delta)
	_sun_update(delta)
	if director and not teams.is_empty():
		var cars: Array = []
		for ts in teams:
			cars.append(ts.car)
		director.record(delta, cars)
		if zones.has("replay"):
			zones["replay"].visible = director.available() and state != State.ENDED
	_map_tick += delta
	if ipad_vp != null and Gfx.map_fps < 60 and _map_tick >= 1.0 / float(Gfx.map_fps):
		_map_tick = 0.0
		ipad_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	if state == State.RUNNING and not fast_done and teams[my_team].speed > 140.0 and my_role == "driver":
		fast_done = true
		Profile.event("speed140")
	if state == State.COUNTDOWN:
		countdown_left -= delta
	if my_role == "driver":
		_read_driving_input()
	_update_look(delta)
	_update_repair_ui(delta)
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
		local_avatar.cam.h_offset = randf_range(-1.0, 1.0) * (shake * 0.08 + _drive_shake)
		local_avatar.cam.v_offset = randf_range(-1.0, 1.0) * (shake * 0.08 + _drive_shake)
	_update_hud()


func _zone_pressed(zone_name: String) -> bool:
	if not zones.has(zone_name) or not (zones[zone_name] as Control).visible:
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
		if steer_mode == "buttons":
			if _zone_pressed("left"):
				steer -= 1.0
			if _zone_pressed("right"):
				steer += 1.0
		else:
			var lk: float = SteerUI.LOCK[steer_mode]
			if wheel_touch == -1:
				wheel_angle = move_toward(wheel_angle, 0.0, get_process_delta_time() * 5.0)   # self-centring
			steer += clampf(wheel_angle / lk, -1.0, 1.0)
			if wheel_ui:
				wheel_ui.angle = wheel_angle
				wheel_ui.queue_redraw()
		if _zone_pressed("gas"):
			thr = 1.0
		if _zone_pressed("brake"):
			brk = 1.0
	_brake_in = brk
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
		local_avatar.cam.fov = move_toward(local_avatar.cam.fov, 40.0 if map_mode else 82.0 + _fov_kick, delta * 160.0)
	if map_mode and not dragging:
		if solo and local_avatar.role == "driver":      # the dashboard screen is on the passenger side
			look_yaw = move_toward(look_yaw, -0.72, delta * 5.0)
			look_pitch = move_toward(look_pitch, -0.12, delta * 4.0)
		else:
			look_yaw = move_toward(look_yaw, 0.0, delta * 5.0)
			look_pitch = move_toward(look_pitch, -1.03, delta * 4.0)
		look_idle = 0.0
	elif (Input.is_action_pressed("look_mate") or (Controls.map.get("look_mate", -1) >= 0 and Input.is_joy_button_pressed(0, Controls.map["look_mate"]))) and local_avatar.seat_dx != 0.0:
		var target_yaw := -signf(local_avatar.seat_dx) * 1.45
		look_yaw = move_toward(look_yaw, target_yaw, delta * 7.0)
		look_pitch = move_toward(look_pitch, 0.1, delta * 3.0)
		look_idle = 0.0
	elif dragging:
		look_idle = 0.0
	else:
		look_idle += delta
		if look_idle > 2.5:    # spring back to looking at the road (or at the engine while repairing)
			look_yaw = move_toward(look_yaw, 0.0, delta * 3.0)
			look_pitch = move_toward(look_pitch, -0.35 if _am_repairer() else 0.0, delta * 3.0)
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
	look_pitch = clampf(look_pitch - rel.y * 0.006, -1.2, 0.3 if (local_avatar != null and local_avatar.role == "driver") else 0.75)
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
	if teams[my_team].phase >= 1:
		return
	if not solo:
		Profile.event("punch")
	if multiplayer.is_server():
		_server_punch(my_id)
	else:
		request_punch.rpc_id(1)


# ---- stickers: pick one -> server -> every player sees it above the sender's car (and hears it, positional)
var sticker_picker: Stickers.Picker
var director: ReplayDirector
var _sticker_cd := 0.0


func _take_photo() -> void:
	if Net.dedicated:
		return
	Share.snap(self, "race", tname_for_photo(), [hud])


func tname_for_photo() -> String:
	return "%s  %s" % [track.stage_name, "%d km/h" % int(teams[my_team].speed)]


func _play_replay() -> void:
	if director and director.available():
		if sticker_picker and is_instance_valid(sticker_picker):
			sticker_picker.queue_free()
			sticker_picker = null
		director.play(self, teams)


func _toggle_stickers() -> void:
	if state == State.ENDED or Net.dedicated:
		return
	if sticker_picker and is_instance_valid(sticker_picker):
		sticker_picker.queue_free()
		sticker_picker = null
		return
	sticker_picker = Stickers.Picker.new()
	sticker_picker.z_index = 110
	hud_root.add_child(sticker_picker)
	var vs := get_viewport().get_visible_rect().size
	var ms := sticker_picker.get_combined_minimum_size()
	sticker_picker.position = Vector2(vs.x - ms.x - 160.0, 100.0)
	sticker_picker.size = ms
	sticker_picker.picked.connect(_send_sticker)


func _send_sticker(idx: int) -> void:
	if sticker_picker and is_instance_valid(sticker_picker):
		sticker_picker.queue_free()
		sticker_picker = null
	var now := Time.get_ticks_msec() / 1000.0
	if now < _sticker_cd:
		return
	_sticker_cd = now + Stickers.COOLDOWN
	Sfx.play("click", -8.0)
	if multiplayer.is_server():
		_server_sticker(my_id, idx)
	else:
		request_sticker.rpc_id(1, idx)


@rpc("any_peer", "reliable")
func request_sticker(idx: int) -> void:
	if multiplayer.is_server():
		_server_sticker(multiplayer.get_remote_sender_id(), idx)


func _server_sticker(peer: int, idx: int) -> void:
	if idx < 0 or idx >= Stickers.LIST.size() or not Net.team_of.has(peer):
		return
	var now := Time.get_ticks_msec()
	if now - int(last_punch.get(-1000 - peer, 0)) < int(Stickers.COOLDOWN * 900.0):
		return
	last_punch[-1000 - peer] = now
	sticker_fx.rpc(int(Net.team_of[peer]), idx)


@rpc("authority", "call_local", "reliable")
func sticker_fx(team: int, idx: int) -> void:
	if Net.dedicated or team < 0 or team >= teams.size() or idx < 0 or idx >= Stickers.LIST.size():
		return
	Stickers.show_on(teams[team].car, idx)


func _do_emote() -> void:
	if teams[my_team].phase >= 1:
		return
	Profile.event("emote")
	if multiplayer.is_server():
		_server_emote(my_id)
	else:
		request_emote.rpc_id(1)


@rpc("any_peer", "reliable")
func request_emote() -> void:
	if multiplayer.is_server():
		_server_emote(multiplayer.get_remote_sender_id())


func _server_emote(peer: int) -> void:
	var now := Time.get_ticks_msec()
	if now - int(last_punch.get(-peer, 0)) < 3000 or not avatars.has(peer):
		return
	last_punch[-peer] = now
	var o: Dictionary = (Net.loadouts.get(peer, {}) as Dictionary).get("outfit", {})
	emote_fx.rpc(peer, str(o.get("emote", "wave")))


@rpc("authority", "call_local", "reliable")
func emote_fx(peer: int, id: String) -> void:
	if avatars.has(peer):
		(avatars[peer] as Avatar).play_emote(id)


func _set_gesture(g: int) -> void:
	if my_role != "navigator":
		return
	var ng := 0 if my_gesture == g else g    # tapping the same gesture again returns the hand to rest
	if multiplayer.is_server():
		_server_gesture(my_id, ng)
	else:
		request_gesture.rpc_id(1, ng)


func _do_beacon() -> void:
	if my_role != "navigator" and (not solo or Net.ffa):
		return
	Profile.event("beacon")
	if multiplayer.is_server():
		_server_beacon(my_id)
	else:
		request_beacon.rpc_id(1)


## MAP button: closed -> flips open and the camera looks at it -> back to the road (stays open) -> closes
func _toggle_map() -> void:
	if map_screen:
		if not map_screen.is_open:
			map_screen.set_open(true)
			map_mode = true
		elif map_mode:
			map_mode = false
		else:
			map_screen.set_open(false)
	elif ipad_vp:
		map_mode = not map_mode
	elif clipboard:
		clipboard.visible = not clipboard.visible


func _map_size() -> void:
	if map_screen:
		map_screen.cycle_size()
		if not map_screen.is_open:
			map_screen.set_open(true)


func _map_near() -> void:
	if map_screen:
		map_screen.toggle_near()
		if not map_screen.is_open:
			map_screen.set_open(true)


func _input(event: InputEvent) -> void:
	if _picker != null and is_instance_valid(_picker):
		return
	if _hud_editor != null and is_instance_valid(_hud_editor):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_H:
				_cabin("horn")
			KEY_L:
				_cabin("lights")
			KEY_K:
				_cabin("wipers")
			KEY_G:
				_cabin("drink")
			KEY_COMMA:
				_cabin("signal_left")
			KEY_PERIOD:
				_cabin("signal_right")
			KEY_BRACKETLEFT:
				_cabin("mirror_left")
			KEY_BRACKETRIGHT:
				_cabin("mirror_right")
			KEY_J:
				_cabin("hazard")
			KEY_F:
				_cabin("flash")
			KEY_B:
				_cabin("hbrake")
			KEY_N:
				_cabin("window")
			KEY_V:
				_cabin("ac")
			KEY_I:
				_cabin("dome")
			KEY_Y:
				_cabin("greet")
	var pad_act := Controls.cabin_for(event)
	if pad_act != "":
		match pad_act:
			"reset":
				_request_reset()
			"map_toggle":
				_toggle_map()
			"radio_next":
				_radio_step(1)
			"radio_prev":
				_radio_step(-1)
			"emote":
				_do_emote()
			"look_mate":
				pass
			_:
				if my_role == "driver":
					_cabin(pad_act)
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_press(event.index, event.position)
		else:
			touches.erase(event.index)
			zone_touch.erase(event.index)
			if event.index == wheel_touch:
				wheel_touch = -1
			if event.index == look_touch:
				look_touch = -1
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
		if event.index == wheel_touch and wheel_ui:
			var a: float = (event.position - _wheel_rect().get_center()).angle()
			var lk: float = SteerUI.LOCK[steer_mode]
			wheel_angle = clampf(wheel_angle + wrapf(a - wheel_last, -PI, PI), -lk, lk)
			wheel_last = a
			return
		var mt := teams[my_team]
		if mt.phase == 2 and mt.repairer == my_id:
			lift_swipe += -event.relative.y
			if lift_swipe > 260.0:
				lift_swipe = 0.0
				_repair_action()
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
	elif event.is_action_pressed("interact"):
		_repair_action()
	elif event.is_action_pressed("map_toggle"):
		_toggle_map()
	elif event.is_action_pressed("emote"):
		_do_emote()
	elif event.is_action_pressed("map_size"):
		_map_size()
	elif event.is_action_pressed("map_near"):
		_map_near()
	elif event.is_action_pressed("radio_next"):
		_radio_step(1)
	elif event.is_action_pressed("radio_prev"):
		_radio_step(-1)
	elif event.is_action_pressed("radio_toggle"):
		Radio.toggle()


func _apply_steer_mode() -> void:
	steer_mode = Profile.steer_mode if Profile.steer_mode != "" else "buttons"
	for zn in ["left", "right"]:
		if zones.has(zn):
			(zones[zn] as Control).queue_free()
			zones.erase(zn)
	if wheel_ui:
		wheel_ui.queue_free()
		wheel_ui = null
	wheel_angle = 0.0
	if steer_mode == "buttons":
		_make_zone("left", "", 0.0, 1.0, 20, -170, 160, -40, 40)
		_make_zone("right", "", 0.0, 1.0, 180, -170, 320, -40, 40)
	else:
		wheel_ui = SteerUI.Wheel.new()
		wheel_ui.lock = SteerUI.LOCK[steer_mode]
		wheel_ui.show360 = steer_mode == "wheel360"
		wheel_ui.anchor_top = 1.0
		wheel_ui.anchor_bottom = 1.0
		wheel_ui.offset_left = 16
		wheel_ui.offset_right = 300
		wheel_ui.offset_top = -300
		wheel_ui.offset_bottom = -16
		hud_root.add_child(wheel_ui)
	for tm in teams:
		if tm.car and tm.driver_id == my_id:
			tm.car.wheel_gain = SteerUI.LOCK[steer_mode]


## mirror the bottom driving controls (pedals, steering, buttons) left <-> right when the player chose it
func _flip_hud() -> void:
	if not Profile.hud_flip:
		return
	var list: Array = []
	for k in zones:
		list.append(zones[k])
	if wheel_ui:
		list.append(wheel_ui)
	for c in list:
		var ctl := c as Control
		if ctl == null or not is_instance_valid(ctl):
			continue
		if ctl.has_meta("fl_l") and is_equal_approx(ctl.offset_left, float(ctl.get_meta("fl_l"))) and is_equal_approx(ctl.anchor_left, float(ctl.get_meta("fl_a"))):
			continue                    # already mirrored and not moved since
		var al := ctl.anchor_left
		var ar := ctl.anchor_right
		var ol := ctl.offset_left
		var orr := ctl.offset_right
		ctl.anchor_left = 1.0 - ar
		ctl.anchor_right = 1.0 - al
		ctl.offset_left = -orr
		ctl.offset_right = -ol
		ctl.rotation = -ctl.rotation
		ctl.set_meta("fl_l", ctl.offset_left)
		ctl.set_meta("fl_a", ctl.anchor_left)


## every frame: switched-off buttons stay off, and the player's transparency is applied to all driving buttons
func _hud_tick() -> void:
	for id in HudLayout.HIDEABLE:
		if zones.has(id) and HudLayout.is_removed(id):
			(zones[id] as Control).visible = false
	for k in zones:
		var za := HudLayout.get_alpha(str(k))
		var zc := zones[k] as Control
		if not is_equal_approx(zc.modulate.a, za):
			zc.modulate.a = za
	for k in zones:                                              # pressed: the body lights up and the icon + text shrink a little
		var zp := zones[k] as Control
		if not zp.visible or zp.get_child_count() < 2:
			continue
		var pr := _zone_pressed(str(k))
		zp.self_modulate = Color(1.6, 1.6, 1.6) if pr else Color.WHITE
		var want := 0.88 if pr else 1.0
		for ch in zp.get_children():
			if ch is Label or ch is ZoneIcon:
				var cc := ch as Control
				cc.pivot_offset = cc.size * 0.5
				cc.scale = cc.scale.lerp(Vector2(want, want), 0.45)


func _open_pause_menu() -> void:
	if _pause != null and is_instance_valid(_pause):
		return
	var pm := PauseMenu.new()
	pm.hud_editor_cb = _open_hud_editor if my_role == "driver" else Callable()
	pm.exit_cb = func():
		get_tree().paused = false
		Net.return_to_menu()
	if _can_pause():                                 # alone: the race waits while the menu is open (online / LAN keeps running)
		get_tree().paused = true
		pm.tree_exited.connect(func():
			if _hud_editor == null or not is_instance_valid(_hud_editor):
				get_tree().paused = false)
	pm.reset_cb = _request_reset
	pm.photo_cb = _take_photo
	pm.steer_cb = func():
		_apply_steer_mode()
		_flip_hud()
		HudLayout.apply_world(zones)
	_pause = pm
	hud_root.add_child(pm)


var _pause: Control


func _wheel_rect() -> Rect2:
	if wheel_ui == null:
		return Rect2()
	return wheel_ui.get_global_rect()


func _touch_press(index: int, pos: Vector2) -> void:
	touches[index] = pos
	if hint_layer != null and is_instance_valid(hint_layer):
		hint_layer.queue_free()
		hint_layer = null
	if wheel_ui and wheel_touch == -1 and _wheel_rect().has_point(pos):
		wheel_touch = index
		wheel_last = (pos - _wheel_rect().get_center()).angle()
		return
	for zn in zones:
		if (zones[zn] as Control).visible and not HudLayout.is_removed(str(zn)) and _zone_has(zones[zn] as Control, pos):
			zone_touch[index] = zn
			_press_feel(str(zn))
			if tap_zones.has(zn):
				(tap_zones[zn] as Callable).call()
			return
	if look_touch == -1:
		look_touch = index   # a touch outside every button = look around


## a button was touched: short vibration + soft click (the driving pedals only vibrate, no click)
func _press_feel(zn: String) -> void:
	if Gfx.haptics and OS.has_feature("mobile"):
		Input.vibrate_handheld(12 if ["gas", "brake", "left", "right"].has(zn) else 18, 0.5)
	if not ["gas", "brake", "left", "right"].has(zn):
		Sfx.play("click", -12.0, 1.0 + randf_range(-0.05, 0.08))


## hit test that also works for buttons the player scaled / rotated
func _zone_has(c: Control, pos: Vector2) -> bool:
	var l := c.get_global_transform().affine_inverse() * pos
	return Rect2(Vector2.ZERO, c.size).has_point(l)


var _hud_editor: Control


func _open_hud_editor() -> void:
	if _hud_editor != null and is_instance_valid(_hud_editor):
		return
	var ed := HudEditor.new()
	_hud_editor = ed
	if _can_pause():
		get_tree().paused = true
	ed.closed.connect(func():
		_hud_editor = null
		if _pause == null or not is_instance_valid(_pause):
			get_tree().paused = false
		HudLayout.apply_world(zones)
		_flip_hud()
		_cab_page(1))
	hud_root.add_child(ed)


func _click_zone(pos: Vector2) -> void:
	for zn in zones:
		if (zones[zn] as Control).visible and not HudLayout.is_removed(str(zn)) and _zone_has(zones[zn] as Control, pos) and tap_zones.has(zn):
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
		env.fog_density = 0.011 * Gfx.fog_mul()
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
		env.fog_density = th["fog"] * Gfx.fog_mul() * 0.7
		sun.light_energy = 1.0
		sun.light_color = Color(1.0, 0.95, 0.86)                 # warm sun
		env.fog_sun_scatter = 0.22                               # haze glows towards the sun
		_apply_weather(env, sm, sun)
		if weather == "clear" and Net.track_seed % 3 == 0:        # golden hour: deep blue top fading into orange at the horizon
			sm.sky_top_color = Color(0.16, 0.26, 0.55)
			sm.sky_horizon_color = Color(1.0, 0.62, 0.32)
			sm.ground_horizon_color = Color(0.95, 0.6, 0.4)
			sm.sky_curve = 0.12
			env.fog_light_color = Color(1.0, 0.7, 0.45)
			env.fog_density = 0.0045 * Gfx.fog_mul()
			sun.rotation_degrees = Vector3(-14, 30, 0)
			sun.light_color = Color(1.0, 0.68, 0.38)
			env.fog_sun_scatter = 0.5
		if Gfx.fx >= 0.8 and weather != "night":                 # real shadows on medium and high quality
			sun.shadow_enabled = true
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			sun.directional_shadow_max_distance = 80.0
			sun.shadow_blur = 1.5
		if weather == "clear" or weather == "":
			_make_sun_glare(sun)
	_wx_env = env
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	add_child(sun)


# ====================================================================== weather + bots

func _apply_weather(env: Environment, sm: ProceduralSkyMaterial, sun: DirectionalLight3D) -> void:
	match weather:
		"fog":
			var g := Color(0.66, 0.69, 0.73)
			sm.sky_top_color = g
			sm.sky_horizon_color = g
			sm.ground_horizon_color = g
			sm.ground_bottom_color = g
			env.fog_light_color = g
			env.fog_density = 0.0125 * Gfx.fog_mul()
			sun.light_energy = 0.6
		"rain":
			var g2 := Color(0.4, 0.43, 0.48)
			sm.sky_top_color = g2
			sm.sky_horizon_color = g2.lightened(0.1)
			sm.ground_horizon_color = g2.lightened(0.1)
			sm.ground_bottom_color = g2
			env.fog_light_color = g2.lightened(0.1)
			env.fog_density = 0.0065 * Gfx.fog_mul()
			sun.light_energy = 0.5
			env.ambient_light_energy = 0.75
		"storm":
			var g3 := Color(0.2, 0.22, 0.27)
			sm.sky_top_color = g3
			sm.sky_horizon_color = g3.lightened(0.08)
			sm.ground_horizon_color = g3.lightened(0.08)
			sm.ground_bottom_color = g3
			env.fog_light_color = g3.lightened(0.08)
			env.fog_density = 0.0095 * Gfx.fog_mul()
			sun.light_energy = 0.25
			env.ambient_light_energy = 0.55
		"night":
			sm.sky_top_color = Color(0.008, 0.012, 0.035)
			sm.sky_horizon_color = Color(0.03, 0.04, 0.09)
			sm.ground_horizon_color = Color(0.03, 0.04, 0.09)
			sm.ground_bottom_color = Color(0.015, 0.02, 0.045)
			env.fog_light_color = Color(0.02, 0.03, 0.07)
			env.fog_density = 0.006 * Gfx.fog_mul()
			env.ambient_light_energy = 0.28
			sun.light_color = Color(0.55, 0.65, 1.0)
			sun.light_energy = 0.12


## the film look per weather: warm at golden hour, cold at night, washed out in rain and fog
func _grade_look() -> Dictionary:
	if weather == "night" or weather == "storm":
		return {"tint": Vector3(0.9, 0.97, 1.12), "shadow_tint": Vector3(0.1, 0.25, 0.6), "contrast": 1.0, "sat": 0.95, "vig": 0.35, "bloom": 1.3}
	if weather == "rain" or weather == "fog":
		return {"tint": Vector3(0.98, 1.0, 1.03), "shadow_tint": Vector3(0.0, 0.05, 0.15), "contrast": 1.06, "sat": 0.86, "vig": 0.3, "bloom": 0.45}
	if Net.track_seed % 3 == 0:
		return {"tint": Vector3(1.12, 0.98, 0.84), "shadow_tint": Vector3(0.25, 0.08, 0.2), "contrast": 1.13, "sat": 1.15, "vig": 0.36, "bloom": 0.95}
	return {"tint": Vector3(1.04, 1.0, 0.96), "shadow_tint": Vector3(0.05, 0.1, 0.25), "contrast": 1.1, "sat": 1.1, "vig": 0.28, "bloom": 0.6}


func _weather_grip() -> float:
	return {"rain": 0.86, "storm": 0.78}.get(weather, 1.0)


func _build_weather_fx() -> void:
	if Net.dedicated or not (weather in ["rain", "storm"]):
		return
	_rain = CPUParticles3D.new()
	_rain.amount = 700 if weather == "storm" else 450
	_rain.lifetime = 0.9
	_rain.preprocess = 1.0
	_rain.top_level = true
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(24, 0.5, 34)
	_rain.direction = Vector3(0.12, -1, 0)
	_rain.spread = 2.0
	_rain.gravity = Vector3(0, -22, 0)
	_rain.initial_velocity_min = 16.0
	_rain.initial_velocity_max = 20.0
	var bm := BoxMesh.new()
	bm.size = Vector3(0.018, 0.75, 0.018)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(0.85, 0.9, 1.0, 0.6)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rain.mesh = bm
	_rain.material_override = rm
	add_child(_rain)
	if weather == "storm" and hud_root:
		_bolt = ColorRect.new()
		_bolt.color = Color(0.85, 0.9, 1.0, 0.0)
		_bolt.set_anchors_preset(Control.PRESET_FULL_RECT)
		_bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_root.add_child(_bolt)
		hud_root.move_child(_bolt, 0)


func _make_sun_glare(sun: DirectionalLight3D) -> void:
	_sun_ref = sun
	_sun_node = Sprite3D.new()
	_sun_node.texture = Scenery.glare_texture()
	_sun_node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sun_node.shaded = false
	_sun_node.no_depth_test = true
	_sun_node.double_sided = true
	_sun_node.transparent = true
	_sun_node.pixel_size = 6.0
	_sun_node.modulate = Color(1, 1, 1, 0.9)
	_sun_node.top_level = true
	_sun_node.render_priority = 5
	_sun_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat_blend := Sprite3D.new()                                # (placeholder to keep the type checker quiet)
	mat_blend.queue_free()
	add_child(_sun_node)


## keep the sun glow far away in its direction, centred around the camera
func _sun_update(delta: float) -> void:
	var tm := Time.get_ticks_msec() * 0.001
	for fi in _wave_flags.size():
		_wave_flags[fi].rotation.y = sin(tm * 3.0 + float(fi)) * 0.35
		_wave_flags[fi].scale.z = 1.0 + sin(tm * 5.0 + float(fi) * 2.0) * 0.12
	for bd in _birds:
		var a: float = bd.get_meta("a") + tm * float(bd.get_meta("sp"))
		var r: float = bd.get_meta("r")
		var c: Vector3 = bd.get_meta("c")
		bd.position = c + Vector3(cos(a) * r, float(bd.get_meta("y")) + sin(tm * 0.7 + a) * 4.0, sin(a) * r)
		bd.rotation.y = -a
		bd.rotation.z = sin(tm * 9.0 + a * 5.0) * 0.5
	if _sun_node == null or _sun_ref == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var toward: Vector3 = _sun_ref.global_transform.basis.z
	var dist := minf(cam.far * 0.8, 1500.0)
	_sun_node.global_position = cam.global_position + toward * dist
	_sun_node.pixel_size = dist * 0.00042
	var facing := (-cam.global_transform.basis.z).dot(toward)         # glare grows when you look at the sun
	_sun_node.modulate.a = clampf(0.25 + facing * 0.9, 0.0, 0.95)
	if _cloud_root != null:
		_cloud_root.rotation.y += delta * 0.003


func _weather_process(delta: float) -> void:
	if _rain and not teams.is_empty():
		var c := teams[my_team].car
		if is_instance_valid(c):
			_rain.global_position = c.global_position + Vector3(0, 13, -8)
			_rain.global_rotation = Vector3.ZERO
			_rain.emitting = not track.in_tunnel(teams[my_team].prog)
	if _bolt:
		_bolt_wait -= delta
		if _bolt_wait <= 0.0:
			_bolt_wait = randf_range(7.0, 16.0)
			var tw := _bolt.create_tween()
			tw.tween_property(_bolt, "color:a", 0.55, 0.05)
			tw.tween_property(_bolt, "color:a", 0.05, 0.08)
			tw.tween_property(_bolt, "color:a", 0.4, 0.05)
			tw.tween_property(_bolt, "color:a", 0.0, 0.35)
			Sfx.play("boom", -12.0, 0.45)


## the server drives a bot car: follow the road ahead, brake for corners, make small mistakes at low skill
func _bot_input(ts: TeamState, delta: float) -> Vector3:
	var car := ts.car
	var spd := car.speed_kmh
	var n := track.points.size()
	var ahead := clampi(int(spd / 20.0) + 2, 3, 11)
	var ti := mini(ts.prog + ahead, n - 1)
	var tgt := track.points[ti]
	# obstacles: aim for the free side of the road, slow down for a bump
	var bump := false
	for k in range(maxi(0, ts.prog - 1), mini(n, ts.prog + ahead + 7)):
		if _obst_at.has(k):
			var o: Dictionary = _obst_at[k]
			if o["kind"] == "bump":
				bump = true
			else:
				tgt += Track.left_of(track.headings[ti]) * (-float(o["side"]) * 3.4)
			break
	var lp := car.global_transform.affine_inverse() * tgt
	var steer := clampf(lp.x / maxf(absf(lp.z), 3.0) * 1.9, -1.0, 1.0)
	# human-like mistakes: now and then a short wobble (more often and bigger for weak bots)
	ts.wob_wait -= delta
	if ts.wob_wait <= 0.0:
		ts.wob_wait = randf_range(3.0, 8.0) * (0.5 + ts.bot_skill)
		ts.wob_t = 0.5
		ts.wob = randf_range(-1.0, 1.0) * (1.05 - ts.bot_skill) * 1.6
	if ts.wob_t > 0.0:
		ts.wob_t -= delta
		steer = clampf(steer + ts.wob, -1.0, 1.0)
	# corner speed: how much the road turns in the next ~50 m
	var h0 := track.headings[ts.prog]
	var h1 := track.headings[mini(ts.prog + 10, n - 1)]
	var dh := absf(wrapf(h1 - h0, -PI, PI))
	var vmax: float = car.top_speed
	var vt := lerpf(vmax, 42.0, clampf(dh / 1.0, 0.0, 1.0)) * ts.bot_skill
	if weather == "rain" or weather == "storm":
		vt *= 0.88
	elif weather == "fog" or weather == "night":
		vt *= 0.94
	if track.ice_at(mini(ts.prog + 6, n - 1)):
		vt = minf(vt, 55.0)
	if bump:
		vt = minf(vt, 62.0)
	var thr := 1.0 if spd < vt else 0.0
	var brk := clampf((spd - vt - 4.0) / 25.0, 0.0, 1.0)
	if ts.wrong:
		thr = 0.4
	# stuck on something: put the car back on the road
	if spd < 4.0 and race_time > 3.0:
		ts.stuck += delta
		if ts.stuck > 3.0:
			ts.stuck = 0.0
			ts.resets += 1
			_reset_team(ts)
	else:
		ts.stuck = 0.0
	return Vector3(steer, thr, brk)


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
		for sd in [-1.0, 1.0]:                                  # solid edge lines
			_edge_lines.append(Transform3D(basis * Basis.from_scale(Vector3(0.24, 0.02, seg * 1.06)), mid + left * sd * (W * 0.5 - 0.45) + basis.y * 0.041))
		if main and (i * 7919) % 11 == 0:                       # a repaired patch of tarmac
			var lat := float((i * 37) % 7 - 3) * 0.7
			_patches.append(Transform3D(basis * Basis.from_scale(Vector3(1.6 + float(i % 3) * 0.7, 0.02, 2.0 + float(i % 4))), mid + left * lat + basis.y * 0.038))
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
			var kb := Transform3D(flat * Basis.from_scale(Vector3(1.0, 0.05, Track.STEP * 1.2)), pos - left * side * 0.9 + Vector3(0, 0.72, 0))
			if i % 2 == 0:
				_kerb_a.append(kb)
			else:
				_kerb_b.append(kb)
			if main and i % 8 == 0 and (int(side) > 0) == ((i / 8) % 2 == 0):      # street lamps, alternating sides
				var lp: Vector3 = mid + left * side * (W * 0.5 + 3.7)
				_lamp_poles.append(Transform3D(flat * Basis.from_scale(Vector3(0.16, 5.4, 0.16)), lp + Vector3(0, 2.7, 0)))
				_lamp_poles.append(Transform3D(flat * Basis.from_scale(Vector3(1.7, 0.1, 0.1)), lp - left * side * 0.8 + Vector3(0, 5.35, 0)))
				_lamp_heads.append(Transform3D(flat * Basis.from_scale(Vector3(0.55, 0.12, 0.3)), lp - left * side * 1.55 + Vector3(0, 5.28, 0)))
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
	var road_m := Scenery.road_material(th["road"])
	if weather in ["rain", "storm"]:                         # wet asphalt: darker and shiny, it mirrors the sky
		road_m.albedo_color = (th["road"] as Color).darkened(0.25)
		road_m.roughness = 0.22
		road_m.metallic_specular = 0.9
	_multimesh(_unit_box(), road_m, road)
	_multimesh(_unit_box(), _mat(Color(0.95, 0.95, 0.95)), dashes)
	_multimesh(_unit_box(), _mat(Color(0.93, 0.93, 0.9)), _edge_lines)
	_multimesh(_unit_box(), _mat((th["road"] as Color).darkened(0.3)), _patches)
	_multimesh(_unit_box(), _mat(Color(0.85, 0.12, 0.1)), _kerb_a)
	_multimesh(_unit_box(), _mat(Color(0.95, 0.95, 0.95)), _kerb_b)
	_multimesh(_unit_box(), _mat(Color(0.3, 0.31, 0.34)), _lamp_poles)
	_multimesh(_unit_box(), Scenery.emissive(Color(1.0, 0.9, 0.65), 2.5), _lamp_heads)
	_build_corner_props()
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
	_build_tunnels()
	_build_trees()
	_build_mountains()


## tunnels: an arched tube around the road (with collision), light strips on the ceiling and a rock headwall at each mouth
func _build_tunnels() -> void:
	if track.tunnels.is_empty():
		return
	var W := Track.ROAD_WIDTH * 0.5 + 2.2
	var wall_h := 3.6
	var prof: Array[Vector2] = [Vector2(-W, -0.4), Vector2(-W, wall_h)]
	for k in range(1, 12):
		var a := PI - PI * k / 12.0
		prof.append(Vector2(cos(a) * W, wall_h + sin(a) * W * 0.66))
	prof.append(Vector2(W, wall_h))
	prof.append(Vector2(W, -0.4))
	var tube_mat := _mat(Color(0.3, 0.3, 0.33))
	tube_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp_mat.albedo_color = Color(1.0, 0.92, 0.7)
	var lamps: Array[Transform3D] = []
	var heads: Array[Transform3D] = []
	var body := StaticBody3D.new()
	add_child(body)
	for t in track.tunnels:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var f: int = t["from"]
		var e: int = t["to"]
		for i in range(f, e):
			var pa := track.points[i]
			var pb := track.points[i + 1]
			var la := Track.left_of(track.headings[i])
			var lb := Track.left_of(track.headings[i + 1])
			for q in prof.size() - 1:
				var a0 := pa + la * -prof[q].x + Vector3(0, prof[q].y, 0)
				var a1 := pa + la * -prof[q + 1].x + Vector3(0, prof[q + 1].y, 0)
				var b0 := pb + lb * -prof[q].x + Vector3(0, prof[q].y, 0)
				var b1 := pb + lb * -prof[q + 1].x + Vector3(0, prof[q + 1].y, 0)
				for v in [a0, a1, b1, a0, b1, b0]:
					st.add_vertex(v)
			if i % 2 == 0:
				for side in [-1.0, 1.0]:
					var lp: Vector3 = pa + la * side * W * 0.42 + Vector3(0, wall_h + W * 0.66 * 0.9, 0)
					var yaw: float = atan2(-(pb - pa).x, -(pb - pa).z)
					lamps.append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(0.5, 0.18, 1.6)), lp))
		st.generate_normals()
		var mesh := st.commit()
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = tube_mat
		add_child(mi)
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_trimesh_shape()
		body.add_child(cs)
		# rock headwalls over both mouths
		for idx in [f, e]:
			var yaw2 := track.headings[idx]
			var top: Vector3 = track.points[idx] + Vector3(0, wall_h + W * 0.66 + 4.0, 0)
			heads.append(Transform3D(Basis(Vector3.UP, yaw2) * Basis.from_scale(Vector3(W * 2.0 + 22.0, 9.0, 4.0)), top))
			for side in [-1.0, 1.0]:
				var le: Vector3 = Track.left_of(yaw2)
				heads.append(Transform3D(Basis(Vector3.UP, yaw2) * Basis.from_scale(Vector3(11.0, wall_h + 6.0, 4.0)), track.points[idx] + le * side * (W + 5.5) + Vector3(0, (wall_h + 6.0) * 0.5 - 0.4, 0)))
	_multimesh(_unit_box(), lamp_mat, lamps)
	_multimesh(_unit_box(), _mat(th.get("bank", Color(0.35, 0.34, 0.36))), heads)


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
	for i in range(4, n - 2, 1):
		if mountain and track.is_open(i):
			continue
		if track.in_tunnel(i):
			continue
		for side in [-1.0, 1.0]:
			if rng.randf() > (0.55 if mountain else 0.8) * Gfx.trees * float(th.get("tree_p", 1.0)):
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
			var s := rng.randf_range(0.8, 2.1)
			pos.y = track.points[i].y
			var b := Basis(Vector3.UP, rng.randf() * TAU)
			trunks.append(Transform3D(b * Basis.from_scale(Vector3(0.5, 2.0 * s, 0.5)), pos + Vector3(0, s, 0)))
			leaves1.append(Transform3D(b * Basis.from_scale(Vector3(3.2 * s, 2.0 * s, 3.2 * s)), pos + Vector3(0, 2.8 * s, 0)))
			leaves2.append(Transform3D(b * Basis.from_scale(Vector3(2.0 * s, 1.8 * s, 2.0 * s)), pos + Vector3(0, 4.5 * s, 0)))
	_multimesh(_unit_box(), _mat(th["trunk"]), trunks)
	_multimesh(_unit_box(), _mat(th["l1"]), leaves1)
	_multimesh(_unit_box(), _mat(th["l2"]), leaves2)
	_build_roadside_extras(rng, avoid, min_d2)


## bushes, rocks, grandstand, houses, parked cars, crowds, flags and birds
func _build_roadside_extras(rng: RandomNumberGenerator, avoid: PackedVector3Array, min_d2: float) -> void:
	var n := track.points.size()
	var mountain := track.theme == "mountain"
	var W := Track.ROAD_WIDTH
	var bushes: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	var houses: Array[Transform3D] = []
	var roofs: Array[Transform3D] = []
	var crowd_b: Array = [[], [], [], []]
	var heads: Array[Transform3D] = []
	var flag_poles: Array[Transform3D] = []
	for i in range(6, n - 6, 2):
		if track.in_tunnel(i) or (mountain and track.is_open(i)):
			continue
		var left := Track.left_of(track.headings[i])
		var flat := Basis(Vector3.UP, track.headings[i])
		for side in [-1.0, 1.0]:
			if rng.randf() < 0.55 * Gfx.trees:                       # bush
				var bp: Vector3 = track.points[i] + left * side * (W * 0.5 + 5.0 + rng.randf_range(0, 9))
				bp.y = track.points[i].y
				bushes.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(rng.randf_range(1.0, 2.2), rng.randf_range(0.7, 1.3), rng.randf_range(1.0, 2.2))), bp + Vector3(0, 0.4, 0)))
			if rng.randf() < 0.28 * Gfx.trees:                       # rock
				var rp: Vector3 = track.points[i] + left * side * (W * 0.5 + 5.5 + rng.randf_range(0, 18))
				rp.y = track.points[i].y
				var rs := rng.randf_range(0.8, 2.6)
				rocks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)) * Basis.from_scale(Vector3(rs * 1.3, rs, rs * 1.1)), rp + Vector3(0, rs * 0.35, 0)))
			if not mountain and i % 14 == 0 and rng.randf() < 0.6:     # small house with roof, well off the road
				var hp: Vector3 = track.points[i] + left * side * (W * 0.5 + 26.0 + rng.randf_range(0, 14))
				var clear := true
				for q in avoid:
					if (q.x - hp.x) * (q.x - hp.x) + (q.z - hp.z) * (q.z - hp.z) < 22.0 * 22.0:
						clear = false
						break
				if clear:
					hp.y = track.points[i].y
					var hs := Vector3(rng.randf_range(6, 10), rng.randf_range(4, 7), rng.randf_range(6, 9))
					var hb := Basis(Vector3.UP, rng.randf() * TAU)
					houses.append(Transform3D(hb * Basis.from_scale(hs), hp + Vector3(0, hs.y * 0.5, 0)))
					roofs.append(Transform3D(hb * Basis.from_scale(Vector3(hs.x * 1.1, 1.2, hs.z * 1.1)), hp + Vector3(0, hs.y + 0.6, 0)))
	# crowds + flags on the outside of every real bend, and at the start
	var last := -99
	for i in range(8, n - 10, 2):
		if i - last < 16 or track.in_tunnel(i) or track.is_open(i):
			continue
		var dh := wrapf(track.headings[mini(i + 6, n - 1)] - track.headings[i], -PI, PI)
		if absf(dh) < 0.32 and i > 14:
			continue
		last = i
		var side2 := -1.0 if dh > 0.0 else 1.0                       # outside of the bend
		for k in range(0, 8):
			var ti := mini(i + k, n - 2)
			var tl := Track.left_of(track.headings[ti])
			for row in 2:
				var cp: Vector3 = track.points[ti] + tl * side2 * (W * 0.5 + 6.0 + float(row) * 1.1 + rng.randf_range(-0.3, 0.3))
				cp.y = track.points[ti].y
				var ci := rng.randi() % 4
				var ch := rng.randf_range(0.85, 1.0)
				crowd_b[ci].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(0.5, ch, 0.4)), cp + Vector3(0, ch * 0.5 + float(row) * 0.25, 0)))
				heads.append(Transform3D(Basis.from_scale(Vector3(0.3, 0.3, 0.3)), cp + Vector3(0, ch + 0.15 + float(row) * 0.25, 0)))
		var fp: Vector3 = track.points[i] + Track.left_of(track.headings[i]) * side2 * (W * 0.5 + 5.0)
		fp.y = track.points[i].y
		flag_poles.append(Transform3D(Basis.from_scale(Vector3(0.12, 6.0, 0.12)), fp + Vector3(0, 3.0, 0)))
		if _wave_flags.size() < 14:
			var f := MeshInstance3D.new()
			var fm := BoxMesh.new()
			fm.size = Vector3(0.05, 1.0, 1.7)
			f.mesh = fm
			f.material_override = _mat([Color(0.9, 0.15, 0.12), Color(0.15, 0.4, 0.9), Color(0.95, 0.8, 0.1), Color(0.1, 0.7, 0.35)][_wave_flags.size() % 4])
			f.position = fp + Vector3(0, 5.4, 0)
			add_child(f)
			_wave_flags.append(f)
	_multimesh(_unit_box(), Scenery.plain((th["l1"] as Color).lerp(th["l2"], 0.5).darkened(0.1)), bushes)
	_multimesh(Scenery.peak_mesh(), Scenery.plain((th["mount"] as Color).darkened(0.25), 1.0, true), rocks)
	_multimesh(_unit_box(), _mat(Color(0.82, 0.78, 0.7)), houses)
	_multimesh(_unit_box(), _mat(Color(0.62, 0.22, 0.16)), roofs)
	var cols := [Color(0.9, 0.25, 0.2), Color(0.2, 0.45, 0.9), Color(0.95, 0.85, 0.2), Color(0.92, 0.92, 0.95)]
	for ci in 4:
		var arr: Array[Transform3D] = []
		arr.assign(crowd_b[ci])
		_multimesh(_unit_box(), _mat(cols[ci]), arr)
	_multimesh(_unit_box(), _mat(Color(0.9, 0.72, 0.58)), heads)
	_multimesh(_unit_box(), _mat(Color(0.8, 0.8, 0.82)), flag_poles)
	_make_grandstand()
	_make_birds(rng)


func _make_grandstand() -> void:
	var W := Track.ROAD_WIDTH
	var i := 12
	var h := track.headings[i]
	var left := Track.left_of(h)
	var flat := Basis(Vector3.UP, h)
	var base: Vector3 = track.points[i] + left * (W * 0.5 + 12.0)
	base.y = track.points[i].y
	var tiers: Array[Transform3D] = []
	var seats: Array[Transform3D] = []
	for t in 4:
		tiers.append(Transform3D(flat * Basis.from_scale(Vector3(5.0 + float(t) * 2.0, 1.0, 26.0)), base + left * float(t) * 2.0 + Vector3(0, 0.5 + float(t) * 1.0, 0)))
		seats.append(Transform3D(flat * Basis.from_scale(Vector3(1.4, 0.35, 24.0)), base - left * 1.0 + left * float(t) * 2.0 + Vector3(0, 1.2 + float(t) * 1.0, 0)))
	var roof: Array[Transform3D] = [Transform3D(flat * Basis.from_scale(Vector3(11.0, 0.3, 28.0)), base + left * 4.0 + Vector3(0, 7.0, 0))]
	var posts: Array[Transform3D] = []
	for z in [-12.0, 0.0, 12.0]:
		posts.append(Transform3D(flat * Basis.from_scale(Vector3(0.3, 7.0, 0.3)), base - left * 1.0 + flat * Vector3(0, 0, z) + Vector3(0, 3.5, 0)))
	_multimesh(_unit_box(), _mat(Color(0.55, 0.56, 0.6)), tiers)
	_multimesh(_unit_box(), _mat(Color(0.85, 0.2, 0.18)), seats)
	_multimesh(_unit_box(), _mat(Color(0.9, 0.9, 0.92)), roof)
	_multimesh(_unit_box(), _mat(Color(0.3, 0.3, 0.34)), posts)


func _make_birds(rng: RandomNumberGenerator) -> void:
	if weather in ["night", "storm", "fog"]:
		return
	var mid := track.points[track.points.size() / 2]
	for b in 7:
		var bird := Node3D.new()
		var bm := _mat(Color(0.12, 0.12, 0.14))
		for sd in [-1.0, 1.0]:
			var wing := MeshInstance3D.new()
			var m := BoxMesh.new()
			m.size = Vector3(1.4, 0.05, 0.4)
			wing.mesh = m
			wing.material_override = bm
			wing.position = Vector3(sd * 0.7, 0, 0)
			bird.add_child(wing)
		bird.set_meta("r", rng.randf_range(30.0, 160.0))
		bird.set_meta("a", rng.randf() * TAU)
		bird.set_meta("y", rng.randf_range(35.0, 80.0))
		bird.set_meta("sp", rng.randf_range(0.04, 0.1))
		bird.set_meta("c", mid)
		add_child(bird)
		_birds.append(bird)


## warning signs and tyre stacks before every real corner
func _build_corner_props() -> void:
	var n := track.points.size()
	var W := Track.ROAD_WIDTH
	var posts: Array[Transform3D] = []
	var boards: Array[Transform3D] = []
	var tyres: Array[Transform3D] = []
	var last := -99
	for i in range(8, n - 10, 3):
		if i - last < 14 or track.in_tunnel(i) or track.is_open(i):
			continue
		var dh := wrapf(track.headings[i + 6] - track.headings[i], -PI, PI)
		if absf(dh) < 0.32:
			continue
		last = i
		var h := track.headings[i]
		var left := Track.left_of(h)
		var flat := Basis(Vector3.UP, h)
		for side in [-1.0, 1.0]:
			var sp: Vector3 = track.points[i - 3] + left * side * (W * 0.5 + 4.4)
			posts.append(Transform3D(flat * Basis.from_scale(Vector3(0.1, 2.2, 0.1)), sp + Vector3(0, 1.1, 0)))
			boards.append(Transform3D(flat * Basis(Vector3.BACK, deg_to_rad(45.0)) * Basis.from_scale(Vector3(1.0, 1.0, 0.06)), sp + Vector3(0, 2.5, 0)))
		for k in range(0, 5):                                 # tyre stacks along the outside of the bend
			var ti := mini(i + k * 2, n - 2)
			var tleft := Track.left_of(track.headings[ti])
			for side2 in [-1.0, 1.0]:
				var tp: Vector3 = track.points[ti] + tleft * side2 * (W * 0.5 + 3.75)
				for lv in 3:
					tyres.append(Transform3D(Basis(Vector3.UP, float(k * 31 + lv * 17)), tp + Vector3(0, 0.18 + float(lv) * 0.33, 0)))
	_multimesh(_unit_box(), _mat(Color(0.5, 0.5, 0.52)), posts)
	_multimesh(_unit_box(), _mat(Color(1.0, 0.78, 0.1)), boards)
	_multimesh(Scenery.tire_mesh(), _mat(Color(0.06, 0.06, 0.07)), tyres)


## the horizon: two rings of low-poly peaks (the far one hazy), snow caps, slow clouds. All scaled to what the camera can see.
func _build_mountains() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Net.track_seed + 1
	var mid := track.points[track.points.size() / 2]
	var R := minf(Gfx.far_clip() * 0.82, 1900.0)
	var k := R / 1700.0
	var near_x: Array[Transform3D] = []
	var far_x: Array[Transform3D] = []
	var caps: Array[Transform3D] = []
	for i in 34:
		var a := TAU * float(i) / 34.0 + rng.randf_range(-0.07, 0.07)
		var far_ring := i % 2 == 0
		var dist := R * (rng.randf_range(0.95, 1.0) if far_ring else rng.randf_range(0.55, 0.7))
		var h := rng.randf_range(160.0, 330.0) * k * (1.25 if far_ring else 1.0)
		var w := rng.randf_range(300.0, 520.0) * k
		var pos := Vector3(mid.x + cos(a) * dist, track.floor_y, mid.z + sin(a) * dist)
		var bs := Basis(Vector3.UP, rng.randf() * TAU)
		var t := Transform3D(bs * Basis.from_scale(Vector3(w, h, w)), pos + Vector3(0, h * 0.5 - 6.0, 0))
		if far_ring:
			far_x.append(t)
		else:
			near_x.append(t)
		if h > 240.0 * k and not (track.theme in ["autumn", "desert", "beach"]):
			caps.append(Transform3D(bs * Basis.from_scale(Vector3(w * 0.3, h * 0.3, w * 0.3)), pos + Vector3(0, h * 0.85 - 6.0, 0)))
	var mc: Color = th["mount"]
	var hz: Color = th["hor"]
	_multimesh(Scenery.peak_mesh(), Scenery.plain(mc.lerp(hz, 0.4), 1.0, false), far_x)
	_multimesh(Scenery.peak_mesh(), Scenery.plain(mc.lerp(hz, 0.12), 1.0, false), near_x)
	_multimesh(Scenery.peak_mesh(), Scenery.plain(Color(0.96, 0.97, 1.0).lerp(hz, 0.25), 1.0, false), caps)
	# clouds: flat clumps that drift slowly around us
	if weather in ["night"]:
		return
	_cloud_root = Node3D.new()
	_cloud_root.position = Vector3(mid.x, track.floor_y, mid.z)
	add_child(_cloud_root)
	var cl: Array[Transform3D] = []
	var rain := weather in ["rain", "storm", "fog"]
	for i in (34 if rain else 24):
		var a2 := TAU * float(i) / 24.0 + rng.randf_range(-0.2, 0.2)
		var d2 := R * rng.randf_range(0.35, 0.9)
		var y2 := rng.randf_range(260.0, 430.0) * k
		for j in 3:
			var off := Vector3(rng.randf_range(-70, 70), rng.randf_range(-8, 8), rng.randf_range(-50, 50)) * k
			cl.append(Transform3D(Basis.from_scale(Vector3(rng.randf_range(90, 170), rng.randf_range(38, 64), rng.randf_range(60, 100)) * k), Vector3(cos(a2) * d2, y2, sin(a2) * d2) + off))
	var cmat := Scenery.plain(Color(1, 1, 1).lerp(hz, 0.15) if not rain else Color(0.62, 0.65, 0.7), 1.0, false)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Scenery.cloud_mesh()
	mm.instance_count = cl.size()
	for ci in cl.size():
		mm.set_instance_transform(ci, cl[ci])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = cmat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cloud_root.add_child(mi)


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
	if count > 4:
		lat = ((t % 3) - 1) * 3.2
		back = float(t / 3) * 5.5
	var left := Track.left_of(track.headings[i])
	var fwd := Track.forward(track.headings[i])
	var pos := track.points[i] + left * lat - fwd * back + Vector3(0, 0.8, 0)
	return Transform3D(Basis(Vector3.UP, track.headings[i]), pos)


func _build_teams() -> void:
	for t in Net.team_count:
		var ts := TeamState.new()
		ts.idx = t
		ts.color = TEAM_COLORS[t % TEAM_COLORS.size()]
		if Net.squads > 0:
			ts.color = TEAM_COLORS[t % Net.squads]
		for id in Net.roles:
			if Net.team_of.get(id, -1) == t:
				if Net.roles[id] == "driver":
					ts.driver_id = id
				else:
					ts.nav_id = id
		var car := Car.new()
		car.name = "Car%d" % t
		var lo: Dictionary = Net.loadouts.get(ts.driver_id, {})
		if Net.bots.has(t):
			var b: Dictionary = Net.bots[t]
			ts.bot = true
			ts.bot_name = str(b["name"])
			ts.bot_skill = float(b["skill"])
			ts.bot_lo = b["lo"]
			lo = ts.bot_lo
		car.setup(t, ts.color, not multiplayer.is_server(), lo)
		car.transform = _grid_transform(t)
		add_child(car)
		if (Net.blind and not solo) or weather in ["night", "storm"]:
			car.add_lights()
		ts.car = car
		car.wet = weather in ["rain", "storm"]
		if car.actions != null and weather in ["rain", "storm"]:
			car.actions.rain = 0.95 if weather == "storm" else 0.6
		if t == my_team and not Net.dedicated:
			car.enable_mirrors(my_role)
			car.bind_radio()
		car.set_plate_text(ts.bot_name if ts.bot else str(Net.players.get(ts.driver_id, char(65 + t))))
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
	av.outfit = (Net.loadouts.get(id, {}) as Dictionary).get("outfit", {})
	if av.is_local and ipad_vp:
		av.ipad_tex = ipad_vp.get_texture()
	var dash_wanted: bool = av.is_local and solo and role == "driver"
	av.position = ts.car.seat_origin(role)
	var mate := ts.nav_id if role == "driver" else ts.driver_id
	if mate != 0:
		av.seat_dx = ts.car.seat_origin(Net.roles[mate]).x - av.position.x
	ts.car.add_child(av)
	if dash_wanted:
		# solo / FFA: the map is a screen on the dashboard of your own car
		map_screen = MapScreen.new()
		map_screen.tex = ipad_vp.get_texture()
		map_screen.position = Vector3(0.12, 1.22, -0.95)
		map_screen.open_angle = -22.0
		map_screen.closed_angle = 88.0
		map_screen.near_offset = Vector3(-0.35, 0.12, 0.45)
		ts.car.add_child(map_screen)
	elif av.is_local and av.map_screen:
		map_screen = av.map_screen
		map_screen.set_open(true)
	avatars[id] = av
	if role == "driver":
		ts.car.driver_avatar = av
		if av.is_local and ts.car.actions != null and not ts.car.actions.changed.is_connected(_sig_hud):
			ts.car.actions.changed.connect(_sig_hud)
			ts.car.actions.net_event.connect(_cabin_net)
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
	p.add_theme_stylebox_override("panel", ZoneStyle.box(zone_name))
	var l := Label.new()
	l.text = text.split("\n")[0] if fs <= 16 else text
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(l, fs)
	p.add_child(l)
	ZoneStyle.decorate(p, zone_name, l, o_r - o_l, o_b - o_t)
	hud_root.add_child(p)
	zones[zone_name] = p
	if tap.is_valid():
		tap_zones[zone_name] = tap


func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	hud_root = Control.new()
	hud_root.layout_direction = Control.LAYOUT_DIRECTION_LTR      # the driving screen keeps one layout in every language (Arabic would mirror it)
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hud_root)
	flash_rect = ColorRect.new()
	flash_rect.color = Color(0.9, 0.1, 0.1, 0.0)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(flash_rect)

	speed_fx = ColorRect.new()                       # streaks at the screen edges at high speed (FxShaders.speed_lines)
	speed_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speed_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_fx.material = FxShaders.speed_lines()
	speed_fx.visible = Gfx.fx >= 0.5
	hud_root.add_child(speed_fx)
	grade_fx = ColorRect.new()
	grade_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grade_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grsh := Shader.new()
	grsh.code = GRADE_SHADER
	var grm := ShaderMaterial.new()
	grm.shader = grsh
	var gp := _grade_look()
	for k in gp:
		grm.set_shader_parameter(k, gp[k])
	grade_fx.material = grm
	grade_fx.visible = Gfx.fx >= 0.8 and not blind_mode
	hud_root.add_child(grade_fx)
	glow_fx = ColorRect.new()
	glow_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gsh := Shader.new()
	gsh.code = GLOW_SHADER
	var gm := ShaderMaterial.new()
	gm.shader = gsh
	glow_fx.material = gm
	glow_fx.visible = Gfx.fx >= 0.5
	hud_root.add_child(glow_fx)
	hud_root.move_child(glow_fx, 0)
	hud_root.move_child(grade_fx, 0)
	timer_label = _full_label(8, 56, 46)
	medal_label = _full_label(62, 34, 24)
	gesture_label = _full_label(100, 50, 34)
	center_label = _full_label(0, 160, 120, 0.2)
	msg_label = _full_label(0, 50, 28, 0.42)
	alert_label = _full_label(0, 60, 32, 0.55)
	alert_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	role_label = Label.new()
	role_label.position = Vector2(14, 8)
	var tname := (L.t("TEAMX") % char(65 + my_team)) + "  -  " if (Net.team_count > 1 and Net.bots.is_empty()) else ""
	role_label.text = tname + L.t("DRIVER" if my_role == "driver" else "CODRIVER")
	if Net.ffa:
		role_label.text = _tname(my_team)
		if Net.squads > 0:
			role_label.text = (L.t("TEAMX") % char(65 + my_team % Net.squads)) + "  -  " + role_label.text
	_style_label(role_label, 22)
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	role_label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	role_label.anchor_left = 0.0
	role_label.anchor_right = 0.0
	role_label.anchor_top = 0.0
	role_label.anchor_bottom = 0.0
	role_label.offset_left = 24.0
	role_label.offset_right = 364.0
	role_label.offset_top = 8.0
	role_label.offset_bottom = 38.0
	hud_root.add_child(role_label)
	speed_label = Label.new()
	speed_label.position = Vector2(14, 36)
	_style_label(speed_label, 22)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	speed_label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	speed_label.anchor_left = 0.0
	speed_label.anchor_right = 0.0
	speed_label.anchor_top = 0.0
	speed_label.anchor_bottom = 0.0
	speed_label.offset_left = 24.0
	speed_label.offset_right = 364.0
	speed_label.offset_top = 36.0
	speed_label.offset_bottom = 66.0
	hud_root.add_child(speed_label)
	rank_label = Label.new()
	rank_label.position = Vector2(14, 66)
	_style_label(rank_label, 20)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rank_label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	rank_label.anchor_left = 0.0
	rank_label.anchor_right = 0.0
	rank_label.anchor_top = 0.0
	rank_label.anchor_bottom = 0.0
	rank_label.offset_left = 24.0
	rank_label.offset_right = 364.0
	rank_label.offset_top = 66.0
	rank_label.offset_bottom = 96.0
	hud_root.add_child(rank_label)

	grace_label = _full_label(132, 40, 26)
	grace_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	skip_wait_btn = Button.new()
	skip_wait_btn.text = UI.tx("Skip", "تخطي")
	skip_wait_btn.add_theme_font_size_override("font_size", 22)
	for st in ["normal", "hover", "pressed", "focus"]:
		skip_wait_btn.add_theme_stylebox_override(st, UI.sb(Color(0, 0, 0, 0.6), 10, UI.ACCENT, 2))
	skip_wait_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	skip_wait_btn.offset_left = -70
	skip_wait_btn.offset_right = 70
	skip_wait_btn.offset_top = 176
	skip_wait_btn.offset_bottom = 226
	skip_wait_btn.visible = false
	skip_wait_btn.pressed.connect(func(): request_skip.rpc_id(1))
	hud_root.add_child(skip_wait_btn)
	repair_label = _full_label(0, 70, 26, 0.74)
	repair_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_make_zone("act", "", 0.5, 1.0, -105, -176, 105, -84, 22, _repair_action)
	_make_zone("spray", L.t("z_spray"), 0.5, 0.0, -105, 170, 105, 260, 22)
	zones["act"].visible = false
	zones["spray"].visible = false
	# right column (top): reset / emote / punch - never collides with the bottom controls
	_make_zone("reset", L.t("z_reset"), 1.0, 0.0, -150, 14, -14, 60, 20, _request_reset)
	_make_zone("emote", L.t("z_emote"), 1.0, 0.0, -150, 70, -14, 116, 20, _do_emote)
	if not solo:
		_make_zone("punch", L.t("z_punch"), 1.0, 0.0, -150, 126, -14, 172, 20, _do_punch)
	var sy := 126 if solo else 182
	_make_zone("stickers", UI.tx("STICKERS", "ملصقات"), 1.0, 0.0, -150, sy, -14, sy + 46, 20, _toggle_stickers)
	_make_zone("replay", UI.tx("REPLAY", "إعادة سينمائية"), 1.0, 0.0, -150, sy + 56, -14, sy + 102, 17, _play_replay)
	zones["replay"].visible = false
	_make_zone("photo", UI.tx("PHOTO", "صورة"), 1.0, 0.0, -150, sy + 112, -14, sy + 158, 20, _take_photo)
	if my_role == "driver":
		_make_zone("hudcfg", UI.tx("BUTTONS", "الأزرار"), 0.0, 0.0, 14, 94, 150, 136, 17, _open_hud_editor)
	_make_zone("menu", UI.tx("MENU", "القائمة"), 0.0, 0.0, 14, 144 if my_role == "driver" else 94, 150, 186 if my_role == "driver" else 136, 17, _open_pause_menu)
	# driver cabin controls (his own hand does them): big buttons in a 3x3 block above the steering buttons, left side
	if my_role == "driver":
		# page 1 = the six everyday buttons, page 2 = everything else (4 columns). Big, spaced buttons so a thumb hits them at speed.
		var items := [
			["c_sigl", UI.tx("SIGNAL", "إشارة"), "signal_left"], ["c_horn", UI.tx("HORN", "بوق"), "horn"], ["c_sigr", UI.tx("SIGNAL", "إشارة"), "signal_right"],
			["c_lights", UI.tx("LIGHTS", "إضاءة"), "lights"], ["c_wipers", UI.tx("WIPER", "مساحات"), "wipers"], ["c_more", UI.tx("MORE", "المزيد"), "@more"],
			["c_drink", UI.tx("DRINK", "اشرب"), "drink"], ["c_mirl", UI.tx("MIRROR L", "مرآة يسار"), "mirror_left"], ["c_mirr", UI.tx("MIRROR R", "مرآة يمين"), "mirror_right"], ["c_kind", UI.tx("JUICE", "عصير"), ""],
			["p2_haz", UI.tx("HAZARD", "طوارئ"), "hazard"], ["p2_flash", UI.tx("HIGH BEAM", "ضوء بعيد"), "flash"], ["p2_hb", UI.tx("HANDBRAKE", "فرامل يد"), "hbrake"],
			["p2_win", UI.tx("WINDOWS", "نوافذ"), "window"], ["p2_ac", UI.tx("A/C FAN", "مروحة"), "ac"], ["p2_dome", UI.tx("CABIN LIGHT", "إضاءة داخلية"), "dome"],
			["p2_greet", UI.tx("GREET", "تحية"), "greet"], ["p2_back", UI.tx("BACK", "رجوع"), "@back"]]
		for k in items.size():
			var col: int
			var row: int
			var y0: float
			if k < 6:
				col = k % 3
				row = k / 3
				y0 = -196.0 - (2 - row) * 84.0
			else:
				col = (k - 6) % 4
				row = (k - 6) / 4
				y0 = -196.0 - (3 - row) * 84.0
			var x0 := 14.0 + col * 132.0
			var cb: Callable
			match str(items[k][2]):
				"": cb = _toggle_drink
				"@more": cb = _cab_page.bind(2)
				"@back": cb = _cab_page.bind(1)
				_: cb = _cabin.bind(items[k][2])
			_make_zone(items[k][0], items[k][1], 0.0, 1.0, x0, y0, x0 + 124.0, y0 + 76.0, 20, cb)
			if k >= 6:
				zones[items[k][0]].visible = false
		cab_toast = Label.new()
		cab_toast.position = Vector2(14, 0)
		cab_toast.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		cab_toast.offset_left = 14
		cab_toast.offset_top = -196.0 - 3 * 84.0 - 36.0
		cab_toast.offset_right = 360
		cab_toast.offset_bottom = -196.0 - 3 * 84.0
		_style_label(cab_toast, 22)
		cab_toast.modulate.a = 0.0
		hud_root.add_child(cab_toast)
	# radio (bottom centre): < station >   (tap the name to switch it off / on)
	_make_zone("radio_prev", "", 0.5, 1.0, -160, -70, -98, -12, 26, _radio_step.bind(-1))
	_make_zone("radio_name", Radio.label(), 0.5, 1.0, -90, -70, 90, -12, 17, Radio.toggle)
	_make_zone("radio_next", "", 0.5, 1.0, 98, -70, 160, -12, 26, _radio_step.bind(1))
	Radio.changed.connect(_update_radio_hud)
	if show_touch:
		_apply_steer_mode()
		_make_zone("gas", "GAS", 1.0, 1.0, -170, -170, -20, -40)
		_make_zone("brake", "BRAKE", 1.0, 1.0, -340, -170, -190, -40)
	if my_role == "navigator" or solo:
		# gestures: bottom-left row (navigator only, no steering buttons there)
		if my_role == "navigator":
			var gy := -100.0
			_make_zone("g_left", L.t("z_left"), 0.0, 1.0, 20, gy, 112, gy + 70, 18, _set_gesture.bind(1))
			_make_zone("g_fwd", L.t("z_fwd"), 0.0, 1.0, 120, gy, 212, gy + 70, 18, _set_gesture.bind(2))
			_make_zone("g_right", L.t("z_right"), 0.0, 1.0, 220, gy, 312, gy + 70, 18, _set_gesture.bind(3))
			_make_zone("g_stop", L.t("z_stop"), 0.0, 1.0, 320, gy, 412, gy + 70, 18, _set_gesture.bind(4))
		# map / signal cluster: bottom-right (above GAS/BRAKE when touch driving)
		var cy := -234.0 if show_touch else -100.0
		var bw := 98.0 if show_touch else 110.0
		var n_btn := 3 if Net.ffa else 4
		var gap := 10.0
		var x := -20.0 - (bw * n_btn + gap * (n_btn - 1))
		var ch := 60.0 if show_touch else 70.0
		_make_zone("msize", UI.tx("SIZE", "الحجم"), 1.0, 1.0, x, cy, x + bw, cy + ch, 16, _map_size)
		x += bw + gap
		_make_zone("mnear", UI.tx("NEAR", "قرّب"), 1.0, 1.0, x, cy, x + bw, cy + ch, 16, _map_near)
		x += bw + gap
		_make_zone("map", L.t("z_map"), 1.0, 1.0, x, cy, x + bw, cy + ch, 16, _toggle_map)
		if not Net.ffa:
			x += bw + gap
			_make_zone("beacon", L.t("z_signal"), 1.0, 1.0, x, cy, x + bw, cy + ch, 16, _do_beacon)
		if ipad_vp == null:
			clipboard = Clipboard.new()
			clipboard.mouse_filter = Control.MOUSE_FILTER_IGNORE
			clipboard.my_color = teams[my_team].color
			clipboard.set_track(track)
			hud_root.add_child(clipboard)
	if my_role == "driver":
		_smart_repack()
	HudLayout.apply_world(zones)
	_flip_hud()
	get_tree().create_timer(1.0).timeout.connect(_show_hints)


func _my_actions() -> CarActions:
	if my_role != "driver" or teams.is_empty() or my_team >= teams.size():
		return null
	var c = teams[my_team].car
	if c == null or not is_instance_valid(c):
		return null
	return c.actions


var cab_toast: Label
var speed_fx: ColorRect
const GRADE_SHADER := """
shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, repeat_disable, filter_linear;
uniform vec3 tint = vec3(1.0);
uniform vec3 shadow_tint = vec3(0.0);
uniform float contrast = 1.1;
uniform float sat = 1.1;
uniform float vig = 0.3;
uniform float bloom = 0.6;
uniform float blur = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - vec2(0.5);
	vec3 c = texture(scr, uv).rgb;
	if (blur > 0.001) {
		vec3 acc = c;
		for (int i = 1; i < 5; i++) {
			acc += texture(scr, uv - d * blur * float(i) * 0.03).rgb;
		}
		c = mix(c, acc / 5.0, smoothstep(0.1, 0.5, length(d)));
	}
	vec3 b = texture(scr, uv + vec2(0.01, 0.0)).rgb + texture(scr, uv - vec2(0.01, 0.0)).rgb + texture(scr, uv + vec2(0.0, 0.015)).rgb + texture(scr, uv - vec2(0.0, 0.015)).rgb;
	b = max(b * 0.25 - vec3(0.72), vec3(0.0));
	c += b * bloom;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, sat);
	c = (c - 0.5) * contrast + 0.5;
	c = c * tint + shadow_tint * (1.0 - clamp(l, 0.0, 1.0)) * 0.08;
	float v = smoothstep(0.3, 0.85, length(d * vec2(1.0, 0.85)));
	c *= 1.0 - vig * v;
	COLOR = vec4(max(c, vec3(0.0)), 1.0);
}
"""
var grade_fx: ColorRect              # cinematic colour grade + bloom + speed blur + vignette (medium quality and up)
var glow_fx: ColorRect                  # coloured screen-edge glow: warm at speed, red when braking hard
var _glow_amt := 0.0
var _glow_col := Color(1.0, 0.55, 0.15)
var _brake_in := 0.0
const GLOW_SHADER := "shader_type canvas_item;\nuniform vec4 col : source_color = vec4(1.0, 0.5, 0.1, 1.0);\nuniform float amount = 0.0;\nvoid fragment() {\n\tvec2 d = (UV - 0.5) * vec2(1.25, 1.0);\n\tfloat e = smoothstep(0.32, 0.78, length(d));\n\tCOLOR = vec4(col.rgb, e * amount);\n}\n"


## cabin button block has two pages: 1 = everyday, 2 = the extras (hazard, high beam, handbrake, windows, fan, cabin light, greet)
## first race: small tips on the main buttons (tap anywhere to close)
## fixed place on the HUD, independent of the layout direction (anchors at the top-left, plain offsets)
func _place_abs(c: Control, r: Rect2) -> void:
	c.layout_direction = Control.LAYOUT_DIRECTION_LTR
	c.anchor_left = 0.0
	c.anchor_right = 0.0
	c.anchor_top = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = r.position.x
	c.offset_top = r.position.y
	c.offset_right = r.position.x + r.size.x
	c.offset_bottom = r.position.y + r.size.y


func _show_hints() -> void:
	if Gfx.hints_seen or not show_touch or my_role != "driver" or Net.dedicated or hud_root == null:
		return
	Gfx.hints_seen = true
	Gfx.save()
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.layout_direction = Control.LAYOUT_DIRECTION_LTR
	layer.z_index = 30
	hud_root.add_child(layer)
	var tips := [["gas", UI.tx("Gas", "بنزين"), 1], ["brake", UI.tx("Brake", "فرامل"), 1], ["left", UI.tx("Steer", "توجيه"), -1], ["c_horn", UI.tx("Horn", "بوق"), -1],
		["c_more", UI.tx("More buttons", "أزرار أكثر"), -1], ["menu", UI.tx("Menu + customise buttons", "القائمة + تخصيص الأزرار"), -1]]
	for t in tips:
		if not zones.has(t[0]) or not (zones[t[0]] as Control).visible:
			continue
		var z := zones[t[0]] as Control
		var P := hud_root.size
		var zc2 := Vector2(z.anchor_left * P.x + (z.offset_left + z.offset_right) * 0.5, z.anchor_top * P.y + (z.offset_top + z.offset_bottom) * 0.5)
		var zs := Vector2(z.offset_right - z.offset_left, z.offset_bottom - z.offset_top) * z.scale
		var r := Rect2(zc2 - zs * 0.5, zs)
		var ring := Panel.new()
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place_abs(ring, Rect2(r.position - Vector2(5, 5), r.size + Vector2(10, 10)))
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = Color(1.0, 0.75, 0.2, 0.12)
		rsb.border_color = Color(1.0, 0.75, 0.2)
		rsb.set_border_width_all(4)
		rsb.set_corner_radius_all(20)
		ring.add_theme_stylebox_override("panel", rsb)
		layer.add_child(ring)
		var tw := ring.create_tween().set_loops()
		tw.tween_property(ring, "modulate:a", 0.25, 0.6)
		tw.tween_property(ring, "modulate:a", 1.0, 0.6)
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", UI.sb(Color(0.04, 0.05, 0.08, 0.88), 16, Color(1.0, 0.75, 0.2), 2))
	var tx := Label.new()
	tx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tx.custom_minimum_size = Vector2(560, 0)
	tx.add_theme_font_size_override("font_size", 20)
	tx.text = UI.tx("Gas and brake: right side · Steering: left side · MORE: extra buttons · MENU: customise the buttons\nTap anywhere to close", "البنزين والفرامل على اليمين · التوجيه على اليسار · «المزيد» لأزرار أكثر · «القائمة» لتخصيص الأزرار\nالمس أي مكان للإغلاق")
	card.add_child(tx)
	layer.add_child(card)
	card.layout_direction = Control.LAYOUT_DIRECTION_LTR
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.0
	card.anchor_bottom = 0.0
	card.offset_left = -300.0
	card.offset_right = 300.0
	card.offset_top = 120.0
	card.offset_bottom = 120.0
	var cl := get_tree().create_timer(14.0)
	cl.timeout.connect(func():
		if is_instance_valid(layer):
			layer.queue_free())
	hint_layer = layer


## smart buttons: wipers only when it rains, lights only at night / fog / rain (unless the player moved them himself)
func _smart_off(id: String) -> bool:
	if not Gfx.smart_buttons or HudLayout.has_saved(id):
		return false
	match id:
		"c_wipers":
			return not (weather in ["rain", "storm"])
		"c_lights":
			return not (weather in ["night", "fog", "storm", "rain"])
	return false


## page 1 of the cabin block without the smart-hidden buttons, packed with no gaps
func _smart_repack() -> void:
	var ids := ["c_sigl", "c_horn", "c_sigr", "c_lights", "c_wipers", "c_more"]
	var vis: Array = []
	for id in ids:
		if zones.has(id) and not _smart_off(id) and not HudLayout.has_saved(id):
			vis.append(id)
	var rows := ceili(float(vis.size()) / 3.0)
	for i in vis.size():
		var zc := zones[vis[i]] as Control
		var x0 := 14.0 + (i % 3) * 132.0
		var y0 := -196.0 - (rows - i / 3) * 84.0
		zc.offset_left = x0
		zc.offset_right = x0 + 124.0
		zc.offset_top = y0
		zc.offset_bottom = y0 + 76.0


func _cab_page(n: int) -> void:
	for zn in zones:
		var z := str(zn)
		if _smart_off(z):
			(zones[zn] as Control).visible = false
			continue
		if not Controls.touch_wanted() and (z.begins_with("c_") or z.begins_with("p2_") or z == "hudcfg"):
			(zones[zn] as Control).visible = false         # gamepad connected: no touch buttons
			continue
		if HudLayout.is_removed(z):
			(zones[zn] as Control).visible = false
			continue
		if HudLayout.is_added(z):                 # the player put this one on the screen: always there, in his spot
			(zones[zn] as Control).visible = true
			continue
		if z.begins_with("p2_") or ["c_kind", "c_drink", "c_mirl", "c_mirr"].has(z):
			(zones[zn] as Control).visible = n == 2
		elif z.begins_with("c_"):
			(zones[zn] as Control).visible = n == 1


func _toast(text: String) -> void:
	if cab_toast == null:
		return
	cab_toast.text = text
	cab_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(cab_toast, "modulate:a", 0.0, 0.5)


func _cabin(what: String) -> void:
	var a := _my_actions()
	if a == null:
		return
	if a.is_busy():
		_toast(UI.tx("Wait...", "لحظة..."))
	a.do(what)


## the other players hear the horn and see lights / signals / wipers (relayed through the server)
func _cabin_net(what: String, val: int) -> void:
	if multiplayer.is_server():
		cabin_sync.rpc(my_team, what, val)
	else:
		send_cabin.rpc_id(1, what, val)


@rpc("any_peer", "reliable")
func send_cabin(what: String, val: int) -> void:
	if not multiplayer.is_server():
		return
	var s := multiplayer.get_remote_sender_id()
	for ts in teams:
		if ts.driver_id == s:
			cabin_sync.rpc(ts.idx, what, val)
			_cabin_apply(ts.idx, what, val)
			return


@rpc("authority", "call_remote", "reliable")
func cabin_sync(team: int, what: String, val: int) -> void:
	_cabin_apply(team, what, val)


func _cabin_apply(team: int, what: String, val: int) -> void:
	if team == my_team and my_role == "driver":
		return
	if team < 0 or team >= teams.size():
		return
	var c = teams[team].car
	if c != null and is_instance_valid(c) and c.actions != null:
		c.actions.remote(what, val)


func _sig_hud() -> void:
	var a := _my_actions()
	if a == null:
		return
	var st := [["c_sigl", a.signal_dir == -1], ["c_sigr", a.signal_dir == 1], ["c_lights", a.lights_on], ["c_wipers", a.wipers_on],
		["p2_haz", a.hazard], ["p2_hb", a.hb_on], ["p2_win", a.win_target > 0.5], ["p2_ac", a.fan_level > 0], ["p2_dome", a.dome_on]]
	for pair in st:
		if zones.has(pair[0]):
			(zones[pair[0]] as Panel).add_theme_stylebox_override("panel", ZoneStyle.box(str(pair[0]), bool(pair[1])))


func _toggle_drink() -> void:
	var a := _my_actions()
	if a == null:
		return
	a.toggle_drink()
	_toast(UI.tx("Energy drink", "مشروب طاقة") if a.drink_kind == "energy" else UI.tx("Juice", "عصير"))
	if zones.has("c_kind"):
		((zones["c_kind"] as Control).get_child(0) as Label).text = UI.tx("ENERGY", "طاقة") if a.drink_kind == "energy" else UI.tx("JUICE", "عصير")


func _radio_step(d: int) -> void:
	var a := _my_actions()
	if a and a.car.driver_avatar != null:
		a.do("radio_next" if d > 0 else "radio_prev")
	elif d > 0:
		Radio.next()
	else:
		Radio.prev()


func _update_radio_hud() -> void:
	if not zones.has("radio_name"):
		return
	var l := (zones["radio_name"] as Control).get_child(0) as Label
	l.text = Radio.label()
	l.modulate = Color.WHITE if Radio.on else Color(1, 1, 1, 0.55)


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
	ipad_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if Gfx.map_fps >= 60 else SubViewport.UPDATE_DISABLED
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


func _am_repairer() -> bool:
	var ts := teams[my_team]
	return ts.phase >= 2 and ts.phase <= 3 and ts.repairer == my_id


func _aimed_at_engine() -> bool:
	if local_avatar == null or local_avatar.cam == null:
		return false
	var car := teams[my_team].car
	var eng := car.global_transform * Vector3(0, 1.25, -1.7)
	var to := (eng - local_avatar.cam.global_position).normalized()
	return to.dot(-local_avatar.cam.global_basis.z) > 0.9


func _repair_action() -> void:
	var ts := teams[my_team]
	if state != State.RUNNING or ts.finished:
		return
	var act := ""
	match ts.phase:
		0:
			act = "lever"
		1:
			act = "exit"
		2:
			act = "lift" if ts.repairer == my_id else ""
		3:
			if ts.repairer == my_id:
				act = "cover" if (not ts.cover and ts.inner > 0.03) else "enter"
	if act == "":
		return
	if multiplayer.is_server():
		_server_repair(my_id, act)
	else:
		request_repair.rpc_id(1, act)


## smoke / fire warnings, context buttons for the fire repair and the spray input
func _update_repair_ui(delta: float) -> void:
	# countdown beeps
	if state == State.COUNTDOWN:
		var c := ceili(countdown_left)
		if c != last_count and c >= 1 and c <= 3:
			Sfx.play("beep")
		if countdown_left <= 0.0 and last_count != 0:
			Sfx.play("go")
			last_count = 0
		elif c != 0:
			last_count = c
	var my := teams[my_team]
	# animate the repairers' arms with the hood
	for ts in teams:
		if ts.phase >= 2 and ts.repairer != 0 and avatars.has(ts.repairer):
			var av: Avatar = avatars[ts.repairer]
			var ang := ts.car._hood_ang
			av.reach_t = clampf(ang / 62.0, 0.0, 1.0)
			av.work = 2 if ang > 55.0 else 1
			av.cover_hand = ts.cover
	# warnings
	if my.damage >= 80.0 and my.warned < 2:
		my.warned = 2
		Sfx.play("warn", 4.0)
	elif my.damage >= 40.0 and my.warned < 1:
		my.warned = 1
		Sfx.play("warn")
	elif my.damage < 30.0:
		my.warned = 0
	# prompts + buttons
	var text := ""
	var act_key := ""
	var rep := _am_repairer()
	var burning := my.fire > 0.03 or my.inner > 0.03
	match my.phase:
		0:
			if my.damage >= 40.0 and not my.finished and state == State.RUNNING:
				text = L.t("rp_fire") if my.damage >= 80.0 else L.t("rp_smoke")
				act_key = "z_lever"
		1:
			text = L.t("rp_latched")
			act_key = "z_exit"
		2:
			text = L.t("rp_lift") if rep else L.t("rp_wait")
			act_key = "z_lift" if rep else ""
		3:
			if not rep:
				text = L.t("rp_wait")
			elif not my.cover and my.inner > 0.03:
				text = L.t("rp_spray") if my.fire > 0.03 else L.t("rp_cover")
				act_key = "z_cover"
			elif burning:
				text = L.t("rp_spray")
			elif my.damage >= 25.0:
				text = L.t("rp_cool")
			else:
				text = L.t("rp_enter")
				act_key = "z_enter"
	repair_label.text = text
	repair_label.visible = text != "" and (my.phase > 0 or int(Time.get_ticks_msec() / 400.0) % 2 == 0)
	var act_zone: Control = zones["act"]
	act_zone.visible = act_key != ""
	if act_key != "":
		((act_zone.get_child(0)) as Label).text = L.t(act_key)
	zones["spray"].visible = rep and my.phase == 3
	# spray input (only the repairer)
	if rep and my.phase == 3:
		var want := Input.is_action_pressed("spray") or _zone_pressed("spray")
		var aim := _aimed_at_engine()
		var now := Time.get_ticks_msec()
		if want != spray_last or aim != spray_aim_last or (want and now - spray_ms > 250):
			spray_last = want
			spray_aim_last = aim
			spray_ms = now
			if multiplayer.is_server():
				_server_spray(my_id, want, aim)
			else:
				request_spray.rpc_id(1, want, aim)
	elif spray_last:
		spray_last = false


func _update_hud() -> void:
	var my := teams[my_team]
	if grace_show > 0.0 and state == State.RUNNING:
		grace_show -= get_process_delta_time()
		grace_label.text = UI.tx("Race ends in %d s", "السباق ينتهي بعد %d ث") % ceili(maxf(grace_show, 0.0))
	else:
		grace_label.text = ""
	if skip_wait_btn:
		skip_wait_btn.visible = grace_show > 0.0 and state == State.RUNNING and my.finished
	var shown_time := my.finish_time if my.finished else maxf(race_time, 0.0)
	timer_label.text = _fmt(shown_time)
	var spd := my.car.speed_kmh if multiplayer.is_server() else my.speed
	speed_label.text = "%d km/h" % int(spd)
	if state == State.RUNNING:
		if speed_fx != null and speed_fx.visible:
			(speed_fx.material as ShaderMaterial).set_shader_parameter("amount", smoothstep(130.0, 210.0, spd))
		_drive_shake = ((0.012 * clampf(spd / 200.0, 0.0, 1.0) if (_brake_in > 0.5 and spd > 60.0) else 0.0) + 0.003 * smoothstep(150.0, 220.0, spd)) * Gfx.fx
		if grade_fx != null and grade_fx.visible:
			(grade_fx.material as ShaderMaterial).set_shader_parameter("blur", smoothstep(120.0, 230.0, spd) * 0.9)
		_fov_kick = lerpf(_fov_kick, 11.0 * smoothstep(60.0, 220.0, spd) * Gfx.fx, 0.06)
		if glow_fx != null and glow_fx.visible:
			var hard := _brake_in > 0.5 and spd > 40.0
			var want_a := 0.5 if hard else smoothstep(110.0, 210.0, spd) * 0.4
			var want_c := Color(1.0, 0.15, 0.1) if hard else Color(1.0, 0.55, 0.15)
			_glow_amt = lerpf(_glow_amt, want_a, 0.12)
			_glow_col = _glow_col.lerp(want_c, 0.2)
			var gmat := glow_fx.material as ShaderMaterial
			gmat.set_shader_parameter("amount", _glow_amt)
			gmat.set_shader_parameter("col", _glow_col)
		Score.drive(spd, my.car != null and is_instance_valid(my.car) and my.car.damage >= 80.0)
	var shown := false
	for m in MEDALS:
		if shown_time <= m[1]:
			medal_label.text = "%s  %s" % [L.t(m[0]), _fmt(m[1])]
			medal_label.add_theme_color_override("font_color", m[2])
			shown = true
			break
	if not shown:
		medal_label.text = L.t("NOMEDAL")
		medal_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	match state:
		State.WAITING:
			center_label.text = ""
			msg_label.text = L.t("loading") + ".".repeat(int(Time.get_ticks_msec() / 400.0) % 4)
			msg_timer = 0.1
		State.COUNTDOWN:
			center_label.text = str(ceili(countdown_left)) if countdown_left > 0.0 else L.t("go")
			msg_label.text = L.t("stage") % [track.stage_name.to_upper(), L.t("th_" + track.theme)]
			msg_timer = 0.1
		State.RUNNING:
			center_label.text = L.t("go") if race_time < 1.0 else ""
		State.ENDED:
			center_label.text = ""
	# standings
	if teams.size() > 1:
		var sorted := teams.duplicate()
		sorted.sort_custom(_ahead)
		var lines: Array[String] = []
		for i in sorted.size():
			var ts: TeamState = sorted[i]
			var tag: String = _place(i) + "  " + _tname(ts.idx)
			if ts.dnf:
				tag += "  (%s)" % L.t("out")
			elif ts.finished:
				tag += "  " + _fmt(ts.finish_time)
			lines.append(("> " if ts.idx == my_team else "   ") + tag)
		rank_label.text = "\n".join(lines)
	# what the co-driver is signalling (the driver must notice it!)
	var g := my_gesture if solo else mate_gesture
	if (my_role == "driver" or solo) and g > 0 and not blind_mode:
		gesture_label.text = L.t("g%d" % g)
		var blink := g != 4 or int(Time.get_ticks_msec() / 200.0) % 2 == 0
		gesture_label.add_theme_color_override("font_color", Color(1, 0.3, 0.25) if g == 4 else Color(1, 0.9, 0.3))
		gesture_label.visible = blink
	else:
		gesture_label.visible = false
	# alerts about the closed side roads
	alert_label.text = ""
	if state == State.RUNNING and my.wrong and not my.finished:
		if my_role == "driver" and spd < 4.0 and not blind_mode:
			alert_label.text = L.t("dead_end")
		elif my_role == "navigator":
			alert_label.text = L.t("driver_closed")
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
		lines.append("%s   %s   %s" % [_place(i), _tname(ts.idx), _fmt(ts.finish_time)])
	for ts in teams:
		if not ts.finished:
			lines.append("-      %s   %s" % [_tname(ts.idx), L.t("out") if ts.dnf else L.t("racing")])
	return "\n".join(lines)


func _refresh_result() -> void:
	if result_standings:
		result_standings.text = _standings_text()


func _show_result(place: int, t: float) -> void:
	Score.finish(place == 1)
	var medal := L.t("no_medal")
	var mi := -1
	for i in MEDALS.size():
		if t <= MEDALS[i][1]:
			medal = L.t(MEDALS[i][0])
			mi = i
			break
	var rw := Profile.race_reward(place, Net.team_count, mi, track.theme == "mountain")
	_career_apply(place, rw)
	_rewarded = true
	my_reward_line = _reward_line(rw)
	my_coins = int(rw["coins"])
	var solo_room := Net.required_players <= 1
	var card := ResultCard.new()
	card.build(str(place) if Net.team_count > 1 else "", track.stage_name, _fmt(t), mi, medal, rw, Profile.level, Net.team_count > 1, solo_room,
		func():
			if solo_room:
				Net.start_now()
			else:
				Net.return_to_room(true),
		func():
			if solo_room:
				Net.return_to_menu()
			else:
				Net.return_to_room(false))
	result_panel = card
	result_standings = card.standings
	rematch_btn = card.again_btn
	room_btn = card.exit_btn
	if Net.team_count > 1:
		_refresh_result()
	_update_result_buttons()
	hud_root.add_child(result_panel)


## career: stars, unlock, extra coins / gems / chest of the stage
func _career_apply(place: int, rw: Dictionary) -> void:
	var ci := int(Net.solo_cfg.get("career", -1))
	if ci < 0:
		return
	var cr := Profile.career_result(ci, place)
	rw["coins"] = int(rw["coins"]) + int(cr["coins"])
	var lv := Career.level(ci)
	var t := ""
	if cr["passed"]:
		t = UI.tx("STAGE %d CLEARED  -  %d/3 stars", "المرحلة %d اكتملت  -  %d/3 نجوم") % [ci + 1, int(cr["stars"])]
		if int(cr["gems"]) > 0:
			t += "    +%d %s" % [int(cr["gems"]), UI.tx("gems", "جواهر")]
		if str(cr["chest"]) != "":
			t += "    +1 " + UI.tx("chest", "صندوق")
		if ci < Career.COUNT - 1 and bool(cr["first"]):
			t += "    " + UI.tx("Next stage unlocked", "فُتحت المرحلة التالية")
	else:
		t = UI.tx("Finish top %d to pass stage %d", "أنهِ ضمن أول %d لتجتاز المرحلة %d") % [int(lv["need"]), ci + 1]
	rw["career"] = t


func _reward_line(rw: Dictionary) -> String:
	var s := "+%d %s    +%d XP" % [int(rw["coins"]), UI.tx("coins", "عملة"), int(rw["xp"])]
	if rw.has("career"):
		s += "\n" + str(rw["career"])
	if rw["chest"] != "":
		s += "    +1 " + UI.tx("chest", "صندوق")
	if rw["level_up"]:
		s += "    " + UI.tx("LEVEL UP!  Level %d", "ارتقيت! المستوى %d") % Profile.level
	return s


## team race: points per place, summed per team (best individual place breaks a tie)
func _squad_rows() -> Array:
	var rows: Array = []
	if Net.squads <= 0:
		return rows
	var pts := {}
	var best := {}
	var names := {}
	for i in final_order.size():
		var ts := teams[final_order[i]]
		var sq: int = ts.idx % Net.squads
		pts[sq] = int(pts.get(sq, 0)) + int(PTS[mini(i, PTS.size() - 1)])
		if not best.has(sq):
			best[sq] = i
		if not names.has(sq):
			names[sq] = []
		(names[sq] as Array).append(_tname(ts.idx))
	for sq in pts:
		rows.append({"name": L.t("TEAMX") % char(65 + sq), "pts": pts[sq], "color": TEAM_COLORS[sq % TEAM_COLORS.size()], "best": best[sq], "members": names[sq]})
	rows.sort_custom(func(a, b):
		if a["pts"] != b["pts"]:
			return a["pts"] > b["pts"]
		return a["best"] < b["best"])
	return rows


func _start_ceremony() -> void:
	if ceremony != null or not is_inside_tree() or final_order.is_empty():
		return
	if result_panel and is_instance_valid(result_panel):
		result_panel.queue_free()
	result_panel = null
	rematch_btn = null
	room_btn = null
	hud.visible = false
	Radio.duck(true)
	var entries: Array = []
	for i in final_order.size():
		var ts := teams[final_order[i]]
		var plist: Array = []
		for id in [ts.driver_id, ts.nav_id]:
			if id != 0:
				plist.append({"name": str(Net.players.get(id, "?")), "outfit": (Net.loadouts.get(id, {}) as Dictionary).get("outfit", {}), "role": Net.roles.get(id, "driver")})
		entries.append({
			"rank": i + 1, "name": _tname(ts.idx), "plate": ts.bot_name if ts.bot else str(Net.players.get(ts.driver_id, char(65 + ts.idx))),
			"players": plist, "lo": ts.bot_lo if ts.bot else Net.loadouts.get(ts.driver_id, {}), "time": ts.finish_time, "fin": ts.finished, "dnf": ts.dnf,
			"pct": int(final_pcts[ts.idx]) if ts.idx < final_pcts.size() else 0, "color": ts.color, "place": _place(i), "mine": ts.idx == my_team})
	var solo_room := Net.required_players <= 1
	var c := Ceremony.new()
	c.entries = entries
	c.squad_rows = _squad_rows()
	c.info_line = my_reward_line
	c.double_coins = my_coins
	c.stage_name = track.stage_name
	c.again_text = UI.tx("Race again", "سباق جديد") if solo_room else UI.tx("Rematch", "إعادة المباراة")
	c.exit_text = UI.tx("Main menu", "القائمة الرئيسية") if solo_room else UI.tx("Back to room", "الرجوع للغرفة")
	c.on_again = func():
		if solo_room:
			Net.start_now()
		else:
			Net.return_to_room(true)
	c.on_exit = func():
		if solo_room:
			Net.return_to_menu()
		else:
			Net.return_to_room(false)
	c.position = Vector3(0, 1800, 0)
	ceremony = c
	add_child(c)


## the host runs the physics: he may only leave when everybody has finished
func _update_result_buttons() -> void:
	if rematch_btn == null:
		return
	var wait := multiplayer.is_server() and state != State.ENDED and Net.required_players > 1
	rematch_btn.disabled = wait
	room_btn.disabled = wait
	if wait:
		rematch_btn.text = UI.tx("Waiting for the others...", "ننتظر باقي اللاعبين...")


func _can_pause() -> bool:
	return Net.players.size() == 1 and not Net.ffa and not Net.dedicated and Net.required_players <= 1


func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false
	Gfx.racing = false
	Radio.stop_race()
	if Radio.changed.is_connected(_update_radio_hud):
		Radio.changed.disconnect(_update_radio_hud)
