extends Control
## Main menu: sidebar hub (play / garage / workshop / ...) with a 3D showroom behind the PLAY page,
## game setup screen and the room (ready check + 5 s countdown).

const SLOT_COLORS := [Color(0.9, 0.22, 0.2), Color(0.25, 0.5, 0.95), Color(0.25, 0.75, 0.4), Color(0.95, 0.75, 0.15), Color(0.7, 0.4, 0.9), Color(0.2, 0.8, 0.85)]


# ====================================================================== small drawn widgets

class Backdrop extends Control:
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		for i in 20:
			var f := float(i) / 20.0
			draw_rect(Rect2(0, h * f, w, h / 20.0 + 1), Color(0.035, 0.04, 0.052).lerp(Color(0.085, 0.09, 0.11), f))
		# slow diagonal light streaks
		for k in 7:
			var x := fposmod(k * w / 6.0 + t * (14.0 + k * 3.0), w + 400.0) - 200.0
			var a := 0.035 + 0.02 * sin(t * 0.7 + k)
			draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 26, 0), Vector2(x - 220, h), Vector2(x - 246, h)]), Color(1.0, 0.47, 0.1, a))


class ModeIcon extends Control:
	var kind := "solo"
	var hot := false

	func _init(k := "solo") -> void:
		kind = k
		custom_minimum_size = Vector2(70, 56)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _car(p: Vector2, col: Color) -> void:
		draw_rect(Rect2(p.x - 16, p.y - 4, 32, 10), col)
		draw_rect(Rect2(p.x - 9, p.y - 11, 18, 8), col)
		draw_circle(p + Vector2(-9, 7), 3.2, Color(0.04, 0.045, 0.06))
		draw_circle(p + Vector2(9, 7), 3.2, Color(0.04, 0.045, 0.06))

	func _draw() -> void:
		var c := size * 0.5
		var col := UI.ACCENT if hot else UI.TXT
		match kind:
			"solo":
				_car(c, col)
			"coop":
				_car(c + Vector2(0, 5), col)
				draw_circle(c + Vector2(-5, -6), 3.5, col)
				draw_circle(c + Vector2(5, -6), 3.5, col)
			"teams":
				_car(c + Vector2(-6, -9), col)
				_car(c + Vector2(6, 11), col.darkened(0.3))
			"ffa":
				_car(c + Vector2(-8, -14), col)
				_car(c + Vector2(4, 0), col.darkened(0.2))
				_car(c + Vector2(-4, 14), col.darkened(0.4))


## one game mode in the PLAY list
class ModeRow extends Button:
	var micon: ModeIcon

	func _init(k: String, title: String, desc: String, cb: Callable) -> void:
		custom_minimum_size = Vector2(0, 78)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n := UI.sb(Color(0.075, 0.08, 0.1, 0.9), 8, UI.LINE, 1)
		var hv := UI.sb(Color(0.13, 0.12, 0.12, 0.95), 8, UI.ACCENT, 2)
		add_theme_stylebox_override("normal", n)
		add_theme_stylebox_override("hover", hv)
		add_theme_stylebox_override("pressed", hv)
		add_theme_stylebox_override("focus", n)
		pressed.connect(cb)
		var h := HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 10
		h.offset_right = -14
		h.add_theme_constant_override("separation", 10)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(h)
		micon = ModeIcon.new(k)
		h.add_child(micon)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 1)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(v)
		UI.lbl(v, title, 22, UI.TXT, false)
		UI.lbl(v, desc, 14, UI.TXT2, false)
		mouse_entered.connect(func():
			micon.hot = true
			micon.queue_redraw())
		mouse_exited.connect(func():
			micon.hot = false
			micon.queue_redraw())


class Spinner extends Control:
	var t := 0.0

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		draw_arc(c, 30.0, 0.0, TAU, 40, Color(1, 1, 1, 0.1), 5.0)
		draw_arc(c, 30.0, t * 4.0, t * 4.0 + 1.6, 20, UI.ACCENT, 5.0)


# ====================================================================== state

