extends StaticBody2D
## Üstüne basınca titreyip çöken, bir süre sonra geri gelen platform. Orijin sol üst.

@export var size := Vector2(120, 24)
@export var shake_time := 0.45
@export var respawn_time := 2.0
@export var color := Color(0.75, 0.6, 0.4)

var _vis: ColorRect
var _col: CollisionShape2D
var _busy := false
var _gen := 0  ## reset() eski zamanlayıcıları geçersiz kılsın diye


func _ready() -> void:
	add_to_group("resettable")
	_vis = ColorRect.new()
	_vis.size = size
	_vis.color = color
	_vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vis)
	var shape := RectangleShape2D.new()
	shape.size = size
	_col = CollisionShape2D.new()
	_col.shape = shape
	_col.position = size / 2.0
	add_child(_col)

	# Üst yüzeye ince bir algılayıcı: basıldığını anlamak için
	var sensor := Area2D.new()
	sensor.collision_layer = 0
	var sshape := RectangleShape2D.new()
	sshape.size = Vector2(size.x - 4.0, 6.0)
	var scol := CollisionShape2D.new()
	scol.shape = sshape
	scol.position = Vector2(size.x / 2.0, -3.0)
	sensor.add_child(scol)
	add_child(sensor)
	sensor.body_entered.connect(_on_sensor_body_entered)


func _on_sensor_body_entered(body: Node2D) -> void:
	if body is Player and not _busy:
		_crumble()


func _crumble() -> void:
	_busy = true
	_gen += 1
	var g := _gen
	var t := 0.0
	while t < shake_time:
		await get_tree().physics_frame
		if g != _gen:
			return
		t += get_physics_process_delta_time()
		_vis.position.x = randf_range(-3.0, 3.0)
	_vis.position.x = 0.0
	_set_solid(false)
	await get_tree().create_timer(respawn_time, false, true).timeout
	if g == _gen:
		reset()


func _set_solid(on: bool) -> void:
	_col.set_deferred("disabled", not on)
	_vis.visible = on


func reset() -> void:
	_gen += 1
	_busy = false
	_vis.position.x = 0.0
	_set_solid(true)
