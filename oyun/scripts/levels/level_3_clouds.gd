extends Level
## LEVEL 3 - BULUTLARIN ÜSTÜ. Yüzen adalar; altta yürünebilir bulut denizi (düşmek ölüm değil,
## yastıklar ve yukarı akımlar adalara geri taşır). Sonunda Cennet Kapısı.
## Kapıdan sonrası (Kapı Bekçisi, sonlar) henüz yok: kapıya varınca "To be continued".
##
## Questler:
##   main    "The Gate of Heaven"     kapıya ulaş
##   spirit  "Walk with the Spirit"   (senaryo, sonu etkiler) kayıp ruhu kapıya kadar götür
##   chicks  "Lost Chicks"            rüzgarın savurduğu 3 yavruyu yuvaya getir
##   lanterns "Lanterns of the Sky"   gök çanını çal, süre bitmeden 4 feneri yak

const SPIRIT_COMMIT_X := 199 * TILE   ## Bunun sağına ruhsuz geçilirse seçim kesinleşir
const LANTERN_TIME := 35.0
const SEA_ROW := 34                   ## Bu satırın altı bulut denizi

const BIRD_EXTRA := {
	"chicks": {
		"lines": [
			["BIRD", "Tweet... the wind took my three chicks! Blew them all over the clouds!"],
			["BIRD", "My nest is far ahead, past the steps of cloud. Bring them home? Tweet!"],
		],
		"action": "start_chicks",
		"next": "start",
	},
}

const NEST_THANKS := [
	["BIRD", "My babies! All three! Tweet tweet tweet!"],
	["BIRD", "Take this, it fell from the sky ages ago. Shiny things belong to angels. Tweet!"],
	["ANGEL", "...It's a feather of light. Mine, once."],
]

const BELL_IDLE := [["ANGEL", "Sky-lanterns. They only wake to the bell, and they don't stay awake for long."]]

const GATE_ARRIVAL := [
	["ANGEL", "There it is. The Gate."],
	["ANGEL", "(the angel's voice shakes, just slightly) Stay close to me now."],
]


var _chicks: Array[Node] = []    ## Peşimizdeki yavrular (takipçi)
var _delivered := 0
var _spirit_follower: Node2D
var _lantern_time := 0.0
var _lit := {}
var _at_gate := false


func _setup() -> void:
	set_angel_following(true)
	if not story().has("spirit"):
		story()["spirit"] = ""
	ent("Spirit").state = story()["spirit"]
	for id in ["Bird", "Spirit"]:
		var n: Node = ent(id)
		n.tree_provider = _tree_for
		n.action.connect(_on_action)
	for i in 3:
		ent("Chick%d" % (i + 1)).used.connect(_on_chick)
	ent("NestZone").entered.connect(_on_nest)
	ent("SkyBell").one_shot = false
	ent("SkyBell").used.connect(_on_bell)
	for i in 4:
		var l: Node = ent("Lantern%d" % (i + 1))
		l.used.connect(_on_lantern)
	ent("Gate").entered.connect(_on_gate)


func _start() -> void:
	super._start()
	quests.start("main", "The Gate of Heaven", "Cross the clouds and find the Gate")


# =====================================================================
# Diyaloglar
# =====================================================================

func _tree_for(npc: Node) -> Dictionary:
	match npc.name:
		"Bird":
			return _bird_tree()
		"Spirit":
			return StoryData.tree_for("spirit", story()["spirit"],
					{"helped": _helped_so_far(), "items": player.items})
	return {}


func _helped_so_far() -> int:
	var c := 0
	for k in ["child", "climber", "spirit"]:
		if story().get(k, "") == "helped":
			c += 1
	return c


func _bird_tree() -> Dictionary:
	if quests.state("chicks") == "done":
		return {"start": {"lines": [["BIRD", "Home, all of us! The Gate is that way. Tweet!"]]}}
	var t: Dictionary = StoryData.BIRD.duplicate(true)
	t.merge(BIRD_EXTRA.duplicate(true))
	if quests.has("chicks"):
		t["chicks"] = {"lines": [["BIRD", "%d of three home. Keep looking! Tweet!" % _delivered]], "next": "start"}
	t["start"]["options"].insert(0, {"text": "You look worried.", "next": "chicks"})
	return t


# =====================================================================
# Eylemler
# =====================================================================

func _on_action(npc: Node, a: String) -> void:
	match a:
		"accept":
			_set_spirit("accepted")
			quests.start("spirit", "Walk with the Spirit", "Lead the spirit to the Gate")
			_spawn_spirit_follower(npc)
		"skip":
			_set_spirit("skipped")
		"start_chicks":
			_start_chicks()


func _set_spirit(st: String) -> void:
	story()["spirit"] = st
	ent("Spirit").state = st


func _spawn_spirit_follower(npc: Node) -> void:
	if _spirit_follower:
		return
	_spirit_follower = load("res://scripts/follower.gd").new()
	var lk := PixelArt.look("spirit")
	_spirit_follower.template = lk[0]
	_spirit_follower.palette = lk[1]
	_spirit_follower.player = player
	_spirit_follower.offset = Vector2(-110, -40)
	_spirit_follower.global_position = npc.global_position
	add_child(_spirit_follower)
	npc.hide()
	npc.process_mode = Node.PROCESS_MODE_DISABLED


