# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
class_name Tutorial
extends Control
## "How to play" slides shown before the race. Animated pictures, can be skipped.

signal finished

var pages: Array = []      # [{icon, title, body}] (translation keys)
var idx := 0
var _t := 0.0
var _card: PanelContainer
var _art: Control
var _title: Label
var _body: Label
var _dots: HBoxContainer
var _next: Button
var _skip: Button
var _never: CheckBox
var _done := false


static func pages_for(role: String, solo_race: bool, ffa: bool) -> Array:
	if role == "navigator":
		return [
			{"icon": "map", "title": "tut_n1_t", "body": "tut_n1"},
			{"icon": "hand", "title": "tut_n2_t", "body": "tut_n2"},
			{"icon": "danger", "title": "tut_n3_t", "body": "tut_n3"},
			{"icon": "fire", "title": "tut_f_t", "body": "tut_f"},
		]
	if solo_race:
		var p := [
			{"icon": "trophy", "title": "tut_s1_t", "body": "tut_s1"},
			{"icon": "map", "title": "tut_s2_t", "body": "tut_s2"},
			{"icon": "controls", "title": "tut_s3_t", "body": "tut_s3"},
		]
		if ffa:
			p.append({"icon": "race", "title": "tut_s4_t", "body": "tut_s4"})
		p.append({"icon": "fire", "title": "tut_f_t", "body": "tut_f"})
		return p
	return [
		{"icon": "wheel", "title": "tut_d1_t", "body": "tut_d1"},
		{"icon": "hand", "title": "tut_d2_t", "body": "tut_d2"},
		{"icon": "controls", "title": "tut_d3_t", "body": "tut_d3"},
		{"icon": "fire", "title": "tut_f_t", "body": "tut_f"},
	]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.08, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.2)
	sb.set_corner_radius_all(26)
	sb.set_border_width_all(3)
	sb.border_color = Color(1.0, 0.82, 0.25, 0.8)
	sb.set_content_margin_all(26)
	sb.shadow_size = 30
	sb.shadow_color = Color(0, 0, 0, 0.6)
	_card.add_theme_stylebox_override("panel", sb)
	_card.custom_minimum_size = Vector2(980, 470)
	center.add_child(_card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	_card.add_child(vb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if L.is_ar():
		row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	vb.add_child(row)

	_art = Control.new()
	_art.custom_minimum_size = Vector2(380, 300)
	_art.draw.connect(_draw_art)
	row.add_child(_art)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 14)
	row.add_child(col)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 40)
	_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_title)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 25)
	_body.add_theme_color_override("font_color", Color(0.88, 0.92, 1.0))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_body)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	if L.is_ar():
		bottom.layout_direction = Control.LAYOUT_DIRECTION_RTL
	vb.add_child(bottom)
	_skip = _btn(L.t("tut_skip"), Color(0.35, 0.37, 0.5))
	_skip.pressed.connect(_finish)
	bottom.add_child(_skip)
	_never = CheckBox.new()
	_never.text = L.t("tut_never")
	_never.add_theme_font_size_override("font_size", 20)
	_never.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_never)
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 8)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_child(_dots)
	_next = _btn(L.t("tut_next"), Color(0.15, 0.6, 0.3))
	_next.pressed.connect(_advance)
	bottom.add_child(_next)

	_show_page(true)
	# pop-in
	_card.pivot_offset = _card.custom_minimum_size * 0.5
	_card.scale = Vector2(0.85, 0.85)
	_card.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.45)
	tw.tween_property(_card, "modulate:a", 1.0, 0.3)


