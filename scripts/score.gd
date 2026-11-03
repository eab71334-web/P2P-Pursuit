# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
extends Node
## Autoload "Score": the interactive race music. Three stems (calm / drive / intense, scripts: tools/make_score.py) play
## in sync inside one AudioStreamSynchronized; the world tells it the speed and the events and it fades the layers:
## slow = calm pad only, 40-90 km/h adds the beat, 110+ km/h (or a burning car) adds the lead. A crash ducks the music
## and plays a stinger, the finish plays a win / lose stinger. Setting "Race music": radio | score | off.

const SAVE := "user://score.cfg"
var mode := "radio"            # radio (the in-car radio) | score (this) | off
var vol := 0.7
var active := false            # a race is running
var _player: AudioStreamPlayer
var _sync: AudioStreamSynchronized
var _lv := [1.0, 0.0, 0.0]
var _tg := [1.0, 0.0, 0.0]
var _duck := 0.0
var _fade := 0.0               # 0..1 master fade (start / stop)
var _want := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cf := ConfigFile.new()
	if cf.load(SAVE) == OK:
		mode = str(cf.get_value("score", "mode", "radio"))
		vol = float(cf.get_value("score", "vol", 0.7))
	_player = AudioStreamPlayer.new()
	add_child(_player)


func owns_music() -> bool:
	return mode == "score"


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("score", "mode", mode)
	cf.set_value("score", "vol", vol)
	cf.save(SAVE)


func set_mode(m: String) -> void:
	mode = m
	_save()
	Radio.refresh()
	if active:
		_apply_play()


func set_vol(v: float) -> void:
	vol = v
	_save()


func _build() -> void:
	if _sync != null:
		return
	_sync = AudioStreamSynchronized.new()
	_sync.stream_count = 3
	var names := ["score_calm", "score_drive", "score_intense"]
	for i in 3:
		var st := Sfx.stream(names[i], true)
		if st == null:
			_sync = null
			return
		_sync.set_sync_stream(i, st)
	_player.stream = _sync


## a race started / ended
func start() -> void:
	active = true
	_lv = [1.0, 0.0, 0.0]
	_tg = [1.0, 0.0, 0.0]
	_fade = 0.0
	_apply_play()


func stop() -> void:
	active = false
	_apply_play()


func _apply_play() -> void:
	_want = active and mode == "score"
	if _want:
		_build()
		if _sync != null and not _player.playing:
			_player.volume_db = -60.0
			_player.play()
	elif _player.playing and not active:
		pass                                      # _process fades it out and stops it


## called every frame by the world for the local car
func drive(speed_kmh: float, burning := false) -> void:
	_tg[0] = 1.0 if not burning else 0.7
	_tg[1] = smoothstep(35.0, 85.0, speed_kmh)
	_tg[2] = maxf(smoothstep(110.0, 165.0, speed_kmh), 0.9 if burning else 0.0)


func crash() -> void:
	if mode != "score" or not active:
		return
	_duck = 1.3
	Sfx.play("stinger_crash", -2.0)


func finish(win: bool) -> void:
	if mode != "score":
		return
	_tg = [0.0, 0.0, 0.0]
	Sfx.play("stinger_win" if win else "stinger_lose", -3.0)


func _process(delta: float) -> void:
	if _player == null:
		return
	var up := _want
	_fade = move_toward(_fade, 1.0 if up else 0.0, delta * (0.8 if up else 1.5))
	if not up and _fade <= 0.0 and _player.playing:
		_player.stop()
		return
	if not _player.playing or _sync == null:
		return
	_duck = maxf(_duck - delta, 0.0)
	var duck_k := 1.0 - 0.75 * clampf(_duck / 0.5, 0.0, 1.0)
	for i in 3:
		_lv[i] = lerpf(_lv[i], _tg[i], clampf(delta * 1.1, 0.0, 1.0))
		_sync.set_sync_stream_volume(i, linear_to_db(maxf(_lv[i] * duck_k, 0.0005)))
	_player.volume_db = linear_to_db(maxf(vol * Gfx.vol_master * _fade, 0.0001)) - 4.0
