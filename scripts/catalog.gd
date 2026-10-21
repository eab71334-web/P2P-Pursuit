class_name Catalog
extends RefCounted
## Static game data: cars, paints, outfit items, emotes, upgrades, quests. Names are [en, ar].

const RARITY := ["common", "rare", "epic", "legendary"]
const RARITY_COLOR := [Color(0.7, 0.75, 0.82), Color(0.25, 0.6, 1.0), Color(0.7, 0.35, 0.95), Color(1.0, 0.7, 0.1)]
const RARITY_NAME := [["Common", "عادي"], ["Rare", "نادر"], ["Epic", "ملحمي"], ["Legendary", "أسطوري"]]

# power = engine force x, top = top speed km/h, grip = tyre grip x, armor = damage taken x (lower = tougher)
const CARS := {
	"hatch": {"n": ["Rally Hatch RX", "رالي هاتش RX"], "r": 0, "price": 0, "lvl": 1, "power": 1.0, "top": 165.0, "grip": 1.0, "armor": 1.0,
		"d": ["Balanced starter rally car", "سيارة رالي متوازنة للبداية"]},
	"buggy": {"n": ["Dune Buggy", "بقي الكثبان"], "r": 1, "price": 2500, "lvl": 3, "power": 0.95, "top": 150.0, "grip": 1.25, "armor": 0.9,
		"d": ["Grips like glue off-road", "تمسك الأرض بقوة"]},
	"muscle": {"n": ["Muscle GT", "ماسل GT"], "r": 1, "price": 6000, "lvl": 5, "power": 1.2, "top": 180.0, "grip": 0.88, "armor": 1.0,
		"d": ["Huge power, hard to tame", "قوة هائلة وصعبة الترويض"], "drop": 0.2, "paint": "yellow", "stripe": "black", "rim": "black"},
	"sierra": {"n": ["Cosworth RS", "كوزورث RS"], "r": 1, "price": 8000, "lvl": 6, "power": 1.15, "top": 178.0, "grip": 1.0, "armor": 1.0,
		"d": ["Homologation legend", "أسطورة الرالي الكلاسيكية"], "drop": 0.14, "paint": "black", "stripe": "none", "rim": "steel"},
	"charger": {"n": ["Charger R/T", "تشارجر R/T"], "r": 2, "price": 12500, "lvl": 8, "power": 1.3, "top": 186.0, "grip": 0.95, "armor": 1.15,
		"d": ["Heavy, loud and fast", "ثقيلة وصاخبة وسريعة"], "drop": 0.18, "paint": "granite", "stripe": "none", "rim": "black"},
	"pickup": {"n": ["Trail 4x4", "تريل 4x4"], "r": 2, "price": 9500, "lvl": 7, "power": 1.05, "top": 160.0, "grip": 1.1, "armor": 1.35,
		"d": ["Tough as a tank", "قوية كالدبابة"]},
	"coupe": {"n": ["Apex Coupe", "أبكس كوبيه"], "r": 2, "price": 20000, "lvl": 10, "power": 1.25, "top": 195.0, "grip": 1.12, "armor": 0.95,
		"d": ["Track-bred speed", "سرعة سباقات حقيقية"], "drop": 0.26, "paint": "white", "stripe": "none", "rim": "black"},
	"m4": {"n": ["M4 Competition", "إم 4 كومبيتشن"], "r": 2, "price": 26000, "lvl": 11, "power": 1.35, "top": 205.0, "grip": 1.15, "armor": 1.0,
		"d": ["German sport coupe, twin kidney grille", "كوبيه ألماني رياضي بشبك مزدوج"], "drop": 0.26, "paint": "estoril", "stripe": "none", "rim": "black"},
	"gt3": {"n": ["GT3 Racer", "جي تي 3 ريسر"], "r": 3, "price": 32000, "lvl": 12, "power": 1.4, "top": 210.0, "grip": 1.3, "armor": 1.0,
		"d": ["Full-blown race machine", "سيارة سباق متكاملة"], "drop": 0.32, "paint": "papaya", "stripe": "none", "rim": "black"},
	"hyper": {"n": ["Phantom Hyper", "فانتوم هايبر"], "r": 3, "price": 50000, "lvl": 15, "power": 1.5, "top": 225.0, "grip": 1.2, "armor": 1.05,
		"d": ["The ultimate machine", "الوحش الأخير"], "drop": 0.3, "paint": "black", "stripe": "none", "rim": "black"},
}
const CAR_ORDER := ["hatch", "buggy", "muscle", "sierra", "pickup", "charger", "coupe", "m4", "gt3", "hyper"]

