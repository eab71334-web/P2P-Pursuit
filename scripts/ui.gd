# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
class_name UI
extends RefCounted
## Shared look for the hub screens (garage, workshop, character, shop, quests).

# One accent colour (rally orange) on a graphite base. Rarity colours only appear on items.
const ACCENT := Color(1.0, 0.47, 0.1)
const GOLD := ACCENT
const BG := Color(0.045, 0.05, 0.062)
const NAVY := Color(0.09, 0.1, 0.125)
const PANEL := Color(0.075, 0.08, 0.1, 0.94)
const CARD := Color(0.1, 0.108, 0.135)
const CARD2 := Color(0.14, 0.15, 0.185)
const LINE := Color(1, 1, 1, 0.09)
const TXT := Color(0.94, 0.95, 0.97)
const TXT2 := Color(0.62, 0.66, 0.74)
const OK := Color(0.3, 0.85, 0.5)
const GREEN := ACCENT
const RED := Color(0.72, 0.17, 0.2)
const BLUE := Color(0.17, 0.19, 0.25)


static func tx(en: String, ar: String) -> String:
	return ar if L.is_ar() else en


static func sb(col: Color, radius := 8, border := Color.TRANSPARENT, bw := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	return s


static func lbl(parent: Node, text: String, fs: int, color := Color.WHITE, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent:
		parent.add_child(l)
	return l


static func pop(c: Control, amount := 1.05) -> void:
	c.resized.connect(func(): c.pivot_offset = c.size * 0.5)
	c.mouse_entered.connect(func(): c.create_tween().tween_property(c, "scale", Vector2(amount, amount), 0.1))
	c.mouse_exited.connect(func(): c.create_tween().tween_property(c, "scale", Vector2.ONE, 0.1))


static func btn(parent: Node, text: String, col: Color, cb: Callable, fs := 22, min_size := Vector2(0, 54)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_stylebox_override("normal", sb(col))
	b.add_theme_stylebox_override("hover", sb(col.lightened(0.18)))
	b.add_theme_stylebox_override("pressed", sb(col.darkened(0.15)))
	b.add_theme_stylebox_override("focus", sb(col))
	b.add_theme_stylebox_override("disabled", sb(Color(0.25, 0.26, 0.33)))
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.62, 0.7))
	b.pressed.connect(cb)
	pop(b, 1.04)
	if parent:
		parent.add_child(b)
	return b


static func panel(parent: Node, col := PANEL, radius := 10) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(col, radius, LINE, 1))
	if parent:
		parent.add_child(p)
	return p


## coin / gem icon that is drawn (the font has no emoji)
class Coin extends Control:
	var gem := false

	func _init(is_gem := false) -> void:
		gem = is_gem
		custom_minimum_size = Vector2(24, 24)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		if gem:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -11), c + Vector2(10, -2), c + Vector2(0, 11), c + Vector2(-10, -2)]), Color(0.3, 0.9, 1.0))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -11), c + Vector2(4, -2), c + Vector2(0, 11), c + Vector2(-4, -2)]), Color(0.7, 1.0, 1.0))
		else:
			draw_circle(c, 10.0, Color(0.95, 0.7, 0.1))
			draw_circle(c, 7.0, Color(1.0, 0.85, 0.3))
			draw_rect(Rect2(c.x - 1.5, c.y - 5, 3, 10), Color(0.8, 0.55, 0.05))


static func price_row(parent: Node, amount: int, gem: bool, fs := 18, col := Color.WHITE) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(Coin.new(gem))
	lbl(h, str(amount), fs, col, false)
	if parent:
		parent.add_child(h)
	return h


## little pictograms for items that are not just a colour
class Glyph extends Control:
	var kind := ""
	var col := Color.WHITE
	var t := 0.0

	func _init(k := "", c := Color.WHITE) -> void:
		kind = k
		col = c
		custom_minimum_size = Vector2(0, 52)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		match kind:
			"paint":
				draw_rect(Rect2(c.x - 40, c.y - 18, 80, 36), col)
				draw_rect(Rect2(c.x - 22, c.y - 30, 44, 16), col.darkened(0.25))
				draw_circle(c + Vector2(-26, 18), 8, Color(0.05, 0.05, 0.06))
				draw_circle(c + Vector2(26, 18), 8, Color(0.05, 0.05, 0.06))
			"stripe":
				draw_rect(Rect2(c.x - 40, c.y - 22, 80, 44), Color(0.5, 0.1, 0.1))
				draw_rect(Rect2(c.x - 10, c.y - 22, 8, 44), col)
				draw_rect(Rect2(c.x + 4, c.y - 22, 8, 44), col)
			"rim":
				draw_circle(c, 26, Color(0.05, 0.05, 0.06))
				draw_circle(c, 17, col)
				draw_circle(c, 9, Color(0.1, 0.1, 0.12))
				for k in 5:
					var a := TAU * k / 5.0 + t
					draw_line(c, c + Vector2(cos(a), sin(a)) * 17, col, 3.0)
			"glow":
				draw_rect(Rect2(c.x - 40, c.y - 8, 80, 16), col.darkened(0.2))
				draw_rect(Rect2(c.x - 48, c.y + 6, 96, 10), Color(col, 0.35 + 0.2 * sin(t * 4.0)))
			"hat":
				draw_rect(Rect2(c.x - 22, c.y - 18, 44, 28), col)
				draw_rect(Rect2(c.x - 36, c.y + 8, 72, 6), col.darkened(0.3))
			"glasses":
				draw_circle(c + Vector2(-16, 0), 12, col)
				draw_circle(c + Vector2(16, 0), 12, col)
				draw_line(c + Vector2(-4, 0), c + Vector2(4, 0), col, 3.0)
			"emote":
				draw_circle(c + Vector2(0, -14), 8, col)
				draw_line(c + Vector2(0, -6), c + Vector2(0, 14), col, 5.0)
				var up := sin(t * 6.0) * 6.0
				draw_line(c + Vector2(0, 0), c + Vector2(-18, -10 + up), col, 4.0)
				draw_line(c + Vector2(0, 0), c + Vector2(18, -10 - up), col, 4.0)
				draw_line(c + Vector2(0, 14), c + Vector2(-10, 28), col, 4.0)
				draw_line(c + Vector2(0, 14), c + Vector2(10, 28), col, 4.0)
			"shirt":
				draw_rect(Rect2(c.x - 18, c.y - 22, 36, 44), col)
				draw_rect(Rect2(c.x - 34, c.y - 22, 16, 14), col.darkened(0.15))
				draw_rect(Rect2(c.x + 18, c.y - 22, 16, 14), col.darkened(0.15))
			"pants":
				draw_rect(Rect2(c.x - 20, c.y - 22, 18, 44), col)
				draw_rect(Rect2(c.x + 2, c.y - 22, 18, 44), col)
			"shoes":
				draw_rect(Rect2(c.x - 34, c.y - 4, 32, 14), col)
				draw_rect(Rect2(c.x + 2, c.y - 4, 32, 14), col)
			_:
				draw_rect(Rect2(c.x - 24, c.y - 24, 48, 48), col)
