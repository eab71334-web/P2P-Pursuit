# Copyright (c) 2026 KRG Studios. All rights reserved. See LICENSE.
class_name HudEditor
extends Control
## Full-screen button layout editor (used from Settings and from inside a race). Drag a button to move it,
## then use the bar to resize / rotate / reset. Only the essential driving buttons can be changed.

signal closed

var _mock := {}
var _os: HSlider
var _pill: Control
var _pill_at := 0
var _pill_open := false
var _pill_k := 1.0
const NEUTRAL := Color(0.2, 0.23, 0.32)
const DANGER := Color(0.6, 0.17, 0.17)
const OKC := Color(0.18, 0.48, 0.28)
var _undo: Array = []
var _last_push := 0
var _top: Control
var _tg: Button
var _idle := 0.0
var _guides: Control
var _gx := -1.0
var _gy := -1.0
var _pp := {}
var _pp_base := {}
var _chip: Button
var _hide_cb := Callable()
var _more_btn: Button
var _syncing := false
var _selset := {}               # selected button ids
var _multi := false
var _multi_btn: Button
var _touch_seen := false
var _ptrs := {}                 # finger index -> {id, pos, grab}
var _pinch := {}
var _layer: Control
var _picker: Control
var _picker_box: VBoxContainer
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
	_layer = Control.new()                         # the mock buttons live here, under the bars and dialogs
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	_guides = Control.new()
	_guides.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_guides.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guides.draw.connect(func():
		var vsz := _guides.size
		if _gx >= 0.0:
			_guides.draw_line(Vector2(_gx * vsz.x, 0), Vector2(_gx * vsz.x, vsz.y), Color(0.3, 0.9, 1.0, 0.8), 2.0)
		if _gy >= 0.0:
			_guides.draw_line(Vector2(0, _gy * vsz.y), Vector2(vsz.x, _gy * vsz.y), Color(0.3, 0.9, 1.0, 0.8), 2.0))
	add_child(_guides)
	_build_mocks()
	_intro_mocks()
	# ---- top strip: exit | title | layouts | save | delete | done
	var top := PanelContainer.new()
	_top = top
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.055, 0.065, 0.095, 0.98)
	tsb.border_color = UI.ACCENT
	tsb.border_width_bottom = 3
	tsb.content_margin_left = 12
	tsb.content_margin_right = 12
	tsb.content_margin_top = 5
	tsb.content_margin_bottom = 5
	top.add_theme_stylebox_override("panel", tsb)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(top)
	# small tab that hides the top strip, so buttons under it (Reset, Emote...) can be grabbed too
	var tg := Button.new()
	tg.text = UI.tx("Hide bar", "إخفاء الشريط")
	tg.focus_mode = Control.FOCUS_NONE
	tg.add_theme_font_size_override("font_size", 15)
	tg.anchor_left = 0.0
	tg.anchor_right = 0.0
	tg.offset_left = 12
	tg.offset_right = 160
	tg.offset_top = 122
	tg.offset_bottom = 150
	tg.add_theme_stylebox_override("normal", UI.sb(Color(0.055, 0.065, 0.095, 0.95), 8, UI.ACCENT, 1))
	tg.add_theme_stylebox_override("hover", UI.sb(Color(0.1, 0.11, 0.15, 0.95), 8, UI.ACCENT, 1))
	tg.add_theme_stylebox_override("pressed", UI.sb(Color(0.1, 0.11, 0.15, 0.95), 8, UI.ACCENT, 1))
	tg.offset_top = 4
	tg.offset_bottom = 32
	tg.visible = false
	tg.text = UI.tx("Show bar", "إظهار الشريط")
	var tgl := func():
		top.visible = not top.visible
		_idle = 0.0
		_pill_refresh(top.visible)
		tg.visible = not top.visible
	tg.pressed.connect(tgl)
	_hide_cb = tgl
	_tg = tg
	add_child(tg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_bh = 40.0
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 6)
	top.add_child(tv)
	tv.add_child(row)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	tv.add_child(row2)
	_tbtn(row, UI.tx("✕ Exit", "✕ خروج"), DANGER, _exit, 18, 92)
	_tbtn(row, UI.tx("＋ Add / remove", "＋ إضافة / حذف أزرار"), NEUTRAL, _open_picker, 18, 170)
	_more_btn = _tbtn(row, "", NEUTRAL, func():
		_push_undo()
		if HudLayout.is_on_screen("c_more"):
			HudLayout.remove_button("c_more")
		else:
			HudLayout.add_button("c_more")
		_build_mocks()
		_more_label(), 17, 150)
	_more_label()
	var oc := UI.lbl(row2, UI.tx("Opacity (selected)", "شفافية المحدد"), 15, UI.TXT2, false)
	oc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_os = HSlider.new()
	_os.min_value = 0.15
	_os.max_value = 1.0
	_os.step = 0.05
	_os.value = 1.0
	_os.editable = false
	_os.custom_minimum_size = Vector2(130, 30)
	_os.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row2.add_child(_os)
	_os.value_changed.connect(func(v: float):
		if _syncing:
			return
		for t in _targets():
			var e := HudLayout.entry(t)
			e["al"] = v
			HudLayout.set_entry(t, e)
		_style_all())
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(sp)
	var cap := UI.lbl(row2, UI.tx("Layouts", "التخصيصات"), 16, UI.TXT2, false)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_scroll = ScrollContainer.new()
	_slot_scroll.custom_minimum_size = Vector2(320, 48)
	_slot_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_slot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	row2.add_child(_slot_scroll)
	_slot_bar = HBoxContainer.new()
	_slot_bar.add_theme_constant_override("separation", 6)
	_slot_scroll.add_child(_slot_bar)
	_tbtn(row2, UI.tx("▤ Hide bars", "▤ إخفاء الشريط"), NEUTRAL, func(): _hide_cb.call(), 17, 150)
	_tbtn(row, UI.tx("↶ Undo", "↶ تراجع"), NEUTRAL, _do_undo, 17, 110)
	_tbtn(row, UI.tx("↺ Reset ALL", "↺ إعادة الكل للأصل"), DANGER, _reset_all_ask, 17, 170)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp2)
	_tbtn(row, UI.tx("▣ Save", "▣ حفظ"), OKC, _save_slot, 18, 90)
	_tbtn(row, UI.tx("✕ Delete", "✕ مسح"), DANGER, _del_slot, 18, 90)
	_tbtn(row, UI.tx("✓ Done", "✓ تم"), UI.ACCENT, _done, 20, 90)
	_bh = 46.0
	# ---- hint under the strip
	var hint := PanelContainer.new()
	hint.add_theme_stylebox_override("panel", UI.sb(Color(0, 0, 0, 0.45), 12))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hc := CenterContainer.new()
	hc.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hc.offset_top = 124
	hc.offset_bottom = 160
	hc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hc)
	hc.add_child(hint)
	_info = UI.lbl(hint, UI.tx("Drag to move. Two fingers on a button = resize + turn. Several fingers = several buttons at once. Done keeps, Exit discards.",
		"اسحب الزر لتحريكه. إصبعان على الزر = تكبير ولفّ. أكثر من إصبع = أكثر من زر معاً. «تم» يحفظ و«خروج» يلغي."), 15, UI.TXT2, false)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ---- tools pill, bottom left (never over GAS / BRAKE)
	var pill := PanelContainer.new()
	_pill = pill
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
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	pill.add_child(pv)
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 8)
	pv.add_child(pr)
	var pb := HBoxContainer.new()
	pb.add_theme_constant_override("separation", 8)
	pv.add_child(pb)
	var hd := PanelContainer.new()
	hd.add_theme_stylebox_override("panel", UI.sb(Color(1.0, 0.6, 0.05, 0.22), 10, UI.ACCENT, 2))
	hd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hd.custom_minimum_size = Vector2(120, 0)
	pr.add_child(hd)
	_sel_lbl = UI.lbl(hd, "", 18, Color(1.0, 0.85, 0.4), false)
	_sel_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sel_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sel_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tbtn(pr, UI.tx("< Prev", "السابق >"), NEUTRAL, _cycle.bind(-1), 17, 90)
	_tbtn(pr, UI.tx("Next >", "< التالي"), NEUTRAL, _cycle.bind(1), 17, 90)
	_multi_btn = _tbtn(pr, UI.tx("Multi", "متعدد"), UI.CARD2, _toggle_multi, 17, 84)
	_tbtn(pr, UI.tx("All", "الكل"), UI.CARD2, _select_all, 17, 64)
	_tbtn(pr, UI.tx("Reset", "إعادة"), UI.CARD2, _reset_one, 17, 80)
	_tbtn(pr, UI.tx("⇄ Move bar", "⇄ انقل الشريط"), NEUTRAL, func():
		_pill_at = (_pill_at + 1) % 3
		_place_pill(), 17, 120)
	_tbtn(pb, UI.tx("－ Size", "－ حجم"), UI.CARD2, _scale.bind(-0.1), 17, 78)
	_tbtn(pb, UI.tx("＋ Size", "＋ حجم"), UI.CARD2, _scale.bind(0.1), 17, 78)
	_tbtn(pb, UI.tx("⟲ Turn", "⟲ لفّ"), UI.CARD2, _rot.bind(-15.0), 17, 78)
	_tbtn(pb, UI.tx("⟳ Turn", "⟳ لفّ"), UI.CARD2, _rot.bind(15.0), 17, 78)
	for nd in [["◀", -1.0, 0.0], ["▶", 1.0, 0.0], ["▲", 0.0, -1.0], ["▼", 0.0, 1.0]]:
		_tbtn(pb, nd[0], NEUTRAL, _nudge.bind(nd[1], nd[2]), 20, 56)
	_tbtn(pb, UI.tx("－ Bar", "－ الشريط"), UI.CARD2, _pill_zoom.bind(-0.15), 16, 90)
	_tbtn(pb, UI.tx("＋ Bar", "＋ الشريط"), UI.CARD2, _pill_zoom.bind(0.15), 16, 90)
	_tbtn(pr, "✕", DANGER, func(): _pill_set(false), 18, 48)
	_place_pill()
	pill.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			var q := _pill as Control
			q.offset_left += ev.relative.x
			q.offset_right += ev.relative.x
			q.offset_top += ev.relative.y
			q.offset_bottom += ev.relative.y)
	# small chip that opens the tools: the middle of the screen stays free for the player's buttons
	_chip = Button.new()
	_chip.text = UI.tx("Tools ▴", "أدوات ▴")
	_chip.focus_mode = Control.FOCUS_NONE
	_chip.add_theme_font_size_override("font_size", 17)
	_chip.anchor_left = 0.33
	_chip.anchor_right = 0.33
	_chip.anchor_top = 1.0
	_chip.anchor_bottom = 1.0
	_chip.offset_left = -50
	_chip.offset_right = 50
	_chip.offset_top = -52
	_chip.offset_bottom = -8
	for st in ["normal", "hover", "pressed", "focus"]:
		_chip.add_theme_stylebox_override(st, UI.sb(Color(0.055, 0.065, 0.095, 0.96), 14, UI.ACCENT, 2))
	_chip.pressed.connect(func(): _pill_set(true))
	add_child(_chip)
	_pill_set(false)
	_build_slots()
	_sel_text()


