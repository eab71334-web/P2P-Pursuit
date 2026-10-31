# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
extends Node
## Talks to the Sabak backend (backend/server.py): redeem codes, events, card payments, error reports.
## Set DEFAULT_URL (or the BACKEND_URL environment variable) to your server's https address before exporting.
## With no address everything here quietly does nothing and the game works offline.

signal config_ready
signal wallet_changed(kind: String, amount: int)

const DEFAULT_URL := "https://sabak-backend.onrender.com"
const GAME := "hairpin"
const VERSION := "1.0"
const FLAG := "user://session.flag"

var url := DEFAULT_URL
var payments := false
var provider := ""
var events: Array = []
var _sent := {}
var _report_count := 0
var _polling := ""
var banned := false
var _notices: Array = []          # [{title, text}] shown one by one
var _showing := false
const SEEN := "user://seen_announcements.json"


func _ready() -> void:
	var env := OS.get_environment("BACKEND_URL")
	if env != "":
		url = env
	url = url.rstrip("/")
	if url == "":
		return
	_check_unclean_exit()
	_set_flag(true)
	hello()
	fetch_config()
	if Profile.pending_order != "":
		_poll(Profile.pending_order, Callable(), 0)


func enabled() -> bool:
	return url != ""


func _notification(what: int) -> void:
	if url == "":
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_set_flag(false)
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_set_flag(true)


func _set_flag(on: bool) -> void:
	if on:
		var f := FileAccess.open(FLAG, FileAccess.WRITE)
		if f:
			f.store_string("1")
	elif FileAccess.file_exists(FLAG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FLAG))


func _check_unclean_exit() -> void:
	if FileAccess.file_exists(FLAG):
		report("crash", "Previous session ended without a clean exit (crash or forced close)")


## one request; cb(http_code, dictionary). http_code 0 = no connection
func call_api(method: int, path: String, body: Variant, cb: Callable) -> void:
	if url == "":
		if cb.is_valid():
			cb.call(0, {"ok": false, "error": "offline"})
		return
	var req := HTTPRequest.new()
	req.timeout = 15.0
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, bytes: PackedByteArray):
		req.queue_free()
		var d: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if cb.is_valid():
			cb.call(code if result == HTTPRequest.RESULT_SUCCESS else 0, d if d is Dictionary else {"ok": false, "error": "net"}))
	var err := req.request(url + path, PackedStringArray(["Content-Type: application/json"]), method, JSON.stringify(body) if body != null else "")
	if err != OK:
		req.queue_free()
		if cb.is_valid():
			cb.call(0, {"ok": false, "error": "net"})


func hello() -> void:
	call_api(HTTPClient.METHOD_POST, "/api/player/hello", {"player_id": Profile.pid, "name": Profile.pname, "game": GAME, "platform": OS.get_name(), "version": VERSION}, func(code: int, d: Dictionary):
		if code != 200 or not d.get("ok", false):
			return
		if bool(d.get("banned", false)):
			banned = true
			_show_ban()
			return
		for g in d.get("grants", []):
			var c := int(g.get("coins", 0))
			var gm := int(g.get("gems", 0))
			if c > 0:
				_credit("coins", c)
			if gm > 0:
				_credit("gems", gm)
			call_api(HTTPClient.METHOD_POST, "/api/grant/ack", {"player_id": Profile.pid, "id": int(g.get("id", 0))}, Callable())
			var parts: Array = []
			if c > 0:
				parts.append(str(c) + (" عملة" if L.is_ar() else " coins"))
			if gm > 0:
				parts.append(str(gm) + (" جوهرة" if L.is_ar() else " gems"))
			var txt := (" + ").join(parts)
			if str(g.get("note", "")) != "":
				txt += "\n" + str(g["note"])
			_notify("وصلتك هدية!" if L.is_ar() else "You got a gift!", txt))


func fetch_config() -> void:
	call_api(HTTPClient.METHOD_GET, "/api/config?game=" + GAME, null, func(code: int, d: Dictionary):
		if code == 200 and d.get("ok", false):
			payments = bool(d.get("payments", false))
			provider = str(d.get("provider", ""))
			events = d.get("events", [])
			Billing.enabled = payments
			_announce(d.get("announcements", []))
			config_ready.emit())


func fetch_events(cb: Callable) -> void:
	call_api(HTTPClient.METHOD_GET, "/api/events?game=%s&player_id=%s" % [GAME, Profile.pid], null, func(code: int, d: Dictionary):
		if code == 200:
			events = d.get("events", [])
		cb.call(code, d))


func _credit(kind: String, amount: int) -> void:
	if kind == "gems":
		Profile.gems += amount
	else:
		Profile.coins += amount
	Profile.save()
	wallet_changed.emit(kind, amount)


func redeem(code: String, cb: Callable) -> void:
	call_api(HTTPClient.METHOD_POST, "/api/redeem", {"player_id": Profile.pid, "code": code, "game": GAME}, func(http: int, d: Dictionary):
		if d.get("ok", false):
			var c := int(d.get("coins", 0))
			var g := int(d.get("gems", 0))
			if c > 0:
				_credit("coins", c)
			if g > 0:
				_credit("gems", g)
		cb.call(http, d))


func claim_event(id: int, cb: Callable) -> void:
	call_api(HTTPClient.METHOD_POST, "/api/event/claim", {"player_id": Profile.pid, "event_id": id}, func(http: int, d: Dictionary):
		if d.get("ok", false):
			if int(d.get("coins", 0)) > 0:
				_credit("coins", int(d["coins"]))
			if int(d.get("gems", 0)) > 0:
				_credit("gems", int(d["gems"]))
		cb.call(http, d))


