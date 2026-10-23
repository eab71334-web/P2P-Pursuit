# Copyright (c) 2026 AVF. All rights reserved. See LICENSE.
class_name Hub
extends Control
## The "game hub": top bar (level, coins, gems) + tabs PLAY / GARAGE / WORKSHOP / CHARACTER / SHOP / QUESTS / CHESTS.
## Used on the main menu (all tabs) and inside the room (garage, workshop, character, shop only).

signal closed

var play_content: Control
var in_room := false
var tab_ids: Array = []
var cur := ""
var content: Control
var nav_btns := {}
var lv_label: Label
var xp_bar: ProgressBar
var xp_label: Label
var coin_label: Label
var gem_label: Label
var toast: Label
var preview: Preview3D
var name_edit: LineEdit
var ws_tab := "parts"
var g_car := "hatch"           # car being looked at in the garage
var browser_slot := ""
var browser_id := ""
var browser_box: Control
var action_box: HBoxContainer
var stat_box: VBoxContainer
var _toast_tw: Tween
var _pending_levelups: Array = []


class LevelBadge extends Control:
	var level := 1
	var t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(52, 52)

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		# hexagon badge
		var pts := PackedVector2Array()
		for k in 7:
			var a := TAU * k / 6.0 + PI / 6.0
			pts.append(c + Vector2(cos(a), sin(a)) * 25.0)
		draw_colored_polygon(pts.slice(0, 6), Color(0.12, 0.13, 0.17))
		draw_polyline(pts, UI.ACCENT, 2.5)
		var f := ThemeDB.fallback_font
		var s := str(level)
		var sz := f.get_string_size(s, HORIZONTAL_ALIGNMENT_CENTER, -1, 24)
		draw_string(f, c + Vector2(-sz.x * 0.5, 8), s, HORIZONTAL_ALIGNMENT_CENTER, -1, 24, UI.TXT)


## sidebar entry: flat button, accent bar on the active one, small drawn icon
class NavItem extends Button:
	var kind := ""
	var active := false:
		set(v):
			active = v
			add_theme_color_override("font_color", UI.TXT if v else UI.TXT2)
			queue_redraw()

	func _init(k := "") -> void:
		kind = k
		custom_minimum_size = Vector2(0, 54)
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_theme_font_size_override("font_size", 20)
		var n := UI.sb(Color(0, 0, 0, 0), 6)
		n.content_margin_left = 58
		n.content_margin_right = 58
		add_theme_stylebox_override("normal", n)
		var h := UI.sb(Color(1, 1, 1, 0.06), 6)
		h.content_margin_left = 58
		h.content_margin_right = 58
		add_theme_stylebox_override("hover", h)
		add_theme_stylebox_override("pressed", h)
		add_theme_stylebox_override("focus", n)
		add_theme_color_override("font_color", UI.TXT2)
		add_theme_color_override("font_hover_color", UI.TXT)

	func _draw() -> void:
		var rtl := is_layout_rtl()
		var col := UI.ACCENT if active else UI.TXT2
		if active:
			draw_rect(Rect2(0, 0, size.x, size.y), Color(1.0, 0.47, 0.1, 0.12))
			draw_rect(Rect2(size.x - 4 if rtl else 0, 6, 4, size.y - 12), UI.ACCENT)
		var c := Vector2(size.x - 30 if rtl else 30, size.y * 0.5)
		match kind:
			"play":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-7, -10), c + Vector2(10, 0), c + Vector2(-7, 10)]), col)
			"garage":
				draw_rect(Rect2(c.x - 12, c.y - 2, 24, 8), col)
				draw_rect(Rect2(c.x - 7, c.y - 8, 14, 7), col)
				draw_circle(c + Vector2(-7, 7), 3.5, UI.BG)
				draw_circle(c + Vector2(7, 7), 3.5, UI.BG)
				draw_arc(c + Vector2(-7, 7), 3.5, 0, TAU, 12, col, 1.5)
				draw_arc(c + Vector2(7, 7), 3.5, 0, TAU, 12, col, 1.5)
			"workshop":
				draw_arc(c, 8, 0, TAU, 16, col, 3.0)
				for k in 6:
					var a := TAU * k / 6.0
					draw_line(c + Vector2(cos(a), sin(a)) * 8, c + Vector2(cos(a), sin(a)) * 12, col, 3.5)
			"character":
				draw_circle(c + Vector2(0, -6), 5, col)
				draw_rect(Rect2(c.x - 8, c.y + 1, 16, 10), col)
			"shop":
				draw_rect(Rect2(c.x - 10, c.y - 4, 20, 14), col)
				draw_arc(c + Vector2(0, -4), 5, PI, TAU, 10, col, 2.0)
			"quests":
				for k in 3:
					draw_rect(Rect2(c.x - 11, c.y - 9 + k * 8, 4, 4), col)
					draw_rect(Rect2(c.x - 4, c.y - 8 + k * 8, 15, 2.5), col)
			"settings":
				for k in 3:
					draw_rect(Rect2(c.x - 11, c.y - 8 + k * 8, 22, 2.5), col)
					draw_circle(Vector2(c.x - 5 + k * 5, c.y - 7 + k * 8), 3.2, UI.BG)
					draw_arc(Vector2(c.x - 5 + k * 5, c.y - 7 + k * 8), 3.2, 0, TAU, 10, col, 2.0)
			"chests":
				draw_rect(Rect2(c.x - 11, c.y - 2, 22, 12), col)
				draw_rect(Rect2(c.x - 11, c.y - 9, 22, 7), col.darkened(0.25))
				draw_rect(Rect2(c.x - 2, c.y - 3, 4, 6), UI.BG)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Profile.changed.connect(_update_top)
	Profile.leveled.connect(_on_leveled)
	_build()
	select(tab_ids[0])


func _on_leveled(lv: int, r: Dictionary) -> void:
	_pending_levelups.append([lv, r])


