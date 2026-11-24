class_name QTE
extends CanvasLayer
## Zamanlama mini oyunu: gidip gelen işaret yeşil bölgedeyken etkileşim/zıplama tuşuna bas.
## hits_needed kadar isabet gerekir. Iskalamak sadece bir isabeti geri alır; başarısız olunmaz.
## Bitince on_success çağrılır. Bu sırada oyuncu kilitlidir.

const BAR_W := 360.0
const ZONE_W := 64.0
const SPEED := 1.3   ## saniyede tur

var player: Player
var active := false

var _hits := 0
var _need := 3
var _t := 0.0
var _zone_x := 0.0
var _on_success: Callable
var _root: Control
var _title: Label
var _zone: ColorRect
var _marker: ColorRect
var _pips: Array[ColorRect] = []
var _bar: ColorRect


func _ready() -> void:
	layer = 6
	GameInput.setup()
	add_to_group("ui_blockers")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var frame := ColorRect.new()
	frame.color = Color(0.95, 0.85, 0.55)
	frame.position = Vector2(-BAR_W / 2.0 - 4, -4)
	frame.size = Vector2(BAR_W + 8, 32)
	_root.add_child(frame)
	_bar = ColorRect.new()
	_bar.color = Color(0.08, 0.08, 0.12)
	_bar.position = Vector2(-BAR_W / 2.0, 0)
	_bar.size = Vector2(BAR_W, 24)
	_root.add_child(_bar)
	_zone = ColorRect.new()
	_zone.color = Color(0.3, 0.85, 0.45)
	_zone.size = Vector2(ZONE_W, 24)
	_root.add_child(_zone)
	_marker = ColorRect.new()
	_marker.color = Color(1, 1, 1)
	_marker.size = Vector2(6, 36)
	_root.add_child(_marker)

	_title = Label.new()
	_title.position = Vector2(-BAR_W / 2.0, -48)
	_title.size = Vector2(BAR_W, 30)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_constant_override("outline_size", 6)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_root.add_child(_title)
	var hint := Label.new()
	hint.text = "Press F / Space (pad: Y / A) in the green zone"
	hint.position = Vector2(-BAR_W / 2.0 - 60, 40)
	hint.size = Vector2(BAR_W + 120, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_constant_override("outline_size", 5)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_root.add_child(hint)
	_root.hide()


func start(title: String, hits_needed: int, on_success: Callable) -> void:
	_title.text = title
	_need = hits_needed
	_hits = 0
	_t = 0.0
	_on_success = on_success
	for p in _pips:
		p.queue_free()
	_pips.clear()
	for i in _need:
		var p := ColorRect.new()
		p.size = Vector2(14, 14)
		p.position = Vector2(-(_need * 22) / 2.0 + i * 22, 72)
		_root.add_child(p)
		_pips.append(p)
	_new_zone()
	_update_pips()
	active = true
	if player:
		player.input_locked = true
	_root.show()


func _new_zone() -> void:
	_zone_x = randf_range(0.1, 0.9) * (BAR_W - ZONE_W)
	_zone.position = Vector2(-BAR_W / 2.0 + _zone_x, 0)


func _update_pips() -> void:
	for i in _pips.size():
		_pips[i].color = Color(0.35, 0.95, 0.5) if i < _hits else Color(0.3, 0.3, 0.38)


func _process(delta: float) -> void:
	if not active:
		return
	_t += delta
	# Ping-pong: 0 → 1 → 0
	var k := absf(fmod(_t * SPEED * 2.0, 2.0) - 1.0)
	var mx := k * (BAR_W - _marker.size.x)
	_marker.position = Vector2(-BAR_W / 2.0 + mx, -6)

	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump"):
		var center := mx + _marker.size.x / 2.0
		if center >= _zone_x and center <= _zone_x + ZONE_W:
			_hits += 1
			_flash(Color(0.35, 0.95, 0.5))
			if _hits >= _need:
				_finish()
				return
			_new_zone()
		else:
			_hits = maxi(_hits - 1, 0)
			_flash(Color(0.95, 0.35, 0.35))
		_update_pips()


func _flash(c: Color) -> void:
	_bar.color = c.darkened(0.6)
	var tw := create_tween()
	tw.tween_property(_bar, "color", Color(0.08, 0.08, 0.12), 0.2)


func _finish() -> void:
	active = false
	_update_pips()
	await get_tree().create_timer(0.3).timeout
	_root.hide()
	if _on_success.is_valid():
		_on_success.call()
	await get_tree().create_timer(0.15).timeout
	if player and not DialogueBox.ui_busy(get_tree()):
		player.input_locked = false
