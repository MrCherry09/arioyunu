extends Level
## LEVEL 1 - ORMAN. Melek gökten düşer, oyuncu onunla tanışır ve dağa doğru yola çıkar.
##
## Questler:
##   main    "The Fallen Light"        meleği bul, ormanı geç
##   child   "The Child in the Well"   (senaryo, son'u etkiler) ip bul + QTE ile çek
##   lamb    "The Runaway Lamb"        kaçan kuzuyu köşeye sıkıştır, çobana geri götür
##   bridge  "The Old Bridge"          kütüğü plakaya it, köprü insin (ilerlemek için gerekli)
##   stones  "Granny's Tales"          ormana gizlenmiş 3 hikâye taşını oku (meleğin geçmişine ipucu)

# =====================================================================
# Diyaloglar
# =====================================================================

const STONE_TEXTS := {
	"Stone1": [
		["STONE", "\"Long ago, the brightest star of the sky was kept by one of the Heavens' children.\""],
		["ANGEL", "..."],
	],
	"Stone2": [
		["STONE", "\"But the child would not share the star's light. 'It is mine,' it said, and hid it beneath its wings.\""],
		["ANGEL", "Who carves such nonsense into rocks?"],
	],
	"Stone3": [
		["STONE", "\"So the Heavens let the child fall. 'You may return,' they said, 'when you learn what light is for.'\""],
		["ANGEL", "(the angel turns away and says nothing)"],
	],
}

const FARMER_TREE := {
	"start": {
		"lines": [["FARMER", "Oh! A traveler. And... is that a glow behind you?"]],
		"ask": ["FARMER", "Sorry, my head's all over the place today."],
		"options": [
			{"text": "What happened?", "next": "news"},
			{"text": "Where does this road go?", "next": "road"},
			{"text": "Goodbye.", "next": "bye"},
		],
	},
	"news": {
		"lines": [
			["FARMER", "The shepherd's lamb bolted into the meadow, past the old tree."],
			["FARMER", "And the little one ran after it. Haven't seen the kid since. I hope nothing happened..."],
		],
		"next": "start",
	},
	"road": {
		"lines": [["FARMER", "East, through the forest, over the river, up to the foothills. The miller keeps the bridge."]],
		"next": "start",
	},
	"bye": {"lines": [["FARMER", "Mind the old well, it's deeper than it looks."]]},
}

const FARMER_TRACE := {
	"start": {"lines": [
		["FARMER", "Did you hear? They searched all night for the child who fell into the well."],
		["FARMER", "Someone must have walked right past... Well. Safe travels."],
		["ANGEL", "..."],
	]},
}

const CHILD_AT_EXIT := {
	"start": {
		"lines": [["CHILD", "You're going to the mountain? Wow!"]],
		"ask": ["CHILD", "Will you come back and tell me what's up there?"],
		"options": [
			{"text": "I promise.", "next": "yes"},
			{"text": "Maybe.", "next": "maybe"},
		],
	},
	"yes": {"lines": [["CHILD", "Bye! Bye, shiny one!"], ["ANGEL", "(the angel waves back, then pretends it didn't)"]]},
	"maybe": {"lines": [["CHILD", "Okay! Bye, shiny one!"]]},
}

const BIRD_TREE := {
	"start": {
		"lines": [["BIRD", "Tweet! Travelers! Going up the mountain? Tweet!"]],
		"ask": ["BIRD", "Want some advice? Tweet!"],
		"options": [
			{"text": "Yes, please.", "next": "tip"},
			{"text": "Why are you following us?", "next": "why"},
			{"text": "No thanks.", "next": "bye"},
		],
	},
	"tip": {"lines": [["BIRD", "The wind up there pushes you back. Keep your feet on the rock when it blows! Tweet!"]]},
	"why": {"lines": [["BIRD", "Following? I live everywhere! I just like shiny things. Tweet!"], ["ANGEL", "Shoo."]]},
	"bye": {"lines": [["BIRD", "Suit yourself! Tweet!"]]},
}

