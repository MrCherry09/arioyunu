extends Node2D
## Mekanik test odaları: her oda tek bir mekaniği dener.
## Odalar kodla kurulur (bkz. _define_rooms). Yeni oda eklemek için
## _define_rooms'a bir satır, altına bir _r_xxx fonksiyonu ekle.
##
## Q/E (PageUp/PageDown): önceki/sonraki oda, R: odayı sıfırla.
## Çıkış kapısına (yeşil) değince sonraki odaya geçilir.

const PLATFORM := preload("res://scenes/platform.tscn")
const Hazard := preload("res://scripts/elements/hazard.gd")
const JumpPad := preload("res://scripts/elements/jump_pad.gd")
const MovingPlatform := preload("res://scripts/elements/moving_platform.gd")
const CrumblePlatform := preload("res://scripts/elements/crumble_platform.gd")
const Breakable := preload("res://scripts/elements/breakable.gd")
const WindZone := preload("res://scripts/elements/wind_zone.gd")
const Enemy := preload("res://scripts/elements/enemy.gd")
const Collectible := preload("res://scripts/elements/collectible.gd")
const Checkpoint := preload("res://scripts/elements/checkpoint.gd")
const RoomExit := preload("res://scripts/elements/room_exit.gd")
const Crate := preload("res://scripts/elements/crate.gd")
const PressurePlate := preload("res://scripts/elements/pressure_plate.gd")
const Lever := preload("res://scripts/elements/lever.gd")
const Door := preload("res://scripts/elements/door.gd")
const KeyItem := preload("res://scripts/elements/key_item.gd")
const ToggleBlock := preload("res://scripts/elements/toggle_block.gd")
const Portal := preload("res://scripts/elements/portal.gd")
const LightOrb := preload("res://scripts/elements/light_orb.gd")
const Npc := preload("res://scripts/elements/npc.gd")
const Angel := preload("res://scripts/angel.gd")
const Pickup := preload("res://scripts/elements/pickup.gd")
const Follower := preload("res://scripts/follower.gd")
const PauseMenuScene := preload("res://scenes/ui/pause_menu.tscn")

const STRIDE := 2400.0     ## Odalar arası yatay mesafe (en geniş odadan büyük olmalı)
const FLOOR_Y := 640.0     ## Zeminin üst yüzeyi
const BOTTOM := 720.0      ## Odanın alt sınırı
const WALL := 40.0
const STAND_Y := FLOOR_Y - 25.0  ## Zemindeki doğma noktasının y'si

const C_WALL := Color(0.26, 0.29, 0.36)
const C_PLAT := Color(0.36, 0.42, 0.52)
const C_ONE_WAY := Color(0.55, 0.7, 0.85)
const C_ICE := Color(0.7, 0.9, 1.0)
const C_BELT := Color(0.45, 0.45, 0.3)
const C_RED := Color(0.9, 0.3, 0.35)
const C_BLUE := Color(0.3, 0.5, 0.95)
const C_WIRE := Color(0.5, 0.9, 0.6, 0.25)
const C_BG := Color(0.22, 0.27, 0.3)    ## Oda arka planı: koyu tile'lardan ayrışsın

## Odaların varsayılan tile stili (bkz. TileStyle). "" yaparsan her şey eskisi gibi düz renk olur.
## Sadece varsayılan renkli (C_PLAT, C_WALL) platformlara uygulanır; buz, bant, tek yönlü gibi
## rengiyle anlam taşıyanlar düz renkte kalır.
const ROOM_STYLE := "green_valley"
const FLOOR_DECOR := 0.2

static var _current := 0   ## R ile sahne yeniden yüklense de aynı odada kal

@onready var player: Player = $Player

var _rooms: Array[Dictionary] = []
var _room_nodes: Array[Node2D] = []
var _room_exits: Dictionary = {}       ## oda indeksi -> [RoomExit]
var _room_feathers_left: Dictionary = {}  ## oda indeksi -> kalan tüy
var _building := 0
var _changing := false
var _feathers_got := 0
var _feathers_total := 0

var _cam: Camera2D
var _title: Label
var _desc: Label
var _msg: Label
var _feather_label: Label
var _orb_label: Label
var _dialogue: DialogueBox
var _angel: Node2D
var _light_got := 0.0
var _light_total := 0.0
var _help: Label
var _pad_help := false

const HELP_KEYS := "A/D move · Space jump (hold: glide) · Shift dash · " \
		+ "S: slide / ground pound · S+Space: drop down · F talk/use · Q/E room · R reset"
const HELP_PAD := "Left stick move · A jump (hold: glide) · X/RT dash · " \
		+ "Down: slide / ground pound · Down+A: drop down · Y talk/use · LB/RB room · Select reset"


func _ready() -> void:
	GameInput.setup()
	_define_rooms()
	for i in _rooms.size():
		_building = i
		var r := Node2D.new()
		r.name = "Room%02d" % (i + 1)
		r.position = Vector2(i * STRIDE, 0)
		add_child(r)
		_build_shell(r, _rooms[i])
		(_rooms[i]["build"] as Callable).call(r)
		_mark_decor_skips(r)
		_room_nodes.append(r)

	_make_environment()
	player.z_index = 10
	_dialogue = DialogueBox.new()
	_dialogue.player = player
	add_child(_dialogue)
	_angel = Angel.new()
	_angel.player = player
	add_child(_angel)
	_qte = QTE.new()
	_qte.player = player
	add_child(_qte)
	player.respawned.connect(_on_player_respawned)
	_make_camera()
	_make_hud()
	_add_pause_menu()
	_go_to_room(clampi(_current, 0, _rooms.size() - 1))


func _input(event: InputEvent) -> void:
	# Yardım yazısı en son kullanılan cihaza göre değişsin (klavye / kol)
	if event is InputEventKey:
		_set_help(false)
	elif event is InputEventJoypadButton \
			or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		_set_help(true)


func _set_help(pad: bool) -> void:
	if _help and (pad != _pad_help or _help.text.is_empty()):
		_pad_help = pad
		_help.text = HELP_PAD if pad else HELP_KEYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("next_room"):
		_go_to_room((_current + 1) % _rooms.size())
	elif event.is_action_pressed("prev_room"):
		_go_to_room((_current - 1 + _rooms.size()) % _rooms.size())
	elif event.is_action_pressed("restart"):
		_go_to_room(_current)


# =====================================================================
# Oda listesi
# =====================================================================

