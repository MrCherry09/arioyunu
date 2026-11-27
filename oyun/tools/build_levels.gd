extends SceneTree
## Level üretici: 3 level sahnesini (scenes/levels/*.tscn) hazır tileset'lerle kurar ve kaydeder.
## Tileset'ler: Orman = Green Valley (Foozle, CC0), Dağ = Green Valley karlı sürümü, Bulutlar = cennet
## sürümü (bkz. tools/recolor_green_valley.py). Her hücrenin parçası komşularına göre seçilir.
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
const TILESET_PATH := "res://assets/tilesets/levels_tileset.tres"

## Kaynak kimlikleri: katı zemin 0-2, aynı dokuların tek yönlü platform sürümleri 10-12
const SOURCES := {
	"forest": "res://assets/tilesets/green_valley/green_valley.png",
	"rock": "res://assets/tilesets/generated/snow.png",
	"cloud": "res://assets/tilesets/generated/heaven.png",
}
const SOURCE_ID := {"forest": 0, "rock": 1, "cloud": 2, "wood": 0}
const ONEWAY_ID := {"forest": 10, "rock": 11, "cloud": 12}
## Biyom -> süs yoğunluğu (üst yüzeylere serpilen çiçek/çalı/ağaç)
const DECOR_DENSITY := {"forest": 0.14, "rock": 0.06, "cloud": 0.08}

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
var back: TileMapLayer ## Çarpışmasız arka plan tile'ları (ağaç gövdesi, kapı sütunu...)
var planks := {}       ## Vector2i -> true (tek yönlü platform)
var plank_biome := "forest"
var _rng := RandomNumberGenerator.new()


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
	var lay: Dictionary = TileStyle.LAYOUTS["gv"]
	var solid_coords := {}
	for k in ["tl", "t", "tr", "l", "r", "bl", "b", "br"]:
		solid_coords[lay[k]] = true
	for k in ["c", "fill", "thin", "pillar"]:
		for c: Vector2i in lay[k]:
			solid_coords[c] = true
	for biome: String in SOURCES:
		var tex: Texture2D = load(SOURCES[biome])
		# Katı zemin kaynağı
		var src := TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(16, 16)
		ts.add_source(src, SOURCE_ID[biome])
		for c: Vector2i in solid_coords:
			src.create_tile(c)
			var td := src.get_tile_data(c, 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))
		# Tek yönlü platform kaynağı: ince platform parçaları, sadece üst kenar, alttan geçilir
		var ow := TileSetAtlasSource.new()
		ow.texture = tex
		ow.texture_region_size = Vector2i(16, 16)
		ts.add_source(ow, ONEWAY_ID[biome])
		for c: Vector2i in lay["thin"]:
			ow.create_tile(c)
			var td := ow.get_tile_data(c, 0)
			td.add_collision_polygon(1)
			td.set_collision_polygon_points(1, 0, PackedVector2Array([
				Vector2(-8, -8), Vector2(8, -8), Vector2(8, -3), Vector2(-8, -3)]))
			td.set_collision_polygon_one_way(1, 0, true)
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
	planks = {}
	_rng.seed = index * 1000 + 7
	deco = _child(Node2D.new(), "Deco", lvl)
	deco.z_index = -20
	back = _layer("Background")
	back.collision_enabled = false
	back.modulate = Color(0.75, 0.75, 0.8)  # arkada olduğu belli olsun
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


## Tek yönlü (alttan geçilen) ince platform
func plank(x0: int, x1: int, y: int) -> void:
	for x in range(x0, x1):
		planks[Vector2i(x, y)] = true


## Hücre dolu mu? Level sınırının dışı dolu sayılır (ekran kenarında kenar çizgisi çıkmasın)
func _filled(c: Vector2i) -> bool:
	if c.y >= lvl.bounds.end.y or c.x < lvl.bounds.position.x or c.x >= lvl.bounds.end.x:
		return true
	return cells.has(c)