var root_box: Control
var panels := {}
var current := "main"
var ip_edit: LineEdit
var status: Label
var _status_tw: Tween
var hosts_box: VBoxContainer
var blind_check: CheckBox
var setup_mode := ""
var setup_count := 2
var setup_per := 2
var per_row: HBoxContainer
var count_row: HBoxContainer
var setup_title: Label
var setup_blind_row: Control
var lobby_title: Label
var lobby_sub: Label
var lobby_slots: GridContainer
var lobby_ips: Label
var lobby_bar: ProgressBar
var shown_slots := 0
var cd_label: Label
var ready_btn: Button
var confirm_box: Control
var room_hub: Hub
var hub: Hub
var hero: Preview3D
var hero_name: Label
var _hero_key := ""
var _last_cd := -1
var _t := 0.0
var _backdrop: Backdrop


func _ready() -> void:
	Net.players_changed.connect(_refresh_lobby)
	Net.hosts_changed.connect(_refresh_hosts)
	Net.joined.connect(_show_lobby)
	Net.join_failed.connect(_on_join_failed)
	Net.lobby_closed.connect(_on_lobby_closed)
	L.changed.connect(_on_lang)
	Profile.changed.connect(_refresh_hero)
	Net.start_browsing()
	_backdrop = Backdrop.new()
	add_child(_backdrop)
	status = UI.lbl(null, "", 22, Color.WHITE, false)
	status.add_theme_stylebox_override("normal", UI.sb(Color(0, 0, 0, 0.9), 8, UI.ACCENT, 1))
	status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	status.grow_horizontal = Control.GROW_DIRECTION_BOTH
	status.position.y = 14
	status.z_index = 60
	status.modulate.a = 0.0
	add_child(status)
	if Net.in_room and not Net.players.is_empty():      # back from a race: the room stays open
		current = "lobby"
		Net.enter_room(Net.enter_ready)
		Net.enter_ready = false
	_build_ui()
	if Net.pending_message != "":
		_say(Net.pending_message)
		Net.pending_message = ""


func _exit_tree() -> void:
	Net.stop_browsing()


func _say(text: String) -> void:
	if status == null or not is_instance_valid(status):
		return
	status.text = "  " + text + "  "
	if _status_tw:
		_status_tw.kill()
	_status_tw = status.create_tween()
	_status_tw.tween_property(status, "modulate:a", 1.0, 0.15)
	_status_tw.tween_interval(3.2)
	_status_tw.tween_property(status, "modulate:a", 0.0, 0.4)


func _on_lang() -> void:
	# deferred: never rebuild the UI from inside a button callback of the old UI
	_build_ui.call_deferred()


func _process(d: float) -> void:
	_t += d
	if current == "lobby" and lobby_title and is_instance_valid(lobby_title):
		_update_lobby_texts()
		_update_countdown()
		if lobby_bar:
			var target := 100.0 * Net.players.size() / maxf(1.0, Net.required_players)
			lobby_bar.value = lerpf(lobby_bar.value, target, clampf(d * 6.0, 0.0, 1.0))


# ====================================================================== UI

func _build_ui() -> void:
	if root_box and is_instance_valid(root_box):
		root_box.free()
	hub = null
	hero = null
	room_hub = null
	confirm_box = null
	panels.clear()
	layout_direction = Control.LAYOUT_DIRECTION_RTL if L.is_ar() else Control.LAYOUT_DIRECTION_LTR
	var mc := MarginContainer.new()
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, 12)
	add_child(mc)
	root_box = mc
	var stack := Control.new()
	mc.add_child(stack)
	hub = Hub.new()
	hub.tab_ids = ["play", "garage", "workshop", "character", "shop", "quests", "chests", "settings"]
	hub.play_content = _build_main()
	panels["main"] = hub
	panels["setup"] = _build_setup()
	panels["lobby"] = _build_lobby()
	if current == "lobby" and not Net.is_hosting and Net.players.is_empty():
		current = "main"
	if current == "room_garage" or not panels.has(current):
		current = "lobby" if Net.in_room and not Net.players.is_empty() else "main"
	for k in panels:
		var p: Control = panels[k]
		stack.add_child(p)
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		p.visible = (k == current)
	_refresh_hosts()
	_refresh_lobby()
	var root_p: Control = panels[current]
	root_p.modulate.a = 0.0
	root_p.create_tween().tween_property(root_p, "modulate:a", 1.0, 0.3)


