# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
extends Node
## Autoload "Profile": the player's garage, outfit, coins, level, daily quests and chests (saved on the device).

signal changed
signal leveled(level: int, reward: Dictionary)

const SAVE := "user://profile.json"

var pname := ""
var steer_mode := ""          # "" = not chosen yet | buttons | wheel | wheel360
var coins := 1000
var gems := 20
var xp := 0
var level := 1
var owned := {}                 # "slot:id" -> true (bought / won)
var cars := {"hatch": true}
var car := "hatch"
var carset := {}                # car id -> {paint, stripe, rim, glow}
var up := {}                    # car id -> {engine: 0..5, ...}
var outfit := Catalog.DEFAULT_OUTFIT.duplicate()
var quests := {"date": "", "list": []}
var chests := {"bronze": 1, "silver": 0, "gold": 0}
var adbox := {"date": "", "n": 0}       # daily chests earned by watching a rewarded ad
var login := {"last": "", "streak": 0}
var stats := {"races": 0, "wins": 0, "fires": 0}
var career := {}                # career level index (string) -> best stars 0..3
var solo_pref := {"bots": 3, "level": 1, "weather": "clear", "theme": ""}
var pid := ""                   # anonymous player id used by the backend
var pending_order := ""         # card payment started but not yet credited
var _busy_save := false


func _ready() -> void:
	_load()
	if pname == "":
		pname = "Player%d" % (randi() % 900 + 100)
		save()
	if pid == "":
		pid = Crypto.new().generate_random_bytes(10).hex_encode()
		save()
	refresh_quests()


# ---------------------------------------------------------------- save / load
func _load() -> void:
	if not FileAccess.file_exists(SAVE):
		return
	var f := FileAccess.open(SAVE, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary):
		return
	pname = str(d.get("pname", pname))
	pid = str(d.get("pid", ""))
	pending_order = str(d.get("pending_order", ""))
	steer_mode = str(d.get("steer_mode", ""))
	coins = int(d.get("coins", coins))
	gems = int(d.get("gems", gems))
	xp = int(d.get("xp", xp))
	level = maxi(1, int(d.get("level", level)))
	owned = d.get("owned", owned)
	cars = d.get("cars", cars)
	car = str(d.get("car", car))
	carset = d.get("carset", carset)
	up = d.get("up", up)
	var o: Dictionary = d.get("outfit", {})
	for k in o:
		outfit[k] = o[k]
	quests = d.get("quests", quests)
	chests = d.get("chests", chests)
	adbox = d.get("adbox", adbox)
	login = d.get("login", login)
	stats = d.get("stats", stats)
	career = d.get("career", career)
	var sp: Variant = d.get("solo_pref", solo_pref)
	if sp is Dictionary:
		solo_pref = sp
	for cid in cars:
		_grant_defaults(str(cid))
	if not Catalog.CARS.has(car) or not cars.has(car):
		car = "hatch"


func save() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f == null and has_node("/root/Backend"):
		Backend.report("error", "Could not write the save file (%s)" % error_string(FileAccess.get_open_error()))
	if f:
		f.store_string(JSON.stringify({"pid": pid, "pending_order": pending_order, "pname": pname, "steer_mode": steer_mode, "coins": coins, "gems": gems, "xp": xp, "level": level, "owned": owned, "cars": cars, "car": car,
			"carset": carset, "up": up, "outfit": outfit, "quests": quests, "chests": chests, "adbox": adbox, "login": login, "stats": stats, "career": career, "solo_pref": solo_pref}))
	changed.emit()


# ---------------------------------------------------------------- ownership
func is_free(e: Dictionary) -> bool:
	return int(e.get("price", 0)) == 0 and not e.has("gem")


func owns(slot: String, id: String) -> bool:
	var e := Catalog.entry(slot, id)
	return is_free(e) or owned.has(slot + ":" + id)


func price_text(e: Dictionary) -> String:
	if e.has("gem"):
		return "%d 💎" % int(e["gem"])
	return "%d 🪙" % int(e.get("price", 0))


func can_afford(e: Dictionary) -> bool:
	if e.has("gem"):
		return gems >= int(e["gem"])
	return coins >= int(e.get("price", 0))


func _pay(e: Dictionary) -> bool:
	if not can_afford(e):
		return false
	if e.has("gem"):
		gems -= int(e["gem"])
	else:
		coins -= int(e.get("price", 0))
	return true


