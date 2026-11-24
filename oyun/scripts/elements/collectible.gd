extends Area2D
## Toplanabilir melek tüyü.

signal collected

var _vis: Polygon2D


func _ready() -> void:
	collision_layer = 0
	_vis = Polygon2D.new()
	# Eğik duran basit bir tüy: sivri uçlu yaprak biçimi + ortasında sap
	_vis.polygon = PackedVector2Array([
		Vector2(0, -16), Vector2(6, -8), Vector2(7, 2), Vector2(3, 10),
		Vector2(0, 14), Vector2(-3, 10), Vector2(-7, 2), Vector2(-6, -8),
	])
	_vis.color = Color(0.97, 0.95, 0.85)
	_vis.rotation = 0.5
	add_child(_vis)
	var quill := Line2D.new()
	quill.width = 1.5
	quill.default_color = Color(0.85, 0.7, 0.35)
	quill.points = PackedVector2Array([Vector2(0, -12), Vector2(0, 18)])
	_vis.add_child(quill)
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
