extends SceneTree
## Level üretici: 3 level sahnesini (scenes/levels/*.tscn) test tile'larıyla kurar ve kaydeder.
## Çalıştırma (oyun/ klasöründen):
##   godot --headless --path . -s res://tools/build_levels.gd
##
## DİKKAT: Bu betik sahneleri baştan yazar. Level'ları editörde elle düzenlemeye (tile boyama,
## süsleme) başladıktan sonra tekrar çalıştırırsanız o düzenlemeler kaybolur. Yerleşimi değiştirmek
## için ya burayı düzenleyip yeniden üretin, ya da artık doğrudan editörde çalışın.
##
## Koordinatlar tile cinsindendir (1 tile = 16 px x 3 ölçek = 48 px). y aşağı doğru artar.
## "Zemin üstü y" (top) = o satırdaki tile'ın üst kenarı; karakterler ayaklarıyla oraya basar.
## Route: level'ın baştan sona gidilebilir yolu (tests/levels_test.gd bu noktalar arasını bot ile dener).

const TILE := 48
const TILESET_PATH := "res://assets/tilesets/test/test_tileset.tres"
const TILES_PNG := "res://assets/tilesets/test/test_tiles.png"

## Biyom -> [iç tile, üst yüzey tile] (atlas sütunu)
const BIOMES := {"forest": [0, 1], "rock": [2, 3], "cloud": [4, 5], "wood": [7, 7]}
const PLANK := 6

const Npc := preload("res://scripts/elements/npc.gd")
const Pickup := preload("res://scripts/elements/pickup.gd")
const Interactable := preload("res://scripts/elements/interactable.gd")
const Critter := preload("res://scripts/elements/critter.gd")
const TriggerZone := preload("res://scripts/elements/trigger_zone.gd")
const Crate := preload("res://scripts/elements/crate.gd")
const Plate := preload("res://scripts/elements/pressure_plate.gd")
const Lever := preload("res://scripts/elements/lever.gd")
const Door := preload("res://scripts/elements/door.gd")
const ToggleBlock := preload("res://scripts/elements/toggle_block.gd")
const WindZone := preload("res://scripts/elements/wind_zone.gd")
const JumpPad := preload("res://scripts/elements/jump_pad.gd")
const Breakable := preload("res://scripts/elements/breakable.gd")
const Crumble := preload("res://scripts/elements/crumble_platform.gd")
const Mover := preload("res://scripts/elements/moving_platform.gd")
const LightOrb := preload("res://scripts/elements/light_orb.gd")
const PLATFORM := preload("res://scenes/platform.tscn")

var tileset: TileSet

# --- Kurulmakta olan level ---
var lvl: Node2D
var ground: TileMapLayer
var oneway: TileMapLayer
var entities: Node2D
var route: Node2D
var deco: Node2D
var cells := {}        ## Vector2i -> biyom (katı zemin)


func _initialize() -> void:
	tileset = _make_tileset()
	_build_forest()
	_build_mountain()
	_build_clouds()
	print("leveller kuruldu")
	quit()


# =====================================================================
# Test tileset
# =====================================================================

func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(1, 2)  # tek yönlü platformlar ayrı katmanda (aşağı inilebilsin)
	ts.set_physics_layer_collision_mask(1, 0)
	var src := TileSetAtlasSource.new()
	src.texture = load(TILES_PNG)
	src.texture_region_size = Vector2i(16, 16)
	ts.add_source(src, 0)
	for i in 8:
		src.create_tile(Vector2i(i, 0))
		var td := src.get_tile_data(Vector2i(i, 0), 0)
		if i == PLANK:
			td.add_collision_polygon(1)
			td.set_collision_polygon_points(1, 0, PackedVector2Array([
				Vector2(-8, -8), Vector2(8, -8), Vector2(8, -3), Vector2(-8, -3)]))
			td.set_collision_polygon_one_way(1, 0, true)
		else:
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))
	ResourceSaver.save(ts, TILESET_PATH)
	return load(TILESET_PATH)


# =====================================================================
# Kurulum yardımcıları
# =====================================================================

