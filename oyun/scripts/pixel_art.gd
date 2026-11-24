class_name PixelArt
## ASCII şablondan piksel art doku üretir. Her karakter bir renge karşılık gelir ('.' = boş).
## Şablonlar elle düzenlenebilir: harfleri değiştirip oyunu yeniden başlatman yeterli.
## Şablonlar ileride gerçek sprite'larla değiştirilebilir; çizim kodu sadece doku döndürür.

const PIXEL := 3  ## 1 sanat pikseli = 3 ekran pikseli (ışık topları ile aynı ölçek)

# --- Karakter şablonları ---

const NINE := [
	"....gggg....",
	"...gggggg...",
	"...gssssg...",
	"...sesses...",
	"...ssssss...",
	"....ssss....",
	"..pppppppp..",
	".pppppppppp.",
	".pppppppppsc",
	".ppddddddp.c",
	"..dddddddd.c",
	"..dddddddd.c",
	"..dddddddd.c",
	"..dddddddd.c",
	"..dddddddd.c",
	"...bb..bb..c",
]
const NINE_PAL := {
	"g": Color(0.82, 0.82, 0.86), "s": Color(0.95, 0.78, 0.65), "e": Color(0.2, 0.15, 0.2),
	"p": Color(0.6, 0.42, 0.75), "d": Color(0.38, 0.28, 0.5), "b": Color(0.3, 0.2, 0.15),
	"c": Color(0.55, 0.38, 0.2),
}

const KESIS := [
	"....ssss....",
	"...ssssss...",
	"...ssssss...",
	"...sesses...",
	"...ssssss...",
	"...wwwwww...",
	"....wwww....",
	"..rrrwwrrr..",
	".rrrrwwrrrr.",
	".rrrrrrrrrr.",
	".ssrrrrrrss.",
	"..rrraarrr..",
	"..rrrrrrrr..",
	"..rrrrrrrr..",
	"..rrrrrrrr..",
	"..rrrrrrrr..",
	"...bb..bb...",
]
const KESIS_PAL := {
	"s": Color(0.85, 0.66, 0.5), "e": Color(0.15, 0.1, 0.1), "w": Color(0.95, 0.95, 0.95),
	"r": Color(0.55, 0.33, 0.18), "a": Color(0.95, 0.75, 0.3), "b": Color(0.25, 0.18, 0.12),
}

const KUS := [
	"...kkk...",
	"..kkkkk..",
	"..kekkko.",
	".kkkkkk..",
	"kwwkkkk..",
	".wwwkkk..",
	"..wwkk...",
	"...o.o...",
]
const KUS_PAL := {
	"k": Color(0.4, 0.65, 0.95), "e": Color(0.1, 0.1, 0.15), "o": Color(1.0, 0.6, 0.2),
	"w": Color(0.95, 0.95, 1.0),
}

## Melek: altın hale, sarı saç, beyaz cüppe; kanatları yolunmuş (seyrek, boşluklu)
const MELEK := [
	"...hhhhhh...",
	"..h......h..",
	"...hhhhhh...",
	"....yyyy....",
	"...yyyyyy...",
	"...yssssy...",
	"...sesses...",
	"...ysssssy..",
	"f...ssss...f",
	"ff.wwwwww.ff",
	"f.fwwwwwwf.f",
	".ffwwwwwwff.",
	".f.wwwwww.f.",
	"...wwwwww...",
	"...wwwwww...",
	"..wwwwwwww..",
	"..ww.ww.ww..",
]
const MELEK_PAL := {
	"h": Color(1.0, 0.85, 0.4), "y": Color(1.0, 0.9, 0.55), "s": Color(0.98, 0.88, 0.8),
	"e": Color(0.25, 0.4, 0.7), "w": Color(0.93, 0.93, 1.0), "f": Color(0.78, 0.8, 0.9),
}


const COCUK := [
	"...hhhh...",
	"..hhhhhh..",
	"..hssssh..",
	"..sesses..",
	"..ssssss..",
	"...ssss...",
	"..tttttt..",
	".tttttttt.",
	".stttttts.",
	"..tttttt..",
	"..jj..jj..",
	"..bb..bb..",
]
const COCUK_PAL := {
	"h": Color(0.45, 0.28, 0.15), "s": Color(0.97, 0.8, 0.66), "e": Color(0.15, 0.1, 0.1),
	"t": Color(0.85, 0.3, 0.3), "j": Color(0.3, 0.4, 0.7), "b": Color(0.25, 0.18, 0.12),
}

