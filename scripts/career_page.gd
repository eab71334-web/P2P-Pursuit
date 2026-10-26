# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
class_name CareerPage
extends VBoxContainer
## Career: championship tabs, an event map (stage nodes joined by roads) and a tall poster card for the selected stage.

signal back
signal play(idx: int)
signal toast(msg: String)

const NODE_FRAC := [Vector2(0.11, 0.66), Vector2(0.31, 0.27), Vector2(0.5, 0.7), Vector2(0.69, 0.3), Vector2(0.89, 0.62)]

var sel := 0
var _title: Label
var _tabs: HBoxContainer
var _map: MapView
var _poster: PanelContainer
var _chips: HBoxContainer


class StarRow extends Control:
	var stars := 0
	var sz := 12.0

	func _init(n := 0, s := 12.0) -> void:
		stars = n
		sz = s
		custom_minimum_size = Vector2(sz * 8.0, sz * 2.2)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for k in 3:
			var c := Vector2(sz + k * sz * 2.6, sz * 1.1)
			var pts := PackedVector2Array()
			for i in 10:
				var r := sz if i % 2 == 0 else sz * 0.43
				var a := -PI / 2.0 + i * PI / 5.0
				pts.append(c + Vector2(cos(a), sz * 0.0 + sin(a)) * r)
			draw_colored_polygon(pts, Color(1.0, 0.8, 0.25) if k < stars else Color(1, 1, 1, 0.16))


class Mark extends Control:
	var done := false
	var lock := false

	func _init(d := false, l := false, s := 22.0) -> void:
		done = d
		lock = l
		custom_minimum_size = Vector2(s, s)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := size
		var c := s * 0.5
		var r := minf(s.x, s.y) * 0.5 - 1.0
		if lock:
			var body := Rect2(c.x - r * 0.62, c.y - r * 0.1, r * 1.24, r * 0.95)
			draw_arc(Vector2(c.x, c.y - r * 0.1), r * 0.4, PI, TAU, 14, Color(0.92, 0.94, 0.98), maxf(2.0, r * 0.16))
			draw_rect(body, Color(0.92, 0.94, 0.98))
			draw_circle(Vector2(c.x, c.y + r * 0.3), r * 0.12, Color(0.1, 0.11, 0.14))
			return
		if done:
			draw_circle(c, r, UI.ACCENT)
			draw_polyline(PackedVector2Array([Vector2(c.x - r * 0.45, c.y), Vector2(c.x - r * 0.1, c.y + r * 0.38), Vector2(c.x + r * 0.5, c.y - r * 0.35)]), Color.BLACK, maxf(2.0, r * 0.2))
		else:
			draw_arc(c, r - 1.0, 0.0, TAU, 24, Color(1, 1, 1, 0.35), 2.0)


class Backdrop extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color(0.045, 0.05, 0.065))
		# soft diagonal bands
		for k in 4:
			var x0 := w * (0.1 + k * 0.28)
			draw_colored_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x0 + w * 0.09, 0), Vector2(x0 - w * 0.14, h), Vector2(x0 - w * 0.23, h)]), Color(1, 1, 1, 0.018))
		# halftone dots fading towards the top-right
		var step := 15.0
		var ny := int(h / step)
		var nx := int(w / step)
		for iy in ny:
			for ix in nx:
				var fx := float(ix) / nx
				var fy := float(iy) / ny
				var f := clampf((1.0 - fx) * 0.55 + fy * 0.75 - 0.35, 0.0, 1.0)
				if f > 0.04:
					draw_circle(Vector2(ix * step + 7.0, iy * step + 7.0), 0.8 + 3.2 * f, Color(1.0, 0.47, 0.1, 0.05 + 0.08 * f))