# --- Yavrular ---

func _start_chicks() -> void:
	if not quests.has("chicks"):
		quests.start("chicks", "Lost Chicks", "Find the bird's 3 chicks and bring them to the nest", 3)
		_update_chicks()


func _on_chick(node: Node) -> void:
	_start_chicks()
	node.hide()
	var f: Node2D = load("res://scripts/follower.gd").new()
	var lk := PixelArt.look("chick")
	f.template = lk[0]
	f.palette = lk[1]
	f.player = player
	f.offset = Vector2(-50 - 26 * _chicks.size(), -10 - 8 * _chicks.size())
	f.global_position = node.global_position
	add_child(f)
	_chicks.append(f)
	hud.toast("A chick hops along behind you")
	_update_chicks()


func _on_nest(body: Node2D) -> void:
	if not body is Player or _chicks.is_empty():
		return
	for f in _chicks:
		var nest_pos: Vector2 = ent("Nest").global_position + Vector2(randf_range(-20, 20), -20)
		f.player = null
		var tw := f.create_tween()
		tw.tween_property(f, "global_position", nest_pos, 0.6).set_trans(Tween.TRANS_SINE)
	_delivered += _chicks.size()
	_chicks.clear()
	# Anne kuş yuvasına uçar
	var bird: Node2D = ent("Bird")
	bird.global_position = ent("Nest").global_position + Vector2(70, 0)
	_update_chicks()
	if _delivered >= 3:
		quests.complete("chicks")
		reward_orb(ent("Nest").global_position + Vector2(0, -120), 25.0)
		say(NEST_THANKS)
	else:
		hud.toast("Chicks home: %d / 3" % _delivered)


func _update_chicks() -> void:
	if not quests.is_active("chicks"):
		return
	quests.set_progress("chicks", _delivered, 3)
	quests.set_objective("chicks", "Bring the chicks to the nest" if not _chicks.is_empty()
			else "Find the bird's 3 chicks and bring them to the nest")


# --- Fenerler ---

func _on_bell(_n: Node) -> void:
	if quests.state("lanterns") == "done":
		hud.toast("The lanterns are already burning")
		return
	if not quests.has("lanterns"):
		quests.start("lanterns", "Lanterns of the Sky", "Light the 4 lanterns before the bell fades", 4)
	_reset_lanterns()
	_lantern_time = LANTERN_TIME
	quests.set_objective("lanterns", "Light the 4 lanterns before the bell fades")
	hud.toast("The bell rings. The lanterns stir!")


func _on_lantern(node: Node) -> void:
	if _lantern_time <= 0.0:
		node.reset_state()  # çan çalmadan yanmaz
		if not dialogue.active:
			say(BELL_IDLE)
		return
	node.set_look("lantern_on")
	_lit[node.name] = true
	quests.set_progress("lanterns", _lit.size(), 4)
	if _lit.size() >= 4:
		_lantern_time = 0.0
		hud.set_timer(0.0)
		quests.set_objective("lanterns", "The sky-lanterns burn")
		quests.complete("lanterns")
		reward_orb(node.global_position + Vector2(0, -110), 25.0)


func _reset_lanterns() -> void:
	_lit.clear()
	for i in 4:
		var l: Node = ent("Lantern%d" % (i + 1))
		l.reset_state()
		l.set_look("lantern")
	if quests.is_active("lanterns"):
		quests.set_progress("lanterns", 0, 4)


# =====================================================================
# Akış
# =====================================================================

func _process(delta: float) -> void:
	if player == null or finished:
		return
	# Fener süresi
	if _lantern_time > 0.0:
		_lantern_time -= delta
		hud.set_timer(maxf(_lantern_time, 0.01))
		if _lantern_time <= 0.0:
			_lantern_time = 0.0
			hud.set_timer(0.0)
			_reset_lanterns()
			quests.set_objective("lanterns", "Ring the sky-bell to try again")
			hud.toast("The bell fades. The lanterns go dark.")
	# Ruh: yardım etmeden kapı adasına geçince kesinleşir
	if player.global_position.x > SPIRIT_COMMIT_X and story()["spirit"] == "":
		_set_spirit("skipped")
		if not dialogue.active:
			say(StoryData.LEFT_BEHIND["spirit"])


func _on_gate(body: Node2D) -> void:
	if not body is Player or _at_gate:
		return
	_at_gate = true
	player.input_locked = true
	if story()["spirit"] == "":
		_set_spirit("skipped")
	await say(GATE_ARRIVAL)
	if story()["spirit"] == "accepted" and _spirit_follower:
		_set_spirit("helped")
		quests.complete("spirit")
		_spirit_follower.ascend()
		await say(StoryData.SPIRIT_ASCENDS)
	quests.complete("main")
	finished = true
	# Kapıdan sonrası henüz yok
	hud.show_center("The Gate of Heaven\n\nTo be continued...")
	await get_tree().create_timer(4.0).timeout
	var flow := get_node_or_null("/root/GameFlow")
	if flow and is_inside_tree():
		flow.go_to_main_menu()
