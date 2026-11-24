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

static var _current := 0   ## R ile sahne yeniden yüklense de aynı odada kal

@onready var player: Player = $Player

var _rooms: Array[Dictionary] = []
var _room_nodes: Array[Node2D] = []
var _room_exits: Dictionary = {}       ## oda indeksi -> [RoomExit]
var _room_honey_left: Dictionary = {}  ## oda indeksi -> kalan bal
var _building := 0
var _changing := false
var _honey_got := 0
var _honey_total := 0

var _cam: Camera2D
var _title: Label
var _desc: Label
var _msg: Label
var _honey_label: Label


func _ready() -> void:
	_setup_inputs()
	_define_rooms()
	for i in _rooms.size():
		_building = i
		var r := Node2D.new()
		r.name = "Room%02d" % (i + 1)
		r.position = Vector2(i * STRIDE, 0)
		add_child(r)
		_build_shell(r, _rooms[i])
		(_rooms[i]["build"] as Callable).call(r)
		_room_nodes.append(r)

	player.z_index = 10
	player.respawned.connect(_on_player_respawned)
	_make_camera()
	_make_hud()
	_go_to_room(clampi(_current, 0, _rooms.size() - 1))


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
	_add("Yürüme ve Zıplama",
		"A/D ile yürü, Space ile zıpla. Kısa basarsan alçak zıplarsın. "
		+ "Kenardan düştükten hemen sonra da zıplayabilirsin (coyote time).", _r_walk)
	_add("Çift Zıplama",
		"Havadayken Space'e bir daha bas. Bu duvar tek zıplamayla aşılmaz.", _r_double_jump)
	_add("Dash",
		"Shift (veya K) ile kısa ve hızlı atıl. Alçak tavan yüzünden yüksek zıplayamazsın: "
		+ "zıpla + havada dash ile çukuru geç.", _r_dash)
	_add("Duvar Kayma ve Duvar Zıplaması",
		"Havada duvara doğru basılı tut: yavaş kayarsın (sarı). O sırada Space ile duvardan sek. "
		+ "İki duvar arasında sekerek tırman.", _r_wall, {"h": 1300})
	_add("Yere Çakılma ve Kırılabilir Bloklar",
		"Havada S ile yere çakıl (kırmızı): çatlak blokları kırar. "
		+ "Aşağıdaki çatlak duvarı da dash ile kır.", _r_breakable,
		{"spawn": Vector2(120, 355)})
	_add("Süzülme (Arı Kanatları)",
		"Düşerken Space'i basılı tut: yavaşça süzülürsün (yeşil). Çukuru süzülerek geç.",
		_r_glide, {"spawn": Vector2(120, 175), "floor": [[1300, 1560]]})
	_add("Kayma ve Sürünme",
		"Yerdeyken S ile kay (mor). S'yi basılı tutarsan çömelik kalıp sürünürsün; "
		+ "alçak tavanın altında da ayağa kalkamazsın.", _r_slide)
	_add("Zıplama Yastığı",
		"Pembe yastıklar seni yukarı fırlatır ve çift zıplama/dash hakkını yeniler.", _r_jump_pad)
	_add("Hareketli Platformlar",
		"Platformlar seni taşır. Zamanlamayı tuttur.", _r_moving, {"floor": [[40, 300]]})
	_add("Tek Yönlü Platformlar",
		"Açık mavi platformların altından zıplayıp geçebilirsin. "
		+ "Üstündeyken S basılı tutup Space ile aşağı in. Çıkış kapalı odanın içinde.", _r_one_way)
	_add("Çöken Platformlar",
		"Üstüne basınca titreyip çökerler, 2 saniye sonra geri gelirler. Durma!", _r_crumble,
		{"floor": [[40, 260], [1360, 1560]]})
	_add("Buz Zemin",
		"Buzda hızlanmak da durmak da zor. Küçük buz adasında durmayı dene.", _r_ice, {"floor": []})
	_add("Yürüyen Bant",
		"Bantlar seni taşır: ilki geriye, ikincisi ileri iter.", _r_conveyor,
		{"floor": [[40, 300], [1000, 1560]]})
	_add("Rüzgar ve Yukarı Akım",
		"Yukarı akımda Space'i basılı tutup süzülürsen yükselirsin. "
		+ "Üstte rüzgar seni geri itiyor.", _r_wind, {"h": 1200})
	_add("Dikenler ve Kontrol Noktası",
		"Dikenlere değme. Bayrağa değince ölürsen oradan başlarsın. "
		+ "Tavandaki dikenlere dikkat: orada çift zıplama yapma!", _r_spikes, {"w": 1800})
	_add("Düşmanlar",
		"Kırmızı düşmanların üstüne zıplayarak ez (sekersin). Dash veya çakılma da öldürür. "
		+ "Yandan değersen ölürsün.", _r_enemies, {"w": 1800})
	_add("Bal Topla",
		"Kapı tüm bal damlaları toplanınca açılır. Her biri için farklı bir yetenek gerekiyor.",
		_r_honey, {"w": 1800})
	_add("Serbest Oyun Alanı",
		"Her şey bir arada. İstediğin gibi dene. (Çıkış yok; Q/E ile oda değiştir.)",
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
	})


