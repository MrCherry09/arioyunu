class_name CrumbleTiles
## Oyun başlarken normal tile katmanlarına boyanmış "crumble" işaretli tile'ları
## bulur, katmandan siler ve yan yana olanları birleştirip FallingPlatform'a çevirir.
## Böylece çöken tile'ı istediğin katmana boyaman yeterli.

const FALLING_SCENE := preload("res://scenes/falling_platform.tscn")


static func convert_all(root: Node) -> void:
	for layer in _static_layers(root):
		_convert_layer(layer)


static func _static_layers(node: Node, out: Array[TileMapLayer] = []) -> Array[TileMapLayer]:
	# Script'li katmanlar (hareketli/çöken platformlar) zaten kendi işini yapıyor
	if node is TileMapLayer and node.get_script() == null:
		out.append(node)
	for child in node.get_children():
		_static_layers(child, out)
	return out


static func _convert_layer(layer: TileMapLayer) -> void:
	if layer.tile_set == null or layer.tile_set.get_custom_data_layer_by_name("crumble") < 0:
		return

	var cells: Array[Vector2i] = []
	for c in layer.get_used_cells():
		var data := layer.get_cell_tile_data(c)
		if data and data.get_custom_data("crumble") == true:
			cells.append(c)
	if cells.is_empty():
		return

	# Satır satır, soldan sağa sırala; yan yana olanlar tek platform olsun
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var run: Array[Vector2i] = []
	for c in cells:
		if not run.is_empty() and (c.y != run[-1].y or c.x != run[-1].x + 1):
			_spawn(layer, run)
			run = []
		run.append(c)
	_spawn(layer, run)


static func _spawn(layer: TileMapLayer, run: Array[Vector2i]) -> void:
	var platform: TileMapLayer = FALLING_SCENE.instantiate()
	platform.tile_set = layer.tile_set
	platform.clear()
	for i in run.size():
		var c := run[i]
		platform.set_cell(Vector2i(i, 0), layer.get_cell_source_id(c), layer.get_cell_atlas_coords(c), layer.get_cell_alternative_tile(c))
		layer.erase_cell(c)
	# Konum add_child'dan önce verilmeli: platform _ready'de başlangıç konumunu kaydediyor
	platform.position = layer.map_to_local(run[0]) - Vector2(layer.tile_set.tile_size) / 2.0
	layer.add_child(platform)
