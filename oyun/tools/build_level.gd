extends SceneTree
## İLK KURULUM ARACI. TileSet'i, platform sahnelerini ve örnek parkuru üretir:
##   res://tiles/tileset.tres
##   res://scenes/moving_platform.tscn, res://scenes/falling_platform.tscn
##   res://scenes/level.tscn
##
## Bu dosyalar artık editörde elle düzenlenmek için var. Script, var olan dosyaların
## üstüne YAZMAZ. Hepsini baştan üretmek için (elle yapılan değişiklikler silinir):
##   godot --headless --path oyun --script res://tools/build_level.gd -- --force
##
## Koordinatlar tile cinsindendir (1 tile = 32 px). y aşağı doğru artar.
## Zıplama: en fazla ~4 tile yukarı, düz zeminde ~10 tile uzağa.

const T := 32
const BOTTOM := 19  ## Zemin dolgusunun indiği en alt satır

const GROUND_TOP := Vector2i(0, 0)
const GROUND := Vector2i(1, 0)
const MOVING := Vector2i(2, 0)
const CRUMBLE := Vector2i(3, 0)
const SPIKE := Vector2i(4, 0)
const ONEWAY := Vector2i(5, 0)

const TILESET_PATH := "res://tiles/tileset.tres"
const MOVING_PATH := "res://scenes/moving_platform.tscn"
const FALLING_PATH := "res://scenes/falling_platform.tscn"
const LEVEL_PATH := "res://scenes/level.tscn"

var CheckpointScene := load("res://scenes/checkpoint.tscn")
var GoalScene := load("res://scenes/goal.tscn")

var force := "--force" in OS.get_cmdline_user_args()
var ts: TileSet
var moving_scene: PackedScene
var falling_scene: PackedScene
var level: Node2D
var ground: TileMapLayer
var oneway: TileMapLayer
var hazards: TileMapLayer
var _count := {}


func _init() -> void:
	if not force and FileAccess.file_exists(LEVEL_PATH):
		print("Dosyalar zaten var, üzerine yazılmadı. Baştan üretmek için: -- --force")
		quit()
		return

	ts = _make_tileset()
	_save(ts, TILESET_PATH)
	ts = ResourceLoader.load(TILESET_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)

	moving_scene = _make_piece_scene("MovingPlatform", "res://scripts/moving_platform.gd", MOVING, MOVING_PATH)
	falling_scene = _make_piece_scene("FallingPlatform", "res://scripts/falling_platform.gd", CRUMBLE, FALLING_PATH)

	level = Node2D.new()
	level.name = "Level"
	ground = _layer("Ground")
	oneway = _layer("OneWay")
	hazards = _layer("Hazards")
	var movers := Node2D.new()
	movers.name = "Platforms"
	_add(movers)
	var markers := Node2D.new()
	markers.name = "Checkpoints"
	_add(markers)

	_build()

	var scene := PackedScene.new()
	scene.pack(level)
	_save(scene, LEVEL_PATH)
	quit()