func _build_mocks() -> void:
	for id in _mock:
		(_mock[id] as Control).queue_free()
	_mock.clear()
	var nm := HudLayout.names()
	for id in HudLayout.ORDER:
		if not HudLayout.is_on_screen(id):
			_selset.erase(id)
			continue
		var p := Panel.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := Label.new()
		var lk := HudLayout.look(id)
		l.text = str(lk.get("txt", "")) if str(lk.get("txt", "")) != "" else nm[id]
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", int(lk.get("fs", 24 if id == "gas" or id == "brake" else 20)))
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 8)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(l)
		_layer.add_child(p)
		_mock[id] = p
		HudLayout.place(p, id)
	_style_all()
	_sel_text()


## "+ / -" dialog: every button of the game, tap to put it on the screen or take it off
func _open_picker() -> void:
	if _picker != null and is_instance_valid(_picker):
		return
	_picker = Control.new()
	_picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picker.z_index = 20
	add_child(_picker)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picker.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picker.add_child(cc)
	var card := PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.07, 0.08, 0.115)
	csb.set_corner_radius_all(20)
	csb.border_color = UI.ACCENT
	csb.set_border_width_all(3)
	csb.content_margin_left = 22
	csb.content_margin_right = 22
	csb.content_margin_top = 16
	csb.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", csb)
	cc.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var hd := UI.lbl(v, UI.tx("Add / remove buttons", "إضافة وحذف الأزرار"), 28, UI.ACCENT, false)
	hd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := UI.lbl(v, UI.tx("Tap a button to put it on your screen (green) or take it off. Buttons you take off stay in the MORE page, except the basic ones which are hidden.",
		"اضغط على زر لوضعه على شاشتك (أخضر) أو إزالته. الأزرار الإضافية المزالة ترجع لصفحة «المزيد»، والأساسية تختفي."), 15, UI.TXT2, true)
	sub.custom_minimum_size = Vector2(700, 0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_picker_box = VBoxContainer.new()
	_picker_box.add_theme_constant_override("separation", 8)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(720, 300)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_child(_picker_box)
	_picker_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	_picker_fill()
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	_tbtn(h, UI.tx("Close", "إغلاق"), UI.ACCENT, func():
		_picker.queue_free()
		_picker = null, 22, 160)


func _picker_fill() -> void:
	for c in _picker_box.get_children():
		_picker_box.remove_child(c)
		c.queue_free()
	var nm := HudLayout.names()
	for sec in [[UI.tx("Driving", "السواقة"), HudLayout.ESSENTIAL], [UI.tx("Cabin extras", "إضافات الكابينة"), HudLayout.EXTRA], [UI.tx("Other buttons (switch off / on)", "أزرار أخرى (إيقاف / تشغيل)"), HudLayout.HIDEABLE]]:
		var l := UI.lbl(_picker_box, sec[0], 17, UI.TXT2, false)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var g := GridContainer.new()
		g.columns = 3
		g.add_theme_constant_override("h_separation", 8)
		g.add_theme_constant_override("v_separation", 8)
		_picker_box.add_child(g)
		for id in sec[1]:
			if not HudLayout.exists(id):
				continue
			var on := HudLayout.is_on_screen(id)
			var locked: bool = HudLayout.LOCKED.has(id)
			var b := Button.new()
			b.custom_minimum_size = Vector2(228, 58)
			b.text = ("✓  " if on else "+  ") + nm[id] + ("   🔒" if locked else "")
			b.add_theme_font_size_override("font_size", 18)
			var col := Color(0.14, 0.38, 0.22) if on else Color(0.13, 0.14, 0.19)
			for st in ["normal", "hover", "pressed", "focus", "disabled"]:
				b.add_theme_stylebox_override(st, UI.sb(col, 14, Color(0.4, 0.85, 0.55, 0.8) if on else Color(1, 1, 1, 0.12), 2))
			b.add_theme_color_override("font_color", UI.TXT if on else UI.TXT2)
			b.add_theme_color_override("font_disabled_color", UI.TXT)
			b.disabled = locked
			var bid: String = id
			b.pressed.connect(func():
				_push_undo()
				if HudLayout.is_on_screen(bid):
					HudLayout.remove_button(bid)
					_say(UI.tx("%s removed" % HudLayout.names()[bid], "تم حذف %s" % HudLayout.names()[bid]))
				else:
					HudLayout.add_button(bid)
					_say(UI.tx("%s added - drag it where you want" % HudLayout.names()[bid], "تمت إضافة %s - اسحبه للمكان اللي تبيه" % HudLayout.names()[bid]))
				_build_mocks()
				_picker_fill())
			g.add_child(b)


const GLYPH_ICO := {"✕": "close", "＋": "plus", "－": "minus", "↺": "reset", "↶": "undo", "↻": "redo", "⟲": "rot_l", "⟳": "rot_r",
	"✓": "check", "▣": "save", "▤": "hide", "⇄": "move", "◀": "left", "▶": "right", "▲": "up", "▼": "down"}
var _bh := 46.0


## editor button: a leading glyph in the text becomes a drawn icon (icon only when nothing follows it)
func _tbtn(parent: Node, text: String, col: Color, cb: Callable, fs: int, w: float) -> Button:
	var ico := ""
	if text != "" and GLYPH_ICO.has(text.substr(0, 1)):
		ico = GLYPH_ICO[text.substr(0, 1)]
		text = text.substr(1).strip_edges()
	var b := UI.btn(parent, text, col, cb, fs, Vector2(w, _bh))
	for st in ["normal", "hover", "pressed", "focus"]:
		var sbx := b.get_theme_stylebox(st) as StyleBoxFlat
		sbx.set_corner_radius_all(12)
		sbx.content_margin_left = 34 if (ico != "" and text != "") else 8
		sbx.content_margin_right = 8
		sbx.border_width_bottom = 3
		sbx.border_color = col.darkened(0.4)
		sbx.shadow_size = 3
		sbx.shadow_color = Color(0, 0, 0, 0.35)
		sbx.shadow_offset = Vector2(0, 2)
	if ico != "":
		var ic := Ico.new(ico)
		ic.layout_direction = Control.LAYOUT_DIRECTION_LTR
		ic.anchor_top = 0.5
		ic.anchor_bottom = 0.5
		ic.offset_top = -11
		ic.offset_bottom = 11
		if text == "":
			ic.anchor_left = 0.5
			ic.anchor_right = 0.5
			ic.offset_left = -11
			ic.offset_right = 11
		else:
			ic.anchor_left = 0.0
			ic.anchor_right = 0.0
			ic.offset_left = 9
			ic.offset_right = 31
		b.add_child(ic)
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


## opening: the screen fades in and the buttons pop in one after another
func _intro_mocks() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.22)
	var i := 0
	for id in _mock:
		var m := _mock[id] as Control
		var sc: Vector2 = m.scale
		m.scale = sc * 0.8
		m.self_modulate.a = 0.0
		var tw := m.create_tween().set_parallel(true)
		tw.tween_property(m, "scale", sc, 0.28).set_delay(0.03 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(m, "self_modulate:a", 1.0, 0.2).set_delay(0.03 * i)
		i += 1


## closing: the real HUD shows at once, the editor fades away
func _leave() -> void:
	closed.emit()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(false)
	for c in get_children():
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)