func buy(slot: String, id: String) -> bool:
	if owns(slot, id):
		return true
	if not _pay(Catalog.entry(slot, id)):
		return false
	owned[slot + ":" + id] = true
	save()
	return true


func buy_car(id: String) -> bool:
	var e: Dictionary = Catalog.CARS[id]
	if cars.has(id) or level < int(e["lvl"]):
		return false
	if coins < int(e["price"]):
		return false
	coins -= int(e["price"])
	cars[id] = true
	car = id
	_grant_defaults(id)
	save()
	return true


## a car comes with its showroom paint / stripe / rims
func _grant_defaults(id: String) -> void:
	var e: Dictionary = Catalog.CARS.get(id, {})
	for slot in ["paint", "stripe", "rim"]:
		if e.has(slot):
			owned[slot + ":" + str(e[slot])] = true


func car_set(id := "") -> Dictionary:
	if id == "":
		id = car
	var d: Dictionary = carset.get(id, {})
	var cd: Dictionary = Catalog.CARS.get(id, {})
	return {"paint": d.get("paint", cd.get("paint", "red")), "stripe": d.get("stripe", cd.get("stripe", "none")), "rim": d.get("rim", cd.get("rim", "steel")), "glow": d.get("glow", "none"), "decal": d.get("decal", "none"), "spoiler": d.get("spoiler", "none"), "front": d.get("front", "none"), "hood": d.get("hood", "none"), "skirts": d.get("skirts", "none"), "wheel": d.get("wheel", "stock")}


func equip_car_part(slot: String, id: String) -> void:
	if not owns(slot, id):
		return
	var d: Dictionary = car_set()
	d[slot] = id
	carset[car] = d
	save()


func equip_outfit(slot: String, id: String) -> void:
	if owns(slot, id):
		outfit[slot] = id
		save()


func select_car(id: String) -> void:
	if cars.has(id):
		car = id
		save()


func part_owned(slot: String, tier: int) -> bool:
	return owned.has("part:%s:%d" % [slot, tier])


func buy_part(slot: String, tier: int) -> bool:
	var price := int(Catalog.PARTS[slot]["price"][tier - 1])
	if part_owned(slot, tier) or coins < price:
		return false
	coins -= price
	owned["part:%s:%d" % [slot, tier]] = true
	install_part(car, slot, tier)
	return true


## fit a bought part on a car (it leaves the car that had it); tier 0 removes
func install_part(car_id: String, slot: String, tier: int) -> void:
	if tier > 0 and not part_owned(slot, tier):
		return
	if tier > 0:
		for cid in up.keys():
			if int((up[cid] as Dictionary).get("fit_" + slot, 0)) == tier:
				(up[cid] as Dictionary)["fit_" + slot] = 0
	var d: Dictionary = up.get(car_id, {})
	d["fit_" + slot] = tier
	up[car_id] = d
	save()


func up_level(car_id: String, key: String) -> int:
	return int((up.get(car_id, {}) as Dictionary).get(key, 0))


func upgrade(car_id: String, key: String) -> bool:
	var lv := up_level(car_id, key)
	if lv >= Catalog.MAX_UP:
		return false
	var cost := Catalog.upgrade_cost(key, lv)
	if coins < cost:
		return false
	coins -= cost
	var d: Dictionary = up.get(car_id, {})
	d[key] = lv + 1
	up[car_id] = d
	save()
	return true


## what is sent to the other players / used by the server physics
func loadout() -> Dictionary:
	var cs := car_set()
	return {"car": car, "paint": cs["paint"], "stripe": cs["stripe"], "rim": cs["rim"], "glow": cs["glow"], "decal": cs["decal"], "spoiler": cs["spoiler"], "front": cs["front"], "hood": cs["hood"], "skirts": cs["skirts"], "wheel": cs["wheel"],
		"up": (up.get(car, {}) as Dictionary).duplicate(), "outfit": outfit.duplicate()}


# ---------------------------------------------------------------- xp / level
func add_xp(n: int) -> void:
	xp += n
	while xp >= Catalog.xp_for(level):
		xp -= Catalog.xp_for(level)
		level += 1
		var r := Catalog.level_reward(level)
		coins += int(r["coins"])
		gems += int(r["gems"])
		for k in r["kinds"]:
			chests[k] = int(chests.get(k, 0)) + 1
		leveled.emit(level, r)
	save()