func _begin(script_path: String, index: int, title: String, subtitle: String, bounds: Rect2i,
		sky_top: Color, sky_bottom: Color) -> void:
	lvl = Node2D.new()
	lvl.name = "Level%d" % index
	lvl.set_script(load(script_path))
	lvl.level_index = index
	lvl.level_title = title
	lvl.level_subtitle = subtitle
	lvl.bounds = bounds
	lvl.sky_top = sky_top
	lvl.sky_bottom = sky_bottom
	cells = {}
	deco = _child(Node2D.new(), "Deco", lvl)
	deco.z_index = -20
	ground = _layer("Ground")
	oneway = _layer("OneWay")
	entities = _child(Node2D.new(), "Entities", lvl)
	route = _child(Node2D.new(), "Route", lvl)
	route.visible = false


func _layer(n: String) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.tile_set = tileset
	l.scale = Vector2(3, 3)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return _child(l, n, lvl)


func _child(n: Node, nm: String, parent: Node) -> Node:
	n.name = nm
	parent.add_child(n)
	n.owner = lvl
	return n


## Katı zemin: x0..x1-1, y0..y1-1 hücreleri
func solid(x0: int, x1: int, y0: int, y1: int, biome := "forest") -> void:
	for x in range(x0, x1):
		for y in range(y0, y1):
			cells[Vector2i(x, y)] = biome


func clear(x0: int, x1: int, y0: int, y1: int) -> void:
	for x in range(x0, x1):
		for y in range(y0, y1):
			cells.erase(Vector2i(x, y))


## Zemin: üst yüzeyi top satırında, level tabanına kadar dolu
func ground_at(x0: int, x1: int, top: int, biome := "forest") -> void:
	solid(x0, x1, top, lvl.bounds.end.y, biome)


## Tek yönlü (alttan geçilen) tahta platform
func plank(x0: int, x1: int, y: int) -> void:
	for x in range(x0, x1):
		oneway.set_cell(Vector2i(x, y), 0, Vector2i(PLANK, 0))


## Hücreleri tile'lara dök: üstü boş olan hücre "üst yüzey" tile'ı alır
func _paint() -> void:
	for c: Vector2i in cells:
		var b: Array = BIOMES[cells[c]]
		var top := not cells.has(c + Vector2i.UP)
		ground.set_cell(c, 0, Vector2i(b[1] if top else b[0], 0))


## Tile koordinatından dünya koordinatı (x: hücre sol kenarı + frac, y: hücre üst kenarı)
func at(tx: float, ty: float) -> Vector2:
	return Vector2(tx * TILE, ty * TILE)


func ent(n: Node, nm: String, tx: float, ty: float) -> Node:
	n.position = at(tx, ty)
	return _child(n, nm, entities)


func npc(nm: String, id: String, tx: float, ty: float, extra := {}) -> Node:
	var n := Npc.new()
	n.npc_id = id
	for k: String in extra:
		n.set(k, extra[k])
	return ent(n, nm, tx, ty)


func item(nm: String, id: String, tx: float, ty: float) -> Node:
	var p := Pickup.new()
	p.item_id = id
	return ent(p, nm, tx, ty)


func thing(nm: String, look: String, verb: String, tx: float, ty: float, extra := {}) -> Node:
	var n := Interactable.new()
	n.look = look
	n.verb = verb
	for k: String in extra:
		n.set(k, extra[k])
	return ent(n, nm, tx, ty)


func zone(nm: String, tx: float, ty: float, w: float, h: float, label := "") -> Node:
	var z := TriggerZone.new()
	z.size = Vector2(w, h) * TILE
	z.label_text = label
	return ent(z, nm, tx, ty)


func orb(tx: float, ty: float, heal := 10.0) -> void:
	var o := LightOrb.new()
	o.heal_amount = heal
	o.radius = 14.0 if heal <= 10.0 else 20.0
	if heal > 10.0:
		o.color = Color(0.6, 0.85, 1.0)
	ent(o, "Orb%d" % entities.get_child_count(), tx, ty)


func wind(nm: String, tx: float, ty: float, w: float, h: float, force: Vector2) -> Node:
	var z := WindZone.new()
	z.size = Vector2(w, h) * TILE
	z.force = force
	return ent(z, nm, tx, ty)


func pad(tx: float, ty: float, strength: float) -> void:
	var p := JumpPad.new()
	p.strength = strength
	p.size = Vector2(80, 16)
	ent(p, "Pad%d" % entities.get_child_count(), tx, ty - 16.0 / TILE)


## Görsel süs (çarpışmasız renkli dikdörtgen): ev, ağaç gövdesi, kapı sütunu...
func deco_rect(tx: float, ty: float, w: float, h: float, c: Color) -> void:
	var r := ColorRect.new()
	r.position = at(tx, ty)
	r.size = Vector2(w, h) * TILE
	r.color = c
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_child(r, "Deco%d" % deco.get_child_count(), deco)


