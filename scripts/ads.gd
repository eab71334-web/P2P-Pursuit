# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
extends Node
## Autoload "Ads": AdMob on iOS (rewarded video, one test banner, consent form).
## On every build that has no AdMob plugin (desktop, Android for now) it does nothing and the
## "watch an ad" buttons simply stay hidden, so the game never depends on it.
##
## Safety rules this file follows (so Google does not flag the account):
##  - real ad units are used only when res://ads_config.json says "live": true, otherwise Google's own test units
##  - ads only start from a button the player pressed, never during a race, never at launch
##  - the reward is given only after the SDK says the player earned it and closed the ad

signal changed                       # availability / status text changed (buttons refresh)

const CFG_PATH := "res://ads_config.json"
const TEST_UNITS := {
	"banner": "ca-app-pub-3940256099942544/2934735716",
	"rewarded": "ca-app-pub-3940256099942544/1712485313",
}
const AD_POS_BOTTOM := 1

var enabled := false                 # the native AdMob plugin exists in this build
var sdk_ready := false               # SDK finished initialising
var live := false                    # at least one real ad unit in use
var live_banner := false
var live_rewarded := false
var status := "off"                  # short text for the settings page
var last_error := ""
var units := {}
var sim := false                     # desktop test mode: fake ad overlay so the flow can be tried

var _sdk: Object
var _rew: Object
var _ban: Object
var _size: Object
var _cinfo: Object
var _ump: Object

var _rew_uid := -1
var _rew_loaded := false
var _rew_loading := false
var _rew_cb := Callable()
var _earned := false
var _showing := false
var _retry := 0.0
var _retries := 0

var _ban_uid := -1
var _ban_loaded := false
var _ban_creating := false
var _ban_want := false
var _ban_visible := false
var _poll := 0.0
var _init_started := false
var _muted_before := false


const TRACE := "user://ads_trace.txt"
const GUARD := "user://ads_guard.flag"


func _trace(msg: String) -> void:
	var f := FileAccess.open(TRACE, FileAccess.READ_WRITE if FileAccess.file_exists(TRACE) else FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line("%s  %s" % [Time.get_time_string_from_system(), msg])
		f.flush()
		f.close()


func _guard_set(on: bool) -> void:
	if on:
		var f := FileAccess.open(GUARD, FileAccess.WRITE)
		if f:
			f.store_string("1")
			f.close()
	elif FileAccess.file_exists(GUARD):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GUARD))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_cfg()
	if OS.get_name() == "iOS":
		_trace("launch")
	sim = OS.has_feature("editor") or OS.get_environment("ADS_SIM") == "1"
	if OS.get_name() == "iOS" and FileAccess.file_exists(GUARD):
		# the previous run died while ads were starting: stay in safe mode (no native ad calls)
		_trace("SAFE MODE: previous launch crashed during ad start-up")
		status = "safe mode (ads crashed last time)"
		last_error = "ads disabled after a crash - see ads_trace.txt"
		_guard_set(false)
	elif OS.get_name() == "iOS" and Engine.has_singleton("PoingGodotAdMob"):
		_trace("plugin singleton found")
		_sdk = Engine.get_singleton("PoingGodotAdMob")
		_rew = Engine.get_singleton("PoingGodotAdMobRewardedAd") if Engine.has_singleton("PoingGodotAdMobRewardedAd") else null
		_ban = Engine.get_singleton("PoingGodotAdMobAdView") if Engine.has_singleton("PoingGodotAdMobAdView") else null
		_size = Engine.get_singleton("PoingGodotAdMobAdSize") if Engine.has_singleton("PoingGodotAdMobAdSize") else null
		_cinfo = Engine.get_singleton("PoingGodotAdMobConsentInformation") if Engine.has_singleton("PoingGodotAdMobConsentInformation") else null
		_ump = Engine.get_singleton("PoingGodotAdMobUserMessagingPlatform") if Engine.has_singleton("PoingGodotAdMobUserMessagingPlatform") else null
		enabled = _rew != null
		status = "starting"
		if enabled:
			# let the first menu frame appear before any ad code runs
			get_tree().create_timer(2.0).timeout.connect(_begin)
		else:
			status = "plugin incomplete"
	else:
		status = "off (no AdMob in this build)" if not sim else "simulated (desktop)"


func _load_cfg() -> void:
	units = TEST_UNITS.duplicate()
	live = false
	live_banner = false
	live_rewarded = false
	if not FileAccess.file_exists(CFG_PATH):
		return
	var f := FileAccess.open(CFG_PATH, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary):
		return
	var all_live := bool(d.get("live", false))
	var b := str(d.get("banner", ""))
	var r := str(d.get("rewarded", ""))
	if (all_live or bool(d.get("live_banner", false))) and b.begins_with("ca-app-pub-"):
		units["banner"] = b
		live_banner = true
	if (all_live or bool(d.get("live_rewarded", false))) and r.begins_with("ca-app-pub-"):
		units["rewarded"] = r
		live_rewarded = true
	live = live_banner or live_rewarded


