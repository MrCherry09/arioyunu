extends AnimatableBody2D
## İki nokta arasında gidip gelen platform. Üstündeki karakteri taşır. Orijin sol üst.

@export var size := Vector2(160, 24)
@export var travel := Vector2(300, 0)   ## Başlangıca göre gidilecek uzaklık
@export var duration := 2.0             ## Tek yön süresi
@export var color := Color(0.4, 0.7, 0.55)


func _ready() -> void:
	var vis := ColorRect.new()
	vis.size = size
	vis.color = color
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vis)
	var shape := RectangleShape2D.new()
	shape.size = size
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = size / 2.0
	add_child(col)

	var start := position
	var tw := create_tween().set_loops().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "position", start + travel, duration)
	tw.tween_interval(0.3)
	tw.tween_property(self, "position", start, duration)
	tw.tween_interval(0.3)