## a quick flash on a button (picked / snapped)
func _flash(id: String) -> void:
	if not _mock.has(id):
		return
	var m := _mock[id] as Control
	m.self_modulate = Color(1.7, 1.7, 1.7, 1.0)
	m.create_tween().tween_property(m, "self_modulate", Color(1, 1, 1, 1), 0.22)


func _sel_text() -> void:
	if _sel_lbl != null:
		var n := _selset.size()
		var nt: String = UI.tx("Select a button", "اختر زراً") if n == 0 else (HudLayout.names()[_selset.keys()[0]] if n == 1 else UI.tx("%d buttons" % n, "%d أزرار" % n))
		if nt != _sel_lbl.text:
			_sel_lbl.text = nt
			var chip := _sel_lbl.get_parent() as Control
			if chip != null:
				chip.pivot_offset = chip.size * 0.5
				chip.scale = Vector2(1.14, 1.14)
				chip.create_tween().tween_property(chip, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
	_leave()


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
			_selset.clear()
			_refresh()
			_say(UI.tx("Layout %d loaded" % (idx + 1), "تم تحميل التخصيص %d" % (idx + 1)) if HudLayout.slot_filled(idx) else UI.tx("Layout %d is empty - arrange the buttons, then press Save" % (idx + 1), "التخصيص %d فارغ - رتّب الأزرار ثم اضغط حفظ" % (idx + 1))))
		_slot_bar.add_child(b)
	if HudLayout.all_filled():        # all slots used: a "+" appears to add another one (no limit)
		var pb := _tbtn(_slot_bar, "+", Color(0.18, 0.42, 0.25), func():
			HudLayout.add_slot()
			_selset.clear()
			_refresh()
			_say(UI.tx("New layout added", "تمت إضافة تخصيص جديد")), 26, 54)
		pb.custom_minimum_size = Vector2(54, 46)