# ---------------------------------------------------------------- PARKUR
func _build() -> void:
	spawn(2, 15)

	# --- Bölüm 1: ısınma, çukur ve dikenler
	ground_block(-12, 20, 15)
	plat(24, 13, 4)
	plat(31, 11, 4)
	plat(38, 13, 5)
	ground_block(45, 70, 15)
	spikes(52, 14, 2)
	spikes(60, 14, 3)
	oneway_plat(58, 11, 7)            # dikenlerin üstünden alternatif yol
	checkpoint(67, 15)

	# --- Bölüm 2: yatay hareketli platformlar
	moving(72, 15, 4, Vector2i(10, 0), 2.2)
	plat(90, 15, 5)
	moving(97, 14, 3, Vector2i(12, 0), 2.6)
	ground_block(116, 140, 15)
	spikes(124, 14, 3)
	checkpoint(137, 15)

	# --- Bölüm 3: dikey asansörlerle tırmanış
	moving(142, 15, 3, Vector2i(0, -8), 2.5)
	plat(147, 7, 8)
	spikes(150, 6, 2)
	moving(157, 7, 3, Vector2i(0, -6), 2.2)
	plat(162, 1, 10)
	checkpoint(169, 1)

	# --- Bölüm 4: çöken platformlarla iniş
	falling(174, 3, 3)
	falling(179, 5, 3)
	falling(184, 7, 3)
	falling(189, 9, 3)
	plat(194, 11, 6)
	ground_block(202, 230, 15)
	spikes(208, 14, 2)
	spikes(214, 14, 2)
	oneway_plat(207, 12, 10)
	checkpoint(227, 15)

	# --- Bölüm 5: karışık final
	moving(232, 15, 3, Vector2i(8, 0), 1.8)
	falling(246, 14, 2)
	moving(250, 14, 3, Vector2i(0, -6), 2.0)
	plat(255, 8, 3)
	falling(260, 8, 2)
	falling(264, 9, 2)
	moving(268, 10, 3, Vector2i(8, 0), 1.6)
	ground_block(282, 300, 12)
	spikes(288, 11, 2)
	goal(297, 12)


# ---------------------------------------------------------------- YARDIMCILAR
func ground_block(x0: int, x1: int, top: int) -> void:
	for x in range(x0, x1 + 1):
		ground.set_cell(Vector2i(x, top), 0, GROUND_TOP)
		for y in range(top + 1, BOTTOM + 1):
			ground.set_cell(Vector2i(x, y), 0, GROUND)


func plat(x: int, y: int, w: int) -> void:
	for i in w:
		ground.set_cell(Vector2i(x + i, y), 0, GROUND_TOP)


func spikes(x: int, y: int, w: int) -> void:
	for i in w:
		hazards.set_cell(Vector2i(x + i, y), 0, SPIKE)


func oneway_plat(x: int, y: int, w: int) -> void:
	for i in w:
		oneway.set_cell(Vector2i(x + i, y), 0, ONEWAY)


func moving(x: int, y: int, w: int, offset: Vector2i, dur: float) -> void:
	var n := _piece(moving_scene, "Moving", MOVING, x, y, w)
	n.set("duration", dur)
	# Bitiş noktası: editörde sürüklenebilir Marker2D
	var end := Marker2D.new()
	end.name = "End"
	end.gizmo_extents = 24.0
	end.position = Vector2(offset * T)
	_add(end, n)


func falling(x: int, y: int, w: int) -> void:
	_piece(falling_scene, "Falling", CRUMBLE, x, y, w)


func checkpoint(x: int, y: int) -> void:
	var cp: Node2D = CheckpointScene.instantiate()
	cp.name = _next_name("Checkpoint")
	cp.position = Vector2(x * T + T / 2, y * T)
	_add(cp, level.get_node("Checkpoints"))


func spawn(x: int, y: int) -> void:
	var m := Marker2D.new()
	m.name = "Spawn"
	m.position = Vector2(x * T + T / 2, y * T)
	_add(m)


func goal(x: int, y: int) -> void:
	var g: Node2D = GoalScene.instantiate()
	g.name = "Goal"
	g.position = Vector2(x * T + T / 2, y * T)
	_add(g)


func _piece(scene: PackedScene, prefix: String, tile: Vector2i, x: int, y: int, w: int) -> TileMapLayer:
	var n: TileMapLayer = scene.instantiate()
	n.name = _next_name(prefix)
	n.position = Vector2(x * T, y * T)
	n.clear()
	for i in w:
		n.set_cell(Vector2i(i, 0), 0, tile)
	_add(n, level.get_node("Platforms"))
	return n