func _btn(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(190, 62)
	b.add_theme_font_size_override("font_size", 26)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(16)
	b.add_theme_stylebox_override("normal", sb)
	var hv := sb.duplicate() as StyleBoxFlat
	hv.bg_color = col.lightened(0.2)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	return b


func _show_page(first := false) -> void:
	var p: Dictionary = pages[idx]
	_title.text = L.t(p["title"])
	_body.text = L.t(p["body"])
	_next.text = L.t("tut_go") if idx == pages.size() - 1 else L.t("tut_next")
	for c in _dots.get_children():
		c.queue_free()
	for i in pages.size():
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(22 if i == idx else 11, 11)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		d.color = Color(1.0, 0.82, 0.25) if i == idx else Color(0.4, 0.45, 0.6)
		_dots.add_child(d)
	if not first:
		for n in [_title, _body]:
			(n as Control).modulate.a = 0.0
			create_tween().tween_property(n, "modulate:a", 1.0, 0.35)
	_t = 0.0


func _advance() -> void:
	if idx >= pages.size() - 1:
		_finish()
	else:
		idx += 1
		_show_page()


func _finish() -> void:
	if _done:
		return
	_done = true
	if _never.button_pressed:
		L.set_tutorial_off(true)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	await tw.finished
	finished.emit()
	queue_free()


func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e.keycode == KEY_ENTER or e.keycode == KEY_SPACE):
		_advance()


func _process(d: float) -> void:
	_t += d
	_art.queue_redraw()


# ------------------------------------------------------------------ animated pictures

func _draw_art() -> void:
	var c := _art.size * 0.5
	_art.draw_circle(c, 150.0, Color(0.14, 0.17, 0.3))
	_art.draw_arc(c, 150.0, 0.0, TAU, 64, Color(1, 1, 1, 0.12), 3.0)
	match pages[idx]["icon"]:
		"wheel":
			_art_wheel(c)
		"hand":
			_art_hand(c)
		"map":
			_art_map(c)
		"controls":
			_art_keys(c)
		"danger":
			_art_danger(c)
		"race":
			_art_race(c)
		"trophy":
			_art_trophy(c)
		"fire":
			_art_fire(c)


func _art_wheel(c: Vector2) -> void:
	# dark world + dim road + a wheel turning left and right
	for i in 6:
		var y := fposmod(_t * 60.0 + i * 38.0, 228.0)
		var w := 6.0 + y * 0.12
		_art.draw_rect(Rect2(c.x - w * 0.5, c.y - 110 + y, w, 14), Color(0.35, 0.37, 0.45, 0.55))
	var a := sin(_t * 1.6) * 0.7
	var r := 62.0
	var col := Color(0.92, 0.92, 0.96)
	_art.draw_arc(c + Vector2(0, 40), r, a, a + TAU, 40, col, 11.0)
	for k in 3:
		var an := a + k * TAU / 3.0 + PI * 0.5
		_art.draw_line(c + Vector2(0, 40), c + Vector2(0, 40) + Vector2(cos(an), sin(an)) * r, col, 8.0)
	_art.draw_circle(c + Vector2(0, 40), 12, Color(1.0, 0.3, 0.25))


func _art_hand(c: Vector2) -> void:
	# a character pointing left / straight / right
	var s := int(_t * 0.9) % 3
	var dirv := [Vector2(-1, -0.15), Vector2(0, -1), Vector2(1, -0.15)][s] as Vector2
	_art.draw_rect(Rect2(c.x - 34, c.y - 10, 68, 80), Color(0.82, 0.18, 0.2))
	_art.draw_rect(Rect2(c.x - 26, c.y - 62, 52, 52), Color(0.15, 0.4, 0.95))
	_art.draw_rect(Rect2(c.x - 22, c.y - 42, 44, 12), Color(0.05, 0.05, 0.08))
	var sh := c + Vector2(34, 6)
	var tip := sh + dirv * (70.0 + sin(_t * 8.0) * 4.0)
	_art.draw_line(sh, tip, Color(0.93, 0.84, 0.7), 14.0)
	_art.draw_circle(tip, 11, Color(0.93, 0.84, 0.7))
	var a := tip + dirv * 34.0
	_art.draw_line(tip + dirv * 14.0, a, Color(1.0, 0.9, 0.3), 8.0)
	_art.draw_line(a, a - dirv.rotated(0.6) * 14.0, Color(1.0, 0.9, 0.3), 8.0)
	_art.draw_line(a, a - dirv.rotated(-0.6) * 14.0, Color(1.0, 0.9, 0.3), 8.0)


