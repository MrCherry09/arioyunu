@tool
extends TileMapLayer
## Tile'larla boyanan hareketli platform.
##
## BAŞLANGIÇ: platformun sahnedeki konumu (platformu sürükle).
## BİTİŞ: platformun altındaki "End" Marker2D'si. Editörde seçip sürükle.
## ARA NOKTALAR: altına daha fazla Marker2D eklersen platform sırayla hepsinden geçer
## (sahne ağacındaki sıraya göre).
##
## Editörde rota çizgiyle, her durak da yarı saydam kutuyla gösterilir.

@export var duration := 2.0                     ## İki nokta arası süre (saniye)
@export var pause := 0.4                        ## Her noktada bekleme süresi
@export var loop := false                       ## Kapalı: gidip geri döner. Açık: son noktadan başa döner
@export_range(0.0, 1.0) var start_phase := 0.0  ## Döngünün neresinden başlasın
## Eski sürüm uyumluluğu: hiç Marker2D yoksa bu ofset kullanılır
@export var move_offset := Vector2(320, 0)

const PATH_COLOR := Color(0.4, 0.7, 1.0)

var _origin: Vector2
var _route: Array[Vector2] = []
var _t := 0.0
var _drawn_points: Array[Vector2] = []


func _ready() -> void:
	# Hareket eden tile katmanının oyuncuyu taşıyabilmesi için gerekli
	use_kinematic_bodies = true
	if Engine.is_editor_hint():
		_ensure_end_marker.call_deferred()
		return
	_origin = position
	_route = _build_route(_points())
	_t = start_phase * _cycle()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _route.size() < 2:
		return
	_t += delta
	var step := pause + duration
	var local := fmod(_t, _cycle())
	var i := mini(int(local / step), _route.size() - 1)
	var s := local - i * step
	var f := 0.0 if s < pause else smoothstep(0.0, 1.0, (s - pause) / duration)
	position = _origin + _route[i].lerp(_route[(i + 1) % _route.size()], f)


func _process(_delta: float) -> void:
	# Editörde marker sürüklendikçe rotayı yeniden çiz
	if Engine.is_editor_hint() and _points() != _drawn_points:
		queue_redraw()


## Başlangıç (0,0) + Marker2D çocuklarının konumları, platforma göre yerel
func _points() -> Array[Vector2]:
	var pts: Array[Vector2] = [Vector2.ZERO]
	for child in get_children():
		if child is Marker2D:
			pts.append(child.position)
	if pts.size() == 1:
		pts.append(move_offset)
	return pts


func _build_route(pts: Array[Vector2]) -> Array[Vector2]:
	var route := pts.duplicate()
	if not loop:
		# Gidip gelme: A B C -> A B C B (sonra tekrar A)
		for j in range(pts.size() - 2, 0, -1):
			route.append(pts[j])
	return route


func _cycle() -> float:
	return _route.size() * (pause + duration)


## Editörde yeni eklenen platformda sürüklenebilir bir "End" noktası oluştur
func _ensure_end_marker() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child is Marker2D:
			return
	var scene_root := get_tree().edited_scene_root
	# Platform sahnesinin kendisini düzenlerken ekleme; her örnek kendi noktasını alsın
	if scene_root == null or scene_root == self:
		return
	var end := Marker2D.new()
	end.name = "End"
	end.gizmo_extents = 24.0
	end.position = move_offset
	add_child(end)
	end.owner = scene_root


func _draw() -> void:
	if not Engine.is_editor_hint() or tile_set == null:
		return
	var pts := _points()
	_drawn_points = pts
	var used := get_used_rect()
	var ts := Vector2(tile_set.tile_size)
	var rect := Rect2(Vector2(used.position) * ts, Vector2(used.size) * ts)
	var center := rect.get_center()
	for j in pts.size():
		var p := pts[j]
		if j > 0:
			draw_rect(Rect2(rect.position + p, rect.size), Color(PATH_COLOR, 0.25), true)
			draw_rect(Rect2(rect.position + p, rect.size), Color(PATH_COLOR, 0.8), false, 2.0)
		var next := j + 1
		if next < pts.size():
			draw_line(center + p, center + pts[next], Color(PATH_COLOR, 0.8), 2.0)
		elif loop and pts.size() > 2:
			draw_dashed_line(center + p, center + pts[0], Color(PATH_COLOR, 0.6), 2.0, 8.0)