func spawn(tx: float, ty: float) -> void:
	var m := Marker2D.new()
	m.position = at(tx, ty) - Vector2(0, 25)
	_child(m, "Spawn", lvl)


## Rota noktası: oyuncunun ayakta duracağı yer. tech: oraya önceki noktadan nasıl gidilir
## ("walk" yürü/zıpla, "wall" iki duvar arası tırman, "glide" süzül, "pad" yastık, "wind" akım)
func waypoint(tx: float, ty: float, tech := "walk") -> void:
	var m := Marker2D.new()
	m.position = at(tx, ty) - Vector2(0, 25)
	m.set_meta("tech", tech)
	_child(m, "P%02d" % route.get_child_count(), route)


func _save(path: String) -> void:
	_paint()
	var ps := PackedScene.new()
	var err := ps.pack(lvl)
	assert(err == OK, "pack hatası: %s" % err)
	err = ResourceSaver.save(ps, path)
	assert(err == OK, "kayıt hatası: %s" % err)
	print("kaydedildi: ", path, "  (", cells.size(), " hücre, ", entities.get_child_count(), " nesne, ",
			route.get_child_count(), " rota noktası)")
	lvl.free()


# =====================================================================
# LEVEL 1 - ORMAN: yatay, az yükseklik farkı
# =====================================================================
# Bölümler (x): 0-34 düşüş alanı | 34-60 orman yolu | 60-96 köy | 96-124 yaşlı ağaç
# | 124-152 çayır (kuzu) | 152-176 nehir ve köprü | 176-232 derin orman (gizli mahzen) | 232-262 etekler

