extends CharacterBody2D
## Kaçan hayvan (ör. kuzu). Üç durum:
##   "flee":   oyuncu yaklaşınca ondan uzağa koşar (oyuncudan biraz yavaş). Zıplayamaz; çitler tutar.
##             Duvara/çite sıkışınca durur; oyuncu dokununca yakalanır (caught sinyali).
##   "follow": oyuncuyu arkasından takip eder; önüne engel çıkarsa zıplar, çok geride kalırsa yanına ışınlanır.
##   "stay":   olduğu yerde durur (eve teslim edilince).
## Orijin ayak hizasında.

signal caught(node: Node)

@export var look := "lamb"
@export var flee_speed := 230.0
@export var flee_range := 260.0

var mode := "flee"
var player: Player
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _sprite: Sprite2D
var _t := 0.0
var _start: Vector2


func _ready() -> void:
	add_to_group("critters")
	collision_layer = 0
	collision_mask = 1 | 2   # zemin + tek yönlü platformlar
	_start = position
	var lk := PixelArt.look(look)
	_sprite = PixelArt.sprite(lk[0], lk[1])
	add_child(_sprite)
	var h: float = lk[0].size() * PixelArt.PIXEL
	var shape := RectangleShape2D.new()
	shape.size = Vector2(30, h)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -h / 2.0)
	add_child(col)
	# Oyuncuya dokunmayı algılayan alan (gövde çarpışmaz, sadece yakalama için)
	var area := Area2D.new()
	area.collision_layer = 0
	var ashape := RectangleShape2D.new()
	ashape.size = Vector2(44, h + 10)
	var acol := CollisionShape2D.new()
	acol.shape = ashape
	acol.position = Vector2(0, -h / 2.0)
	area.add_child(acol)
	add_child(area)
	area.body_entered.connect(_on_touch)


func _physics_process(delta: float) -> void:
	_t += delta
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
	if not is_on_floor():
		velocity.y += gravity * delta
	match mode:
		"flee":
			_flee()
		"follow":
			_follow()
		_:
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
	move_and_slide()
	if absf(velocity.x) > 10.0:
		_sprite.flip_h = velocity.x < 0.0
	_sprite.position.y = -PixelArt.PIXEL if absf(velocity.x) > 10.0 and fmod(_t, 0.25) < 0.12 else 0.0


func _flee() -> void:
	if player == null:
		return
	var dx := global_position.x - player.global_position.x
	var dy := absf(global_position.y - player.global_position.y)
	if absf(dx) < flee_range and dy < 120.0:
		velocity.x = signf(dx if dx != 0.0 else 1.0) * flee_speed
		if is_on_wall():  # köşeye sıkıştı
			velocity.x = 0.0
	else:
		# Ara sıra otla, yavaşça dolaş
		velocity.x = 40.0 * sin(_t * 0.7)


func _follow() -> void:
	if player == null:
		return
	var target := player.global_position.x - 70.0 * signf(player.velocity.x if absf(player.velocity.x) > 5.0 else 1.0)
	var dx := target - global_position.x
	var dist := global_position.distance_to(player.global_position)
	if dist > 700.0:
		# Çok geride kaldı (ör. oyuncu yükseğe tırmandı): yanına ışınlan
		global_position = player.global_position + Vector2(-60, 20)
		velocity = Vector2.ZERO
		reset_physics_interpolation()
		return
	velocity.x = clampf(dx * 4.0, -340.0, 340.0) if absf(dx) > 12.0 else 0.0
	var below := player.global_position.y < global_position.y - 70.0
	if is_on_floor() and (is_on_wall() and absf(dx) > 20.0 or below and absf(dx) < 160.0):
		velocity.y = -620.0


func _on_touch(body: Node2D) -> void:
	if body is Player and mode == "flee":
		mode = "follow"
		caught.emit(self)


func stay_at(pos: Vector2) -> void:
	mode = "stay"
	global_position = pos
	velocity = Vector2.ZERO
	reset_physics_interpolation()
