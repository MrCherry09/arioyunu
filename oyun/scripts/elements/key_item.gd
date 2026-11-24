extends Area2D
## Anahtar: alınınca oyuncuyu takip eder, aynı key_id'li kapıya değince kapıyı açar.

@export var key_id := "a"

var carried := false
var used := false
var _start: Vector2
var _player: Node2D
var _vis: Node2D


func _ready() -> void:
	add_to_group("keys")
	add_to_group("resettable")
	collision_layer = 0
	_start = position
	_vis = Node2D.new()
	add_child(_vis)
	var ring := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 10:
		pts.append(Vector2.from_angle(TAU * i / 10.0) * 9.0 + Vector2(-8, 0))
	ring.polygon = pts
	ring.color = Color(1.0, 0.85, 0.2)
	_vis.add_child(ring)
	var bar := ColorRect.new()
	bar.size = Vector2(20, 5)
	bar.position = Vector2(0, -2.5)
	bar.color = Color(1.0, 0.85, 0.2)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vis.add_child(bar)
	var tooth := ColorRect.new()
	tooth.size = Vector2(4, 8)
	tooth.position = Vector2(14, 0)
	tooth.color = Color(1.0, 0.85, 0.2)
	tooth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vis.add_child(tooth)
	var shape := CircleShape2D.new()
	shape.radius = 18.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not carried and not used:
		carried = true
		_player = body


func _physics_process(_delta: float) -> void:
	if carried and not used and is_instance_valid(_player):
		# Oyuncunun omzunun üstünde süzülsün
		global_position = global_position.lerp(_player.global_position + Vector2(-26, -44), 0.2)


func use(target: Vector2) -> void:
	used = true
	var tw := create_tween()
	tw.tween_property(self, "global_position", target, 0.25)
	tw.tween_callback(hide)


func reset() -> void:
	carried = false
	used = false
	_player = null
	position = _start
	show()
	reset_physics_interpolation()
