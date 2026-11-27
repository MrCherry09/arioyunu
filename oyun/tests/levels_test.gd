extends SceneTree
## Level testleri:
##   1) Normal akış: ana menü -> Play -> yükleme -> Level 1; test odalarına normal yoldan girilemiyor;
##      gizli debug tuşları çalışıyor.
##   2) Rota: her level'daki rota noktaları (Route/Pxx) arasındaki her geçişi bir bot gerçek fizikle
##      dener (yürü, zıpla, çift zıpla, süzül, duvardan tırman...). Level baştan sona oynanabilir mi?
##   3) Questler ve NPC'ler: her quest bot tarafından baştan sona yapılır.
##   4) Geçişler: level biter -> cutscene -> yükleme -> sonraki level; cutscene atlanabiliyor.
## Çalıştırma (oyun/ klasöründen):
##   godot --headless --path . -s res://tests/levels_test.gd            (hepsi)
##   godot --headless --path . -s res://tests/levels_test.gd -- route   (sadece rota)
## Hepsi geçerse çıkış kodu 0, biri bile kalırsa 1.

const TILE := 48.0
const LEVELS := [
	"res://scenes/levels/level_1_forest.tscn",
	"res://scenes/levels/level_2_mountain.tscn",
	"res://scenes/levels/level_3_clouds.tscn",
]

var _pass := 0
var _fail := 0
var _fails: Array[String] = []
var lv: Node
var p: Player


func _initialize() -> void:
	_run.call_deferred()


func check(name: String, cond: bool, info: Variant = "") -> void:
	if cond:
		_pass += 1
		print("  OK    ", name)
	else:
		_fail += 1
		_fails.append(name)
		print("  FAIL  ", name, "   -> ", info)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func release_all() -> void:
	for a in ["move_left", "move_right", "jump", "down", "dash", "interact"]:
		Input.action_release(a)


func tap(action: String, n := 2) -> void:
	Input.action_press(action)
	await frames(n)
	Input.action_release(action)
	await frames(2)


func _run() -> void:
	var only: Array = OS.get_cmdline_user_args()
	var all := only.is_empty()
	if all or "flow" in only:
		print("== Normal akış ve debug erişimi")
		await _test_flow()
	if all or "route" in only:
		for i in LEVELS.size():
			if ResourceLoader.exists(LEVELS[i]):
				print("== Rota: ", LEVELS[i].get_file())
				await _test_route(LEVELS[i])
	if all or "quests" in only:
		print("== Questler")
		for i in LEVELS.size():
			if ResourceLoader.exists(LEVELS[i]):
				await call("_quests_level_%d" % (i + 1))
	if all or "transitions" in only:
		print("== Level geçişleri")
		await _test_transitions()
	release_all()
	print("\nSONUÇ: %d geçti, %d kaldı" % [_pass, _fail])
	for f in _fails:
		print("  kalan: ", f)
	quit(0 if _fail == 0 else 1)


# =====================================================================
# Level yükleme yardımcıları
# =====================================================================

func open_level(path: String) -> void:
	change_scene_to_file(path)
	for i in 20:
		await process_frame
	lv = current_scene
	p = lv.player
	# Açılış sahnesi (ör. düşen ışık) bitsin
	for i in 400:
		if not p.input_locked:
			break
		await frames(1)
	lv.dialogue.stop()
	await frames(5)


## Diyalog/QTE kapansın ve oyuncunun kilidi kalksın (diyalog kapanınca ~0.15 sn kilitli kalır)
func idle() -> void:
	if lv and lv.dialogue.active:
		await finish()
	for i in 120:
		if not p.input_locked and not DialogueBox.ui_busy(self):
			break
		await frames(1)
	await frames(2)


func put_at(pos: Vector2) -> void:
	await idle()
	p.global_position = pos
	p.velocity = Vector2.ZERO
	p.reset_physics_interpolation()
	await frames(6)


func lp_tiles() -> Vector2:
	return (p.global_position + Vector2(0, 25)) / TILE


# =====================================================================
# Rota botu
# =====================================================================

