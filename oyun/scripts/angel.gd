extends Node2D
## Oyuncuyu takip eden melek (şimdilik görsel takipçi). Işık topları ona uçar ve heal() çağırır.
## Arkasında hafifçe süzülür, oyuncunun baktığı yönün tersinde durur.

@export var max_light := 100.0

var player: Player
var light := 0.0

var _sprite: Sprite2D
var _t := 0.0
var _facing := 1.0

const FOLLOW_OFFSET := Vector2(-46, -34)
const FOLLOW_SPEED := 6.0


func _ready() -> void:
	add_to_group("angel")
	z_index = 9
	_sprite = PixelArt.sprite(PixelArt.MELEK, PixelArt.MELEK_PAL)
	_sprite.offset.y += 8  # gövde ortası yaklaşık orijinde
	add_child(_sprite)
	if player:
		player.respawned.connect(snap_to_player)
		snap_to_player()


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_t += delta
	if absf(player.velocity.x) > 10.0:
		_facing = signf(player.velocity.x)
	var target := player.global_position + Vector2(FOLLOW_OFFSET.x * _facing, FOLLOW_OFFSET.y)
	target.y += sin(_t * 2.4) * 6.0
	global_position = global_position.lerp(target, 1.0 - exp(-FOLLOW_SPEED * delta))
	# flip_h yerine ölçek: aksesuarlar (taç, fener) da aynalansın
	_sprite.scale.x = PixelArt.PIXEL * (-1.0 if _facing < 0.0 else 1.0)
	# Piksel ızgarasına otursun (titrek alt piksel kaymaları olmasın)
	_sprite.global_position = global_position.snapped(Vector2.ONE * PixelArt.PIXEL)


## Meleğe piksel art bir aksesuar tak (ör. çiçek tacı). col/row: melek şablonundaki sol üst köşe.
func add_accessory(id: String, rows: Array, palette: Dictionary, col: int, row: int) -> void:
	remove_accessory(id)
	var acc := Sprite2D.new()
	acc.name = id
	acc.texture = PixelArt.texture(rows, palette)
	acc.centered = false
	var tex_size := _sprite.texture.get_size()
	acc.position = _sprite.offset - tex_size / 2.0 + Vector2(col, row)
	_sprite.add_child(acc)


func remove_accessory(id: String) -> void:
	var old := _sprite.get_node_or_null(id)
	if old:
		old.free()


func snap_to_player() -> void:
	if player:
		global_position = player.global_position + FOLLOW_OFFSET
		reset_physics_interpolation()


## Işık topları çağırır
func heal(amount: float) -> void:
	light = minf(light + amount, max_light)
	# Beyaz parlama
	_sprite.self_modulate = Color(2.0, 2.0, 2.0)
	var tw := create_tween()
	tw.tween_property(_sprite, "self_modulate", Color.WHITE, 0.35)
	# Yükselen "+10"
	var l := Label.new()
	l.text = "+%d" % int(amount)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.position = Vector2(-12, -70)
	add_child(l)
	var tw2 := l.create_tween().set_parallel()
	tw2.tween_property(l, "position:y", -100.0, 0.7)
	tw2.tween_property(l, "modulate:a", 0.0, 0.7)
	tw2.chain().tween_callback(l.queue_free)
