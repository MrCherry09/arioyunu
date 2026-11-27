extends SceneTree
## Oynanış testleri: mekanik odaları, bulmacalar ve hikâyenin üç sonu bir bot tarafından oynanır.
## Çalıştırma (oyun/ klasöründen):
##   godot --headless --path . -s res://tests/gameplay_test.gd
## Hepsi geçerse çıkış kodu 0, biri bile kalırsa 1.

var m: Node
var p: Player
var d: DialogueBox
var _pass := 0
var _fail := 0
var _fails: Array[String] = []


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


# =====================================================================
# Yardımcılar
# =====================================================================

func frames(n: int) -> void:
	for i in n:
		await physics_frame


func room(title: String) -> void:
	var idx := -1
	for i in m._rooms.size():
		if m._rooms[i]["title"] == title:
			idx = i
	assert(idx >= 0, "oda bulunamadı: " + title)
	m._go_to_room(idx)
	await frames(5)
	d.stop()
	_release_all()
	await frames(3)


func lp() -> Vector2:
	return p.global_position - Vector2(m._current * m.STRIDE, 0)


func put(x: float, y := 615.0) -> void:
	p.global_position = Vector2(m._current * m.STRIDE + x, y)
	p.velocity = Vector2.ZERO
	p.reset_physics_interpolation()
	await frames(4)


func tap(action: String, n := 2) -> void:
	Input.action_press(action)
	await frames(n)
	Input.action_release(action)
	await frames(2)


func _release_all() -> void:
	for a in ["move_left", "move_right", "jump", "down", "dash", "interact"]:
		Input.action_release(a)


## Sağa yürü; cond doğru olunca dur (en fazla max_frames)
func walk_right_until(cond: Callable, max_frames := 600) -> void:
	Input.action_press("move_right")
	for i in max_frames:
		if cond.call():
			break
		await frames(1)
	Input.action_release("move_right")


func room_done() -> bool:
	return m._changing


func kids() -> Array:
	return m._room_nodes[m._current].get_children()


func crates() -> Array:
	return kids().filter(func(c: Node) -> bool: return c.is_in_group("crate"))


func doors() -> Array:
	return kids().filter(func(c: Node) -> bool: return c.get("channels") != null)


func wait_room_change() -> void:
	for i in 120:
		if not m._changing:
			break
		await frames(1)


# =====================================================================
# Çalıştırıcı
# =====================================================================

func _run() -> void:
	m = load("res://scenes/test_rooms.tscn").instantiate()
	root.add_child(m)
	await frames(10)
	p = m.get_node("Player")
	d = m._dialogue

	print("== Mekanikler")
	await _mechanics()
	print("== Bulmacalar")
	await _puzzles()
	print("== Hikâye ve sonlar")
	await _story()

	print("\nSONUÇ: %d geçti, %d kaldı" % [_pass, _fail])
	for f in _fails:
		print("  kalan: ", f)
	_release_all()
	quit(0 if _fail == 0 else 1)


# =====================================================================
# Mekanikler
# =====================================================================

