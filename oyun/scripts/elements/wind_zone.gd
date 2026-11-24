extends Area2D
## İçindeki karakteri sürekli iten rüzgar bölgesi. Orijin sol üst.
## Yukarı akım (force.y < 0) süzülürken daha güçlü etki eder.

@export var size := Vector2(200, 400)
@export var force := Vector2(0, -800)


func _ready() -> void:
	collision_layer = 0
	var bg := ColorRect.new()
	bg.size = size
	bg.color = Color(0.6, 0.85, 1.0, 0.12)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var p := CPUParticles2D.new()
	p.position = size / 2.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = size / 2.0
	p.amount = int(clampf(size.x * size.y / 2500.0, 8, 120))
	p.lifetime = 0.8
	p.gravity = Vector2.ZERO
	p.direction = force.normalized()
	p.spread = 4.0
	p.initial_velocity_min = force.length() * 0.3
	p.initial_velocity_max = force.length() * 0.4
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = Color(0.85, 0.95, 1.0, 0.6)
	add_child(p)

	var shape := RectangleShape2D.new()
	shape.size = size
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = size / 2.0
	add_child(col)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).add_wind(self)


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		(body as Player).remove_wind(self)
