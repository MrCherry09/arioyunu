extends Node2D
## Level geçiş cutscene'leri. Hangi sahnenin oynayacağını GameFlow.pending_cutscene söyler.
## Sahneler kodla kurulur (gökyüzü, silüetler, piksel karakterler) ve kısa tutulur.
## Esc / Start ile atlanabilir. Bitince GameFlow.cutscene_finished() çağrılır (yükleme + sonraki level).
##
## Yeni bir cutscene eklemek için: _play() içine bir "match" dalı ve aşağıya bir _scene_xxx fonksiyonu.

const W := 1152.0
const H := 648.0
const GROUND_Y := 520.0

var dialogue: DialogueBox
var _layer: CanvasLayer
var _fade: ColorRect
var _caption: Label
var _skip: Label
var _done := false
var _story := {}


func _ready() -> void:
	GameInput.setup()
	var flow := get_node_or_null("/root/GameFlow")
	var id: String = flow.pending_cutscene if flow else "forest_to_mountain"
	_story = flow.story if flow else {}

	dialogue = DialogueBox.new()
	add_child(dialogue)
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	_caption = _label(40, Vector2(0, H * 0.42))
	_caption.modulate.a = 0.0
	_skip = _label(15, Vector2(W / 2.0 - 160, H - 34))
	_skip.text = "Esc / Start: Skip"
	_skip.modulate.a = 0.7
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.size = Vector2(W, H)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)
	_play(id)


func _label(size: int, pos: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.position = Vector2(0, pos.y) if pos.x == 0 else pos
	l.size = Vector2(W, 60)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(l)
	return l


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not _done:
		get_viewport().set_input_as_handled()
		_finish()


func _play(id: String) -> void:
	match id:
		"forest_to_mountain":
			await _scene_forest_to_mountain()
		"mountain_to_clouds":
			await _scene_mountain_to_clouds()
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	dialogue.stop()
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.5)
	await tw.finished
	var flow := get_node_or_null("/root/GameFlow")
	if flow:
		flow.cutscene_finished()


# --- Sahneler ---

func _scene_forest_to_mountain() -> void:
	_sky(Color(0.16, 0.12, 0.28), Color(0.85, 0.45, 0.35))  # akşam
	_mountain(Vector2(820, GROUND_Y), 380, 300, Color(0.22, 0.2, 0.34), true)
	_mountain(Vector2(1040, GROUND_Y), 260, 200, Color(0.18, 0.17, 0.28), false)
	for x in [40, 120, 210, 300]:
		_tree(Vector2(x, GROUND_Y))
	_ground(Color(0.2, 0.28, 0.18))
	var pl := _char("player", Vector2(-40, GROUND_Y))
	var an := _char("angel", Vector2(-110, GROUND_Y - 30))

	await _fade_in()
	var tw := create_tween().set_parallel()
	tw.tween_property(pl, "position:x", 430.0, 3.2)
	tw.tween_property(an, "position:x", 360.0, 3.2)
	await _wait_tween(tw)
	if _done:
		return
	var lines := [
		["ANGEL", "There it is. The mountain from the old woman's tale."],
	]
	if _story.get("child", "") == "helped":
		lines.append(["ANGEL", "...That child kept waving until we were out of sight. Strange creatures, mortals."])
	else:
		lines.append(["ANGEL", "Keep walking. We've wasted enough daylight in that forest."])
	lines.append(["ANGEL", "The stairway is at the top. Climb, and don't look down."])
	await _say(lines)
	if _done:
		return
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(pl, "position:x", W + 60, 2.6)
	tw2.tween_property(an, "position:x", W - 10, 2.6)
	await _show_caption("Part 2 - The Mountain")
	await _wait_tween(tw2)