## Hücreleri tile'lara dök: her hücrenin parçası komşularına göre seçilir
## (köşe/kenar/iç, tek sıra yükseklikte ince platform, tek sütun genişlikte sütun)
func _paint() -> void:
	var lay: Dictionary = TileStyle.LAYOUTS["gv"]
	for c: Vector2i in cells:
		var up := _filled(c + Vector2i.UP)
		var down := _filled(c + Vector2i.DOWN)
		var left := _filled(c + Vector2i.LEFT)
		var right := _filled(c + Vector2i.RIGHT)
		var coord: Vector2i
		if not left and not right:
			var p: Array = lay["pillar"]
			coord = p[0] if not up else (p[2] if not down else p[1])
		elif not up and not down:
			var t: Array = lay["thin"]
			coord = t[0] if not left else (t[2] if not right else t[1])
		else:
			var row := "t" if not up else ("b" if not down else "")
			var col := "l" if not left else ("r" if not right else "")
			if row == "" and col == "":
				var cs: Array = lay["c"]
				coord = cs[absi(hash(c)) % cs.size()]
			elif row == "":
				coord = lay[col]
			elif col == "":
				coord = lay[row]
			else:
				coord = lay[row + col]
		ground.set_cell(c, SOURCE_ID[cells[c]], coord)
	var thin: Array = lay["thin"]
	for c: Vector2i in planks:
		var l := planks.has(c + Vector2i.LEFT)
		var r := planks.has(c + Vector2i.RIGHT)
		oneway.set_cell(c, ONEWAY_ID[plank_biome], thin[1] if l and r else (thin[0] if r else (thin[2] if l else thin[1])))
	_scatter_decor()


## Üst yüzeylere hazır süs parçaları (çiçek, mantar, çalı, ağaç). NPC/eşya/rota noktası yakınına konmaz.
func _scatter_decor() -> void:
	var keep_clear := []
	for n in entities.get_children():
		if n is Node2D:
			keep_clear.append((n as Node2D).position / TILE)
	for m in route.get_children():
		keep_clear.append((m as Node2D).position / TILE)
	var items: Array = TileStyle.GV_DECOR
	for c: Vector2i in cells:
		var biome: String = cells[c]
		if biome == "wood" or _filled(c + Vector2i.UP) or c.y <= lvl.bounds.position.y:
			continue
		if _rng.randf() > DECOR_DENSITY.get(biome, 0.0):
			continue
		var near := false
		for k: Vector2 in keep_clear:
			if absf(k.x - (c.x + 0.5)) < 3.0 and absf(k.y - c.y) < 3.0:
				near = true
				break
		if near:
			continue
		var r: Rect2 = items[_rng.randi() % items.size()]
		var sp := Sprite2D.new()
		sp.texture = load(SOURCES[biome])
		sp.region_enabled = true
		sp.region_rect = r
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.scale = Vector2.ONE * 3
		sp.centered = false
		# Alt kenarı zemine otursun (1 piksel içeri)
		sp.position = Vector2(c.x * TILE + (TILE - r.size.x * 3) / 2.0, c.y * TILE - r.size.y * 3 + 3)
		_child(sp, "Decor%d" % deco.get_child_count(), deco)


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


## Arka plan sütunu (çarpışmasız): ağaç gövdesi, kapı sütunu. y0 üst, y1 alt (hariç)
func back_pillar(x: int, y0: int, y1: int, biome := "forest") -> void:
	var p: Array = TileStyle.LAYOUTS["gv"]["pillar"]
	for y in range(y0, y1):
		back.set_cell(Vector2i(x, y), SOURCE_ID[biome], p[0] if y == y0 else (p[2] if y == y1 - 1 else p[1]))


## Arka plan yatay kiriş (çarpışmasız): kapı kemeri gibi
func back_beam(x0: int, x1: int, y: int, biome := "forest") -> void:
	var t: Array = TileStyle.LAYOUTS["gv"]["thin"]
	for x in range(x0, x1):
		back.set_cell(Vector2i(x, y), SOURCE_ID[biome], t[0] if x == x0 else (t[2] if x == x1 - 1 else t[1]))


