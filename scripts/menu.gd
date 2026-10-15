extends Control
## Main menu (landscape, animated) + lobby with an animated "waiting for your friends" screen.

const GOLD := Color(1.0, 0.82, 0.25)
const NAVY := Color(0.08, 0.1, 0.19)
const CARD_COLORS := [Color(0.2, 0.55, 0.95), Color(0.2, 0.75, 0.4), Color(0.95, 0.5, 0.15), Color(0.85, 0.25, 0.4)]
const SLOT_COLORS := [Color(0.82, 0.1, 0.1), Color(0.15, 0.4, 0.95), Color(0.15, 0.7, 0.3), Color(0.95, 0.72, 0.1), Color(0.65, 0.25, 0.85), Color(0.1, 0.75, 0.8)]


# ====================================================================== small drawn widgets

class Backdrop extends Control:
	var t := 0.0
	var flakes: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for i in 60:
			flakes.append(Vector3(randf(), randf(), randf_range(0.3, 1.0)))

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var bands := 24
		for i in bands:
			var f := float(i) / bands
			draw_rect(Rect2(0, h * f, w, h / bands + 1), Color(0.04, 0.05, 0.13).lerp(Color(0.32, 0.14, 0.36), pow(f, 1.6)))
		# stars / snow
		for fl in flakes:
			var x := fposmod(fl.x * w + sin(t * 0.7 + fl.y * 9.0) * 14.0, w)
			var y := fposmod(fl.y * h * 0.8 + t * 22.0 * fl.z, h * 0.8)
			draw_circle(Vector2(x, y), 1.0 + fl.z * 1.6, Color(1, 1, 1, 0.25 + 0.5 * fl.z))
		# parallax mountains
		for layer in 3:
			var base := h * (0.58 + layer * 0.05)
			var col := Color(0.09, 0.1, 0.22).lerp(Color(0.03, 0.04, 0.1), layer / 2.0)
			var pts := PackedVector2Array()
			pts.append(Vector2(0, h))
			var step := 40.0
			var off := t * (6.0 + layer * 10.0)
			for k in int(w / step) + 3:
				var x := k * step - fposmod(off, step * 8.0)
				var seed_x := (k + int(off / (step * 8.0)) * 8)
				var peak := 60.0 + 50.0 * absf(sin(seed_x * 1.7 + layer)) + 30.0 * layer
				pts.append(Vector2(x, base - peak * (0.5 + 0.5 * sin(seed_x * 0.9))))
			pts.append(Vector2(w + 100, h))
			draw_colored_polygon(pts, col)
		# road in perspective
		var horizon := h * 0.74
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.5 - 18, horizon), Vector2(w * 0.5 + 18, horizon), Vector2(w * 1.05, h), Vector2(-w * 0.05, h)]), Color(0.09, 0.09, 0.13))
		for k in 9:
			var f := fposmod(float(k) / 9.0 + t * 0.35, 1.0)
			var y := horizon + (h - horizon) * f * f
			var wd := 2.0 + 14.0 * f * f
			draw_rect(Rect2(w * 0.5 - wd * 0.5, y, wd, 4.0 + 22.0 * f * f), Color(1, 1, 1, 0.5))
		# little red car
		var cx := w * 0.5 + sin(t * 0.9) * w * 0.07
		var cy := h * 0.9 + sin(t * 9.0) * 1.5
		draw_rect(Rect2(cx - 52, cy - 26, 104, 34), Color(0.82, 0.08, 0.08))
		draw_rect(Rect2(cx - 34, cy - 50, 68, 26), Color(0.62, 0.05, 0.05))
		draw_rect(Rect2(cx - 28, cy - 46, 56, 16), Color(0.1, 0.12, 0.2))
		draw_rect(Rect2(cx - 60, cy - 6, 22, 16), Color(0.03, 0.03, 0.04))
		draw_rect(Rect2(cx + 38, cy - 6, 22, 16), Color(0.03, 0.03, 0.04))
		draw_rect(Rect2(cx - 48, cy - 20, 14, 8), Color(1.0, 0.9, 0.5, 0.9))
		draw_rect(Rect2(cx + 34, cy - 20, 14, 8), Color(1.0, 0.9, 0.5, 0.9))