class MapView extends Control:
	var pts: Array = []  # node centres
	var rects: Array = []
	var open: Array = []
	var sel_i := -1
	var boss_last := true
	var _t := 0.0

	func _init() -> void:
		clip_contents = true
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(420, 260)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _process(dt: float) -> void:
		if is_visible_in_tree():
			_t += dt
			queue_redraw()

	func _bez(a: Vector2, b: Vector2, u: float) -> Vector2:
		var c1 := Vector2(a.x + (b.x - a.x) * 0.55, a.y)
		var c2 := Vector2(b.x - (b.x - a.x) * 0.55, b.y)
		var v := 1.0 - u
		return a * v * v * v + c1 * 3.0 * v * v * u + c2 * 3.0 * v * u * u + b * u * u * u

	func _draw() -> void:
		if pts.size() < 2:
			return
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var line := PackedVector2Array()
			for k in 31:
				line.append(_bez(a, b, k / 30.0))
			var live: bool = open[i + 1]
			draw_polyline(line, Color(0, 0, 0, 0.55), 13.0, true)
			draw_polyline(line, Color(1.0, 0.47, 0.1, 0.95) if live else Color(1, 1, 1, 0.14), 5.0, true)
			if live:
				draw_polyline(line, Color(1, 0.8, 0.5, 0.5), 1.5, true)
			# moving pulses towards the frontier stage
			var frontier: bool = live and (i + 2 >= pts.size() or not open[i + 2])
			if frontier:
				for q in 3:
					var u := fposmod(_t * 0.35 + q / 3.0, 1.0)
					draw_circle(_bez(a, b, u), 4.5, Color(1, 1, 1, 0.9))
		# glow around the selected node
		if sel_i >= 0 and sel_i < rects.size():
			var r: Rect2 = rects[sel_i]
			var pulse := 0.5 + 0.5 * sin(_t * 3.2)
			for g in 3:
				var gg := 5.0 + g * 5.0 + pulse * 3.0
				draw_rect(r.grow(gg), Color(1.0, 0.47, 0.1, 0.12 - g * 0.035), false, 3.0)


func _init() -> void:
	add_theme_constant_override("separation", 10)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	add_child(top)
	UI.btn(top, "<  " + L.t("back"), UI.CARD2, func(): back.emit(), 20, Vector2(150, 48))
	_title = UI.lbl(top, "", 32, UI.TXT, false)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chips = HBoxContainer.new()
	_chips.add_theme_constant_override("separation", 8)
	top.add_child(_chips)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	add_child(_tabs)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", UI.sb(Color(0.045, 0.05, 0.065), 14, UI.LINE, 1))
	body.add_child(frame)
	var holder := Control.new()
	holder.clip_contents = true
	frame.add_child(holder)
	var bd := Backdrop.new()
	bd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(bd)
	_map = MapView.new()
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map.resized.connect(_layout)
	holder.add_child(_map)
	_poster = PanelContainer.new()
	_poster.custom_minimum_size = Vector2(340, 0)
	_poster.add_theme_stylebox_override("panel", UI.sb(UI.PANEL, 14, UI.LINE, 1))
	body.add_child(_poster)


func open_page() -> void:
	sel = 0
	for i in Career.COUNT:
		if Career.unlocked(i):
			sel = i
	refresh()


func _stars(i: int) -> int:
	return int(Profile.career.get(str(i), 0))


func refresh() -> void:
	var tier := sel / 5
	_title.text = Career.nm(Career.TIER_NAMES[tier])
	var total := 0
	for i in Career.COUNT:
		total += _stars(i)
	for c in _chips.get_children():
		c.queue_free()
	for chip in [["%d" % int(Profile.coins), UI.tx("coins", "عملة"), Color(1.0, 0.8, 0.25)], ["%d" % int(Profile.gems), UI.tx("gems", "جوهرة"), Color(0.5, 0.85, 1.0)], ["%d / %d" % [total, Career.COUNT * 3], UI.tx("stars", "نجمة"), UI.ACCENT]]:
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UI.sb(Color(0, 0, 0, 0.5), 18, Color(1, 1, 1, 0.14), 1))
		var pm := MarginContainer.new()
		pm.add_theme_constant_override("margin_left", 14)
		pm.add_theme_constant_override("margin_right", 14)
		pm.add_theme_constant_override("margin_top", 5)
		pm.add_theme_constant_override("margin_bottom", 5)
		pc.add_child(pm)
		UI.lbl(pm, "%s  %s" % [chip[0], chip[1]], 17, chip[2], false)
		_chips.add_child(pc)
	_build_tabs(tier)
	_build_nodes(tier)
	_build_poster()


