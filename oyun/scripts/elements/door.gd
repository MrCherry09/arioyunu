extends StaticBody2D
## Kapı. İki türü var:
## - channels doluysa: listedeki kanalların HEPSİ açıkken açılır (plaka, şalter, düğme).
##   Kapının üstündeki ışıklar hangi kanalların açık olduğunu gösterir.
## - key_id doluysa: o anahtarı taşıyan oyuncu değince kalıcı olarak açılır.
## İçinde oyuncu veya kutu varken kapanmaz. Orijin sol üst.

@export var size := Vector2(40, 600)
@export var channels: Array = []
@export var key_id := ""

var _states := {}
var _key_opened := false
var _want_open := false
var _open := false
var _vis: ColorRect
var _col: CollisionShape2D
var _area: Area2D
var _lights: Array[ColorRect] = []


func _ready() -> void:
	add_to_group("puzzle")
	add_to_group("resettable")
	_vis = ColorRect.new()
	_vis.size = size
	_vis.color = Color(0.85, 0.7, 0.2) if key_id != "" else Color(0.35, 0.5, 0.75)
	_vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vis)
	if key_id != "":
		var hole := ColorRect.new()
		hole.size = Vector2(10, 18)
		hole.position = Vector2(size.x / 2.0 - 5, size.y - 60)
		hole.color = Color(0.2, 0.15, 0.05)
		hole.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vis.add_child(hole)
	for i in channels.size():
		var l := ColorRect.new()
		l.size = Vector2(14, 10)
		l.position = Vector2(size.x / 2.0 - 7, size.y - 80 + i * 14)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vis.add_child(l)
		_lights.append(l)

	var shape := RectangleShape2D.new()
	shape.size = size
	_col = CollisionShape2D.new()
	_col.shape = shape
	_col.position = size / 2.0
	add_child(_col)

	# Biraz daha geniş algılayıcı: anahtarla yaklaşma ve "içinde biri var mı" kontrolü
	_area = Area2D.new()
	_area.collision_layer = 0
	var ashape := RectangleShape2D.new()
	ashape.size = size + Vector2(16, 0)
	var acol := CollisionShape2D.new()
	acol.shape = ashape
	acol.position = size / 2.0
	_area.add_child(acol)
	add_child(_area)
	_refresh()


func on_channel(ch: String, on: bool) -> void:
	if ch in channels:
		_states[ch] = on
		_refresh()


func on_toggle(_ch: String) -> void:
	pass


func _refresh() -> void:
	var all_on := not channels.is_empty()
	for i in channels.size():
		var on: bool = _states.get(channels[i], false)
		all_on = all_on and on
		_lights[i].color = Color(0.35, 0.95, 0.5) if on else Color(0.9, 0.3, 0.3)
	_want_open = _key_opened or all_on


func _physics_process(_delta: float) -> void:
	if key_id != "" and not _key_opened:
		for b in _area.get_overlapping_bodies():
			if b is Player:
				for k in get_tree().get_nodes_in_group("keys"):
					if k.get("key_id") == key_id and k.get("carried") and not k.get("used"):
						k.call("use", global_position + size / 2.0)
						_key_opened = true
						_refresh()
	if _want_open == _open:
		return
	if _want_open:
		_set_open(true)
	elif not _occupied():
		_set_open(false)


func _occupied() -> bool:
	for b in _area.get_overlapping_bodies():
		if b is Player or b.is_in_group("crate"):
			return true
	return false


func _set_open(open: bool) -> void:
	_open = open
	_col.set_deferred("disabled", open)
	var tw := create_tween()
	tw.tween_property(_vis, "size:y", 6.0 if open else size.y, 0.18)


func reset() -> void:
	_states.clear()
	_key_opened = false
	_refresh()