func _define_rooms() -> void:
	_add("Walk & Jump",
		"A/D to walk, Space to jump. Tap for a short hop. "
		+ "You can still jump right after running off a ledge (coyote time).", _r_walk)
	_add("Double Jump",
		"Press Space again in mid-air. This wall is too tall for a single jump.", _r_double_jump)
	_add("Dash",
		"Shift (or K) for a quick dash. The low ceiling stops high jumps: "
		+ "jump, then dash in mid-air to cross the pit.", _r_dash)
	_add("Wall Slide & Wall Jump",
		"Hold toward a wall in mid-air to slide slowly (yellow). Press Space to kick off. "
		+ "Climb by bouncing between the two walls.", _r_wall, {"h": 1300})
	_add("Ground Pound & Breakable Blocks",
		"Press S in mid-air to slam down (red): it breaks cracked blocks. "
		+ "Dash through the cracked wall below.", _r_breakable,
		{"spawn": Vector2(120, 355)})
	_add("Glide",
		"Hold Space while falling to glide slowly (green). Glide across the pit.",
		_r_glide, {"spawn": Vector2(120, 175), "floor": [[1300, 1560]]})
	_add("Slide & Crawl",
		"Press S on the ground to slide (purple). Hold S to stay low and crawl; "
		+ "you can't stand up under a low ceiling.", _r_slide)
	_add("Jump Pads",
		"Pink pads launch you up and refresh your double jump and dash.", _r_jump_pad)
	_add("Moving Platforms",
		"Platforms carry you. Time your jumps.", _r_moving, {"floor": [[40, 300]]})
	_add("One-Way Platforms",
		"Jump up through the light blue platforms. "
		+ "Hold S and press Space to drop down. The exit is inside the closed room.", _r_one_way)
	_add("Crumbling Platforms",
		"They shake and fall when you step on them, then return after 2 seconds. Keep moving!",
		_r_crumble, {"floor": [[40, 260], [1360, 1560]]})
	_add("Ice",
		"Hard to speed up, hard to stop. Try stopping on the tiny ice island.", _r_ice, {"floor": []})
	_add("Conveyor Belts",
		"Belts carry you: the first pushes you back, the second pushes you forward.", _r_conveyor,
		{"floor": [[40, 300], [1000, 1560]]})
	_add("Wind & Updrafts",
		"Glide (hold Space) inside the updraft to rise. "
		+ "Up top, the wind pushes you back.", _r_wind, {"h": 1200})
	_add("Spikes & Checkpoints",
		"Don't touch the spikes. Touch a flag and you'll respawn there. "
		+ "Watch the ceiling spikes: no double jumps there!", _r_spikes, {"w": 1800})
	_add("Enemies",
		"Jump on red enemies to squash them (you bounce). Dash and ground pound kill them too. "
		+ "Touching them from the side kills you.", _r_enemies, {"w": 1800})
	_add("Collect the Feathers",
		"The door opens once every angel feather is collected. Each one needs a different skill.",
		_r_feathers, {"w": 1800})
	# --- Puzzles ---
	_add("Puzzle: Pushing Crates",
		"Walk into the crate to push it. The ledge is too high even for a double jump: use the crate as a step.",
		_r_p_crate)
	_add("Puzzle: Pressure Plate",
		"The door stays open only while something is on the plate. Who stays on it while you go through?",
		_r_p_plate)
	_add("Puzzle: Lever & Color Blocks",
		"Pull the lever with F (pad: Y): red and blue blocks swap. "
		+ "You can only stand on the solid color.", _r_p_toggle, {"floor": [[40, 400], [1200, 1560]]})
	_add("Puzzle: Key",
		"The yellow door needs a key. Grab it, it follows you; bring it to the door.", _r_p_key)
	_add("Puzzle: Timed Button",
		"After you step off the orange button, the door stays open for 3 seconds. Run and dash!",
		_r_p_timed, {"floor": [[40, 800], [950, 1560]]})
	_add("Puzzle: Portal",
		"Enter a purple portal, exit from its twin. The plate outside opens the door in the closed room.",
		_r_p_portal)
	_add("Puzzle: Crate Portal",
		"The orange portal only lets crates through. The plate is in the closed room: send the crate there.",
		_r_p_crate_portal)
	_add("Puzzle: All Together",
		"Both door lights must be green: one is wired to the plate, one to the lever. Then find the key for the yellow door.",
		_r_p_combo)
	_add("Light Orbs",
		"We heal the angel with these light orbs. Collect one: the light flies to the angel.", _r_orbs)
	_add("Story: The Journey",
		"Earth > Mountain > Clouds > the Gate. Talk to everyone with F (pad: Y). "
		+ "Some of them need help; helping is up to you. The ending depends on it.", _r_story,
		{"w": 2380, "floor": [], "intro": StoryData.INTRO})
	_add("Sandbox",
		"Everything in one place. Play around. (No exit; use Q/E to change rooms.)",
		_r_sandbox, {"w": 2200, "h": 1200})


func _add(title: String, desc: String, build: Callable, opts := {}) -> void:
	var w: float = opts.get("w", 1600.0)
	_rooms.append({
		"title": title,
		"desc": desc,
		"build": build,
		"w": w,
		"h": opts.get("h", 720.0),
		"spawn": opts.get("spawn", Vector2(120, STAND_Y)),
		"floor": opts.get("floor", [[WALL, w - WALL]]),
		"intro": opts.get("intro", []),
	})


# =====================================================================
# Odalar (koordinatlar oda içi; zemin üstü y=640, oda tabanı y=720)
# =====================================================================

func _r_walk(r: Node2D) -> void:
	_plat(r, 350, 540, 160, 24)
	_plat(r, 600, 440, 160, 24)
	_hide_floor_gap(r, 900, 1060)
	_sign(r, Vector2(80, 520), "A/D: walk\nSpace: jump")
	_sign(r, Vector2(860, 380), "You can still jump\nwhile falling off a ledge")
	_exit(r, 1480)


func _r_double_jump(r: Node2D) -> void:
	_plat(r, 700, 420, 120, 220, {"color": C_WALL})
	_sign(r, Vector2(400, 360), "Space again in mid-air")
	_plat(r, 1100, 430, 120, 210, {"color": C_WALL})
	_exit(r, 1480)


func _r_dash(r: Node2D) -> void:
	_hide_floor_gap(r, 620, 880)
	_plat(r, 560, WALL, 380, 500, {"color": C_WALL})  # alçak tavan (alt kenar y=540)
	_sign(r, Vector2(240, 480), "Jump + Shift")
	_exit(r, 1480)