func _build_tabs(tier: int) -> void:
	for c in _tabs.get_children():
		c.queue_free()
	for ti in 4:
		var got := 0
		for j in 5:
			got += _stars(ti * 5 + j)
		var open := Career.unlocked(ti * 5)
		var tb := Button.new()
		tb.focus_mode = Control.FOCUS_NONE
		tb.custom_minimum_size = Vector2(0, 44)
		tb.text = ("%d  %s   %d/15" % [ti + 1, Career.nm(Career.TIER_NAMES[ti]), got]) if open else ("%d  %s" % [ti + 1, Career.nm(Career.TIER_NAMES[ti])])
		tb.add_theme_font_size_override("font_size", 16)
		var on := ti == tier
		var nb := UI.sb(Color(1.0, 0.47, 0.1, 0.16) if on else Color(0.09, 0.098, 0.125, 0.9), 8, UI.ACCENT if on else UI.LINE, 2 if on else 1)
		for sn in ["normal", "hover", "pressed", "focus"]:
			tb.add_theme_stylebox_override(sn, nb)
		tb.add_theme_color_override("font_color", UI.ACCENT if on else (UI.TXT if open else Color(0.4, 0.43, 0.5)))
		tb.add_theme_color_override("font_hover_color", UI.ACCENT if on else UI.TXT)
		var tix := ti
		tb.pressed.connect(func():
			Sfx.play("click", -8.0)
			if not Career.unlocked(tix * 5):
				toast.emit(UI.tx("Finish the previous championship first.", "أنهِ البطولة السابقة أولاً."))
				return
			var pick := tix * 5
			for j in 5:
				if Career.unlocked(tix * 5 + j):
					pick = tix * 5 + j
			sel = pick
			refresh())
		_tabs.add_child(tb)


func _build_nodes(tier: int) -> void:
	for c in _map.get_children():
		c.queue_free()
	_map.pts.clear()
	_map.rects.clear()
	_map.open.clear()
	_map.sel_i = sel - tier * 5
	for j in 5:
		var i := tier * 5 + j
		var lv := Career.level(i)
		var st := _stars(i)
		var op := Career.unlocked(i)
		var boss := bool(lv["boss"])
		var sz := Vector2(268, 112) if boss else Vector2(238, 98)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.size = sz
		b.custom_minimum_size = sz
		b.set_meta("j", j)
		var on := i == sel
		var edge := UI.ACCENT if on else (Color(1.0, 0.8, 0.25) if boss else Color(1, 1, 1, 0.16))
		var plate := UI.sb(Color(0.07, 0.075, 0.095, 0.98) if op else Color(0.05, 0.055, 0.07, 0.96), 12, edge, 3 if (on or boss) else 1)
		for sn in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(sn, plate)
		var h := HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 7
		h.offset_top = 7
		h.offset_right = -10
		h.offset_bottom = -7
		h.add_theme_constant_override("separation", 10)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(h)
		var th := Control.new()
		th.custom_minimum_size = Vector2(sz.y - 14, sz.y - 14)
		th.clip_contents = true
		th.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(th)
		var art := StageArt.new(str(lv["theme"]), str(lv["weather"]))
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.speed = 2.4 if on else 0.9
		art.dim = 0.0 if op else 0.7
		th.add_child(art)
		if not op:
			var lk := Mark.new(false, true, 30.0)
			lk.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			lk.offset_left = -15
			lk.offset_top = -15
			lk.offset_right = 15
			lk.offset_bottom = 15
			th.add_child(lk)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 1)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(v)
		var nl := UI.lbl(v, "%02d%s" % [i + 1, ("  " + UI.tx("FINAL", "النهائي")) if boss else ""], 22, Color(1.0, 0.8, 0.25) if boss else Color.WHITE, false)
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nm := UI.lbl(v, Career.stage_name(i), 13, UI.TXT2 if op else Color(0.45, 0.48, 0.55), true)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if op:
			v.add_child(StarRow.new(st, 9.0))
		var idx := i
		b.pressed.connect(func():
			Sfx.play("click", -8.0)
			if not Career.unlocked(idx):
				toast.emit(UI.tx("Finish the previous stage first.", "أنهِ المرحلة السابقة أولاً."))
				return
			sel = idx
			refresh())
		_map.add_child(b)
		_map.pts.append(Vector2.ZERO)
		_map.rects.append(Rect2())
		_map.open.append(op)
	_layout()