func _art_map(c: Vector2) -> void:
	var r := Rect2(c - Vector2(115, 80), Vector2(230, 160))
	_art.draw_rect(r.grow(8), Color(0.75, 0.76, 0.8))
	_art.draw_rect(r, Color(0.05, 0.05, 0.09))
	var pts := PackedVector2Array([Vector2(-90, 60), Vector2(-60, 20), Vector2(-20, 40), Vector2(10, -10), Vector2(50, 10), Vector2(85, -50)])
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + p)
	_art.draw_polyline(out, Color(0.98, 0.93, 0.6), 4.0)
	_art.draw_polyline(PackedVector2Array([c + Vector2(10, -10), c + Vector2(40, -45), c + Vector2(70, -60)]), Color(0.95, 0.25, 0.25), 4.0)
	_art.draw_line(c + Vector2(64, -66), c + Vector2(76, -54), Color(1, 0.3, 0.3), 4.0)
	_art.draw_line(c + Vector2(64, -54), c + Vector2(76, -66), Color(1, 0.3, 0.3), 4.0)
	var f := fposmod(_t * 0.25, 1.0) * 5.0
	var i := mini(int(f), 4)
	var pos := out[i].lerp(out[i + 1], f - i)
	_art.draw_circle(pos, 8, Color.WHITE)
	_art.draw_circle(pos, 5, Color(0.9, 0.1, 0.1))
	_art.draw_circle(c + Vector2(0, 108), 5.0 + sin(_t * 4.0) * 2.0, Color(1, 1, 1, 0.8))   # "look down"


func _art_keys(c: Vector2) -> void:
	var labels := ["A", "D", "W", "S"]
	var pos := [Vector2(-80, 40), Vector2(0, 40), Vector2(-40, -40), Vector2(-40, 40)]
	pos[3] = Vector2(-40, 40)
	pos[0] = Vector2(-100, 40)
	pos[1] = Vector2(20, 40)
	var act := int(_t * 1.4) % 4
	for i in 4:
		var p: Vector2 = c + pos[i]
		var on := i == act
		var rr := Rect2(p - Vector2(30, 30) * (1.12 if on else 1.0), Vector2(60, 60) * (1.12 if on else 1.0))
		_art.draw_rect(rr, Color(1.0, 0.82, 0.25) if on else Color(0.3, 0.34, 0.5))
		_art.draw_string(ThemeDB.fallback_font, p + Vector2(-9, 11), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.BLACK if on else Color.WHITE)
	_art.draw_string(ThemeDB.fallback_font, c + Vector2(-60, 112), "R  =  RESET", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.8, 0.85, 1))