# metal / rough control the paint finish
const PAINTS := {
	"red": {"n": ["Racing Red", "أحمر سباق"], "r": 0, "price": 0, "c": Color(0.78, 0.08, 0.08), "m": 0.35, "ro": 0.4},
	"blue": {"n": ["Ocean Blue", "أزرق المحيط"], "r": 0, "price": 300, "c": Color(0.1, 0.3, 0.85), "m": 0.35, "ro": 0.4},
	"white": {"n": ["Snow White", "أبيض ثلجي"], "r": 0, "price": 300, "c": Color(0.93, 0.94, 0.96), "m": 0.3, "ro": 0.4},
	"black": {"n": ["Night Black", "أسود ليلي"], "r": 0, "price": 400, "c": Color(0.06, 0.06, 0.08), "m": 0.5, "ro": 0.3},
	"yellow": {"n": ["Sunny Yellow", "أصفر شمسي"], "r": 0, "price": 400, "c": Color(0.98, 0.78, 0.1), "m": 0.3, "ro": 0.4},
	"green": {"n": ["Forest Green", "أخضر الغابة"], "r": 0, "price": 400, "c": Color(0.1, 0.5, 0.2), "m": 0.35, "ro": 0.4},
	"estoril": {"n": ["Estoril Blue", "أزرق إستوريل"], "r": 1, "price": 1500, "c": Color(0.1, 0.25, 0.75), "m": 0.5, "ro": 0.3},
	"papaya": {"n": ["Papaya Orange", "برتقالي بابايا"], "r": 2, "price": 2200, "c": Color(1.0, 0.45, 0.02), "m": 0.5, "ro": 0.3},
	"granite": {"n": ["Granite Grey", "رمادي جرانيت"], "r": 1, "price": 1400, "c": Color(0.36, 0.38, 0.42), "m": 0.45, "ro": 0.4},
	"orange": {"n": ["Lava Orange", "برتقالي الحمم"], "r": 1, "price": 900, "c": Color(1.0, 0.4, 0.05), "m": 0.5, "ro": 0.3},
	"purple": {"n": ["Violet Pearl", "بنفسجي لؤلؤي"], "r": 1, "price": 1200, "c": Color(0.5, 0.15, 0.8), "m": 0.6, "ro": 0.25},
	"matte": {"n": ["Stealth Matte", "رمادي مطفي"], "r": 2, "price": 2500, "c": Color(0.22, 0.24, 0.27), "m": 0.1, "ro": 0.9},
	"candy": {"n": ["Candy Pink", "وردي كاندي"], "r": 2, "price": 3000, "c": Color(1.0, 0.2, 0.55), "m": 0.7, "ro": 0.2},
	"gold": {"n": ["Liquid Gold", "ذهب سائل"], "r": 3, "price": 0, "gem": 120, "c": Color(1.0, 0.75, 0.15), "m": 0.95, "ro": 0.18},
	"chrome": {"n": ["Mirror Chrome", "كروم مرآة"], "r": 3, "price": 0, "gem": 150, "c": Color(0.85, 0.88, 0.95), "m": 1.0, "ro": 0.08},
}
const PAINT_ORDER := ["red", "blue", "white", "black", "yellow", "green", "orange", "purple", "estoril", "papaya", "granite", "matte", "candy", "gold", "chrome"]

const STRIPES := {
	"none": {"n": ["No stripes", "بدون خطوط"], "r": 0, "price": 0, "c": Color.WHITE},
	"white": {"n": ["Center white", "أبيض وسط"], "r": 0, "price": 250, "c": Color(0.95, 0.95, 0.97)},
	"black": {"n": ["Center black", "أسود وسط"], "r": 0, "price": 250, "c": Color(0.05, 0.05, 0.07)},
	"gold": {"n": ["Center gold", "ذهبي وسط"], "r": 1, "price": 800, "c": Color(1.0, 0.8, 0.2)},
	"cyan": {"n": ["Neon cyan", "سماوي نيون"], "r": 2, "price": 1800, "c": Color(0.1, 0.95, 1.0)},
	"flame": {"n": ["Hot orange", "برتقالي ناري"], "r": 2, "price": 1800, "c": Color(1.0, 0.45, 0.05)},
}
const STRIPE_ORDER := ["none", "white", "black", "gold", "cyan", "flame"]

const RIMS := {
	"steel": {"n": ["Steel", "حديد"], "r": 0, "price": 0, "c": Color(0.7, 0.72, 0.76)},
	"black": {"n": ["Black rims", "جنوط سوداء"], "r": 0, "price": 350, "c": Color(0.08, 0.08, 0.1)},
	"red": {"n": ["Red rims", "جنوط حمراء"], "r": 1, "price": 700, "c": Color(0.9, 0.1, 0.1)},
	"bronze": {"n": ["Bronze rims", "جنوط برونز"], "r": 1, "price": 900, "c": Color(0.75, 0.5, 0.2)},
	"neon": {"n": ["Neon rims", "جنوط نيون"], "r": 2, "price": 1800, "c": Color(0.2, 1.0, 0.5)},
	"gold": {"n": ["Gold rims", "جنوط ذهب"], "r": 3, "price": 0, "gem": 90, "c": Color(1.0, 0.8, 0.2)},
}
const RIM_ORDER := ["steel", "black", "red", "bronze", "neon", "gold"]

const GLOWS := {
	"none": {"n": ["No underglow", "بدون إضاءة"], "r": 0, "price": 0, "c": Color.BLACK},
	"blue": {"n": ["Blue glow", "إضاءة زرقاء"], "r": 1, "price": 1000, "c": Color(0.1, 0.4, 1.0)},
	"pink": {"n": ["Pink glow", "إضاءة وردية"], "r": 1, "price": 1000, "c": Color(1.0, 0.2, 0.7)},
	"green": {"n": ["Green glow", "إضاءة خضراء"], "r": 2, "price": 2000, "c": Color(0.2, 1.0, 0.3)},
	"white": {"n": ["Ice glow", "إضاءة جليدية"], "r": 3, "price": 0, "gem": 80, "c": Color(0.8, 0.95, 1.0)},
}
const GLOW_ORDER := ["none", "blue", "pink", "green", "white"]

