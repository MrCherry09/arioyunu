extends Area2D
## Zıplama yastığı: üstüne gelen karakteri yukarı fırlatır. Orijin sol üst.

@export var size := Vector2(80, 16)
@export var strength := 1000.0

var _top: ColorRect


func _ready() -> void:
	collision_layer = 0
	var base := ColorRect.new()
	base.size = Vector2(size.x, size.y * 0.5)
	base.position = Vector2(0, size.y * 0.5)
	base.color = Color(0.35, 0.3, 0.4)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	_top = ColorRect.new()
	_top.size = Vector2(size.x, size.y * 0.5)
	_top.color = Color(1.0, 0.45, 0.75)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top)

	var shape := RectangleShape2D.new()
	shape.size = size
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = size / 2.0
	add_child(col)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).bounce(strength)
		var tw := create_tween()
		tw.tween_property(_top, "position:y", -10.0, 0.06)
		tw.tween_property(_top, "position:y", 0.0, 0.2)