const MILLER_TREE := {
	"start": {
		"lines": [
			["MILLER", "Careful, the gorge wind will throw you right back. Nobody jumps this river."],
			["MILLER", "The bridge only comes down when the counterweight sits on the plate."],
		],
		"ask": ["MILLER", "My old back can't push that log anymore. Could you?"],
		"options": [
			{"text": "I'll do it.", "action": "accept_bridge", "next": "how"},
			{"text": "How does it work?", "next": "how"},
		],
	},
	"how": {"lines": [["MILLER", "Push the log onto the plate by the bank. The bump will keep it from rolling into the river."]]},
	"done": {"lines": [["MILLER", "There she goes! Good as new. Off you go, then."]]},
}


# =====================================================================
# Kurulum
# =====================================================================

var _stones_read := {}
var _lamb_done := false
var _bridge_crossed := false
var _met_angel := false
var _river_hint := false


func _setup() -> void:
	set_angel_following(false)
	add_to_group("puzzle")  # köprü plakasının kanalını dinle (on_channel)
	if not story().has("child"):
		story()["child"] = ""

	# Kuyu görseli (çocuk içinde, sadece başı görünür)
	var well := PixelArt.sprite(PixelArt.KUYU, PixelArt.KUYU_PAL)
	well.position = ent("Well").position
	get_node("Entities").add_child(well)
	var child_npc: Node2D = ent("Child")
	child_npc.z_index = -1
	well.z_index = 0

	for id in ["Granny", "Farmer", "Child", "Shepherd", "Miller", "Bird", "ChildAtExit", "FarmerAtExit"]:
		var n: Node = ent(id)
		n.tree_provider = _tree_for
		n.action.connect(_on_action)
	for id in STONE_TEXTS:
		ent(id).used.connect(_on_stone)
	ent("Lamb").caught.connect(_on_lamb_caught)
	ent("Pen").entered.connect(_on_pen)
	ent("RiverTalk").entered.connect(_on_river_near)
	_update_exit_npcs()


func _start() -> void:
	player.input_locked = true
	await _intro_fall()
	player.input_locked = false
	hud.show_title(level_title, level_subtitle)
	quests.start("main", "The Fallen Light", "Something fell from the sky. Go and see.")


## Açılış: gökten bir ışık düşer
func _intro_fall() -> void:
	var site: Vector2 = ent("CrashSite").position
	var lk := PixelArt.look("angel")
	var star := PixelArt.sprite(lk[0], lk[1])
	star.self_modulate = Color(2.0, 1.9, 1.5)
	star.position = site + Vector2(-500, -900)
	star.rotation = 0.6
	add_child(star)
	await get_tree().create_timer(0.6).timeout
	var tw := create_tween()
	tw.tween_property(star, "position", site, 1.1).set_ease(Tween.EASE_IN)
	await tw.finished
	_shake(10.0)
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.9)
	flash.size = get_viewport_rect().size
	var fl := CanvasLayer.new()
	fl.layer = 3
	add_child(fl)
	fl.add_child(flash)
	var tf := create_tween()
	tf.tween_property(flash, "color:a", 0.0, 0.8)
	tf.tween_callback(fl.queue_free)
	star.queue_free()
	# Düşen melek: yanına gidip konuşulacak NPC
	var fallen: Node2D = load("res://scripts/elements/npc.gd").new()
	fallen.npc_id = "fallen_angel"
	fallen.look = "angel"
	fallen.name = "FallenAngel"
	fallen.position = site
	get_node("Entities").add_child(fallen)
	fallen.tree_provider = _tree_for
	fallen.action.connect(_on_action)
	await get_tree().create_timer(0.6).timeout


func _shake(amount: float) -> void:
	var settings := get_node_or_null("/root/SettingsManager")
	if settings and not settings.get_setting("screenshake"):
		return
	var tw := cam.create_tween()
	for i in 6:
		var a := amount * (6 - i) / 6.0
		tw.tween_property(cam, "offset", Vector2(randf_range(-a, a), randf_range(-a, a)), 0.04)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.04)


# =====================================================================
# Diyalog ağaçları (duruma göre)
# =====================================================================