# car part kinds shown in the garage
const DECALS := {
	"none": {"n": ["No sticker", "بدون ملصق"], "r": 0, "price": 0, "t": "", "c": Color.WHITE, "bg": Color.BLACK},
	"n07": {"n": ["Number 07", "رقم 07"], "r": 0, "price": 250, "t": "07", "c": Color(0.05, 0.05, 0.06), "bg": Color(0.95, 0.95, 0.95)},
	"n44": {"n": ["Number 44", "رقم 44"], "r": 0, "price": 250, "t": "44", "c": Color(1, 1, 1), "bg": Color(0.08, 0.08, 0.1)},
	"rs": {"n": ["RS badge", "شارة RS"], "r": 1, "price": 700, "t": "RS", "c": Color(1, 1, 1), "bg": Color(0.75, 0.08, 0.08)},
	"gt": {"n": ["GT badge", "شارة GT"], "r": 1, "price": 900, "t": "GT", "c": Color(0.05, 0.05, 0.06), "bg": Color(0.95, 0.75, 0.1)},
	"v8": {"n": ["V8 badge", "شارة V8"], "r": 2, "price": 1500, "t": "V8", "c": Color(1, 1, 1), "bg": Color(0.1, 0.3, 0.8)},
	"x": {"n": ["Team X", "فريق X"], "r": 3, "price": 0, "gem": 70, "t": "X", "c": Color(0.05, 0.05, 0.06), "bg": Color(0.2, 1.0, 0.5)},
}
const DECAL_ORDER := ["none", "n07", "n44", "rs", "gt", "v8", "x"]

# ---- body kit (shape changes). Every car has its own list of options per slot (BODY_OPTS).
const BODY_SLOTS := ["spoiler", "front", "hood", "skirts"]
const SPOILERS := {
	"none": {"n": ["Stock rear", "المؤخرة الأصلية"], "r": 0, "price": 0},
	"lip": {"n": ["Lip spoiler", "سبويلر شفة"], "r": 1, "price": 400},
	"duck": {"n": ["Ducktail", "ذيل البطة"], "r": 1, "price": 900},
	"gt": {"n": ["GT wing", "جناح GT"], "r": 2, "price": 2200},
	"twin": {"n": ["Twin-deck wing", "جناح مزدوج"], "r": 3, "price": 3500},
}
const FRONTS := {
	"none": {"n": ["Stock front", "المقدمة الأصلية"], "r": 0, "price": 0},
	"splitter": {"n": ["Carbon splitter", "سبليتر كربون"], "r": 1, "price": 700},
	"canards": {"n": ["Canard fins", "زعانف أمامية"], "r": 2, "price": 1400},
	"bullbar": {"n": ["Bull bar", "حديد حماية أمامي"], "r": 1, "price": 800},
}
const HOODS := {
	"none": {"n": ["Stock hood", "الغطاء الأصلي"], "r": 0, "price": 0},
	"scoop": {"n": ["Hood scoop", "مدخل هواء"], "r": 1, "price": 800},
	"vents": {"n": ["Louvred vents", "فتحات تهوية"], "r": 1, "price": 700},
	"carbon": {"n": ["Carbon hood", "غطاء كربون"], "r": 2, "price": 1800},
}
const SKIRTS := {
	"none": {"n": ["Stock sides", "الجوانب الأصلية"], "r": 0, "price": 0},
	"skirts": {"n": ["Side skirts", "عتبات جانبية"], "r": 1, "price": 600},
	"wide": {"n": ["Widebody kit", "طقم عريض"], "r": 3, "price": 3200},
}
const BODY_OPTS := {
	"hatch": {"spoiler": ["none", "lip", "duck", "gt"], "front": ["none", "splitter", "canards"], "hood": ["none", "scoop", "vents"], "skirts": ["none", "skirts"]},
	"buggy": {"spoiler": ["none", "twin"], "front": ["none", "bullbar", "splitter"], "hood": ["none", "scoop"], "skirts": ["none", "skirts"]},
	"muscle": {"spoiler": ["none", "lip", "duck"], "front": ["none", "splitter"], "hood": ["none", "scoop", "vents", "carbon"], "skirts": ["none", "skirts"]},
	"sierra": {"spoiler": ["none", "lip", "duck", "twin"], "front": ["none", "splitter"], "hood": ["none", "vents"], "skirts": ["none", "skirts"]},
	"pickup": {"spoiler": ["none", "lip"], "front": ["none", "bullbar", "splitter"], "hood": ["none", "scoop", "vents"], "skirts": ["none", "skirts"]},
	"charger": {"spoiler": ["none", "lip", "duck"], "front": ["none", "splitter", "canards"], "hood": ["none", "scoop", "vents", "carbon"], "skirts": ["none", "skirts", "wide"], "wheel": WHEEL_ORDER},
	"coupe": {"spoiler": ["none", "lip", "gt"], "front": ["none", "splitter", "canards"], "hood": ["none", "vents", "carbon"], "skirts": ["none", "skirts", "wide"]},
	"m4": {"spoiler": ["none", "lip", "gt"], "front": ["none", "splitter", "canards"], "hood": ["none", "vents", "carbon"], "skirts": ["none", "skirts", "wide"]},
	"gt3": {"spoiler": ["none", "gt", "twin"], "front": ["none", "splitter", "canards"], "hood": ["none", "vents", "carbon"], "skirts": ["none", "skirts", "wide"]},
	"hyper": {"spoiler": ["none", "gt", "twin"], "front": ["none", "splitter", "canards"], "hood": ["none", "vents", "carbon"], "skirts": ["none", "skirts", "wide"]},
}