func _test_route(path: String) -> void:
	await open_level(path)
	var pts: Array = lv.get_node("Route").get_children()
	check("rotada nokta var (%d)" % pts.size(), pts.size() >= 2)
	for i in range(1, pts.size()):
		var a: Marker2D = pts[i - 1]
		var b: Marker2D = pts[i]
		var tech: String = b.get_meta("tech", "walk")
		lv.dialogue.stop()
		p.input_locked = false
		await _prepare(tech)
		await put_at(a.global_position)
		var ok := await _go(b.global_position, tech)
		var from_t := (a.global_position + Vector2(0, 25)) / TILE
		var to_t := (b.global_position + Vector2(0, 25)) / TILE
		check("%s -> %s (%s)" % [a.name, b.name, tech], ok,
				"tile (%.1f,%.1f) -> (%.1f,%.1f), kaldığı yer (%.1f,%.1f)" % [from_t.x, from_t.y, to_t.x, to_t.y,
				lp_tiles().x, lp_tiles().y])
		release_all()


## Bazı geçişlerden önce dünyayı hazırla (ör. köprü için kütüğü plakaya koy)
func _prepare(tech: String) -> void:
	if tech == "bridge":
		var crate: Node2D = lv.ent("BridgeCrate")
		var plate: Node2D = lv.ent("BridgePlate")
		crate.global_position = plate.global_position + Vector2(40, -30)
		crate.reset_physics_interpolation()
		await frames(30)


## Hedef çıkıntıya varıldı mı: aynı yükseklikte ve hedefin 1.5 tile yakınında, ayakta
func _arrived(target: Vector2) -> bool:
	return p.is_on_floor() and absf(p.global_position.x - target.x) < 72.0 \
			and absf(p.global_position.y - target.y) < 30.0


