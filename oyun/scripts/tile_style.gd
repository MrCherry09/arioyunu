@tool
class_name TileStyle
## Platformları tileset parçalarıyla çizer (bkz. platform.gd "style" ayarı).
## Her platform dikdörtgeni 16x16'lık hücrelere bölünür ve konumuna göre doğru parça seçilir:
## köşeler, kenarlar, iç kısım (rastgele varyantlarla), ince platform satırı, tek genişlikte sütun.
## Hücreye tam sığmayan kenarlar kırpılarak çizilir. İstenirse üst yüzeye süs (çiçek, ağaç...) serpilir.
##
## Ölçek: 1 tile pikseli = 3 ekran pikseli (karakterler ve ışık topları ile aynı piksel yoğunluğu).
## Yeni bir stil eklemek için STYLES'a bir satır, gerekirse LAYOUTS'a bir yerleşim ekle.

const SCALE := 3
const TILE := 16
const CELL := TILE * SCALE  ## 48 ekran pikseli

## Parça yerleşimleri: atlas koordinatları (sütun, satır), 16'lık ızgarada
const LAYOUTS := {
	# Green Valley ve ondan üretilen renk sürümleri (snow, heaven) aynı yerleşimi kullanır
	"gv": {
		"tl": Vector2i(0, 0), "t": Vector2i(1, 0), "tr": Vector2i(2, 0),
		"l": Vector2i(0, 1), "r": Vector2i(2, 1),
		"bl": Vector2i(0, 2), "b": Vector2i(1, 2), "br": Vector2i(2, 2),
		# İç kısım: çoğunlukla düz, arada kök/bitki varyantları
		"c": [Vector2i(1, 1), Vector2i(1, 1), Vector2i(1, 1), Vector2i(5, 0), Vector2i(6, 0),
				Vector2i(6, 1), Vector2i(7, 1)],
		"fill": [Vector2i(1, 1), Vector2i(1, 1), Vector2i(5, 0), Vector2i(6, 0)],
		"thin": [Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3)],
		"pillar": [Vector2i(3, 0), Vector2i(3, 2), Vector2i(3, 3)],
	},
	"winter": {
		"tl": Vector2i(3, 3), "t": Vector2i(4, 3), "tr": Vector2i(5, 3),
		"l": Vector2i(3, 4), "r": Vector2i(5, 4),
		"bl": Vector2i(3, 5), "b": Vector2i(4, 5), "br": Vector2i(5, 5),
		"c": [Vector2i(4, 4), Vector2i(4, 4), Vector2i(9, 8)],
		"fill": [Vector2i(4, 4), Vector2i(9, 8)],
		"thin": [Vector2i(9, 2), Vector2i(10, 2), Vector2i(11, 2)],
		"pillar": [Vector2i(14, 2), Vector2i(14, 3), Vector2i(14, 5)],
	},
}

## Süs parçaları: kaynak dikdörtgen (tile pikseli), alt kenarı zemine oturur
const GV_DECOR := [
	Rect2(192, 0, 16, 16), Rect2(208, 0, 16, 16),       # çiçekler
	Rect2(192, 16, 16, 16), Rect2(208, 16, 16, 16),     # kırmızı mantarlar
	Rect2(192, 32, 16, 16), Rect2(208, 32, 16, 16),     # kahverengi mantarlar
	Rect2(224, 0, 32, 32), Rect2(256, 16, 32, 16),      # çalılar
	Rect2(288, 16, 32, 16), Rect2(320, 0, 32, 32),      # kıvırcık bitki, uzun ot
	Rect2(352, 0, 32, 32), Rect2(384, 0, 32, 32),       # küçük ağaç, sarmaşık
]
const WINTER_DECOR := [
	Rect2(16, 0, 32, 64), Rect2(64, 0, 32, 64),         # karlı çamlar
	Rect2(112, 16, 32, 48), Rect2(208, 0, 32, 64),      # yuvarlak ağaç, büyük ağaç
	Rect2(16, 80, 32, 32), Rect2(64, 80, 32, 32), Rect2(112, 80, 32, 32),  # kar kaplı çalılar
	Rect2(16, 128, 32, 32), Rect2(64, 128, 32, 32),     # kayalar
	Rect2(112, 128, 32, 32),                            # buz kristali
	Rect2(64, 176, 32, 32),                             # kar yığını
]

## Stiller. "fallback": dosya yoksa (ör. git'e konmayan Winter) kullanılacak stil.
const STYLES := {
	"green_valley": {"tex": "res://assets/tilesets/green_valley/green_valley.png", "layout": "gv",
			"decor_tex": "", "decor": GV_DECOR},
	"snow": {"tex": "res://assets/tilesets/generated/snow.png", "layout": "gv",
			"decor_tex": "", "decor": GV_DECOR},
	"heaven": {"tex": "res://assets/tilesets/generated/heaven.png", "layout": "gv",
			"decor_tex": "", "decor": GV_DECOR},
	"winter": {"tex": "res://assets/tilesets/winter/winter_tileset.png", "layout": "winter",
			"decor_tex": "res://assets/tilesets/winter/winter_environment.png", "decor": WINTER_DECOR,
			"fallback": "snow"},
}

static var _tex_cache := {}


