extends Area2D
## Sağa sola dolaşan düşman. Üstüne zıplayınca (veya dash/çakılma ile) ölür,
## yandan değersen sen ölürsün. Orijin ayak hizasında.

@export var patrol := 220.0   ## Başlangıçtan sağa doğru dolaşma mesafesi
@export var speed := 90.0

const SIZE := Vector2(40, 28)

var _start: Vector2
var _dir := 1.0
var _dead := false
var _body: Node2D


func _ready() -> void:
	add_to_group("resettable")
	collision_layer = 0
	_start = position
	_body = Node2D.new()
	add_child(_body)
	var vis := ColorRect.new()
	vis.size = SIZE
	vis.position = Vector2(-SIZE.x / 2.0, -SIZE.y)
	vis.color = Color(0.85, 0.2, 0.3)
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(vis)
	var eye := ColorRect.new()
	eye.size = Vector2(6, 8)
	eye.position = Vector2(8, -22)
	eye.color = Color.WHITE
	eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(eye)

	var shape := RectangleShape2D.new()
	shape.size = SIZE - Vector2(4, 0)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -SIZE.y / 2.0)
	add_child(col)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	position.x += _dir * speed * delta
	if position.x > _start.x + patrol:
		_dir = -1.0
	elif position.x < _start.x:
		_dir = 1.0
	_body.scale.x = _dir


func _on_body_entered(body: Node2D) -> void:
	if _dead or not body is Player:
		return
	var p := body as Player
	var stomp := p.velocity.y > 0.0 and p.global_position.y < global_position.y - SIZE.y
	if p.is_attacking() or stomp:
		_kill()
		if stomp or p.velocity.y > 0.0:
			p.bounce(420.0)
	else:
		p.die.call_deferred()


func _kill() -> void:
	_dead = true
	set_deferred("monitoring", false)
	var tw := create_tween()
	tw.tween_property(_body, "scale:y", 0.15, 0.1)
	tw.tween_interval(0.25)
	tw.tween_callback(hide)


func reset() -> void:
	_dead = false
	position = _start
	_dir = 1.0
	_body.scale = Vector2.ONE
	show()
	set_deferred("monitoring", true)
