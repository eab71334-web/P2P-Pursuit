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
		custom_minimum_size = Vector2(64, 64)

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 30.0, Color(0.12, 0.14, 0.3))
		draw_arc(c, 30.0, 0.0, TAU, 40, UI.GOLD, 4.0)
		draw_arc(c, 24.0, t, t + 1.2, 12, Color(1, 0.9, 0.5, 0.7), 3.0)
		var f := ThemeDB.fallback_font
		var s := str(level)
		var sz := f.get_string_size(s, HORIZONTAL_ALIGNMENT_CENTER, -1, 28)
		draw_string(f, c + Vector2(-sz.x * 0.5, 10), s, HORIZONTAL_ALIGNMENT_CENTER, -1, 28, UI.GOLD)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Profile.changed.connect(_update_top)
	Profile.leveled.connect(func(lv: int, r: Dictionary): _pending_levelups.append([lv, r]))
	_build()
	select(tab_ids[0])


func _build() -> void:
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)
	# ---- top bar
	var top := UI.panel(vb, Color(0.05, 0.06, 0.14, 0.9), 18)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 14)
	top.add_child(th)
	if in_room:
		UI.btn(th, UI.tx("< Back to room", "< رجوع للغرفة"), UI.BLUE, func(): closed.emit(), 22, Vector2(200, 50))
	var badge := LevelBadge.new()
	badge.name = "badge"
	th.add_child(badge)
	var xv := VBoxContainer.new()
	xv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xv.alignment = BoxContainer.ALIGNMENT_CENTER
	th.add_child(xv)
	lv_label = UI.lbl(xv, "", 20, UI.GOLD, false)
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(0, 14)
	xp_bar.show_percentage = false
	xp_bar.add_theme_stylebox_override("fill", UI.sb(UI.GOLD, 7))
	xp_bar.add_theme_stylebox_override("background", UI.sb(Color(1, 1, 1, 0.12), 7))
	xv.add_child(xp_bar)
	xp_label = UI.lbl(xv, "", 14, UI.TXT2, false)
	var cp := UI.panel(th, Color(0.1, 0.12, 0.25), 14)
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 6)
	cp.add_child(ch)
	ch.add_child(UI.Coin.new(false))
	coin_label = UI.lbl(ch, "0", 24, Color.WHITE, false)
	var gp := UI.panel(th, Color(0.1, 0.12, 0.25), 14)
	var gh := HBoxContainer.new()
	gh.add_theme_constant_override("separation", 6)
	gp.add_child(gh)
	gh.add_child(UI.Coin.new(true))
	gem_label = UI.lbl(gh, "0", 24, Color.WHITE, false)
	# ---- content
	content = Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.clip_contents = true
	vb.add_child(content)
	# ---- nav
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	vb.add_child(nav)
	var names := {"play": ["PLAY", "العب"], "garage": ["GARAGE", "الكراج"], "workshop": ["WORKSHOP", "الورشة"], "character": ["CHARACTER", "الشخصية"],
		"shop": ["SHOP", "المتجر"], "quests": ["QUESTS", "المهام"], "chests": ["CHESTS", "الصناديق"]}
	var cols := {"play": Color(0.15, 0.6, 0.3), "garage": Color(0.2, 0.45, 0.9), "workshop": Color(0.9, 0.5, 0.1), "character": Color(0.7, 0.3, 0.85),
		"shop": Color(0.9, 0.7, 0.1), "quests": Color(0.2, 0.75, 0.75), "chests": Color(0.85, 0.3, 0.4)}
	for id in tab_ids:
		var b := UI.btn(nav, UI.tx(names[id][0], names[id][1]), cols[id], select.bind(id), 21, Vector2(0, 50))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = false
		nav_btns[id] = b
	toast = UI.lbl(self, "", 26, Color.WHITE, false)
	toast.add_theme_stylebox_override("normal", UI.sb(Color(0, 0, 0, 0.82), 20))
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast.position.y -= 120
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.modulate.a = 0.0
	toast.z_index = 20
	_update_top()


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
		(nav_btns[k] as Button).modulate = Color(1, 1, 1) if k == id else Color(0.72, 0.74, 0.82)
	var p: Control
	match id:
		"play":
			p = play_content
			if p.get_parent():
				p.get_parent().remove_child(p)
		"garage":
			p = _tab_garage()
		"workshop":
			p = _tab_workshop()
		"character":
			p = _tab_character()
		"shop":
			p = _tab_shop()
		"quests":
			p = _tab_quests()
		"chests":
			p = _tab_chests()
	content.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.modulate.a = 0.0
	create_tween().tween_property(p, "modulate:a", 1.0, 0.2)