## Hedefe git. Genel bir sezgisel kontrolcü: hedefe doğru yürü; engel/boşluk/yükselti varsa zıpla;
## havada hâlâ alçaktaysa ikinci zıplama; uzak boşlukta süzül; "wall" için iki duvar arası tırman.
func _go(target: Vector2, tech: String) -> bool:
	var max_frames := 900 if tech in ["wall", "glide", "wind"] else 600
	var jump_hold := 0
	# Bacada önce hedefin ters yönündeki (kapalı) duvara git, oradan sekerek tırman
	var wall_dir := -signf(target.x - p.global_position.x) if absf(target.x - p.global_position.x) > 1.0 else 1.0
	var stuck := 0
	var last_x := p.global_position.x
	var start_x := p.global_position.x
	for f in max_frames:
		if lv.get("finished") == true:
			return true
		# Yol üstünde kendiliğinden açılan hikâye konuşmaları rota testini durdurmasın
		if lv.dialogue.active:
			lv.dialogue.stop()
		if _arrived(target):
			release_all()
			await frames(10)
			return _arrived(target) or lv.get("finished") == true
		var pos := p.global_position
		var dx := target.x - pos.x
		var dy := target.y - pos.y  # eksi: hedef yukarıda
		var dir := signf(dx) if absf(dx) > 12.0 else 0.0
		var on_floor := p.is_on_floor()

		# Bacadan dışarı kaydıysak (yerde, başladığımız yerden uzakta) geri dön
		if tech == "wall" and on_floor and absf(pos.x - start_x) > 30.0:
			_steer(signf(start_x - pos.x))
			await frames(1)
			continue
		# Yastık: önce yakındaki yastığın üstüne yürü, fırlayınca hedefe yönel
		if tech == "pad" and on_floor:
			var pad := _nearest_pad(pos)
			if pad != Vector2.INF:
				dir = signf(pad.x - pos.x) if absf(pad.x - pos.x) > 8.0 else 0.0

		if tech == "wall":
			# İki duvar arasında: duvara yapışınca zıpla, karşı duvara yönel
			if dy > -10.0 and absf(dx) > 12.0:
				dir = signf(dx)  # tepeye çıktık: hedefe yürü
			else:
				if p.is_on_wall_only():
					# Duvara doğru basılı tutarken zıpla (oyuncu gibi), yönü ancak sonra değiştir
					var normal := signf(p.get_wall_normal().x)
					_steer(-normal)
					Input.action_release("jump")
					await frames(1)
					Input.action_press("jump")
					await frames(1)
					jump_hold = 12
					wall_dir = normal
				elif on_floor and jump_hold <= 0:
					Input.action_release("jump")
					await frames(1)
					Input.action_press("jump")
					jump_hold = 14
				# Yerden önce dik zıpla (alçakta yana gidilirse bacanın girişinden dışarı kayılır),
				# yükselirken duvara yönel
				dir = 0.0 if on_floor or (jump_hold > 6 and p.velocity.y < -200.0 and not p.is_on_wall()) \
						else wall_dir
		_steer(dir)

		if tech == "pad" and on_floor:
			pass  # yastığa yürürken zıplama; yastık fırlatacak
		elif tech != "wall":
			if on_floor:
				var blocked := p.is_on_wall()
				var higher := dy < -20.0 and absf(dx) < 340.0
				var gap_ahead := dir != 0.0 and not _floor_ahead(pos, dir) and dy < 120.0
				if (blocked or higher or gap_ahead) and jump_hold <= 0:
					Input.action_press("jump")
					jump_hold = 18
			else:
				# Havada: hâlâ hedefin altındaysak ya da boşluğun üstündeysek ikinci zıplama
				var below := dy < -15.0 or (not _floor_below(pos) and absf(dx) > 150.0)
				if below and p.velocity.y > -80.0 and p._air_jumps_left > 0 and jump_hold <= 0:
					Input.action_release("jump")
					await frames(1)
					Input.action_press("jump")
					jump_hold = 18
				# Uzun boşlukta süzül (Space basılı); hedef çok aşağıdaysa bırak, düşsün
				# Yükselirken yeni basış ikinci zıplama olur ve yastığın fırlatışını keser: sadece düşerken bas
				if jump_hold <= 0 and p.velocity.y > 0.0:
					if absf(dx) > 120.0 and dy < 200.0 or tech in ["glide", "wind"]:
						Input.action_press("jump")
					else:
						Input.action_release("jump")
		if jump_hold > 0:
			jump_hold -= 1
		# Bacada zıplama tuşu basılı kalır (gerçek oyuncu gibi): kısa basış zıplamayı yarıya indirir,
		# basılı tutmak ise düşerken süzülmeyi sağlar
		# Takılma tespiti: uzun süre ilerleme yoksa zıplamayı dene
		if absf(p.global_position.x - last_x) < 1.0 and on_floor and dir != 0.0:
			stuck += 1
			if stuck > 20:
				Input.action_press("jump")
				jump_hold = 18
				stuck = 0
		else:
			stuck = 0
		last_x = p.global_position.x
		if OS.get_environment("ROUTE_DEBUG") == tech and f % 10 == 0:
			print("    [", f, "] ", lp_tiles().snapped(Vector2(0.1, 0.1)), " v=", p.velocity.round(), " zemin=",
					on_floor, " duvar=", p.is_on_wall(), " dir=", dir, " hold=", jump_hold)
		await frames(1)
	release_all()
	return _arrived(target)


func _nearest_pad(pos: Vector2) -> Vector2:
	var best := Vector2.INF
	for n in lv.find_children("*", "Area2D", true, false):
		if n.get("strength") != null and absf(n.global_position.y - pos.y) < 80.0:
			var c: Vector2 = n.global_position + Vector2(40, 0)
			if absf(c.x - pos.x) < 8 * TILE and (best == Vector2.INF or absf(c.x - pos.x) < absf(best.x - pos.x)):
				best = c
	return best


func _steer(dir: float) -> void:
	if dir > 0.0:
		Input.action_release("move_left")
		Input.action_press("move_right")
	elif dir < 0.0:
		Input.action_release("move_right")
		Input.action_press("move_left")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")


func _ray(from: Vector2, to: Vector2) -> bool:
	var space := p.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from, to, 1 | 2)
	q.exclude = [p.get_rid()]
	return not space.intersect_ray(q).is_empty()