# =====================================================================
# Odalar (koordinatlar oda içi; zemin üstü y=640, oda tabanı y=720)
# =====================================================================

func _r_walk(r: Node2D) -> void:
	_plat(r, 350, 540, 160, 24)
	_plat(r, 600, 440, 160, 24)
	_hide_floor_gap(r, 900, 1060)
	_sign(r, Vector2(80, 520), "A/D: yürü\nSpace: zıpla")
	_sign(r, Vector2(860, 380), "Kenardan düşerken\nhâlâ zıplayabilirsin")
	_exit(r, 1480)


func _r_double_jump(r: Node2D) -> void:
	_plat(r, 700, 420, 120, 220, {"color": C_WALL})
	_sign(r, Vector2(400, 360), "Havada tekrar Space")
	_plat(r, 1100, 430, 120, 210, {"color": C_WALL})
	_exit(r, 1480)


func _r_dash(r: Node2D) -> void:
	_hide_floor_gap(r, 620, 880)
	_plat(r, 560, WALL, 380, 500, {"color": C_WALL})  # alçak tavan (alt kenar y=540)
	_sign(r, Vector2(240, 480), "Zıpla + Shift")
	_exit(r, 1480)


func _r_wall(r: Node2D) -> void:
	# Soldaki duvarın altından geçilip iki duvar arasındaki bacaya girilir
	_plat(r, 500, -300, 40, 820, {"color": C_WALL})
	_plat(r, 760, -380, 40, 1020, {"color": C_WALL})
	_plat(r, 800, -380, 760, 30)
	_sign(r, Vector2(140, 520), "Duvara doğru bas + Space")
	_exit(r, 1480, -380)


func _r_breakable(r: Node2D) -> void:
	_plat(r, WALL, 380, 640, 30)
	for i in 4:
		_breakable(r, 680 + i * 50, 380, 50, 30)
	_plat(r, 880, 380, 680, 30)
	# Alt katta dash ile kırılacak duvar
	for i in 5:
		_breakable(r, 1150, 410 + i * 46, 40, 46)
	_sign(r, Vector2(560, 290), "Çatlakların üstünde: zıpla + S")
	_sign(r, Vector2(900, 560), "Shift ile duvarı kır →")
	_exit(r, 1450)


func _r_glide(r: Node2D) -> void:
	_plat(r, WALL, 200, 260, 30)
	_sign(r, Vector2(60, 100), "Düşerken Space basılı tut")
	_exit(r, 1480)


func _r_slide(r: Node2D) -> void:
	_plat(r, 450, WALL, 400, 564, {"color": C_WALL})   # tünel: alt kenar y=604 (36px boşluk)
	_plat(r, 1050, WALL, 350, 564, {"color": C_WALL})
	_sign(r, Vector2(150, 520), "Yürürken S (basılı tut)")
	_exit(r, 1480)


