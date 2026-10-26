# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
class_name SoloHub
extends VBoxContainer
## Solo landing page: one tall featured tile (Career) next to a mosaic of smaller tiles.

signal back
signal career
signal custom
signal quick
signal soon

var _badge: Label


class Tile extends Button:
	func _init(title: String, sub: String, th: String, wx: String, big: bool, locked: bool, badge: String, grade := Color(0, 0, 0, 0), lm := "") -> void:
		focus_mode = Control.FOCUS_NONE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(160, 120)
		var n := UI.sb(Color(0.085, 0.092, 0.115), 16, Color(1, 1, 1, 0.1), 1)
		var hv := UI.sb(Color(0.1, 0.105, 0.13), 16, UI.ACCENT, 3)
		add_theme_stylebox_override("normal", n)
		add_theme_stylebox_override("hover", hv)
		add_theme_stylebox_override("pressed", hv)
		add_theme_stylebox_override("focus", n)
		var art := StageArt.new(th, wx)
		art.poster = true
		art.landmark = lm
		art.grade = grade
		art.speed = 1.4
		art.dim = 0.55 if locked else 0.0
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.offset_left = 9
		art.offset_top = 9
		art.offset_right = -9
		art.offset_bottom = -9
		add_child(art)
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		v.offset_left = 30
		v.offset_right = -30
		v.offset_bottom = -28
		v.offset_top = -120
		v.alignment = BoxContainer.ALIGNMENT_END
		v.add_theme_constant_override("separation", 4)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(v)
		var tl := UI.title(v, title, 46 if big else 32, Color.WHITE)
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bar := ColorRect.new()
		bar.color = UI.ACCENT if not locked else Color(1, 1, 1, 0.3)
		bar.custom_minimum_size = Vector2(54, 4)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(bar)
		var sl := UI.lbl(v, sub, 15 if big else 14, Color(0.88, 0.9, 0.95), true)
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if badge != "":
			var pill := PanelContainer.new()
			pill.add_theme_stylebox_override("panel", UI.sb(Color(0, 0, 0, 0.62) if not locked else Color(0.15, 0.16, 0.2, 0.9), 14, Color(1, 1, 1, 0.18) if locked else UI.ACCENT, 1))
			pill.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
			pill.offset_left = 26
			pill.offset_top = 24
			pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(pill)
			var pm := MarginContainer.new()
			pm.add_theme_constant_override("margin_left", 12)
			pm.add_theme_constant_override("margin_right", 12)
			pm.add_theme_constant_override("margin_top", 3)
			pm.add_theme_constant_override("margin_bottom", 3)
			pm.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pill.add_child(pm)
			var pl := UI.lbl(pm, badge, 15, UI.TXT2 if locked else UI.ACCENT, false)
			pl.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _init() -> void:
	add_theme_constant_override("separation", 12)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	add_child(top)
	UI.btn(top, "<  " + L.t("back"), UI.CARD2, func(): back.emit(), 20, Vector2(150, 48))
	var t := UI.lbl(top, UI.tx("SOLO", "اللعب الفردي"), 30, UI.TXT, false)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func build() -> void:
	# (re)build the mosaic; called every time the page opens so badges are fresh
	for c in get_children():
		if c is HBoxContainer and c.has_meta("mosaic"):
			c.queue_free()
	var got := 0
	for i in Career.COUNT:
		got += int(Profile.career.get(str(i), 0))
	var body := HBoxContainer.new()
	body.set_meta("mosaic", true)
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	var big := Tile.new(UI.tx("CAREER", "المهنة"), UI.tx("20 stages in 4 championships. Win to earn stars, coins and chests.", "20 مرحلة في 4 بطولات. فُز لتكسب النجوم والعملات والصناديق."),
		"autumn", "clear", true, false, "%d / %d  %s" % [got, Career.COUNT * 3, UI.tx("stars", "نجمة")], Color(1.0, 0.5, 0.1, 0.10), "bridge")
	big.size_flags_stretch_ratio = 1.0
	big.pressed.connect(func():
		Sfx.play("click", -6.0)
		career.emit())
	body.add_child(big)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.size_flags_stretch_ratio = 1.9
	body.add_child(grid)
	var t1 := Tile.new(UI.tx("CUSTOM RACE", "سباق مخصّص"), UI.tx("Opponents, level, weather and track", "المنافسون والمستوى والطقس والمضمار"), "mountain", "fog", false, false, "", Color(0.1, 0.3, 0.7, 0.12), "tower")
	t1.pressed.connect(func():
		Sfx.play("click", -6.0)
		custom.emit())
	grid.add_child(t1)
	var t2 := Tile.new(UI.tx("QUICK START", "بداية سريعة"), UI.tx("A random stage, right now", "مرحلة عشوائية فوراً"), "snow", "night", false, false, "", Color(0.3, 0.1, 0.6, 0.12), "village")
	t2.pressed.connect(func():
		Sfx.play("click", -6.0)
		quick.emit())
	grid.add_child(t2)
	var t3 := Tile.new(UI.tx("LEADERBOARDS", "لوحة الترتيب"), UI.tx("Fastest time on every track", "أسرع زمن على كل مضمار"), "mountain", "clear", false, true, UI.tx("COMING SOON", "قريباً"), Color(0, 0, 0, 0), "tunnel")
	t3.pressed.connect(func(): soon.emit())
	grid.add_child(t3)
	var t4 := Tile.new(UI.tx("WEEKLY CHALLENGE", "التحدي الأسبوعي"), UI.tx("A new event every week", "حدث جديد كل أسبوع"), "autumn", "storm", false, true, UI.tx("COMING SOON", "قريباً"), Color(0, 0, 0, 0), "bridge")
	t4.pressed.connect(func(): soon.emit())
	grid.add_child(t4)
	var all: Array = [big] + grid.get_children()
	await get_tree().process_frame
	for k in all.size():
		UI.enter(all[k], 0.06 * k)
		UI.pop(all[k], 1.015)
