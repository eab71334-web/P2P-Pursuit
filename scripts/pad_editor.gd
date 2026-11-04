# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
class_name PadEditor
extends CanvasLayer
## Gamepad button map: every action with the button it is on; tap a row, then press the new pad button. Reset restores defaults.

var _list: VBoxContainer
var _hint: Label


func _ready() -> void:
	layer = 100
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cc)
	var box := UI.panel(cc, UI.PANEL, 16)
	box.custom_minimum_size = Vector2(640, 560)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	UI.lbl(v, UI.tx("GAMEPAD BUTTONS", "أزرار اليد"), 26, UI.ACCENT)
	_hint = UI.lbl(v, "", 15, UI.TXT2)
	_hint.custom_minimum_size = Vector2(600, 0)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(600, 380)
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	sc.add_child(_list)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	v.add_child(hb)
	UI.btn(hb, UI.tx("Reset to default", "إعادة الافتراضي"), UI.CARD2, func(): Controls.reset_defaults(), 18, Vector2(200, 46))
	UI.btn(hb, UI.tx("Close", "إغلاق"), UI.ACCENT, queue_free, 18, Vector2(140, 46))
	Controls.changed.connect(_refresh)
	_refresh()


func _exit_tree() -> void:
	if Controls.changed.is_connected(_refresh):
		Controls.changed.disconnect(_refresh)
	Controls.start_listen("")


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var lis := Controls.listening()
	_hint.text = UI.tx("Steer: left stick · Gas: R2 · Brake: L2 (fixed).  Tap an action, then press the button you want.", "التوجيه: العصا اليسرى · بنزين: R2 · فرامل: L2 (ثابتة).  اضغط على الوظيفة ثم اضغط الزر الذي تريده.") if lis == "" else UI.tx("Press a gamepad button now...", "اضغط زراً في اليد الآن...")
	for a in Controls.ACTIONS:
		var row := UI.panel(_list, UI.ACCENT if a == lis else UI.CARD, 8)
		var h := HBoxContainer.new()
		row.add_child(h)
		var t := UI.lbl(h, UI.tx(Controls.ACTIONS[a][0], Controls.ACTIONS[a][1]), 18, UI.TXT)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.custom_minimum_size = Vector2(320, 0)
		var bl := UI.lbl(h, "…" if a == lis else Controls.button_name(int(Controls.map.get(a, -1))), 18, UI.GOLD if a != lis else Color.WHITE, false)
		bl.custom_minimum_size = Vector2(180, 0)
		row.gui_input.connect(func(e: InputEvent):
			if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
				Controls.start_listen(a)
				_refresh())