## Hazır süs parçası (GV_DECOR içinden), ayakları (tx, ty) noktasında
func decor_at(index: int, tx: float, ty: float, biome := "forest") -> void:
	var r: Rect2 = TileStyle.GV_DECOR[index]
	var sp := Sprite2D.new()
	sp.texture = load(SOURCES[biome])
	sp.region_enabled = true
	sp.region_rect = r
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.scale = Vector2.ONE * 3
	sp.centered = false
	sp.position = at(tx, ty) - Vector2(r.size.x * 1.5, r.size.y * 3 - 3)
	_child(sp, "Decor%d" % deco.get_child_count(), deco)


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
	# Köy: evler için hazır sprite yok; şimdilik köyü ağaçlar ve çalılar belli ediyor
	for k: Array in [[10, 63], [6, 65.5], [10, 75], [7, 77.5], [11, 84]]:
		decor_at(k[0], k[1], G)
	npc("Granny", "granny", 68, G)
	npc("Farmer", "farmer", 80, G)
	ent(Marker2D.new(), "Well", 90, G)
	npc("Child", "child", 90, G + 0.25)
	orb(72, G - 3)
	waypoint(70, G)
	waypoint(92, G)

	# --- Yaşlı ağaç: dallardan tırman, ip tepede ---
	ground_at(96, 124, G)
	back_pillar(104, G - 11, G)                 # gövde (arka plan, çarpışmasız)
	for k: Array in [[10, 102], [10, 105], [10, 108], [6, 110.5], [11, 99.5]]:
		decor_at(k[0], k[1], G - 11)            # taç: hazır ağaç ve çalı parçaları
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
	zone("RiverTalk", 151, G - 4, 6, 4)  # çitin ötesinde: kuzuyu yakalarken tetiklenmesin
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


# =====================================================================
# LEVEL 2 - DAĞ: dikey, aşağıdan yukarı tırmanış (~150 tile)
# =====================================================================
# Bölümler (y, aşağıdan yukarı): 146 etek (Keşiş) | 144-120 zikzak kayalıklar | 118-100 baca (duvar
# zıplaması) | 100-82 buzlu çıkıntılar | 80 kamp (dağcı) | 78-58 rüzgarlı sırt + mahsur madenci mağarası
# | 56-40 merdiven (+ isteğe bağlı asansör) | 38-14 son tırmanış (yastık, Kuş) | 12 zirve (Keşiş, merdiven)

## Tek yönlü çıkıntılar dizisi: her biri [x0, x1, y]; rota noktası ortalarına konur
func ledges(list: Array, tech := "walk") -> void:
	for l: Array in list:
		plank(l[0], l[1], l[2])
		waypoint((l[0] + l[1]) / 2.0, l[2], tech)


## Buzlu çıkıntı (kaygan, katı): platform sahnesi, kar stiliyle çizilir
func ice_ledge(x0: int, x1: int, y: int) -> void:
	var pl := PLATFORM.instantiate()
	pl.size = Vector2((x1 - x0) * TILE, TILE)
	pl.friction_mult = 0.15
	pl.style = "snow"
	ent(pl, "Ice%d" % entities.get_child_count(), x0, y)
	waypoint((x0 + x1) / 2.0, y)


