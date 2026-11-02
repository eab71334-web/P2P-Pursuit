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
var _slot_bar: HBoxContainer
var _slot_scroll: ScrollContainer
var _sel_lbl: Label
var _snap := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200
	_snap = HudLayout.snapshot()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.07, 0.92)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_grid_lines()
	# phone-screen frame so the player sees where the real screen ends
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
	# ---- top strip: exit | title | layouts | save | delete | done
	var top := PanelContainer.new()
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.055, 0.065, 0.095, 0.98)
	tsb.border_color = UI.ACCENT
	tsb.border_width_bottom = 3
	tsb.content_margin_left = 12
	tsb.content_margin_right = 12
	tsb.content_margin_top = 8
	tsb.content_margin_bottom = 8
	top.add_theme_stylebox_override("panel", tsb)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	top.add_child(row)
	_tbtn(row, UI.tx("Exit", "خروج"), Color(0.42, 0.16, 0.16), _exit, 18, 92)
	var title := UI.lbl(row, UI.tx("Buttons", "الأزرار"), 22, UI.ACCENT, false)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var cap := UI.lbl(row, UI.tx("Layouts", "التخصيصات"), 16, UI.TXT2, false)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_scroll = ScrollContainer.new()
	_slot_scroll.custom_minimum_size = Vector2(320, 48)
	_slot_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_slot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	row.add_child(_slot_scroll)
	_slot_bar = HBoxContainer.new()
	_slot_bar.add_theme_constant_override("separation", 6)
	_slot_scroll.add_child(_slot_bar)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp2)
	_tbtn(row, UI.tx("Save", "حفظ"), Color(0.18, 0.48, 0.28), _save_slot, 18, 90)
	_tbtn(row, UI.tx("Delete", "مسح"), Color(0.45, 0.2, 0.2), _del_slot, 18, 90)
	_tbtn(row, UI.tx("Done", "تم"), UI.ACCENT, _done, 20, 90)
	# ---- hint under the strip
	var hint := PanelContainer.new()
	hint.add_theme_stylebox_override("panel", UI.sb(Color(0, 0, 0, 0.45), 12))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hc := CenterContainer.new()
	hc.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hc.offset_top = 76
	hc.offset_bottom = 112
	hc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hc)
	hc.add_child(hint)
	_info = UI.lbl(hint, UI.tx("Drag a button to move it. Tap it to edit. Done keeps the changes, Exit throws them away.",
		"اسحب الزر لتحريكه. اضغط عليه للتعديل. «تم» يحفظ التغييرات و«خروج» يلغيها."), 15, UI.TXT2, false)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ---- tools pill, bottom left (never over GAS / BRAKE)
	var pill := PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.055, 0.065, 0.095, 0.96)
	psb.set_corner_radius_all(18)
	psb.border_color = Color(1, 1, 1, 0.18)
	psb.set_border_width_all(2)
	psb.content_margin_left = 12
	psb.content_margin_right = 12
	psb.content_margin_top = 8
	psb.content_margin_bottom = 8
	pill.add_theme_stylebox_override("panel", psb)
	pill.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	pill.offset_left = 14
	pill.offset_bottom = -12
	pill.offset_top = -72
	add_child(pill)
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 8)
	pill.add_child(pr)
	_sel_lbl = UI.lbl(pr, "", 17, UI.ACCENT, false)
	_sel_lbl.custom_minimum_size = Vector2(96, 0)
	_sel_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tbtn(pr, UI.tx("Size -", "حجم -"), UI.CARD2, _scale.bind(-0.1), 17, 84)
	_tbtn(pr, UI.tx("Size +", "حجم +"), UI.CARD2, _scale.bind(0.1), 17, 84)
	_tbtn(pr, UI.tx("Turn <", "لفّ <"), UI.CARD2, _rot.bind(-15.0), 17, 84)
	_tbtn(pr, UI.tx("Turn >", "لفّ >"), UI.CARD2, _rot.bind(15.0), 17, 84)
	_tbtn(pr, UI.tx("Reset", "إعادة"), UI.CARD2, _reset_one, 17, 80)
	_tbtn(pr, UI.tx("Reset all", "إعادة الكل"), UI.CARD2, _reset_all, 17, 100)
	_build_slots()
	_sel_text()


