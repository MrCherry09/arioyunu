extends Node2D
## Oyuncuyu arkasından süzülerek takip eden basit takipçi (ör. kayıp ruh).
## Piksel art şablonuyla çizilir, saydamlığı nabız gibi atar.

var player: Player
var template: Array = []
var palette: Dictionary = {}
var offset := Vector2(-80, -30)

var _sprite: Sprite2D
var _t := 0.0


func _ready() -> void:
	z_index = 8
	_sprite = PixelArt.sprite(template, palette)
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_t += delta
	var face := -1.0 if player.velocity.x < -10.0 else 1.0
	var target := player.global_position + Vector2(offset.x * face, offset.y + sin(_t * 2.0) * 8.0)
	global_position = global_position.lerp(target, 1.0 - exp(-3.5 * delta))
	_sprite.global_position = global_position.snapped(Vector2.ONE * PixelArt.PIXEL)
	_sprite.modulate.a = 0.7 + sin(_t * 3.0) * 0.2


## Kapıya varınca yukarı süzülüp kaybolur
func ascend() -> void:
	player = null
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "global_position:y", global_position.y - 260.0, 1.6).set_ease(Tween.EASE_IN)
	tw.tween_property(_sprite, "modulate:a", 0.0, 1.6)
	tw.chain().tween_callback(queue_free)
