extends StaticBody2D
## Renk bloğu: aynı kanaldaki şalter her çekildiğinde katı/hayalet arasında değişir.
## İçinde oyuncu veya kutu varken katılaşmaz, çıkmasını bekler. Orijin sol üst.

@export var size := Vector2(60, 24)
@export var channel := ""
@export var solid_at_start := true
@export var color := Color(0.9, 0.3, 0.35)

var _solid := true
var _want := true
var _fill: ColorRect
var _col: CollisionShape2D
var _area: Area2D


func _ready() -> void:
	add_to_group("puzzle")
	add_to_group("resettable")
	_fill = ColorRect.new()
	_fill.size = size
	_fill.color = color
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fill)
	var outline := Line2D.new()
	outline.width = 2.0
	outline.default_color = color.lightened(0.3)
	outline.points = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y), Vector2.ZERO])
	add_child(outline)
	var shape := RectangleShape2D.new()
	shape.size = size
	_col = CollisionShape2D.new()
	_col.shape = shape
	_col.position = size / 2.0
	add_child(_col)
	_area = Area2D.new()
	_area.collision_layer = 0
	var ashape := RectangleShape2D.new()
	ashape.size = size - Vector2(2, 2)
	var acol := CollisionShape2D.new()
	acol.shape = ashape
	acol.position = size / 2.0
	_area.add_child(acol)
	add_child(_area)
	_want = solid_at_start
	_apply(solid_at_start)


func on_channel(_ch: String, _on: bool) -> void:
	pass


func on_toggle(ch: String) -> void:
	if ch == channel:
		_want = not _want


func _physics_process(_delta: float) -> void:
	if _want == _solid:
		return
	if _want and _occupied():
		_fill.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 60.0)  # bekliyor: yanıp söner
		return
	_apply(_want)


func _occupied() -> bool:
	for b in _area.get_overlapping_bodies():
		if b is Player or b.is_in_group("crate"):
			return true
	return false


func _apply(s: bool) -> void:
	_solid = s
	_col.set_deferred("disabled", not s)
	_fill.modulate.a = 1.0
	_fill.color.a = 1.0 if s else 0.15


func reset() -> void:
	_want = solid_at_start
	_apply(solid_at_start)