func units_text() -> String:
	return "banner:%s  rewarded:%s" % ["LIVE" if live_banner else "test", "LIVE" if live_rewarded else "test"]


## true when pressing a "watch an ad" button can work right now
func can_show() -> bool:
	if _showing:
		return false
	if enabled:
		return sdk_ready and _rew_loaded
	return sim


## the button should exist at all (hidden on builds without AdMob)
func offered() -> bool:
	return enabled or sim


func label_for_button() -> String:
	if enabled and not _rew_loaded:
		return UI.tx("Loading ad...", "جاري تحميل الإعلان...")
	return ""


# ------------------------------------------------------------------ start up: consent, then SDK
func _begin() -> void:
	_guard_set(true)
	_trace("begin (consent)")
	get_tree().create_timer(25.0).timeout.connect(func():
		_trace("survived 25s - guard cleared")
		_guard_set(false))
	if _cinfo == null:
		_init_sdk()
		return
	status = "consent"
	_cinfo.connect("on_consent_info_updated_success", _on_consent_info_ok)
	_cinfo.connect("on_consent_info_updated_failure", _on_consent_info_fail)
	_cinfo.call("update", {"tag_for_under_age_of_consent": false, "consent_debug_settings": {}})
	# never wait forever for the consent servers
	get_tree().create_timer(10.0).timeout.connect(_init_sdk)


func _on_consent_info_ok() -> void:
	if _cinfo != null and int(_cinfo.call("get_consent_status")) == 2 and bool(_cinfo.call("get_is_consent_form_available")) and _ump != null:
		_show_consent_form(true)
	else:
		_init_sdk()


func _on_consent_info_fail(err: Dictionary) -> void:
	last_error = "consent: " + str(err.get("message", err))
	_init_sdk()


func _show_consent_form(then_init: bool) -> void:
	if _ump == null:
		if then_init:
			_init_sdk()
		return
	if not _ump.is_connected("on_consent_form_load_success_listener", _on_form_loaded):
		_ump.connect("on_consent_form_load_success_listener", _on_form_loaded)
		_ump.connect("on_consent_form_load_failure_listener", _on_form_load_fail)
		_ump.connect("on_consent_form_dismissed", _on_form_dismissed)
	_ump.call("load_consent_form")


func _on_form_loaded(uid: int) -> void:
	_ump.call("show", uid)


func _on_form_load_fail(err: Dictionary) -> void:
	last_error = "form: " + str(err.get("message", err))
	_init_sdk()


func _on_form_dismissed(_uid: int, _err: Dictionary) -> void:
	_init_sdk()


## Settings page button ("Privacy choices"): lets the player change his consent answer.
func show_privacy_options() -> void:
	if _cinfo == null or _ump == null:
		return
	_show_consent_form(false)


func _init_sdk() -> void:
	if _init_started or _sdk == null:
		return
	_init_started = true
	_trace("init sdk")
	status = "init"
	_sdk.call("set_request_configuration", {"max_ad_content_rating": "T", "tag_for_child_directed_treatment": -1, "tag_for_under_age_of_consent": -1}, PackedStringArray())
	_sdk.connect("on_initialization_complete", _on_sdk_ready)
	_sdk.call("initialize")
	get_tree().create_timer(15.0).timeout.connect(func():
		if not sdk_ready:
			status = "init timeout"
			last_error = "SDK did not answer in 15s"
			changed.emit())


func _on_sdk_ready(_st: Dictionary) -> void:
	sdk_ready = true
	_trace("sdk ready")
	status = "ready (" + units_text() + ")"
	_sdk.call("set_ios_app_pause_on_background", false)
	_connect_rewarded()
	_load_rewarded()
	changed.emit()


# ------------------------------------------------------------------ rewarded
func _connect_rewarded() -> void:
	_rew.connect("on_rewarded_ad_loaded", _on_rew_loaded)
	_rew.connect("on_rewarded_ad_failed_to_load", _on_rew_load_fail)
	_rew.connect("on_rewarded_ad_user_earned_reward", _on_rew_earned)
	_rew.connect("on_rewarded_ad_dismissed_full_screen_content", _on_rew_closed)
	_rew.connect("on_rewarded_ad_failed_to_show_full_screen_content", _on_rew_show_fail)
	_rew.connect("on_rewarded_ad_showed_full_screen_content", func(_u: int): _mute(true))


func _request() -> Dictionary:
	return {"google_request_agent": "", "mediation_extras": [], "extras": {}}


func _load_rewarded() -> void:
	if not sdk_ready or _rew_loading or _rew_loaded:
		return
	_rew_loading = true
	_rew_uid = int(_rew.call("create"))
	_rew.call("load", str(units["rewarded"]), _request(), PackedStringArray(), _rew_uid)


