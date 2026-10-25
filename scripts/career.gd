# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
class_name Career
extends RefCounted
## Career mode: 20 fixed stages in a row. Every stage has its own track, weather and opponents; the opponents get
## faster as you go. Finish in the top places to pass (and unlock the next one); a better place gives more stars.

const COUNT := 20
const LEVEL_NAMES := [["Rookie", "مبتدئ"], ["Pro", "محترف"], ["Expert", "خبير"], ["Legend", "أسطورة"]]
const WEATHER_NAMES := {
	"clear": ["Clear", "صافي"], "fog": ["Fog", "ضباب"], "rain": ["Rain", "مطر"], "night": ["Night", "ليل"], "storm": ["Storm", "عاصفة"],
}
const THEME_NAMES := {
	"mountain": ["Mountain", "جبل"], "snow": ["Snow", "ثلج"], "autumn": ["Autumn", "خريف"],
}
const THEME_ORDER := ["autumn", "snow", "mountain", "mountain", "snow", "autumn", "mountain"]
const WEATHER_ORDER := ["clear", "clear", "fog", "rain", "night", "clear", "rain", "fog", "storm", "night"]


static func level(i: int) -> Dictionary:
	i = clampi(i, 0, COUNT - 1)
	var boss := (i % 5) == 4
	var tier := clampi(i / 5, 0, 3)
	var weather: String = WEATHER_ORDER[i % WEATHER_ORDER.size()]
	if i < 2:
		weather = "clear"
	var bots := clampi(2 + i / 4, 2, 5)
	var need := 1 if boss else (3 if i < 5 else 2)
	var coins := 500 + i * 180 + (1500 if boss else 0)
	var gems := (5 + i) if boss else 0
	var chest := ""
	if boss:
		chest = "bronze" if i < 9 else ("silver" if i < 19 else "gold")
	return {"i": i, "boss": boss, "tier": tier, "level": tier, "weather": weather, "theme": THEME_ORDER[i % THEME_ORDER.size()], "bots": bots, "need": need,
		"seed": 4100 + i * 131, "coins": coins, "gems": gems, "chest": chest}


static func stars_for(place: int) -> int:
	return clampi(4 - place, 0, 3)


static func unlocked(i: int) -> bool:
	return i == 0 or int(Profile.career.get(str(i - 1), 0)) > 0


static func nm(arr: Array) -> String:
	return str(arr[1] if L.is_ar() else arr[0])
