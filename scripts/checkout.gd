# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
class_name Checkout
extends Control
## Buy-coins dialog: pack summary, payment methods, pay button. Payments are not connected yet (see Billing).

var pack: Dictionary
var method := "card"
var _pay: Button
var _note: Label
var _rows := {}


class CoinStack extends Control:
	var gems := false

	func _init(p_gems := false) -> void:
		gems = p_gems
		custom_minimum_size = Vector2(96, 70)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if gems:
			var gc := Color(0.45, 0.9, 1.0)
			for i in 3:
				var c := Vector2(size.x * 0.5 + (i - 1) * 18, 40 - i * 4)
				var pts := PackedVector2Array([c + Vector2(0, -22), c + Vector2(18, -6), c + Vector2(0, 22), c + Vector2(-18, -6)])
				draw_colored_polygon(pts, gc.darkened(0.35))
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -17), c + Vector2(13, -5), c + Vector2(0, 16), c + Vector2(-13, -5)]), gc)
			return
		var g := Color(1.0, 0.8, 0.2)
		for i in 3:
			var c := Vector2(size.x * 0.5 + (i - 1) * 16, 44 - i * 6)
			draw_circle(c, 22, g.darkened(0.45))
			draw_circle(c, 19, g)
			draw_arc(c, 12, 0, TAU, 24, g.darkened(0.3), 2.5)


static func open(host: Control, p: Dictionary, on_close := Callable()) -> void:
	var c := Checkout.new()
	c.pack = p
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(c)
	c._build(on_close)


func _build(on_close: Callable) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.add_theme_stylebox_override("panel", UI.sb(Color(0.07, 0.075, 0.095, 0.98), 18, Color(1, 1, 1, 0.12), 1))
	cc.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var hd := HBoxContainer.new()
	vb.add_child(hd)
	var t := UI.lbl(hd, UI.tx("CHECKOUT", "إتمام الشراء"), 24, UI.TXT, false)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.btn(hd, "X", UI.CARD2, func():
		queue_free()
		if on_close.is_valid():
			on_close.call(), 20, Vector2(52, 44))
	# summary
	var sm := PanelContainer.new()
	sm.add_theme_stylebox_override("panel", UI.sb(Color(1, 1, 1, 0.045), 14, Color(1.0, 0.8, 0.2, 0.3), 1))
	vb.add_child(sm)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 14)
	sm.add_child(sh)
	sh.add_child(CoinStack.new(pack["kind"] == "gems"))
	var sv := VBoxContainer.new()
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(sv)
	var gem_pack: bool = pack["kind"] == "gems"
	UI.lbl(sv, "%s %s" % [_fmt(int(pack["amount"])), UI.tx("gems", "جوهرة") if gem_pack else UI.tx("coins", "عملة")], 30, Color(0.55, 0.92, 1.0) if gem_pack else Color(1.0, 0.86, 0.35), false)
	if str(pack["bonus"]) != "":
		UI.lbl(sv, UI.tx("Bonus ", "مكافأة ") + str(pack["bonus"]), 16, UI.OK, false)
	UI.lbl(sh, "$" + str(pack["price"]), 34, UI.TXT, false)
	# methods
	UI.lbl(vb, UI.tx("Payment method", "طريقة الدفع"), 16, UI.TXT2, false)
	for m in Billing.METHODS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 62)
		b.focus_mode = Control.FOCUS_NONE
		var id: String = m["id"]
		var inner := HBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 14
		inner.offset_right = -14
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_theme_constant_override("separation", 12)
		b.add_child(inner)
		var dot := Control.new()
		dot.custom_minimum_size = Vector2(26, 26)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.draw.connect(func():
			dot.draw_arc(Vector2(13, 13), 11, 0, TAU, 24, UI.TXT2 if method != id else UI.ACCENT, 2.5)
			if method == id:
				dot.draw_circle(Vector2(13, 13), 6, UI.ACCENT))
		inner.add_child(dot)
		var tv := VBoxContainer.new()
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_theme_constant_override("separation", 0)
		inner.add_child(tv)
		UI.lbl(tv, Catalog.txt(m["n"]), 20, UI.TXT, false)
		UI.lbl(tv, str(m["sub"]), 13, UI.TXT2, false)
		b.pressed.connect(func():
			method = id
			Sfx.play("click", -8.0)
			_refresh())
		vb.add_child(b)
		_rows[id] = [b, dot]
	_note = UI.lbl(vb, "", 15, Color(1.0, 0.82, 0.3), true)
	_note.custom_minimum_size = Vector2(500, 0)
	_pay = UI.btn(vb, "", UI.ACCENT, _on_pay, 24, Vector2(0, 62))
	_refresh()


func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out


func _refresh() -> void:
	for id in _rows:
		var on: bool = id == method
		var b: Button = _rows[id][0]
		var col := Color(UI.ACCENT.r, UI.ACCENT.g, UI.ACCENT.b, 0.14) if on else Color(1, 1, 1, 0.05)
		var bd := UI.ACCENT if on else Color(1, 1, 1, 0.1)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, UI.sb(col, 12, bd, 2 if on else 1))
		(_rows[id][1] as Control).queue_redraw()
	if Billing.enabled:
		_pay.text = UI.tx("Pay $%s", "ادفع $%s") % str(pack["price"])
		_pay.disabled = false
		_note.text = ""
	else:
		_pay.text = UI.tx("Coming soon", "قريباً")
		_pay.disabled = true
		_note.text = UI.tx("Payments are not connected yet in this version. Nothing will be charged.", "الدفع غير مفعّل بعد في هذه النسخة. لن يُسحب أي مبلغ.")


func _on_pay() -> void:
	if not Billing.enabled:
		return
	# the store plugin starts the purchase here and calls Billing.grant(pack["id"]) once it is verified
