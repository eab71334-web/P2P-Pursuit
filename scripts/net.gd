extends Node
## Autoload "Net": LAN networking (ENet), LAN discovery (UDP broadcast) and lobby logic.
## The game starts automatically when the number of connected players reaches `required_players`.

const PORT := 24565
const DISCOVERY_PORT := 24566
const MAX_PLAYERS := 8
const MENU_SCENE := "res://scenes/main.tscn"
const WORLD_SCENE := "res://scenes/world.tscn"

signal players_changed
signal hosts_changed
signal joined
signal join_failed
signal lobby_closed(reason: String)
signal peer_left(id: int)

var player_name := "Player"
var required_players := 2
var players := {}   # peer_id -> name
var roles := {}     # peer_id -> "driver" | "navigator"
var team_of := {}   # peer_id -> team index (0..3)
var team_count := 1
var track_seed := 0
var stage := {}        # stage description made by the offline stage director
var ffa := false       # every player has his own car + map (2-6 players)
var blind := true      # driver can hardly see (co-driver must guide)
var in_game := false
var race_over := false
var is_hosting := false
var pending_message := ""
var found_hosts := {}   # ip -> {name, count, required, time}
var loadouts := {}      # peer -> cosmetic / car loadout (see Profile.loadout)
var rdy := {}         # peer -> pressed READY in the room
var present := {}       # peer -> is looking at the room screen right now
var lobby_cd := -1.0    # >= 0 : the start countdown is running
var enter_ready := false   # set before going back to the room (rematch)
var in_room := false       # the menu should open the room screen directly
var _cd_shown := -1

var _bcast := PacketPeerUDP.new()
var _listen := PacketPeerUDP.new()
var _listening := false
var _bcast_timer := 0.0
var _starting := false