func _build() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	# ---- sidebar
	var side := UI.panel(root, UI.PANEL, 10)
	side.custom_minimum_size = Vector2(228, 0)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 4)
	side.add_child(sv)
	var logo := VBoxContainer.new()
	logo.add_theme_constant_override("separation", 0)
	sv.add_child(logo)
	UI.lbl(logo, "HAIRPIN", 25, UI.TXT, false)
	var rl := UI.lbl(logo, "RUSH", 25, UI.ACCENT, false)
	rl.add_theme_constant_override("outline_size", 0)
	if L.is_ar():
		logo.get_child(0).text = "هيربن"
		rl.text = "راش"
	var bar := ColorRect.new()
	bar.color = UI.ACCENT
	bar.custom_minimum_size = Vector2(46, 3)
	sv.add_child(bar)
	var sp0 := Control.new()
	sp0.custom_minimum_size = Vector2(0, 10)
	sv.add_child(sp0)
	var names := {"play": ["PLAY", "العب"], "garage": ["GARAGE", "الكراج"], "character": ["CHARACTER", "الشخصية"],
		"shop": ["SHOP", "المتجر"], "quests": ["QUESTS", "المهام"], "chests": ["CHESTS", "الصناديق"], "settings": ["SETTINGS", "الإعدادات"]}
	for id in tab_ids:
		var b := NavItem.new(id)
		b.text = UI.tx(names[id][0], names[id][1])
		b.pressed.connect(func():
			Sfx.play("click", -8.0)
			select(id))
		sv.add_child(b)
		nav_btns[id] = b
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sv.add_child(grow)
	if in_room:
		UI.btn(sv, UI.tx("< Back to room", "< رجوع للغرفة"), UI.ACCENT, func(): closed.emit(), 20, Vector2(0, 50))
	else:
		UI.btn(sv, L.t("lang_btn"), UI.CARD2, func(): L.set_lang("en" if L.is_ar() else "ar"), 18, Vector2(0, 42))
	# ---- main column
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 10)
	root.add_child(vb)
	var top := UI.panel(vb, UI.PANEL, 10)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 14)
	top.add_child(th)
	var badge := LevelBadge.new()
	badge.name = "badge"
	th.add_child(badge)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 0)
	pv.custom_minimum_size = Vector2(190, 0)
	th.add_child(pv)
	name_edit = LineEdit.new()
	name_edit.text = Profile.pname
	name_edit.max_length = 14
	name_edit.flat = true
	name_edit.select_all_on_focus = true
	name_edit.add_theme_font_size_override("font_size", 21)
	name_edit.add_theme_color_override("font_color", UI.TXT)
	name_edit.add_theme_stylebox_override("normal", UI.sb(Color(1, 1, 1, 0.05), 6))
	name_edit.add_theme_stylebox_override("focus", UI.sb(Color(1, 1, 1, 0.1), 6, UI.ACCENT, 1))
	name_edit.text_changed.connect(_on_name)
	name_edit.text_submitted.connect(func(_t): name_edit.release_focus())
	name_edit.focus_exited.connect(func(): _on_name(name_edit.text, true))
	name_edit.editable = not in_room
	pv.add_child(name_edit)
	lv_label = UI.lbl(pv, "", 14, UI.TXT2, false)
	var xv := VBoxContainer.new()
	xv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xv.alignment = BoxContainer.ALIGNMENT_CENTER
	th.add_child(xv)
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(0, 8)
	xp_bar.show_percentage = false
	xp_bar.add_theme_stylebox_override("fill", UI.sb(UI.ACCENT, 4))
	xp_bar.add_theme_stylebox_override("background", UI.sb(Color(1, 1, 1, 0.1), 4))
	xv.add_child(xp_bar)
	xp_label = UI.lbl(xv, "", 13, UI.TXT2, false)
	for gem in [false, true]:
		var cp := UI.panel(th, UI.CARD, 8)
		var ch := HBoxContainer.new()
		ch.add_theme_constant_override("separation", 6)
		cp.add_child(ch)
		ch.add_child(UI.Coin.new(gem))
		var l := UI.lbl(ch, "0", 22, UI.TXT, false)
		if gem:
			gem_label = l
		else:
			coin_label = l
		# a small "+" opens the coin shop
		var plus := UI.btn(ch, "+", UI.ACCENT, func():
			Sfx.play("click", -8.0)
			select("shop"), 22, Vector2(34, 34))
		plus.add_theme_color_override("font_color", Color(0.08, 0.05, 0.02))
	content = Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.clip_contents = true
	vb.add_child(content)
	toast = UI.lbl(self, "", 24, Color.WHITE, false)
	toast.add_theme_stylebox_override("normal", UI.sb(Color(0, 0, 0, 0.88), 8, UI.ACCENT, 1))
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast.position.y -= 80
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.modulate.a = 0.0
	toast.z_index = 20
	_update_top()


func _on_name(t: String, final := false) -> void:
	var n := t.strip_edges()
	if n == "":
		n = Profile.pname if final else ""
		if final:
			name_edit.text = n
		return
	Profile.pname = n
	if final:
		Profile.save()


func _update_top() -> void:
	if lv_label == null:
		return
	lv_label.text = "%s %d" % [UI.tx("LEVEL", "المستوى"), Profile.level]
	var need := Catalog.xp_for(Profile.level)
	xp_bar.max_value = need
	create_tween().tween_property(xp_bar, "value", float(Profile.xp), 0.4)
	xp_label.text = "%d / %d XP" % [Profile.xp, need]
	coin_label.text = str(Profile.coins)
	gem_label.text = str(Profile.gems)
	for n in find_children("badge", "Control", true, false):
		(n as LevelBadge).level = Profile.level
	if not _pending_levelups.is_empty():
		var lv: Array = _pending_levelups.pop_front()
		var r: Dictionary = lv[1]
		var msg := "%s %d!  +%d" % [UI.tx("LEVEL UP!", "ارتقيت للمستوى"), lv[0], int(r["coins"])]
		if int(r["gems"]) > 0:
			msg += "  +%d %s" % [int(r["gems"]), UI.tx("gems", "جوهرة")]
		say(msg)
		Sfx.play("success", 2.0)


func say(text: String) -> void:
	toast.text = "  " + text + "  "
	if _toast_tw:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_property(toast, "modulate:a", 1.0, 0.15)
	_toast_tw.tween_interval(1.8)
	_toast_tw.tween_property(toast, "modulate:a", 0.0, 0.4)


# ====================================================================== tabs

func select(id: String) -> void:
	for c in content.get_children():
		if c == play_content:
			content.remove_child(c)
		else:
			c.queue_free()
	preview = null
	browser_box = null
	cur = id
	for k in nav_btns:
		(nav_btns[k] as NavItem).active = (k == id or (id == "modify" and k == "garage"))
	var p: Control
	match id:
		"play":
			p = play_content
			if p.get_parent():
				p.get_parent().remove_child(p)
		"garage":
			p = _tab_garage()
		"modify":
			p = _tab_modify()
		"character":
			p = _tab_character()
		"shop":
			p = _tab_shop()
		"quests":
			p = _tab_quests()
		"chests":
			p = _tab_chests()
		"settings":
			p = SettingsUI.new()
	content.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.modulate.a = 0.0
	create_tween().tween_property(p, "modulate:a", 1.0, 0.2)


func _scroll(parent: Node) -> ScrollContainer:
	var sc := TScroll.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if parent:
		parent.add_child(sc)
	return sc


func _bar(parent: Node, text: String, frac: float, col: Color, extra := 0.0) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	parent.add_child(h)
	var l := UI.lbl(h, text, 14, UI.TXT2, false)
	l.custom_minimum_size = Vector2(70, 0)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(0, 12)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.show_percentage = false
	b.max_value = 1.0
	b.value = clampf(frac, 0.0, 1.0)
	b.add_theme_stylebox_override("fill", UI.sb(col, 6))
	b.add_theme_stylebox_override("background", UI.sb(Color(1, 1, 1, 0.1), 6))
	h.add_child(b)


## performance bars of a car with its upgrades
func _stats(parent: Node, car_id: String) -> void:
	var m: Dictionary = Catalog.CARS[car_id]
	var up: Dictionary = Profile.up.get(car_id, {})
	var fm := Catalog.fit_mods(up)
	var power := float(m["power"]) * (1.0 + 0.06 * int(up.get("engine", 0))) * float(fm["power"])
	var top := float(m["top"]) * (1.0 + 0.03 * int(up.get("engine", 0))) * float(fm["top"])
	var grip := float(m["grip"]) * (1.0 + 0.05 * int(up.get("tires", 0))) * float(fm["grip"])
	var tough := 1.0 / (float(m["armor"]) * (1.0 - 0.08 * int(up.get("armor", 0))) * float(fm["armor"]))
	var heat := float(m["top"]) * 0.88 + 6.0 * int(up.get("cooling", 0))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 2)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(g)
	_bar(g, UI.tx("Power", "القوة"), power / 2.0, Color(0.95, 0.35, 0.2))
	_bar(g, UI.tx("Speed", "السرعة"), top / 260.0, Color(0.95, 0.75, 0.2))
	_bar(g, UI.tx("Grip", "الثبات"), grip / 1.9, Color(0.3, 0.8, 0.4))
	_bar(g, UI.tx("Armor", "المتانة"), tough / 2.2, Color(0.3, 0.6, 0.95))
	_bar(g, UI.tx("Cooling", "التبريد"), heat / 230.0, Color(0.5, 0.85, 0.95))


