# Copyright (c) 2026 KRG Studios. All rights reserved. See LICENSE.
class_name ZoneStyle
extends RefCounted
## One look for every race button (used by the race HUD and by the layout editor, so they always match):
## dark glass body, coloured border by importance, a drawn icon and a readable label.

const ICONS := {
	"gas": "gas", "brake": "brake", "c_horn": "horn", "c_sigl": "arrow_l", "c_sigr": "arrow_r", "c_lights": "light", "c_wipers": "wiper",
	"c_more": "more", "p2_back": "back", "c_drink": "cup", "c_kind": "cup", "c_mirl": "mirror_l", "c_mirr": "mirror_r",
	"p2_haz": "hazard", "p2_flash": "beam", "p2_hb": "hbrake", "p2_win": "window", "p2_ac": "fan", "p2_dome": "bulb", "p2_greet": "hand",
	"reset": "reset", "emote": "smile", "punch": "fist", "stickers": "star", "photo": "camera", "menu": "menu", "hudcfg": "grid",
	"replay": "play", "radio_name": "radio", "msize": "expand", "mnear": "zoom", "map": "pin", "beacon": "wave",
	"left": "arrow_l", "right": "arrow_r", "radio_prev": "arrow_l", "radio_next": "arrow_r",
	"g_left": "arrow_l", "g_fwd": "arrow_u", "g_right": "arrow_r", "g_stop": "stop",
}


## buttons that show only an icon (a "<" / ">" character gets mirrored in Arabic, so arrows are drawn instead)
const ICON_ONLY := ["left", "right", "radio_prev", "radio_next"]


static func has_icon(id: String) -> bool:
	return ICONS.has(id)


## the body of a button: id decides the colours, `active` = switched on (signals, lights...)
static func box(id: String, active := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(20 if id == "gas" or id == "brake" else 14)
	sb.set_border_width_all(3 if id == "gas" or id == "brake" else 2)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 2)
	sb.bg_color = Color(0.04, 0.055, 0.09, 0.78)
	sb.border_color = Color(1, 1, 1, 0.42)
	if active:
		sb.bg_color = Color(1.0, 0.58, 0.05, 0.85)
		sb.border_color = Color(1, 0.95, 0.7, 0.95)
		sb.shadow_color = Color(1.0, 0.6, 0.1, 0.55)                  # glows while switched on
		sb.shadow_size = 14
		sb.shadow_offset = Vector2.ZERO
	return sb


## give a zone panel its icon and lay the label out (called once per button; safe to call again)
static func decorate(p: Control, id: String, l: Label, w: float, h: float) -> void:
	if not ICONS.has(id):
		return
	var ic := p.get_node_or_null("Icon") as ZoneIcon
	if ic == null:
		ic = ZoneIcon.new()
		ic.name = "Icon"
		p.add_child(ic)
	ic.kind = ICONS[id]
	ic.radius = 20.0 if (id == "gas" or id == "brake") else 14.0
	ic.tall = h >= 56.0
	ic.only = ICON_ONLY.has(id)
	if ic.only:
		l.text = ""
		ic.queue_redraw()
		return
	ic.queue_redraw()
	var txt := l.text
	if ic.tall:
		l.offset_left = 2
		l.offset_right = -2
		l.offset_top = h * (0.58 if h >= 70.0 else 0.56)
		l.offset_bottom = -3
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 22 if (id == "gas" or id == "brake") else (15 if (txt.length() > 9 or h < 70.0) else 17))
	else:
		l.offset_left = h * 0.95
		l.offset_right = -4
		l.offset_top = 0
		l.offset_bottom = 0
		l.add_theme_font_size_override("font_size", 17 if txt.length() <= 8 else 14)
	l.add_theme_constant_override("outline_size", 6)