func _build_forest() -> void:
	_begin("res://scripts/levels/level_1_forest.gd", 1, "Part 1 - The Forest",
			"Find the way to the mountain", Rect2i(0, 0, 262, 23),
			Color(0.42, 0.58, 0.62), Color(0.78, 0.86, 0.72))
	const G := 18  # zemin üstü

	solid(0, 1, 0, 23)            # sol duvar
	solid(261, 262, 0, 23)        # sağ duvar

	# --- Düşüş alanı ---
	ground_at(1, 34, G)
	solid(14, 18, G - 1, G)       # küçük tümsek (zıplamayı öğret)
	spawn(5, G)
	ent(Marker2D.new(), "CrashSite", 24, G)
	orb(10, G - 2.5)
	orb(16, G - 3.5)
	orb(28, G - 3)
	waypoint(5, G)
	waypoint(16, G - 1)
	waypoint(30, G)

	# --- Orman yolu ---
	ground_at(34, 44, G - 1)      # hafif yokuş
	ground_at(44, 60, G)
	solid(50, 52, G - 2, G)       # devrilmiş kütük (2 tile)
	plank(37, 41, G - 3)          # dallar: 1. hikâye taşı yukarıda
	plank(41, 45, G - 5)
	thing("Stone1", "stone", "Read", 43, G - 5, {"glow": true})
	orb(39, G - 4.5)
	waypoint(38, G - 1)
	waypoint(48, G)
	waypoint(51, G - 2)
	waypoint(57, G)

	# --- Köy ---
	ground_at(60, 96, G)
	deco_rect(63, G - 4, 7, 4, Color(0.45, 0.32, 0.24))   # ev 1
	deco_rect(62.5, G - 6, 8, 2, Color(0.55, 0.22, 0.2))  # çatı
	deco_rect(74, G - 4, 6, 4, Color(0.42, 0.3, 0.22))    # ev 2
	deco_rect(73.5, G - 6, 7, 2, Color(0.5, 0.2, 0.18))
	npc("Granny", "granny", 68, G)
	npc("Farmer", "farmer", 80, G)
	ent(Marker2D.new(), "Well", 90, G)
	npc("Child", "child", 90, G + 0.25)
	orb(72, G - 3)
	waypoint(70, G)
	waypoint(92, G)

	# --- Yaşlı ağaç: dallardan tırman, ip tepede ---
	ground_at(96, 124, G)
	deco_rect(104, G - 12, 1.5, 12, Color(0.3, 0.2, 0.13))  # gövde
	deco_rect(99, G - 13, 15, 3, Color(0.24, 0.38, 0.22))   # taç
	plank(100, 104, G - 2)
	plank(104, 108, G - 4)
	plank(100, 104, G - 6)
	plank(104, 109, G - 8)
	plank(108, 113, G - 10)
	item("Rope", "rope", 106.5, G - 8)
	thing("Stone2", "stone", "Read", 111, G - 10, {"glow": true})
	orb(102, G - 7.5)
	waypoint(101, G - 2)
	waypoint(105, G - 4)
	waypoint(101, G - 6)
	waypoint(106, G - 8)
	waypoint(111, G - 10)
	waypoint(118, G)

	# --- Çayır: kaçan kuzu (çitler kuzuyu tutar, oyuncu zıplayarak geçer) ---
	ground_at(124, 152, G)
	npc("Shepherd", "shepherd", 121, G)
	zone("Pen", 116, G - 3, 7, 3, "Pen")
	solid(126, 127, G - 2, G, "wood")     # batı çiti
	solid(149, 150, G - 2, G, "wood")     # doğu çiti
	var lamb := Critter.new()
	lamb.look = "lamb"
	ent(lamb, "Lamb", 140, G)
	orb(138, G - 3)
	waypoint(124, G)
	waypoint(126.5, G - 2)
	waypoint(138, G)
	waypoint(149.5, G - 2)

	# --- Nehir: rüzgarlı geçit, köprü kütük-plaka ile iner ---
	ground_at(152, 160, G)
	npc("Miller", "miller", 151.5, G)
	var crate := Crate.new()
	ent(crate, "BridgeCrate", 155, G)
	crate.position.y -= Crate.SIZE.y / 2.0
	solid(159, 160, G - 1, G)             # kütüğü tutan tümsek (nehre düşmesin)
	var plate := Plate.new()
	plate.channel = "bridge"
	ent(plate, "BridgePlate", 157, G)
	ground_at(160, 174, G + 3)            # nehir yatağı
	var bridge := ToggleBlock.new()
	bridge.channel = "bridge"
	bridge.mode = "hold"
	bridge.solid_at_start = false
	bridge.size = Vector2(14 * TILE, TILE)
	bridge.color = Color(0.62, 0.45, 0.28)
	ent(bridge, "Bridge", 160, G)
	# Geçitte sert rüzgar: zıplayan/süzülen geri itilir; köprüde yürüyen etkilenmez
	# Rüzgar sadece nehrin üstünde (tümseğin sağından başlar: tümseğe zıplayan geri itilmesin)
	var gust := wind("GorgeWind", 160.5, 8, 14, 9, Vector2(-2600, 0))
	gust.set("size", Vector2(14 * TILE, 9 * TILE - 6))  # köprüde ayakta duranın başına değmesin
	zone("RiverTalk", 148, G - 4, 6, 4)
	waypoint(156, G)
	waypoint(167, G, "bridge")
	waypoint(178, G)

	# --- Derin orman: dallar, gizli mahzen (çatlak zemini çakılarak kır) ---
	ground_at(174, 232, G)
	plank(184, 188, G - 2)
	plank(188, 192, G - 4)
	plank(192, 196, G - 6)
	orb(186, G - 3.5)
	orb(194, G - 7.5)
	orb(222, G - 3)
	# Mahzen: zeminin altında oyuk, üstü çatlak bloklarla kapalı
	clear(210, 219, G + 1, G + 4)
	clear(212, 215, G, G + 1)
	for i in 3:
		var b := Breakable.new()
		b.size = Vector2(TILE, TILE)
		ent(b, "CellarLid%d" % i, 212 + i, G)
	thing("Stone3", "stone", "Read", 216.5, G + 4, {"glow": true})
	orb(211, G + 3, 25.0)
	waypoint(190, G - 4)
	waypoint(205, G)
	waypoint(225, G)

	# --- Etekler: dağa çıkış ---
	ground_at(232, 244, G)
	ground_at(244, 250, G - 1)
	ground_at(250, 261, G - 2)
	solid(236, 237, G - 1, G)             # kuşun kütüğü
	npc("Bird", "bird", 236.5, G - 1, {"hop": true})
	npc("ChildAtExit", "child", 241, G)
	npc("FarmerAtExit", "farmer", 241, G)
	zone("Exit", 257, G - 8, 4, 6, "To the mountain")
	waypoint(243, G)
	waypoint(247, G - 1)
	waypoint(256, G - 2)
	_save("res://scenes/levels/level_1_forest.tscn")


func _build_mountain() -> void:
	pass  # bir sonraki adımda


func _build_clouds() -> void:
	pass  # bir sonraki adımda