func _scroll(parent: Node) -> ScrollContainer:
	var sc := ScrollContainer.new()
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
	var power := float(m["power"]) * (1.0 + 0.06 * int(up.get("engine", 0)))
	var top := float(m["top"]) * (1.0 + 0.03 * int(up.get("engine", 0)))
	var grip := float(m["grip"]) * (1.0 + 0.05 * int(up.get("tires", 0)))
	var tough := 1.0 / (float(m["armor"]) * (1.0 - 0.08 * int(up.get("armor", 0))))
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
	var lo := {"car": car_id, "paint": cs["paint"], "stripe": cs["stripe"], "rim": cs["rim"], "glow": cs["glow"], "up": Profile.up.get(car_id, {}), "outfit": Profile.outfit}
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
	var tsc := ScrollContainer.new()
	tsc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tsc.custom_minimum_size = Vector2(0, 52)
	tsc.add_child(tabs)
	vb.add_child(tsc)
	var grid_sc := _scroll(vb)
	var grid := GridContainer.new()
	grid.columns = 4
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
		var b := UI.btn(tabs, Catalog.txt(Catalog.SLOT_NAME[s]), Color(0.2, 0.24, 0.45), func(): fill.call(s), 20, Vector2(0, 46))
		b.set_meta("slot", s)
	browser_box = vb
	vb.set_meta("fill", fill)
	fill.call(slots[0])
	return vb


func _equipped(slot: String) -> String:
	if slot == "emote":
		return str(Profile.outfit.get("emote", "wave"))
	if Catalog.CAR_SLOTS.has(slot):
		return str(Profile.car_set(g_car if cur == "garage" else Profile.car)[slot])
	return str(Profile.outfit.get(slot, Catalog.DEFAULT_OUTFIT[slot]))


func _item_cell(slot: String, id: String, equipped: String, on_pick: Callable, grid: Control) -> Control:
	var e: Dictionary = Catalog.entry(slot, id)
	var rar := int(e["r"])
	var rc: Color = Catalog.RARITY_COLOR[rar]
	var owned := Profile.owns(slot, id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(150, 118)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := UI.sb(Color(0.1, 0.12, 0.24), 14, rc.darkened(0.2), 2)
	var sel := UI.sb(Color(0.16, 0.2, 0.38), 14, rc, 4)
	b.add_theme_stylebox_override("normal", n if id != equipped else UI.sb(Color(0.12, 0.28, 0.2), 14, Color(0.3, 1.0, 0.5), 4))
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
			var st := UI.sb(Color(0.16, 0.2, 0.38), 14, rc, 4)
			if cid == id:
				(c as Button).add_theme_stylebox_override("normal", st)
			elif cid == eq:
				(c as Button).add_theme_stylebox_override("normal", UI.sb(Color(0.12, 0.28, 0.2), 14, Color(0.3, 1.0, 0.5), 4))
			else:
				var ce: Dictionary = Catalog.entry(slot, cid)
				(c as Button).add_theme_stylebox_override("normal", UI.sb(Color(0.1, 0.12, 0.24), 14, (Catalog.RARITY_COLOR[int(ce["r"])] as Color).darkened(0.2), 2)))
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
		Profile.select_car(g_car) if cur == "garage" else null
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
	if browser_box and browser_box.has_meta("fill"):
		(browser_box.get_meta("fill") as Callable).call(browser_slot)
	if preview:
		if cur in ["garage", "workshop"]:
			preview.show_car(_lo_for(g_car if cur == "garage" else Profile.car))
		elif cur == "character":
			preview.show_avatar(Profile.outfit)
	if stat_box:
		for c in stat_box.get_children():
			c.queue_free()
		_stats(stat_box, g_car if cur == "garage" else Profile.car)
	_update_top()


# ====================================================================== GARAGE