func _r_wall(r: Node2D) -> void:
	# Soldaki duvarın altından geçilip iki duvar arasındaki bacaya girilir
	_plat(r, 500, -300, 40, 820, {"color": C_WALL})
	_plat(r, 760, -380, 40, 1020, {"color": C_WALL})
	_plat(r, 800, -380, 760, 30)
	_sign(r, Vector2(140, 520), "Hold toward the wall + Space")
	_exit(r, 1480, -380)


func _r_breakable(r: Node2D) -> void:
	_plat(r, WALL, 380, 640, 30)
	for i in 4:
		_breakable(r, 680 + i * 50, 380, 50, 30)
	_plat(r, 880, 380, 680, 30)
	# Alt katta dash ile kırılacak duvar
	for i in 5:
		_breakable(r, 1150, 410 + i * 46, 40, 46)
	_sign(r, Vector2(560, 290), "Above the cracks: jump + S")
	_sign(r, Vector2(900, 560), "Shift to smash the wall ->")
	_exit(r, 1450)


func _r_glide(r: Node2D) -> void:
	_plat(r, WALL, 200, 260, 30)
	_sign(r, Vector2(60, 100), "Hold Space while falling")
	_exit(r, 1480)


func _r_slide(r: Node2D) -> void:
	_plat(r, 450, WALL, 400, 564, {"color": C_WALL})   # tünel: alt kenar y=604 (36px boşluk)
	_plat(r, 1050, WALL, 350, 564, {"color": C_WALL})
	_sign(r, Vector2(150, 520), "S while walking (hold it)")
	_exit(r, 1480)


func _r_jump_pad(r: Node2D) -> void:
	_pad(r, 340, 760.0)
	_plat(r, 260, 300, 200, 24)
	_pad(r, 760, 1000.0)
	_plat(r, 1000, 240, 560, 30)
	_sign(r, Vector2(600, 540), "Step on it ->")
	_exit(r, 1480, 240)


func _r_moving(r: Node2D) -> void:
	_mover(r, 350, 560, 160, Vector2(350, 0), 2.2)
	_mover(r, 900, 500, 140, Vector2(0, -260), 2.0)
	_plat(r, 1120, 260, 440, 30)
	_exit(r, 1480, 260)


func _r_one_way(r: Node2D) -> void:
	_plat(r, 420, 530, 200, 16, {"one_way": true, "color": C_ONE_WAY})
	_plat(r, 660, 430, 200, 16, {"one_way": true, "color": C_ONE_WAY})
	_plat(r, 900, 330, 200, 16, {"one_way": true, "color": C_ONE_WAY})
	# Kapalı oda: tek giriş üstteki tek yönlü çatıdan aşağı inmek
	_plat(r, 1200, 316, 40, 324, {"color": C_WALL})
	_plat(r, 1200, 300, 360, 16, {"one_way": true, "color": C_ONE_WAY})
	_sign(r, Vector2(1260, 220), "S + Space to drop down")
	_exit(r, 1450)


func _r_crumble(r: Node2D) -> void:
	var ys := [560, 520, 560, 520, 560]
	for i in ys.size():
		_crumble(r, 320 + i * 200, ys[i], 120)
	_exit(r, 1480)


func _r_ice(r: Node2D) -> void:
	_plat(r, WALL, FLOOR_Y, 560, 80, {"friction_mult": 0.12, "color": C_ICE})
	_plat(r, 600, FLOOR_Y, 600, 80)
	_spikes(r, 600, FLOOR_Y - 24, 600)
	_plat(r, 840, 560, 100, 24, {"friction_mult": 0.12, "color": C_ICE})
	_plat(r, 1200, FLOOR_Y, 360, 80, {"friction_mult": 0.12, "color": C_ICE})
	_exit(r, 1480)


func _r_conveyor(r: Node2D) -> void:
	_plat(r, 300, FLOOR_Y, 700, 80, {"conveyor_speed": -220.0, "color": C_BELT})
	_sign(r, Vector2(560, FLOOR_Y + 20), "<<   <<   <<")
	_spikes(r, 1000, FLOOR_Y - 24, 360)
	_plat(r, 1100, 520, 200, 24, {"conveyor_speed": 300.0, "color": C_BELT})
	_sign(r, Vector2(1150, 490), ">>  >>")
	_exit(r, 1480)


func _r_wind(r: Node2D) -> void:
	_wind(r, 500, -420, 200, 1060, Vector2(0, -800))
	_plat(r, 700, -260, 860, 30)
	_wind(r, 900, -470, 400, 210, Vector2(-800, 0))   # karşı rüzgar: yürürken yavaşlatır, süzülürken geri iter
	_sign(r, Vector2(180, 500), "Enter the updraft, hold Space")
	_exit(r, 1480, -260)


func _r_spikes(r: Node2D) -> void:
	_spikes(r, 350, FLOOR_Y - 24, 150)
	_checkpoint(r, 600)
	_plat(r, 700, WALL, 300, 380, {"color": C_WALL})
	_spikes(r, 700, 420, 300, true)
	_spikes(r, 750, FLOOR_Y - 24, 200)
	_checkpoint(r, 1100)
	_spikes(r, 1250, FLOOR_Y - 24, 200)
	_plat(r, 1300, 520, 100, 20)
	_exit(r, 1700)


func _r_enemies(r: Node2D) -> void:
	_enemy(r, 350, 250, 90.0)
	_enemy(r, 800, 250, 140.0)
	_plat(r, 1100, 480, 200, 24)
	_enemy(r, 1250, 250, 200.0)
	_exit(r, 1700)


func _r_feathers(r: Node2D) -> void:
	_feather(r, Vector2(400, 390))          # çift zıplama
	_pad(r, 200, 1100.0)
	_feather(r, Vector2(240, 210))          # yastık
	_plat(r, 640, 330, 160, 20)
	_plat(r, 820, 120, 40, 400, {"color": C_WALL})
	_feather(r, Vector2(720, 300))          # duvar zıplaması
	_plat(r, 950, WALL, 250, 564, {"color": C_WALL})
	_feather(r, Vector2(1075, 620))         # kayma tüneli
	for i in 3:
		_breakable(r, 1300, 520 + i * 40, 40, 40)
	_plat(r, 1300, 500, 200, 20)
	_plat(r, 1460, 520, 40, 120, {"color": C_WALL})
	_feather(r, Vector2(1390, 615))         # dash ile kır
	_exit(r, 1700, FLOOR_Y, true)


func _r_p_crate(r: Node2D) -> void:
	_crate(r, 400)
	_plat(r, 1100, 380, 460, 30)                        # yerden 260px: çift zıplama 246px'e yetmez
	_plat(r, 1100, 410, 40, 230, {"color": C_WALL})    # kutu çıkıntının altına kaçmasın
	_sign(r, Vector2(300, 480), "Push the crate ->")
	_exit(r, 1480, 380)