func _r_jump_pad(r: Node2D) -> void:
	_pad(r, 340, 760.0)
	_plat(r, 260, 300, 200, 24)
	_pad(r, 760, 1000.0)
	_plat(r, 1000, 240, 560, 30)
	_sign(r, Vector2(600, 540), "Üstüne bas →")
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
	_sign(r, Vector2(1260, 220), "S + Space ile in ↓")
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
	_wind(r, 900, -470, 400, 210, Vector2(-1400, 0))
	_sign(r, Vector2(180, 500), "Akıma gir, Space basılı tut ↑")
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


func _r_honey(r: Node2D) -> void:
	_honey(r, Vector2(400, 390))          # çift zıplama
	_pad(r, 200, 1100.0)
	_honey(r, Vector2(240, 210))          # yastık
	_plat(r, 640, 330, 160, 20)
	_plat(r, 820, 120, 40, 400, {"color": C_WALL})
	_honey(r, Vector2(720, 300))          # duvar zıplaması
	_plat(r, 950, WALL, 250, 564, {"color": C_WALL})
	_honey(r, Vector2(1075, 620))         # kayma tüneli
	for i in 3:
		_breakable(r, 1300, 520 + i * 40, 40, 40)
	_plat(r, 1300, 500, 200, 20)
	_plat(r, 1460, 520, 40, 120, {"color": C_WALL})
	_honey(r, Vector2(1390, 615))         # dash ile kır
	_exit(r, 1700, FLOOR_Y, true)


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
	bg.color = Color(0.16, 0.17, 0.22)
	bg.z_index = -10
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(bg)
	_plat(r, 0, top, WALL, h, {"color": C_WALL})
	_plat(r, w - WALL, top, WALL, h, {"color": C_WALL})
	_plat(r, 0, top, w, WALL, {"color": C_WALL})
	for seg: Array in def["floor"]:
		_plat(r, seg[0], FLOOR_Y, seg[1] - seg[0], BOTTOM - FLOOR_Y)


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


func _honey(r: Node2D, pos: Vector2) -> void:
	var h := Collectible.new()
	h.position = pos
	r.add_child(h)
	var room := _building
	_room_honey_left[room] = _room_honey_left.get(room, 0) + 1
	_honey_total += 1
	h.collected.connect(_on_honey_collected.bind(room))


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


func _on_player_respawned() -> void:
	get_tree().call_group("resettable", "reset")


func _on_exit_reached() -> void:
	if _changing:
		return
	_changing = true
	var last := _current == _rooms.size() - 1
	_msg.text = "Tüm odalar bitti!" if last else "Oda tamamlandı!"
	_msg.show()
	await get_tree().create_timer(0.8).timeout
	if _changing:
		_go_to_room((_current + 1) % _rooms.size())


func _on_honey_collected(room: int) -> void:
	_honey_got += 1
	_honey_label.text = "Bal: %d/%d" % [_honey_got, _honey_total]
	_room_honey_left[room] -= 1
	if _room_honey_left[room] <= 0:
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

	var help := _hud_label(hud, Vector2(16, 0), 15)
	help.text = "A/D yürü · Space zıpla (basılı: süzül) · Shift dash · S: yerde kay/sürün, havada çakıl · " \
			+ "S+Space: platformdan in · Q/E oda değiştir · R sıfırla"
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_top = -30.0

	_honey_label = _hud_label(hud, Vector2(0, 12), 22)
	_honey_label.anchor_left = 1.0
	_honey_label.anchor_right = 1.0
	_honey_label.offset_left = -160.0
	_honey_label.text = "Bal: 0/%d" % _honey_total
	_honey_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.25))

	_msg = _hud_label(hud, Vector2.ZERO, 48)
	_msg.anchor_left = 0.5
	_msg.anchor_right = 0.5
	_msg.anchor_top = 0.5
	_msg.anchor_bottom = 0.5
	_msg.offset_left = -300.0
	_msg.offset_right = 300.0
	_msg.offset_top = -40.0
	_msg.offset_bottom = 40.0
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_msg.hide()


func _hud_label(parent: Node, pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


static func _setup_inputs() -> void:
	var map := {
		"next_room": [KEY_E, KEY_PAGEDOWN],
		"prev_room": [KEY_Q, KEY_PAGEUP],
	}
	for action: String in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
