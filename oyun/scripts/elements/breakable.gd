extends StaticBody2D
## Dash veya yere çakılma ile kırılan blok. Oyuncu ölünce geri gelir. Orijin sol üst.

@export var size := Vector2(50, 30)
@export var color := Color(0.8, 0.5, 0.25)

var _col: CollisionShape2D
var _broken := false


func _ready() -> void:
	add_to_group("resettable")
	var vis := ColorRect.new()
	vis.size = size
	vis.color = color
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vis)
	# Çatlak işareti
	var crack := Line2D.new()
	crack.width = 2.0
	crack.default_color = color.darkened(0.45)
	crack.points = PackedVector2Array([
		Vector2(size.x * 0.2, 0), Vector2(size.x * 0.45, size.y * 0.45),
		Vector2(size.x * 0.3, size.y * 0.7), Vector2(size.x * 0.6, size.y),
	])
	add_child(crack)
	var shape := RectangleShape2D.new()
	shape.size = size
	_col = CollisionShape2D.new()
	_col.shape = shape
	_col.position = size / 2.0
	add_child(_col)


func smash() -> void:
	if _broken:
		return
	_broken = true
	_col.set_deferred("disabled", true)
	hide()
	# Küçük parçalar saçılsın
	for i in 4:
		var bit := ColorRect.new()
		bit.size = size / 3.0
		bit.color = color
		bit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bit.position = position + size / 2.0 - bit.size / 2.0  # aynı ebeveyn → yerel koordinat
		get_parent().add_child(bit)
		var to := bit.position + Vector2(randf_range(-60, 60), randf_range(-50, 40))
		var tw := bit.create_tween().set_parallel()
		tw.tween_property(bit, "position", to, 0.4)
		tw.tween_property(bit, "modulate:a", 0.0, 0.4)
		tw.chain().tween_callback(bit.queue_free)


func reset() -> void:
	_broken = false
	_col.set_deferred("disabled", false)
	show()
