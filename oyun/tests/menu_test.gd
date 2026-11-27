extends SceneTree
## Menü testleri: ana menü, duraklatma (pause), ayarlar; kol/klavye ile gezinme ve ayarların etkisi.
## Çalıştırma (oyun/ klasöründen):
##   godot --headless --path . -s res://tests/menu_test.gd
## Hepsi geçerse çıkış kodu 0, biri bile kalırsa 1.

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


func frames(n: int) -> void:
	for i in n:
		await process_frame


## Gerçek bir tuş olayı gönder (menüler _unhandled_input / odak sistemiyle çalışır)
func key(code: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await frames(2)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await frames(3)


func pad(button: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = button
	e.pressed = true
	Input.parse_input_event(e)
	await frames(2)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await frames(3)


func focused() -> Control:
	return root.gui_get_focus_owner()


func _pause_menu() -> Control:
	for n in current_scene.find_children("*", "Control", true, false):
		if n.has_method("pause") and n.has_method("resume"):
			return n
	return null


func _run() -> void:
	var settings := root.get_node_or_null("SettingsManager")
	var old_shake: Variant = settings.get_setting("screenshake") if settings else null

	print("== Ana menü")
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await frames(10)
	var title_ok := current_scene.find_children("*", "Label", true, false) \
			.any(func(l: Label) -> bool: return l.text == "From the Heavens")
	check("başlık 'From the Heavens'", title_ok)
	var f := focused()
	check("açılışta ilk düğme (Play) seçili", f is Button and f.text == "Play", f)

	# Ayarlara gir ve geri dön (klavye)
	await key(KEY_DOWN)
	f = focused()
	if f is Button and f.text == "Continue":  # kayıt varsa araya Continue girer
		await key(KEY_DOWN)
	check("aşağı ok ile Settings seçildi", focused() is Button and focused().text == "Settings", focused())
	await key(KEY_ENTER)
	await frames(3)
	check("ayarlar açılınca ilk ayar (ses) seçili", focused() is HSlider, focused())
	var back: Button = current_scene.find_children("*", "Button", true, false) \
			.filter(func(b: Button) -> bool: return b.text == "Back")[0]
	back.pressed.emit()
	await frames(3)
	check("ayarlardan dönünce Settings düğmesi seçili", focused() is Button and focused().text == "Settings", focused())

	# Kol ile oyuna başla: yukarı çık, A'ya bas
	await pad(JOY_BUTTON_DPAD_UP)
	if focused() is Button and focused().text == "Continue":
		await pad(JOY_BUTTON_DPAD_UP)
	check("kol D-pad ile Play seçildi", focused() is Button and focused().text == "Play", focused())
	await pad(JOY_BUTTON_A)
	await frames(15)
	check("kol A ile oyun başladı (test odaları)", current_scene != null \
			and current_scene.scene_file_path == "res://scenes/test_rooms.tscn", current_scene)

	print("== Duraklatma")
	var m := current_scene
	await frames(10)
	m._dialogue.stop()
	var pm := _pause_menu()
	check("pause menüsü sahnede", pm != null)
	await key(KEY_ESCAPE)
	check("Esc: oyun durdu, menü açık", paused and pm.visible)
	check("pause açılınca Resume seçili", focused() is Button and focused().text == "Resume", focused())
	await key(KEY_ESCAPE)
	check("tekrar Esc: oyun devam", not paused and not pm.visible)
	await pad(JOY_BUTTON_START)
	check("kolda Start: oyun durdu", paused and pm.visible)
	await key(KEY_DOWN)
	await key(KEY_ENTER)
	await frames(3)
	check("pause > Settings açıldı, ses ayarı seçili", focused() is HSlider, focused())
	var back2: Button = m.find_children("*", "Button", true, false) \
			.filter(func(b: Button) -> bool: return b.text == "Back")[0]
	back2.pressed.emit()
	await frames(3)
	check("pause ayarlarından dönünce Settings seçili", focused() is Button and focused().text == "Settings", focused())
	pm.resume()
	await frames(3)
	check("Resume ile oyun devam", not paused)

	print("== Oyun içi HUD ve ayarlar")
	var feather_room := -1
	for i in m._rooms.size():
		if m._rooms[i]["title"] == "Collect the Feathers":
			feather_room = i
	m._go_to_room(0)
	await frames(5)
	check("tüy sayacı tüysüz odada gizli", not m._feather_label.visible)
	m._go_to_room(feather_room)
	await frames(5)
	check("tüy sayacı tüy odasında görünüyor", m._feather_label.visible)
	m._dialogue.stop()

	# Sarsıntı kapalıyken ışık topu kamerayı sarsmaz
	if settings:
		settings.set_setting("screenshake", false)
		var orb_room := -1
		for i in m._rooms.size():
			if m._rooms[i]["title"] == "Light Orbs":
				orb_room = i
		m._go_to_room(orb_room)
		await frames(10)
		var p: Node2D = m.get_node("Player")
		var cam: Camera2D = root.get_viewport().get_camera_2d()
		p.global_position = Vector2(orb_room * m.STRIDE + 300, 590)
		p.reset_physics_interpolation()
		var moved := false
		for i in 90:
			await process_frame
			if cam.offset != Vector2.ZERO:
				moved = true
		check("Screen Shake kapalı: kamera sarsılmadı", not moved)
		settings.set_setting("screenshake", true)
		m._go_to_room(orb_room)
		await frames(10)
		# Toplanan toplar geri gelmez: hâlâ duran bir topa git
		var orbs := root.get_tree().get_nodes_in_group("light_orbs").filter(
				func(o: Node) -> bool: return not o._taken)
		p.global_position = (orbs[0] as Node2D).global_position
		p.reset_physics_interpolation()
		moved = false
		for i in 90:
			await process_frame
			if cam.offset != Vector2.ZERO:
				moved = true
		check("Screen Shake açık: kamera sarsıldı", moved)
		settings.set_setting("screenshake", old_shake)

	print("== Ana menüye dönüş")
	_pause_menu().pause()
	await frames(2)
	_pause_menu()._on_main_menu()
	await frames(10)
	check("pause > Main Menu: ana menüye dönüldü, oyun duraklı değil",
			current_scene.scene_file_path == "res://scenes/ui/main_menu.tscn" and not paused, current_scene)

	print("\nSONUÇ: %d geçti, %d kaldı" % [_pass, _fail])
	for x in _fails:
		print("  kalan: ", x)
	quit(0 if _fail == 0 else 1)
