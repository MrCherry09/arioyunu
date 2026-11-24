extends Area2D
## Odanın çıkış kapısı. Kilitliyken soluk görünür ve çalışmaz. Orijin ayak hizasında.

signal reached

var locked := false:
	set(value):
		locked = value
		if _door:
			_door.color = Color(0.4, 0.45, 0.4, 0.5) if locked else Color(0.3, 0.9, 0.45)

var _door: ColorRect


func _ready() -> void:
	collision_layer = 0
	_door = ColorRect.new()
	_door.size = Vector2(48, 72)
	_door.position = Vector2(-24, -72)
	_door.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_door)
	locked = locked  # rengi uygula
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 72)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -36)
	add_child(col)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not locked:
		reached.emit()


## Kilit açıldığında karakter zaten kapının içindeyse de çalışsın
func unlock() -> void:
	locked = false
	for b in get_overlapping_bodies():
		if b is Player:
			reached.emit()