func _build_main() -> Control:
	var c := Control.new()
	hero = Preview3D.new()
	hero.hero = true
	hero.custom_minimum_size = Vector2(10, 10)
	hero.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(hero)
	hero.ready.connect(func():
		hero.show_car(Profile.loadout())
		_hero_key = JSON.stringify(Profile.loadout()))
	hero.tree_entered.connect(_refresh_hero.call_deferred)
	_hero_key = ""
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(h)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(470, 0)
	col.add_theme_constant_override("separation", 8)
	h.add_child(col)
	var cap := UI.lbl(col, UI.tx("SELECT MODE", "اختر نمط اللعب"), 16, UI.ACCENT, false)
	cap.add_theme_constant_override("outline_size", 0)
	var specs := [
		["solo", "solo", "solo_d", func(): _on_solo()],
		["coop", "coop", "coop_d", func(): _open_setup("coop")],
		["teams", "teams", "teams_d", func(): _open_setup("teams")],
		["ffa", "ffa", "ffa_d", func(): _open_setup("ffa")],
	]
	for i in specs.size():
		var r := ModeRow.new(specs[i][0], L.t(specs[i][1]), L.t(specs[i][2]), specs[i][3])
		col.add_child(r)
		r.modulate.a = 0.0
		r.create_tween().tween_interval(0.07 * i)
		r.create_tween().tween_property(r, "modulate:a", 1.0, 0.35).set_delay(0.07 * i)
	# LAN strip
	var join := UI.panel(col, UI.PANEL, 8)
	var jv := VBoxContainer.new()
	jv.add_theme_constant_override("separation", 6)
	join.add_child(jv)
	var jt := HBoxContainer.new()
	jv.add_child(jt)
	var ttl := UI.lbl(jt, L.t("games_found") + "  (LAN)", 16, UI.TXT, false)
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hosts_box = VBoxContainer.new()
	hosts_box.add_theme_constant_override("separation", 4)
	jv.add_child(hosts_box)
	var rr := HBoxContainer.new()
	rr.add_theme_constant_override("separation", 8)
	jv.add_child(rr)
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = L.t("ip_hint") + "  192.168.1.10"
	ip_edit.custom_minimum_size = Vector2(0, 44)
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_edit.add_theme_font_size_override("font_size", 18)
	ip_edit.add_theme_stylebox_override("normal", UI.sb(Color(1, 1, 1, 0.06), 6, UI.LINE, 1))
	ip_edit.add_theme_stylebox_override("focus", UI.sb(Color(1, 1, 1, 0.1), 6, UI.ACCENT, 1))
	rr.add_child(ip_edit)
	UI.btn(rr, L.t("join_btn"), UI.ACCENT, func(): _join(ip_edit.text), 20, Vector2(110, 44))
	# spacer + car info (the 3D car is behind everything)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(sp)
	var info := VBoxContainer.new()
	info.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info.alignment = BoxContainer.ALIGNMENT_END
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp.add_child(info)
	hero_name = UI.lbl(info, "", 26, UI.TXT, false)
	hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cb := UI.btn(null, UI.tx("CUSTOMIZE", "تخصيص"), UI.CARD2, func(): hub.select("garage"), 18, Vector2(220, 44))
	cb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	info.add_child(cb)
	_update_hero_name()
	return c


func _update_hero_name() -> void:
	if hero_name and is_instance_valid(hero_name):
		var m: Dictionary = Catalog.CARS[Profile.car]
		hero_name.text = Catalog.nm(m)
		hero_name.add_theme_color_override("font_color", (Catalog.RARITY_COLOR[int(m["r"])] as Color).lightened(0.2))


func _refresh_hero() -> void:
	if hero == null or not is_instance_valid(hero) or hero.vp == null:
		return
	if not hero.is_inside_tree() or not hero.is_visible_in_tree():
		_hero_key = ""        # hidden (another hub tab): refresh when it comes back, no wasted rebuilds
		return
	var key := JSON.stringify(Profile.loadout())
	if key != _hero_key:
		_hero_key = key
		hero.show_car(Profile.loadout())
		_update_hero_name()