func _scene_mountain_to_clouds() -> void:
	_sky(Color(0.04, 0.05, 0.14), Color(0.22, 0.24, 0.42))  # yıldızlı gece
	_stars(70)
	_mountain(Vector2(250, GROUND_Y + 40), 520, 160, Color(0.55, 0.6, 0.78), true)  # zirve
	_ground(Color(0.75, 0.8, 0.9))
	var pl := _char("player", Vector2(170, GROUND_Y))
	var an := _char("angel", Vector2(110, GROUND_Y - 30))
	await _fade_in()
	if _done:
		return
	# Işıktan merdiven: basamaklar sırayla belirir
	var steps := []
	for i in 9:
		var s := ColorRect.new()
		s.size = Vector2(70, 12)
		s.position = Vector2(560 + i * 62, GROUND_Y - 20 - i * 52)
		s.color = Color(1.4, 1.3, 0.9, 0.0)
		s.z_index = 2
		add_child(s)
		steps.append(s)
		var t := create_tween()
		t.tween_property(s, "color:a", 1.0, 0.25)
		await _wait(0.12)
		if _done:
			return
	var lines := [["ANGEL", "The Stairway. Exactly where it was... before."]]
	if _story.get("climber", "") == "helped":
		lines.append(["ANGEL", "(quietly) That fire is still burning down there. I can see it from here."])
	lines.append(["ANGEL", "Come. The Gate does not wait forever."])
	await _say(lines)
	if _done:
		return
	# İkisi merdivenden yükselir, ekran beyaza açılır
	var tw := create_tween().set_parallel()
	tw.tween_property(pl, "position", Vector2(560 + 8 * 62 + 30, GROUND_Y - 20 - 8 * 52), 3.0)
	tw.tween_property(an, "position", Vector2(560 + 8 * 62 - 30, GROUND_Y - 50 - 8 * 52), 3.0)
	await _wait_tween(tw)
	if _done:
		return
	var flash := ColorRect.new()
	flash.size = Vector2(W, H)
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(flash)
	_layer.move_child(flash, 0)
	var tf := create_tween()
	tf.tween_property(flash, "color:a", 1.0, 0.7)
	await _wait_tween(tf)
	_caption.add_theme_color_override("font_color", Color(0.2, 0.15, 0.3))
	_caption.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.6))
	await _show_caption("Part 3 - Above the Clouds")


# --- Sahne parçaları ---

func _sky(top: Color, bottom: Color) -> void:
	var g := Gradient.new()
	g.colors = PackedColorArray([top, bottom])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 128
	var bg := TextureRect.new()
	bg.texture = tex
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = Vector2(W, H)
	bg.z_index = -10
	add_child(bg)


func _ground(c: Color) -> void:
	var g := ColorRect.new()
	g.position = Vector2(0, GROUND_Y)
	g.size = Vector2(W, H - GROUND_Y)
	g.color = c
	g.z_index = 1
	add_child(g)


func _mountain(base_center: Vector2, half_w: float, height: float, c: Color, snow: bool) -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		base_center + Vector2(-half_w, 0), base_center + Vector2(0, -height), base_center + Vector2(half_w, 0)])
	poly.color = c
	poly.z_index = -5
	add_child(poly)
	if snow:
		var cap := Polygon2D.new()
		var k := 0.28
		cap.polygon = PackedVector2Array([
			base_center + Vector2(-half_w * k, -height * (1.0 - k)), base_center + Vector2(0, -height),
			base_center + Vector2(half_w * k, -height * (1.0 - k))])
		cap.color = Color(0.92, 0.94, 1.0)
		cap.z_index = -4
		add_child(cap)


func _tree(foot: Vector2) -> void:
	var trunk := ColorRect.new()
	trunk.position = foot + Vector2(-6, -60)
	trunk.size = Vector2(12, 60)
	trunk.color = Color(0.2, 0.14, 0.1)
	add_child(trunk)
	var crown := Polygon2D.new()
	crown.polygon = PackedVector2Array([foot + Vector2(-40, -50), foot + Vector2(0, -150), foot + Vector2(40, -50)])
	crown.color = Color(0.12, 0.2, 0.14)
	add_child(crown)


func _stars(n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var s := ColorRect.new()
		s.size = Vector2.ONE * (3 if rng.randf() < 0.2 else 2)
		s.position = Vector2(rng.randf() * W, rng.randf() * GROUND_Y * 0.8)
		s.color = Color(1, 1, 0.9, rng.randf_range(0.4, 1.0))
		s.z_index = -8
		add_child(s)


## Piksel karakter (ayakları pos'ta), hafifçe zıplayarak yürür
func _char(id: String, pos: Vector2) -> Node2D:
	var n := Node2D.new()
	n.position = pos
	n.z_index = 3
	var lk: Array
	if id == "player":
		lk = [PixelArt.PLAYER_IDLE, PixelArt.PLAYER_PAL]
	else:
		lk = PixelArt.look(id)
	var s := PixelArt.sprite(lk[0], lk[1])
	n.add_child(s)
	add_child(n)
	var tw := s.create_tween().set_loops()
	tw.tween_property(s, "position:y", -PixelArt.PIXEL, 0.2)
	tw.tween_property(s, "position:y", 0.0, 0.2)
	return n


# --- Zamanlama yardımcıları (atlanınca hemen döner) ---

func _fade_in() -> void:
	_fade.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 0.0, 0.8)
	await _wait_tween(tw)


func _show_caption(text: String) -> void:
	_caption.text = text
	var tw := create_tween()
	tw.tween_property(_caption, "modulate:a", 1.0, 0.6)
	tw.tween_interval(1.6)
	await _wait_tween(tw)


func _say(lines: Array) -> void:
	dialogue.play(lines)
	while dialogue.active and not _done:
		await get_tree().process_frame


func _wait(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end and not _done:
		await get_tree().process_frame


func _wait_tween(tw: Tween) -> void:
	while tw.is_valid() and tw.is_running() and not _done:
		await get_tree().process_frame
