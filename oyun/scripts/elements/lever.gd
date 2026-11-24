extends Area2D
## Şalter: yanındayken etkileşim tuşu (F / kolda Y) ile açılıp kapanır.
## Kanalına hem durumunu (kapılar için) hem de "değişti" bilgisini (renk blokları için) yollar.
## Orijin ayak hizasında.

@export var channel := ""

var on := false
var _handle: ColorRect
var _prompt: Label


func _ready() -> void:
	add_to_group("resettable")
	collision_layer = 0
	var base := ColorRect.new()
	base.size = Vector2(36, 12)
	base.position = Vector2(-18, -12)
	base.color = Color(0.45, 0.45, 0.5)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	_handle = ColorRect.new()
	_handle.size = Vector2(6, 30)
	_handle.position = Vector2(-3, -40)
	_handle.pivot_offset = Vector2(3, 30)
	_handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_handle)
	_prompt = Label.new()
	_prompt.text = "F / Y"
	_prompt.position = Vector2(-24, -72)
	_prompt.add_theme_font_size_override("font_size", 16)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.hide()
	add_child(_prompt)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(64, 64)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -32)
	add_child(col)
	_update_visual()


func _physics_process(_delta: float) -> void:
	var near := false
	for b in get_overlapping_bodies():
		if b is Player:
			near = true
	_prompt.visible = near
	if near and Input.is_action_just_pressed("interact"):
		toggle()


func toggle() -> void:
	on = not on
	_update_visual()
	get_tree().call_group("puzzle", "on_channel", channel, on)
	get_tree().call_group("puzzle", "on_toggle", channel)


func _update_visual() -> void:
	_handle.rotation = 0.6 if on else -0.6
	_handle.color = Color(0.35, 0.95, 0.5) if on else Color(0.9, 0.4, 0.35)


func reset() -> void:
	on = false
	_update_visual()
	get_tree().call_group("puzzle", "on_channel", channel, false)