func _refresh() -> void:
	_build_mocks()
	_build_slots()


func _say(t: String) -> void:
	_info.text = t


func _more_label() -> void:
	if _more_btn != null:
		_more_btn.text = UI.tx("MORE button: ", "زر المزيد: ") + (UI.tx("ON", "مفعّل") if HudLayout.is_on_screen("c_more") else UI.tx("OFF", "مطفي"))


func _sync_alpha() -> void:
	if _os == null:
		return
	var ts := _targets()
	_os.editable = ts.size() > 0
	if ts.size() > 0:
		_syncing = true
		_os.value = float(HudLayout.entry(ts[0]).get("al", 1.0))
		_syncing = false


func _style_all() -> void:
	for id in _mock:
		var pn := _mock[id] as Panel
		var sb := StyleBoxFlat.new()
		var on: bool = _selset.has(id)
		sb.bg_color = Color(1.0, 0.6, 0.05, 0.4) if on else Color(1, 1, 1, 0.18)        # same fill / border as in the race
		sb.set_corner_radius_all(14)
		sb.border_color = Color(1.0, 0.8, 0.2) if on else Color(1, 1, 1, 0.5)
		sb.set_border_width_all(3)
		pn.add_theme_stylebox_override("panel", sb)
		pn.modulate.a = float(HudLayout.entry(id).get("al", 1.0))
		var glow := pn.get_node_or_null("Glow") as Panel
		if on and glow == null:
			glow = Panel.new()
			glow.name = "Glow"
			glow.set_anchors_preset(Control.PRESET_FULL_RECT)
			glow.offset_left = -5
			glow.offset_top = -5
			glow.offset_right = 5
			glow.offset_bottom = 5
			glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var gs := StyleBoxFlat.new()
			gs.bg_color = Color(0, 0, 0, 0)
			gs.set_corner_radius_all(18)
			gs.border_color = Color(1.0, 0.75, 0.2)
			gs.set_border_width_all(3)
			glow.add_theme_stylebox_override("panel", gs)
			pn.add_child(glow)
			var tw := glow.create_tween().set_loops()
			tw.tween_property(glow, "modulate:a", 0.25, 0.55)
			tw.tween_property(glow, "modulate:a", 1.0, 0.55)
		elif not on and glow != null:
			glow.queue_free()
	_sync_alpha()