## card payment: create the order, open the payment page, then poll until the server says it is paid.
## cb gets {state: "waiting"|"granted"|"failed"|"timeout", ...}
func buy(pack_id: String, cb: Callable) -> void:
	call_api(HTTPClient.METHOD_POST, "/api/pay/create", {"player_id": Profile.pid, "pack_id": pack_id, "game": GAME}, func(_c: int, d: Dictionary):
		if not d.get("ok", false):
			cb.call({"state": "failed", "error": str(d.get("error", "net"))})
			return
		Profile.pending_order = str(d["order_id"])
		Profile.save()
		OS.shell_open(str(d["checkout_url"]))
		cb.call({"state": "waiting", "url": str(d["checkout_url"])})
		_poll(str(d["order_id"]), cb, 0))


func _poll(order_id: String, cb: Callable, tries: int) -> void:
	if _polling == order_id and tries == 0 and not cb.is_valid():
		return
	_polling = order_id
	call_api(HTTPClient.METHOD_POST, "/api/pay/claim", {"player_id": Profile.pid, "order_id": order_id}, func(_c: int, d: Dictionary):
		if d.get("ok", false):
			if Profile.pending_order == order_id:
				Profile.pending_order = ""
			_credit(str(d["kind"]), int(d["amount"]))
			_polling = ""
			if cb.is_valid():
				cb.call({"state": "granted", "kind": str(d["kind"]), "amount": int(d["amount"])})
			return
		var err := str(d.get("error", "net"))
		if err == "pending" or err == "net":
			if tries > 300:
				_polling = ""
				if cb.is_valid():
					cb.call({"state": "timeout"})
				return
			await get_tree().create_timer(3.0).timeout
			_poll(order_id, cb, tries + 1)
			return
		# unknown / already granted / failed
		if Profile.pending_order == order_id:
			Profile.pending_order = ""
			Profile.save()
		_polling = ""
		if cb.is_valid():
			cb.call({"state": "failed", "error": err}))


## report a problem to the admin app (max 20 per session, same message once)
func report(kind: String, message: String, stack := "") -> void:
	if url == "" or _report_count >= 20 or _sent.has(message):
		return
	_sent[message] = true
	_report_count += 1
	call_api(HTTPClient.METHOD_POST, "/api/report", {"game": GAME, "version": VERSION, "player_id": Profile.pid, "kind": kind, "message": message, "stack": stack, "platform": OS.get_name()}, Callable())


# ---------------------------------------------------------------- announcements, gifts, ban screen
func _seen() -> Array:
	var f := FileAccess.open(SEEN, FileAccess.READ)
	if f:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Array:
			return d
	return []


func _announce(list: Array) -> void:
	var seen := _seen()
	var changed := false
	for a in list:
		var id := int(a.get("id", 0))
		if seen.has(id):
			continue
		seen.append(id)
		changed = true
		var txt := str(a.get("text_ar", "")) if L.is_ar() else str(a.get("text", ""))
		if txt == "":
			txt = str(a.get("text", "")) if L.is_ar() else str(a.get("text_ar", ""))
		if txt != "":
			_notify("إعلان" if L.is_ar() else "Announcement", txt)
	if changed:
		var f := FileAccess.open(SEEN, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(seen))


func _notify(title: String, text: String) -> void:
	_notices.append({"title": title, "text": text})
	if not _showing:
		_next_notice()


func _next_notice() -> void:
	if _notices.is_empty():
		_showing = false
		return
	_showing = true
	await get_tree().create_timer(1.2).timeout
	var n: Dictionary = _notices.pop_front()
	_overlay(str(n["title"]), str(n["text"]), "حسناً" if L.is_ar() else "OK", func(): _next_notice())


func _show_ban() -> void:
	_overlay("تم حظر حسابك" if L.is_ar() else "Account banned",
		"تم منع هذا الحساب من اللعبة. إذا كان هذا خطأ تواصل مع الدعم." if L.is_ar() else "This account is blocked from the game. If this is a mistake, contact support.", "", Callable())


func _overlay(title: String, text: String, btn_text: String, on_close: Callable) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	var pnl := PanelContainer.new()
	pnl.custom_minimum_size = Vector2(560, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.1, 0.13)
	sb.set_corner_radius_all(20)
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 0.5, 0.1, 0.8)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	pnl.add_theme_stylebox_override("panel", sb)
	cc.add_child(pnl)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	pnl.add_child(v)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", Color(1.0, 0.55, 0.15))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var m := Label.new()
	m.text = text
	m.add_theme_font_size_override("font_size", 24)
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.custom_minimum_size = Vector2(500, 0)
	v.add_child(m)
	if btn_text != "":
		var b := Button.new()
		b.text = btn_text
		b.custom_minimum_size = Vector2(0, 58)
		b.add_theme_font_size_override("font_size", 24)
		b.add_theme_color_override("font_color", Color(0.1, 0.06, 0.02))
		for k in ["normal", "hover", "pressed"]:
			var bs := StyleBoxFlat.new()
			bs.bg_color = Color(1.0, 0.5, 0.1) if k != "pressed" else Color(0.85, 0.4, 0.05)
			bs.set_corner_radius_all(14)
			b.add_theme_stylebox_override(k, bs)
		b.pressed.connect(func():
			layer.queue_free()
			if on_close.is_valid():
				on_close.call())
		v.add_child(b)
	return layer
