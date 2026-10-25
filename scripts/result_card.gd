# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
class_name ResultCard
extends PanelContainer
## The "you finished" card: medal badge, big time, reward tiles, level-up banner, two buttons.

var standings: Label
var again_btn: Button
var exit_btn: Button


class Badge extends Control:
	var col := Color(1, 0.82, 0.25)
	var txt := "1"
	var none := false

	func _init() -> void:
		custom_minimum_size = Vector2(88, 96)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, 44)
		# ribbon tails
		draw_colored_polygon(PackedVector2Array([c + Vector2(-22, 24), c + Vector2(-6, 30), c + Vector2(-14, 56), c + Vector2(-24, 46), c + Vector2(-34, 54)]), col.darkened(0.35))
		draw_colored_polygon(PackedVector2Array([c + Vector2(22, 24), c + Vector2(6, 30), c + Vector2(14, 56), c + Vector2(24, 46), c + Vector2(34, 54)]), col.darkened(0.45))
		draw_circle(c, 36, col.darkened(0.45))
		draw_circle(c, 33, col)
		draw_circle(c, 27, col.darkened(0.18))
		draw_arc(c, 30, -2.6, -0.9, 14, Color(1, 1, 1, 0.55), 3.0)
		var f := ThemeDB.fallback_font
		var fs := 34
		var s := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(f, Vector2(c.x - s.x * 0.5, c.y + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.1, 0.07, 0.02, 0.92))


class Tile extends PanelContainer:
	var kind := "coin"
	var icon: Control
	var val: Label

	func _init(k: String, value: String, caption: String, col: Color) -> void:
		kind = k
		custom_minimum_size = Vector2(172, 92)
		add_theme_stylebox_override("panel", UI.sb(Color(1, 1, 1, 0.045), 12, Color(col.r, col.g, col.b, 0.35), 1))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		add_child(h)
		icon = Control.new()
		icon.custom_minimum_size = Vector2(44, 44)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.draw.connect(_draw_icon.bind(col))
		h.add_child(icon)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		h.add_child(v)
		val = UI.lbl(v, value, 30, col.lightened(0.25), false)
		UI.lbl(v, caption, 14, UI.TXT2, false)

	func _draw_icon(col: Color) -> void:
		var c := Vector2(22, 22)
		match kind:
			"coin":
				icon.draw_circle(c, 20, col.darkened(0.4))
				icon.draw_circle(c, 17, col)
				icon.draw_arc(c, 11, 0, TAU, 24, col.darkened(0.35), 2.5)
				icon.draw_arc(c, 14, -2.5, -1.0, 8, Color(1, 1, 1, 0.5), 2.0)
			"xp":
				icon.draw_colored_polygon(PackedVector2Array([c + Vector2(4, -20), c + Vector2(-12, 3), c + Vector2(-1, 3), c + Vector2(-5, 20), c + Vector2(13, -4), c + Vector2(1, -4)]), col)
			"chest":
				icon.draw_rect(Rect2(3, 14, 38, 24), col.darkened(0.3))
				icon.draw_rect(Rect2(3, 6, 38, 12), col)
				icon.draw_rect(Rect2(19, 16, 6, 8), Color(0.1, 0.08, 0.05))


func build(place_txt: String, stage: String, time_txt: String, medal_idx: int, medal_name: String, rw: Dictionary, level: int, team: bool, solo_room: bool, on_again: Callable, on_exit: Callable) -> void:
	var mcols := [Color(1.0, 0.82, 0.25), Color(0.82, 0.84, 0.9), Color(0.85, 0.52, 0.25)]
	var mc: Color = mcols[medal_idx] if medal_idx >= 0 else Color(0.5, 0.55, 0.62)
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(600, 0)
	add_theme_stylebox_override("panel", UI.sb(Color(0.06, 0.065, 0.085, 0.96), 18, Color(mc.r, mc.g, mc.b, 0.55), 2))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	add_child(vb)
	# header
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	vb.add_child(head)
	var badge := Badge.new()
	badge.col = mc
	badge.txt = place_txt if place_txt != "" else "★"
	head.add_child(badge)
	var hv := VBoxContainer.new()
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_theme_constant_override("separation", 2)
	head.add_child(hv)
	UI.lbl(hv, UI.tx("FINISH", "وصلت!"), 42, UI.TXT, false)
	var sub := UI.lbl(hv, stage, 16, UI.TXT2, false)
	sub.visible = stage != ""
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UI.sb(Color(mc.r, mc.g, mc.b, 0.18), 12, Color(mc.r, mc.g, mc.b, 0.6), 1))
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hv.add_child(pill)
	UI.lbl(pill, "  " + UI.tx("Medal", "الميدالية") + ":  " + medal_name + "  ", 16, mc.lightened(0.25), false)
	# time
	var tbox := VBoxContainer.new()
	tbox.add_theme_constant_override("separation", 0)
	vb.add_child(tbox)
	var tl := UI.lbl(tbox, UI.tx("TIME", "الوقت"), 14, UI.TXT2, false)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tv := UI.lbl(tbox, time_txt, 64, UI.TXT, false)
	tv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# rewards
	var rr := HBoxContainer.new()
	rr.alignment = BoxContainer.ALIGNMENT_CENTER
	rr.add_theme_constant_override("separation", 12)
	vb.add_child(rr)
	var t1 := Tile.new("coin", "+0", UI.tx("Coins", "عملات"), Color(1.0, 0.8, 0.2))
	rr.add_child(t1)
	var t2 := Tile.new("xp", "+0", "XP", Color(0.35, 0.65, 1.0))
	rr.add_child(t2)
	if str(rw.get("chest", "")) != "":
		rr.add_child(Tile.new("chest", "+1", UI.tx("Chest", "صندوق"), Color(0.95, 0.55, 0.2)))
	var coins := int(rw["coins"])
	var xp := int(rw["xp"])
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(v: float): t1.val.text = "+%d" % int(v), 0.0, float(coins), 1.1).set_delay(0.3)
	tw.tween_method(func(v: float): t2.val.text = "+%d" % int(v), 0.0, float(xp), 1.1).set_delay(0.3)
	if rw.get("level_up", false):
		var lu := PanelContainer.new()
		lu.add_theme_stylebox_override("panel", UI.sb(Color(UI.ACCENT.r, UI.ACCENT.g, UI.ACCENT.b, 0.16), 12, UI.ACCENT, 2))
		vb.add_child(lu)
		var l := UI.lbl(lu, UI.tx("LEVEL UP!  Level %d", "ارتقيت! المستوى %d") % level, 24, UI.ACCENT.lightened(0.3), false)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if team:
		standings = Label.new()
		standings.add_theme_font_size_override("font_size", 20)
		standings.add_theme_color_override("font_color", UI.TXT2)
		standings.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(standings)
	# buttons
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	exit_btn = UI.btn(row, UI.tx("Main menu", "القائمة الرئيسية") if solo_room else UI.tx("Back to room", "الرجوع للغرفة"), UI.CARD2, on_exit, 22, Vector2(0, 60))
	exit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again_btn = UI.btn(row, UI.tx("Race again", "سباق جديد") if solo_room else UI.tx("Rematch", "إعادة المباراة"), UI.ACCENT, on_again, 24, Vector2(0, 60))
	again_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again_btn.add_theme_color_override("font_color", Color(0.08, 0.05, 0.02))
	# entrance
	modulate.a = 0.0
	pivot_offset = Vector2(300, 200)
	scale = Vector2(0.93, 0.93)
	var en := create_tween().set_parallel(true)
	en.tween_property(self, "modulate:a", 1.0, 0.3)
	en.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
