extends Area2D
## Basınç plakası: üstünde oyuncu veya kutu varken kanalını açar.
## hold_time > 0 ise zamanlı düğmedir: bırakıldıktan sonra o kadar saniye daha açık kalır.
## Orijin plakanın sol alt köşesi (zemin hizası).

@export var channel := ""
@export var hold_time := 0.0

const W := 80.0

var _active := false
var _timer := 0.0
var _top: ColorRect
var _label: Label


func _ready() -> void:
	add_to_group("resettable")
	collision_layer = 0
	var base := ColorRect.new()
	base.size = Vector2(W, 4)
	base.position = Vector2(0, -4)
	base.color = Color(0.3, 0.3, 0.35)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	_top = ColorRect.new()
	_top.size = Vector2(W - 12, 6)
	_top.position = Vector2(6, -10)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(W - 8, 16)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(W / 2.0, -8)
	add_child(col)
	if hold_time > 0.0:
		_label = Label.new()
		_label.position = Vector2(W / 2.0 - 20, -44)
		_label.size = Vector2(40, 24)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 18)
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_label)
	_update_visual(false)


func _physics_process(delta: float) -> void:
	var pressed := false
	for b in get_overlapping_bodies():
		if b is Player or b.is_in_group("crate"):
			pressed = true
			break
	if pressed:
		_timer = hold_time
	elif _timer > 0.0:
		_timer -= delta
	var active := pressed or _timer > 0.0
	if active != _active:
		_set_active(active)
	_update_visual(pressed)
	if _label:
		_label.text = "%.1f" % _timer if not pressed and _timer > 0.0 else ""


func _set_active(on: bool) -> void:
	_active = on
	get_tree().call_group("puzzle", "on_channel", channel, on)


func _update_visual(pressed: bool) -> void:
	_top.position.y = -6.0 if pressed else -10.0
	if hold_time > 0.0:
		_top.color = Color(1.0, 0.6, 0.2) if _active else Color(0.75, 0.45, 0.2)
	else:
		_top.color = Color(0.35, 0.95, 0.5) if _active else Color(0.3, 0.6, 0.4)


func reset() -> void:
	_timer = 0.0
	_set_active(false)
