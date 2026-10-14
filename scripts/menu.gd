extends Control
## Main menu + lobby. Host a LAN game, pick how many players are needed, or join one.
## The race starts automatically when the lobby is full.

var name_edit: LineEdit
var team_opt: OptionButton
var ip_edit: LineEdit
var status: Label
var hosts_box: VBoxContainer
var main_panel: VBoxContainer
var lobby_panel: VBoxContainer
var lobby_list: Label
var lobby_status: Label
var lobby_ips: Label


var blind_check: CheckBox


func _ready() -> void:
	_build_ui()
	Net.players_changed.connect(_refresh_lobby)
	Net.hosts_changed.connect(_refresh_hosts)
	Net.joined.connect(_show_lobby)
	Net.join_failed.connect(_on_join_failed)
	Net.lobby_closed.connect(_on_lobby_closed)
	Net.start_browsing()
	if Net.pending_message != "":
		status.text = Net.pending_message
		Net.pending_message = ""


func _exit_tree() -> void:
	Net.stop_browsing()


func _label(parent: Node, text: String, fs: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	scroll.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	margin.add_child(vb)

	var title := _label(vb, "CO-DRIVER RALLY", 48, Color(1.0, 0.82, 0.25))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label(vb, "LAN co-op: one drives, the other reads the map and pace notes.", 20, Color(0.8, 0.85, 0.95))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	main_panel = VBoxContainer.new()
	main_panel.add_theme_constant_override("separation", 12)
	vb.add_child(main_panel)
	_label(main_panel, "Your name", 20)
	name_edit = LineEdit.new()
	name_edit.text = "Player%d" % (randi() % 900 + 100)
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(0, 56)
	name_edit.add_theme_font_size_override("font_size", 24)
	main_panel.add_child(name_edit)
	blind_check = CheckBox.new()
	blind_check.text = "Blind driver mode (driver sees almost nothing - co-driver guides)"
	blind_check.button_pressed = true
	blind_check.add_theme_font_size_override("font_size", 20)
	main_panel.add_child(blind_check)
	_button(main_panel, "HOST CO-OP  (1 car, 2 players)", func(): _host(1))
	main_panel.add_child(HSeparator.new())
	_label(main_panel, "TEAM RACE: every team = 1 car, 2 players (driver + map holder)", 20, Color(1.0, 0.82, 0.25))
	team_opt = OptionButton.new()
	team_opt.custom_minimum_size = Vector2(0, 56)
	team_opt.add_theme_font_size_override("font_size", 24)
	for n in range(2, 5):
		team_opt.add_item("%d teams  (%d players)" % [n, n * 2], n)
	main_panel.add_child(team_opt)
	_button(main_panel, "HOST TEAM RACE", func(): _host(team_opt.get_selected_id()))
	_button(main_panel, "Solo practice", _on_solo)
	main_panel.add_child(HSeparator.new())
	_label(main_panel, "Games found on your Wi-Fi / LAN", 20)
	hosts_box = VBoxContainer.new()
	hosts_box.add_theme_constant_override("separation", 8)
	main_panel.add_child(hosts_box)
	_label(main_panel, "...or type the host's IP", 20)
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "192.168.1.10"
	ip_edit.custom_minimum_size = Vector2(0, 56)
	ip_edit.add_theme_font_size_override("font_size", 24)
	main_panel.add_child(ip_edit)
	_button(main_panel, "JOIN", func(): _join(ip_edit.text))

	lobby_panel = VBoxContainer.new()
	lobby_panel.add_theme_constant_override("separation", 14)
	lobby_panel.visible = false
	vb.add_child(lobby_panel)
	_label(lobby_panel, "LOBBY", 36, Color(1.0, 0.82, 0.25))
	lobby_status = _label(lobby_panel, "", 26)
	lobby_list = _label(lobby_panel, "", 24)
	lobby_ips = _label(lobby_panel, "", 20, Color(0.7, 0.9, 1.0))
	_button(lobby_panel, "Cancel", _on_cancel)

	status = _label(vb, "", 20, Color(1.0, 0.6, 0.5))
	_refresh_hosts()


# ------------------------------------------------------------------ actions

func _my_name() -> String:
	var n := name_edit.text.strip_edges()
	return n if n != "" else "Player"


func _host(teams: int) -> void:
	var err := Net.host_game(_my_name(), teams, blind_check.button_pressed)
	if err != OK:
		status.text = "Could not host (port %d busy?)" % Net.PORT
		return
	_show_lobby()


func _on_solo() -> void:
	var err := Net.host_game(_my_name(), 0, false)
	if err != OK:
		status.text = "Could not start (port %d busy?)" % Net.PORT
		return
	_show_lobby()


func _join(ip: String) -> void:
	if ip.strip_edges() == "":
		status.text = "Enter the host IP first"
		return
	status.text = "Connecting..."
	var err := Net.join_game(ip, _my_name())
	if err != OK:
		status.text = "Invalid address"


func _on_cancel() -> void:
	Net.leave()
	_show_main()


func _on_join_failed() -> void:
	status.text = "Could not connect"
	_show_main()


func _on_lobby_closed(reason: String) -> void:
	status.text = reason
	_show_main()


func _show_main() -> void:
	main_panel.visible = true
	lobby_panel.visible = false


func _show_lobby() -> void:
	status.text = ""
	main_panel.visible = false
	lobby_panel.visible = true
	_refresh_lobby()


func _refresh_lobby() -> void:
	if not lobby_panel.visible:
		return
	var count := Net.players.size()
	if count >= Net.required_players:
		lobby_status.text = "Lobby full - starting..."
	else:
		lobby_status.text = "Waiting for players  %d / %d" % [count, Net.required_players]
	lobby_list.text = "\n".join(Net.lobby_lines())
	if Net.is_hosting:
		lobby_ips.text = "Tell your friend to join:\n" + "\n".join(Net.local_ips())
	else:
		lobby_ips.text = ""


func _refresh_hosts() -> void:
	if hosts_box == null:
		return
	for c in hosts_box.get_children():
		c.queue_free()
	if Net.found_hosts.is_empty():
		_label(hosts_box, "(none found yet)", 18, Color(0.6, 0.65, 0.75))
		return
	for ip in Net.found_hosts:
		var h: Dictionary = Net.found_hosts[ip]
		var text := "%s   %d/%d   (%s)" % [h["name"], h["count"], h["required"], ip]
		_button(hosts_box, text, _join.bind(ip))