## the body options a car can take for a slot (always starts with "none")
static func body_opts(car_id: String, slot: String) -> Array:
	var d: Dictionary = BODY_OPTS.get(car_id, BODY_OPTS["hatch"])
	return d.get(slot, ["none"])


# ---- real-world tech per car: engine, stage names, the parts each car can take, wheel designs it can wear
const CAR_TECH := {
	"hatch": {"engine": "1.6L Turbo I4  ·  220 hp", "stages": ["Sport air filter", "ECU remap", "Hybrid turbo", "Forged pistons", "Group-A race engine"],
		"slots": ["turbo", "exhaust", "aero", "susp", "kit"], "stock_wheel": "spoke5", "wheels": ["stock", "steel", "mesh"],
		"turbo": ["Garrett GT15", "Garrett GT25", "Garrett GT28 ball-bearing"], "exhaust": ["Cat-back sport", "Stainless 3\" race", "Titanium straight-pipe"],
		"aero": ["Front lip", "Roof spoiler kit", "Rally wing kit"], "susp": ["Lowering springs", "Rally coilovers", "Long-travel Ohlins"], "kit": ["Skid plate", "Underbody guard", "Full rally armor"]},
	"buggy": {"engine": "2.0L Turbo flat-4  ·  180 hp", "stages": ["Free-flow intake", "Dune remap", "Big turbo", "Forged flat-4", "Baja race engine"],
		"slots": ["turbo", "exhaust", "susp", "kit"], "stock_wheel": "beadlock", "wheels": ["stock", "steel"],
		"turbo": ["Mini turbo", "Hybrid turbo", "Race big turbo"], "exhaust": ["Side-exit pipe", "Race header", "Titanium stinger"],
		"susp": ["Long-travel shocks", "Bypass dampers", "Baja race shocks"], "kit": ["Roll bar braces", "Tube bumper", "Full roll cage"]},
	"muscle": {"engine": "5.7L V8  ·  360 hp", "stages": ["Cold-air intake", "Long-tube headers", "Cam + tune", "6.2L stroker kit", "Supercharged race V8"],
		"slots": ["turbo", "exhaust", "aero", "susp"], "stock_wheel": "classic", "wheels": ["stock", "spoke5", "mesh"],
		"turbo": ["Roots blower", "Twin-screw supercharger", "Centrifugal ProCharger"], "exhaust": ["Dual cat-back", "Long-tube headers", "Race X-pipe"],
		"aero": ["Rear lip", "Ducktail spoiler", "Drag wing"], "susp": ["Sport springs", "Tubular arms", "Drag coilovers"]},
	"sierra": {"engine": "2.0L Cosworth YB Turbo I4  ·  204 hp", "stages": ["Group-A airbox", "Chip tune", "Garrett T3/T4", "Forged YB internals", "Group-A race spec"],
		"slots": ["turbo", "exhaust", "aero", "susp", "kit"], "stock_wheel": "mesh", "wheels": ["stock", "spoke5", "steel"],
		"turbo": ["Garrett T3", "Garrett T3/T04E", "Garrett T04B race"], "exhaust": ["Stainless 3\"", "Group-A manifold", "Titanium race"],
		"aero": ["Whale-tail trim", "Extended whale tail", "Group-A wing"], "susp": ["Bilstein springs", "Group-A struts", "Rally coilovers"], "kit": ["Sump guard", "Underbody plates", "Full rally armor"]},
	"pickup": {"engine": "3.0L Turbo-diesel V6  ·  260 hp", "stages": ["Snorkel + filter", "Diesel remap", "Bigger turbo", "Reinforced block", "Baja race diesel"],
		"slots": ["turbo", "exhaust", "susp", "kit"], "stock_wheel": "steel", "wheels": ["stock", "beadlock", "spoke5"],
		"turbo": ["VNT turbo", "Twin turbo", "Compound turbo"], "exhaust": ["Diesel cat-back", "4\" turbo-back", "Race straight-pipe"],
		"susp": ["Lift springs", "Fox shocks", "Long-travel 2.5\""], "kit": ["Winch bumper", "Skid plates", "Armor + roof rack"]},
	"charger": {"engine": "6.4L HEMI V8  ·  485 hp", "stages": ["Cold-air intake", "Cat-back + tune", "Cam + heads", "7.0L stroker", "Supercharged Hellcat"],
		"slots": ["turbo", "exhaust", "aero", "susp"], "stock_wheel": "classic", "wheels": ["stock", "multi", "mesh"],
		"turbo": ["Whipple supercharger", "Twin-screw supercharger", "Hellcat supercharger"], "exhaust": ["Dual cat-back", "Long-tube headers", "Race headers"],
		"aero": ["Front splitter", "Ducktail kit", "GT wing"], "susp": ["Hellcat springs", "Adaptive dampers", "Race coilovers"]},
	"coupe": {"engine": "3.5L Twin-turbo V6  ·  400 hp", "stages": ["Performance intake", "ECU + tune", "Upgraded turbos", "Forged internals", "Track race engine"],
		"slots": ["turbo", "exhaust", "aero", "susp"], "stock_wheel": "multi", "wheels": ["stock", "spoke5", "turbine"],
		"turbo": ["Hybrid twin-turbo", "Big twin-turbo", "Race turbos"], "exhaust": ["Valved cat-back", "Race downpipes", "Titanium system"],
		"aero": ["Carbon lip", "Rear diffuser kit", "Track wing kit"], "susp": ["Sport springs", "Adjustable coilovers", "Track suspension"]},
	"m4": {"engine": "3.0L Twin-turbo I6 (S58)  ·  510 hp", "stages": ["Intake + charge pipes", "Stage 1 tune", "Catless downpipes", "Stage 2 hybrid turbos", "Stage 3 race build"],
		"slots": ["turbo", "exhaust", "aero", "susp"], "stock_wheel": "multi", "wheels": ["stock", "mesh", "centre"],
		"turbo": ["Upgraded turbos", "Hybrid turbos", "Race turbos"], "exhaust": ["Valved cat-back", "Catless downpipes", "Titanium race"],
		"aero": ["CSL lip", "Carbon trunk spoiler", "GT4 wing"], "susp": ["Eibach springs", "KW coilovers", "Race coilovers"]},
	"gt3": {"engine": "4.0L Flat-6 NA  ·  510 hp", "stages": ["Race intake", "ECU race map", "Cams + valvetrain", "Titanium rods", "Cup-spec engine"],
		"slots": ["exhaust", "aero", "susp", "kit"], "stock_wheel": "centre", "wheels": ["stock", "mesh", "multi"],
		"exhaust": ["Sport headers", "Race headers", "Titanium works exhaust"], "aero": ["Front splitter", "Swan-neck wing", "Cup aero package"],
		"susp": ["Sport dampers", "Race dampers", "Cup suspension"], "kit": ["Roll cage", "Fire system", "FIA safety pack"]},
	"hyper": {"engine": "8.0L Quad-turbo W16  ·  1500 hp", "stages": ["Hyper intake", "Hyper ECU", "Bigger turbos", "Titanium internals", "Hyper race build"],
		"slots": ["turbo", "exhaust", "aero", "susp"], "stock_wheel": "centre", "wheels": ["stock", "turbine", "multi"],
		"turbo": ["Quad hybrid turbos", "Big quad turbos", "Race quad turbos"], "exhaust": ["Hyper valved", "Titanium race", "Inconel system"],
		"aero": ["Active lip", "Active wing kit", "Track aero pack"], "susp": ["Active dampers", "Race active", "Track active"]},
}