func add_coins(n: int) -> void:
	coins += n
	save()


# ---------------------------------------------------------------- daily login + quests
func _today() -> String:
	return Time.get_date_string_from_system()


## returns {} when already collected today, else the reward that was given
func daily_login() -> Dictionary:
	var today := _today()
	if login["last"] == today:
		return {}
	var yesterday := Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)
	login["streak"] = int(login["streak"]) + 1 if login["last"] == yesterday else 1
	login["last"] = today
	var day := (int(login["streak"]) - 1) % 7 + 1
	var r := {"coins": 200 + day * 100, "gems": 0, "chest": ""}
	if day == 7:
		r["gems"] = 20
		r["chest"] = "silver"
		chests["silver"] = int(chests.get("silver", 0)) + 1
	coins += int(r["coins"])
	gems += int(r["gems"])
	r["day"] = day
	save()
	return r


func refresh_quests() -> void:
	var today := _today()
	if quests["date"] == today and (quests["list"] as Array).size() == 3:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(today)
	var pool := Catalog.QUEST_POOL.duplicate()
	var list: Array = []
	var used_ev := {}
	while list.size() < 3 and not pool.is_empty():
		var q: Dictionary = pool.pop_at(rng.randi() % pool.size())
		if used_ev.has(q["ev"]):
			continue
		used_ev[q["ev"]] = true
		list.append({"id": q["id"], "p": 0, "claimed": false})
	quests = {"date": today, "list": list}
	save()


func quest_def(id: String) -> Dictionary:
	for q in Catalog.QUEST_POOL:
		if q["id"] == id:
			return q
	return {}


func event(ev: String, n := 1) -> void:
	refresh_quests()
	for q in quests["list"]:
		var d := quest_def(q["id"])
		if d.get("ev", "") == ev and not q["claimed"]:
			q["p"] = mini(int(d["n"]), int(q["p"]) + n)
	save()


func quest_done(i: int) -> bool:
	var q: Dictionary = quests["list"][i]
	return int(q["p"]) >= int(quest_def(q["id"])["n"])


func claim_quest(i: int) -> bool:
	var q: Dictionary = quests["list"][i]
	if q["claimed"] or not quest_done(i):
		return false
	q["claimed"] = true
	var d := quest_def(q["id"])
	coins += int(int(d["coins"]) * Backend.rc("quest_mult"))
	var all_done := true
	for o in quests["list"]:
		if not o["claimed"]:
			all_done = false
	if all_done:
		chests["silver"] = int(chests.get("silver", 0)) + 1     # bonus for finishing every daily quest
	add_xp(int(int(d["xp"]) * Backend.rc("quest_mult")))
	return true


# ---------------------------------------------------------------- chests
const AD_BOXES_PER_DAY := 3


func adbox_cap() -> int:
	return maxi(0, int(Backend.rc("adbox_per_day", float(AD_BOXES_PER_DAY))))


func adbox_used() -> int:
	if str(adbox.get("date", "")) != _today():
		return 0
	return int(adbox.get("n", 0))


func adbox_left() -> int:
	return maxi(0, adbox_cap() - adbox_used())


## called after a rewarded ad was really watched: returns the chest kind that was added ("" = none left today)
func claim_adbox() -> String:
	if adbox_left() <= 0:
		return ""
	var n := adbox_used() + 1
	adbox = {"date": _today(), "n": n}
	var kind := "silver" if n == adbox_cap() else "bronze"
	chests[kind] = int(chests.get(kind, 0)) + 1
	save()
	return kind


func give_chest(kind: String) -> void:
	chests[kind] = int(chests.get(kind, 0)) + 1
	save()


## opens one chest: returns {kind, coins, gems, item:{slot,id,rar,dup}}
func open_chest(kind: String) -> Dictionary:
	if int(chests.get(kind, 0)) <= 0:
		return {}
	chests[kind] = int(chests[kind]) - 1
	var w: Array = Catalog.CHESTS[kind]["w"]
	var total := 0
	for x in w:
		total += int(x)
	var roll := randi() % total
	var rar := 0
	for i in w.size():
		if roll < int(w[i]):
			rar = i
			break
		roll -= int(w[i])
	var cm := Backend.rc("chest_mult")
	var res := {"kind": kind, "coins": int((100 + randi() % 200 * (rar + 1)) * cm), "gems": int(((randi() % 5 + 1) * (1 if rar < 2 else 3) if rar >= 1 else 0) * cm)}
	var pool: Array = []
	for it in Catalog.all_items():
		var e: Dictionary = it["e"]
		if int(e["r"]) == rar and not owns(it["slot"], it["id"]) and (it["slot"] != "emote" or true):
			pool.append(it)
	if not pool.is_empty():
		var it: Dictionary = pool[randi() % pool.size()]
		owned[it["slot"] + ":" + it["id"]] = true
		res["item"] = {"slot": it["slot"], "id": it["id"], "rar": rar}
	else:
		res["coins"] = int(res["coins"]) + 400 * (rar + 1)
	coins += int(res["coins"])
	gems += int(res["gems"])
	save()
	return res


