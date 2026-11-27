extends Level
## LEVEL 2 - DAĞ. Aşağıdan yukarı tırmanış; zirvede ışıktan merdiven.
##
## Questler:
##   main     "The Stairway"          zirveye tırman
##   climber  "The Frozen Climber"    (senaryo, son'u etkiler) 3 odunu bul, ateşi yak
##   bells    "The Monk's Bells"      dağdaki 3 çanı çal; zirvedeki tapınak açılır
##   miner    "Trapped Below"         çatlak kayaları kırıp mahsur madenciyi kurtar

const CLIMBER_COMMIT_ROW := 56  ## Bu satırın üstüne çıkınca dağcıya yardım edilmediyse kesinleşir

const BELL_TOAST := "A bell rings out across the mountain"

const SHRINE_STONE := [
	["STONE", "\"The keeper of the star was not cast out for stealing it. It was cast out for keeping it.\""],
	["ANGEL", "...Keeping something is not a crime."],
	["ANGEL", "(quietly) Is it?"],
]

const MINER_TRAPPED := {
	"start": {
		"lines": [
			["MINER", "Hello? Is someone out there? A rockslide sealed me in!"],
			["MINER", "Those cracked rocks at the entrance... if you hit them hard enough, they'd give."],
		],
		"ask": ["MINER", "Can you break through?"],
		"options": [
			{"text": "Stand back.", "action": "start_miner", "next": "tip"},
			{"text": "How?", "next": "tip"},
		],
	},
	"tip": {"lines": [["MINER", "Run at them and dash! Shoulder first! That's how we do it in the mines."]],
			"action": "start_miner"},
}

const MINER_FREED := {
	"start": {"lines": [
		["MINER", "Free! Fresh air! I thought I'd be a fossil by spring."],
		["MINER", "Here, I found this glowing deep in the rock. Looks like it belongs to your friend."],
		["ANGEL", "(the angel takes the light without a word, then nods, once)"],
	], "action": "miner_thanks"},
}

const MINER_DONE := {"start": {"lines": [["MINER", "I'll take the long way down. Mind the wind on the ridge!"]]}}

const BIRD_TREE := {
	"start": {
		"lines": [["BIRD", "Tweet! You again! You climb well, for someone without wings. Tweet!"]],
		"ask": ["BIRD", "Want a tip? Tweet!"],
		"options": [
			{"text": "Sure.", "next": "tip"},
			{"text": "Not now.", "next": "bye"},
		],
	},
	"tip": {"lines": [
		["BIRD", "The last bell hangs far to the left. Jump, then dash in the air! Tweet!"],
		["BIRD", "And the summit is right above. Up, up, up! Tweet!"]]},
	"bye": {"lines": [["BIRD", "Suit yourself! Tweet!"]]},
}


var _bells := {}
var _miner_freed := false
var _miner_thanked := false
var _summit_reached := false
var _campfire: Sprite2D
var _fire_tween: Tween


func _setup() -> void:
	set_angel_following(true)
	if not story().has("climber"):
		story()["climber"] = ""
	ent("Climber").state = story()["climber"]
	for id in ["Monk", "MonkSummit", "Climber", "Miner", "Bird"]:
		var n: Node = ent(id)
		n.tree_provider = _tree_for
		n.action.connect(_on_action)
	for b in ["Bell1", "Bell2", "Bell3"]:
		ent(b).used.connect(_on_bell)
	ent("ShrineStone").used.connect(func(_n: Node) -> void: say(SHRINE_STONE))
	ent("MinerTalk").entered.connect(_on_miner_near)
	# Sönmüş kamp ateşi
	_campfire = PixelArt.sprite(PixelArt.ATES_SONUK, PixelArt.ATES_PAL)
	_campfire.position = ent("Campfire").position
	get_node("Entities").add_child(_campfire)
	if story()["climber"] == "helped":
		_light_campfire()


func _start() -> void:
	super._start()
	quests.start("main", "The Stairway", "Climb to the summit of the mountain")


# =====================================================================
# Diyaloglar
# =====================================================================

func _tree_for(npc: Node) -> Dictionary:
	match npc.name:
		"Monk":
			return _monk_tree()
		"MonkSummit":
			return _monk_summit_tree()
		"Climber":
			return StoryData.tree_for("climber", story()["climber"],
					{"helped": _helped_so_far(), "items": player.items})
		"Miner":
			if _miner_thanked:
				return MINER_DONE
			return MINER_FREED if _miner_freed else MINER_TRAPPED
		"Bird":
			return BIRD_TREE
	return {}


func _helped_so_far() -> int:
	var c := 0
	for k in ["child", "climber", "spirit"]:
		if story().get(k, "") == "helped":
			c += 1
	return c


func _monk_tree() -> Dictionary:
	var t: Dictionary = StoryData.MONK.duplicate(true)
	t["menu"]["options"].insert(2, {"text": "Can I help with anything?", "next": "bells"})
	if quests.has("bells"):
		t["bells"] = {"lines": [["MONK", "%d of three bells have rung. The shrine at the summit waits." % _bells.size()]],
				"next": "menu"}
	else:
		t["bells"] = {"lines": [
			["MONK", "Three bells hang on this mountain. My order rang them every dawn, long ago."],
			["MONK", "Ring all three, and the shrine at the summit will open its door."]],
			"action": "start_bells", "next": "menu"}
	return t