func _hit(pos: Vector2) -> String:
	for i in range(HudLayout.ORDER.size() - 1, -1, -1):
		var id: String = HudLayout.ORDER[i]
		if not _mock.has(id):
			continue
		var c: Control = _mock[id]
		var l := c.get_global_transform().affine_inverse() * pos
		if Rect2(Vector2.ZERO, c.size).has_point(l):
			return id
	return ""


func _centre(id: String) -> Vector2:
	var c: Control = _mock[id]
	return c.get_global_transform() * (c.size * 0.5)


## buttons the tools act on: the selected ones
func _targets() -> Array:
	return _selset.keys()


func _select(id: String) -> void:
	if _multi:
		if _selset.has(id):
			_selset.erase(id)
		else:
			_selset[id] = true
	elif not _selset.has(id) or _selset.size() > 1:
		_selset.clear()
		_selset[id] = true
	_sel_text()
	_style_all()
	_flash(id)


# ---- touch: every finger drags its own button (so several can be moved at once); two fingers on one button
# pinch (size) and twist (rotation); with "Multi" on, selected buttons move / resize / turn together.
func _process(delta: float) -> void:
	if _top == null or not _top.visible:
		return
	_idle += delta
	if _idle > 5.0 and _ptrs.is_empty() and not (_picker != null and is_instance_valid(_picker)):
		_top.visible = false                       # the top strip tucks away by itself so the buttons under it can be reached
		_tg.visible = true


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if _top != null and _top.visible and _top.get_global_rect().has_point(event.position):
			_idle = 0.0
	if _pill_touch(event):
		return
	if _in_pill(get_viewport().get_mouse_position()) and event is InputEventMouseButton:
		return
	if event is InputEventScreenTouch:
		_touch_seen = true
		_ptrs.erase(-1)           # the mouse press Godot emulates from the first touch arrives before it: drop it
		var t := event as InputEventScreenTouch
		if t.pressed:
			_ptr_down(t.index, t.position)
		else:
			_ptr_up(t.index)
	elif event is InputEventScreenDrag:
		_ptr_move((event as InputEventScreenDrag).index, (event as InputEventScreenDrag).position)
	elif not _touch_seen and event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_ptr_down(-1, mb.position)
		else:
			_ptr_up(-1)
	elif not _touch_seen and event is InputEventMouseMotion and _ptrs.has(-1):
		_ptr_move(-1, (event as InputEventMouseMotion).position)


func _ptr_down(idx: int, pos: Vector2) -> void:
	var id := _hit(pos)
	if id == "":
		return
	# a second finger on the same button = pinch / twist
	for k in _ptrs:
		if k != idx and _ptrs[k]["id"] == id and not _pinch.has("a"):
			var o: Vector2 = _ptrs[k]["pos"]
			var d := pos - o
			_pinch = {"a": k, "b": idx, "d0": maxf(d.length(), 20.0), "ang0": d.angle(), "mid": (pos + o) * 0.5, "base": {}}
			if not _selset.has(id):
				_select(id)
			for t in _targets():
				_pinch["base"][t] = HudLayout.entry(t)
			_ptrs[idx] = {"id": id, "pos": pos, "grab": Vector2.ZERO}
			return
	_select(id)
	_push_undo()
	_fade_bars(true)
	_ptrs[idx] = {"id": id, "pos": pos, "grab": pos - _centre(id)}