func _tree_for(npc: Node) -> Dictionary:
	match npc.npc_id:
		"fallen_angel":
			var t: Dictionary = StoryData.INTRO.duplicate(true)
			t["go"]["action"] = "joined"
			return t
		"granny":
			return _granny_tree()
		"farmer":
			return FARMER_TRACE if npc.name == "FarmerAtExit" else FARMER_TREE
		"child":
			if npc.name == "ChildAtExit":
				return CHILD_AT_EXIT
			var st: String = story()["child"]
			if st == "helped":
				return _child_after_rescue()
			return StoryData.tree_for("child", st, {"helped": 0, "items": player.items})
		"shepherd":
			return _shepherd_tree()
		"miller":
			return {"start": MILLER_TREE["done"]} if _bridge_crossed else MILLER_TREE
		"bird":
			return BIRD_TREE
	return {}


func _granny_tree() -> Dictionary:
	var t: Dictionary = StoryData.GRANNY.duplicate(true)
	var tales := {"text": "Do you know any old tales?", "next": "tales"}
	for k in ["menu", "more"]:
		t[k]["options"].insert(2, tales)
	var read := _stones_read.size()
	if read >= 3:
		t["tales"] = {"lines": [
			["GRANNY", "You read all three? Then you know the old story."],
			["GRANNY", "My grandmother said the fallen child is still out there, walking among us..."],
			["ANGEL", "(the angel looks away)"]], "next": "more"}
	else:
		t["tales"] = {"lines": [
			["GRANNY", "My grandmother carved her tales into three stones in these woods."],
			["GRANNY", "One sits up in the branches, one in the old tree's crown, and one... below the ground."],
			["GRANNY", "Find them and read them, dear. They're about the sky."]],
			"action": "start_stones", "next": "more"}
	return t


func _child_after_rescue() -> Dictionary:
	if _lamb_done:
		return {"start": {"lines": [["CHILD", "My lamb is home! You're the best!"]]}}
	return {"start": {"lines": [
		["CHILD", "Thank you again! But my lamb is still out there..."],
		["CHILD", "She ran into the meadow past the old tree. The shepherd is waiting there."]],
		"action": "hint_lamb"}}


func _shepherd_tree() -> Dictionary:
	if _lamb_done:
		return {"start": {"lines": [["SHEPHERD", "She's safe in the pen. Bless you, traveler."]]}}
	if quests.is_active("lamb"):
		return {"start": {"lines": [["SHEPHERD", "She's fast, but she can't jump the fences. Corner her against one!"]]}}
	return {
		"start": {
			"lines": [
				["SHEPHERD", "My lamb! She bolted into the meadow when the child fell in that well."],
				["SHEPHERD", "My knees are too old to chase her."],
			],
			"ask": ["SHEPHERD", "Could you catch her and bring her back to the pen?"],
			"options": [
				{"text": "I'll catch her.", "action": "accept_lamb", "next": "tip"},
				{"text": "Not now.", "next": ""},
			],
		},
		"tip": {"lines": [["SHEPHERD", "She runs from you, but she can't jump the fences. Corner her!"]]},
	}


# =====================================================================
# Eylemler
# =====================================================================

func _on_action(npc: Node, a: String) -> void:
	match a:
		"joined":
			_met_angel = true
			npc.queue_free()
			set_angel_following(true)
			quests.set_objective("main", "Head east through the forest, toward the mountain")
		"accept":   # çocuk: yardım
			_set_child("accepted")
			quests.start("child", "The Child in the Well", "")
			_update_child_objective()
		"skip":
			_set_child("skipped")
		"use_rope":
			qte.start("Pull the rope!", 3, _on_child_rescued.bind(npc))
		"start_stones":
			_start_stones()
		"accept_lamb":
			quests.start("lamb", "The Runaway Lamb", "Catch the lamb in the meadow (corner it against a fence)")
		"hint_lamb":
			if not quests.has("lamb"):
				quests.start("lamb", "The Runaway Lamb", "Find the shepherd in the meadow, past the old tree")
		"accept_bridge":
			_start_bridge()


func _set_child(st: String) -> void:
	story()["child"] = st
	ent("Child").state = st
	_update_exit_npcs()


