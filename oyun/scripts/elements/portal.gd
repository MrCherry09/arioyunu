extends Area2D
## Portal: içine giren eşine ışınlanır, hızı korunur.
## crates_only ise sadece kutuları geçirir (turuncu), oyuncu içinden normal geçer.
## Orijin merkezde.

@export var color := Color(0.6, 0.4, 1.0)
@export var crates_only := false

var partner: Area2D  ## Eş portal (test_rooms bağlar)
var _ignore: Array[Node] = []
var _ring: Polygon2D


func _ready() -> void:
	collision_layer = 0
	_ring = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(Vector2(cos(a) * 18.0, sin(a) * 32.0))
	_ring.polygon = pts
	_ring.color = Color(color, 0.85)
	add_child(_ring)
	var inner := Polygon2D.new()
	var ipts := PackedVector2Array()
	for p in pts:
		ipts.append(p * 0.6)
	inner.polygon = ipts
	inner.color = Color(0.1, 0.08, 0.15, 0.9)
	add_child(inner)
	var tw := _ring.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tw.tween_property(_ring, "scale", Vector2(1.1, 1.05), 0.5)
	tw.tween_property(_ring, "scale", Vector2.ONE, 0.5)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 60)
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	body_entered.connect(_on_body_entered)
	body_exited.connect(func(b: Node2D) -> void: _ignore.erase(b))


func _on_body_entered(body: Node2D) -> void:
	if partner == null or body in _ignore:
		return
	var ok := body.is_in_group("crate") or (body is Player and not crates_only)
	if not ok:
		return
	# Eşinden çıkarken hemen geri ışınlanmasın
	(partner as Object).get("_ignore").append(body)
	_teleport.call_deferred(body)


func _teleport(body: Node2D) -> void:
	body.global_position = partner.global_position
	body.reset_physics_interpolation()