func _tbtn(parent: Node, text: String, col: Color, cb: Callable, fs: int, w: float) -> Button:
	var b := UI.btn(parent, text, col, cb, fs, Vector2(w, 46))
	for st in ["normal", "hover", "pressed", "focus"]:
		var sbx := b.get_theme_stylebox(st) as StyleBoxFlat
		sbx.set_corner_radius_all(12)
		sbx.content_margin_left = 8
		sbx.content_margin_right = 8
	return b


## faint guide lines so placement feels deliberate
func _grid_lines() -> void:
	for k in range(1, 4):
		for horiz in [true, false]:
			var r := ColorRect.new()
			r.color = Color(1, 1, 1, 0.04)
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if horiz:
				r.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
				r.anchor_top = k * 0.25
				r.anchor_bottom = k * 0.25
				r.offset_top = 0
				r.offset_bottom = 1
			else:
				r.set_anchors_preset(Control.PRESET_VCENTER_WIDE)
				r.anchor_left = k * 0.25
				r.anchor_right = k * 0.25
				r.anchor_top = 0.0
				r.anchor_bottom = 1.0
				r.offset_left = 0
				r.offset_right = 1
			add_child(r)


func _sel_text() -> void:
	if _sel_lbl != null:
		_sel_lbl.text = HudLayout.names()[_sel] if _sel != "" else UI.tx("Select a button", "اختر زراً")


func _save_slot() -> void:
	HudLayout.save_slot()
	_build_slots()
	_say(UI.tx("Saved to layout %d" % (HudLayout.active + 1), "تم الحفظ في التخصيص %d" % (HudLayout.active + 1)))


func _del_slot() -> void:
	var n := HudLayout.active + 1
	HudLayout.delete_slot(HudLayout.active)
	_refresh()
	_say(UI.tx("Layout %d deleted" % n, "تم مسح التخصيص %d" % n))


func _exit() -> void:
	HudLayout.restore(_snap)
	closed.emit()
	queue_free()


func _build_slots() -> void:
	for c in _slot_bar.get_children():
		_slot_bar.remove_child(c)
		c.queue_free()
	for i in HudLayout.slot_count():
		var on: bool = i == HudLayout.active
		var filled := HudLayout.slot_filled(i)
		var b := Button.new()
		b.text = str(i + 1)
		b.custom_minimum_size = Vector2(54, 46)
		b.add_theme_font_size_override("font_size", 20)
		var col := UI.ACCENT if on else (Color(0.2, 0.36, 0.25) if filled else UI.CARD2)
		for st in ["normal", "hover", "pressed", "focus"]:
			var sbx := UI.sb(col, 12, Color(1, 1, 1, 0.6) if on else (Color(0.4, 0.8, 0.5, 0.7) if filled else Color.TRANSPARENT), 2)
			sbx.content_margin_left = 6
			sbx.content_margin_right = 6
			b.add_theme_stylebox_override(st, sbx)
		b.add_theme_color_override("font_color", Color(0.08, 0.06, 0.04) if on else UI.TXT)
		var idx := i
		b.pressed.connect(func():
			HudLayout.select_slot(idx)
			_sel = ""
			_refresh()
			_say(UI.tx("Layout %d loaded" % (idx + 1), "تم تحميل التخصيص %d" % (idx + 1)) if HudLayout.slot_filled(idx) else UI.tx("Layout %d is empty - arrange the buttons, then press Save" % (idx + 1), "التخصيص %d فارغ - رتّب الأزرار ثم اضغط حفظ" % (idx + 1))))
		_slot_bar.add_child(b)
	if HudLayout.all_filled():        # all slots used: a "+" appears to add another one (no limit)
		var pb := _tbtn(_slot_bar, "+", Color(0.18, 0.42, 0.25), func():
			HudLayout.add_slot()
			_sel = ""
			_refresh()
			_say(UI.tx("New layout added", "تمت إضافة تخصيص جديد")), 26, 54)
		pb.custom_minimum_size = Vector2(54, 46)


func _refresh() -> void:
	for id in _mock:
		HudLayout.place(_mock[id], id)
	_style_all()
	_build_slots()
	_sel_text()


func _say(t: String) -> void:
	_info.text = t


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
				_sel_text()
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
