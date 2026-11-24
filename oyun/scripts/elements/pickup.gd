extends Area2D
## Yerden alınan hikâye eşyası (ip, odun...). Oyuncunun envanterine (player.items) eklenir.
## Oda yeniden kurulunca reset() ile geri gelir. Orijin ayak hizasında.

@export var item_id := ""

var template: Array = []
var palette: Dictionary = {}
var _sprite: Sprite2D
var _t := 0.0


func _ready() -> void:
	add_to_group("story_npcs")  # oda girişinde sıfırlanacaklar
	collision_layer = 0
	_sprite = PixelArt.sprite(template, palette)
	add_child(_sprite)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 40)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -16)
	add_child(col)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	_sprite.position.y = -PixelArt.PIXEL if fmod(_t, 1.0) < 0.5 else 0.0


func _on_body_entered(body: Node2D) -> void:
	if not visible or not body is Player:
		return
	var p := body as Player
	p.items[item_id] = p.items.get(item_id, 0) + 1
	hide()
	set_deferred("monitoring", false)


func reset() -> void:
	show()
	set_deferred("monitoring", true)