func _build_setup() -> Control:
	var wrap := CenterContainer.new()
	var p := UI.panel(null, UI.PANEL, 12)
	p.custom_minimum_size = Vector2(720, 0)
	wrap.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	p.add_child(vb)
	setup_title = UI.lbl(vb, "", 34, UI.TXT, false)
	setup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var q := UI.lbl(vb, L.t("choose"), 18, UI.TXT2, false)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_row = HBoxContainer.new()
	count_row.alignment = BoxContainer.ALIGNMENT_CENTER
	count_row.add_theme_constant_override("separation", 12)
	vb.add_child(count_row)
	per_row = HBoxContainer.new()
	per_row.alignment = BoxContainer.ALIGNMENT_CENTER
	per_row.add_theme_constant_override("separation", 12)
	vb.add_child(per_row)
	var bl := VBoxContainer.new()
	vb.add_child(bl)
	setup_blind_row = bl
	blind_check = CheckBox.new()
	blind_check.text = L.t("blind") + "  -  " + L.t("blind_d")
	blind_check.button_pressed = true
	blind_check.add_theme_font_size_override("font_size", 19)
	bl.add_child(blind_check)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	UI.btn(row, L.t("back"), UI.CARD2, func(): _go("main"), 22, Vector2(170, 56))
	var go := UI.btn(row, L.t("start_host"), UI.ACCENT, _on_create, 24, Vector2(0, 56))
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return wrap


func _count_buttons(parent: Control, lo: int, hi: int, cur: int, cb: Callable) -> void:
	var group := ButtonGroup.new()
	for n in range(lo, hi + 1):
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(88, 80)
		b.text = str(n)
		b.add_theme_font_size_override("font_size", 38)
		b.add_theme_stylebox_override("normal", UI.sb(UI.CARD2, 8, UI.LINE, 1))
		b.add_theme_stylebox_override("hover", UI.sb(UI.CARD2.lightened(0.1), 8, UI.LINE, 1))
		b.add_theme_stylebox_override("pressed", UI.sb(UI.ACCENT, 8))
		b.add_theme_stylebox_override("hover_pressed", UI.sb(UI.ACCENT, 8))
		b.add_theme_color_override("font_pressed_color", Color.BLACK)
		b.add_theme_color_override("font_hover_pressed_color", Color.BLACK)
		b.button_pressed = (n == cur)
		b.pressed.connect(func(): cb.call(n))
		parent.add_child(b)


func _open_setup(mode: String) -> void:
	setup_mode = mode
	for c in count_row.get_children():
		c.queue_free()
	for c in per_row.get_children():
		c.queue_free()
	per_row.visible = false
	setup_title.text = L.t(mode)
	setup_blind_row.visible = mode == "coop"
	if mode == "coop":
		setup_count = 1
		var l := UI.lbl(count_row, L.t("coop_d"), 22, UI.TXT, false)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(600, 80)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	elif mode == "teams":
		# 2-4 teams, every player drives his own car; the team score is the sum of the members' points
		setup_count = 2
		setup_per = 2
		per_row.visible = true
		_fill_team_rows()
	else:
		setup_count = 2
		_count_buttons(count_row, 2, 6, 2, func(n): setup_count = n)
	_go("setup")


## teams: 2..4 ; players per team: 1..(8 / teams)
func _fill_team_rows() -> void:
	for c in count_row.get_children():
		c.queue_free()
	for c in per_row.get_children():
		c.queue_free()
	var q := UI.lbl(count_row, L.t("teams_q") + "   ", 20, UI.TXT2, false)
	q.custom_minimum_size = Vector2(0, 80)
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_buttons(count_row, 2, 4, setup_count, func(n):
		setup_count = n
		setup_per = mini(setup_per, 8 / n)
		_fill_team_rows.call_deferred())
	var q2 := UI.lbl(per_row, L.t("per_team_q") + "   ", 20, UI.TXT2, false)
	q2.custom_minimum_size = Vector2(0, 80)
	q2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_buttons(per_row, 1, 8 / setup_count if setup_count > 1 else 2, setup_per, func(n): setup_per = n)