func _mechanics() -> void:
	# Zıplama yüksekliği ve çift zıplama
	await room("Walk & Jump")
	await frames(20)
	var y0 := lp().y
	var miny := y0
	Input.action_press("jump")
	for i in 50:
		await frames(1)
		miny = minf(miny, lp().y)
	Input.action_release("jump")
	check("tam zıplama ~138 px", absf((y0 - miny) - 138.0) < 8.0, y0 - miny)
	await frames(60)
	Input.action_press("jump")
	await frames(14)
	Input.action_release("jump")
	await frames(1)
	Input.action_press("jump")
	await frames(2)
	check("havada ikinci zıplama", p._air_jumps_left == 0 and p.velocity.y < -300.0, p.velocity)
	Input.action_release("jump")
	await frames(60)

	# Dash
	await room("Dash")
	await frames(10)
	await tap("dash")
	check("dash hızı", absf(p.velocity.x) > 300.0, p.velocity)

	# Duvar tırmanışı
	await room("Wall Slide & Wall Jump")
	await put(650, 300)
	var dir := 1.0
	var hold := 0
	miny = 9999.0
	for i in 900:
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_press("move_right" if dir > 0 else "move_left")
		if hold > 0:
			hold -= 1
			if hold == 0:
				Input.action_release("jump")
		elif p.is_on_wall_only():
			Input.action_press("jump")
			hold = 12
			dir = -dir
		await frames(1)
		miny = minf(miny, lp().y)
		if room_done():
			break
	_release_all()
	check("iki duvar arasında tırmanış", miny < -350.0 or room_done(), miny)
	await wait_room_change()

	# Yere çakılma bloğu kırar
	await room("Ground Pound & Breakable Blocks")
	await put(790, 300)
	await tap("down")
	await frames(30)
	check("çakılma çatlak blokları kırdı", lp().y > 500.0, lp())

	# Süzülme çukuru geçer
	await room("Glide")
	Input.action_press("move_right")
	await frames(10)
	Input.action_press("jump")
	for i in 450:
		await frames(1)
		if room_done() or lp().x > 1300.0:
			break
	_release_all()
	check("süzülerek çukur geçildi", room_done() or lp().x > 1300.0, lp())
	await wait_room_change()

	# Kayma tünelden geçer
	await room("Slide & Crawl")
	Input.action_press("move_right")
	Input.action_press("down")
	for i in 600:
		await frames(1)
		if room_done() or lp().x > 900.0:
			break
	_release_all()
	check("S basılıyken tünelden geçildi", room_done() or lp().x > 900.0, lp())
	await wait_room_change()

	# Zıplama yastığı
	await room("Jump Pads")
	await put(700)
	Input.action_press("move_right")
	var minvy := 0.0
	for i in 40:
		await frames(1)
		minvy = minf(minvy, p.velocity.y)
	_release_all()
	check("yastık fırlattı", minvy < -900.0, minvy)

	# Tek yönlü platform: üstte durur, S+Space ile iner
	await room("One-Way Platforms")
	await put(1400, 270)
	await frames(20)
	check("tek yönlü çatıda duruyor", p.is_on_floor(), lp())
	Input.action_press("down")
	await frames(1)
	Input.action_press("jump")
	await frames(2)
	_release_all()
	await frames(40)
	check("S+Space ile aşağı indi", room_done() or lp().y > 400.0, lp())
	await wait_room_change()

	# Çöken platform
	await room("Crumbling Platforms")
	await put(380, 530)
	await frames(10)
	check("çöken platformda duruyor", p.is_on_floor(), lp())
	await frames(60)
	check("platform çöktü", not p.is_on_floor() and lp().y > 560.0, lp())

	# Buz
	await room("Ice")
	await put(200)
	Input.action_press("move_right")
	await frames(10)
	var v_ice := p.velocity.x
	_release_all()
	await room("Walk & Jump")
	await put(200)
	Input.action_press("move_right")
	await frames(10)
	var v_norm := p.velocity.x
	_release_all()
	check("buzda yavaş hızlanma", v_ice < v_norm * 0.5, [v_ice, v_norm])

	# Yürüyen bant
	await room("Conveyor Belts")
	await put(700)
	await frames(30)
	var bx := lp().x
	await frames(30)
	check("bant geri taşıyor", lp().x < bx - 50.0, [bx, lp().x])

	# Rüzgar: süzülürken yükselir, süzülmeden yükselmez
	await room("Wind & Updrafts")
	await put(600, 400)
	Input.action_press("jump")
	await frames(90)
	check("akımda süzülerek yükseliyor", lp().y < 300.0, lp())
	_release_all()
	await put(600, 400)
	await frames(30)
	check("süzülmeden yükselmiyor", lp().y > 400.0, lp())

	# Diken ve kontrol noktası
	await room("Spikes & Checkpoints")
	await put(420, 560)
	await frames(20)
	check("dikende ölüp başa döndü", lp().x < 200.0, lp())
	await put(600, 600)
	await frames(5)
	await put(800, 560)
	await frames(20)
	check("kontrol noktasından doğdu", absf(lp().x - 600.0) < 5.0, lp())

	# Düşman ezme ve yandan ölüm
	await room("Enemies")
	var e: Node2D = kids().filter(func(c: Node) -> bool: return c.get("patrol") != null)[0]
	await put(e.position.x, e.position.y - 70)
	await frames(15)
	check("düşman ezildi", e._dead, lp())
	await room("Enemies")
	await put(e.position.x - 80, e.position.y - 25)
	Input.action_press("move_right")
	await frames(30)
	_release_all()
	check("düşmana yandan değince öldü", lp().x < 200.0, lp())

	# Tüy toplama kapıyı açar
	await room("Collect the Feathers")
	var hs := kids().filter(func(c: Node) -> bool: return c.has_signal("collected") and c.get("heal_amount") == null)
	for h: Node2D in hs:
		await put(h.position.x, h.position.y)
	await frames(10)
	check("tüm tüyler toplanınca kapı açıldı", not m._room_exits[m._current][0].locked, m._feathers_got)

	# Işık topu meleği iyileştirir
	await room("Light Orbs")
	var light0: float = m._angel.light
	await put(300, 590)
	await frames(80)
	check("ışık topu meleği iyileştirdi", m._angel.light > light0, [light0, m._angel.light])


