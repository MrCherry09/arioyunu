extends Area2D
## Toplanabilir bal damlası.

signal collected

var _vis: Polygon2D


func _ready() -> void:
	collision_layer = 0
	_vis = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(Vector2.from_angle(TAU * i / 6.0 + PI / 6.0) * 12.0)
	_vis.polygon = pts
	_vis.color = Color(1.0, 0.78, 0.15)
	add_child(_vis)
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	var tw := _vis.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tw.tween_property(_vis, "position:y", -5.0, 0.6)
	tw.tween_property(_vis, "position:y", 0.0, 0.6)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	set_deferred("monitoring", false)
	collected.emit()
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "scale", Vector2(1.8, 1.8), 0.2)
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(queue_free)