func _ptr_up(idx: int) -> void:
	if not _ptrs.has(idx):
		return
	_ptrs.erase(idx)
	if _ptrs.is_empty():
		_fade_bars(false)
		_gx = -1.0
		_gy = -1.0
		_guides.queue_redraw()
	if _pinch.has("a") and (int(_pinch["a"]) == idx or int(_pinch["b"]) == idx):
		_pinch = {}
		for k in _ptrs:                         # the finger that stays keeps dragging
			_ptrs[k]["grab"] = _ptrs[k]["pos"] - _centre(_ptrs[k]["id"])


func _ptr_move(idx: int, pos: Vector2) -> void:
	if not _ptrs.has(idx):
		return
	_ptrs[idx]["pos"] = pos
	var vs := get_viewport_rect().size
	if _pinch.has("a"):
		if not (_ptrs.has(_pinch["a"]) and _ptrs.has(_pinch["b"])):
			return
		var pa: Vector2 = _ptrs[_pinch["a"]]["pos"]
		var pb: Vector2 = _ptrs[_pinch["b"]]["pos"]
		var d := pb - pa
		var ratio := d.length() / float(_pinch["d0"])
		var dang := rad_to_deg(wrapf(d.angle() - float(_pinch["ang0"]), -PI, PI))
		var shift := ((pa + pb) * 0.5 - (_pinch["mid"] as Vector2)) / vs
		for t in _pinch["base"]:
			var e: Dictionary = (_pinch["base"][t] as Dictionary).duplicate()
			e["sc"] = float(e["sc"]) * ratio
			e["rot"] = float(e["rot"]) + dang
			e["fx"] = float(e["fx"]) + shift.x
			e["fy"] = float(e["fy"]) + shift.y
			HudLayout.set_entry(t, e)
			HudLayout.place(_mock[t], t)
		return
	var id: String = _ptrs[idx]["id"]
	var old := _centre(id)
	var delta: Vector2 = (pos - (_ptrs[idx]["grab"] as Vector2)) - old
	var group: Array = _targets() if _selset.has(id) else [id]
	for t in group:
		var e := HudLayout.entry(t)
		e["fx"] = float(e["fx"]) + delta.x / vs.x
		e["fy"] = float(e["fy"]) + delta.y / vs.y
		if group.size() == 1:
			_snap_guides(t, e)
		HudLayout.set_entry(t, e)
		HudLayout.place(_mock[t], t)


func _push_undo(throttle := false) -> void:
	var now := Time.get_ticks_msec()
	if throttle and now - _last_push < 700:
		return
	_last_push = now
	_undo.append(HudLayout.snapshot())
	if _undo.size() > 40:
		_undo.pop_front()


func _do_undo() -> void:
	if _undo.is_empty():
		_say(UI.tx("Nothing to undo", "ما في شي للتراجع عنه"))
		return
	HudLayout.restore(_undo.pop_back())
	_build_mocks()
	_more_label()


func _fade_bars(on: bool) -> void:
	var a := 0.2 if on else 1.0
	for n in [_top, _pill]:
		if n != null:
			var tw := (n as Control).create_tween()
			tw.tween_property(n, "modulate:a", a, 0.15)


func _snap_guides(id: String, e: Dictionary) -> void:
	var old_gx := _gx
	var old_gy := _gy
	var tx := 0.007
	var ty := 0.012
	_gx = -1.0
	_gy = -1.0
	var xs: Array = [0.5]
	var ys: Array = [0.5]
	for k in _mock:
		if k == id:
			continue
		var o := HudLayout.entry(k)
		xs.append(float(o["fx"]))
		ys.append(float(o["fy"]))
	var bx := tx
	for x in xs:
		if absf(float(e["fx"]) - float(x)) < bx:
			bx = absf(float(e["fx"]) - float(x))
			e["fx"] = float(x)
			_gx = float(x)
	var by := ty
	for y in ys:
		if absf(float(e["fy"]) - float(y)) < by:
			by = absf(float(e["fy"]) - float(y))
			e["fy"] = float(y)
			_gy = float(y)
	if (_gx >= 0.0 and not is_equal_approx(_gx, old_gx)) or (_gy >= 0.0 and not is_equal_approx(_gy, old_gy)):
		_flash(id)
	_guides.queue_redraw()


func _scale(d: float) -> void:
	_push_undo(true)
	for t in _targets():
		var e := HudLayout.entry(t)
		e["sc"] = float(e["sc"]) + d
		HudLayout.set_entry(t, e)
		HudLayout.place(_mock[t], t)


func _rot(d: float) -> void:
	_push_undo(true)
	for t in _targets():
		var e := HudLayout.entry(t)
		e["rot"] = float(e["rot"]) + d
		HudLayout.set_entry(t, e)
		HudLayout.place(_mock[t], t)


