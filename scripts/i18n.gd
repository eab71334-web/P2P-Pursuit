# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
extends Node
## Tiny translation system (English / Arabic). Use L.t("key") everywhere. The choice is saved.

signal changed

var lang := "ar"
var tutorial_off := false

const T := {
	"z_emote": ["EMOTE", "حركة"],
	"boom_soon": ["%s: fire spreading - EXPLOSION coming!", "%s: الحريق ينتشر - انفجار قريب!"],
	"title": ["HAIRPIN RUSH", "هيربن راش"],
	"subtitle": ["Drive blind. Read the map. Trust your partner.", "سوق وأنت شبه أعمى. اقرأ الخريطة. ثق بصاحبك."],
	"name": ["YOUR NAME", "اسمك"],
	"solo": ["SOLO PRACTICE", "تدريب فردي"],
	"solo_d": ["Just you and the stage", "أنت والمرحلة فقط"],
	"coop": ["CO-OP", "تعاوني"],
	"coop_d": ["1 car · driver + co-driver", "سيارة واحدة · سائق + مساعد"],
	"teams": ["TEAM RACE", "سباق فرق"],
	"teams_d": ["2-4 teams · everybody drives his own car", "من 2 إلى 4 فرق · كل لاعب يسوق سيارته"],
	"teams_q": ["How many teams?", "كم عدد الفرق؟"],
	"per_team_q": ["Players in each team", "عدد اللاعبين في كل فريق"],
	"race_over": ["RACE OVER!", "انتهى السباق!"],
	"ends_in": ["Race ends in %d s", "السباق ينتهي بعد %d ث"],
	"team_wins": ["%s WINS!", "%s يفوز!"],
	"team_board": ["TEAM STANDINGS", "ترتيب الفرق"],
	"pts": ["pts", "نقطة"],
	"ffa": ["EVERYONE FOR HIMSELF", "كل واحد لنفسه"],
	"ffa_d": ["2-6 players · own car and own map", "من 2 إلى 6 لاعبين · سيارة وخريطة لكل لاعب"],
	"join": ["JOIN A GAME", "انضم للعبة"],
	"join_btn": ["JOIN", "دخول"],
	"games_found": ["Games on your Wi-Fi", "ألعاب على شبكتك"],
	"none_found": ["Searching for games...", "جاري البحث عن ألعاب..."],
	"ip_hint": ["or type host IP", "أو اكتب IP المضيف"],
	"blind": ["Blind driver mode", "وضع السائق الأعمى"],
	"blind_d": ["Driver sees almost nothing", "السائق ما يشوف تقريباً شي"],
	"players_n": ["%d players", "%d لاعبين"],
	"teams_n": ["%d teams", "%d فرق"],
	"choose": ["How many?", "كم العدد؟"],
	"start_host": ["CREATE GAME", "إنشاء اللعبة"],
	"back": ["BACK", "رجوع"],
	"lang_btn": ["العربية", "English"],
	"lobby": ["LOBBY", "غرفة الانتظار"],
	"waiting": ["Waiting for your friends", "بانتظار أصحابك"],
	"full": ["Everyone is here! Starting...", "الكل جاهز! تبدأ اللعبة..."],
	"tell_friends": ["Friends join with this address:", "الأصحاب يدخلون بهذا العنوان:"],
	"cancel": ["CANCEL", "إلغاء"],
	"empty_slot": ["waiting...", "بانتظار..."],
	"host_tag": ["host", "المضيف"],
	"team": ["Team", "فريق"],
	"role_driver": ["driver", "سائق"],
	"role_nav": ["map holder", "حامل الخريطة"],
	"role_solo": ["racer", "متسابق"],
	"err_host": ["Could not host (port busy?)", "تعذر إنشاء اللعبة (المنفذ مشغول؟)"],
	"err_ip": ["Enter the host IP first", "اكتب IP المضيف أولاً"],
	"connecting": ["Connecting...", "جاري الاتصال..."],
	"err_addr": ["Invalid address", "عنوان غير صحيح"],
	"err_conn": ["Could not connect", "تعذر الاتصال"],
	# --- HUD
	"DRIVER": ["DRIVER", "السائق"],
	"CODRIVER": ["CO-DRIVER", "المساعد"],
	"RACER": ["RACER", "متسابق"],
	"TEAMX": ["TEAM %s", "فريق %s"],
	"g0": ["", ""],
	"g1": ["<  CO-DRIVER SAYS: LEFT", "المساعد يقول: يسار  >"],
	"g2": ["^  CO-DRIVER SAYS: STRAIGHT", "المساعد يقول: مستقيم  ^"],
	"g3": ["CO-DRIVER SAYS: RIGHT  >", "<  المساعد يقول: يمين"],
	"g4": ["!!  STOP / WARNING  !!", "!!  قف / تحذير  !!"],
	"loading": ["Waiting for all players to load...", "بانتظار تحميل كل اللاعبين..."],
	"stage": ["STAGE: %s  (%s)", "المرحلة: %s  (%s)"],
	"th_snow": ["SNOW", "ثلج"],
	"th_autumn": ["AUTUMN", "خريف"],
	"th_mountain": ["MOUNTAIN", "جبل"],
	"go": ["GO!", "انطلق!"],
	"out": ["out", "خارج"],
	"racing": ["racing...", "يتسابق..."],
	"place1": ["1st", "الأول"],
	"place2": ["2nd", "الثاني"],
	"place3": ["3rd", "الثالث"],
	"place4": ["4th", "الرابع"],
	"place5": ["5th", "الخامس"],
	"place6": ["6th", "السادس"],
	"place7": ["7th", "السابع"],
	"place8": ["8th", "الثامن"],
	"back_road": ["%s: back on the road", "%s: رجع للطريق"],
	"racer_back": ["%s: back on the road", "%s: رجع للطريق"],
	"fell": ["%s FELL!  +5s", "%s طاح!  +5 ثواني"],
	"is_out": ["%s is out", "%s خرج من السباق"],
	"codriver_left": ["%s: the co-driver left", "%s: المساعد خرج"],
	"dead_end": ["DEAD END!  Reverse (S) or press RESET", "طريق مسدود!  ارجع للخلف أو اضغط RESET"],
	"driver_closed": ["THE DRIVER IS ON A CLOSED ROAD!", "السائق في طريق مسدود!"],
	"wrong_road": ["WRONG ROAD!  YOU ARE ON A CLOSED ROAD", "طريق خطأ! أنت في طريق مسدود"],
	"finish": ["FINISH!", "وصلت!"],
	"time": ["Time", "الوقت"],
	"medal": ["Medal", "الميدالية"],
	"no_medal": ["No medal", "بدون ميدالية"],
	"GOLD": ["GOLD", "ذهبية"],
	"SILVER": ["SILVER", "فضية"],
	"BRONZE": ["BRONZE", "برونزية"],
	"NOMEDAL": ["NO MEDAL", "بدون ميدالية"],
	"to_menu": ["Back to menu", "العودة للقائمة"],
	"z_reset": ["RESET (R)", "إعادة (R)"],
	"z_punch": ["PUNCH\n(F)", "ضربة\n(F)"],
	"z_left": ["< LEFT\n(1)", "يسار >\n(1)"],
	"z_fwd": ["^ GO\n(2)", "^ امش\n(2)"],
	"z_right": ["RIGHT >\n(3)", "< يمين\n(3)"],
	"z_stop": ["STOP!\n(4)", "قف!\n(4)"],
	"z_signal": ["SIGNAL\n(G)", "إشارة\n(G)"],
	"z_map": ["MAP\n(M)", "الخريطة\n(M)"],
	# --- tutorial
	"tut_skip": ["SKIP", "تخطي"],
	"tut_next": ["NEXT", "التالي"],
	"tut_go": ["START!", "ابدأ!"],
	"tut_never": ["Don't show again", "لا تظهر مرة أخرى"],
	"tut_wait": ["Waiting for the others...", "بانتظار الباقين..."],
	"tut_d1_t": ["YOU ARE THE DRIVER", "أنت السائق"],
	"tut_d1": ["You steer the car. In blind mode the world is almost black: you can only see the road dimly.", "أنت تسوق السيارة. في وضع الأعمى العالم أسود تقريباً وما تشوف إلا الطريق بشكل خافت."],
	"tut_d2_t": ["FOLLOW YOUR CO-DRIVER", "اتبع المساعد"],
	"tut_d2": ["Your partner sits on the right and holds the map. Watch his hand: it points where to go. Listen to his voice and look for the green light signal.", "صاحبك يجلس على اليمين ويمسك الخريطة. شوف يده: تشير وين تمشي. اسمع صوته وابحث عن عمود الضوء الأخضر."],
	"tut_d3_t": ["CONTROLS", "التحكم"],
	"tut_d3": ["A / D steer · W gas · S brake · R reset the car\nTouch: arrow buttons + GAS / BRAKE\nDrag the screen to look at your partner · PUNCH to hit him!", "A / D توجيه · W بنزين · S فرامل · R إعادة السيارة\nعلى الجوال: أزرار الأسهم + GAS / BRAKE\nاسحب الشاشة لتشوف صاحبك · زر الضرب لتضربه!"],
	"tut_n1_t": ["YOU ARE THE CO-DRIVER", "أنت المساعد"],
	"tut_n1": ["Your partner is driving almost blind. You hold an iPad with the map: look DOWN to read it (press M or MAP to zoom).", "صاحبك يسوق وهو شبه أعمى. معك أيباد فيه الخريطة: انظر للأسفل لتقرأها (اضغط M أو MAP للتقريب)."],
	"tut_n2_t": ["GUIDE HIM", "وجّهه"],
	"tut_n2": ["Point with your right hand: 1 left · 2 straight · 3 right · 4 stop. Press the same button again to lower your hand. SIGNAL (G) drops a green light on the correct road.", "أشر بيدك اليمنى: 1 يسار · 2 مستقيم · 3 يمين · 4 قف. اضغط نفس الزر ليرجع اليد. زر الإشارة (G) يضع عمود ضوء على الطريق الصحيح."],
	"tut_n3_t": ["BEWARE OF DANGER", "احذر الأخطار"],
	"tut_n3": ["Red roads on the map are CLOSED. Orange = cliff edge (a fall costs +5 s), blue = ice, triangle = rockfall. Warn the driver with your hand and voice!", "الطرق الحمراء في الخريطة مسدودة. البرتقالي حافة جبل (السقوط +5 ثواني)، الأزرق جليد، المثلث انهيار صخور. حذّر السائق بيدك وصوتك!"],
	"tut_s1_t": ["WELCOME TO THE RALLY", "أهلاً في الرالي"],
	"tut_s1": ["Reach the finish line as fast as you can. Gold, Silver or Bronze medal depends on your time.", "وصّل خط النهاية بأسرع وقت. الميدالية الذهبية أو الفضية أو البرونزية حسب وقتك."],
	"tut_s2_t": ["READ THE MAP", "اقرأ الخريطة"],
	"tut_s2": ["The map shows the route, the pace notes and the CLOSED roads (red). Press M to show or hide it. Falling off a cliff costs +5 s.", "الخريطة تعرض الطريق وملاحظات المنعطفات والطرق المسدودة (حمراء). اضغط M لإظهارها أو إخفائها. السقوط من الجبل +5 ثواني."],
	"tut_s3_t": ["CONTROLS", "التحكم"],
	"tut_s3": ["A / D steer · W gas · S brake · R reset the car\nTouch: arrow buttons + GAS / BRAKE", "A / D توجيه · W بنزين · S فرامل · R إعادة السيارة\nعلى الجوال: أزرار الأسهم + GAS / BRAKE"],
	"tut_s4_t": ["RACE YOUR FRIENDS", "تسابق مع أصحابك"],
	"tut_s4": ["Everyone has his own car and his own map. The first to cross the finish wins. Closed roads cost you time!", "كل واحد له سيارته وخريطته. أول واحد يعبر خط النهاية يفوز. الطرق المسدودة تضيع وقتك!"],
	# --- clipboard notes
	"n_fork": ["FORK: %s CLOSED", "تفرع: %s مسدود"],
	"n_left": ["LEFT", "يسار"],
	"n_right": ["RIGHT", "يمين"],
	"n_cliff": ["CLIFF EDGE  %dm", "حافة جبل  %dم"],
	"n_rockfall": ["ROCKFALL  ", "انهيار صخور  "],
	"n_finish": ["FINISH IN %dm", "النهاية بعد %dم"],
	"n_wrong": ["WRONG ROAD! WARN THE DRIVER", "طريق خطأ! حذّر السائق"],
	"n_flat": ["FLAT OUT", "بأقصى سرعة"],
	"n_crest": ["OVER CREST", "قمة"],
	"n_ice": ["ICE", "جليد"],
	"n_tunnel": ["TUNNEL", "نفق"],
	"n_Tunnel": ["TUNNEL", "نفق"],
	"n_rock": ["ROCK", "صخرة"],
	"n_log": ["LOG", "جذع"],
	"n_bump": ["BIG BUMP", "مطب كبير"],
	"n_Easy": ["EASY", "سهل"],
	"n_Chill": ["CHILL", "هادئ"],
	"n_Medium": ["MEDIUM", "متوسط"],
	"n_Hard": ["HARD", "صعب"],
	"n_Yikes": ["YIKES", "خطير"],
	"rp_smoke": ["ENGINE IS SMOKING!  Stop the car and pull the hood lever (E)", "المحرك يدخّن! أوقف السيارة وشدّ مقبض الكبوت (E)"],
	"rp_fire": ["ENGINE ON FIRE!  Stop and pull the hood lever (E)", "المحرك يحترق! أوقف السيارة وشدّ مقبض الكبوت (E)"],
	"rp_latched": ["Hood released. Get out of the car (E)", "انفتح قفل الكبوت. انزل من السيارة (E)"],
	"rp_lift": ["Lift the hood: swipe UP on the screen or press E", "ارفع الكبوت: اسحب الشاشة للأعلى أو اضغط E"],
	"rp_spray": ["Aim at the flames and HOLD the extinguisher (Q)", "صوّب على النار واضغط مطوّلاً على الطفاية (Q)"],
	"rp_cover": ["The fire hides under the engine cover: open it (E) with your other hand", "النار مختبئة تحت غطاء المحرك: افتحه بيدك الثانية (E)"],
	"rp_cool": ["Fire is out. Wait for the engine to cool...", "انطفت النار. انتظر حتى يبرد المحرك..."],
	"rp_enter": ["Close the hood and get back in (E)", "أغلق الكبوت وارجع للسيارة (E)"],
	"rp_wait": ["Your partner is fixing the engine...", "صاحبك يصلح المحرك..."],
	"z_lever": ["HOOD\nLEVER (E)", "مقبض\nالكبوت (E)"],
	"z_exit": ["GET OUT\n(E)", "انزل\n(E)"],
	"z_lift": ["LIFT\nHOOD (E)", "ارفع\nالكبوت (E)"],
	"z_cover": ["OPEN\nCOVER (E)", "افتح\nالغطاء (E)"],
	"z_enter": ["CLOSE &\nGET IN (E)", "أغلق وادخل\n(E)"],
	"z_spray": ["SPRAY\n(Q) hold", "رش\n(Q) اضغط"],
	"wreck": ["%s: ENGINE BLEW UP!  +25s", "%s: انفجر المحرك!  +25 ثانية"],
	"tut_f_t": ["ENGINE ON FIRE?", "المحرك يحترق؟"],
	"tut_f": ["Crashes or driving flat out make the engine smoke, then burn. Stop, pull the hood lever (E), get out, lift the hood, spray the extinguisher (Q), open the engine cover and put out the hidden fire. Don't take too long or the engine blows up!", "الاصطدام أو السرعة العالية يخلّون المحرك يدخّن ثم يحترق. أوقف السيارة، شدّ مقبض الكبوت (E)، انزل، ارفع الكبوت، استخدم الطفاية (Q)، افتح غطاء المحرك وأطفئ النار المخبّأة. لا تتأخر وإلا ينفجر المحرك!"],
	"n_Oh no": ["OH NO", "خطير جداً"],
}


func _ready() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		lang = cf.get_value("ui", "lang", "ar")
		tutorial_off = cf.get_value("ui", "tutorial_off", false)
	else:
		lang = "ar"
	_apply_font()


func _apply_font() -> void:
	var f := load("res://fonts/DejaVuSans.ttf") as Font
	if f:
		ThemeDB.get_default_theme().default_font = f
		ThemeDB.fallback_font = f


func is_ar() -> bool:
	return lang == "ar"


func t(key: String) -> String:
	var e: Array = T.get(key, [key, key])
	return e[1] if lang == "ar" else e[0]


func set_lang(l: String) -> void:
	lang = l
	_save()
	changed.emit()


func set_tutorial_off(v: bool) -> void:
	tutorial_off = v
	_save()


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("ui", "lang", lang)
	cf.set_value("ui", "tutorial_off", tutorial_off)
	cf.save("user://settings.cfg")