## Stil kullanılabilir mi? Dosyası yoksa yedeğine düşer; hiçbiri yoksa "" döner.
static func resolve(style: String) -> String:
	var s := style
	while s != "" and STYLES.has(s):
		if _texture(STYLES[s]["tex"]) != null:
			return s
		s = STYLES[s].get("fallback", "")
	return ""


static func _texture(path: String) -> Texture2D:
	if path == "":
		return null
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[path]


## Platformu ci (CanvasItem) üzerine çizer. size: ekran pikseli. fill_only: sadece iç dolgu
## (oda duvarı/tavanı gibi kenarsız yüzeyler). decor: üst yüzeyde süs yoğunluğu 0..1.
static func draw_block(ci: CanvasItem, size: Vector2, style: String, fill_only := false,
		decor := 0.0, seed := 0, decor_skip: Array = []) -> void:
	var st := resolve(style)
	if st == "":
		return
	var def: Dictionary = STYLES[st]
	var tex := _texture(def["tex"])
	var lay: Dictionary = LAYOUTS[def["layout"]]

	var cols := _spans(size.x)
	var rows := _spans(size.y)
	# Ortadakiler önce, kenarlar sonra: kenarlar üste gelir (dar platformlarda örtüşme temiz görünür)
	for pass_edges in [false, true]:
		for ry in rows.size():
			for rx in cols.size():
				var cx: Array = cols[rx]
				var cy: Array = rows[ry]
				var edge: bool = cx[2] != "mid" or cy[2] != "mid"
				if edge != pass_edges:
					continue
				var coord := _pick(lay, cx[2], cy[2], fill_only, rx, ry, seed)
				_draw_cell(ci, tex, coord, Rect2(cx[0], cy[0], cx[1], cy[1]), cx[2], cy[2])

	if decor > 0.0 and not fill_only and size.x >= CELL * 2:
		_draw_decor(ci, def, size, decor, seed, decor_skip)


## Bir eksen boyunca hücreler: [başlangıç, uzunluk, rol]. rol: single / first / mid / last
static func _spans(length: float) -> Array:
	if length <= CELL:
		return [[0.0, length, "single"]]
	var out := [[0.0, float(CELL), "first"]]
	var x := float(CELL)
	while x < length - CELL:
		out.append([x, minf(CELL, length - CELL - x), "mid"])
		x += CELL
	out.append([length - CELL, float(CELL), "last"])
	return out


static func _pick(lay: Dictionary, rx: String, ry: String, fill_only: bool, ix: int, iy: int,
		seed: int) -> Vector2i:
	var h := absi(hash(Vector3i(ix, iy, seed)))
	if fill_only:
		var f: Array = lay["fill"]
		return f[h % f.size()]
	if ry == "single":  # tek sıra yüksekliğinde: ince platform
		var thin: Array = lay["thin"]
		match rx:
			"first":
				return thin[0]
			"last":
				return thin[2]
		return thin[1]
	if rx == "single":  # tek sütun genişliğinde: dikey sütun
		var p: Array = lay["pillar"]
		match ry:
			"first":
				return p[0]
			"last":
				return p[2]
		return p[1]
	var row := "t" if ry == "first" else ("b" if ry == "last" else "")
	var col := "l" if rx == "first" else ("r" if rx == "last" else "")
	if row == "" and col == "":
		var c: Array = lay["c"]
		return c[h % c.size()]
	if row == "":
		return lay[col]
	if col == "":
		return lay[row]
	return lay[row + col]


## Hücreyi çiz; hücre 48'den küçükse kaynak kırpılır:
## yatayda tek sütun ortadan, ara hücre soldan; dikeyde tek sıra ve ara hücre üstten (çim görünür kalsın)
static func _draw_cell(ci: CanvasItem, tex: Texture2D, coord: Vector2i, dst: Rect2, rx: String,
		ry: String) -> void:
	var sw := dst.size.x / SCALE
	var sh := dst.size.y / SCALE
	var sx := 0.0
	if rx == "single":
		sx = (TILE - sw) / 2.0
	var src := Rect2(coord.x * TILE + sx, coord.y * TILE, sw, sh)
	ci.draw_texture_rect_region(tex, dst, src)


## decor_skip: [[x0, x1], ...] yerel x aralıkları; buralara süs konmaz (plaka, yastık, kapı...)
static func _draw_decor(ci: CanvasItem, def: Dictionary, size: Vector2, density: float, seed: int,
		decor_skip: Array) -> void:
	var tex := _texture(def["decor_tex"]) if def["decor_tex"] != "" else _texture(def["tex"])
	if tex == null:
		return
	var items: Array = def["decor"]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var x := CELL * 0.4
	while x < size.x - CELL * 0.4:
		var r: Rect2 = items[rng.randi() % items.size()]
		var w := r.size.x * SCALE
		if x + w > size.x - CELL * 0.3:
			break
		var blocked := false
		for sk: Array in decor_skip:
			if x < sk[1] and x + w > sk[0]:
				blocked = true
				break
		if not blocked and rng.randf() < density:
			# Alt kenar platformun üstüne oturur, 2 piksel içeri batar (havada durmasın)
			var dst := Rect2(x, -r.size.y * SCALE + 2 * SCALE, w, r.size.y * SCALE)
			ci.draw_texture_rect_region(tex, dst, r)
			x += w + CELL * 0.3
		else:
			x += CELL * 0.75