## pick the next / previous button (reaches the ones that are covered or too close to grab)
func _cycle(d: int) -> void:
	var ids: Array = []
	for id in HudLayout.ORDER:
		if _mock.has(id):
			ids.append(id)
	if ids.is_empty():
		return
	var cur := -1
	for k in _selset:
		cur = ids.find(k)
		break
	var n := ids.size()
	var nx: int = (cur + d + n) % n if cur >= 0 else (0 if d > 0 else n - 1)
	_selset.clear()
	_selset[ids[nx]] = true
	_style_all()
	_sel_text()


## small steps with arrows: fine placement of a selected button
func _nudge(dx: float, dy: float) -> void:
	_push_undo(true)
	for t in _targets():
		var e := HudLayout.entry(t)
		e["fx"] = float(e["fx"]) + dx * 0.006
		e["fy"] = float(e["fy"]) + dy * 0.01
		HudLayout.set_entry(t, e)
		HudLayout.place(_mock[t], t)


func _reset_one() -> void:
	_push_undo()
	for t in _targets():
		HudLayout.reset(t)
		HudLayout.place(_mock[t], t)


## the tools bar sits where nothing is: middle of the screen, bottom-left, or under the top strip (button cycles)
const PILL_MIN := 0.6
const PILL_MAX := 1.6


func _pill_zoom(d: float) -> void:
	_pill_scale(_pill_k + d)


func _pill_scale(k: float) -> void:
	_pill_k = clampf(k, PILL_MIN, PILL_MAX)
	if _pill != null:
		(_pill as Control).pivot_offset = (_pill as Control).size * 0.5
		(_pill as Control).scale = Vector2(_pill_k, _pill_k)


func _in_pill(pos: Vector2) -> bool:
	if _pill == null or not _pill.visible:
		return false
	var c := _pill as Control
	return Rect2(Vector2.ZERO, c.size).has_point(c.get_global_transform().affine_inverse() * pos)