func _r_p_plate(r: Node2D) -> void:
	_crate(r, 250)
	var plate := _plate(r, 550, _ch("a"))
	var door := _door(r, 1100, WALL, 40, 600, [_ch("a")])
	_wire(r, plate, door)
	_exit(r, 1480)


func _r_p_toggle(r: Node2D) -> void:
	_toggle(r, 400, 560, 300, 24, _ch("t"), true, C_RED)
	_plat(r, 700, 560, 80, 24)
	_lever(r, 740, 560, _ch("t"))
	_toggle(r, 780, 560, 420, 24, _ch("t"), false, C_BLUE)
	_toggle(r, 1320, WALL, 40, 600, _ch("t"), false, C_BLUE)
	_lever(r, 1285, FLOOR_Y, _ch("t"))  # mavi duvara yaslanınca erişilebilsin
	_exit(r, 1480)


func _r_p_key(r: Node2D) -> void:
	_pad(r, 480, 950.0)
	_plat(r, 600, 230, 160, 20)
	_key(r, Vector2(680, 210), "a")
	_door(r, 1200, WALL, 40, 600, [], "a")
	_exit(r, 1480)


func _r_p_timed(r: Node2D) -> void:
	var plate := _plate(r, 300, _ch("a"), 3.0)
	var door := _door(r, 1250, WALL, 40, 600, [_ch("a")])
	_wire(r, plate, door)
	_exit(r, 1480)


func _r_p_portal(r: Node2D) -> void:
	_crate(r, 500)
	var plate := _plate(r, 700, _ch("a"))
	_portals(r, Vector2(950, FLOOR_Y - 32), Vector2(1290, FLOOR_Y - 32))
	_plat(r, 1200, WALL, 40, 600, {"color": C_WALL})
	var door := _door(r, 1390, WALL, 40, 600, [_ch("a")])
	_wire(r, plate, door)
	_exit(r, 1500)


func _r_p_crate_portal(r: Node2D) -> void:
	_crate(r, 400)
	_portals(r, Vector2(700, FLOOR_Y - 32), Vector2(1300, 400), true)
	var door := _door(r, 950, WALL, 40, 600, [_ch("a")])
	_exit(r, 1100)
	_plat(r, 1200, WALL, 40, 600, {"color": C_WALL})
	var plate := _plate(r, 1260, _ch("a"))
	_wire(r, plate, door)


func _r_p_combo(r: Node2D) -> void:
	_crate(r, 300)
	var plate := _plate(r, 550, _ch("a"))
	_pad(r, 800, 950.0)
	_plat(r, 880, 220, 180, 20)
	var lever := _lever(r, 940, 220, _ch("b"))
	_key(r, Vector2(1020, 185), "k")
	var door := _door(r, 1250, WALL, 40, 600, [_ch("a"), _ch("b")])
	_wire(r, plate, door)
	_wire(r, lever, door)
	_door(r, 1400, WALL, 40, 600, [], "k")
	_exit(r, 1500)


func _r_orbs(r: Node2D) -> void:
	_orb(r, Vector2(300, 590))
	_orb(r, Vector2(450, 520))
	_orb(r, Vector2(600, 450))
	_plat(r, 700, 460, 200, 24)
	_orb(r, Vector2(800, 400))
	_orb(r, Vector2(800, 300), 25.0, Color(0.6, 0.85, 1.0))   # büyük, mavi: daha çok iyileştirir
	_pad(r, 1000, 900.0)
	_orb(r, Vector2(1040, 250))
	_orb(r, Vector2(1040, 150))
	_orb(r, Vector2(1300, 590), 10.0, Color(1.0, 0.6, 0.9))   # pembe


# =====================================================================
# Hikâye bölümü: Yeryüzü → Dağ → Bulutlar → Kapı. Diyaloglar: story_data.gd
# =====================================================================

const STORY_EARTH_END := 820.0      ## Bu x'i geçince yeryüzündeki seçim kesinleşir
const STORY_MOUNTAIN_END := 1600.0  ## Bu x'i geçince dağdaki seçim kesinleşir

var _story_room := -1
var _story_npcs := {}        ## id -> NPC (child, climber, spirit)
var _spirit_follower: Node2D
var _campfire: Sprite2D
var _fire_tween: Tween
var _fire_lit := false
var _ending_running := false
var _qte: QTE
var _help_label: Label