const WHEELS := {
	"stock": {"n": ["Stock design", "التصميم الأصلي"], "r": 0, "price": 0},
	"steel": {"n": ["Steel wheel", "جنط حديد"], "r": 0, "price": 300},
	"spoke5": {"n": ["5-spoke", "5 أذرع"], "r": 1, "price": 900},
	"mesh": {"n": ["Mesh (BBS style)", "شبكي"], "r": 2, "price": 1600},
	"multi": {"n": ["Multi-spoke", "أذرع متعددة"], "r": 2, "price": 1800},
	"turbine": {"n": ["Turbine", "تيربين"], "r": 2, "price": 2200},
	"beadlock": {"n": ["Beadlock off-road", "أوف رود مثبّت"], "r": 1, "price": 1200},
	"classic": {"n": ["Classic muscle", "كلاسيك ماسل"], "r": 1, "price": 1000},
	"centre": {"n": ["Centre-lock race", "سباق قفل مركزي"], "r": 3, "price": 3500},
}
const WHEEL_ORDER := ["stock", "steel", "spoke5", "mesh", "multi", "turbine", "beadlock", "classic", "centre"]


static func tech(car_id: String) -> Dictionary:
	return CAR_TECH.get(car_id, CAR_TECH["hatch"])


## the real design a wheel id means on this car ("stock" = the car's own)
static func wheel_style(car_id: String, id: String) -> String:
	return str(tech(car_id)["stock_wheel"]) if id == "stock" or not WHEELS.has(id) else id


static func wheel_opts(car_id: String) -> Array:
	return tech(car_id)["wheels"]


static func part_tier_names(car_id: String, slot: String) -> Array:
	var t: Dictionary = tech(car_id)
	if t.has(slot):
		return t[slot]
	return []


static func has_part(car_id: String, slot: String) -> bool:
	return (tech(car_id)["slots"] as Array).has(slot)


const CAR_SLOTS := {"paint": PAINTS, "stripe": STRIPES, "rim": RIMS, "glow": GLOWS, "decal": DECALS,
	"spoiler": SPOILERS, "front": FRONTS, "hood": HOODS, "skirts": SKIRTS, "wheel": WHEELS}
const CAR_SLOT_ORDER := {"paint": PAINT_ORDER, "stripe": STRIPE_ORDER, "rim": RIM_ORDER, "glow": GLOW_ORDER, "decal": DECAL_ORDER,
	"spoiler": ["none", "lip", "duck", "gt", "twin"], "front": ["none", "splitter", "canards", "bullbar"], "hood": ["none", "scoop", "vents", "carbon"], "skirts": ["none", "skirts", "wide"], "wheel": WHEEL_ORDER}