func _lo_for(car_id: String, over := {}) -> Dictionary:
	var cs: Dictionary = Profile.car_set(car_id)
	var lo := {"car": car_id, "paint": cs["paint"], "stripe": cs["stripe"], "rim": cs["rim"], "glow": cs["glow"], "decal": cs["decal"], "spoiler": cs["spoiler"], "front": cs["front"], "hood": cs["hood"], "skirts": cs["skirts"], "wheel": cs["wheel"], "up": Profile.up.get(car_id, {}), "outfit": Profile.outfit}
	for k in over:
		lo[k] = over[k]
	return lo


# ---------------------------------------------------------------- item browser (paint, hats, ...)

## slots: array of slot names. on_pick(slot, id) is called when something is selected (for the 3D preview)
func _browser(slots: Array, on_pick: Callable) -> Control:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	var tsc := TScroll.new()
	tsc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tsc.custom_minimum_size = Vector2(0, 52)
	tsc.add_child(tabs)
	vb.add_child(tsc)
	var grid_sc := _scroll(vb)
	var grid := GridContainer.new()
	grid.columns = 4 if slots[0] in Catalog.CAR_SLOTS else 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_sc.add_child(grid)
	action_box = HBoxContainer.new()
	action_box.add_theme_constant_override("separation", 10)
	action_box.custom_minimum_size = Vector2(0, 54)
	vb.add_child(action_box)
	var fill := func(slot: String) -> void:
		browser_slot = slot
		for tb in tabs.get_children():
			var on: bool = tb.get_meta("slot") == slot
			(tb as Button).add_theme_stylebox_override("normal", UI.sb(UI.ACCENT if on else UI.CARD2, 6))
		for c in grid.get_children():
			c.queue_free()
		var order: Array = []
		if slot == "emote":
			order = Catalog.EMOTE_ORDER
		elif Catalog.CAR_SLOT_ORDER.has(slot):
			order = Catalog.CAR_SLOT_ORDER[slot]
		else:
			order = (Catalog.OUTFIT_SLOTS[slot] as Dictionary).keys()
		var equipped := _equipped(slot)
		browser_id = equipped
		for id in order:
			grid.add_child(_item_cell(slot, id, equipped, on_pick, grid))
		_action_bar(slot, browser_id)
	for s in slots:
		var b := UI.btn(tabs, Catalog.txt(Catalog.SLOT_NAME[s]), UI.CARD2, func(): fill.call(s), 20, Vector2(0, 46))
		b.set_meta("slot", s)
	browser_box = vb
	vb.set_meta("fill", fill)
	fill.call(slots[0])
	return vb


func _equipped(slot: String) -> String:
	if slot == "emote":
		return str(Profile.outfit.get("emote", "wave"))
	if Catalog.CAR_SLOTS.has(slot):
		return str(Profile.car_set(g_car)[slot])
	return str(Profile.outfit.get(slot, Catalog.DEFAULT_OUTFIT[slot]))


func _item_cell(slot: String, id: String, equipped: String, on_pick: Callable, grid: Control) -> Control:
	var e: Dictionary = Catalog.entry(slot, id)
	var rar := int(e["r"])
	var rc: Color = Catalog.RARITY_COLOR[rar]
	var owned := Profile.owns(slot, id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(120, 112)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := UI.sb(UI.CARD, 14, rc.darkened(0.2), 2)
	var sel := UI.sb(UI.CARD2, 14, rc, 4)
	b.add_theme_stylebox_override("normal", n if id != equipped else UI.sb(Color(0.1, 0.2, 0.15), 14, UI.OK, 4))
	b.add_theme_stylebox_override("hover", sel)
	b.add_theme_stylebox_override("pressed", sel)
	b.add_theme_stylebox_override("focus", n)
	b.set_meta("id", id)
	UI.pop(b, 1.04)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 2)
	b.add_child(vb)
	var col: Color = rc
	if e.has("c") and e["c"] != Color.TRANSPARENT:
		col = e["c"]
	elif slot == "shirt" and id == "team":
		col = Color(0.8, 0.2, 0.25)
	var kind := slot
	if slot == "skin":
		kind = "shirt"
	if Catalog.CAR_SLOTS.has(slot):
		var sw := HubArt.SwatchArt.new()
		sw.slot = slot
		sw.model = g_car
		sw.kit_id = id
		sw.wheel_cur = str(Profile.car_set(g_car)["wheel"])
		sw.rim_cur = Catalog.RIMS[Profile.car_set(g_car)["rim"]]["c"]
		sw.col = col
		sw.none = id == "none"
		sw.metal = float(e.get("m", 0.0))
		sw.rough = float(e.get("ro", 0.5))
		sw.txt = str(e.get("t", ""))
		sw.bg = e.get("bg", Color.BLACK)
		sw.base = Catalog.PAINTS[Profile.car_set(g_car)["paint"]]["c"]
		sw.custom_minimum_size = Vector2(0, 82 if slot != "rim" else 66)
		sw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sw.selected = id == equipped
		vb.add_child(sw)
	else:
		vb.add_child(UI.Glyph.new(kind, col))
	var nm := UI.lbl(vb, Catalog.nm(e), 14, rc.lightened(0.3), true)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if id == equipped:
		var t := UI.lbl(vb, UI.tx("EQUIPPED", "مستخدم"), 13, Color(0.4, 1.0, 0.6), false)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif owned:
		var t := UI.lbl(vb, UI.tx("OWNED", "مملوك"), 13, UI.TXT2, false)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		UI.price_row(vb, int(e["gem"]) if e.has("gem") else int(e["price"]), e.has("gem"), 15)
	b.pressed.connect(func():
		browser_id = id
		_action_bar(slot, id)
		on_pick.call(slot, id)
		for c in grid.get_children():
			var cid: String = c.get_meta("id")
			var eq := _equipped(slot)
			var st := UI.sb(UI.CARD2, 14, rc, 4)
			if cid == id:
				(c as Button).add_theme_stylebox_override("normal", st)
			elif cid == eq:
				(c as Button).add_theme_stylebox_override("normal", UI.sb(Color(0.1, 0.2, 0.15), 14, UI.OK, 4))
			else:
				var ce: Dictionary = Catalog.entry(slot, cid)
				(c as Button).add_theme_stylebox_override("normal", UI.sb(UI.CARD, 14, (Catalog.RARITY_COLOR[int(ce["r"])] as Color).darkened(0.2), 2)))
	return b


func _action_bar(slot: String, id: String) -> void:
	for c in action_box.get_children():
		c.queue_free()
	var e: Dictionary = Catalog.entry(slot, id)
	var info := UI.lbl(action_box, "%s  -  %s" % [Catalog.nm(e), Catalog.rar_name(int(e["r"]))], 20, Catalog.RARITY_COLOR[int(e["r"])], false)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var eq := _equipped(slot)
	if Profile.owns(slot, id):
		var b := UI.btn(action_box, UI.tx("Equip", "استخدم"), UI.GREEN, func(): _equip(slot, id), 22, Vector2(190, 50))
		b.disabled = id == eq
	else:
		var gem := e.has("gem")
		var cost := int(e["gem"]) if gem else int(e["price"])
		var b := UI.btn(action_box, "", UI.GOLD.darkened(0.35), func(): _buy(slot, id), 22, Vector2(230, 50))
		b.disabled = not Profile.can_afford(e)
		var ph := UI.price_row(null, cost, gem, 22)
		ph.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		ph.grow_horizontal = Control.GROW_DIRECTION_BOTH
		ph.grow_vertical = Control.GROW_DIRECTION_BOTH
		b.add_child(ph)
		b.text = ""