func _build_lobby() -> Control:
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 12)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 16)
	vb.add_child(top)
	var sp := Spinner.new()
	sp.custom_minimum_size = Vector2(70, 70)
	top.add_child(sp)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	top.add_child(tv)
	lobby_title = UI.lbl(tv, "", 32, UI.TXT, false)
	lobby_title.custom_minimum_size = Vector2(560, 0)
	lobby_sub = UI.lbl(tv, "", 17, UI.TXT2, false)
	cd_label = UI.lbl(vb, "", 92, UI.ACCENT, false)
	cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_label.custom_minimum_size = Vector2(0, 104)
	cd_label.pivot_offset = Vector2(640, 52)
	lobby_bar = ProgressBar.new()
	lobby_bar.custom_minimum_size = Vector2(0, 6)
	lobby_bar.show_percentage = false
	var lf := UI.sb(UI.ACCENT, 3)
	var lb := UI.sb(Color(1, 1, 1, 0.1), 3)
	for sbx in [lf, lb]:
		sbx.content_margin_top = 0
		sbx.content_margin_bottom = 0
	lobby_bar.add_theme_stylebox_override("fill", lf)
	lobby_bar.add_theme_stylebox_override("background", lb)
	vb.add_child(lobby_bar)
	lobby_slots = GridContainer.new()
	lobby_slots.columns = 3
	lobby_slots.add_theme_constant_override("h_separation", 12)
	lobby_slots.add_theme_constant_override("v_separation", 10)
	var cc := CenterContainer.new()
	cc.add_child(lobby_slots)
	vb.add_child(cc)
	lobby_ips = UI.lbl(vb, "", 18, UI.TXT2, false)
	lobby_ips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	vb.add_child(row)
	UI.btn(row, UI.tx("< Back", "< رجوع"), UI.CARD2, _ask_leave, 22, Vector2(170, 58))
	UI.btn(row, UI.tx("GARAGE / WORKSHOP", "الكراج / الورشة"), UI.CARD2, _open_room_garage, 22, Vector2(310, 58))
	ready_btn = UI.btn(row, UI.tx("READY", "جاهز"), UI.ACCENT, _toggle_ready, 26, Vector2(300, 58))
	shown_slots = 0
	return vb


func _toggle_ready() -> void:
	var me := multiplayer.get_unique_id()
	var now: bool = not Net.rdy.get(me, false)
	Net.toggle_ready(now)
	Sfx.play("click")
	_refresh_lobby()
	_update_countdown()


func _open_room_garage() -> void:
	Net.toggle_ready(false)
	if room_hub and is_instance_valid(room_hub):
		room_hub.queue_free()
	room_hub = Hub.new()
	room_hub.in_room = true
	room_hub.tab_ids = ["garage", "workshop", "character", "shop", "settings"]
	room_hub.closed.connect(_close_room_garage)
	var stack: Control = panels["lobby"].get_parent()
	stack.add_child(room_hub)
	panels["room_garage"] = room_hub
	panels["lobby"].visible = false
	current = "room_garage"
	room_hub.modulate.a = 0.0
	room_hub.create_tween().tween_property(room_hub, "modulate:a", 1.0, 0.25)


func _close_room_garage() -> void:
	Net.push_loadout()
	if room_hub and is_instance_valid(room_hub):
		room_hub.queue_free()
	panels.erase("room_garage")
	room_hub = null
	current = "lobby"
	panels["lobby"].visible = true
	_refresh_lobby()


