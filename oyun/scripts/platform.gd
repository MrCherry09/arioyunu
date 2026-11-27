@tool
extends StaticBody2D
## Dikdörtgen platform. Boyut ve renk editörde Inspector'dan değiştirilebilir. Orijin sol üst köşede.
## style doluysa (green_valley, winter, snow, heaven) tileset parçalarıyla çizilir (bkz. TileStyle);
## boşsa düz renk. Çarpışma her iki durumda da aynıdır.
## one_way: alttan geçilir, üstüne basılır (S + Space ile aşağı inilir).
## friction_mult: 1'den küçükse buz gibi kaygan. conveyor_speed: yürüyen bant hızı.

@export var size := Vector2(200, 32):
	set(value):
		size = value
		if is_node_ready():
			_apply()

@export var color := Color(0.36, 0.42, 0.52):
	set(value):
		color = value
		if is_node_ready():
			_apply()

@export var one_way := false:
	set(value):
		one_way = value
		if is_node_ready():
			_apply()

@export var friction_mult := 1.0

@export_group("Tile görünümü")
@export_enum("none", "green_valley", "winter", "snow", "heaven") var style := "":
	set(value):
		style = value
		if is_node_ready():
			_apply()
@export var fill_only := false:  ## Sadece iç dolgu (oda duvarı/tavanı gibi kenarsız yüzeyler)
	set(value):
		fill_only = value
		queue_redraw()
@export_range(0.0, 1.0) var decor := 0.0:  ## Üst yüzeye serpilen süs yoğunluğu
	set(value):
		decor = value
		queue_redraw()
@export_group("")

## Süs konmayacak yerel x aralıkları [[x0, x1], ...]: oyun nesneleri süsün arkasında kalmasın
var decor_skip: Array = []:
	set(value):
		decor_skip = value
		queue_redraw()

@export var conveyor_speed := 0.0:
	set(value):
		conveyor_speed = value
		constant_linear_velocity = Vector2(conveyor_speed, 0.0)


func _ready() -> void:
	_apply()


func _apply() -> void:
	var visual := $Visual as ColorRect
	visual.position = Vector2.ZERO
	visual.size = size
	visual.color = color
	# Tile stili kullanılabiliyorsa düz rengi gizle, _draw tile'ları çizsin
	var tiled := style not in ["", "none"] and TileStyle.resolve(style) != ""
	visual.visible = not tiled
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()

	var shape := RectangleShape2D.new()
	shape.size = size
	var col := $Shape as CollisionShape2D
	col.shape = shape
	col.position = size / 2.0
	col.one_way_collision = one_way
	# Tek yönlü platformlar ayrı katmanda: oyuncu aşağı inerken bu katmanı kapatır
	collision_layer = 2 if one_way else 1
	if one_way:
		add_to_group("one_way")
	elif is_in_group("one_way"):
		remove_from_group("one_way")


func _draw() -> void:
	if style in ["", "none"]:
		return
	# Aynı odadaki platformlar farklı görünsün, ama her açılışta aynı kalsın
	var seed := int(position.x) * 73856093 ^ int(position.y) * 19349663
	TileStyle.draw_block(self, size, style, fill_only, decor, seed, decor_skip)