func _equip(slot: String, id: String) -> void:
	if Catalog.CAR_SLOTS.has(slot):
		if Profile.cars.has(g_car):
			Profile.select_car(g_car)
		Profile.equip_car_part(slot, id)
	elif slot == "emote":
		Profile.outfit["emote"] = id
		Profile.save()
	else:
		Profile.equip_outfit(slot, id)
	say(UI.tx("Equipped", "تم الاستخدام"))
	Sfx.play("click")
	_rerender()


func _buy(slot: String, id: String) -> void:
	if Profile.buy(slot, id):
		Sfx.play("success", 0.0)
		say(UI.tx("Purchased!", "تم الشراء!"))
		_equip(slot, id)
	else:
		say(UI.tx("Not enough funds", "رصيدك لا يكفي"))
		Sfx.play("warn", -6.0)


## after a purchase / equip: refresh the current tab without losing the 3D preview
func _rerender() -> void:
	if cur == "modify":
		_mod_fill()
	elif browser_box and browser_box.has_meta("fill"):
		(browser_box.get_meta("fill") as Callable).call(browser_slot)
	if preview:
		if cur in ["garage", "modify"]:
			preview.show_car(_lo_for(g_car))
		elif cur == "character":
			preview.show_avatar(Profile.outfit)
	if stat_box:
		for c in stat_box.get_children():
			c.queue_free()
		_stats(stat_box, g_car)
	_update_top()


# ====================================================================== GARAGE
const DOCK_H := 188
const MOD_SECTIONS := ["paint", "body", "mods", "wheels", "engine"]
const MOD_SUBS := {"paint": ["paint", "stripe", "decal", "glow"], "body": ["spoiler", "front", "hood", "skirts"], "mods": ["aero", "susp", "kit", "armor"], "wheels": ["wheel", "rim", "tires"], "engine": ["engine", "turbo", "exhaust", "cooling"]}
const MOD_NAMES := {"paint": ["Colour", "اللون"], "stripe": ["Stripes", "الخطوط"], "decal": ["Stickers", "الملصقات"], "glow": ["Underglow", "الإضاءة السفلية"], "rim": ["Rim colour", "لون الجنوط"], "wheel": ["Wheel design", "تصميم الجنط"],
	"spoiler": ["Rear wing", "المؤخرة"], "front": ["Front", "المقدمة"], "hood": ["Hood", "الغطاء"], "skirts": ["Sides", "الجوانب"]}
const SEC_NAMES := {"paint": ["PAINT", "الطلاء"], "body": ["BODY", "الشكل"], "mods": ["MODS", "التعديلات"], "wheels": ["WHEELS", "العجلات"], "engine": ["ENGINE", "المحرك"]}
var mod_section := "paint"
var mod_sub := {}
var _mod_chips: HBoxContainer
var _mod_strip: HBoxContainer
var _mod_tabs: HBoxContainer


func _anchor(c: Control, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = l
	c.anchor_top = t
	c.anchor_right = r
	c.anchor_bottom = b


func _tab_garage() -> Control:
	g_car = Profile.car
	var root := Control.new()
	preview = Preview3D.new()
	preview.zoom = 0.74
	root.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.offset_bottom = -(DOCK_H + 4)
	preview.ready.connect(func(): preview.show_car(_lo_for(g_car)))
	# selected car: name + description (top left) and Modify / Buy (top right)
	var ip := UI.panel(root, UI.PANEL, 12)
	ip.position = Vector2(12, 12)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 2)
	iv.custom_minimum_size = Vector2(300, 0)
	ip.add_child(iv)
	var ap := MarginContainer.new()
	root.add_child(ap)
	_anchor(ap, 1, 0, 1, 0)
	ap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ap.offset_right = -12
	ap.offset_top = 12
	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 6)
	ap.add_child(av)
	# stats: same place (bottom left of the showroom) but raised above the dock
	var sp := UI.panel(root, UI.PANEL, 12)
	_anchor(sp, 0, 1, 0, 1)
	sp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sp.offset_left = 12
	sp.offset_top = -(DOCK_H + 14)
	sp.offset_bottom = -(DOCK_H + 14)
	var sv := VBoxContainer.new()
	sv.custom_minimum_size = Vector2(380, 0)
	sv.add_theme_constant_override("separation", 4)
	sp.add_child(sv)
	UI.lbl(sv, UI.tx("CAR STATS", "قدرات السيارة"), 15, UI.TXT2, false)
	stat_box = VBoxContainer.new()
	stat_box.add_theme_constant_override("separation", 4)
	sv.add_child(stat_box)
	_stats(stat_box, g_car)
	# dock: full-width bar with every car
	var dock := PanelContainer.new()
	dock.add_theme_stylebox_override("panel", UI.sb(UI.PANEL, 0, UI.LINE, 1))
	_anchor(dock, 0, 1, 1, 1)
	dock.offset_top = -DOCK_H
	root.add_child(dock)
	var csc := TScroll.new()
	csc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dock.add_child(csc)
	var cars := HBoxContainer.new()
	cars.add_theme_constant_override("separation", 10)
	csc.add_child(cars)
	var rebuild_info := func() -> void:
		for c in iv.get_children():
			c.queue_free()
		for c in av.get_children():
			c.queue_free()
		var m: Dictionary = Catalog.CARS[g_car]
		UI.lbl(iv, Catalog.nm(m), 30, Catalog.RARITY_COLOR[int(m["r"])], false)
		UI.lbl(iv, Catalog.txt(m["d"]), 16, UI.TXT2, true)
		UI.lbl(iv, Catalog.rar_name(int(m["r"])), 14, UI.TXT2, false)
		if Profile.cars.has(g_car):
			UI.btn(av, UI.tx("MODIFY", "تعديل"), UI.ACCENT, func():
				Sfx.play("click")
				select("modify"), 24, Vector2(210, 58))
		else:
			var need := int(m["lvl"])
			var b := UI.btn(av, "", UI.GOLD.darkened(0.35), func():
				if Profile.buy_car(g_car):
					Sfx.play("success")
					say(UI.tx("New car!", "سيارة جديدة!"))
					select("garage"), 22, Vector2(210, 58))
			b.disabled = Profile.level < need or Profile.coins < int(m["price"])
			var ph := UI.price_row(null, int(m["price"]), false, 24)
			ph.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			b.add_child(ph)
			if Profile.level < need:
				UI.lbl(av, UI.tx("Level %d needed", "يحتاج مستوى %d") % need, 17, Color(1.0, 0.55, 0.45), false)
	var fill_dock: Callable
	fill_dock = func() -> void:
		for c in cars.get_children():
			c.queue_free()
		for id in Catalog.CAR_ORDER:
			cars.add_child(_car_card(id, func():
				g_car = id
				if Profile.cars.has(id):
					Profile.select_car(id)
				preview.show_car(_lo_for(id))
				rebuild_info.call()
				for c in stat_box.get_children():
					c.queue_free()
				_stats(stat_box, id)
				fill_dock.call()))
	fill_dock.call()
	rebuild_info.call()
	return root


# ====================================================================== MODIFY (paint / mods / wheels / engine)

