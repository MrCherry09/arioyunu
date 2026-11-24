extends Area2D
## Kontrol noktası: değince karakter ölünce buradan başlar. Orijin ayak hizasında.

const OFF := Color(0.5, 0.5, 0.55)
const ON := Color(0.3, 0.95, 0.45)

var _flag: ColorRect


func _ready() -> void:
	add_to_group("checkpoints")
	collision_layer = 0
	var pole := ColorRect.new()
	pole.size = Vector2(4, 64)
	pole.position = Vector2(-2, -64)
	pole.color = Color(0.8, 0.8, 0.85)
	pole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pole)
	_flag = ColorRect.new()
	_flag.size = Vector2(28, 18)
	_flag.position = Vector2(2, -64)
	_flag.color = OFF
	_flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flag)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 64)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -32)
	add_child(col)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and _flag.color != ON:
		get_tree().call_group("checkpoints", "deactivate")
		_flag.color = ON
		(body as Player).set_spawn(global_position + Vector2(0, -25))


func deactivate() -> void:
	_flag.color = OFF