# ---------------------------------------------------------------- character
const SKINS := {
	"s0": {"n": ["Light", "فاتح"], "r": 0, "price": 0, "c": Color(0.93, 0.84, 0.7)},
	"s1": {"n": ["Tan", "حنطي"], "r": 0, "price": 0, "c": Color(0.85, 0.68, 0.5)},
	"s2": {"n": ["Brown", "أسمر"], "r": 0, "price": 0, "c": Color(0.62, 0.43, 0.3)},
	"s3": {"n": ["Dark", "داكن"], "r": 0, "price": 0, "c": Color(0.4, 0.27, 0.2)},
	"s4": {"n": ["Mint", "نعناعي"], "r": 1, "price": 600, "c": Color(0.6, 0.9, 0.75)},
	"s5": {"n": ["Robot", "روبوت"], "r": 2, "price": 2000, "c": Color(0.62, 0.68, 0.76)},
}
const SHIRTS := {
	"team": {"n": ["Team tee", "تيشيرت الفريق"], "r": 0, "price": 0, "c": Color.TRANSPARENT},
	"white": {"n": ["White tee", "تيشيرت أبيض"], "r": 0, "price": 150, "c": Color(0.94, 0.94, 0.96)},
	"black": {"n": ["Black tee", "تيشيرت أسود"], "r": 0, "price": 150, "c": Color(0.1, 0.1, 0.12)},
	"orange": {"n": ["Orange tee", "تيشيرت برتقالي"], "r": 0, "price": 150, "c": Color(1.0, 0.5, 0.1)},
	"green": {"n": ["Green tee", "تيشيرت أخضر"], "r": 0, "price": 150, "c": Color(0.15, 0.6, 0.3)},
	"stripe": {"n": ["Striped tee", "تيشيرت مخطط"], "r": 1, "price": 600, "c": Color(0.15, 0.3, 0.8), "stripe": Color.WHITE},
	"jacket": {"n": ["Racing jacket", "جاكيت سباق"], "r": 2, "price": 1500, "c": Color(0.75, 0.08, 0.1), "stripe": Color.WHITE, "sleeve": true},
	"hoodie": {"n": ["Night hoodie", "هودي ليلي"], "r": 2, "price": 1700, "c": Color(0.2, 0.2, 0.3), "stripe": Color(0.3, 0.9, 1.0), "sleeve": true},
	"gold": {"n": ["Champion suit", "بدلة البطل"], "r": 3, "price": 0, "gem": 200, "c": Color(1.0, 0.75, 0.15), "stripe": Color(0.15, 0.1, 0.0), "sleeve": true},
}
const PANTS := {
	"navy": {"n": ["Navy pants", "سروال كحلي"], "r": 0, "price": 0, "c": Color(0.12, 0.15, 0.3)},
	"black": {"n": ["Black pants", "سروال أسود"], "r": 0, "price": 150, "c": Color(0.07, 0.07, 0.09)},
	"jeans": {"n": ["Blue jeans", "جينز أزرق"], "r": 0, "price": 200, "c": Color(0.2, 0.35, 0.65)},
	"khaki": {"n": ["Khaki pants", "سروال كاكي"], "r": 0, "price": 200, "c": Color(0.66, 0.58, 0.4)},
	"red": {"n": ["Red pants", "سروال أحمر"], "r": 1, "price": 600, "c": Color(0.8, 0.12, 0.15)},
	"camo": {"n": ["Camo pants", "سروال تمويه"], "r": 2, "price": 1400, "c": Color(0.28, 0.38, 0.2), "stripe": Color(0.15, 0.2, 0.1)},
	"gold": {"n": ["Gold pants", "سروال ذهبي"], "r": 3, "price": 0, "gem": 150, "c": Color(1.0, 0.75, 0.15)},
}
const SHOES := {
	"white": {"n": ["White sneakers", "حذاء أبيض"], "r": 0, "price": 0, "c": Color(0.95, 0.95, 0.97)},
	"black": {"n": ["Black boots", "حذاء أسود"], "r": 0, "price": 150, "c": Color(0.06, 0.06, 0.07)},
	"red": {"n": ["Red kicks", "حذاء أحمر"], "r": 0, "price": 250, "c": Color(0.9, 0.1, 0.12)},
	"neon": {"n": ["Neon runners", "حذاء نيون"], "r": 1, "price": 800, "c": Color(0.3, 1.0, 0.4)},
	"gold": {"n": ["Gold shoes", "حذاء ذهبي"], "r": 3, "price": 0, "gem": 100, "c": Color(1.0, 0.78, 0.2)},
}
const HATS := {
	"helmet": {"n": ["Team helmet", "خوذة الفريق"], "r": 0, "price": 0},
	"cap": {"n": ["Racing cap", "قبعة سباق"], "r": 0, "price": 200},
	"beanie": {"n": ["Beanie", "طاقية صوف"], "r": 0, "price": 200},
	"headset": {"n": ["Radio headset", "سماعة راديو"], "r": 0, "price": 300},
	"bandana": {"n": ["Bandana", "بندانا"], "r": 1, "price": 600},
	"cowboy": {"n": ["Cowboy hat", "قبعة رعاة"], "r": 1, "price": 900},
	"tophat": {"n": ["Top hat", "قبعة رسمية"], "r": 2, "price": 2200},
	"crown": {"n": ["Golden crown", "تاج ذهبي"], "r": 3, "price": 0, "gem": 250},
}
const GLASSES := {
	"none": {"n": ["No glasses", "بدون نظارة"], "r": 0, "price": 0},
	"round": {"n": ["Round glasses", "نظارة مدورة"], "r": 0, "price": 200},
	"sun": {"n": ["Sunglasses", "نظارة شمسية"], "r": 1, "price": 700},
	"goggles": {"n": ["Racing goggles", "نظارة سباق"], "r": 1, "price": 900},
	"star": {"n": ["Star shades", "نظارة نجمة"], "r": 2, "price": 2000},
	"visor": {"n": ["Neon visor", "قناع نيون"], "r": 3, "price": 0, "gem": 140},
}
const OUTFIT_SLOTS := {"skin": SKINS, "shirt": SHIRTS, "pants": PANTS, "shoes": SHOES, "hat": HATS, "glasses": GLASSES}
const OUTFIT_ORDER := ["skin", "hat", "glasses", "shirt", "pants", "shoes"]
const SLOT_NAME := {
	"paint": ["Paint", "الطلاء"], "stripe": ["Stripes", "الخطوط"], "rim": ["Rims", "الجنوط"], "glow": ["Underglow", "إضاءة سفلية"], "decal": ["Stickers", "ملصقات"], "spoiler": ["Rear", "المؤخرة"], "front": ["Front", "المقدمة"], "hood": ["Hood", "الغطاء"], "skirts": ["Sides", "الجوانب"], "wheel": ["Wheel design", "تصميم الجنط"],
	"skin": ["Skin", "البشرة"], "hat": ["Hat", "القبعة"], "glasses": ["Glasses", "النظارة"], "shirt": ["T-shirt", "التيشيرت"],
	"pants": ["Pants", "السروال"], "shoes": ["Shoes", "الحذاء"], "emote": ["Emote", "الحركة"],
}
const DEFAULT_OUTFIT := {"skin": "s0", "hat": "helmet", "glasses": "none", "shirt": "team", "pants": "navy", "shoes": "white", "emote": "wave"}

