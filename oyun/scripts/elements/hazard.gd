extends Area2D
## Diken şeridi: değince karakter ölür. Orijin sol üst.

@export var size := Vector2(128, 24)
@export var pointing_down := false  ## Tavana asılı dikenler için true
@export var color := Color(0.85, 0.85, 0.9)


func _ready() -> void:
	collision_layer = 0
	var h := size.y
	var count := maxi(1, roundi(size.x / 24.0))
	var tw := size.x / count
	var base_y := 0.0 if pointing_down else h
	var tip_y := h if pointing_down else 0.0
	var pts := PackedVector2Array([Vector2(0, base_y)])
	for i in count:
		pts.append(Vector2(i * tw + tw / 2.0, tip_y))
		pts.append(Vector2((i + 1) * tw, base_y))
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.color = color
	add_child(poly)

	# Çarpışma şekli uçlara kadar uzanmaz, biraz affedici olsun
	var shape := RectangleShape2D.new()
	shape.size = Vector2(size.x - 8.0, h * 0.55)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(size.x / 2.0, h * (0.28 if pointing_down else 0.72))
	add_child(col)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).die.call_deferred()
