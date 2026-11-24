@tool
extends StaticBody2D
## Düz renkli dikdörtgen platform. Boyut ve renk editörde Inspector'dan değiştirilebilir.
## Orijin sol üst köşededir.
## one_way: alttan geçilir, üstüne basılır (S + Space ile aşağı inilir).
## friction_mult: 1'den küçükse buz gibi kaygan. conveyor_speed: yürüyen bant hızı.

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

@export var one_way := false:
	set(value):
		one_way = value
		if is_node_ready():
			_apply()

@export var friction_mult := 1.0

@export var conveyor_speed := 0.0:
	set(value):
		conveyor_speed = value
		constant_linear_velocity = Vector2(conveyor_speed, 0.0)


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
	col.one_way_collision = one_way
	# Tek yönlü platformlar ayrı katmanda: oyuncu aşağı inerken bu katmanı kapatır
	collision_layer = 2 if one_way else 1
	if one_way:
		add_to_group("one_way")
	elif is_in_group("one_way"):
		remove_from_group("one_way")