func _r_story(r: Node2D) -> void:
	_story_room = _building
	# Üç bölge: zemin ve arka plan rengiyle ayrılır
	_zone(r, WALL, STORY_EARTH_END, Color(0.27, 0.36, 0.38), "green_valley", 0.35)
	_zone(r, STORY_EARTH_END, STORY_MOUNTAIN_END, Color(0.17, 0.2, 0.3), "winter", 0.3)
	_zone_backdrop(r, STORY_EARTH_END, STORY_MOUNTAIN_END)
	_zone(r, STORY_MOUNTAIN_END, 2340, Color(0.24, 0.22, 0.4), "heaven", 0.3)
	_sign(r, Vector2(80, 300), "Part 1: Earth")
	_sign(r, Vector2(STORY_EARTH_END + 40, 300), "Part 2: The Mountain")
	_sign(r, Vector2(STORY_MOUNTAIN_END + 40, 300), "Part 3: The Clouds")

	# --- Yeryüzü: Nine, yaşlı ağaç (dalında ip), kuyu (içinde çocuk) ---
	_npc(r, 300, FLOOR_Y, "granny", PixelArt.NINE, PixelArt.NINE_PAL, StoryData.GRANNY)
	# Yaşlı ağaç: yosunlu gövde + Green Valley ağaç/çalı parçalarından taç
	_tile_visual(r, Rect2(540, 380, 24, 260), "green_valley")
	_decor_sprite(r, "green_valley", Rect2(352, 0, 32, 32), Vector2(552, 392))
	_decor_sprite(r, "green_valley", Rect2(224, 0, 32, 32), Vector2(495, 410))
	_decor_sprite(r, "green_valley", Rect2(384, 0, 32, 32), Vector2(610, 410))
	_plat(r, 440, 590, 40, 50, {"style": "green_valley"})                # kütük basamağı
	_plat(r, 480, 470, 150, 16, {"style": "green_valley"})               # dal
	_pickup(r, 590, 470, "rope", PixelArt.ROPE, PixelArt.ROPE_PAL)
	var well := PixelArt.sprite(PixelArt.KUYU, PixelArt.KUYU_PAL)
	well.position = Vector2(720, FLOOR_Y)
	r.add_child(well)
	var child := _npc(r, 720, FLOOR_Y + 12, "child", PixelArt.COCUK, PixelArt.COCUK_PAL, {})
	child.z_index = -1  # kuyunun ve zeminin arkasında: sadece başı görünür
	_story_npcs["child"] = child

	# --- Dağ: Keşiş, üşüyen dağcı + sönük ateş, aşağıya saçılmış 3 odun ---
	_npc(r, 900, FLOOR_Y, "monk", PixelArt.KESIS, PixelArt.KESIS_PAL, StoryData.MONK)
	_pickup(r, 1040, FLOOR_Y, "wood", PixelArt.ODUN, PixelArt.ODUN_PAL)
	_plat(r, 1120, 560, 120, 80, {"style": "winter"})                    # kaya
	_pickup(r, 1180, 560, "wood", PixelArt.ODUN, PixelArt.ODUN_PAL)
	_pickup(r, 1540, FLOOR_Y, "wood", PixelArt.ODUN, PixelArt.ODUN_PAL)
	var climber := _npc(r, 1340, FLOOR_Y, "climber", PixelArt.DAGCI, PixelArt.DAGCI_PAL, {})
	_story_npcs["climber"] = climber
	_campfire = PixelArt.sprite(PixelArt.ATES_SONUK, PixelArt.ATES_PAL)
	_campfire.position = Vector2(1400, FLOOR_Y)
	r.add_child(_campfire)

	# --- Bulutlar: kuş, kayıp ruh, Cennetin Kapısı ---
	_plat(r, 1700, 580, 24, 60, {"style": "heaven"})                     # kuşun direği
	_npc(r, 1712, 580, "bird", PixelArt.KUS, PixelArt.KUS_PAL, StoryData.BIRD, true)
	var spirit := _npc(r, 1960, FLOOR_Y - 20, "spirit", PixelArt.RUH, PixelArt.RUH_PAL, {})
	spirit.hop = true
	_story_npcs["spirit"] = spirit
	# Cennetin Kapısı: bulut sütunlar ve altın çimli kemer (sadece görsel)
	for x in [2196, 2298]:
		_tile_visual(r, Rect2(x, 380, 40, 260), "heaven")
	_tile_visual(r, Rect2(2180, 344, 172, 40), "heaven")
	_sign(r, Vector2(2160, 300), "The Gate of Heaven")
	_exit(r, 2262)

	for id in _story_npcs:
		var n: Node = _story_npcs[id]
		n.tree_provider = _story_tree
		n.action.connect(_on_story_action)
	_story_npcs["climber"].shiver = true


## Çarpışmasız, sadece görsel tile bloğu (ağaç gövdesi, kapı sütunu...)
func _tile_visual(r: Node2D, rect: Rect2, style: String) -> void:
	var n := Node2D.new()
	n.position = rect.position
	n.z_index = -5
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.draw.connect(func() -> void: TileStyle.draw_block(n, rect.size, style))
	r.add_child(n)
	n.queue_redraw()


## Stilin süs dokusundan tek bir parça; feet: alt orta noktası
func _decor_sprite(r: Node2D, style: String, region: Rect2, feet: Vector2) -> void:
	var st := TileStyle.resolve(style)
	if st == "":
		return
	var def: Dictionary = TileStyle.STYLES[st]
	var sp := Sprite2D.new()
	sp.texture = load(def["decor_tex"] if def["decor_tex"] != "" else def["tex"])
	sp.region_enabled = true
	sp.region_rect = region
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.scale = Vector2.ONE * TileStyle.SCALE
	sp.position = feet - Vector2(0, region.size.y * TileStyle.SCALE / 2.0)
	sp.z_index = -4
	r.add_child(sp)


## Bir hikâye bölgesi: arka plan rengi + o bölgenin tile stiliyle zemin (ve üstünde süsler)
func _zone(r: Node2D, x0: float, x1: float, bg: Color, style: String, decor: float) -> void:
	var b := ColorRect.new()
	b.position = Vector2(x0, WALL)
	b.size = Vector2(x1 - x0, FLOOR_Y - WALL)
	b.color = bg
	b.z_index = -9
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(b)
	_plat(r, x0, FLOOR_Y, x1 - x0, BOTTOM - FLOOR_Y, {"style": style, "decor": decor})


## Dağ bölgesinin arkasına Winter Tileset'in gökyüzü/dağ/orman katmanları (dosyalar yoksa atlanır)
func _zone_backdrop(r: Node2D, x0: float, x1: float) -> void:
	const BG_DIR := "res://assets/tilesets/winter/bg/"
	var scale := TileStyle.SCALE
	for layer: String in ["sky0", "mountains1", "forest2", "forest3"]:
		var path: String = BG_DIR + layer + ".png"
		if not ResourceLoader.exists(path):
			return
		var t := TextureRect.new()
		t.texture = load(path)
		t.stretch_mode = TextureRect.STRETCH_TILE
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.size = Vector2((x1 - x0) / scale, 180)
		t.scale = Vector2.ONE * scale
		t.position = Vector2(x0, FLOOR_Y - 180 * scale)  # alt kenar zemine otursun
		t.z_index = -8
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(t)


func _npc(r: Node2D, x: float, y: float, id: String, template: Array, palette: Dictionary,
		tree: Dictionary, hop := false) -> Node2D:
	var n := Npc.new()
	n.position = Vector2(x, y)
	n.npc_id = id
	n.template = template
	n.palette = palette
	n.tree = tree
	n.hop = hop
	r.add_child(n)
	return n


func _pickup(r: Node2D, x: float, y: float, id: String, template: Array, palette: Dictionary) -> void:
	var p := Pickup.new()
	p.position = Vector2(x, y)
	p.item_id = id
	p.template = template
	p.palette = palette
	r.add_child(p)


func _helped_count() -> int:
	var c := 0
	for id in _story_npcs:
		if _story_npcs[id].state == "helped":
			c += 1
	return c


func _story_tree(npc: Node) -> Dictionary:
	return StoryData.tree_for(npc.npc_id, npc.state, {"helped": _helped_count(), "items": player.items})


