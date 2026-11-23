extends Area2D
## Oyuncu değince yeni doğma noktası olur. Orijin, bayrağın zemine değdiği noktadır.

signal activated(checkpoint: Area2D)

const ACTIVE_COLOR := Color(0.35, 0.9, 0.45)

var active := false


func _ready() -> void:
	add_to_group("checkpoint")
	body_entered.connect(_on_body_entered)


func spawn_position() -> Vector2:
	return global_position + Vector2(0, -25)


func _on_body_entered(body: Node2D) -> void:
	if active or not body is CharacterBody2D:
		return
	active = true
	$Flag.color = ACTIVE_COLOR
	activated.emit(self)