func _update_child_objective() -> void:
	if not quests.is_active("child"):
		return
	if player.items.get("rope", 0) > 0:
		quests.set_objective("child", "Bring the rope to the well")
	else:
		quests.set_objective("child", "Find a rope (the old tree, further east)")


func _on_child_rescued(npc: Node) -> void:
	player.items.erase("rope")
	_set_child("helped")
	npc.position = ent("Well").position + Vector2(70, 0)
	npc.z_index = 0
	angel.add_accessory("crown", PixelArt.TAC, PixelArt.TAC_PAL, 3, 3)
	quests.complete("child")
	reward_orb(npc.position + Vector2(0, -90))
	await say(StoryData.CHILD_RESCUED)
	if not quests.has("lamb"):
		await say([["CHILD", "Oh no, my lamb! She ran into the meadow past the old tree... The shepherd is there."]])
		quests.start("lamb", "The Runaway Lamb", "Find the shepherd in the meadow, past the old tree")


func _process(_delta: float) -> void:
	if player == null:
		return
	_update_child_objective()
	# Köprüyü geçince
	if not _bridge_crossed and player.global_position.x > 175 * TILE:
		_bridge_crossed = true
		if not quests.has("bridge"):
			quests.start("bridge", "The Old Bridge", "")
		quests.complete("bridge")


# --- Hikâye taşları ---

func _start_stones() -> void:
	if not quests.has("stones"):
		quests.start("stones", "Granny's Tales", "Find and read the three story stones in the forest", 3)
		quests.set_progress("stones", _stones_read.size(), 3)
		if _stones_read.size() >= 3:
			quests.complete("stones")


func _on_stone(node: Node) -> void:
	_stones_read[node.name] = true
	await say(STONE_TEXTS[node.name])
	_start_stones()
	quests.set_progress("stones", _stones_read.size(), 3)
	if _stones_read.size() >= 3:
		quests.complete("stones")
		reward_orb(node.position + Vector2(0, -100), 25.0)


# --- Kuzu ---

func _on_lamb_caught(_lamb: Node) -> void:
	if not quests.has("lamb"):
		quests.start("lamb", "The Runaway Lamb", "")
	quests.set_objective("lamb", "Lead the lamb back to the shepherd's pen")
	hud.toast("The lamb is following you")


func _on_pen(body: Node2D) -> void:
	if _lamb_done or body != ent("Lamb") or body.mode != "follow":
		return
	_lamb_done = true
	var pen: Node2D = ent("Pen")
	body.stay_at(pen.position + Vector2(pen.size.x / 2.0, pen.size.y))
	quests.complete("lamb")
	reward_orb(ent("Shepherd").position + Vector2(0, -110))
	await say([["SHEPHERD", "There's my girl! Thank you, traveler. Take this, it fell from the sky last night."]])


# --- Köprü ---

func _on_river_near(body: Node2D) -> void:
	if not body is Player or _river_hint or _bridge_crossed:
		return
	_river_hint = true
	if not quests.has("bridge"):
		_start_bridge()
	if _met_angel:
		await say([["ANGEL", "The bridge is up, and this wind... Ask the old man with the flour on his hat."]])


func _start_bridge() -> void:
	if not quests.has("bridge"):
		quests.start("bridge", "The Old Bridge", "Push the log onto the plate to lower the bridge")


## Köprü plakası (group "puzzle" üzerinden)
func on_channel(ch: String, on: bool) -> void:
	if ch != "bridge" or _bridge_crossed:
		return
	if not quests.has("bridge"):
		_start_bridge()
	quests.set_objective("bridge", "Cross the bridge" if on else "Push the log onto the plate to lower the bridge")


func on_toggle(_ch: String) -> void:
	pass


# --- Çıkış ve izler ---

func _update_exit_npcs() -> void:
	var helped: bool = story().get("child", "") == "helped"
	ent("ChildAtExit").visible = helped
	ent("FarmerAtExit").visible = not helped


func _on_exit_reached() -> void:
	if not _met_angel:
		await say([["???", "(Something is still glowing back at the clearing. Better go and see.)"]])
		return
	complete()


func _before_complete() -> void:
	if story().get("child", "") in ["", "accepted"]:
		story()["child"] = "skipped"
	quests.complete("main")