func _ready() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	_setup_inputs()
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _setup_inputs() -> void:
	var map := {
		"steer_left": [KEY_A, KEY_LEFT],
		"steer_right": [KEY_D, KEY_RIGHT],
		"accel": [KEY_W, KEY_UP],
		"brake": [KEY_S, KEY_DOWN],
		"reset": [KEY_R],
		"punch": [KEY_F, KEY_SPACE],
		"g_left": [KEY_1],
		"g_fwd": [KEY_2],
		"g_right": [KEY_3],
		"g_stop": [KEY_4],
		"beacon": [KEY_G],
		"interact": [KEY_E],
		"spray": [KEY_Q],
		"map_toggle": [KEY_M],
		"look_mate": [KEY_V],
		"emote": [KEY_T],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in map[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)


# ---------------------------------------------------------------- hosting / joining

## teams = 0 -> solo practice, 1 -> co-op (one car, 2 players), 2..4 -> team race (2 players per team)
func host_game(p_name: String, teams: int, p_blind := true, p_ffa := 0) -> int:
	leave()
	ffa = p_ffa >= 2
	player_name = p_name
	blind = p_blind and teams > 0
	if ffa:
		team_count = clampi(p_ffa, 2, 6)
		required_players = team_count
		blind = false
	elif teams <= 0:
		team_count = 1
		required_players = 1
	else:
		team_count = clampi(teams, 1, 4)
		required_players = team_count * 2
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_hosting = true
	players = {1: player_name}
	loadouts = {1: Profile.loadout()}
	rdy = {1: false}
	present = {1: true}
	lobby_cd = -1.0
	in_room = true
	_bcast.set_broadcast_enabled(true)
	_bcast.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	players_changed.emit()
	_check_full()
	return OK


## Text lines for the lobby: teams are filled in join order (driver first, then the map holder).
func lobby_lines() -> Array[String]:
	var out: Array[String] = []
	var ids: Array = players.keys()
	for i in ids.size():
		var team := i if ffa else ((i >> 1) if required_players > 1 else 0)
		var role := L.t("role_solo") if ffa else (L.t("role_driver") if i % 2 == 0 else L.t("role_nav"))
		out.append("%s %s  -  %s  (%s)%s" % [L.t("team"), char(65 + team), players[ids[i]], role, "  [%s]" % L.t("host_tag") if ids[i] == 1 else ""])
	return out


## rows for the room screen
func lobby_rows() -> Array:
	var out: Array = []
	var ids: Array = players.keys()
	for i in ids.size():
		var id: int = ids[i]
		var team := i if ffa else ((i >> 1) if required_players > 1 else 0)
		var role := L.t("role_solo") if ffa else (L.t("role_driver") if i % 2 == 0 else L.t("role_nav"))
		var lo: Dictionary = loadouts.get(id, {})
		var cid: String = lo.get("car", "hatch")
		out.append({"id": id, "name": players[id], "team": team, "role": role, "host": id == 1, "ready": rdy.get(id, false),
			"present": present.get(id, false), "car": Catalog.nm(Catalog.CARS.get(cid, Catalog.CARS["hatch"])), "lo": lo})
	return out


func join_game(ip: String, p_name: String) -> int:
	leave()
	player_name = p_name
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip.strip_edges(), PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func leave() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer:
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	loadouts.clear()
	rdy.clear()
	present.clear()
	lobby_cd = -1.0
	in_room = false
	enter_ready = false
	roles.clear()
	team_of.clear()
	in_game = false
	race_over = false
	is_hosting = false
	_starting = false
	_bcast.close()


func local_ips() -> Array[String]:
	var out: Array[String] = []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return out


# ---------------------------------------------------------------- LAN discovery

func start_browsing() -> void:
	if _listening:
		return
	found_hosts.clear()
	if _listen.bind(DISCOVERY_PORT) == OK:
		_listening = true


func stop_browsing() -> void:
	_listen.close()
	_listening = false


func _all_ready() -> bool:
	if players.size() < required_players or required_players < 2:
		return false
	for id in players:
		if not rdy.get(id, false) or not present.get(id, false):
			return false
	return true


func _process(delta: float) -> void:
	if is_hosting and multiplayer.is_server() and not _starting and in_room:
		if _all_ready():
			if lobby_cd < 0.0:
				lobby_cd = 5.0
				_cd_shown = 5
				_broadcast_players()
			else:
				lobby_cd -= delta
				var whole := ceili(lobby_cd)
				if whole != _cd_shown:
					_cd_shown = whole
					_broadcast_players()
				if lobby_cd <= 0.0:
					lobby_cd = -1.0
					start_now()
		elif lobby_cd >= 0.0:
			lobby_cd = -1.0
			_broadcast_players()
	if is_hosting and not in_game:
		_bcast_timer -= delta
		if _bcast_timer <= 0.0:
			_bcast_timer = 1.0
			var msg := "RALLY|%s|%d|%d" % [player_name, players.size(), required_players]
			_bcast.put_packet(msg.to_utf8_buffer())
	if _listening:
		var changed := false
		while _listen.get_available_packet_count() > 0:
			var text := _listen.get_packet().get_string_from_utf8()
			var ip := _listen.get_packet_ip()
			var parts := text.split("|")
			if parts.size() == 4 and parts[0] == "RALLY":
				found_hosts[ip] = {"name": parts[1], "count": int(parts[2]), "required": int(parts[3]), "time": Time.get_ticks_msec()}
				changed = true
		var now := Time.get_ticks_msec()
		for ip in found_hosts.keys():
			if now - int(found_hosts[ip]["time"]) > 4000:
				found_hosts.erase(ip)
				changed = true
		if changed:
			hosts_changed.emit()


# ---------------------------------------------------------------- lobby (server side)

@rpc("any_peer", "reliable")
func register(p_name: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if in_game or players.size() >= required_players:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	players[id] = p_name.substr(0, 16)
	rdy[id] = false
	present[id] = true
	loadouts[id] = {}
	_broadcast_players()
	_check_full()


@rpc("any_peer", "reliable")
func set_ready(v: bool) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id) and present.get(id, false):
		rdy[id] = v
		_broadcast_players()


@rpc("any_peer", "reliable")
func set_loadout(lo: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		loadouts[id] = lo
		rdy[id] = false
		_broadcast_players()


@rpc("any_peer", "reliable")
func room_enter(want_ready: bool) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		present[id] = true
		rdy[id] = want_ready
		_broadcast_players()


## local player: update my loadout in the room (also leaves READY)
func push_loadout() -> void:
	var lo := Profile.loadout()
	loadouts[multiplayer.get_unique_id()] = lo
	if multiplayer.is_server():
		rdy[1] = false
		_broadcast_players()
	else:
		set_loadout.rpc_id(1, lo)


func enter_room(want_ready: bool) -> void:
	if multiplayer.is_server():
		present[1] = true
		rdy[1] = want_ready
		_broadcast_players()
	else:
		room_enter.rpc_id(1, want_ready)


func toggle_ready(v: bool) -> void:
	if multiplayer.is_server():
		rdy[1] = v
		_broadcast_players()
	else:
		set_ready.rpc_id(1, v)


func _broadcast_players() -> void:
	sync_players.rpc(players, required_players, team_count, ffa, rdy, present, lobby_cd, loadouts)
	players_changed.emit()


@rpc("authority", "call_remote", "reliable")
func sync_players(p: Dictionary, req: int, teams: int, p_ffa: bool, p_ready: Dictionary, p_present: Dictionary, cd: float, p_lo: Dictionary) -> void:
	ffa = p_ffa
	rdy = p_ready
	present = p_present
	lobby_cd = cd
	loadouts = p_lo
	players = p
	required_players = req
	team_count = teams
	players_changed.emit()


## Called whenever someone joins: when the lobby is full the game starts by itself.
func _check_full() -> void:
	if not multiplayer.is_server() or in_game or _starting:
		return
	if players.size() < required_players or required_players > 1:
		return
	_starting = true
	await get_tree().create_timer(0.4).timeout
	if not is_hosting or players.size() < required_players:
		_starting = false
		return
	start_now()


## server: start a race with the people who are in the room (or a rematch of a solo race)
func start_now() -> void:
	if not multiplayer.is_server():
		return
	_starting = true
	for id in players:
		rdy[id] = false
	var ids: Array = players.keys()   # join order: host first
	var r := {}
	var tm := {}
	for i in ids.size():
		r[ids[i]] = "driver" if (ffa or i % 2 == 0) else "navigator"
		tm[ids[i]] = i if ffa else ((i >> 1) if required_players > 1 else 0)
	begin.rpc(Track.design_stage(randi()), r, tm, players, team_count, blind, ffa, loadouts)


@rpc("authority", "call_local", "reliable")
func begin(p_stage: Dictionary, p_roles: Dictionary, p_teams: Dictionary, p_players: Dictionary, p_team_count: int, p_blind: bool, p_ffa: bool, p_lo: Dictionary) -> void:
	loadouts = p_lo
	lobby_cd = -1.0
	present.clear()
	in_room = false
	ffa = p_ffa
	stage = p_stage
	track_seed = int(p_stage.get("seed", 1))
	blind = p_blind
	roles = p_roles
	team_of = p_teams
	team_count = p_team_count
	players = p_players
	in_game = true
	race_over = false
	_starting = false
	_bcast.close()
	get_tree().change_scene_to_file(WORLD_SCENE)


@rpc("authority", "call_local", "reliable")
func abort(reason: String) -> void:
	pending_message = reason
	call_deferred("return_to_menu")


## after a race: back to the room (the lobby stays open). rematch = already READY
func return_to_room(want_ready := false) -> void:
	if players.size() <= 1 and required_players <= 1:
		return_to_menu()
		return
	in_game = false
	race_over = false
	in_room = true
	enter_ready = want_ready
	get_tree().change_scene_to_file(MENU_SCENE)


func return_to_menu() -> void:
	leave()
	get_tree().change_scene_to_file(MENU_SCENE)


# ---------------------------------------------------------------- connection events

func _on_connected() -> void:
	register.rpc_id(1, player_name)
	set_loadout.rpc_id(1, Profile.loadout())
	in_room = true
	joined.emit()


func _on_connection_failed() -> void:
	leave()
	join_failed.emit()


func _on_server_disconnected() -> void:
	var was_in_game := in_game
	leave()
	if was_in_game:
		pending_message = "The host left the game"
		get_tree().change_scene_to_file(MENU_SCENE)
	else:
		lobby_closed.emit("Disconnected (lobby full, game started, or host left)")


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	players.erase(id)
	rdy.erase(id)
	present.erase(id)
	loadouts.erase(id)
	if in_game:
		peer_left.emit(id)
	if lobby_cd >= 0.0:
		lobby_cd = -1.0
	_broadcast_players()