func _on_story_action(npc: Node, action_name: String) -> void:
	match action_name:
		"accept":
			npc.state = "accepted"
			if npc.npc_id == "spirit":
				npc.hide()
				_spirit_follower = Follower.new()
				_spirit_follower.player = player
				_spirit_follower.template = PixelArt.RUH
				_spirit_follower.palette = PixelArt.RUH_PAL
				add_child(_spirit_follower)
				_spirit_follower.global_position = npc.global_position + Vector2(0, -30)
		"skip":
			npc.state = "skipped"
		"use_rope":
			_qte.start("Pull the rope!", 3, _on_child_rescued.bind(npc))
		"light_fire":
			player.items["wood"] = 0
			npc.state = "helped"
			npc.shiver = false
			_light_campfire()
			_angel.add_accessory("lantern", PixelArt.FENER, PixelArt.FENER_PAL, 10, 10)
	_update_help_label()


func _on_child_rescued(npc: Node) -> void:
	player.items.erase("rope")
	npc.state = "helped"
	npc.position = Vector2(780, FLOOR_Y)   # kuyudan çıkıp yanına geçer
	npc.z_index = 0
	_angel.add_accessory("crown", PixelArt.TAC, PixelArt.TAC_PAL, 3, 3)
	_dialogue.play(StoryData.CHILD_RESCUED)
	_update_help_label()


func _light_campfire() -> void:
	_fire_lit = true
	var frames := [PixelArt.texture(PixelArt.ATES_1, PixelArt.ATES_PAL),
			PixelArt.texture(PixelArt.ATES_2, PixelArt.ATES_PAL)]
	_campfire.texture = frames[0]
	_campfire.self_modulate = Color(1.4, 1.4, 1.4)  # hafif bloom
	_fire_tween = _campfire.create_tween().set_loops()
	_fire_tween.tween_callback(func() -> void: _campfire.texture = frames[1])
	_fire_tween.tween_interval(0.18)
	_fire_tween.tween_callback(func() -> void: _campfire.texture = frames[0])
	_fire_tween.tween_interval(0.18)


## Hikâye odasında: bölgeyi yardım etmeden geçince seçim kesinleşir; ruh kapıya varınca yükselir
func _story_tick() -> void:
	if _current != _story_room or _story_room < 0 or _ending_running:
		return
	var x := player.global_position.x - _current * STRIDE
	_commit_if_passed("child", x, STORY_EARTH_END)
	_commit_if_passed("climber", x, STORY_MOUNTAIN_END)


func _commit_if_passed(id: String, x: float, limit: float) -> void:
	var npc: Node = _story_npcs[id]
	if x > limit and npc.state in ["", "accepted"]:
		npc.state = "skipped"
		_update_help_label()
		if not _dialogue.active:
			_dialogue.play(StoryData.LEFT_BEHIND[id])


func _update_help_label() -> void:
	if _help_label:
		_help_label.text = "Helped: %d/%d" % [_helped_count(), StoryData.HELP_TOTAL]
		_help_label.visible = _current == _story_room


## Kapıya varınca: ruh yanındaysa yükselir, sonra yardım sayısına göre son oynar
func _run_story_ending() -> void:
	_ending_running = true
	var spirit: Node = _story_npcs["spirit"]
	if spirit.state == "accepted" and is_instance_valid(_spirit_follower):
		spirit.state = "helped"
		_spirit_follower.ascend()
		_update_help_label()
		_dialogue.play(StoryData.SPIRIT_ASCENDS)
		await _dialogue.finished
	elif spirit.state == "":
		spirit.state = "skipped"
		_dialogue.play(StoryData.LEFT_BEHIND["spirit"])
		await _dialogue.finished
	await get_tree().create_timer(0.3).timeout
	var end := StoryData.ending(_helped_count())
	_dialogue.play(StoryData.GATE_OPENING + end[0])
	await _dialogue.finished
	_msg.text = "%s\n%s" % [end[1], end[2]]
	_msg.add_theme_font_size_override("font_size", 34)
	_msg.show()
	player.input_locked = true
	await get_tree().create_timer(4.0).timeout
	_msg.add_theme_font_size_override("font_size", 48)
	player.input_locked = false
	_ending_running = false
	if _current == _story_room:
		_go_to_room((_current + 1) % _rooms.size())


## Oda her açıldığında hikâyeyi baştan kur
func _reset_story() -> void:
	player.items.clear()
	get_tree().call_group("story_npcs", "reset")
	if _story_room >= 0:
		var child: Node2D = _story_npcs["child"]
		child.position = Vector2(720, FLOOR_Y + 12)
		child.z_index = -1
		_story_npcs["climber"].shiver = true
	if is_instance_valid(_spirit_follower):
		_spirit_follower.queue_free()
	_spirit_follower = null
	if _fire_tween:
		_fire_tween.kill()
		_fire_tween = null
	if _campfire:
		_campfire.texture = PixelArt.texture(PixelArt.ATES_SONUK, PixelArt.ATES_PAL)
		_campfire.self_modulate = Color.WHITE
	_fire_lit = false
	if _angel:
		_angel.remove_accessory("crown")
		_angel.remove_accessory("lantern")
	_ending_running = false
	_update_help_label()


func _r_sandbox(r: Node2D) -> void:
	_pad(r, 250, 900.0)
	_plat(r, 450, 200, 40, 440, {"color": C_WALL})
	_plat(r, 600, 100, 40, 440, {"color": C_WALL})
	_plat(r, 700, 500, 160, 16, {"one_way": true, "color": C_ONE_WAY})
	_plat(r, 700, 380, 160, 16, {"one_way": true, "color": C_ONE_WAY})
	_mover(r, 900, 300, 140, Vector2(300, 0), 2.5)
	_wind(r, 1400, -400, 160, 1040, Vector2(0, -800))
	_plat(r, 1560, -200, 400, 30)
	for i in 3:
		_crumble(r, 1600 + i * 130, 450, 100)
	for i in 4:
		_breakable(r, 1000 + i * 50, 590, 50, 50)
	_enemy(r, 1700, 300, 100.0)


# =====================================================================
# Kurulum yardımcıları
# =====================================================================

func _build_shell(r: Node2D, def: Dictionary) -> void:
	var w: float = def["w"]
	var h: float = def["h"]
	var top := BOTTOM - h
	var bg := ColorRect.new()
	bg.position = Vector2(0, top)
	bg.size = Vector2(w, h)
	bg.color = C_BG
	bg.z_index = -10
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(bg)
	_plat(r, 0, top, WALL, h, {"color": C_WALL, "fill_only": true})
	_plat(r, w - WALL, top, WALL, h, {"color": C_WALL, "fill_only": true})
	_plat(r, 0, top, w, WALL, {"color": C_WALL, "fill_only": true})
	for seg: Array in def["floor"]:
		_plat(r, seg[0], FLOOR_Y, seg[1] - seg[0], BOTTOM - FLOOR_Y, {"decor": FLOOR_DECOR})