const EMOTES := {
	"wave": {"n": ["Wave", "تحية"], "r": 0, "price": 0},
	"thumbs": {"n": ["Thumbs up", "ممتاز"], "r": 0, "price": 300},
	"salute": {"n": ["Salute", "تحية عسكرية"], "r": 1, "price": 900},
	"flex": {"n": ["Muscle flex", "عضلات"], "r": 2, "price": 2000},
	"dance": {"n": ["Victory dance", "رقصة الفوز"], "r": 2, "price": 2600},
	"spin": {"n": ["Legendary spin", "الدوران الأسطوري"], "r": 3, "price": 0, "gem": 200},
	"hover": {"n": ["Legendary hover", "التحليق الأسطوري"], "r": 3, "price": 0, "gem": 260},
}
const EMOTE_ORDER := ["wave", "thumbs", "salute", "flex", "dance", "spin", "hover"]

# ---------------------------------------------------------------- upgrades (per car, level 0..5)
const UPGRADES := {
	"engine": {"n": ["Engine", "المحرك"], "d": ["More power and top speed", "قوة وسرعة أعلى"], "base": 400},
	"tires": {"n": ["Tires", "الإطارات"], "d": ["More grip on ice and curves", "ثبات أفضل على الجليد والمنعطفات"], "base": 300},
	"armor": {"n": ["Armor", "الدرع"], "d": ["Crashes hurt the engine less", "الحوادث تضر المحرك أقل"], "base": 450},
	"cooling": {"n": ["Cooling", "التبريد"], "d": ["Overheats later, fire burns slower", "حرارة أقل واشتعال أبطأ"], "base": 350},
	"extinguisher": {"n": ["Extinguisher", "الطفاية"], "d": ["Puts out fire faster", "تطفئ الحريق أسرع"], "base": 250},
}
const UPGRADE_ORDER := ["engine", "tires", "armor", "cooling", "extinguisher"]
const MAX_UP := 5

# ---- fitted parts: bought once, installed on one car at a time (stored as up["fit_<slot>"] = tier)
const PART_SLOTS := ["turbo", "exhaust", "aero", "susp", "kit"]
const PARTS := {
	"turbo": {"n": ["Turbo", "تيربو"], "d": ["More power", "قوة أكبر"], "stat": "power", "v": [0.06, 0.12, 0.20],
		"tiers": [["Stage 1 turbo", "تيربو مرحلة 1"], ["Twin-scroll turbo", "تيربو مزدوج"], ["Race turbo", "تيربو سباق"]], "price": [900, 2600, 6500]},
	"exhaust": {"n": ["Exhaust", "العادم"], "d": ["Higher top speed", "سرعة قصوى أعلى"], "stat": "top", "v": [0.03, 0.06, 0.10],
		"tiers": [["Sport exhaust", "عادم رياضي"], ["Race exhaust", "عادم سباق"], ["Titanium exhaust", "عادم تيتانيوم"]], "price": [700, 2000, 5200]},
	"aero": {"n": ["Aero kit", "طقم الايرو"], "d": ["More grip at speed", "ثبات أعلى بالسرعة"], "stat": "grip", "v": [0.04, 0.08, 0.13],
		"tiers": [["Front lip", "شفة أمامية"], ["Spoiler kit", "طقم سبويلر"], ["GT wing kit", "جناح GT كامل"]], "price": [800, 2300, 6000]},
	"susp": {"n": ["Suspension", "التعليق"], "d": ["Better handling off-road", "تحكم أفضل خارج الطريق"], "stat": "grip", "v": [0.05, 0.10, 0.16],
		"tiers": [["Sport springs", "سوست رياضي"], ["Rally coilovers", "مساعدات رالي"], ["Race coilovers", "مساعدات سباق"]], "price": [850, 2400, 6200]},
	"kit": {"n": ["Armor kit", "طقم الحماية"], "d": ["Crashes hurt less", "الاصطدام يضر أقل"], "stat": "armor", "v": [0.08, 0.16, 0.25],
		"tiers": [["Skid plate", "حماية سفلية"], ["Roll cage", "قفص أمان"], ["Full armor", "حماية كاملة"]], "price": [800, 2200, 5800]},
}