func _tab_garage() -> Control:
	g_car = Profile.car
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	# left: showroom
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(440, 0)
	left.add_theme_constant_override("separation", 8)
	h.add_child(left)
	preview = Preview3D.new()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(preview)
	var sp := UI.panel(left)
	stat_box = VBoxContainer.new()
	stat_box.add_theme_constant_override("separation", 4)
	sp.add_child(stat_box)
	# right
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	h.add_child(right)
	var csc := ScrollContainer.new()
	csc.custom_minimum_size = Vector2(0, 124)
	csc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(csc)
	var cars := HBoxContainer.new()
	cars.add_theme_constant_override("separation", 8)
	csc.add_child(cars)
	var info := HBoxContainer.new()
	right.add_child(info)
	var rebuild_info := func() -> void:
		for c in info.get_children():
			c.queue_free()
		var m: Dictionary = Catalog.CARS[g_car]
		var t := UI.lbl(info, "%s   -   %s" % [Catalog.nm(m), Catalog.txt(m["d"])], 20, Catalog.RARITY_COLOR[int(m["r"])], false)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not Profile.cars.has(g_car):
			var need := int(m["lvl"])
			var b := UI.btn(info, "", UI.GOLD.darkened(0.35), func():
				if Profile.buy_car(g_car):
					Sfx.play("success")
					say(UI.tx("New car!", "سيارة جديدة!"))
					select("garage"), 22, Vector2(250, 48))
			b.disabled = Profile.level < need or Profile.coins < int(m["price"])
			var ph := UI.price_row(null, int(m["price"]), false, 22)
			ph.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			b.add_child(ph)
			if Profile.level < need:
				UI.lbl(info, UI.tx("Level %d needed", "يحتاج مستوى %d") % need, 18, Color(1.0, 0.55, 0.45), false)
	for id in Catalog.CAR_ORDER:
		cars.add_child(_car_card(id, func():
			g_car = id
			if Profile.cars.has(id):
				Profile.select_car(id)
			preview.show_car(_lo_for(id))
			(rebuild_info as Callable).call()
			for c in stat_box.get_children():
				c.queue_free()
			_stats(stat_box, id)
			if browser_box:
				(browser_box.get_meta("fill") as Callable).call(browser_slot)))
	rebuild_info.call()
	var br := _browser(["paint", "stripe", "rim", "glow"], func(slot: String, id: String):
		preview.show_car(_lo_for(g_car, {slot: id})))
	right.add_child(br)
	_stats(stat_box, g_car)
	preview.ready.connect(func(): preview.show_car(_lo_for(g_car)))
	return h