## Zemindeki oyun nesnelerinin (plaka, yastık, diken, kapı, NPC, kutu...) çevresine süs konmasın.
## Süs sadece görsel; oyuncunun basacağı/bakacağı şeyi kapatmamalı.
func _mark_decor_skips(r: Node2D) -> void:
	const MARGIN := 50.0
	var floors := r.get_children().filter(func(c: Node) -> bool: return c.get("decor") != null and c.decor > 0.0)
	for f: Node2D in floors:
		var skips := []
		for c in r.get_children():
			if c == f or not (c is Area2D or c is CharacterBody2D or c is AnimatableBody2D \
					or c.get("channels") != null or c is StaticBody2D and c.get("decor") == null):
				continue
			# Bu zeminin üst yüzeyine yakın duran nesneler (üstünde 200 px'e kadar)
			var cy: float = c.position.y
			if cy < f.position.y - 200.0 or cy > f.position.y + 40.0:
				continue
			var w := 40.0
			if c.get("size") is Vector2:
				w = c.size.x
			var x0: float = c.position.x - f.position.x
			# Çoğu nesnenin orijini ortada; boyutlu olanlarınki sol üstte
			var left := x0 if c.get("size") is Vector2 else x0 - w / 2.0
			skips.append([left - MARGIN, left + w + MARGIN])
		f.decor_skip = skips


## Varsayılan tam zeminde bir çukur açmak yerine, zemini baştan bölmek daha basit;
## bu yardımcı tam zemini x0..x1 arasında keser.
func _hide_floor_gap(r: Node2D, x0: float, x1: float) -> void:
	for child in r.get_children():
		if child.get("size") is Vector2 and child.position.y == FLOOR_Y \
				and child.position.x <= x0 and child.position.x + child.size.x >= x1:
			var right_end: float = child.position.x + child.size.x
			child.size = Vector2(x0 - child.position.x, child.size.y)
			_plat(r, x1, FLOOR_Y, right_end - x1, BOTTOM - FLOOR_Y)
			return


func _plat(r: Node2D, x: float, y: float, w: float, h: float, extra := {}) -> Node:
	var p := PLATFORM.instantiate()
	p.position = Vector2(x, y)
	p.size = Vector2(w, h)
	p.color = C_PLAT
	for k: String in extra:
		p.set(k, extra[k])
	# Varsayılan renkli platformlar oda stiliyle tile'lanır (stil açıkça verilmediyse)
	if not extra.has("style") and p.color in [C_PLAT, C_WALL] and not p.one_way:
		p.style = ROOM_STYLE
	r.add_child(p)
	return p


func _spikes(r: Node2D, x: float, y: float, w: float, down := false) -> void:
	var s := Hazard.new()
	s.position = Vector2(x, y)
	s.size = Vector2(w, 24)
	s.pointing_down = down
	r.add_child(s)


func _pad(r: Node2D, x: float, strength: float, y := FLOOR_Y) -> void:
	var p := JumpPad.new()
	p.position = Vector2(x, y - 16)
	p.strength = strength
	r.add_child(p)


func _mover(r: Node2D, x: float, y: float, w: float, travel: Vector2, dur: float) -> void:
	var m := MovingPlatform.new()
	m.position = Vector2(x, y)
	m.size = Vector2(w, 24)
	m.travel = travel
	m.duration = dur
	r.add_child(m)


func _crumble(r: Node2D, x: float, y: float, w: float) -> void:
	var c := CrumblePlatform.new()
	c.position = Vector2(x, y)
	c.size = Vector2(w, 24)
	r.add_child(c)


func _breakable(r: Node2D, x: float, y: float, w: float, h: float) -> void:
	var b := Breakable.new()
	b.position = Vector2(x, y)
	b.size = Vector2(w, h)
	r.add_child(b)


func _wind(r: Node2D, x: float, y: float, w: float, h: float, force: Vector2) -> void:
	var z := WindZone.new()
	z.position = Vector2(x, y)
	z.size = Vector2(w, h)
	z.force = force
	r.add_child(z)


func _enemy(r: Node2D, x: float, patrol: float, spd: float, y := FLOOR_Y) -> void:
	var e := Enemy.new()
	e.position = Vector2(x, y)
	e.patrol = patrol
	e.speed = spd
	r.add_child(e)


func _feather(r: Node2D, pos: Vector2) -> void:
	var h := Collectible.new()
	h.position = pos
	r.add_child(h)
	var room := _building
	_room_feathers_left[room] = _room_feathers_left.get(room, 0) + 1
	_feathers_total += 1
	h.collected.connect(_on_feather_collected.bind(room))


func _orb(r: Node2D, pos: Vector2, heal := 10.0, color := Color(1.0, 0.85, 0.5)) -> void:
	var o := LightOrb.new()
	o.position = pos
	o.heal_amount = heal
	o.color = color
	o.radius = 14.0 if heal <= 10.0 else 20.0
	r.add_child(o)
	_light_total += heal
	o.collected.connect(_on_orb_collected)


func _on_orb_collected(amount: float) -> void:
	_light_got += amount
	_orb_label.text = "Light: %d/%d" % [_light_got, _light_total]


## 2D bloom: renk değeri 1'i aşan şeyler (ışık topları) parlar, diğerleri etkilenmez
func _make_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for i in 7:
		env.set_glow_level(i, i >= 1 and i <= 2)  # dar bloom: büyük parıltıyı piksel aura veriyor
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _checkpoint(r: Node2D, x: float, y := FLOOR_Y) -> void:
	var c := Checkpoint.new()
	c.position = Vector2(x, y)
	r.add_child(c)


func _exit(r: Node2D, x: float, y := FLOOR_Y, locked := false) -> void:
	var e := RoomExit.new()
	e.position = Vector2(x, y)
	e.locked = locked
	r.add_child(e)
	e.reached.connect(_on_exit_reached)
	if not _room_exits.has(_building):
		_room_exits[_building] = []
	_room_exits[_building].append(e)


## Kanal adlarını odaya özel yap (farklı odalardaki "a" kanalları karışmasın)
func _ch(name: String) -> String:
	return "%d:%s" % [_building, name]


func _crate(r: Node2D, x: float, y := FLOOR_Y) -> void:
	var c := Crate.new()
	c.position = Vector2(x, y - Crate.SIZE.y / 2.0)
	r.add_child(c)


func _plate(r: Node2D, x: float, ch: String, hold := 0.0) -> Node2D:
	var p := PressurePlate.new()
	p.position = Vector2(x, FLOOR_Y)
	p.channel = ch
	p.hold_time = hold
	r.add_child(p)
	return p