class Icon extends Control:
	var kind := "solo"
	var color := Color.WHITE
	var t := 0.0

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 46.0, color.darkened(0.55))
		draw_arc(c, 46.0, 0.0, TAU, 40, color, 3.0)
		var car := func(p: Vector2, col: Color) -> void:
			draw_rect(Rect2(p.x - 15, p.y - 6, 30, 12), col)
			draw_rect(Rect2(p.x - 9, p.y - 13, 18, 8), col.darkened(0.3))
		match kind:
			"solo":
				car.call(c + Vector2(sin(t * 2.0) * 10.0, 0), Color(0.9, 0.15, 0.15))
			"coop":
				car.call(c + Vector2(0, 6), Color(0.9, 0.15, 0.15))
				draw_circle(c + Vector2(-9, -16), 6, Color(0.93, 0.84, 0.7))
				draw_circle(c + Vector2(9, -16), 6, Color(0.93, 0.84, 0.7))
			"teams":
				car.call(c + Vector2(-10 + sin(t * 2.0) * 4.0, -12), SLOT_COLORS[0])
				car.call(c + Vector2(10 - sin(t * 2.0) * 4.0, 14), SLOT_COLORS[1])
			"ffa":
				for i in 3:
					car.call(c + Vector2(-14 + fposmod(t * 30.0 + i * 20.0, 30.0) * 0.0 + sin(t * 3.0 + i) * 6.0, -18 + i * 18), SLOT_COLORS[i])


class Spinner extends Control:
	var t := 0.0

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		draw_arc(c, 34.0, 0.0, TAU, 40, Color(1, 1, 1, 0.12), 8.0)
		draw_arc(c, 34.0, t * 4.0, t * 4.0 + 1.6, 20, Color(1.0, 0.82, 0.25), 8.0)
		draw_arc(c, 34.0, t * 4.0 + PI, t * 4.0 + PI + 0.8, 12, Color(1.0, 0.82, 0.25, 0.6), 8.0)
		draw_rect(Rect2(c.x - 13, c.y - 5, 26, 10), Color(0.85, 0.1, 0.1))
		draw_rect(Rect2(c.x - 7, c.y - 11, 14, 7), Color(0.6, 0.05, 0.05))


# ====================================================================== state

var root_box: Control
var panels := {}
var current := "main"
var name_text := ""
var name_edit: LineEdit
var ip_edit: LineEdit
var status: Label
var hosts_box: VBoxContainer
var blind_check: CheckBox
var setup_mode := ""
var setup_count := 2
var count_row: HBoxContainer
var setup_title: Label
var setup_blind_row: Control
var lobby_title: Label
var lobby_slots: GridContainer
var lobby_ips: Label
var lobby_bar: ProgressBar
var shown_slots := 0
var _t := 0.0
var _backdrop: Backdrop


func _ready() -> void:
	name_text = "Player%d" % (randi() % 900 + 100)
	Net.players_changed.connect(_refresh_lobby)
	Net.hosts_changed.connect(_refresh_hosts)
	Net.joined.connect(_show_lobby)
	Net.join_failed.connect(_on_join_failed)
	Net.lobby_closed.connect(_on_lobby_closed)
	L.changed.connect(_build_ui)
	Net.start_browsing()
	_backdrop = Backdrop.new()
	add_child(_backdrop)
	_build_ui()
	if Net.pending_message != "":
		status.text = Net.pending_message
		Net.pending_message = ""


func _exit_tree() -> void:
	Net.stop_browsing()


