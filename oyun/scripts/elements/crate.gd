extends CharacterBody2D
## İtilebilir kutu. Üstüne çıkılabilir, basınç plakasına basar, portaldan geçer.
## Orijin merkezde.

const SIZE := Vector2(56, 56)
const FRICTION := 3000.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _start: Vector2
var _pushed := false


func _ready() -> void:
	add_to_group("crate")
	add_to_group("resettable")
	_start = position
	var vis := ColorRect.new()
	vis.size = SIZE
	vis.position = -SIZE / 2.0
	vis.color = Color(0.62, 0.42, 0.24)
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vis)
	var x := Line2D.new()
	x.width = 3.0
	x.default_color = Color(0.42, 0.27, 0.14)
	var h := SIZE / 2.0 - Vector2(6, 6)
	x.points = PackedVector2Array([-h, h, Vector2(h.x, -h.y), Vector2(-h.x, h.y)])
	add_child(x)
	var shape := RectangleShape2D.new()
	shape.size = SIZE
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)


## Oyuncu yandan iterken her kare çağırır
func push(vx: float) -> void:
	velocity.x = vx
	_pushed = true


func _physics_process(delta: float) -> void:
	velocity.y += gravity * delta
	if not _pushed:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	_pushed = false
	move_and_slide()
	if global_position.y > 900.0:
		reset()


func teleport(to: Vector2) -> void:
	global_position = to
	reset_physics_interpolation()


func reset() -> void:
	position = _start
	velocity = Vector2.ZERO
	reset_physics_interpolation()
