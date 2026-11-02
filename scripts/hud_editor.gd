# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
class_name HudEditor
extends Control
## Full-screen button layout editor (used from Settings and from inside a race). Drag a button to move it,
## then use the bar to resize / rotate / reset. Only the essential driving buttons can be changed.

signal closed

var _mock := {}
var _sel := ""
var _drag := false
var _grab := Vector2.ZERO
var _info: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.07, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var title := UI.lbl(self, UI.tx("Customize buttons", "تخصيص الأزرار"), 26, UI.ACCENT, false)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 12
	title.offset_left = -300
	title.offset_right = 300
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info = UI.lbl(self, UI.tx("Drag a button to move it. Tap it, then use the bar below.", "اسحب الزر لتغيير مكانه. اضغط عليه ثم استعمل الشريط تحت."), 16, UI.TXT2, false)
	_info.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_info.offset_top = 48
	_info.offset_left = -380
	_info.offset_right = 380
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nm := HudLayout.names()
	for id in HudLayout.ORDER:
		var p := Panel.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := Label.new()
		l.text = nm[id]
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 24 if id == "gas" or id == "brake" else 20)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(l)
		add_child(p)
		_mock[id] = p
		HudLayout.place(p, id)
	_style_all()
	# bottom bar
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	bar.offset_top = 80
	bar.offset_bottom = 128
	bar.offset_left = -430
	bar.offset_right = 430
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(bar)
	UI.btn(bar, UI.tx("Size -", "حجم -"), UI.CARD2, _scale.bind(-0.1), 18, Vector2(96, 48))
	UI.btn(bar, UI.tx("Size +", "حجم +"), UI.CARD2, _scale.bind(0.1), 18, Vector2(96, 48))
	UI.btn(bar, UI.tx("Rotate <", "لفّ <"), UI.CARD2, _rot.bind(-15.0), 18, Vector2(100, 48))
	UI.btn(bar, UI.tx("Rotate >", "لفّ >"), UI.CARD2, _rot.bind(15.0), 18, Vector2(100, 48))
	UI.btn(bar, UI.tx("Reset button", "إعادة الزر"), UI.CARD2, _reset_one, 18, Vector2(130, 48))
	UI.btn(bar, UI.tx("Reset all", "إعادة الكل"), UI.CARD2, _reset_all, 18, Vector2(120, 48))
	UI.btn(bar, UI.tx("Done", "تم"), UI.ACCENT, _done, 20, Vector2(96, 48))


func _style_all() -> void:
	for id in _mock:
		var sb := StyleBoxFlat.new()
		var on: bool = id == _sel
		sb.bg_color = Color(1.0, 0.6, 0.05, 0.55) if on else Color(1, 1, 1, 0.2)
		sb.set_corner_radius_all(14)
		sb.border_color = Color(1.0, 0.8, 0.2) if on else Color(1, 1, 1, 0.55)
		sb.set_border_width_all(4 if on else 3)
		(_mock[id] as Panel).add_theme_stylebox_override("panel", sb)


func _hit(pos: Vector2) -> String:
	for i in range(HudLayout.ORDER.size() - 1, -1, -1):
		var id: String = HudLayout.ORDER[i]
		var c: Control = _mock[id]
		var l := c.get_global_transform().affine_inverse() * pos
		if Rect2(Vector2.ZERO, c.size).has_point(l):
			return id
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			var id := _hit(mb.position)
			if id != "":
				_sel = id
				_drag = true
				var c: Control = _mock[id]
				_grab = mb.position - (c.get_global_transform() * (c.size * 0.5))
				_style_all()
		else:
			_drag = false
	elif event is InputEventMouseMotion and _drag and _sel != "":
		var mm := event as InputEventMouseMotion
		var vs := get_viewport_rect().size
		var centre := mm.position - _grab
		var e := HudLayout.entry(_sel)
		e["fx"] = centre.x / vs.x
		e["fy"] = centre.y / vs.y
		HudLayout.set_entry(_sel, e)
		HudLayout.place(_mock[_sel], _sel)


func _scale(d: float) -> void:
	if _sel == "":
		return
	var e := HudLayout.entry(_sel)
	e["sc"] = float(e["sc"]) + d
	HudLayout.set_entry(_sel, e)
	HudLayout.place(_mock[_sel], _sel)


func _rot(d: float) -> void:
	if _sel == "":
		return
	var e := HudLayout.entry(_sel)
	e["rot"] = float(e["rot"]) + d
	HudLayout.set_entry(_sel, e)
	HudLayout.place(_mock[_sel], _sel)


func _reset_one() -> void:
	if _sel == "":
		return
	HudLayout.reset(_sel)
	HudLayout.place(_mock[_sel], _sel)


func _reset_all() -> void:
	HudLayout.reset()
	for id in _mock:
		HudLayout.place(_mock[id], id)


func _done() -> void:
	HudLayout.mark_intro()
	closed.emit()
	queue_free()


## first-time card: tells the player the buttons can be customised (and offers to do it now)
static func intro(parent: Control, on_done: Callable) -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.z_index = 150
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.08, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.sb(UI.CARD, 18, UI.ACCENT, 3))
	card.custom_minimum_size = Vector2(620, 0)
	cc.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	var t := UI.lbl(v, UI.tx("Make the buttons yours", "خصّص الأزرار على كيفك"), 30, UI.ACCENT, false)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var b := UI.lbl(v, UI.tx("The basic driving buttons (gas, brake, horn, signals, lights, wipers) are already in place.\nYou can move any of them anywhere, change its size, rotate it, or reset it.\nYou can do this any time from the BUTTONS key in the race, or from Settings.",
		"الأزرار الأساسية للسواقة (بنزين، فرامل، بوق، إشارات، إضاءة، مساحات) موجودة جاهزة.\nتقدر تحرّك أي زر لأي مكان، وتغيّر حجمه، وتلفّه، أو ترجّعه كما كان.\nتقدر تسوي هذا في أي وقت من زر الأزرار داخل السباق أو من الإعدادات."), 19, UI.TXT, true)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(560, 0)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	var finish := func():
		HudLayout.mark_intro()
		root.queue_free()
		on_done.call()
	UI.btn(h, UI.tx("Later", "لاحقاً"), UI.CARD2, finish, 22, Vector2(180, 54))
	UI.btn(h, UI.tx("Customize now", "خصّص الآن"), UI.ACCENT, func():
		var ed := HudEditor.new()
		ed.closed.connect(finish)
		root.add_child(ed), 22, Vector2(230, 54))
	parent.add_child(root)