func _sub_name(sub: String) -> String:
	if MOD_NAMES.has(sub):
		return Catalog.txt(MOD_NAMES[sub])
	if Catalog.PARTS.has(sub):
		return Catalog.txt(Catalog.PARTS[sub]["n"])
	return Catalog.txt(Catalog.UPGRADES[sub]["n"])


func _tab_modify() -> Control:
	g_car = Profile.car
	var root := Control.new()
	var bar_h := 276
	preview = Preview3D.new()
	preview.zoom = 0.74
	root.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.offset_bottom = -bar_h
	preview.ready.connect(func(): preview.show_car(_lo_for(g_car)))
	# back + title (top left)
	var tp := UI.panel(root, UI.PANEL, 12)
	tp.position = Vector2(12, 12)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 14)
	tp.add_child(th)
	UI.btn(th, UI.tx("< GARAGE", "< الكراج"), UI.CARD2, func():
		Sfx.play("click", -6.0)
		select("garage"), 18, Vector2(130, 44))
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	th.add_child(tv)
	UI.lbl(tv, UI.tx("MODIFY", "تعديل السيارة"), 13, UI.TXT2, false)
	UI.lbl(tv, Catalog.nm(Catalog.CARS[g_car]), 24, UI.TXT, false)
	# live stats (top right)
	var sp := UI.panel(root, UI.PANEL, 12)
	_anchor(sp, 1, 0, 1, 0)
	sp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	sp.offset_right = -12
	sp.offset_top = 12
	var sv := VBoxContainer.new()
	sv.custom_minimum_size = Vector2(340, 0)
	sv.add_theme_constant_override("separation", 4)
	sp.add_child(sv)
	UI.lbl(sv, UI.tx("CAR STATS", "قدرات السيارة"), 15, UI.TXT2, false)
	stat_box = VBoxContainer.new()
	stat_box.add_theme_constant_override("separation", 4)
	sv.add_child(stat_box)
	_stats(stat_box, g_car)
	# bottom: options bar (full width) + section tabs
	var bp := PanelContainer.new()
	bp.add_theme_stylebox_override("panel", UI.sb(UI.PANEL, 0, UI.LINE, 1))
	_anchor(bp, 0, 1, 1, 1)
	bp.offset_top = -bar_h
	root.add_child(bp)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 8)
	bp.add_child(bv)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.custom_minimum_size = Vector2(0, 46)
	bv.add_child(head)
	_mod_chips = HBoxContainer.new()
	_mod_chips.add_theme_constant_override("separation", 6)
	head.add_child(_mod_chips)
	action_box = HBoxContainer.new()
	action_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_box.add_theme_constant_override("separation", 10)
	head.add_child(action_box)
	var ssc := TScroll.new()
	ssc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ssc.custom_minimum_size = Vector2(0, 144)
	bv.add_child(ssc)
	_mod_strip = HBoxContainer.new()
	_mod_strip.add_theme_constant_override("separation", 10)
	ssc.add_child(_mod_strip)
	_mod_tabs = HBoxContainer.new()
	_mod_tabs.add_theme_constant_override("separation", 6)
	bv.add_child(_mod_tabs)
	for sec in MOD_SECTIONS:
		var tb := Button.new()
		tb.text = UI.tx(SEC_NAMES[sec][0], SEC_NAMES[sec][1])
		tb.custom_minimum_size = Vector2(0, 54)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.add_theme_font_size_override("font_size", 21)
		tb.set_meta("sec", sec)
		tb.pressed.connect(func():
			Sfx.play("click", -8.0)
			mod_section = sec
			_mod_fill())
		_mod_tabs.add_child(tb)
	_mod_fill()
	return root


func _mod_fill() -> void:
	for c in _mod_chips.get_children():
		c.queue_free()
	for c in _mod_strip.get_children():
		c.queue_free()
	for c in action_box.get_children():
		c.queue_free()
	for tb in _mod_tabs.get_children():
		var on: bool = tb.get_meta("sec") == mod_section
		for st in ["normal", "hover", "pressed", "focus"]:
			(tb as Button).add_theme_stylebox_override(st, UI.sb(UI.ACCENT if on else UI.CARD2, 8))
	var subs: Array = MOD_SUBS[mod_section]
	if mod_section == "body":
		subs = subs.filter(func(x): return Catalog.body_opts(g_car, x).size() > 1)
	elif mod_section == "mods" or mod_section == "engine":
		subs = subs.filter(func(x): return not Catalog.PARTS.has(x) or Catalog.has_part(g_car, x))
	var cs: String = mod_sub.get(mod_section, subs[0])
	if not subs.has(cs):
		cs = subs[0]
	mod_sub[mod_section] = cs
	for sname in subs:
		var on: bool = sname == cs
		var b := UI.btn(_mod_chips, _sub_name(sname), UI.ACCENT if on else UI.CARD2, func():
			mod_sub[mod_section] = sname
			_mod_fill(), 18, Vector2(0, 42))
		b.add_theme_stylebox_override("normal", UI.sb(UI.ACCENT if on else UI.CARD2, 8))
	if Catalog.CAR_SLOTS.has(cs):
		_mod_cosmetics(cs)
	elif Catalog.PARTS.has(cs):
		_mod_tiers(cs)
	else:
		_mod_level(cs)


func _mod_cosmetics(slot: String) -> void:
	var eq := _equipped(slot)
	browser_slot = slot
	browser_id = eq
	var ids: Array = Catalog.CAR_SLOT_ORDER[slot]
	if Catalog.BODY_SLOTS.has(slot):
		ids = Catalog.body_opts(g_car, slot)
	elif slot == "wheel":
		ids = Catalog.wheel_opts(g_car)
	for id in ids:
		var cell := _item_cell(slot, id, eq, func(sl: String, i: String):
			preview.show_car(_lo_for(g_car, {sl: i})), _mod_strip)
		cell.size_flags_horizontal = Control.SIZE_FILL
		cell.custom_minimum_size = Vector2(196 if slot != "rim" else 150, 136)
		_mod_strip.add_child(cell)
	_action_bar(slot, eq)


## a card with title / effect / button used for parts and levels. kind: install | remove | buy | max
func _mod_cell(title: String, effect: String, kind: String, price: int, cb: Callable, fitted := false, wide := false, pips := -1) -> void:
	var cell := UI.panel(_mod_strip, UI.CARD2 if not fitted else Color(0.1, 0.2, 0.15), 12)
	cell.custom_minimum_size = Vector2(280 if wide else 236, 126)
	if fitted:
		cell.add_theme_stylebox_override("panel", UI.sb(Color(0.1, 0.2, 0.15), 12, UI.OK, 2))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	cell.add_child(v)
	var tl := UI.lbl(v, title, 16, UI.TXT, false)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.lbl(v, effect, 18, UI.ACCENT, false)
	if pips >= 0:
		var ph := HBoxContainer.new()
		ph.add_theme_constant_override("separation", 4)
		v.add_child(ph)
		for i in Catalog.MAX_UP:
			var r := ColorRect.new()
			r.custom_minimum_size = Vector2(28, 8)
			r.color = UI.OK if i < pips else Color(1, 1, 1, 0.14)
			ph.add_child(r)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	match kind:
		"max":
			var m := UI.lbl(v, UI.tx("MAX", "الحد الأقصى"), 18, UI.GOLD, false)
			m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		"remove":
			UI.btn(v, UI.tx("Remove", "إزالة"), UI.BLUE, cb, 17, Vector2(0, 38))
		"install":
			UI.btn(v, UI.tx("Install", "تركيب"), UI.GREEN, cb, 17, Vector2(0, 38))
		_:
			var b := UI.btn(v, "", UI.GOLD.darkened(0.35), cb, 17, Vector2(0, 38))
			b.disabled = Profile.coins < price
			var ph2 := UI.price_row(null, price, false, 17)
			ph2.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			b.add_child(ph2)