func _build_mountain() -> void:
	_begin("res://scripts/levels/level_2_mountain.gd", 2, "Part 2 - The Mountain",
			"Climb to the Stairway", Rect2i(0, 0, 46, 150),
			Color(0.36, 0.45, 0.66), Color(0.7, 0.76, 0.86))
	plank_biome = "rock"
	solid(0, 1, 0, 150, "rock")
	solid(45, 46, 0, 150, "rock")

	# --- Etek: Keşiş'in tapınağı ---
	ground_at(1, 45, 146, "rock")
	spawn(4, 146)
	npc("Monk", "monk", 9, 146)
	orb(14, 143)
	waypoint(4, 146)

	# --- Zikzak kayalıklar (tek sıçrayışla, 2 tile arayla) ---
	ledges([[32, 40, 144], [24, 30, 142], [16, 22, 140], [8, 14, 138], [16, 22, 136], [24, 30, 134],
			[32, 40, 132], [24, 30, 130], [16, 22, 128], [8, 14, 126], [16, 22, 124], [24, 30, 122]])
	plank(32, 38, 120)                                # rafa kolay basamak (rota bunu atlayıp doğrudan rafa çıkar)
	plank(2, 6, 124)                                  # yan cep: 1. çan
	thing("Bell1", "bell", "Ring", 4, 124, {"glow": true})
	plank(40, 44, 128)                                # yan cep: 1. odun
	item("Wood1", "wood", 42, 128)
	orb(20, 131)
	orb(36, 125)

	# --- Baca: alt raf, iki duvar arası duvar zıplaması, üst raf ---
	# Alt raf iki dış duvar arasında kenarsız: bacadan kayan oyuncu aşağı düşmez, rafta kalır.
	# Rafa alttan, tek yönlü açıklıktan (x 24-37) zıplanarak çıkılır (altındaki çıkıntılar kafa çarpmasın).
	solid(1, 24, 118, 120, "rock")
	solid(38, 45, 118, 120, "rock")
	plank(24, 38, 118)
	waypoint(35, 118)
	solid(18, 19, 101, 118, "rock")                   # bacanın sol duvarı (rafa kadar: diğer yandan düşülmesin)
	solid(23, 24, 101, 115, "rock")                   # sağ duvar (altı açık: sağdan içeri yürünür)
	plank(19, 20, 110)                                # dinlenme çıkıntıları
	plank(22, 23, 105)
	waypoint(20.5, 118)
	solid(6, 19, 100, 102, "rock")                    # üst raf (sol)
	solid(23, 40, 100, 102, "rock")                   # üst raf (sağ)
	waypoint(28, 100, "wall")
	orb(20.5, 108)

	# --- Buzlu çıkıntılar ---
	ledges([[32, 38, 98], [24, 30, 96], [16, 22, 94]])
	ice_ledge(8, 14, 92)
	ledges([[16, 22, 90]])
	ice_ledge(24, 30, 88)
	ledges([[32, 38, 86], [24, 30, 84], [28, 34, 82]])
	plank(40, 44, 94)                                 # yan cep: 2. odun
	item("Wood2", "wood", 42, 94)
	orb(11, 89)

	# --- Kamp: üşüyen dağcı ---
	solid(4, 26, 80, 82, "rock")
	npc("Climber", "climber", 10, 80, {"shiver": true})
	ent(Marker2D.new(), "Campfire", 13.5, 80)
	waypoint(20, 80)

	# --- Rüzgarlı sırt: rüzgar sağa iter, rota sola gider ---
	ledges([[27, 33, 78], [35, 41, 76], [27, 33, 74], [19, 25, 72], [11, 17, 70], [3, 9, 68],
			[11, 17, 66], [19, 25, 64], [27, 33, 62]])
	wind("RidgeWind", 2, 63, 31, 9, Vector2(450, 0))
	orb(6, 65)
	item("Wood3", "wood", 4, 68)                      # sırtın sol dönemecinde: 3. odun (kampın üstünde, karar satırının altında)
	# Mahsur madenci: mağaranın ağzı çatlak kayalarla kapalı (dash ile kır)
	solid(36, 45, 56, 64, "rock")
	clear(36, 44, 59, 62)
	plank(33, 37, 62)
	for i in 3:
		var b := Breakable.new()
		b.size = Vector2(TILE, TILE)
		ent(b, "Rockfall%d" % i, 37, 59 + i)
	npc("Miner", "miner", 41.5, 62)
	zone("MinerTalk", 30, 58, 6, 4)
	orb(40, 60.5, 25.0)
	ledges([[19, 25, 60], [11, 17, 58]])

	# --- Merdiven (+ isteğe bağlı asansör) ---
	ledges([[3, 9, 56], [11, 17, 54], [3, 9, 52], [11, 17, 50], [3, 9, 48], [11, 17, 46],
			[19, 25, 44], [27, 33, 42], [35, 41, 40]])
	# İsteğe bağlı asansör: rotanın dışında (sağda), 62'deki çıkıntının yanından 43'e çıkar
	var lift := Mover.new()
	lift.size = Vector2(3 * TILE, 24)
	lift.travel = Vector2(0, -16 * TILE)
	lift.duration = 4.0
	lift.color = Color(0.55, 0.6, 0.75)
	ent(lift, "Lift", 33, 59)
	plank(36, 42, 46)                                 # yan cep: 2. çan
	thing("Bell2", "bell", "Ring", 39, 46, {"glow": true})
	orb(39, 43)

	# --- Son tırmanış: yastık, Kuş, dash ile 3. çan ---
	ledges([[27, 33, 38]])
	plank(19, 25, 36)
	waypoint(20, 36)
	pad(23, 36, 1000.0)                               # çıkıntının sağ ucunda: üstüne basınca fırlatır
	ledges([[14, 20, 26]], "pad")
	plank(2, 8, 28)                                   # yan cep: 3. çan (6 tile boşluk: zıpla + dash)
	thing("Bell3", "bell", "Ring", 5, 28, {"glow": true})
	ledges([[22, 28, 24], [30, 36, 22]])
	npc("Bird", "bird", 33, 22, {"hop": true})
	# Son çıkıntı zirvenin solunda: zirveye çift zıplamayla çıkılır (kafa platoya çarpmasın)
	ledges([[38, 44, 20], [30, 36, 18], [22, 27, 16]])
	orb(41, 17)
	orb(24, 13)

	# --- Zirve: Keşiş, kapalı tapınak (3 çan açar), ışıktan merdiven ---
	solid(28, 45, 12, 14, "rock")
	npc("MonkSummit", "monk", 30, 12)
	waypoint(32, 12)
	solid(39, 45, 8, 9, "rock")                       # tapınağın tavanı
	var door := Door.new()
	door.size = Vector2(TILE, 3 * TILE)
	door.channels = ["bell1", "bell2", "bell3"]
	ent(door, "ShrineDoor", 39, 9)
	thing("ShrineStone", "stone", "Read", 42, 12, {"glow": true})
	orb(43, 10.5, 25.0)
	for y in range(3, 12):
		back.set_cell(Vector2i(35, y), SOURCE_ID["cloud"], TileStyle.LAYOUTS["gv"]["pillar"][1])
		back.set_cell(Vector2i(38, y), SOURCE_ID["cloud"], TileStyle.LAYOUTS["gv"]["pillar"][1])
	back_beam(34, 40, 2, "cloud")                     # ışıktan merdivenin kapısı
	zone("Exit", 35, 6, 3, 6, "The Stairway")
	waypoint(36.5, 12)
	_save("res://scenes/levels/level_2_mountain.tscn")