## Önümüzde (bir buçuk tile ileride) basacak zemin var mı?
func _floor_ahead(pos: Vector2, dir: float) -> bool:
	var x := pos.x + dir * 60.0
	return _ray(Vector2(x, pos.y), Vector2(x, pos.y + 24.0 + TILE * 2.2))


func _floor_below(pos: Vector2) -> bool:
	return _ray(pos, pos + Vector2(0, TILE * 3))


# =====================================================================
# Normal akış
# =====================================================================

func _test_flow() -> void:
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await frames(10)
	var play: Button = current_scene.find_children("*", "Button", true, false) \
			.filter(func(b: Button) -> bool: return b.text == "Play")[0]
	var labels := current_scene.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	check("ana menüde test odalarına giden düğme yok", not labels.any(func(t: String) -> bool: return "test" in t.to_lower()), labels)
	play.pressed.emit()
	await frames(5)
	check("Play -> yükleme ekranı", current_scene.scene_file_path == "res://scenes/ui/loading_screen.tscn",
			current_scene.scene_file_path)
	for i in 300:
		if current_scene and current_scene.scene_file_path == LEVELS[0]:
			break
		await process_frame
	check("yükleme bitince Level 1 (Orman)", current_scene.scene_file_path == LEVELS[0], current_scene.scene_file_path)
	await frames(10)
	# Gizli debug tuşu: Ctrl+Shift+T -> test odaları
	await _combo(KEY_T)
	for i in 300:
		if current_scene and current_scene.scene_file_path == "res://scenes/test_rooms.tscn":
			break
		await process_frame
	check("Ctrl+Shift+T -> test odaları", current_scene.scene_file_path == "res://scenes/test_rooms.tscn",
			current_scene.scene_file_path)
	# Tek başına T veya Shift+T bir şey yapmaz
	change_scene_to_file(LEVELS[0])
	await frames(20)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_T
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(10)
	check("tek başına T test odalarını açmıyor", current_scene.scene_file_path == LEVELS[0])
	await _combo(KEY_3)
	for i in 300:
		if current_scene and current_scene.scene_file_path == LEVELS[2]:
			break
		await process_frame
	check("Ctrl+Shift+3 -> Level 3", ResourceLoader.exists(LEVELS[2]) == false \
			or current_scene.scene_file_path == LEVELS[2], current_scene.scene_file_path)