func _mod_tiers(slot: String) -> void:
	var pd: Dictionary = Catalog.PARTS[slot]
	var names: Array = Catalog.part_tier_names(g_car, slot)
	var up: Dictionary = Profile.up.get(g_car, {})
	var fitted := int(up.get("fit_" + slot, 0))
	UI.lbl(action_box, Catalog.txt(pd["d"]) + ("" if fitted == 0 else "  -  " + UI.tx("Fitted: ", "مركّب: ") + (str(names[fitted - 1]) if names.size() >= fitted else Catalog.txt(pd["tiers"][fitted - 1]))), 18, UI.TXT2 if fitted == 0 else UI.OK, false)
	for ti in 3:
		var tier := ti + 1
		var pct := int(round(float(pd["v"][ti]) * 100.0))
		var eff := ("-%d%% " + UI.tx("damage", "ضرر")) % pct if pd["stat"] == "armor" else "+%d%%" % pct
		var price := int(pd["price"][ti])
		var kind := "buy"
		var cb: Callable
		if fitted == tier:
			kind = "remove"
			cb = func():
				Profile.install_part(g_car, slot, 0)
				Sfx.play("click")
				_rerender()
		elif Profile.part_owned(slot, tier):
			kind = "install"
			cb = func():
				Profile.install_part(g_car, slot, tier)
				Sfx.play("success", -4.0)
				say(UI.tx("Installed!", "تم التركيب!"))
				_rerender()
		else:
			cb = func():
				if Profile.buy_part(slot, tier):
					Sfx.play("success", -2.0)
					say(UI.tx("Bought and installed!", "تم الشراء والتركيب!"))
					_rerender()
				else:
					say(UI.tx("Not enough coins", "العملات لا تكفي"))
		_mod_cell(str(names[ti]) if names.size() > ti else Catalog.txt(pd["tiers"][ti]), eff, kind, price, cb, fitted == tier)


func _mod_level(key: String) -> void:
	var u: Dictionary = Catalog.UPGRADES[key]
	var lv := Profile.up_level(g_car, key)
	var tk: Dictionary = Catalog.tech(g_car)
	var stages: Array = tk["stages"] if key == "engine" else []
	var head := Catalog.txt(u["d"])
	if key == "engine":
		head = str(tk["engine"]) + (("  -  " + UI.tx("Stage ", "المرحلة ") + str(lv) + ": " + str(stages[lv - 1])) if lv > 0 else "")
	UI.lbl(action_box, head, 18, UI.TXT2, false)
	if lv >= Catalog.MAX_UP:
		_mod_cell((str(stages[lv - 1]) if key == "engine" else Catalog.txt(u["n"])) + "  " + str(lv) + "/" + str(Catalog.MAX_UP), UI.tx("Fully upgraded", "مطوّر بالكامل"), "max", 0, func(): pass, false, true, lv)
		return
	var cost := Catalog.upgrade_cost(key, lv)
	_mod_cell((str(stages[lv]) if key == "engine" else Catalog.txt(u["n"])) + "  " + str(lv) + "/" + str(Catalog.MAX_UP), UI.tx("Next level", "المستوى التالي") + "  " + str(lv + 1), "buy", cost, func():
		if Profile.upgrade(g_car, key):
			Sfx.play("success", -2.0)
			say(UI.tx("Upgraded!", "تمت الترقية!"))
			_rerender()
		else:
			say(UI.tx("Not enough coins", "العملات لا تكفي")), false, true, lv)


func _car_card(id: String, cb: Callable) -> Control:
	var m: Dictionary = Catalog.CARS[id]
	var rc: Color = Catalog.RARITY_COLOR[int(m["r"])]
	var owned := Profile.cars.has(id)
	var cur_car := id == g_car
	var b := Button.new()
	b.custom_minimum_size = Vector2(236, 160)
	var n := UI.sb(UI.CARD, 12, UI.ACCENT if cur_car else Color(1, 1, 1, 0.08), 3 if cur_car else 1)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", UI.sb(UI.CARD2, 12, UI.ACCENT, 2))
	b.add_theme_stylebox_override("pressed", UI.sb(UI.CARD2, 12, UI.ACCENT, 3))
	b.add_theme_stylebox_override("focus", n)
	b.pressed.connect(cb)
	UI.pop(b, 1.03)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 8
	vb.offset_right = -8
	vb.offset_top = 6
	vb.offset_bottom = -6
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 1)
	b.add_child(vb)
	var cs: Dictionary = Profile.car_set(id)
	var art := HubArt.CarArt.new()
	art.model = id
	art.paint = Catalog.PAINTS[cs["paint"]]["c"]
	art.rim = Catalog.RIMS[cs["rim"]]["c"]
	art.wheel_style = Catalog.wheel_style(id, str(cs["wheel"]))
	art.locked = not owned
	art.custom_minimum_size = Vector2(0, 84)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(art)
	var t := UI.lbl(vb, Catalog.nm(m), 15, UI.TXT, false)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.clip_text = true
	# mini power / speed bars
	for spec in [[float(m["power"]) / 1.5, UI.ACCENT], [float(m["top"]) / 230.0, Color(0.55, 0.62, 0.78)]]:
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 5)
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.value = clampf(float(spec[0]), 0.0, 1.0)
		bar.add_theme_stylebox_override("background", UI.sb(Color(1, 1, 1, 0.08), 3))
		bar.add_theme_stylebox_override("fill", UI.sb(spec[1] if owned else Color(0.4, 0.43, 0.5), 3))
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(bar)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(foot)
	var dot := ColorRect.new()
	dot.color = rc
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(dot)
	var st := (UI.tx("IN USE", "قيد الاستخدام") if id == Profile.car else UI.tx("OWNED", "مملوكة")) if owned else (UI.tx("Lv ", "م ") + str(m["lvl"]) + "  ·  " + str(m["price"]))
	var sl := UI.lbl(foot, "  " + st, 13, UI.TXT2 if owned or Profile.level >= int(m["lvl"]) else Color(1.0, 0.6, 0.45), false)
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


# ====================================================================== CHARACTER

func _tab_character() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(360, 0)
	left.add_theme_constant_override("separation", 8)
	h.add_child(left)
	preview = Preview3D.new()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(preview)
	preview.ready.connect(func(): preview.show_avatar(Profile.outfit))
	UI.btn(left, UI.tx("Play my emote", "شغّل حركتي"), Color(0.6, 0.3, 0.85), func(): preview.play_emote(str(Profile.outfit.get("emote", "wave"))), 22, Vector2(0, 52))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	var br := _browser(Catalog.OUTFIT_ORDER + ["emote"], func(slot: String, id: String):
		if slot == "emote":
			preview.play_emote(id)
		else:
			var o: Dictionary = Profile.outfit.duplicate()
			o[slot] = id
			preview.show_avatar(o))
	right.add_child(br)
	return h


# ====================================================================== SHOP