func _car_card(id: String, cb: Callable) -> Control:
	var m: Dictionary = Catalog.CARS[id]
	var rc: Color = Catalog.RARITY_COLOR[int(m["r"])]
	var owned := Profile.cars.has(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(140, 112)
	var n := UI.sb(Color(0.1, 0.12, 0.24), 16, rc if id == Profile.car else rc.darkened(0.4), 4 if id == Profile.car else 2)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", UI.sb(Color(0.17, 0.2, 0.38), 16, rc, 4))
	b.add_theme_stylebox_override("pressed", UI.sb(Color(0.17, 0.2, 0.38), 16, rc, 4))
	b.add_theme_stylebox_override("focus", n)
	b.pressed.connect(cb)
	UI.pop(b, 1.05)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(vb)
	var cs: Dictionary = Profile.car_set(id)
	vb.add_child(UI.Glyph.new("paint", Catalog.PAINTS[cs["paint"]]["c"] if owned else Color(0.35, 0.37, 0.45)))
	var t := UI.lbl(vb, Catalog.nm(m), 15, rc.lightened(0.3), true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var s := UI.lbl(vb, UI.tx("OWNED", "مملوكة") if owned else (UI.tx("Lv ", "م ") + str(m["lvl"])), 14, UI.TXT2 if owned else Color(1.0, 0.7, 0.5), false)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b


# ====================================================================== WORKSHOP

func _tab_workshop() -> Control:
	g_car = Profile.car
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(440, 0)
	left.add_theme_constant_override("separation", 8)
	h.add_child(left)
	preview = Preview3D.new()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(preview)
	preview.ready.connect(func(): preview.show_car(_lo_for(Profile.car)))
	var sp := UI.panel(left)
	stat_box = VBoxContainer.new()
	stat_box.add_theme_constant_override("separation", 4)
	sp.add_child(stat_box)
	_stats(stat_box, Profile.car)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	h.add_child(right)
	UI.lbl(right, "%s  -  %s" % [UI.tx("Upgrade your", "طوّر"), Catalog.nm(Catalog.CARS[Profile.car])], 26, UI.GOLD, false)
	var sc := _scroll(right)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	sc.add_child(list)
	for key in Catalog.UPGRADE_ORDER:
		var u: Dictionary = Catalog.UPGRADES[key]
		var lv := Profile.up_level(Profile.car, key)
		var row := UI.panel(list, Color(0.09, 0.11, 0.23, 0.95), 16)
		var rh := HBoxContainer.new()
		rh.add_theme_constant_override("separation", 12)
		row.add_child(rh)
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rh.add_child(tv)
		UI.lbl(tv, Catalog.txt(u["n"]), 22, Color.WHITE, false)
		UI.lbl(tv, Catalog.txt(u["d"]), 15, UI.TXT2)
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 4)
		tv.add_child(pips)
		for i in Catalog.MAX_UP:
			var r := ColorRect.new()
			r.custom_minimum_size = Vector2(34, 10)
			r.color = Color(0.3, 0.85, 0.45) if i < lv else Color(1, 1, 1, 0.14)
			pips.add_child(r)
		if lv >= Catalog.MAX_UP:
			var m := UI.lbl(rh, UI.tx("MAX", "الحد الأقصى"), 22, UI.GOLD, false)
			m.custom_minimum_size = Vector2(190, 0)
			m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			var cost := Catalog.upgrade_cost(key, lv)
			var b := UI.btn(rh, "", UI.GREEN, func():
				if Profile.upgrade(Profile.car, key):
					Sfx.play("success", -2.0)
					say(UI.tx("Upgraded!", "تمت الترقية!"))
					select("workshop")
				else:
					say(UI.tx("Not enough coins", "العملات لا تكفي")), 22, Vector2(190, 56))
			b.disabled = Profile.coins < cost
			var ph := UI.price_row(null, cost, false, 22)
			ph.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			b.add_child(ph)
	return h


# ====================================================================== CHARACTER

func _tab_character() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(440, 0)
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

func _tab_shop() -> Control:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 12)
	sc.add_child(vb)
	UI.lbl(vb, UI.tx("DAILY DEALS  -30%", "عروض اليوم  -30%"), 28, UI.GOLD, false)
	var deals := HBoxContainer.new()
	deals.add_theme_constant_override("separation", 12)
	vb.add_child(deals)
	for it in Profile.daily_deals():
		var e: Dictionary = Catalog.entry(it["slot"], it["id"])
		var rc: Color = Catalog.RARITY_COLOR[int(e["r"])]
		var p := UI.panel(deals, Color(0.09, 0.11, 0.23), 18)
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
		var p := UI.panel(chs, Color(0.09, 0.11, 0.23), 18)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		p.add_child(v)
		var cv := ChestArt.new()
		cv.col = cd["c"]
		cv.custom_minimum_size = Vector2(0, 90)
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


class ChestArt extends Control:
	var col := Color(0.8, 0.5, 0.25)
	var t := 0.0
	var shake := 0.0
	var open := 0.0

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5 + Vector2(sin(t * 40.0) * shake * 6.0, 0)
		var w := 84.0
		var h := 46.0
		draw_rect(Rect2(c.x - w * 0.5, c.y - 2, w, h * 0.6), col.darkened(0.35))
		draw_rect(Rect2(c.x - w * 0.5, c.y - 2, w, h * 0.6), col, false, 3.0)
		var lid_y := c.y - 2 - h * 0.5 - open * 26.0
		draw_rect(Rect2(c.x - w * 0.5 - 2, lid_y, w + 4, h * 0.5), col.lightened(0.1))
		draw_rect(Rect2(c.x - 6, c.y - 8, 12, 16), Color(1, 0.9, 0.5))
		if open > 0.0:
			draw_circle(c + Vector2(0, -8), 20.0 + open * 30.0, Color(1, 0.95, 0.6, 0.35 * (1.0 - open * 0.5)))
		draw_circle(c + Vector2(0, -8), 10.0 + sin(t * 3.0) * 2.0, Color(1, 1, 0.8, 0.25))


# ====================================================================== QUESTS

