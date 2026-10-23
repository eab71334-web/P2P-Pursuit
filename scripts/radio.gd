# Copyright (c) 2026 AVF. All rights reserved. See LICENSE.
extends Node
## Autoload "Radio": the in-car radio. Five stations (synthesised loops in res://audio/radio), tuning static between
## stations, on/off + volume (Gfx.vol_radio). The world HUD and the dashboard unit just call next() / prev() / toggle().

signal changed

const STATIONS := [
	{"id": "st_rally", "name": "RALLY FM", "mhz": "98.4", "en": "Rock", "ar": "روك"},
	{"id": "st_night", "name": "NIGHT DRIVE", "mhz": "101.2", "en": "Synthwave", "ar": "سينث ويف"},
	{"id": "st_sahara", "name": "SAHARA WAVES", "mhz": "94.7", "en": "Oriental", "ar": "شرقي"},
	{"id": "st_lofi", "name": "LO-FI GARAGE", "mhz": "88.9", "en": "Chill", "ar": "هادئ"},
	{"id": "st_turbo", "name": "TURBO BEATS", "mhz": "104.5", "en": "Dance", "ar": "إلكتروني"},
]
const SAVE := "user://radio.cfg"

var on := true
var idx := 0
var in_race := false           # the radio only plays while driving (HUD / dashboard exist)
var muted_by_scene := false    # ceremony / menus
var _player: AudioStreamPlayer
var _tune: AudioStreamPlayer
var _fade := 0.0               # 0..1 (tuning dip)
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cf := ConfigFile.new()
	if cf.load(SAVE) == OK:
		on = cf.get_value("radio", "on", true)
		idx = clampi(int(cf.get_value("radio", "idx", 0)), 0, STATIONS.size() - 1)
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_tune = AudioStreamPlayer.new()
	_tune.stream = Sfx.stream("tune")
	_tune.volume_db = -10.0
	add_child(_tune)
	Gfx.changed.connect(_apply_volume)


func station() -> Dictionary:
	return STATIONS[idx]


func label() -> String:
	if not on:
		return UI.tx("RADIO OFF", "الراديو مغلق")
	return str(STATIONS[idx]["name"])


func sub_label() -> String:
	if not on:
		return ""
	var s: Dictionary = STATIONS[idx]
	return "FM %s  -  %s" % [s["mhz"], s["ar"] if L.is_ar() else s["en"]]


func start_race() -> void:
	in_race = true
	muted_by_scene = false
	_play(false)


func stop_race() -> void:
	in_race = false
	_player.stop()


func duck(v: bool) -> void:
	muted_by_scene = v
	_apply_volume()


func toggle() -> void:
	on = not on
	_save()
	if on:
		_play(true)
	else:
		_player.stop()
	changed.emit()


func next() -> void:
	_step(1)


func prev() -> void:
	_step(-1)


func _step(d: int) -> void:
	if not on:
		on = true
	else:
		idx = (idx + d + STATIONS.size()) % STATIONS.size()
	_save()
	_play(true)
	changed.emit()


func _play(with_static: bool) -> void:
	if not in_race or not on:
		return
	var id: String = STATIONS[idx]["id"]
	var st: AudioStreamWAV
	if _cache.has(id):
		st = _cache[id]
	else:
		var base := load("res://audio/radio/%s.wav" % id) as AudioStreamWAV
		if base == null:
			return
		st = base.duplicate() as AudioStreamWAV
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = 0
		st.loop_end = st.data.size() / 2
		_cache[id] = st
	_player.stream = st
	_apply_volume()
	if with_static:
		_tune.play()
		_player.volume_db = -60.0
		var tw := create_tween()
		tw.tween_interval(0.25)
		tw.tween_callback(func(): _player.play(randf() * 8.0))
		tw.tween_method(func(db): _player.volume_db = db, -40.0, _target_db(), 0.4)
	else:
		_player.play(randf() * 8.0)


func _target_db() -> float:
	if muted_by_scene:
		return -40.0
	return linear_to_db(maxf(Gfx.vol_radio, 0.0001)) - 9.0


func _apply_volume() -> void:
	if _player and _player.playing:
		_player.volume_db = _target_db()


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("radio", "on", on)
	cf.set_value("radio", "idx", idx)
	cf.save(SAVE)