func _pack_section(vb: VBoxContainer, title: String, list: Array, gems: bool) -> void:
	UI.lbl(vb, title, 28, Color(0.55, 0.92, 1.0) if gems else UI.GOLD, false)
	var packs := HBoxContainer.new()
	packs.add_theme_constant_override("separation", 10)
	vb.add_child(packs)
	for pk in list:
		var pp := UI.panel(packs, UI.CARD, 16)
		pp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var best: bool = str(pk["tag"]) != ""
		if best:
			pp.add_theme_stylebox_override("panel", UI.sb(UI.CARD, 16, UI.GOLD, 2))
		var pv := VBoxContainer.new()
		pv.add_theme_constant_override("separation", 4)
		pp.add_child(pv)
		var tg := UI.lbl(pv, UI.tx("BEST VALUE", "الأفضل قيمة") if pk["tag"] == "best" else (UI.tx("POPULAR", "الأكثر شراء") if pk["tag"] == "popular" else " "), 13, UI.GOLD, false)
		tg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var cs := Checkout.CoinStack.new(gems)
		pv.add_child(cs)
		var cn := UI.lbl(pv, "%d" % int(pk["amount"]), 26, Color(0.55, 0.92, 1.0) if gems else Color(1.0, 0.86, 0.35), false)
		cn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var bn := UI.lbl(pv, str(pk["bonus"]) if str(pk["bonus"]) != "" else " ", 15, UI.OK, false)
		bn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var pid: String = pk["id"]
		UI.btn(pv, "$" + str(pk["price"]), UI.ACCENT, func():
			Sfx.play("click", -6.0)
			Checkout.open(self, Billing.pack(pid)), 20, Vector2(0, 46))


func _tab_shop() -> Control:
	var sc := TScroll.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 12)
	sc.add_child(vb)
	_pack_section(vb, UI.tx("COINS", "العملات"), Billing.COIN_PACKS, false)
	_pack_section(vb, UI.tx("GEMS", "الجواهر"), Billing.GEM_PACKS, true)
	UI.lbl(vb, UI.tx("DAILY DEALS  -30%", "عروض اليوم  -30%"), 28, UI.GOLD, false)
	var deals := HBoxContainer.new()
	deals.add_theme_constant_override("separation", 12)
	vb.add_child(deals)
	for it in Profile.daily_deals():
		var e: Dictionary = Catalog.entry(it["slot"], it["id"])
		var rc: Color = Catalog.RARITY_COLOR[int(e["r"])]
		var p := UI.panel(deals, UI.CARD, 18)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		p.add_child(v)
		var col: Color = e["c"] if e.has("c") and e["c"] != Color.TRANSPARENT else rc
		v.add_child(UI.Glyph.new(it["slot"], col))
		var nm := UI.lbl(v, Catalog.nm(e), 18, rc.lightened(0.3), true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UI.lbl(v, Catalog.txt(Catalog.SLOT_NAME[it["slot"]]), 14, UI.TXT2, false).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var cost := int(int(e["price"]) * 0.7)
		var b := UI.btn(v, "", UI.GOLD.darkened(0.35), func():
			if Profile.buy_deal(it):
				Sfx.play("success")
				say(UI.tx("Purchased! Equip it in the garage / character tab.", "تم الشراء! استخدمه من الكراج أو الشخصية."))
				select("shop")
			else:
				say(UI.tx("Not enough coins", "العملات لا تكفي")), 20, Vector2(0, 48))
		b.disabled = Profile.coins < cost
		var ph := UI.price_row(null, cost, false, 20)
		ph.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		b.add_child(ph)
	if Profile.daily_deals().is_empty():
		UI.lbl(vb, UI.tx("You own everything on sale today!", "تملك كل عروض اليوم!"), 20, UI.TXT2)
	UI.lbl(vb, UI.tx("CHESTS", "الصناديق"), 28, UI.GOLD, false)
	var chs := HBoxContainer.new()
	chs.add_theme_constant_override("separation", 12)
	vb.add_child(chs)
	for kind in ["bronze", "silver", "gold"]:
		var cd: Dictionary = Catalog.CHESTS[kind]
		var p := UI.panel(chs, UI.CARD, 18)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		p.add_child(v)
		var cv := HubArt.ChestBox.new()
		cv.tier = cd["c"]
		cv.custom_minimum_size = Vector2(0, 100)
		v.add_child(cv)
		var nm := UI.lbl(v, Catalog.txt(cd["n"]), 20, cd["c"], false)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var odds := "%d%% / %d%% / %d%% / %d%%" % [cd["w"][0], cd["w"][1], cd["w"][2], cd["w"][3]]
		UI.lbl(v, odds, 13, UI.TXT2, false).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var gem := cd.has("gem")
		var b := UI.btn(v, "", UI.GREEN, func():
			if Profile.buy_chest(kind):
				Sfx.play("success")
				say(UI.tx("Chest added - open it in CHESTS", "أُضيف صندوق - افتحه من الصناديق"))
			else:
				say(UI.tx("Not enough funds", "رصيدك لا يكفي")), 20, Vector2(0, 48))
		var cost := int(cd["gem"]) if gem else int(cd["coins"])
		b.disabled = (Profile.gems < cost) if gem else (Profile.coins < cost)
		var ph := UI.price_row(null, cost, gem, 20)
		ph.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		b.add_child(ph)
	UI.lbl(vb, UI.tx("Rarity odds: common / rare / epic / legendary", "نسب الندرة: عادي / نادر / ملحمي / أسطوري"), 14, UI.TXT2)
	return sc


# ====================================================================== QUESTS

func _tab_quests() -> Control:
	Profile.refresh_quests()
	var sc := TScroll.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 10)
	sc.add_child(vb)
	# daily login
	var lp := UI.panel(vb, UI.CARD, 18)
	var lv := VBoxContainer.new()
	lp.add_child(lv)
	var got: bool = Profile.login["last"] == Time.get_date_string_from_system()
	UI.lbl(lv, UI.tx("DAILY LOGIN BONUS  -  streak %d", "مكافأة الدخول اليومية  -  أيام متتالية %d") % int(Profile.login["streak"]), 24, UI.GOLD, false)
	var days := HBoxContainer.new()
	days.add_theme_constant_override("separation", 6)
	lv.add_child(days)
	var cur_day := (int(Profile.login["streak"]) - 1) % 7 + 1 if int(Profile.login["streak"]) > 0 else 0
	for d in range(1, 8):
		var cell := UI.panel(days, Color(0.18, 0.45, 0.3) if (d < cur_day or (d == cur_day and got)) else UI.CARD, 12)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := VBoxContainer.new()
		cell.add_child(cv)
		UI.lbl(cv, UI.tx("Day %d", "يوم %d") % d, 14, UI.TXT2, false).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UI.price_row(cv, 200 + d * 100, false, 16)
		if d == 7:
			UI.lbl(cv, UI.tx("+chest", "+صندوق"), 13, UI.GOLD, false).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not got:
		UI.btn(lv, UI.tx("Collect today's bonus", "استلم مكافأة اليوم"), UI.GREEN, func():
			var r := Profile.daily_login()
			if not r.is_empty():
				Sfx.play("success")
				say("+%d %s" % [int(r["coins"]), UI.tx("coins", "عملة")])
			select("quests"), 24, Vector2(0, 52))
	# quests
	UI.lbl(vb, UI.tx("DAILY QUESTS  (new ones every day)", "مهام اليوم  (جديدة كل يوم)"), 26, UI.GOLD, false)
	for i in (Profile.quests["list"] as Array).size():
		var q: Dictionary = Profile.quests["list"][i]
		var d := Profile.quest_def(q["id"])
		var row := UI.panel(vb, UI.CARD, 16)
		var rh := HBoxContainer.new()
		rh.add_theme_constant_override("separation", 14)
		row.add_child(rh)
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rh.add_child(tv)
		UI.lbl(tv, Catalog.txt(d["t"]), 22, Color.WHITE)
		var pb := ProgressBar.new()
		pb.custom_minimum_size = Vector2(0, 16)
		pb.max_value = int(d["n"])
		pb.value = int(q["p"])
		pb.show_percentage = false
		pb.add_theme_stylebox_override("fill", UI.sb(Color(0.3, 0.85, 0.5), 8))
		pb.add_theme_stylebox_override("background", UI.sb(Color(1, 1, 1, 0.12), 8))
		tv.add_child(pb)
		UI.lbl(tv, "%d / %d    +%d  +%d XP" % [int(q["p"]), int(d["n"]), int(d["coins"]), int(d["xp"])], 15, UI.TXT2, false)
		var done := Profile.quest_done(i)
		var b := UI.btn(rh, UI.tx("Claimed", "تم الاستلام") if q["claimed"] else UI.tx("Claim", "استلم"), UI.GREEN, func():
			if Profile.claim_quest(i):
				Sfx.play("success")
				say(UI.tx("Reward collected!", "تم استلام الجائزة!"))
				select("quests"), 22, Vector2(170, 56))
		b.disabled = q["claimed"] or not done
	UI.lbl(vb, UI.tx("Finish all 3 quests to win a SILVER chest!", "أنهِ المهام الثلاث واربح صندوقاً فضياً!"), 18, UI.TXT2)
	# next level rewards
	var nr := Catalog.level_reward(Profile.level + 1)
	UI.lbl(vb, UI.tx("Next level reward: %d coins%s", "جائزة المستوى القادم: %d عملة%s") % [int(nr["coins"]), (" + " + UI.tx("wooden chest", "صندوق خشبي") + (" + " + UI.tx("silver chest", "صندوق فضي") if (nr["kinds"] as Array).has("silver") else "") + (" + " + UI.tx("GOLD chest (legendary)", "صندوق ذهبي (أسطوري)") if (nr["kinds"] as Array).has("gold") else ""))], 18, UI.TXT2)
	return sc