## two fingers on the tools bar = pinch to resize it
func _pill_touch(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _in_pill(t.position):
			_pp[t.index] = t.position
			if _pp.size() == 2:
				var ks := _pp.keys()
				_pp_base = {"d": maxf((_pp[ks[0]] - _pp[ks[1]]).length(), 20.0), "k": _pill_k}
			return true
		if not t.pressed and _pp.has(t.index):
			_pp.erase(t.index)
			_pp_base = {}
			return true
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _pp.has(d.index):
			_pp[d.index] = d.position
			if _pp.size() == 2 and not _pp_base.is_empty():
				var ks := _pp.keys()
				_pill_scale(float(_pp_base["k"]) * (_pp[ks[0]] - _pp[ks[1]]).length() / float(_pp_base["d"]))
			return true
	return false


func _pill_set(on: bool) -> void:
	_pill_open = on
	if on:
		_place_pill()
		_pill_scale.call_deferred(_pill_k)
	_pill_refresh(true)


func _pill_refresh(bars_on: bool) -> void:
	if _pill != null:
		_pill.visible = _pill_open and bars_on
	if _chip != null:
		_chip.visible = (not _pill_open) and bars_on


func _place_pill() -> void:
	if _pill == null:
		return
	var p := _pill as Control
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	match _pill_at:
		0:
			p.anchor_left = 0.5
			p.anchor_right = 0.5
			p.anchor_top = 0.36
			p.anchor_bottom = 0.36
		1:
			p.anchor_left = 0.5
			p.anchor_right = 0.5
			p.anchor_top = 0.97
			p.anchor_bottom = 0.97
		_:
			p.anchor_left = 0.5
			p.anchor_right = 0.5
			p.anchor_top = 0.0
			p.anchor_bottom = 0.0
	p.offset_left = 0
	p.offset_right = 0
	p.offset_top = 200 if _pill_at == 2 else -30
	p.offset_bottom = 260 if _pill_at == 2 else 30
	if _pill_at == 1:
		p.offset_top = -62
		p.offset_bottom = -2


func _reset_all_ask() -> void:
	var c := ConfirmationDialog.new()
	c.dialog_text = UI.tx("Put every button back to the game's own layout?", "ترجيع كل الأزرار لمكانها الأصلي؟")
	c.ok_button_text = UI.tx("Yes", "نعم")
	c.cancel_button_text = UI.tx("Cancel", "إلغاء")
	c.confirmed.connect(_reset_all)
	c.canceled.connect(c.queue_free)
	c.confirmed.connect(c.queue_free)
	add_child(c)
	c.popup_centered()


func _reset_all() -> void:
	_push_undo()
	HudLayout.reset()
	_build_mocks()


func _toggle_multi() -> void:
	_multi = not _multi
	_multi_btn.add_theme_stylebox_override("normal", UI.sb(UI.ACCENT if _multi else UI.CARD2, 12))
	_multi_btn.add_theme_color_override("font_color", Color(0.08, 0.06, 0.04) if _multi else UI.TXT)
	_say(UI.tx("Multi on: tap several buttons, then move / resize / turn them together", "تحديد متعدد: اضغط عدة أزرار ثم حرّكها وكبّرها ولفّها معاً") if _multi else UI.tx("Multi off", "إيقاف التحديد المتعدد"))


func _select_all() -> void:
	_selset.clear()
	for id in _mock:
		_selset[id] = true
	_sel_text()
	_style_all()


func _done() -> void:
	HudLayout.mark_intro()
	_leave()


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


## small vector icons drawn in code (no image files): used on the editor buttons
class Ico extends Control:
	var kind := "plus"

	func _init(k := "plus") -> void:
		kind = k
		custom_minimum_size = Vector2(22, 22)
		size = Vector2(22, 22)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_set_transform(Vector2(1, 1.5), 0.0, Vector2.ONE)
		_shape(Color(0, 0, 0, 0.45))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_shape(Color(1, 1, 1, 0.97))

	func _shape(c: Color) -> void:
		var w := 2.6
		var m := Vector2(11, 11)
		match kind:
			"close":
				draw_line(Vector2(5, 5), Vector2(17, 17), c, w, true)
				draw_line(Vector2(17, 5), Vector2(5, 17), c, w, true)
			"plus":
				draw_line(Vector2(4, 11), Vector2(18, 11), c, w, true)
				draw_line(Vector2(11, 4), Vector2(11, 18), c, w, true)
			"minus":
				draw_line(Vector2(4, 11), Vector2(18, 11), c, w, true)
			"check":
				draw_polyline(PackedVector2Array([Vector2(4, 12), Vector2(9, 17), Vector2(18, 6)]), c, w + 0.4, true)
			"save":
				draw_rect(Rect2(4, 4, 14, 14), c, false, w)
				draw_rect(Rect2(7, 4, 8, 5), c, true)
				draw_rect(Rect2(7, 12, 8, 6), c, false, 2.0)
			"hide":
				draw_rect(Rect2(3, 4, 16, 14), c, false, 2.2)
				draw_line(Vector2(3, 8), Vector2(19, 8), c, 2.2)
			"move":
				draw_line(Vector2(3, 8), Vector2(18, 8), c, w, true)
				draw_colored_polygon(PackedVector2Array([Vector2(18, 4), Vector2(19, 8), Vector2(18, 12)]), c)
				draw_line(Vector2(4, 15), Vector2(19, 15), c, w, true)
				draw_colored_polygon(PackedVector2Array([Vector2(4, 11), Vector2(3, 15), Vector2(4, 19)]), c)
			"reset":
				draw_arc(m, 6.5, deg_to_rad(-70), deg_to_rad(215), 20, c, w, true)
				draw_colored_polygon(PackedVector2Array([Vector2(11, 1), Vector2(11, 9), Vector2(17, 5)]), c)
				draw_circle(m, 2.0, c)
			"undo", "rot_l":
				draw_arc(m, 6.5, deg_to_rad(-60), deg_to_rad(210), 20, c, w, true)
				draw_colored_polygon(PackedVector2Array([Vector2(3, 5), Vector2(3, 12), Vector2(10, 9)]), c)
			"redo", "rot_r":
				draw_arc(m, 6.5, deg_to_rad(-30), deg_to_rad(240), 20, c, w, true)
				draw_colored_polygon(PackedVector2Array([Vector2(19, 5), Vector2(19, 12), Vector2(12, 9)]), c)
			"pad":
				draw_rect(Rect2(2, 6, 18, 11), c, false, 2.2)
				draw_line(Vector2(7, 8), Vector2(7, 15), c, 2.0)
				draw_line(Vector2(4, 11.5), Vector2(10, 11.5), c, 2.0)
				draw_circle(Vector2(14.5, 10), 1.6, c)
				draw_circle(Vector2(17, 13), 1.6, c)
			"screen":
				draw_rect(Rect2(2, 4, 18, 11), c, false, 2.2)
				draw_line(Vector2(8, 19), Vector2(14, 19), c, 2.4)
				draw_line(Vector2(11, 15), Vector2(11, 19), c, 2.0)
			"sound":
				draw_colored_polygon(PackedVector2Array([Vector2(3, 8), Vector2(7, 8), Vector2(12, 4), Vector2(12, 18), Vector2(7, 14), Vector2(3, 14)]), c)
				draw_arc(Vector2(12, 11), 5.0, deg_to_rad(-45), deg_to_rad(45), 8, c, 2.0, true)
				draw_arc(Vector2(12, 11), 8.0, deg_to_rad(-45), deg_to_rad(45), 8, c, 2.0, true)
			"flag":
				draw_line(Vector2(5, 3), Vector2(5, 19), c, 2.4)
				draw_colored_polygon(PackedVector2Array([Vector2(6, 4), Vector2(18, 7), Vector2(6, 12)]), c)
			"left":
				draw_colored_polygon(PackedVector2Array([Vector2(15, 4), Vector2(15, 18), Vector2(5, 11)]), c)
			"right":
				draw_colored_polygon(PackedVector2Array([Vector2(7, 4), Vector2(7, 18), Vector2(17, 11)]), c)
			"up":
				draw_colored_polygon(PackedVector2Array([Vector2(4, 15), Vector2(18, 15), Vector2(11, 5)]), c)
			"down":
				draw_colored_polygon(PackedVector2Array([Vector2(4, 7), Vector2(18, 7), Vector2(11, 17)]), c)