func _art_danger(c: Vector2) -> void:
	var pulse := 0.6 + 0.4 * sin(_t * 5.0)
	_art.draw_rect(Rect2(c.x - 100, c.y - 6, 120, 18), Color(0.3, 0.3, 0.34))
	_art.draw_line(c + Vector2(-100, 12), c + Vector2(20, 12), Color(1.0, 0.55, 0.1), 6.0)
	_art.draw_rect(Rect2(c.x - 100, c.y + 12, 120, 70), Color(0.12, 0.13, 0.2))
	_art.draw_rect(Rect2(c.x + 30, c.y - 70, 70, 14), Color(0.45, 0.9, 1.0))
	var t0 := c + Vector2(-60, -60)
	_art.draw_colored_polygon(PackedVector2Array([t0 + Vector2(0, -30), t0 + Vector2(30, 24), t0 + Vector2(-30, 24)]), Color(1.0, 0.25, 0.25, pulse))
	_art.draw_string(ThemeDB.fallback_font, t0 + Vector2(-6, 14), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	for k in 2:
		var p := c + Vector2(40 + k * 30, 40)
		_art.draw_line(p + Vector2(-12, -12), p + Vector2(12, 12), Color(1, 0.3, 0.3, pulse), 6.0)
		_art.draw_line(p + Vector2(-12, 12), p + Vector2(12, -12), Color(1, 0.3, 0.3, pulse), 6.0)


func _art_race(c: Vector2) -> void:
	var cols := [Color(0.82, 0.1, 0.1), Color(0.15, 0.4, 0.95), Color(0.15, 0.7, 0.3), Color(0.95, 0.72, 0.1)]
	for i in 4:
		var x := fposmod(_t * (70.0 + i * 12.0) + i * 40.0, 300.0) - 150.0
		var y := c.y - 66 + i * 38
		_art.draw_rect(Rect2(c.x + x - 22, y, 44, 22), cols[i])
		_art.draw_rect(Rect2(c.x + x - 12, y - 8, 24, 10), cols[i].darkened(0.3))
	for k in 6:
		_art.draw_rect(Rect2(c.x + 118, c.y - 80 + k * 26, 12, 13), Color.WHITE if k % 2 == 0 else Color.BLACK)


func _art_trophy(c: Vector2) -> void:
	var bob := sin(_t * 3.0) * 4.0
	for i in 3:
		var col := [Color(1.0, 0.82, 0.25), Color(0.82, 0.84, 0.9), Color(0.85, 0.52, 0.25)][i] as Color
		var p := c + Vector2((i - 1) * 90, bob * (1 if i == 1 else -1) + (0 if i == 1 else 20))
		_art.draw_circle(p, 34, col)
		_art.draw_circle(p, 24, col.darkened(0.15))
		_art.draw_string(ThemeDB.fallback_font, p + Vector2(-8, 11), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)


func _art_fire(c: Vector2) -> void:
	# car front with open hood, flames and an extinguisher spray
	_art.draw_rect(Rect2(c.x - 70, c.y + 20, 140, 46), Color(0.82, 0.1, 0.1))
	_art.draw_rect(Rect2(c.x - 55, c.y + 10, 110, 14), Color(0.2, 0.22, 0.28))
	var open := 0.5 + 0.5 * sin(_t * 1.6)
	var hood_y := c.y + 12.0 - open * 40.0
	_art.draw_line(Vector2(c.x - 60, c.y + 12), Vector2(c.x - 60, hood_y), Color(0.82, 0.1, 0.1), 8.0)
	_art.draw_line(Vector2(c.x + 60, c.y + 12), Vector2(c.x + 60, hood_y), Color(0.82, 0.1, 0.1), 8.0)
	for i in 6:
		var ph := _t * 4.0 + i * 1.3
		var fh := 26.0 + 12.0 * sin(ph)
		var x := c.x - 40.0 + i * 16.0
		_art.draw_colored_polygon(PackedVector2Array([Vector2(x - 8, c.y + 12), Vector2(x + 8, c.y + 12), Vector2(x + sin(ph * 1.7) * 5.0, c.y + 12 - fh)]), Color(1.0, 0.5 + 0.3 * sin(ph), 0.1, 0.9))
	for i in 4:
		var sm := fposmod(_t * 0.8 + i * 0.25, 1.0)
		_art.draw_circle(Vector2(c.x - 20 + i * 14 + sin(_t + i) * 8.0, c.y - 20 - sm * 80.0), 8.0 + sm * 14.0, Color(0.5, 0.5, 0.55, 0.5 * (1.0 - sm)))
	_art.draw_rect(Rect2(c.x - 120, c.y - 10, 18, 44), Color(0.85, 0.08, 0.08))
	for i in 5:
		var k := fposmod(_t * 2.0 + i * 0.2, 1.0)
		_art.draw_circle(Vector2(c.x - 100 + k * 60.0, c.y - 4 + k * 8.0), 4.0 + k * 5.0, Color(1, 1, 1, 0.8 * (1.0 - k)))
