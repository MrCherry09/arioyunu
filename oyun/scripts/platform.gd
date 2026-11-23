@tool
extends StaticBody2D
## Düz renkli dikdörtgen platform. Boyut ve renk editörde Inspector'dan değiştirilebilir.
## Orijin sol üst köşededir.

@export var size := Vector2(200, 32):
	set(value):
		size = value
		if is_node_ready():
			_apply()

@export var color := Color(0.36, 0.42, 0.52):
	set(value):
		color = value
		if is_node_ready():
			_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	var visual := $Visual as ColorRect
	visual.position = Vector2.ZERO
	visual.size = size
	visual.color = color

	var shape := RectangleShape2D.new()
	shape.size = size
	var col := $Shape as CollisionShape2D
	col.shape = shape
	col.position = size / 2.0
