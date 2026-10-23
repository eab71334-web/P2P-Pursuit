# Copyright (c) 2026 AVF. All rights reserved. See LICENSE.
class_name SteerUI
extends RefCounted
## Steering controls for touch screens: a mode picker shown once before the first race, and the on-screen wheel.
## Modes: "buttons" (< >), "wheel" (drag wheel, about 140 degrees each way), "wheel360" (full turn each way).

const MODES := ["buttons", "wheel", "wheel360"]
const LOCK := {"buttons": 1.6, "wheel": 2.45, "wheel360": 6.283}


static func mode_name(m: String) -> String:
	match m:
		"wheel":
			return UI.tx("Steering wheel", "الدومان")
		"wheel360":
			return UI.tx("Wheel 360", "دومان 360")
	return UI.tx("Two buttons", "زرين يمين ويسار")


static func mode_desc(m: String) -> String:
	match m:
		"wheel":
			return UI.tx("Drag the wheel left and right. It returns to centre when you let go.", "حرّك الدومان يمين ويسار. يرجع للوسط لما تفلته.")
		"wheel360":
			return UI.tx("A wheel that makes a full turn each way, like a real car. Your driver turns it hand over hand.", "دومان يلف دورة كاملة لكل جهة مثل السيارة الحقيقية. والسائق يبرمه يد فوق يد.")
	return UI.tx("Hold < to steer left and > to steer right.", "اضغط < لليسار و > لليمين.")


## the wheel drawn on the HUD
class Wheel extends Control:
	var angle := 0.0          # radians, positive = clockwise
	var lock := 2.45
	var show360 := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var R := minf(size.x, size.y) * 0.46
		draw_circle(c, R + 8.0, Color(0, 0, 0, 0.32))
		# lock marks around the outside (where full lock is)
		draw_arc(c, R + 7.0, -PI / 2.0 - minf(lock, PI), -PI / 2.0 + minf(lock, PI), 48, Color(1, 1, 1, 0.14), 3.0)
		draw_set_transform(c, angle, Vector2.ONE)
		draw_arc(Vector2.ZERO, R - 9.0, 0.0, TAU, 56, Color(0.05, 0.055, 0.07, 0.95), 18.0)       # rim
		draw_arc(Vector2.ZERO, R - 9.0, 0.0, TAU, 56, Color(1, 1, 1, 0.08), 2.0)
		draw_arc(Vector2.ZERO, R - 17.0, 0.0, TAU, 56, Color(0.2, 0.21, 0.25, 0.9), 2.0)
		for a in [PI, 0.0, PI / 2.0]:                                                   # three spokes (left, right, bottom)
			var d := Vector2(cos(a), sin(a))
			draw_line(d * 22.0, d * (R - 16.0), Color(0.08, 0.085, 0.1, 0.96), 14.0)
		draw_circle(Vector2.ZERO, 26.0, Color(0.1, 0.105, 0.13, 0.98))
		draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 28, Color(1, 1, 1, 0.14), 2.0)
		draw_rect(Rect2(-5, -R + 1.0, 10, 20), UI.ACCENT)                               # 12 o'clock marker
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if show360:
			var f := ThemeDB.fallback_font
			draw_string(f, c + Vector2(-16, 6), "360", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.55))


## one-time choice before the first race
class Picker extends Control:
	signal picked(mode: String)

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var dim := ColorRect.new()
		dim.color = Color(0.02, 0.025, 0.035, 0.94)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(dim)
		var cc := CenterContainer.new()
		cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(cc)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 14)
		cc.add_child(vb)
		var t := UI.lbl(vb, UI.tx("HOW DO YOU WANT TO STEER?", "كيف تحب تتحكم بالسيارة؟"), 30, UI.TXT, false)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var s := UI.lbl(vb, UI.tx("You choose once. You can change it later in Settings.", "تختار مرة واحدة فقط، وتقدر تغيّرها من الإعدادات."), 17, UI.TXT2, false)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_child(row)
		for m in SteerUI.MODES:
			row.add_child(_card(m))

	func _card(m: String) -> Control:
		var b := Button.new()
		b.custom_minimum_size = Vector2(230, 250)
		var n := UI.sb(UI.CARD, 14, Color(1, 1, 1, 0.14), 2)
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", UI.sb(UI.CARD2, 14, UI.ACCENT, 3))
		b.add_theme_stylebox_override("pressed", UI.sb(UI.CARD2, 14, UI.ACCENT, 3))
		b.add_theme_stylebox_override("focus", n)
		b.pressed.connect(func():
			Sfx.play("click")
			picked.emit(m))
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 12
		v.offset_right = -12
		v.offset_top = 10
		v.offset_bottom = -10
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 6)
		b.add_child(v)
		var ic := Icon.new()
		ic.mode = m
		ic.custom_minimum_size = Vector2(0, 110)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(ic)
		var nm := UI.lbl(v, SteerUI.mode_name(m), 21, UI.TXT, false)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var ds := UI.lbl(v, SteerUI.mode_desc(m), 14, UI.TXT2, true)
		ds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return b


class Icon extends Control:
	var mode := "buttons"
	var t := 0.0

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		match mode:
			"buttons":
				for k in [-1.0, 1.0]:
					var r := Rect2(c.x + k * 44.0 - 34.0, c.y - 30.0, 68.0, 60.0)
					draw_style_box(UI.sb(Color(1, 1, 1, 0.14), 10, Color(1, 1, 1, 0.5), 2), r)
					var f := ThemeDB.fallback_font
					draw_string(f, Vector2(r.position.x + 22.0, c.y + 12.0), "<" if k < 0.0 else ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
			_:
				var ang := sin(t * 1.6) * (0.5 if mode == "wheel" else 2.4)
				var R := 46.0
				draw_set_transform(c, ang, Vector2.ONE)
				draw_arc(Vector2.ZERO, R - 6.0, 0.0, TAU, 40, Color(0.75, 0.78, 0.85), 11.0)
				for a in [PI, 0.0, PI / 2.0]:
					draw_line(Vector2(cos(a), sin(a)) * 12.0, Vector2(cos(a), sin(a)) * (R - 10.0), Color(0.6, 0.63, 0.7), 8.0)
				draw_circle(Vector2.ZERO, 14.0, Color(0.5, 0.53, 0.6))
				draw_rect(Rect2(-4, -R + 2.0, 8, 12), UI.ACCENT)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				if mode == "wheel360":
					draw_arc(c, R + 12.0, -PI * 0.5, PI * 1.35, 40, UI.ACCENT, 3.0)
					var tip := c + Vector2(cos(PI * 1.35), sin(PI * 1.35)) * (R + 12.0)
					draw_circle(tip, 5.0, UI.ACCENT)