# ====================================================================== CHESTS

func _tab_chests() -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	UI.lbl(vb, UI.tx("YOUR CHESTS", "صناديقك"), 30, UI.GOLD, false)
	UI.lbl(vb, UI.tx("Win races, finish quests and level up to earn chests. Legendary items can only come from chests or the gem shop!", "اربح السباقات وأنهِ المهام وارتقِ بالمستويات لتحصل على صناديق. العناصر الأسطورية من الصناديق أو بالجواهر فقط!"), 17, UI.TXT2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	vb.add_child(row)
	var any := false
	for kind in ["bronze", "silver", "gold"]:
		var n := int(Profile.chests.get(kind, 0))
		var cd: Dictionary = Catalog.CHESTS[kind]
		var p := UI.panel(row, UI.CARD, 18)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		p.add_child(v)
		var art := HubArt.ChestBox.new()
		art.tier = cd["c"]
		art.custom_minimum_size = Vector2(0, 130)
		v.add_child(art)
		UI.lbl(v, "%s  x%d" % [Catalog.txt(cd["n"]), n], 22, cd["c"], false).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var b := UI.btn(v, UI.tx("OPEN", "افتح"), UI.GREEN, func(): _open_chest(kind, art), 24, Vector2(0, 54))
		b.disabled = n <= 0
		any = any or n > 0
	if not any:
		UI.lbl(vb, UI.tx("No chests right now - go race!", "ما عندك صناديق الحين - روح تسابق!"), 20, UI.TXT2)
	return vb


func _open_chest(kind: String, art: Control) -> void:
	var res := Profile.open_chest(kind)
	if res.is_empty():
		return
	var rar := 0
	if res.has("item"):
		rar = int(res["item"]["rar"])
	var rc: Color = Catalog.RARITY_COLOR[rar]
	var ov := ColorRect.new()
	ov.color = Color(0.02, 0.025, 0.035, 0.0)
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.z_index = 30
	add_child(ov)
	create_tween().tween_property(ov, "color:a", 0.92, 0.25)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(v)
	var big := HubArt.ChestBox.new()
	big.tier = Catalog.CHESTS[kind]["c"]
	big.burst = rc.lightened(0.25)
	big.idle = false
	big.custom_minimum_size = Vector2(320, 210)
	v.add_child(big)
	# 1) the chest charges up and shakes harder and harder
	var tw := create_tween()
	tw.tween_property(big, "shake", 0.4, 0.5)
	tw.parallel().tween_property(big, "charge", 0.6, 0.5)
	tw.tween_callback(func(): Sfx.play("clang", -2.0, 0.8))
	tw.tween_property(big, "shake", 1.0, 0.5)
	tw.parallel().tween_property(big, "charge", 1.0, 0.5)
	tw.tween_callback(func(): Sfx.play("clang", 0.0, 1.3))
	tw.tween_property(big, "shake", 0.0, 0.08)
	# 2) the lid snaps open with a flash
	tw.tween_property(big, "open", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	Sfx.play("success", 3.0)
	var fl := ColorRect.new()
	fl.color = Color(rc.r, rc.g, rc.b, 0.5 + 0.12 * rar)
	fl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(fl)
	create_tween().tween_property(fl, "color:a", 0.0, 0.6)
	# 3) reward card slides up
	var card := UI.panel(null, UI.CARD, 14)
	card.custom_minimum_size = Vector2(380, 0)
	card.add_theme_stylebox_override("panel", UI.sb(UI.CARD, 14, rc, 2))
	v.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	card.add_child(cv)
	var tag := UI.lbl(cv, Catalog.rar_name(rar).to_upper(), 16, rc, false)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := UI.lbl(cv, UI.tx("Bonus", "مكافأة"), 30, UI.TXT, false)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if res.has("item"):
		var it: Dictionary = res["item"]
		var e := Catalog.entry(it["slot"], it["id"])
		title.text = Catalog.nm(e)
		var col: Color = e["c"] if e.has("c") and e["c"] != Color.TRANSPARENT else rc
		if Catalog.CAR_SLOTS.has(it["slot"]):
			var sw := HubArt.SwatchArt.new()
			sw.slot = it["slot"]
			sw.model = Profile.car
			sw.kit_id = it["id"]
			sw.col = col
			sw.metal = float(e.get("m", 0.0))
			sw.rough = float(e.get("ro", 0.5))
			sw.txt = str(e.get("t", ""))
			sw.bg = e.get("bg", Color.BLACK)
			sw.base = Catalog.PAINTS[Profile.car_set()["paint"]]["c"]
			sw.custom_minimum_size = Vector2(0, 80)
			cv.add_child(sw)
		else:
			var g := UI.Glyph.new(it["slot"], col)
			g.custom_minimum_size = Vector2(0, 80)
			cv.add_child(g)
		UI.lbl(cv, Catalog.txt(Catalog.SLOT_NAME[it["slot"]]), 16, UI.TXT2, false).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ex := "+%d %s" % [int(res["coins"]), UI.tx("coins", "عملة")]
	if int(res["gems"]) > 0:
		ex += "     +%d %s" % [int(res["gems"]), UI.tx("gems", "جوهرة")]
	UI.lbl(cv, ex, 22, UI.TXT, false).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.btn(v, UI.tx("Collect", "استلم"), UI.GREEN, func():
		ov.queue_free()
		select("chests"), 24, Vector2(0, 56))
	card.modulate.a = 0.0
	create_tween().tween_property(card, "modulate:a", 1.0, 0.35)
	card.pivot_offset = Vector2(190, 80)
	card.scale = Vector2(0.85, 0.85)
	create_tween().tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