## "are you sure you want to leave the room?"
func _ask_leave() -> void:
	if confirm_box and is_instance_valid(confirm_box):
		return
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.z_index = 50
	add_child(dim)
	confirm_box = dim
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cc)
	var p := UI.panel(null, UI.PANEL, 12)
	p.custom_minimum_size = Vector2(600, 0)
	cc.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	p.add_child(vb)
	var t := UI.lbl(vb, UI.tx("Are you sure you want to leave the room?", "هل أنت متأكد أنك تريد الخروج من الغرفة؟"), 28, UI.TXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if Net.is_hosting and Net.players.size() > 1:
		var w := UI.lbl(vb, UI.tx("You are the host: the room will close for everyone.", "أنت صاحب الغرفة: الغرفة بتتقفل على الكل."), 17, Color(1.0, 0.65, 0.5))
		w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	var no := UI.btn(row, UI.tx("Stay", "ابقَ"), UI.CARD2, func(): dim.queue_free(), 22, Vector2(0, 58))
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var yes := UI.btn(row, UI.tx("Confirm", "تأكيد"), UI.RED, func():
		dim.queue_free()
		_on_cancel(), 22, Vector2(0, 58))
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dim.modulate.a = 0.0
	dim.create_tween().tween_property(dim, "modulate:a", 1.0, 0.15)


func _update_lobby_texts() -> void:
	var req := maxi(1, Net.required_players)
	var full := Net.players.size() >= req
	var me := multiplayer.get_unique_id()
	var mine: bool = Net.rdy.get(me, false)
	var n_ready := 0
	for id in Net.players:
		if Net.rdy.get(id, false):
			n_ready += 1
	if not full:
		lobby_title.text = L.t("waiting") + ".".repeat(int(_t * 2.5) % 4)
		lobby_sub.text = UI.tx("%d / %d players   -   you can press READY now", "%d / %d لاعبين   -   تقدر تضغط جاهز من الحين") % [Net.players.size(), req]
	elif Net.lobby_cd >= 0.0:
		lobby_title.text = UI.tx("Everyone is ready!", "الكل جاهز!")
		lobby_sub.text = UI.tx("Race starts in...", "السباق يبدأ بعد...")
	elif mine:
		lobby_title.text = UI.tx("You are READY", "أنت جاهز")
		lobby_sub.text = UI.tx("Waiting for the others...  (%d / %d ready)", "بانتظار الباقين...  (%d / %d جاهزين)") % [n_ready, req]
	else:
		lobby_title.text = UI.tx("Get ready", "استعد")
		lobby_sub.text = UI.tx("Customize in the garage, then press READY  (%d / %d ready)", "غيّر شكلك في الكراج ثم اضغط جاهز  (%d / %d جاهزين)") % [n_ready, req]


func _update_countdown() -> void:
	if cd_label == null or not is_instance_valid(cd_label):
		return
	var n := ceili(Net.lobby_cd) if Net.lobby_cd >= 0.0 else -1
	if n != _last_cd:
		_last_cd = n
		cd_label.text = str(n) if n > 0 else ""
		if n > 0:
			Sfx.play("beep", 0.0, 1.0 + (5 - n) * 0.05)
			cd_label.scale = Vector2(1.6, 1.6)
			cd_label.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(cd_label, "scale", Vector2.ONE, 0.35)
	if ready_btn and is_instance_valid(ready_btn):
		var me := multiplayer.get_unique_id()
		var is_r: bool = Net.rdy.get(me, false)
		ready_btn.text = (UI.tx("READY  -  tap to cancel", "جاهز  -  اضغط للإلغاء")) if is_r else UI.tx("READY", "جاهز")
		var col := Color(0.16, 0.5, 0.3) if is_r else UI.ACCENT
		ready_btn.add_theme_stylebox_override("normal", UI.sb(col))
		ready_btn.add_theme_stylebox_override("hover", UI.sb(col.lightened(0.15)))
		ready_btn.disabled = false


# ====================================================================== navigation

func _go(to: String) -> void:
	if to == current or not panels.has(to):
		return
	if current == "room_garage":
		if room_hub and is_instance_valid(room_hub):
			room_hub.queue_free()
		room_hub = null
		panels.erase("room_garage")
		current = "lobby"
		panels["lobby"].visible = true
		if to == "lobby":
			return
	var to_p: Control = panels[to]
	current = to
	for k in panels:
		var pp: Control = panels[k]
		if pp != to_p:
			pp.visible = false
	to_p.visible = true
	to_p.modulate.a = 0.0
	to_p.create_tween().tween_property(to_p, "modulate:a", 1.0, 0.22)


# ====================================================================== actions

func _my_name() -> String:
	var n := Profile.pname.strip_edges()
	return n if n != "" else "Player"


func _on_create() -> void:
	var err := OK
	match setup_mode:
		"coop":
			err = Net.host_game(_my_name(), 1, blind_check.button_pressed)
		"teams":
			err = Net.host_game(_my_name(), 0, false, setup_count * setup_per, setup_count)
		"ffa":
			err = Net.host_game(_my_name(), 0, false, setup_count)
	if err != OK:
		_say(L.t("err_host"))
		_go("main")
		return
	_show_lobby()


func _on_solo() -> void:
	var err := Net.host_game(_my_name(), 0, false)
	if err != OK:
		_say(L.t("err_host"))
		return
	_show_lobby()


func _join(ip: String) -> void:
	if ip.strip_edges() == "":
		_say(L.t("err_ip"))
		return
	_say(L.t("connecting"))
	var err := Net.join_game(ip, _my_name())
	if err != OK:
		_say(L.t("err_addr"))


func _on_cancel() -> void:
	Net.leave()
	_go("main")


func _on_join_failed() -> void:
	_say(L.t("err_conn"))
	if current != "main":
		_go("main")


func _on_lobby_closed(reason: String) -> void:
	_say(reason)
	if current != "main":
		_go("main")


func _show_lobby() -> void:
	if status:
		status.modulate.a = 0.0
	shown_slots = 0
	_go("lobby")
	_refresh_lobby()


func _refresh_lobby() -> void:
	if lobby_slots == null or not is_instance_valid(lobby_slots):
		return
	var req := maxi(1, Net.required_players)
	var rows := Net.lobby_rows()
	for c in lobby_slots.get_children():
		c.queue_free()
	lobby_slots.columns = 3 if req > 4 else 2 if req > 1 else 1
	for i in req:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(360, 82)
		lobby_slots.add_child(p)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		p.add_child(h)
		if i < rows.size():
			var r: Dictionary = rows[i]
			var col: Color = SLOT_COLORS[int(r["team"]) % 6]
			var bar := ColorRect.new()
			bar.color = col
			bar.custom_minimum_size = Vector2(5, 0)
			h.add_child(bar)
			var v := VBoxContainer.new()
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.alignment = BoxContainer.ALIGNMENT_CENTER
			v.add_theme_constant_override("separation", 1)
			h.add_child(v)
			var tag := "   [%s]" % L.t("host_tag") if r["host"] else ""
			UI.lbl(v, "%s%s" % [r["name"], tag], 21, UI.TXT, false)
			var sub := "%s  -  %s" % [r["car"], r["role"]]
			if (not Net.ffa or Net.squads > 0) and req > 1:
				sub = "%s %s  -  %s" % [L.t("team"), char(65 + int(r["team"])), sub]
			UI.lbl(v, sub, 14, UI.TXT2, false)
			var st := UI.lbl(h, "", 16, UI.TXT2, false)
			st.custom_minimum_size = Vector2(96, 0)
			st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var sbx := UI.sb(UI.PANEL, 8, UI.LINE, 1)
			if r["ready"]:
				st.text = UI.tx("READY", "جاهز")
				st.add_theme_color_override("font_color", UI.OK)
				sbx = UI.sb(Color(0.08, 0.14, 0.11, 0.95), 8, UI.OK, 2)
			elif not r["present"]:
				st.text = UI.tx("in garage", "في الكراج")
			else:
				st.text = UI.tx("not ready", "غير جاهز")
			p.add_theme_stylebox_override("panel", sbx)
			if i >= shown_slots:
				p.pivot_offset = p.custom_minimum_size * 0.5
				p.scale = Vector2(0.7, 0.7)
				p.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(p, "scale", Vector2.ONE, 0.35)
		else:
			var l := UI.lbl(h, "...  " + L.t("empty_slot"), 17, UI.TXT2, false)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var sb2 := UI.sb(Color(1, 1, 1, 0.03), 8, UI.LINE, 1)
			p.add_theme_stylebox_override("panel", sb2)
	shown_slots = rows.size()
	if Net.is_hosting:
		lobby_ips.text = L.t("tell_friends") + "   " + "   ".join(Net.local_ips())
	else:
		lobby_ips.text = ""


func _refresh_hosts() -> void:
	if hosts_box == null or not is_instance_valid(hosts_box):
		return
	for c in hosts_box.get_children():
		c.queue_free()
	if Net.found_hosts.is_empty():
		UI.lbl(hosts_box, L.t("none_found"), 15, UI.TXT2, false)
		return
	for ip in Net.found_hosts:
		var h: Dictionary = Net.found_hosts[ip]
		var text := "%s   %d/%d   (%s)" % [h["name"], h["count"], h["required"], ip]
		UI.btn(hosts_box, text, UI.CARD2, _join.bind(ip), 17, Vector2(0, 40))