# =====================================================================
# Bulmacalar
# =====================================================================

func _puzzles() -> void:
	# Kutu itme: kutu basamak olur; kutusuz çıkılamaz
	await room("Puzzle: Pushing Crates")
	var c: Node2D = crates()[0]
	await walk_right_until(func() -> bool: return c.position.x > 1060.0, 400)
	await frames(10)
	await put(c.position.x, c.position.y - 60)
	await frames(5)
	Input.action_press("jump")
	await frames(14)
	Input.action_press("move_right")
	await frames(6)
	Input.action_release("jump")
	await frames(1)
	Input.action_press("jump")
	await frames(40)
	_release_all()
	await frames(30)
	check("kutudan çıkıntıya çıkıldı", room_done() or lp().y < 380.0, lp())
	await wait_room_change()
	await room("Puzzle: Pushing Crates")
	await put(1000)
	Input.action_press("jump")
	await frames(14)
	Input.action_press("move_right")
	await frames(6)
	Input.action_release("jump")
	await frames(1)
	Input.action_press("jump")
	await frames(40)
	_release_all()
	await frames(30)
	check("kutusuz çıkıntıya çıkılamıyor", not room_done() and lp().y > 380.0, lp())

	# Basınç plakası
	await room("Puzzle: Pressure Plate")
	c = crates()[0]
	await walk_right_until(func() -> bool: return c.position.x > 570.0, 300)
	await frames(5)
	check("kutu plakada, kapı açık", doors()[0]._open, c.position)
	await put(700)
	await walk_right_until(room_done, 300)
	check("kapıdan geçildi", room_done(), lp())
	await wait_room_change()
	await room("Puzzle: Pressure Plate")
	await put(900)
	await walk_right_until(room_done, 200)
	check("plakada bir şey yokken kapı kapalı", not room_done(), lp())
	_release_all()

	# Şalter ve renk blokları
	await room("Puzzle: Lever & Color Blocks")
	var t := kids().filter(func(x: Node) -> bool: return x.get("solid_at_start") != null)
	Input.action_press("move_right")
	for i in 300:
		if lp().x > 330.0 and lp().x < 360.0:
			Input.action_press("jump")
		elif lp().x > 450.0:
			Input.action_release("jump")
		await frames(1)
		if lp().x > 720.0 and p.is_on_floor():
			break
	_release_all()
	await frames(20)
	await tap("interact")
	await frames(5)
	check("1. şalter: kırmızı kalktı, mavi geldi", not t[0]._solid and t[1]._solid, lp())
	Input.action_press("move_right")
	await frames(150)
	Input.action_release("move_right")
	await frames(5)
	await tap("interact")
	await frames(5)
	check("2. şalter: mavi duvar kalktı", t[0]._solid and not t[2]._solid, [lp(), t.map(func(x: Node) -> bool: return x._solid)])
	await walk_right_until(room_done, 200)
	check("renk blokları odası çıkışı", room_done(), lp())
	await wait_room_change()

	# Anahtar
	await room("Puzzle: Key")
	var k: Node = kids().filter(func(x: Node) -> bool: return x.get("carried") != null)[0]
	await put(520, 600)
	for i in 90:
		if i == 22:
			Input.action_press("move_right")
		if i == 45:
			Input.action_release("move_right")
		await frames(1)
	await walk_right_until(room_done, 300)
	check("anahtar alındı ve kapı açıldı", k.carried and room_done(), [k.carried, lp()])
	await wait_room_change()
	await room("Puzzle: Key")
	await walk_right_until(func() -> bool: return lp().x > 1150.0 and p.is_on_floor() and absf(p.velocity.x) < 1.0, 400)
	check("anahtarsız kapı açılmıyor", not room_done() and lp().x < 1200.0, lp())
	_release_all()

	# Zamanlı düğme: süre içinde geçilir; süre bitince kapanır
	await room("Puzzle: Timed Button")
	Input.action_press("move_right")
	for i in 400:
		if lp().x > 760.0 and lp().x < 780.0 and p.is_on_floor():
			Input.action_press("jump")
		if lp().x > 900.0:
			Input.action_release("jump")
		if room_done():
			break
		await frames(1)
	_release_all()
	check("süre bitmeden kapıdan geçildi", room_done(), lp())
	await wait_room_change()
	await room("Puzzle: Timed Button")
	await put(340)
	await frames(5)
	await put(500)
	await frames(200)
	check("süre bitince kapı kapandı", not doors()[0]._open)

	# Portal
	await room("Puzzle: Portal")
	c = crates()[0]
	await walk_right_until(func() -> bool: return c.position.x > 720.0, 300)
	check("kutu plakada (portal odası)", doors()[0]._want_open, c.position)
	await put(860)
	await walk_right_until(room_done, 300)
	check("portaldan kapalı odaya geçip çıkıldı", room_done(), lp())
	await wait_room_change()

	# Kutu portalı
	await room("Puzzle: Crate Portal")
	c = crates()[0]
	await walk_right_until(func() -> bool: return c.position.x > 1250.0, 400)
	await frames(60)
	check("kutu portaldan geçip plakaya düştü", doors()[0]._open, c.position)
	check("oyuncu kutu portalından geçmedi", lp().x < 1000.0, lp())
	await walk_right_until(room_done, 200)
	check("kutu portalı odası çıkışı", room_done(), lp())
	await wait_room_change()

	# Hepsi bir arada
	await room("Puzzle: All Together")
	c = crates()[0]
	await walk_right_until(func() -> bool: return c.position.x > 570.0, 300)
	await put(940, 195)
	await tap("interact")
	await frames(3)
	check("iki kanal açık", doors()[0]._want_open, doors()[0]._states)
	await walk_right_until(func() -> bool: return kids().filter(func(x: Node) -> bool: return x.get("carried") != null)[0].carried, 60)
	await walk_right_until(room_done, 400)
	check("iki kapıdan geçilip çıkıldı", room_done(), lp())
	await wait_room_change()

	# R ile sıfırlama kutuyu başa alır
	await room("Puzzle: Pressure Plate")
	c = crates()[0]
	var sx := c.position.x
	await walk_right_until(func() -> bool: return c.position.x > 500.0, 300)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_R
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(5)
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await frames(5)
	check("R ile kutu başa döndü", absf(crates()[0].position.x - sx) < 1.0, crates()[0].position)