func _on_rew_loaded(uid: int) -> void:
	if uid != _rew_uid:
		return
	_rew_loading = false
	_rew_loaded = true
	last_error = ""
	changed.emit()


func _on_rew_load_fail(uid: int, err: Dictionary) -> void:
	if uid != _rew_uid:
		return
	_rew_loading = false
	_rew_loaded = false
	last_error = "rewarded load: %s (code %s)" % [str(err.get("message", "?")), str(err.get("code", "?"))]
	_retries += 1
	_retry = minf(60.0, 8.0 * pow(2.0, float(mini(_retries, 3))))
	changed.emit()


## Starts a rewarded ad. `on_reward` runs only if the player really earned the reward.
func show_rewarded(on_reward: Callable) -> bool:
	if _showing:
		return false
	if enabled:
		if not (sdk_ready and _rew_loaded):
			return false
		_showing = true
		_earned = false
		_rew_cb = on_reward
		_rew.call("show", _rew_uid)
		changed.emit()
		return true
	if sim:
		_sim_ad(on_reward)
		return true
	return false


func _on_rew_earned(uid: int, _item: Dictionary) -> void:
	if uid == _rew_uid:
		_earned = true


func _on_rew_closed(uid: int) -> void:
	if uid != _rew_uid:
		return
	_mute(false)
	_showing = false
	_rew_loaded = false
	var cb := _rew_cb
	var ok := _earned
	_rew_cb = Callable()
	_earned = false
	_retries = 0
	_load_rewarded()
	changed.emit()
	if ok and cb.is_valid():
		cb.call()


func _on_rew_show_fail(uid: int, err: Dictionary) -> void:
	if uid != _rew_uid:
		return
	_mute(false)
	_showing = false
	_rew_loaded = false
	last_error = "rewarded show: " + str(err.get("message", err))
	_rew_cb = Callable()
	_load_rewarded()
	changed.emit()


func _mute(on: bool) -> void:
	if on:
		_muted_before = AudioServer.is_bus_mute(0)
		AudioServer.set_bus_mute(0, true)
	else:
		AudioServer.set_bus_mute(0, _muted_before)


# ------------------------------------------------------------------ banner (shown only where the page asks for it)
func want_banner(on: bool) -> void:
	_ban_want = on
	_apply_banner()


func _apply_banner() -> void:
	if not enabled or not sdk_ready or _ban == null or _size == null:
		return
	var show_it := _ban_want and not Gfx.racing
	if show_it and _ban_uid < 0 and not _ban_creating:
		_create_banner()
		return
	if _ban_uid >= 0 and _ban_loaded:
		if show_it and not _ban_visible:
			_ban.call("show", _ban_uid)
			_ban_visible = true
		elif not show_it and _ban_visible:
			_ban.call("hide", _ban_uid)
			_ban_visible = false


func _create_banner() -> void:
	_ban_creating = true
	_ban.connect("on_ad_loaded", _on_ban_loaded)
	_ban.connect("on_ad_failed_to_load", _on_ban_fail)
	var sz: Dictionary = _size.call("getCurrentOrientationAnchoredAdaptiveBannerAdSize", -1)
	_ban_uid = int(_ban.call("create", {"ad_unit_id": str(units["banner"]), "ad_position": AD_POS_BOTTOM, "ad_size": sz}))
	_ban.call("hide", _ban_uid)
	_ban_visible = false
	_ban.call("load_ad", _ban_uid, _request(), PackedStringArray())


func _on_ban_loaded(uid: int) -> void:
	if uid != _ban_uid:
		return
	_ban_loaded = true
	_ban_creating = false
	last_error = ""
	_apply_banner()
	changed.emit()


func _on_ban_fail(uid: int, err: Dictionary) -> void:
	if uid != _ban_uid:
		return
	last_error = "banner: %s (code %s)" % [str(err.get("message", "?")), str(err.get("code", "?"))]
	_ban_loaded = false
	_ban_creating = false
	_ban.call("destroy", _ban_uid)
	_ban_uid = -1
	changed.emit()


func banner_active() -> bool:
	return _ban_visible


func _process(d: float) -> void:
	if not enabled:
		return
	_poll += d
	if _poll >= 0.4:
		_poll = 0.0
		_apply_banner()
	if _retry > 0.0:
		_retry -= d
		if _retry <= 0.0:
			_retry = 0.0
			_load_rewarded()


# ------------------------------------------------------------------ desktop simulation (never shipped to the phone)
func _sim_ad(on_reward: Callable) -> void:
	_showing = true
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var l := Label.new()
	l.text = "TEST AD (desktop simulation)"
	l.add_theme_font_size_override("font_size", 40)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bg.add_child(l)
	await get_tree().create_timer(1.2).timeout
	layer.queue_free()
	_showing = false
	if on_reward.is_valid():
		on_reward.call()
	changed.emit()