# =====================================================================
# LEVEL 3 - BULUTLARIN ÜSTÜ: yüzen adalar, altta yürünebilir bulut denizi (düşmek ölüm değil)
# =====================================================================
# Bölümler (x): 0-46 ilk adalar (Kuş, yavrular questi) | 50-78 yüksek adalar (1. yavru) | 78-100 süzülme
# boşluğu (2. yavru) | 104-122 ruh | 126-143 basamak bulutlar (+ hareketli bulut) | 146-156 yuva (3. yavru
# yastıkla yukarıda, fener çanı) | 160-196 fener adaları | 200-231 Gate

## Bulut adası: [x0, x1, y], 2 sıra kalın; rota noktası ortasına konur
func islands(list: Array, tech := "walk") -> void:
	for l: Array in list:
		solid(l[0], l[1], l[2], l[2] + 2, "cloud")
		waypoint((l[0] + l[1]) / 2.0, l[2], tech)


func _build_clouds() -> void:
	_begin("res://scripts/levels/level_3_clouds.gd", 3, "Part 3 - Above the Clouds",
			"Reach the Gate of Heaven", Rect2i(0, 0, 232, 40),
			Color(0.36, 0.32, 0.6), Color(0.95, 0.82, 0.78))
	plank_biome = "cloud"
	solid(0, 1, 0, 40, "cloud")
	solid(231, 232, 0, 40, "cloud")
	ground_at(1, 231, 36, "cloud")                    # bulut denizi: düşen buraya iner

	# --- İlk adalar ---
	solid(1, 14, 26, 28, "cloud")
	spawn(4, 26)
	waypoint(4, 26)
	islands([[18, 24, 24], [28, 34, 22], [38, 46, 24]])
	npc("Bird", "bird", 42, 24, {"hop": true})
	orb(31, 19)
	# Denizden geri dönüş: yastıklar ve yukarı akımlar
	pad(26, 36, 1150.0)

	# --- Yüksek adalar: 1. yavru ---
	islands([[50, 56, 21], [60, 64, 18]])
	thing("Chick1", "chick", "", 62, 18, {"auto": true, "bob": true})
	islands([[68, 78, 22]])
	orb(57, 16)

	# --- Süzülme boşluğu: 2. yavru ---
	islands([[92, 100, 26]], "glide")
	thing("Chick2", "chick", "", 96, 26, {"auto": true, "bob": true})
	wind("Updraft1", 84, 16, 3, 20, Vector2(0, -900))
	orb(85.5, 14)

	# --- Ruh ---
	islands([[104, 110, 24], [114, 122, 22]])
	npc("Spirit", "spirit", 118, 22, {"hop": true})
	pad(102, 36, 1150.0)
	orb(118, 18)

	# --- Basamak bulutlar (+ üstte isteğe bağlı hareketli bulut) ---
	islands([[127, 130, 24], [134, 137, 23], [140, 143, 22]])
	var mover := Mover.new()
	mover.size = Vector2(3 * TILE, 24)
	mover.travel = Vector2(12 * TILE, 0)
	mover.duration = 3.0
	mover.color = Color(0.95, 0.9, 1.0)
	ent(mover, "CloudMover", 127, 19)
	wind("Updraft2", 123.5, 18, 2.5, 18, Vector2(0, -900))
	for i in 3:
		var c := Crumble.new()
		c.size = Vector2(2 * TILE, 24)
		c.color = Color(0.95, 0.92, 1.0)
		ent(c, "Crumble%d" % i, 129 + i * 5, 15)
	orb(136, 13.5)

	# --- Yuva (3. yavru yastıkla yukarıda) ve fener çanı ---
	islands([[146, 156, 22]])
	thing("Nest", "nest", "", 149, 22)
	zone("NestZone", 146, 18, 7, 4)
	thing("SkyBell", "bell", "Ring", 147, 22, {"glow": true})
	pad(155, 22, 1000.0)                             # adanın sağ ucunda
	solid(147, 153, 13, 14, "cloud")                  # 3. yavrunun adası (yastığın sol üstünde)
	thing("Chick3", "chick", "", 149.5, 13, {"auto": true, "bob": true})

	# --- Fener adaları ---
	islands([[160, 166, 20], [170, 176, 24], [180, 186, 21], [190, 196, 22]])
	thing("Lantern1", "lantern", "Light", 163, 20)
	thing("Lantern2", "lantern", "Light", 173, 24)
	thing("Lantern3", "lantern", "Light", 183, 21)
	thing("Lantern4", "lantern", "Light", 193, 22)
	pad(178, 36, 1150.0)
	wind("Updraft3", 197.5, 17, 2.5, 19, Vector2(0, -900))
	orb(175, 18)
	orb(188, 15)

	# --- Gate ---
	islands([[200, 206, 24]])
	solid(210, 231, 26, 28, "cloud")
	waypoint(214, 26)
	pad(208, 36, 1150.0)
	for y in range(15, 26):
		back.set_cell(Vector2i(219, y), SOURCE_ID["cloud"], TileStyle.LAYOUTS["gv"]["pillar"][1])
		back.set_cell(Vector2i(227, y), SOURCE_ID["cloud"], TileStyle.LAYOUTS["gv"]["pillar"][1])
	back_beam(218, 229, 14, "cloud")
	zone("Gate", 221, 20, 5, 6, "The Gate of Heaven")
	waypoint(222, 26)
	_save("res://scenes/levels/level_3_clouds.tscn")