# =====================================================================
# Hikâye
# =====================================================================

func _advance() -> void:
	var g := 0
	while d.active and not (d._asking() and d._opts.visible) and g < 80:
		await tap("interact")
		g += 1


func _choose(i: int) -> void:
	await _advance()
	for k in i:
		await tap("move_right")
	await tap("interact")
	await frames(3)


func _finish() -> void:
	var g := 0
	while d.active and g < 80:
		await tap("interact")
		g += 1
	await frames(15)


func _talk_at(x: float, y := 615.0) -> void:
	await put(x, y)
	await frames(5)
	await tap("interact")
	await frames(3)


func _qte_win() -> void:
	var q: QTE = m._qte
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


func _ending_text() -> String:
	for k in 1200:
		if m._msg.visible and "ENDING" in m._msg.text:
			return m._msg.text
		if d.active:
			await tap("interact")
		else:
			await frames(1)
	return m._msg.text


func _walk_to_gate() -> void:
	await put(2200)
	Input.action_press("move_right")
	await frames(30)
	Input.action_release("move_right")


func _story_room() -> void:
	m._go_to_room(m._story_room)
	await frames(45)


func _story() -> void:
	var npcs: Dictionary = m._story_npcs

	# --- İyi son: herkese yardım ---
	await _story_room()
	check("giriş: melek konuşuyor", d.active and d._name.text == "ANGEL", d._name.text)
	await _choose(1)
	await _advance()
	check("3 seçenekten 2 seçeneğe geçiş", d._asking() and d._opts.get_child_count() == 2)
	await _choose(0)
	await _finish()
	check("giriş bitti, oyuncu serbest", not d.active and not p.input_locked)
	await _talk_at(320)
	await _choose(1)
	await _advance()
	check("nine: seçenekli sohbet geri döndü", d._asking() and d._opts.get_child_count() == 3)
	await _choose(2)
	await _finish()
	await _talk_at(720)
	await _choose(0)
	await _finish()
	check("çocuk: kabul edildi", npcs["child"].state == "accepted")
	await put(590, 440)
	await frames(20)
	check("ip alındı", p.items.get("rope", 0) == 1, p.items)
	await _talk_at(720)
	await _choose(0)
	await frames(10)
	check("QTE başladı, oyuncu kilitli", m._qte.active and p.input_locked)
	await _qte_win()
	await _finish()
	check("çocuk kurtarıldı, taç takıldı", npcs["child"].state == "helped" \
			and m._angel._sprite.get_node_or_null("crown") != null)
	check("QTE sonrası oyuncu serbest", not p.input_locked)
	await _talk_at(900)
	await _choose(0)
	await _advance()
	await _choose(2)
	await _finish()
	await _talk_at(1340)
	await _choose(0)
	await _finish()
	check("dağcı: kabul edildi", npcs["climber"].state == "accepted")
	for xy: Array in [[1040.0, 615.0], [1180.0, 530.0], [1540.0, 615.0]]:
		await put(xy[0], xy[1])
		await frames(15)
	check("3 odun toplandı", p.items.get("wood", 0) == 3, p.items)
	await _talk_at(1340)
	await _choose(0)
	await _finish()
	check("ateş yandı, fener takıldı", npcs["climber"].state == "helped" and m._fire_lit \
			and m._angel._sprite.get_node_or_null("lantern") != null)
	await _talk_at(1712)
	await _choose(0)
	await _finish()
	await _talk_at(1960)
	await _choose(0)
	await _finish()
	check("ruh takip ediyor", npcs["spirit"].state == "accepted" and is_instance_valid(m._spirit_follower))
	await _walk_to_gate()
	var txt := await _ending_text()
	check("İYİ SON", "GOOD ENDING" in txt, txt.left(30))
	await frames(320)

	# --- Kötü son: kimseye yardım yok ---
	await _story_room()
	d.stop()
	await frames(5)
	check("hikâye sıfırlandı", m._helped_count() == 0 and p.items.is_empty() \
			and m._angel._sprite.get_node_or_null("crown") == null and not m._fire_lit)
	await put(800)
	Input.action_press("move_right")
	await frames(20)
	Input.action_release("move_right")
	await frames(5)
	check("yeryüzünden yardımsız çıkınca çocuk kesinleşti", npcs["child"].state == "skipped")
	await _finish()
	await put(1580)
	Input.action_press("move_right")
	await frames(20)
	Input.action_release("move_right")
	await frames(5)
	await _finish()
	check("dağcı kesinleşti", npcs["climber"].state == "skipped")
	await _walk_to_gate()
	txt = await _ending_text()
	check("KÖTÜ SON", "BAD ENDING" in txt, txt.left(30))
	await frames(320)

	# --- Orta son: sadece çocuğa yardım ---
	await _story_room()
	d.stop()
	await frames(5)
	await _talk_at(720)
	await _choose(0)
	await _finish()
	await put(590, 440)
	await frames(20)
	await _talk_at(720)
	await _choose(0)
	await frames(10)
	await _qte_win()
	await _finish()
	await _talk_at(1340)
	await _choose(2)
	await _finish()
	check("dağcıya 'I can't'", npcs["climber"].state == "skipped")
	await _talk_at(1960)
	await _choose(2)
	await _finish()
	check("ruha 'I can't'", npcs["spirit"].state == "skipped")
	await _walk_to_gate()
	txt = await _ending_text()
	check("ORTA SON", "NORMAL ENDING" in txt, txt.left(30))