func buy_chest(kind: String) -> bool:
	var c: Dictionary = Catalog.CHESTS[kind]
	if c.has("coins"):
		if coins < int(c["coins"]):
			return false
		coins -= int(c["coins"])
	else:
		if gems < int(c["gem"]):
			return false
		gems -= int(c["gem"])
	chests[kind] = int(chests.get(kind, 0)) + 1
	save()
	return true


# ---------------------------------------------------------------- shop deals (change every day)
func daily_deals() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_today() + "deal")
	var pool: Array = []
	for it in Catalog.all_items():
		var e: Dictionary = it["e"]
		if int(e.get("price", 0)) > 0 and not owns(it["slot"], it["id"]):
			pool.append(it)
	var out: Array = []
	while out.size() < 3 and not pool.is_empty():
		out.append(pool.pop_at(rng.randi() % pool.size()))
	return out


func buy_deal(it: Dictionary) -> bool:
	var e: Dictionary = Catalog.entry(it["slot"], it["id"])
	var cost := int(int(e["price"]) * 0.7)
	if coins < cost:
		return false
	coins -= cost
	owned[it["slot"] + ":" + it["id"]] = true
	save()
	return true


# ---------------------------------------------------------------- race rewards
## medal: 0 gold, 1 silver, 2 bronze, -1 none. Returns a summary and gives the loot.
func race_reward(place: int, total: int, medal: int, mountain: bool) -> Dictionary:
	var base := 150
	var xpv := 60
	if total > 1:
		base += maxi(0, total - place) * 80
		xpv += maxi(0, total - place) * 20
	if medal == 0:
		base += 300
		xpv += 80
	elif medal == 1:
		base += 180
		xpv += 50
	elif medal == 2:
		base += 90
		xpv += 25
	if mountain:
		base = int(base * 1.2)
	base = int(base * Backend.rc("reward_mult"))
	xpv = int(xpv * Backend.rc("reward_mult"))
	var chest := ""
	if total > 1 and place == 1:
		chest = "bronze"
	elif medal == 0:
		chest = "bronze" if randf() < 0.5 else ""
	stats["races"] = int(stats["races"]) + 1
	event("finish")
	if mountain:
		event("mountain")
	if total > 1 and place == 1:
		stats["wins"] = int(stats["wins"]) + 1
		event("win")
	if medal == 0:
		event("gold")
	coins += base
	if chest != "":
		chests[chest] = int(chests.get(chest, 0)) + 1
	var lv0 := level
	add_xp(xpv)
	return {"coins": base, "xp": xpv, "chest": chest, "level_up": level > lv0}


## career: called when the race of level `idx` is over. Returns what the player got.
func career_result(idx: int, place: int) -> Dictionary:
	var lv := Career.level(idx)
	var stars := Career.stars_for(place)
	var passed: bool = place <= int(lv["need"])
	var key := str(idx)
	var old := int(career.get(key, 0))
	var out := {"passed": passed, "stars": stars, "coins": 0, "gems": 0, "chest": "", "first": false, "new_stars": 0}
	if not passed:
		return out
	var first := old == 0
	out["first"] = first
	var coins := int(lv["coins"]) * (1.0 if first else 0.4) * (0.7 + 0.1 * stars)
	out["coins"] = int(coins)
	coins_add_raw(int(coins))
	if first:
		out["gems"] = int(lv["gems"])
		gems += int(lv["gems"])
		out["chest"] = str(lv["chest"])
		if out["chest"] != "":
			chests[out["chest"]] = int(chests.get(out["chest"], 0)) + 1
	if stars > old:
		career[key] = stars
		out["new_stars"] = stars - old
	save()
	return out


func coins_add_raw(n: int) -> void:
	coins += n