## Sürükle-bırak kullanılabilen platform sahnesi: script + tileset + 3 tile
func _make_piece_scene(node_name: String, script_path: String, tile: Vector2i, path: String) -> PackedScene:
	var n := TileMapLayer.new()
	n.name = node_name
	n.set_script(load(script_path))
	n.tile_set = ts
	n.use_kinematic_bodies = true
	for i in 3:
		n.set_cell(Vector2i(i, 0), 0, tile)
	var scene := PackedScene.new()
	scene.pack(n)
	_save(scene, path)
	n.free()
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)


func _layer(layer_name: String) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.name = layer_name
	l.tile_set = ts
	_add(l)
	return l


func _add(node: Node, parent: Node = null) -> void:
	(parent if parent else level).add_child(node)
	node.owner = level


func _next_name(prefix: String) -> String:
	_count[prefix] = _count.get(prefix, 0) + 1
	return "%s%d" % [prefix, _count[prefix]]


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	print("%s kaydedildi: %s" % [path, error_string(err)])


# ---------------------------------------------------------------- TILESET
func _make_tileset() -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(T, T)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, 1)

	# Özel veri: "hazard" işaretli tile'a değen oyuncu ölür (hangi katmanda olursa olsun)
	tileset.add_custom_data_layer()
	tileset.set_custom_data_layer_name(0, "hazard")
	tileset.set_custom_data_layer_type(0, TYPE_BOOL)
	# Özel veri: "crumble" işaretli tile'lar oyun başlayınca çöken platforma dönüşür
	tileset.add_custom_data_layer()
	tileset.set_custom_data_layer_name(1, "crumble")
	tileset.set_custom_data_layer_type(1, TYPE_BOOL)

	# Terrain: editörde "Terrains" sekmesinden zemin boyarken üst/dolgu tile'ı otomatik seçilir
	tileset.add_terrain_set()
	tileset.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_SIDES)
	tileset.add_terrain(0)
	tileset.set_terrain_name(0, 0, "Zemin")
	tileset.set_terrain_color(0, 0, Color(0.6, 0.67, 0.75))

	var src := TileSetAtlasSource.new()
	src.texture = load("res://tiles/tiles.png")
	src.texture_region_size = Vector2i(T, T)
	tileset.add_source(src, 0)

	var h := T / 2.0
	var full := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	for c in [GROUND_TOP, GROUND, MOVING, CRUMBLE]:
		_tile(src, c, full, false)
	# Diken: çarpışma görselden biraz küçük, affedici olsun
	_tile(src, SPIKE, PackedVector2Array([Vector2(-13, 2), Vector2(13, 2), Vector2(13, h), Vector2(-13, h)]), false)
	src.get_tile_data(SPIKE, 0).set_custom_data("hazard", true)
	src.get_tile_data(CRUMBLE, 0).set_custom_data("crumble", true)
	# Tek yönlü: sadece üst kısım, alttan geçilebilir
	_tile(src, ONEWAY, PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, -h + 10), Vector2(-h, -h + 10)]), true)

	# Zemin terrain'i: üst tile'ın üstü boş, dolgunun dört yanı dolu
	var sides := [TileSet.CELL_NEIGHBOR_RIGHT_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
		TileSet.CELL_NEIGHBOR_LEFT_SIDE, TileSet.CELL_NEIGHBOR_TOP_SIDE]
	for c in [GROUND_TOP, GROUND]:
		var td := src.get_tile_data(c, 0)
		td.terrain_set = 0
		td.terrain = 0
		for side in sides:
			if c == GROUND_TOP and side == TileSet.CELL_NEIGHBOR_TOP_SIDE:
				continue
			td.set_terrain_peering_bit(side, 0)
	return tileset


func _tile(src: TileSetAtlasSource, coords: Vector2i, points: PackedVector2Array, one_way: bool) -> void:
	src.create_tile(coords)
	var data := src.get_tile_data(coords, 0)
	data.add_collision_polygon(0)
	data.set_collision_polygon_points(0, 0, points)
	data.set_collision_polygon_one_way(0, 0, one_way)