## multipliers from the fitted parts of a car's upgrade dict
static func fit_mods(up: Dictionary) -> Dictionary:
	var r := {"power": 1.0, "top": 1.0, "grip": 1.0, "armor": 1.0}
	for slot in PART_SLOTS:
		var t := int(up.get("fit_" + slot, 0))
		if t > 0:
			var p: Dictionary = PARTS[slot]
			var v: float = p["v"][t - 1]
			if p["stat"] == "armor":
				r["armor"] = float(r["armor"]) * (1.0 - v)
			else:
				r[p["stat"]] = float(r[p["stat"]]) * (1.0 + v)
	return r


static func upgrade_cost(key: String, lvl: int) -> int:
	return int(UPGRADES[key]["base"] * (lvl + 1) * (1.0 + lvl * 0.35))


static func xp_for(level: int) -> int:
	return 120 + (level - 1) * 80


## the loot a level-up gives
static func level_reward(level: int) -> Dictionary:
	var gems := 0
	var chest := 0
	if level % 5 == 0:
		chest = 1
		gems = 10
	return {"coins": 250 + level * 60, "gems": gems, "chest": chest}


# ---------------------------------------------------------------- quests
# ev = event name, n = amount; reward coins / xp
const QUEST_POOL := [
	{"id": "finish1", "ev": "finish", "n": 1, "coins": 250, "xp": 60, "t": ["Finish a race", "أنهِ سباقاً"]},
	{"id": "finish3", "ev": "finish", "n": 3, "coins": 700, "xp": 150, "t": ["Finish 3 races", "أنهِ 3 سباقات"]},
	{"id": "win1", "ev": "win", "n": 1, "coins": 500, "xp": 120, "t": ["Win a race", "افز بسباق"]},
	{"id": "gold1", "ev": "gold", "n": 1, "coins": 600, "xp": 130, "t": ["Earn a gold medal", "احصل على ميدالية ذهبية"]},
	{"id": "fire1", "ev": "fire_out", "n": 1, "coins": 450, "xp": 100, "t": ["Put out an engine fire", "أطفئ حريق محرك"]},
	{"id": "fire2", "ev": "fire_out", "n": 2, "coins": 800, "xp": 180, "t": ["Put out 2 engine fires", "أطفئ حريقين"]},
	{"id": "punch3", "ev": "punch", "n": 3, "coins": 200, "xp": 50, "t": ["Punch your mate 3 times (friendly!)", "اضرب صاحبك 3 مرات (مزح!)"]},
	{"id": "beacon2", "ev": "beacon", "n": 2, "coins": 250, "xp": 60, "t": ["Drop 2 beacons", "ضع إشارتين على الطريق"]},
	{"id": "speed140", "ev": "speed140", "n": 1, "coins": 350, "xp": 80, "t": ["Reach 140 km/h", "اوصل سرعة 140 كم/س"]},
	{"id": "mount1", "ev": "mountain", "n": 1, "coins": 550, "xp": 120, "t": ["Finish a mountain stage", "أنهِ مرحلة جبلية"]},
	{"id": "emote2", "ev": "emote", "n": 2, "coins": 150, "xp": 40, "t": ["Use your emote 2 times", "استعمل حركتك مرتين"]},
]

# chest loot: weight per rarity
const CHESTS := {
	"bronze": {"n": ["Bronze chest", "صندوق برونزي"], "w": [70, 25, 5, 0], "coins": 500, "c": Color(0.8, 0.5, 0.25)},
	"silver": {"n": ["Silver chest", "صندوق فضي"], "w": [40, 40, 17, 3], "gem": 25, "c": Color(0.78, 0.82, 0.9)},
	"gold": {"n": ["Gold chest", "صندوق ذهبي"], "w": [10, 40, 35, 15], "gem": 70, "c": Color(1.0, 0.78, 0.2)},
}


static func nm(entry: Dictionary) -> String:
	var a: Array = entry["n"]
	return a[1] if L.is_ar() else a[0]


static func rar_name(r: int) -> String:
	var a: Array = RARITY_NAME[r]
	return a[1] if L.is_ar() else a[0]


static func txt(a: Array) -> String:
	return a[1] if L.is_ar() else a[0]


## every cosmetic as {key, slot, id, entry}
static func all_items() -> Array:
	var out: Array = []
	for slot in CAR_SLOTS:
		for id in CAR_SLOTS[slot]:
			out.append({"slot": slot, "id": id, "e": CAR_SLOTS[slot][id]})
	for slot in OUTFIT_SLOTS:
		for id in OUTFIT_SLOTS[slot]:
			out.append({"slot": slot, "id": id, "e": OUTFIT_SLOTS[slot][id]})
	for id in EMOTES:
		out.append({"slot": "emote", "id": id, "e": EMOTES[id]})
	return out


static func entry(slot: String, id: String) -> Dictionary:
	if slot == "emote":
		return EMOTES.get(id, {})
	if CAR_SLOTS.has(slot):
		return CAR_SLOTS[slot].get(id, {})
	if OUTFIT_SLOTS.has(slot):
		return OUTFIT_SLOTS[slot].get(id, {})
	return {}