func _monk_summit_tree() -> Dictionary:
	var lines := [["MONK", "You made it. Few do."]]
	if _bells.size() >= 3:
		lines.append(["MONK", "And the bells woke the shrine. What was kept there was always meant for travelers."])
	else:
		lines.append(["MONK", "The shrine behind me opens only for those who wake the three bells."])
	lines.append(["MONK", "Beyond the Stairway is the Gate. It weighs hearts, not steps. Remember that."])
	lines.append(["ANGEL", "We know. Let's go."])
	return {"start": {"lines": lines}}


# =====================================================================
# Eylemler
# =====================================================================

func _on_action(npc: Node, a: String) -> void:
	match a:
		"accept":
			_set_climber("accepted")
			quests.start("climber", "The Frozen Climber", "Find 3 pieces of firewood on the mountain", 3)
		"skip":
			_set_climber("skipped")
		"light_fire":
			player.items["wood"] = 0
			_set_climber("helped")
			npc.shiver = false
			_light_campfire()
			angel.add_accessory("lantern", PixelArt.FENER, PixelArt.FENER_PAL, 10, 10)
			quests.complete("climber")
			reward_orb(npc.position + Vector2(0, -100))
		"start_bells":
			_start_bells()
		"start_miner":
			_start_miner()
		"miner_thanks":
			_miner_thanked = true
			quests.complete("miner")
			reward_orb(npc.position + Vector2(-60, -100), 25.0)


func _set_climber(st: String) -> void:
	story()["climber"] = st
	ent("Climber").state = st


func _light_campfire() -> void:
	var frames := [PixelArt.texture(PixelArt.ATES_1, PixelArt.ATES_PAL),
			PixelArt.texture(PixelArt.ATES_2, PixelArt.ATES_PAL)]
	_campfire.texture = frames[0]
	_campfire.self_modulate = Color(1.4, 1.4, 1.4)
	if _fire_tween:
		_fire_tween.kill()
	_fire_tween = _campfire.create_tween().set_loops()
	_fire_tween.tween_callback(func() -> void: _campfire.texture = frames[1])
	_fire_tween.tween_interval(0.18)
	_fire_tween.tween_callback(func() -> void: _campfire.texture = frames[0])
	_fire_tween.tween_interval(0.18)


# --- Çanlar ---

func _start_bells() -> void:
	if not quests.has("bells"):
		quests.start("bells", "The Monk's Bells", "Ring the three bells hidden on the mountain", 3)
		quests.set_progress("bells", _bells.size(), 3)
		_check_bells()


func _on_bell(node: Node) -> void:
	var id: String = node.name.to_lower()  # bell1, bell2, bell3 (kapının kanalları)
	_bells[id] = true
	get_tree().call_group("puzzle", "on_channel", id, true)
	hud.toast(BELL_TOAST)
	_start_bells()
	quests.set_progress("bells", _bells.size(), 3)
	_check_bells()


func _check_bells() -> void:
	if _bells.size() >= 3 and quests.is_active("bells"):
		quests.set_objective("bells", "The shrine at the summit is open")
		quests.complete("bells")


# --- Madenci ---

func _on_miner_near(body: Node2D) -> void:
	if body is Player and not quests.has("miner") and not _miner_freed:
		_start_miner()
		await say([["MINER", "(muffled, from behind the rocks) Help! Is anyone there?"]])


func _start_miner() -> void:
	if not quests.has("miner"):
		quests.start("miner", "Trapped Below", "Break the cracked rocks (dash into them)")


func _process(_delta: float) -> void:
	if player == null or finished:
		return
	# Madenci: bir kaya kırılınca üstündekiler de çöker (mağara açılır, sonra hep açık kalır)
	var any_broken := _miner_freed
	for i in 3:
		if ent("Rockfall%d" % i)._broken:
			any_broken = true
	if any_broken:
		for i in 3:
			ent("Rockfall%d" % i).smash()
		if not _miner_freed:
			_miner_freed = true
			_start_miner()
			quests.set_objective("miner", "Talk to the miner")
	# Odun sayısı
	if quests.is_active("climber"):
		var w: int = player.items.get("wood", 0)
		quests.set_progress("climber", w, 3)
		quests.set_objective("climber", "Bring the firewood to the climber's camp" if w >= 3
				else "Find 3 pieces of firewood on the mountain")
	# Kamptan yukarı çıkınca dağcıya yardım edilmediyse seçim kesinleşir
	var row := player.global_position.y / TILE
	if row < CLIMBER_COMMIT_ROW and story()["climber"] in ["", "accepted"]:
		_set_climber("skipped")
		if quests.is_active("climber"):
			quests.fail("climber")
		if not dialogue.active:
			say(StoryData.LEFT_BEHIND["climber"])
	if row < 13 and not _summit_reached:
		_summit_reached = true
		quests.set_objective("main", "Enter the Stairway of light")


## Yeniden doğunca bulmacalar sıfırlanır; çalınmış çanlar tapınak kapısını yeniden açsın
func _on_respawned() -> void:
	super._on_respawned()
	for id: String in _bells:
		get_tree().call_group("puzzle", "on_channel", id, true)


func _before_complete() -> void:
	if story().get("climber", "") in ["", "accepted"]:
		story()["climber"] = "skipped"
	quests.complete("main")