const DAGCI := [
	"...rrrrrr...",
	"..rrrrrrrr..",
	"..wwwwwwww..",
	"...ssssss...",
	"...sesses...",
	"...ssssss...",
	"....yyyy....",
	"..cccyyccc..",
	".cccccccccc.",
	".cccccccccc.",
	".ssccccccss.",
	"..cccccccc..",
	"..pppppppp..",
	"..pp....pp..",
	"..kk....kk..",
]
const DAGCI_PAL := {
	"r": Color(0.8, 0.2, 0.2), "w": Color(0.95, 0.95, 0.95), "s": Color(0.9, 0.75, 0.7),
	"e": Color(0.15, 0.1, 0.1), "y": Color(0.95, 0.8, 0.3), "c": Color(0.95, 0.55, 0.2),
	"p": Color(0.25, 0.28, 0.35), "k": Color(0.2, 0.15, 0.1),
}

## Kayıp ruh: soluk, yarı saydam, alt kısmı dalgalı
const RUH := [
	"...wwww...",
	"..wwwwww..",
	".wwwwwwww.",
	".wwewwewww",
	".wwwwwwww.",
	"wwwwwwwwww",
	"wwwwwwwwww",
	"w.wwwwww.w",
	"..ww..ww..",
	"...w..w...",
]
const RUH_PAL := {"w": Color(0.8, 0.9, 1.0, 0.8), "e": Color(0.2, 0.3, 0.5)}

## Kuyu: çatı, iki direk, taş bilezik
const KUYU := [
	"..rrrrrrrrrrrr..",
	".rrrrrrrrrrrrrr.",
	"..p..........p..",
	"..p..........p..",
	"..p..........p..",
	"..p..........p..",
	"gggggggggggggggg",
	"gddgddgddgddgddg",
	"gggggggggggggggg",
	"gddgddgddgddgddg",
]
const KUYU_PAL := {
	"r": Color(0.55, 0.3, 0.2), "p": Color(0.45, 0.3, 0.2),
	"g": Color(0.6, 0.6, 0.65), "d": Color(0.42, 0.42, 0.48),
}

const ROPE := [
	"..tttt..",
	".t....t.",
	"t..tt..t",
	"t.t..t.t",
	".t....t.",
	"..tttt..",
]
const ROPE_PAL := {"t": Color(0.85, 0.7, 0.45)}

const ODUN := [
	".bbbbbbbb.",
	"bllllllllr",
	"bllllllllr",
	".bbbbbbbb.",
]
const ODUN_PAL := {"b": Color(0.42, 0.27, 0.15), "l": Color(0.6, 0.4, 0.22), "r": Color(0.85, 0.7, 0.5)}

const ATES_1 := [
	"....y...",
	"...yy...",
	"..yoyy..",
	"..oyyo..",
	".ooyyoo.",
	".orrrro.",
	"bbobbobb",
	".bbbbbb.",
]
const ATES_2 := [
	"...y....",
	"...yy...",
	"..yyoy..",
	"..oyyo..",
	".ooyyoo.",
	".orrrro.",
	"bbobbobb",
	".bbbbbb.",
]
const ATES_SONUK := [
	"........",
	"........",
	"........",
	"........",
	"........",
	"..gggg..",
	"bbbbbbbb",
	".bbbbbb.",
]
const ATES_PAL := {
	"y": Color(1.0, 0.95, 0.5), "o": Color(1.0, 0.6, 0.2), "r": Color(0.9, 0.25, 0.15),
	"b": Color(0.42, 0.27, 0.15), "g": Color(0.4, 0.4, 0.42),
}

## Meleğin aksesuarları (yardım ödülleri, sadece görsel)
const TAC := ["w.w.w.w", "ggggggg"]
const TAC_PAL := {"w": Color(1, 1, 1), "g": Color(0.45, 0.75, 0.35)}
const FENER := [".k.", "kyk", "kyk", ".k."]
const FENER_PAL := {"k": Color(0.3, 0.25, 0.2), "y": Color(1.0, 0.85, 0.4)}


static func texture(rows: Array, palette: Dictionary) -> ImageTexture:
	var w := 0
	for r: String in rows:
		w = maxi(w, r.length())
	var img := Image.create(w, rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch != "." and palette.has(ch):
				img.set_pixel(x, y, palette[ch])
	return ImageTexture.create_from_image(img)


## Yakın komşu filtreli, PIXEL katına büyütülmüş, ayakları orijinde duran sprite
static func sprite(rows: Array, palette: Dictionary) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = texture(rows, palette)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * PIXEL
	s.centered = true
	s.offset = Vector2(0, -rows.size() / 2.0)  # ayak hizası = orijin
	return s