func _process(d: float) -> void:
	_t += d
	if current == "lobby" and lobby_title:
		var base := L.t("waiting") if Net.players.size() < Net.required_players else L.t("full")
		lobby_title.text = base + ("." .repeat(int(_t * 2.5) % 4) if Net.players.size() < Net.required_players else "")
		if lobby_bar:
			var target := 100.0 * Net.players.size() / maxf(1.0, Net.required_players)
			lobby_bar.value = lerpf(lobby_bar.value, target, clampf(d * 6.0, 0.0, 1.0))


# ====================================================================== building blocks

func _label(parent: Node, text: String, fs: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _sb(col: Color, radius := 18) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


func _hover_pop(c: Control, amount := 1.06) -> void:
	c.resized.connect(func(): c.pivot_offset = c.size * 0.5)
	c.mouse_entered.connect(func(): create_tween().tween_property(c, "scale", Vector2(amount, amount), 0.12))
	c.mouse_exited.connect(func(): create_tween().tween_property(c, "scale", Vector2.ONE, 0.12))
	if c is BaseButton:
		(c as BaseButton).button_down.connect(func(): create_tween().tween_property(c, "scale", Vector2(0.96, 0.96), 0.06))


func _button(parent: Node, text: String, col: Color, cb: Callable, fs := 26, min_size := Vector2(0, 62)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_stylebox_override("normal", _sb(col))
	b.add_theme_stylebox_override("hover", _sb(col.lightened(0.18)))
	b.add_theme_stylebox_override("pressed", _sb(col.darkened(0.15)))
	b.add_theme_stylebox_override("focus", _sb(col))
	b.pressed.connect(cb)
	_hover_pop(b)
	parent.add_child(b)
	return b


func _card(parent: Node, kind: String, tkey: String, dkey: String, col: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(270, 250)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := _sb(NAVY.lightened(0.04), 24)
	n.border_color = col
	n.set_border_width_all(3)
	b.add_theme_stylebox_override("normal", n)
	var h := _sb(col.darkened(0.45), 24)
	h.border_color = col.lightened(0.3)
	h.set_border_width_all(4)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("focus", n)
	b.pressed.connect(cb)
	_hover_pop(b, 1.05)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 6)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(vb)
	var ic := Icon.new()
	ic.kind = kind
	ic.color = col
	ic.custom_minimum_size = Vector2(0, 100)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(ic)
	var t := _label(vb, L.t(tkey), 27, col.lightened(0.35))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var d := _label(vb, L.t(dkey), 17, Color(0.8, 0.85, 0.95))
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(b)
	return b


func _panel_frame() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _sb(Color(0.05, 0.06, 0.14, 0.82), 22)
	sb.border_color = Color(1, 1, 1, 0.1)
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	return p


# ====================================================================== UI

func _build_ui() -> void:
	if name_edit:
		name_text = name_edit.text
	if root_box:
		root_box.queue_free()
	panels.clear()
	layout_direction = Control.LAYOUT_DIRECTION_RTL if L.is_ar() else Control.LAYOUT_DIRECTION_LTR
	root_box = MarginContainer.new()
	root_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		root_box.add_theme_constant_override("margin_" + side, 26)
	add_child(root_box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	root_box.add_child(vb)

	# header: title + name + language
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	vb.add_child(head)
	var tcol := VBoxContainer.new()
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tcol)
	var title := _label(tcol, L.t("title"), 52, GOLD)
	title.add_theme_color_override("font_outline_color", Color(0.3, 0.1, 0.0))
	title.add_theme_constant_override("outline_size", 10)
	title.pivot_offset = Vector2(160, 30)
	var tw := create_tween().set_loops()
	tw.tween_property(title, "rotation", 0.012, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(title, "rotation", -0.012, 1.6).set_trans(Tween.TRANS_SINE)
	_label(tcol, L.t("subtitle"), 20, Color(0.8, 0.85, 0.95))
	var ncol := VBoxContainer.new()
	head.add_child(ncol)
	_label(ncol, L.t("name"), 15, Color(0.7, 0.75, 0.9))
	name_edit = LineEdit.new()
	name_edit.text = name_text
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(230, 48)
	name_edit.add_theme_font_size_override("font_size", 22)
	ncol.add_child(name_edit)
	var lb := _button(head, L.t("lang_btn"), Color(0.25, 0.28, 0.5), func(): L.set_lang("en" if L.is_ar() else "ar"), 22, Vector2(130, 56))
	lb.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	status = _label(vb, "", 20, Color(1.0, 0.6, 0.5))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(stack)
	panels["main"] = _build_main()
	panels["setup"] = _build_setup()
	panels["lobby"] = _build_lobby()
	for k in panels:
		var p: Control = panels[k]
		p.set_anchors_preset(Control.PRESET_FULL_RECT)
		stack.add_child(p)
		p.visible = (k == current)
	if current == "lobby" and not Net.is_hosting and Net.players.is_empty():
		current = "main"
		panels["main"].visible = true
		panels["lobby"].visible = false
	_refresh_hosts()
	_refresh_lobby()
	var root_p: Control = panels[current]
	root_p.modulate.a = 0.0
	create_tween().tween_property(root_p, "modulate:a", 1.0, 0.35)


func _build_main() -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(cards)
	var specs := [
		["solo", "solo", "solo_d", func(): _on_solo()],
		["coop", "coop", "coop_d", func(): _open_setup("coop")],
		["teams", "teams", "teams_d", func(): _open_setup("teams")],
		["ffa", "ffa", "ffa_d", func(): _open_setup("ffa")],
	]
	for i in specs.size():
		var c := _card(cards, specs[i][0], specs[i][1], specs[i][2], CARD_COLORS[i], specs[i][3])
		# staggered pop-in
		c.modulate.a = 0.0
		c.position.y += 30
		var tw := create_tween().set_parallel(true)
		tw.tween_interval(0.08 * i)
		tw.chain().tween_property(c, "modulate:a", 1.0, 0.35)
	# join strip
	var join := _panel_frame()
	vb.add_child(join)
	var jh := HBoxContainer.new()
	jh.add_theme_constant_override("separation", 22)
	join.add_child(jh)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jh.add_child(left)
	_label(left, L.t("games_found"), 20, GOLD)
	hosts_box = VBoxContainer.new()
	hosts_box.add_theme_constant_override("separation", 6)
	left.add_child(hosts_box)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(380, 0)
	jh.add_child(right)
	_label(right, L.t("join") + "  -  " + L.t("ip_hint"), 18, Color(0.8, 0.85, 0.95))
	var rr := HBoxContainer.new()
	rr.add_theme_constant_override("separation", 10)
	right.add_child(rr)
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "192.168.1.10"
	ip_edit.custom_minimum_size = Vector2(0, 54)
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_edit.add_theme_font_size_override("font_size", 22)
	rr.add_child(ip_edit)
	_button(rr, L.t("join_btn"), Color(0.15, 0.6, 0.3), func(): _join(ip_edit.text), 24, Vector2(120, 54))
	return vb


func _build_setup() -> Control:
	var wrap := CenterContainer.new()
	var p := _panel_frame()
	p.custom_minimum_size = Vector2(760, 0)
	wrap.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	p.add_child(vb)
	setup_title = _label(vb, "", 38, GOLD)
	setup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var q := _label(vb, L.t("choose"), 22, Color(0.8, 0.85, 0.95))
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_row = HBoxContainer.new()
	count_row.alignment = BoxContainer.ALIGNMENT_CENTER
	count_row.add_theme_constant_override("separation", 14)
	vb.add_child(count_row)
	var bl := VBoxContainer.new()
	vb.add_child(bl)
	setup_blind_row = bl
	blind_check = CheckBox.new()
	blind_check.text = L.t("blind") + "  -  " + L.t("blind_d")
	blind_check.button_pressed = true
	blind_check.add_theme_font_size_override("font_size", 22)
	bl.add_child(blind_check)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	vb.add_child(row)
	_button(row, L.t("back"), Color(0.3, 0.32, 0.5), func(): _go("main"), 26, Vector2(180, 64))
	var go := _button(row, L.t("start_host"), Color(0.15, 0.6, 0.3), _on_create, 28, Vector2(0, 64))
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return wrap


func _open_setup(mode: String) -> void:
	setup_mode = mode
	for c in count_row.get_children():
		c.queue_free()
	setup_title.text = L.t(mode)
	setup_blind_row.visible = mode != "ffa"
	if mode == "coop":
		setup_count = 1
		var l := _label(count_row, L.t("coop_d"), 26, Color(0.7, 0.95, 0.8))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(640, 96)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	else:
		var lo := 2
		var hi := 4 if mode == "teams" else 6
		setup_count = lo
		var group := ButtonGroup.new()
		for n in range(lo, hi + 1):
			var b := Button.new()
			b.toggle_mode = true
			b.button_group = group
			b.custom_minimum_size = Vector2(96, 96)
			b.text = str(n)
			b.add_theme_font_size_override("font_size", 40)
			b.add_theme_stylebox_override("normal", _sb(Color(0.15, 0.17, 0.3), 20))
			b.add_theme_stylebox_override("hover", _sb(Color(0.25, 0.28, 0.45), 20))
			b.add_theme_stylebox_override("pressed", _sb(Color(0.95, 0.7, 0.15), 20))
			b.add_theme_color_override("font_pressed_color", Color.BLACK)
			b.add_theme_color_override("font_hover_pressed_color", Color.BLACK)
			b.add_theme_stylebox_override("hover_pressed", _sb(Color(1.0, 0.8, 0.3), 20))
			b.button_pressed = (n == lo)
			b.pressed.connect(func(): setup_count = n)
			_hover_pop(b)
			count_row.add_child(b)
	_go("setup")


func _build_lobby() -> Control:
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 20)
	vb.add_child(top)
	var sp := Spinner.new()
	sp.custom_minimum_size = Vector2(90, 90)
	top.add_child(sp)
	lobby_title = _label(top, "", 40, GOLD)
	lobby_title.custom_minimum_size = Vector2(620, 0)
	lobby_bar = ProgressBar.new()
	lobby_bar.custom_minimum_size = Vector2(0, 16)
	lobby_bar.show_percentage = false
	lobby_bar.add_theme_stylebox_override("fill", _sb(GOLD, 8))
	lobby_bar.add_theme_stylebox_override("background", _sb(Color(1, 1, 1, 0.1), 8))
	vb.add_child(lobby_bar)
	lobby_slots = GridContainer.new()
	lobby_slots.columns = 3
	lobby_slots.add_theme_constant_override("h_separation", 14)
	lobby_slots.add_theme_constant_override("v_separation", 12)
	var cc := CenterContainer.new()
	cc.add_child(lobby_slots)
	vb.add_child(cc)
	lobby_ips = _label(vb, "", 22, Color(0.7, 0.9, 1.0))
	lobby_ips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cr := CenterContainer.new()
	vb.add_child(cr)
	_button(cr, L.t("cancel"), Color(0.7, 0.2, 0.25), _on_cancel, 26, Vector2(260, 60))
	shown_slots = 0
	return vb


# ====================================================================== navigation

func _go(to: String) -> void:
	if to == current:
		return
	var from_p: Control = panels[current]
	var to_p: Control = panels[to]
	var tw := create_tween()
	tw.tween_property(from_p, "modulate:a", 0.0, 0.15)
	await tw.finished
	from_p.visible = false
	to_p.visible = true
	to_p.modulate.a = 0.0
	current = to
	create_tween().tween_property(to_p, "modulate:a", 1.0, 0.25)


# ====================================================================== actions

func _my_name() -> String:
	var n := name_edit.text.strip_edges()
	return n if n != "" else "Player"


func _on_create() -> void:
	var err := OK
	match setup_mode:
		"coop":
			err = Net.host_game(_my_name(), 1, blind_check.button_pressed)
		"teams":
			err = Net.host_game(_my_name(), setup_count, blind_check.button_pressed)
		"ffa":
			err = Net.host_game(_my_name(), 0, false, setup_count)
	if err != OK:
		status.text = L.t("err_host")
		_go("main")
		return
	_show_lobby()


func _on_solo() -> void:
	var err := Net.host_game(_my_name(), 0, false)
	if err != OK:
		status.text = L.t("err_host")
		return
	_show_lobby()


func _join(ip: String) -> void:
	if ip.strip_edges() == "":
		status.text = L.t("err_ip")
		return
	status.text = L.t("connecting")
	var err := Net.join_game(ip, _my_name())
	if err != OK:
		status.text = L.t("err_addr")


func _on_cancel() -> void:
	Net.leave()
	_go("main")


func _on_join_failed() -> void:
	status.text = L.t("err_conn")
	if current != "main":
		_go("main")


func _on_lobby_closed(reason: String) -> void:
	status.text = reason
	if current != "main":
		_go("main")


func _show_lobby() -> void:
	status.text = ""
	shown_slots = 0
	_go("lobby")
	_refresh_lobby()


func _refresh_lobby() -> void:
	if lobby_slots == null or not is_instance_valid(lobby_slots):
		return
	var req := maxi(1, Net.required_players)
	var lines := Net.lobby_lines()
	var ids: Array = Net.players.keys()
	if lobby_slots.get_child_count() != req:
		for c in lobby_slots.get_children():
			c.queue_free()
		shown_slots = 0
		lobby_slots.columns = 3 if req > 4 else 2 if req > 1 else 1
		for i in req:
			var p := PanelContainer.new()
			p.custom_minimum_size = Vector2(380, 74)
			p.name = "slot%d" % i
			var l := Label.new()
			l.name = "txt"
			l.add_theme_font_size_override("font_size", 22)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			p.add_child(l)
			lobby_slots.add_child(p)
	for i in req:
		var p: PanelContainer = lobby_slots.get_child(i)
		var l: Label = p.get_node("txt")
		var team := i if Net.ffa else ((i >> 1) if req > 1 else 0)
		var col: Color = SLOT_COLORS[team % 6]
		if i < lines.size():
			l.text = lines[i]
			l.add_theme_color_override("font_color", Color.WHITE)
			p.add_theme_stylebox_override("panel", _sb(col.darkened(0.35), 16))
			if i >= shown_slots:   # newly joined: pop animation
				p.pivot_offset = p.custom_minimum_size * 0.5
				p.scale = Vector2(0.6, 0.6)
				create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(p, "scale", Vector2.ONE, 0.4)
		else:
			l.text = "...  " + L.t("empty_slot")
			l.add_theme_color_override("font_color", Color(0.6, 0.65, 0.8))
			var sb := _sb(Color(1, 1, 1, 0.05), 16)
			sb.border_color = Color(1, 1, 1, 0.2)
			sb.set_border_width_all(2)
			p.add_theme_stylebox_override("panel", sb)
	shown_slots = lines.size()
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
		_label(hosts_box, L.t("none_found"), 18, Color(0.6, 0.65, 0.75))
		return
	for ip in Net.found_hosts:
		var h: Dictionary = Net.found_hosts[ip]
		var text := "%s   %d/%d   (%s)" % [h["name"], h["count"], h["required"], ip]
		_button(hosts_box, text, Color(0.2, 0.35, 0.6), _join.bind(ip), 20, Vector2(0, 46))
