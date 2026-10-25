# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
class_name Share
extends RefCounted
## Photo cards: takes a screenshot of the game, stamps it with the game name + Sabak Studios logo + a title, saves it as a PNG.
## A real "share sheet" (WhatsApp / TikTok / Instagram) needs a native plugin; until it exists the picture is saved to
## user://share (iPhone: visible in the Files app, see export options) and the player shares it from there.

const DIR := "user://share"
const NAME := "HAIRPIN RUSH"


static func snap(host: Node, tag: String, title: String, hide_nodes := []) -> void:
	if host == null or not host.is_inside_tree():
		return
	var tree := host.get_tree()
	var layer := CanvasLayer.new()
	layer.layer = 200
	tree.root.add_child(layer)
	var bar := ColorRect.new()
	bar.color = Color(0.03, 0.035, 0.05, 0.9)
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.anchor_right = 1.0
	bar.offset_top = -92
	layer.add_child(bar)
	var accent := ColorRect.new()
	accent.color = UI.ACCENT
	accent.anchor_top = 1.0
	accent.anchor_bottom = 1.0
	accent.anchor_right = 1.0
	accent.offset_top = -95
	accent.offset_bottom = -92
	layer.add_child(accent)
	var logo := load("res://art/sabak_logo.png") as Texture2D
	if logo:
		var tr := TextureRect.new()
		tr.texture = logo
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.anchor_top = 1.0
		tr.anchor_bottom = 1.0
		tr.offset_left = 22
		tr.offset_top = -82
		tr.offset_right = 160
		tr.offset_bottom = -10
		layer.add_child(tr)
	var l1 := Label.new()
	l1.text = NAME
	l1.add_theme_font_size_override("font_size", 34)
	l1.add_theme_color_override("font_color", Color.WHITE)
	l1.anchor_top = 1.0
	l1.anchor_bottom = 1.0
	l1.offset_left = 180
	l1.offset_top = -86
	layer.add_child(l1)
	var l2 := Label.new()
	l2.text = title
	l2.add_theme_font_size_override("font_size", 22)
	l2.add_theme_color_override("font_color", UI.ACCENT)
	l2.anchor_top = 1.0
	l2.anchor_bottom = 1.0
	l2.offset_left = 182
	l2.offset_top = -42
	layer.add_child(l2)
	var hidden: Array = []
	for n in hide_nodes:
		if n != null and is_instance_valid(n) and n.visible:
			n.visible = false
			hidden.append(n)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := host.get_viewport().get_texture().get_image()
	for n in hidden:
		if is_instance_valid(n):
			n.visible = true
	layer.queue_free()
	var path := save(img, tag)
	_toast(tree, path)


static func save(img: Image, tag: String) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var t := Time.get_datetime_dict_from_system()
	var file := "%s/HairpinRush_%s_%04d%02d%02d_%02d%02d%02d.png" % [DIR, tag, t["year"], t["month"], t["day"], t["hour"], t["minute"], t["second"]]
	if img.save_png(file) != OK:
		return ""
	return file


static func _toast(tree: SceneTree, path: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 210
	tree.root.add_child(layer)
	var l := Label.new()
	var msg := UI.tx("Photo saved", "تم حفظ الصورة")
	if path == "":
		msg = UI.tx("Could not save the photo", "ما قدرت أحفظ الصورة")
	elif OS.get_name() == "iOS":
		msg += UI.tx("  -  Files app > Hairpin Rush", "  -  تطبيق الملفات > Hairpin Rush")
	elif OS.get_name() == "Android":
		msg += UI.tx("  -  inside the app (sharing needs a plugin)", "  -  داخل التطبيق (المشاركة تحتاج إضافة)")
	else:
		msg += "  -  " + ProjectSettings.globalize_path(path)
	l.text = "  " + msg + "  "
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_stylebox_override("normal", UI.sb(Color(0.05, 0.06, 0.08, 0.95), 12, UI.ACCENT, 2))
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.anchor_top = 0.0
	l.offset_top = 80
	l.offset_left = -300
	l.offset_right = 300
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(l)
	var tw := layer.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(layer.queue_free)
