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
const TIER_NAMES := [["ROOKIE CUP", "كأس المبتدئين"], ["PRO SERIES", "سلسلة المحترفين"], ["EXPERT LEAGUE", "دوري الخبراء"], ["LEGEND CHAMPIONSHIP", "بطولة الأساطير"]]
const PLACE := {"autumn": [["Maple", "القيقب"], ["Amber", "العنبر"], ["Harvest", "الحصاد"]], "snow": [["Frost", "الصقيع"], ["Glacier", "الجليد"], ["Aurora", "الشفق"]],
	"mountain": [["Summit", "القمة"], ["Cliff", "الجرف"], ["Hairpin", "الدبوس"]]}
const WX_ADJ := {"clear": ["Sunlit", "مشمس"], "fog": ["Misty", "ضبابي"], "rain": ["Rainy", "ماطر"], "night": ["Midnight", "ليلي"], "storm": ["Thunder", "عاصف"]}
const SUFFIX := [["Run", "انطلاقة"], ["Pass", "ممر"], ["Ridge", "حافة"], ["Climb", "تسلق"], ["Circuit", "حلبة"]]
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


static func stage_name(i: int) -> String:
	var lv := level(i)
	var pl: Array = PLACE[lv["theme"]][(i * 2 + i / 5) % 3]
	var sf: Array = SUFFIX[i % 5]
	var wa: Array = WX_ADJ[lv["weather"]]
	if L.is_ar():
		return "%s %s %s" % [sf[1], pl[1], wa[1]]
	return "%s %s %s" % [wa[0], pl[0], sf[0]]


static func stars_for(place: int) -> int:
	return clampi(4 - place, 0, 3)


static func unlocked(i: int) -> bool:
	return i == 0 or int(Profile.career.get(str(i - 1), 0)) > 0


static func nm(arr: Array) -> String:
	return str(arr[1] if L.is_ar() else arr[0])