func _combo(key: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = key
	e.keycode = key
	e.ctrl_pressed = true
	e.shift_pressed = true
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await frames(3)


# =====================================================================
# Questler (her level için ayrı fonksiyon)
# =====================================================================

## Diyaloğu soru gelene ya da kapanana kadar ilerlet
func advance() -> void:
	var d: DialogueBox = lv.dialogue
	var g := 0
	while d.active and not (d._asking() and d._opts.visible) and g < 80:
		await tap("interact")
		g += 1


func choose(i: int) -> void:
	await advance()
	for k in i:
		await tap("move_right")
	await tap("interact")
	await frames(3)


## Diyaloğu kapat. Soru gelirse son seçeneği seç (sohbet menülerinde son seçenek "Goodbye" gibi çıkış).
func finish() -> void:
	var d: DialogueBox = lv.dialogue
	var g := 0
	while d.active and g < 80:
		if d._asking() and d._opts.visible:
			for k in d._choices.size() - 1:
				await tap("move_right")
		await tap("interact")
		g += 1
	await frames(15)


func talk(node_name: String) -> void:
	var n: Node2D = lv.ent(node_name)
	await put_at(n.global_position + Vector2(-30, -25))
	await frames(4)
	await tap("interact")
	await frames(3)


func win_qte() -> void:
	var q: QTE = lv.qte
	for k in 600:
		if not q.active:
			break
		var mx: float = (q._marker.position.x + q.BAR_W / 2.0) + q._marker.size.x / 2.0
		if mx > q._zone_x + 14.0 and mx < q._zone_x + q.ZONE_W - 14.0:
			Input.action_press("interact")
			await frames(1)
			Input.action_release("interact")
			await frames(3)
		else:
			await frames(1)
	await frames(40)


func _quests_level_1() -> void:
	await open_level(LEVELS[0])
	var q: QuestLog = lv.quests
	# Melekle tanışma
	await talk("FallenAngel")
	await choose(2)    # "I'll help you."
	await finish()
	check("L1: melekle tanışıldı, melek takip ediyor", lv.angel.player == p and lv.angel.visible)
	# Çocuk: kabul -> ip -> QTE
	await talk("Child")
	await choose(0)
	await finish()
	check("L1: çocuk questi başladı", q.is_active("child"), q.quests.keys())
	await put_at(lv.ent("Rope").global_position + Vector2(0, -25))
	await frames(10)
	check("L1: ip alındı, hedef güncellendi", p.items.get("rope", 0) == 1 and "Bring the rope" in q.quests["child"]["objective"])
	await talk("Child")
	await choose(0)
	await frames(8)
	check("L1: QTE başladı", lv.qte.active)
	await win_qte()
	await finish()
	check("L1: çocuk kurtarıldı, quest tamam", q.state("child") == QuestLog.DONE and lv.story()["child"] == "helped")
	check("L1: kurtarılınca kuzu questi önerildi", q.has("lamb"))
	# Hikâye taşları (Nine'den başla)
	await talk("Granny")
	await advance()
	await choose(2)    # "Do you know any old tales?"
	await finish()
	check("L1: taş questi başladı", q.is_active("stones"))
	for s in ["Stone1", "Stone2"]:
		await talk(s)
		await finish()
	check("L1: 2 taş okundu", q.quests["stones"]["count"] == 2, q.quests["stones"])
	# Kuzu: kovala, köşeye sıkıştır, çobana götür
	var lamb: Node2D = lv.ent("Lamb")
	await put_at(lamb.global_position + Vector2(-200, -25))
	Input.action_press("move_right")
	for i in 400:
		if lamb.mode == "follow":
			break
		await frames(1)
	release_all()
	check("L1: kuzu çite sıkıştırılıp yakalandı", lamb.mode == "follow", lamb.global_position / TILE)
	check("L1: kuzuyu yakalarken başka konuşma açılmadı", not lv.dialogue.active)
	await idle()
	# Çobanın ağılına yürü (çit üstünden zıplayarak)
	var pen: Node2D = lv.ent("Pen")
	var ok := await _go(pen.global_position + Vector2(pen.size.x / 2.0, pen.size.y - 25), "walk")
	await frames(120)
	check("L1: kuzu ağıla getirildi, quest tamam", q.state("lamb") == QuestLog.DONE,
			[ok, lamb.mode, lamb.global_position / TILE])
	# Köprü: önce değirmenciyle konuş
	await talk("Miller")
	await choose(0)
	await finish()
	check("L1: köprü questi başladı", q.is_active("bridge"), q.quests.get("bridge"))
	# Köprü inmeden karşıya geçilememeli (rüzgar süzülmeyi ve nehir yatağından tırmanmayı engeller)
	var far_bank := (lv.ent("Bridge") as Node2D).global_position + Vector2(16 * TILE, -25)
	await put_at(Vector2(159.5 * TILE, 17 * TILE - 25))
	var crossed := await _go(far_bank, "glide")
	check("L1: köprü inmeden süzülerek geçilemiyor", not crossed and lp_tiles().x < 174.0, lp_tiles())
	await put_at(Vector2(166 * TILE, 21 * TILE - 25))
	crossed = await _go(far_bank, "walk")
	check("L1: nehir yatağından karşı kıyıya tırmanılamıyor", not crossed and lp_tiles().x < 174.0, lp_tiles())
	check("L1: (bu denemeler sırasında oyuncu kilitli değildi)", not p.input_locked)
	# Kütüğü plakaya it
	var crate: Node2D = lv.ent("BridgeCrate")
	await put_at(crate.global_position + Vector2(-90, 0))
	Input.action_press("move_right")
	for i in 200:
		if lv.ent("Bridge")._solid:
			break
		await frames(1)
	release_all()
	await frames(20)
	check("L1: kütük plakada, köprü indi", lv.ent("Bridge")._solid, crate.global_position / TILE)
	var far := (lv.ent("Bridge") as Node2D).global_position + Vector2(17 * TILE, -25)
	await _go(far, "walk")
	await frames(10)
	check("L1: köprüden geçildi, quest tamam", q.state("bridge") == QuestLog.DONE, lp_tiles())
	# 3. taş mahzende (nehrin ötesinde, köprüden sonra): çatlak zemini çakılarak kır
	var lid: Node2D = lv.ent("CellarLid1")
	await put_at(lid.global_position + Vector2(24, -140))
	await frames(2)
	await tap("down")
	await frames(40)
	check("L1: çatlak zemin çakılarak kırıldı, mahzene inildi", lp_tiles().y > 19.0, lp_tiles())
	await talk("Stone3")
	await finish()
	check("L1: 3 taş okundu, quest tamam", q.state("stones") == QuestLog.DONE)
	# Çıkışta: çocuk kurtarıldığı için çocuk görünür, köylü kadın görünmez
	check("L1: çıkışta kurtarılan çocuk var, iz yok", lv.ent("ChildAtExit").visible and not lv.ent("FarmerAtExit").visible)
	check("L1: quest ödülü ışık topları belirdi", lv.light_total > 125.0, lv.light_total)


func _quests_level_2() -> void:
	var flow: Node = root.get_node("GameFlow")
	flow.story["climber"] = ""
	await open_level(LEVELS[1])
	var q: QuestLog = lv.quests
	check("L2: ana quest başladı", q.is_active("main"))
	# Dağcı: kabul -> 3 odun -> ateş
	await talk("Climber")
	await choose(0)
	await finish()
	check("L2: dağcı questi başladı", q.is_active("climber") and flow.story["climber"] == "accepted")
	for w in ["Wood1", "Wood2", "Wood3"]:
		var wn: Node2D = lv.ent(w)
		await put_at(wn.global_position + Vector2(0, -25))
		await frames(10)
		check("L2: %s alınırken dağcı seçimi kesinleşmedi" % w, flow.story["climber"] == "accepted", flow.story["climber"])
	check("L2: 3 odun toplandı", p.items.get("wood", 0) == 3 and q.quests["climber"]["count"] == 3, p.items)
	await talk("Climber")
	await choose(0)    # "Light the fire."
	await finish()
	check("L2: ateş yandı, dağcı kurtarıldı", q.state("climber") == QuestLog.DONE and flow.story["climber"] == "helped")
	# Madenci: dash ile kayaları kır
	await put_at(Vector2(34.5 * TILE, 62 * TILE - 25))
	check("L2: madenci questi mağara ağzında başladı", q.is_active("miner"), q.quests.keys())
	await idle()
	Input.action_press("move_right")
	await frames(6)
	await tap("dash")
	await frames(30)
	release_all()
	check("L2: kayalar dash ile kırıldı, madenci serbest", lv._miner_freed and lv.ent("Rockfall0")._broken,
			[lp_tiles(), lv._miner_freed, lv.ent("Rockfall2")._broken])
	await talk("Miner")
	await finish()
	check("L2: madenci teşekkür etti, quest tamam", q.state("miner") == QuestLog.DONE)
	# Keşiş -> çanlar
	await talk("Monk")
	await choose(2)    # "Can I help with anything?"
	await finish()
	check("L2: çan questi başladı", q.is_active("bells"), q.quests.keys())
	check("L2: tapınak kapısı başta kapalı", not lv.ent("ShrineDoor")._open)
	for b in ["Bell1", "Bell2", "Bell3"]:
		await talk(b)
		await finish()
	await frames(30)
	check("L2: 3 çan çalındı, quest tamam", q.state("bells") == QuestLog.DONE, q.quests.get("bells"))
	check("L2: tapınak kapısı açıldı", lv.ent("ShrineDoor")._open)
	# Düşüp yeniden doğunca kapı açık kalmalı (çanlar tekrar çalınmaz)
	var back_pos := p.global_position
	p.respawned.emit()
	await frames(10)
	check("L2: yeniden doğunca tapınak kapısı açık kalıyor", lv.ent("ShrineDoor")._open)
	await put_at(back_pos)
	# Zirve
	await put_at(Vector2(31 * TILE, 12 * TILE - 25))
	await frames(10)
	check("L2: zirvede hedef merdivene döndü", "Stairway" in q.quests["main"]["objective"], q.quests["main"])
	await talk("ShrineStone")
	await finish()
	check("L2: (taş okunduktan sonra diyalog kapalı)", not lv.dialogue.active)
	# Dağcıya yardım etmeden yukarı çıkılırsa seçim kesinleşir
	flow.story["climber"] = ""
	await open_level(LEVELS[1])
	await put_at(Vector2(6 * TILE, 52 * TILE - 25))
	await frames(10)
	check("L2: dağcıyı geçip yukarı çıkınca 'skipped'", flow.story["climber"] == "skipped", flow.story["climber"])
	check("L2: melek geride bırakma repliğini söyledi", lv.dialogue.active)
	await idle()


func _quests_level_3() -> void:
	var flow: Node = root.get_node("GameFlow")
	# Önce ruha yardım etmeden kapı adasına geçme
	flow.story["spirit"] = ""
	await open_level(LEVELS[2])
	await put_at(Vector2(203 * TILE, 24 * TILE - 25))
	await frames(10)
	check("L3: ruhu geçip kapı adasına varınca 'skipped'", flow.story["spirit"] == "skipped", flow.story["spirit"])
	await idle()
	flow.story["spirit"] = ""
	await open_level(LEVELS[2])
	var q: QuestLog = lv.quests
	check("L3: ana quest başladı", q.is_active("main"))
	# Kuş -> yavrular
	await talk("Bird")
	await choose(0)    # "You look worried."
	await finish()
	check("L3: yavru questi başladı", q.is_active("chicks"), q.quests.keys())
	for c in ["Chick1", "Chick2"]:
		var cn: Node2D = lv.ent(c)
		await put_at(cn.global_position + Vector2(0, -25))
		await frames(10)
	check("L3: 2 yavru peşimizde", lv._chicks.size() == 2, lv._chicks.size())
	var nest: Node2D = lv.ent("NestZone")
	await put_at(nest.global_position + Vector2(100, 4 * TILE - 25))
	await frames(10)
	check("L3: 2 yavru yuvaya bırakıldı", lv._delivered == 2 and lv._chicks.is_empty(), lv._delivered)
	# 3. yavru: yuvanın yanındaki yastıkla yukarı
	await put_at(Vector2(155.6 * TILE, 22 * TILE - 25))
	var c3: Node2D = lv.ent("Chick3")
	var got := false
	for i in 300:
		if lv._chicks.size() == 1:
			got = true
			break
		if p.global_position.y < 12.4 * TILE:
			_steer(-1)  # adanın üst hizasını geçince sola
		await frames(1)
	release_all()
	check("L3: 3. yavruya yastıkla ulaşıldı", got, [lp_tiles(), c3.global_position / TILE])
	await put_at(nest.global_position + Vector2(100, 4 * TILE - 25))
	await frames(20)
	check("L3: 3 yavru yuvada, quest tamam", q.state("chicks") == QuestLog.DONE, lv._delivered)
	await idle()
	# Fenerler: çan çalmadan yanmaz
	await talk("Lantern1")
	await finish()
	check("L3: çan çalmadan fener yanmıyor", not q.has("lanterns") and lv.ent("Lantern1").look == "lantern")
	await talk("SkyBell")
	await finish()
	check("L3: çan çaldı, süre başladı", q.is_active("lanterns") and lv._lantern_time > 0.0)
	await talk("Lantern1")
	await finish()
	check("L3: ilk fener yandı", lv.ent("Lantern1").look == "lantern_on" and q.quests["lanterns"]["count"] == 1)
	lv._lantern_time = 0.05
	await frames(10)
	check("L3: süre bitince fenerler söndü", lv._lit.is_empty() and lv.ent("Lantern1").look == "lantern"
			and "Ring" in q.quests["lanterns"]["objective"], q.quests["lanterns"])
	await talk("SkyBell")
	await finish()
	for l in ["Lantern1", "Lantern2", "Lantern3", "Lantern4"]:
		await talk(l)
		await finish()
	check("L3: 4 fener süre bitmeden yandı, quest tamam", q.state("lanterns") == QuestLog.DONE, q.quests["lanterns"])
	# Ruh: kabul et, kapıya götür
	await talk("Spirit")
	await choose(0)    # "Come with me."
	await finish()
	check("L3: ruh peşimizde", flow.story["spirit"] == "accepted" and lv._spirit_follower != null
			and q.is_active("spirit"))
	await put_at(Vector2(214 * TILE, 26 * TILE - 25))
	await frames(150)
	check("L3: ruh kapı adasına kadar geldi", lv._spirit_follower.global_position.distance_to(p.global_position) < 300.0)
	# Kapıya yürü (rota botu konuşmaları kapattığı için burada düz yürünür)
	Input.action_press("move_right")
	var ok := false
	for i in 600:
		ok = ok or p.global_position.x > 221 * TILE
		if lv.dialogue.active:
			await finish()
		if lv.finished:
			break
		await frames(1)
	release_all()
	check("L3: kapıya varıldı, ruh yükseldi", flow.story["spirit"] == "helped" and q.state("spirit") == QuestLog.DONE, ok)
	check("L3: ana quest tamam, 'To be continued'", q.state("main") == QuestLog.DONE and lv.hud._center.visible
			and "continued" in lv.hud._center.text)
	for i in 600:
		if current_scene and current_scene.scene_file_path == "res://scenes/ui/main_menu.tscn":
			break
		await process_frame
	check("L3: kapıdan sonra ana menüye dönüldü (sonrası yok)",
			current_scene.scene_file_path == "res://scenes/ui/main_menu.tscn", current_scene.scene_file_path)


# =====================================================================
# Geçişler
# =====================================================================

func _wait_scene(path: String, max_frames := 900) -> bool:
	for i in max_frames:
		if current_scene and current_scene.scene_file_path == path:
			return true
		await process_frame
	return current_scene != null and current_scene.scene_file_path == path


func _test_transitions() -> void:
	var flow: Node = root.get_node("GameFlow")
	GameInput.setup()
	flow.start_new_game()
	for i in 60:
		if current_scene:
			break
		await process_frame
	check("yeni oyun: yükleme ekranı", current_scene.scene_file_path == flow.LOADING_SCENE, current_scene.scene_file_path)
	check("yeni oyun: Level 1", await _wait_scene(LEVELS[0]))
	await frames(20)
	current_scene.complete()
	await frames(5)
	check("Level 1 bitti -> cutscene", current_scene.scene_file_path == flow.CUTSCENE_SCENE, current_scene.scene_file_path)
	check("yardım edilmeyen çocuk 'skipped' olarak kaydedildi", flow.story.get("child") == "skipped", flow.story)
	await frames(60)
	# Atla (Esc / Start): gerçek bir tuş olayı gönder
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await frames(2)
	esc = esc.duplicate()
	esc.pressed = false
	Input.parse_input_event(esc)
	check("cutscene atlanınca yükleme -> Level 2", await _wait_scene(LEVELS[1]))
	await frames(20)
	current_scene.complete()
	await frames(5)
	check("Level 2 bitti -> cutscene", current_scene.scene_file_path == flow.CUTSCENE_SCENE)
	# Bu sefer atlamadan sonuna kadar izle (konuşmaları oyuncu gibi ilerlet)
	var reached := false
	for i in 60 * 60:
		if current_scene and current_scene.scene_file_path == LEVELS[2]:
			reached = true
			break
		var dlg = current_scene.get("dialogue") if current_scene else null
		if current_scene and current_scene.scene_file_path == flow.CUTSCENE_SCENE and dlg and dlg.active:
			await tap("interact", 3)
			await frames(10)
		else:
			await process_frame
	check("cutscene sonuna kadar oynayıp Level 3'e geçti", reached)
	await frames(20)
	check("dağcı 'skipped' olarak kaydedildi", flow.story.get("climber") == "skipped", flow.story)
	current_scene.complete()
	await frames(30)
	check("son level complete(): başka bir yere gitmiyor (Gate sonrası yok)",
			current_scene.scene_file_path == LEVELS[2], current_scene.scene_file_path)