func _tab_quests() -> Control:
	Profile.refresh_quests()
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 10)
	sc.add_child(vb)
	# daily login
	var lp := UI.panel(vb, Color(0.09, 0.11, 0.23), 18)
	var lv := VBoxContainer.new()
	lp.add_child(lv)
	var got: bool = Profile.login["last"] == Time.get_date_string_from_system()
	UI.lbl(lv, UI.tx("DAILY LOGIN BONUS  -  streak %d", "مكافأة الدخول اليومية  -  أيام متتالية %d") % int(Profile.login["streak"]), 24, UI.GOLD, false)
	var days := HBoxContainer.new()
	days.add_theme_constant_override("separation", 6)
	lv.add_child(days)
	var cur_day := (int(Profile.login["streak"]) - 1) % 7 + 1 if int(Profile.login["streak"]) > 0 else 0
	for d in range(1, 8):
		var cell := UI.panel(days, Color(0.2, 0.55, 0.3) if (d < cur_day or (d == cur_day and got)) else Color(0.12, 0.14, 0.28), 12)
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
		var row := UI.panel(vb, Color(0.09, 0.11, 0.23), 16)
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
	UI.lbl(vb, UI.tx("Finish all 3 quests to win a GOLD chest!", "أنهِ المهام الثلاث واربح صندوقاً ذهبياً!"), 18, UI.TXT2)
	# next level rewards
	var nr := Catalog.level_reward(Profile.level + 1)
	UI.lbl(vb, UI.tx("Next level reward: %d coins%s", "جائزة المستوى القادم: %d عملة%s") % [int(nr["coins"]), (" + " + UI.tx("silver chest", "صندوق فضي")) if int(nr["chest"]) > 0 else ""], 18, UI.TXT2)
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
		var p := UI.panel(row, Color(0.09, 0.11, 0.23), 18)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		p.add_child(v)
		var art := ChestArt.new()
		art.col = cd["c"]
		art.custom_minimum_size = Vector2(0, 120)
		v.add_child(art)
		UI.lbl(v, "%s  x%d" % [Catalog.txt(cd["n"]), n], 22, cd["c"], false).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var b := UI.btn(v, UI.tx("OPEN", "افتح"), UI.GREEN, func(): _open_chest(kind, art), 24, Vector2(0, 54))
		b.disabled = n <= 0
		any = any or n > 0
	if not any:
		UI.lbl(vb, UI.tx("No chests right now - go race!", "ما عندك صناديق الحين - روح تسابق!"), 20, UI.TXT2)
	return vb


func _open_chest(kind: String, art: ChestArt) -> void:
	var res := Profile.open_chest(kind)
	if res.is_empty():
		return
	var ov := ColorRect.new()
	ov.color = Color(0, 0, 0, 0.8)
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.z_index = 30
	add_child(ov)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(v)
	var big := ChestArt.new()
	big.col = Catalog.CHESTS[kind]["c"]
	big.custom_minimum_size = Vector2(300, 220)
	v.add_child(big)
	var tw := create_tween()
	tw.tween_property(big, "shake", 1.0, 0.6)
	tw.tween_callback(func(): Sfx.play("clang", 0.0, 1.3))
	tw.tween_property(big, "shake", 0.0, 0.05)
	tw.tween_property(big, "open", 1.0, 0.35)
	await tw.finished
	Sfx.play("success", 3.0)
	var rar := 0
	if res.has("item"):
		rar = int(res["item"]["rar"])
	var rc: Color = Catalog.RARITY_COLOR[rar]
	var title := UI.lbl(v, "", 40, rc, false)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if res.has("item"):
		var it: Dictionary = res["item"]
		var e := Catalog.entry(it["slot"], it["id"])
		title.text = "%s!  %s" % [Catalog.rar_name(rar), Catalog.nm(e)]
		var col: Color = e["c"] if e.has("c") and e["c"] != Color.TRANSPARENT else rc
		var g := UI.Glyph.new(it["slot"], col)
		g.custom_minimum_size = Vector2(0, 90)
		v.add_child(g)
		UI.lbl(v, Catalog.txt(Catalog.SLOT_NAME[it["slot"]]), 20, UI.TXT2, false).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		title.text = UI.tx("Bonus!", "مكافأة!")
	var ex := "+%d %s" % [int(res["coins"]), UI.tx("coins", "عملة")]
	if int(res["gems"]) > 0:
		ex += "     +%d %s" % [int(res["gems"]), UI.tx("gems", "جوهرة")]
	UI.lbl(v, ex, 26, Color.WHITE, false).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if rar >= 3:
		var fl := ColorRect.new()
		fl.color = Color(1, 0.9, 0.5, 0.7)
		fl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ov.add_child(fl)
		create_tween().tween_property(fl, "color:a", 0.0, 0.8)
	UI.btn(v, UI.tx("Collect", "استلم"), UI.GREEN, func():
		ov.queue_free()
		select("chests"), 26, Vector2(260, 60))
