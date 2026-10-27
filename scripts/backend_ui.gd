# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
class_name BackendUI
extends Control
## Two small dialogs: redeem a code, and the events list.

var _box: VBoxContainer


static func _shell(host: Control, title: String) -> BackendUI:
	var c := BackendUI.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(c)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(cc)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	panel.add_theme_stylebox_override("panel", UI.sb(Color(0.07, 0.075, 0.095, 0.98), 18, Color(1, 1, 1, 0.12), 1))
	cc.add_child(panel)
	c._box = VBoxContainer.new()
	c._box.add_theme_constant_override("separation", 12)
	panel.add_child(c._box)
	var hd := HBoxContainer.new()
	c._box.add_child(hd)
	var t := UI.title(hd, title, 26, UI.TXT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.btn(hd, "X", UI.CARD2, func(): c.queue_free(), 20, Vector2(52, 44))
	return c


static func open_redeem(host: Control) -> void:
	var c := _shell(host, UI.tx("REDEEM CODE", "إدخال كود"))
	var v := c._box
	UI.lbl(v, UI.tx("Enter your code to get coins and gems.", "أدخل الكود لتحصل على عملات وجواهر."), 16, UI.TXT2, true)
	var le := LineEdit.new()
	le.placeholder_text = "XXXX-XXXX-XXXX"
	le.custom_minimum_size = Vector2(0, 62)
	le.add_theme_font_size_override("font_size", 28)
	le.alignment = HORIZONTAL_ALIGNMENT_CENTER
	le.max_length = 24
	v.add_child(le)
	var msg := UI.lbl(v, "", 18, UI.TXT2, true)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	UI.btn(row, UI.tx("Paste", "لصق"), UI.CARD2, func(): le.text = DisplayServer.clipboard_get().strip_edges(), 20, Vector2(140, 56))
	var go: Button
	go = UI.btn(row, UI.tx("REDEEM", "تفعيل"), UI.ACCENT, func():
		if not Backend.enabled():
			msg.text = UI.tx("This build is not connected to the server.", "هذه النسخة غير متصلة بالسيرفر.")
			return
		go.disabled = true
		msg.text = "..."
		Backend.redeem(le.text, func(http: int, d: Dictionary):
			go.disabled = false
			if d.get("ok", false):
				var parts := []
				if int(d.get("coins", 0)) > 0:
					parts.append("%d %s" % [int(d["coins"]), UI.tx("coins", "عملة")])
				if int(d.get("gems", 0)) > 0:
					parts.append("%d %s" % [int(d["gems"]), UI.tx("gems", "جوهرة")])
				msg.text = UI.tx("Done! You got ", "تم! حصلت على ") + " + ".join(parts)
				msg.add_theme_color_override("font_color", UI.OK)
				Sfx.play("success")
			else:
				msg.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
				msg.text = _err(http, str(d.get("error", "net")))), 24, Vector2(0, 56))
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL


static func _err(http: int, e: String) -> String:
	match e:
		"invalid":
			return UI.tx("This code is not valid.", "هذا الكود غير صحيح.")
		"expired":
			return UI.tx("This code has expired.", "انتهت صلاحية هذا الكود.")
		"used":
			return UI.tx("You already used this code.", "استخدمت هذا الكود من قبل.")
		"limit":
			return UI.tx("This code has no uses left.", "انتهت مرات استخدام هذا الكود.")
		"rate":
			return UI.tx("Too many tries. Wait a minute.", "محاولات كثيرة. انتظر دقيقة.")
	return UI.tx("No connection to the server.", "لا يوجد اتصال بالسيرفر.")


static func open_events(host: Control) -> void:
	var c := _shell(host, UI.tx("EVENTS", "الفعاليات"))
	var v := c._box
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	v.add_child(list)
	var st := UI.lbl(list, UI.tx("Loading...", "جارٍ التحميل..."), 18, UI.TXT2, false)
	if not Backend.enabled():
		st.text = UI.tx("This build is not connected to the server.", "هذه النسخة غير متصلة بالسيرفر.")
		return
	Backend.fetch_events(func(http: int, d: Dictionary):
		if not is_instance_valid(list):
			return
		for ch in list.get_children():
			ch.queue_free()
		var evs: Array = d.get("events", [])
		if http != 200:
			UI.lbl(list, UI.tx("No connection to the server.", "لا يوجد اتصال بالسيرفر."), 18, UI.TXT2, false)
			return
		if evs.is_empty():
			UI.lbl(list, UI.tx("No events right now. Check back soon.", "لا توجد فعاليات الآن. عُد قريباً."), 18, UI.TXT2, false)
			return
		var now := int(Time.get_unix_time_from_system())
		for e in evs:
			var p := PanelContainer.new()
			p.add_theme_stylebox_override("panel", UI.sb(Color(1, 1, 1, 0.05), 14, Color(1.0, 0.8, 0.25, 0.35), 1))
			list.add_child(p)
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 12)
			p.add_child(h)
			var tv := VBoxContainer.new()
			tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(tv)
			UI.title(tv, str(e["title_ar"]) if (L.is_ar() and str(e["title_ar"]) != "") else str(e["title"]), 22, UI.TXT)
			var body := str(e["body_ar"]) if (L.is_ar() and str(e["body_ar"]) != "") else str(e["body"])
			if body != "":
				UI.lbl(tv, body, 15, UI.TXT2, true)
			var left := maxi(0, int(e["ends_at"]) - now)
			var rw := []
			if int(e["reward_coins"]) > 0:
				rw.append("%d %s" % [int(e["reward_coins"]), UI.tx("coins", "عملة")])
			if int(e["reward_gems"]) > 0:
				rw.append("%d %s" % [int(e["reward_gems"]), UI.tx("gems", "جوهرة")])
			UI.lbl(tv, "%s   |   %s" % [" + ".join(rw), UI.tx("%d days left", "باقي %d يوم") % ceili(left / 86400.0)], 15, Color(1.0, 0.8, 0.25), false)
			if int(e["reward_coins"]) + int(e["reward_gems"]) > 0:
				var b: Button
				var eid := int(e["id"])
				b = UI.btn(h, UI.tx("CLAIMED", "تم الاستلام") if bool(e.get("claimed", false)) else UI.tx("CLAIM", "استلم"), UI.ACCENT, func():
					b.disabled = true
					Backend.claim_event(eid, func(_h: int, r: Dictionary):
						if r.get("ok", false):
							b.text = UI.tx("CLAIMED", "تم الاستلام")
							Sfx.play("success")
						else:
							b.text = UI.tx("CLAIMED", "تم الاستلام")), 20, Vector2(150, 52))
				b.disabled = bool(e.get("claimed", false)))