func _lever(r: Node2D, x: float, y: float, ch: String) -> Node2D:
	var l := Lever.new()
	l.position = Vector2(x, y)
	l.channel = ch
	r.add_child(l)
	return l


func _door(r: Node2D, x: float, y: float, w: float, h: float, chs := [], key := "") -> Node2D:
	var d := Door.new()
	d.position = Vector2(x, y)
	d.size = Vector2(w, h)
	d.channels = chs
	d.key_id = key
	r.add_child(d)
	return d


func _key(r: Node2D, pos: Vector2, id: String) -> void:
	var k := KeyItem.new()
	k.position = pos
	k.key_id = id
	r.add_child(k)


func _toggle(r: Node2D, x: float, y: float, w: float, h: float, ch: String,
		solid: bool, color: Color) -> void:
	var t := ToggleBlock.new()
	t.position = Vector2(x, y)
	t.size = Vector2(w, h)
	t.channel = ch
	t.solid_at_start = solid
	t.color = color
	r.add_child(t)


func _portals(r: Node2D, a: Vector2, b: Vector2, crates_only := false) -> void:
	var color := Color(1.0, 0.6, 0.2) if crates_only else Color(0.6, 0.4, 1.0)
	var pa := Portal.new()
	var pb := Portal.new()
	for p in [pa, pb]:
		p.color = color
		p.crates_only = crates_only
	pa.position = a
	pb.position = b
	pa.partner = pb
	pb.partner = pa
	r.add_child(pa)
	r.add_child(pb)


## Tetikleyiciyi kapıya bağlayan soluk kablo: neyin neyi açtığı görünsün
func _wire(r: Node2D, from: Node2D, to: Node2D) -> void:
	var a := from.position + (Vector2(40, -4) if from is PressurePlate else Vector2(0, -20))
	var door_size: Vector2 = to.get("size")
	var b := to.position + Vector2(door_size.x / 2.0, door_size.y - 70)
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = C_WIRE
	line.z_index = -5
	var mid_y := minf(a.y, b.y) - 40.0
	line.points = PackedVector2Array([a, Vector2(a.x, mid_y), Vector2(b.x, mid_y), b])
	r.add_child(line)


func _sign(r: Node2D, pos: Vector2, text: String) -> void:
	var l := Label.new()
	l.position = pos
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(l)


# =====================================================================
# Oda geçişi, kamera, HUD
# =====================================================================

func _go_to_room(i: int) -> void:
	_current = i
	_changing = false
	_msg.hide()
	_dialogue.stop()
	_reset_story()
	var def := _rooms[i]
	var origin := Vector2(i * STRIDE, 0)
	get_tree().call_group("checkpoints", "deactivate")
	player.set_spawn(origin + def["spawn"])
	player.respawn()

	_cam.limit_left = int(origin.x)
	_cam.limit_right = int(origin.x + def["w"])
	_cam.limit_top = int(BOTTOM - def["h"])
	_cam.limit_bottom = int(BOTTOM)
	_title.text = "%d/%d  %s" % [i + 1, _rooms.size(), def["title"]]
	_desc.text = def["desc"]
	await get_tree().physics_frame
	_cam.reset_smoothing()
	# Odanın açılış konuşması varsa kısa bir beklemeden sonra oynat
	var intro = def["intro"]
	if not intro.is_empty():
		await get_tree().create_timer(0.5).timeout
		if _current == i and not _dialogue.active:
			if intro is Dictionary:
				_dialogue.run(intro)
			else:
				_dialogue.play(intro)


func _on_player_respawned() -> void:
	get_tree().call_group("resettable", "reset")


func _physics_process(_delta: float) -> void:
	_story_tick()


func _on_exit_reached() -> void:
	if _changing or _ending_running:
		return
	if _current == _story_room:
		_run_story_ending()
		return
	_changing = true
	var last := _current == _rooms.size() - 1
	_msg.text = "All rooms done!" if last else "Room complete!"
	_msg.show()
	await get_tree().create_timer(0.8).timeout
	if _changing:
		_go_to_room((_current + 1) % _rooms.size())


func _on_feather_collected(room: int) -> void:
	_feathers_got += 1
	_feather_label.text = "Feathers: %d/%d" % [_feathers_got, _feathers_total]
	_room_feathers_left[room] -= 1
	if _room_feathers_left[room] <= 0:
		for e in _room_exits.get(room, []):
			e.unlock()


func _make_camera() -> void:
	_cam = Camera2D.new()
	_cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 8.0
	player.add_child(_cam)
	_cam.make_current()


func _make_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	_title = _hud_label(hud, Vector2(16, 10), 28)
	_desc = _hud_label(hud, Vector2(16, 50), 17)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.size = Vector2(760, 0)

	_help = _hud_label(hud, Vector2(16, 0), 15)
	_set_help(Input.get_connected_joypads().size() > 0)
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.offset_top = -30.0

	_feather_label = _hud_label(hud, Vector2(0, 12), 22)
	_feather_label.anchor_left = 1.0
	_feather_label.anchor_right = 1.0
	_feather_label.offset_left = -160.0
	_feather_label.text = "Feathers: 0/%d" % _feathers_total
	_feather_label.add_theme_color_override("font_color", Color(0.97, 0.95, 0.85))
	_orb_label = _hud_label(hud, Vector2(0, 42), 22)
	_orb_label.anchor_left = 1.0
	_orb_label.anchor_right = 1.0
	_orb_label.offset_left = -160.0
	_orb_label.text = "Light: 0/%d" % _light_total
	_orb_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	_help_label = _hud_label(hud, Vector2(0, 72), 22)
	_help_label.anchor_left = 1.0
	_help_label.anchor_right = 1.0
	_help_label.offset_left = -160.0
	_help_label.add_theme_color_override("font_color", Color(0.6, 0.95, 0.65))
	_update_help_label()

	_msg = _hud_label(hud, Vector2.ZERO, 48)
	_msg.anchor_left = 0.5
	_msg.anchor_right = 0.5
	_msg.anchor_top = 0.5
	_msg.anchor_bottom = 0.5
	_msg.offset_left = -520.0
	_msg.offset_right = 520.0
	_msg.offset_top = -90.0
	_msg.offset_bottom = 90.0
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_msg.hide()


## Pause menü sahnesini CanvasLayer olarak sahneye ekler.
func _add_pause_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100   # HUD'un üstünde
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var pm := PauseMenuScene.instantiate()
	layer.add_child(pm)


func _hud_label(parent: Node, pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