func _layout() -> void:
	if _map == null:
		return
	var s := _map.size
	var j := 0
	var nodes: Array = []
	for c in _map.get_children():
		if c is Button:
			nodes.append(c)
	for c in nodes:
		var f: Vector2 = NODE_FRAC[j]
		if L.is_ar():
			f.x = 1.0 - f.x
		var sz: Vector2 = c.size
		var ctr := Vector2(clampf(f.x * s.x, sz.x * 0.5 + 14, maxf(sz.x * 0.5 + 14, s.x - sz.x * 0.5 - 14)), clampf(f.y * s.y, sz.y * 0.5 + 14, maxf(sz.y * 0.5 + 14, s.y - sz.y * 0.5 - 14)))
		c.position = ctr - sz * 0.5
		if j < _map.pts.size():
			_map.pts[j] = ctr
			_map.rects[j] = Rect2(c.position, sz)
		j += 1


func _build_poster() -> void:
	for c in _poster.get_children():
		c.queue_free()
	var i := sel
	var lv := Career.level(i)
	var st := _stars(i)
	var need := int(lv["need"])
	var m := MarginContainer.new()
	for sd in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + sd, 10)
	_poster.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	# picture
	var pic := PanelContainer.new()
	pic.custom_minimum_size = Vector2(0, 210)
	pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pic.add_theme_stylebox_override("panel", UI.sb(Color(0.03, 0.035, 0.045), 10, Color(1.0, 0.8, 0.25) if bool(lv["boss"]) else Color(1, 1, 1, 0.16), 2))
	v.add_child(pic)
	var ph := Control.new()
	ph.clip_contents = true
	pic.add_child(ph)
	var art := StageArt.new(str(lv["theme"]), str(lv["weather"]))
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.speed = 3.0
	art.poster = true
	ph.add_child(art)
	var cap := VBoxContainer.new()
	cap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	cap.offset_left = 14
	cap.offset_right = -14
	cap.offset_bottom = -10
	cap.offset_top = -80
	cap.alignment = BoxContainer.ALIGNMENT_END
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(cap)
	var k := UI.lbl(cap, "%s %02d%s" % [UI.tx("STAGE", "المرحلة"), i + 1, ("  -  " + UI.tx("FINAL EVENT", "الحدث النهائي")) if bool(lv["boss"]) else ""], 14, Color(1.0, 0.8, 0.25) if bool(lv["boss"]) else UI.ACCENT, false)
	k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nl := UI.lbl(cap, Career.stage_name(i), 24, Color.WHITE, true)
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tl := UI.lbl(cap, "%s  |  %s" % [Career.nm(Career.THEME_NAMES[lv["theme"]]), Career.nm(Career.WEATHER_NAMES[lv["weather"]])], 14, Color(0.85, 0.88, 0.94), false)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# opponents
	UI.lbl(v, "%s  -  %s" % [UI.tx("%d opponents", "%d منافسين") % int(lv["bots"]), Career.nm(Career.LEVEL_NAMES[lv["level"]])], 15, UI.TXT2, false)
	# objectives
	var goals := [
		[UI.tx("Finish in the top %d", "أنهِ ضمن أول %d") % need, st >= 4 - need],
		[UI.tx("Finish 2nd or better", "المركز الثاني أو أفضل"), st >= 2],
		[UI.tx("Win the stage", "فُز بالمرحلة"), st >= 3],
	]
	for gdef in goals:
		var gr := HBoxContainer.new()
		gr.add_theme_constant_override("separation", 10)
		v.add_child(gr)
		gr.add_child(Mark.new(bool(gdef[1])))
		var gl := UI.lbl(gr, str(gdef[0]), 16, UI.TXT if not bool(gdef[1]) else UI.TXT2, false)
		gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# rewards
	var rw := "%d %s" % [int(lv["coins"]), UI.tx("coins", "عملة")]
	if int(lv["gems"]) > 0:
		rw += "  +%d %s" % [int(lv["gems"]), UI.tx("gems", "جوهرة")]
	var chn := {"bronze": UI.tx("Wooden chest", "صندوق خشبي"), "silver": UI.tx("Silver chest", "صندوق فضي"), "gold": UI.tx("Gold chest", "صندوق ذهبي")}
	if str(lv["chest"]) != "":
		rw += "  +" + str(chn[lv["chest"]])
	var rl := UI.lbl(v, UI.tx("REWARD: ", "الجائزة: ") + rw, 15, Color(1.0, 0.8, 0.25), true)
	rl.add_theme_constant_override("outline_size", 0)
	var go := UI.btn(v, UI.tx("RACE AGAIN", "أعد السباق") if st > 0 else UI.tx("PLAY", "العب"), UI.ACCENT, func(): play.emit(sel), 26, Vector2(0, 60))
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
