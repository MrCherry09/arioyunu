extends Area2D
## Işık topu (piksel art): meleği iyileştirmek için toplanır.
## Tüm görseller koddan, seçilen renge göre piksel piksel üretilir ve PIXEL kat büyütülür
## (yakın komşu filtre, bulanıklaşma yok). Elle çizilmiş bir sprite ile değiştirmek istersen
## _make_orb_frames()'in döndürdüğü kareleri bir PNG'den yüklemen yeterli.
##
## Görünüm: arkada nabız gibi atan piksel ışık aurası (Bayer dither ile seyrelen), yavaşça dönen
## piksel ışık hüzmeleri, 4 karelik nabız animasyonlu top (dış halede dither), dönen piksel
## kıvılcımlar, ara sıra çakan "+" yıldızcıklar, yukarı uçan piksel tozları.
## Toplanınca "angel" grubundaki düğüme (yoksa oyuncuya) uçar; beyaz flaş, dışa fırlayan
## hüzmeler, iki şok halkası, piksel patlaması ve hafif kamera sarsıntısı yapar,
## heal(heal_amount) çağırır.

signal collected(amount: float)

@export var heal_amount := 10.0
@export var color := Color(1.0, 0.85, 0.5)   ## Ana renk (sıcak altın)
@export var radius := 14.0                   ## Ekran pikseli cinsinden yaklaşık yarıçap

const PIXEL := 3          ## 1 sanat pikseli = 3 ekran pikseli
const FLY_TIME := 0.45
const ANIM_FPS := 6.0
const GLOW := 2.2         ## Çekirdek parlaklığı (1'in üstü → bloom)
const RAY_GLOW := 1.4     ## Hüzmelerin parlaklığı

var _body: Node2D
var _aura: Sprite2D      ## Büyük piksel parıltı: merkezden dışa doğru dither ile seyrelir (4 karelik nabız)
var _rays: Sprite2D      ## Dönen piksel hüzmeler (8 kare)
var _orb: Sprite2D
var _core: Sprite2D      ## Aynı karelerin sadece çekirdek pikselleri; bloom'u bu verir
var _orbit: Node2D
var _dust: CPUParticles2D
var _twinkle: Sprite2D
var _taken := false
var _t := 0.0
var _twinkle_timer := 0.0

static var _cache := {}   ## Aynı renk/boyuttaki toplar dokuları paylaşır


func _ready() -> void:
	add_to_group("light_orbs")
	collision_layer = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_t = randf() * 10.0
	_twinkle_timer = randf_range(0.5, 2.0)

	_body = Node2D.new()
	add_child(_body)

	# Arka aura: topun etrafındaki büyük piksel parıltı; toplar ortamı aydınlatıyormuş gibi görünür
	_aura = Sprite2D.new()
	_aura.texture = _aura_frames()
	_aura.hframes = 4
	_aura.scale = Vector2.ONE * PIXEL
	_aura.material = _additive()
	_body.add_child(_aura)

	_rays = Sprite2D.new()
	_rays.texture = _ray_frames()
	_rays.hframes = 8
	_rays.scale = Vector2.ONE * PIXEL
	_rays.material = _additive()
	_rays.self_modulate = Color(RAY_GLOW, RAY_GLOW, RAY_GLOW)
	_body.add_child(_rays)

	var frames := _orb_frames()
	_orb = Sprite2D.new()
	_orb.texture = frames
	_orb.hframes = 4
	_orb.scale = Vector2.ONE * PIXEL
	_body.add_child(_orb)
	_core = Sprite2D.new()
	_core.texture = _orb_frames(true)
	_core.hframes = 4
	_core.scale = Vector2.ONE * PIXEL
	_core.self_modulate = Color(GLOW, GLOW, GLOW)
	_body.add_child(_core)

	# Dönen 3 piksel kıvılcım (2x2 sanat pikseli)
	_orbit = Node2D.new()
	_body.add_child(_orbit)
	for i in 3:
		var s := _pixel_sprite(Color(color.lightened(0.6), 1.0), 2 if i == 0 else 1)
		_orbit.add_child(s)

	# Ara sıra çakan "+" yıldızcık
	_twinkle = Sprite2D.new()
	_twinkle.texture = _plus_texture()
	_twinkle.scale = Vector2.ONE * PIXEL
	_twinkle.self_modulate = Color(1.3, 1.3, 1.3)
	_twinkle.hide()
	_body.add_child(_twinkle)

	# Yukarı uçan piksel tozları
	_dust = CPUParticles2D.new()
	_dust.amount = 8
	_dust.lifetime = 1.3
	_dust.texture = _dot_texture()
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(radius * 0.8, radius * 0.4)
	_dust.direction = Vector2.UP
	_dust.spread = 10.0
	_dust.gravity = Vector2.ZERO
	_dust.initial_velocity_min = 12.0
	_dust.initial_velocity_max = 24.0
	_dust.scale_amount_min = PIXEL
	_dust.scale_amount_max = PIXEL
	_dust.color_ramp = _step_ramp(color.lightened(0.4))
	_body.add_child(_dust)

	var shape := CircleShape2D.new()
	shape.radius = radius + 6.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _taken:
		return
	_t += delta
	# Piksel ızgarasına oturan süzülme ve animasyon
	_body.position.y = _snap(sin(_t * 2.0) * 5.0)
	_orb.frame = int(_t * ANIM_FPS) % 4
	_core.frame = _orb.frame
	_rays.frame = int(_t * 7.0) % 8
	_aura.frame = [0, 1, 2, 3, 2, 1][int(_t * 5.0) % 6]   # ileri-geri nabız
	_rays.self_modulate.a = 0.75 + sin(_t * 4.3) * 0.25

	var r := radius * 1.6
	for i in _orbit.get_child_count():
		var a := _t * 2.2 + TAU * i / 3.0
		# Hafif elips: önden geçerken aşağı, arkadan geçerken yukarı
		_orbit.get_child(i).position = Vector2(_snap(cos(a) * r), _snap(sin(a) * r * 0.45))

	_twinkle_timer -= delta
	if _twinkle_timer <= 0.0:
		_twinkle_timer = randf_range(0.8, 2.2)
		_twinkle.position = Vector2(_snap(randf_range(-r, r)), _snap(randf_range(-r, r * 0.3)))
		_twinkle.show()
		get_tree().create_timer(0.18).timeout.connect(_twinkle.hide)


func _snap(v: float) -> float:
	return roundf(v / PIXEL) * PIXEL


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body is Player:
		return
	_taken = true
	set_deferred("monitoring", false)
	_collect(body)


func _collect(player: Node2D) -> void:
	var target: Node2D = player
	var angels := get_tree().get_nodes_in_group("angel")
	if not angels.is_empty():
		target = angels[0]
	_dust.emitting = false
	_orbit.hide()
	_twinkle.hide()
	_rays.hide()
	_body.position = Vector2.ZERO
	var start := global_position
	var tw := create_tween()
	tw.tween_method(_fly_step.bind(start, target), 0.0, 1.0, FLY_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(_burst.bind(target))


## Hedefe doğru kavisli uçuş; konum piksel ızgarasına oturur, top uçarken küçülür
func _fly_step(t: float, start: Vector2, target: Node2D) -> void:
	var end := target.global_position + Vector2(0, -10)
	var ctrl := (start + end) / 2.0 + Vector2(0, -90)
	var p := start.lerp(ctrl, t).lerp(ctrl.lerp(end, t), t)
	global_position = Vector2(_snap(p.x), _snap(p.y))
	_orb.frame = int(t * 8.0) % 4
	_core.frame = _orb.frame
	_body.scale = Vector2.ONE if t < 0.6 else Vector2(0.67, 0.67)
	_aura.modulate = Color(1, 1, 1, 1.0 + t * 0.6)   # hedefe yaklaştıkça parlar


func _burst(target: Node2D) -> void:
	_body.hide()
	collected.emit(heal_amount)
	if target.has_method("heal"):
		target.heal(heal_amount)

	# 1) Beyaz flaş: içi dolu piksel daire, 3 karede büyüyüp seyrelir (bloom ile patlar)
	var flash := _frame_sprite(_flash_frames(), 3, Color(1.6, 1.5, 1.35))
	# 2) Dışa fırlayan 12 hüzme
	var burst := _frame_sprite(_burst_frames(), 6, Color(RAY_GLOW, RAY_GLOW, RAY_GLOW))
	burst.material = _additive()
	# 3) İki şok halkası (ikincisi gecikmeli ve beyaz)
	var ring := _frame_sprite(_ring_frames(), 5, Color(1.25, 1.25, 1.25))
	var ring2 := _frame_sprite(_ring_frames(), 5, Color(1.5, 1.5, 1.5))
	ring2.hide()
	# 4) Büyük piksel parıltı dalgası: dither'lı disk dışa doğru büyüyüp seyrelir
	var glow := _frame_sprite(_glow_burst_frames(), 6, Color(1, 1, 1))
	glow.material = _additive()
	move_child(glow, 0)  # diğer efektlerin arkasında kalsın

	# 5) Kare piksel patlaması: iri, hızlı, yerçekimiyle saçılan
	var boom := CPUParticles2D.new()
	boom.one_shot = true
	boom.explosiveness = 1.0
	boom.amount = 40
	boom.lifetime = 0.8
	boom.texture = _dot_texture()
	boom.spread = 180.0
	boom.gravity = Vector2(0, 260)
	boom.initial_velocity_min = 120.0
	boom.initial_velocity_max = 300.0
	boom.damping_min = 120.0
	boom.damping_max = 220.0
	boom.scale_amount_min = PIXEL
	boom.scale_amount_max = PIXEL * 2
	boom.color_ramp = _step_ramp(Color(color.lightened(0.5) * 1.4, 1.0))
	add_child(boom)
	boom.emitting = true

	_shake_camera()

	var tw := create_tween()
	for f in 6:
		tw.tween_callback(func() -> void:
			glow.frame = f
			flash.frame = mini(f, 2)
			flash.visible = f < 3
			burst.frame = f
			ring.frame = mini(f, 4)
			ring.visible = f < 5
			if f >= 1:
				ring2.show()
				ring2.frame = f - 1)
		tw.tween_interval(0.07)
	tw.tween_callback(func() -> void:
		burst.hide()
		glow.hide()
		ring2.hide())
	tw.tween_interval(0.6)
	tw.tween_callback(queue_free)


func _frame_sprite(tex: Texture2D, frames: int, tint: Color) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.hframes = frames
	sp.scale = Vector2.ONE * PIXEL
	sp.self_modulate = tint
	add_child(sp)
	return sp


## Kısa, piksel ızgarasına oturan kamera sarsıntısı
func _shake_camera() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var tw := cam.create_tween()
	for i in 5:
		var amp := (5 - i) * 1.5
		tw.tween_property(cam, "offset", Vector2(_snap(randf_range(-amp, amp)), _snap(randf_range(-amp, amp))), 0.03)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.03)


# =====================================================================
# Piksel art üretimi
# =====================================================================

## 4 karelik top animasyonu (yan yana). Katmanlar: dither hale → koyu kenar → ana renk →
## açık iç → beyaz çekirdek + sol üstte parlama pikseli.
func _orb_frames(core_only := false) -> Texture2D:
	var key := "orb_%s_%d_%s" % [color.to_html(), int(radius), core_only]
	if _cache.has(key):
		return _cache[key]
	var R := radius / PIXEL                  # sanat pikseli cinsinden yarıçap
	var size := int(ceil(R * 3.6)) + 2
	if size % 2 == 1:
		size += 1
	var img := Image.create(size * 4, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) / 2.0 - Vector2(0.5, 0.5)

	var core := Color(1, 1, 1)
	var inner := color.lightened(0.55)
	var mid := color
	var edge := color.darkened(0.25)
	var halo := Color(color.lightened(0.2), 0.55)
	var pulse := [0.0, 0.35, 0.6, 0.35]       # dış katmanlar nefes alır

	for f in 4:
		var p: float = pulse[f]
		for y in size:
			for x in size:
				var d := Vector2(x, y).distance_to(c)
				var px := Color(0, 0, 0, 0)
				if d <= R * 0.38:
					px = core
				elif core_only:
					pass
				elif d <= R * 0.7:
					px = inner
				elif d <= R * 1.0 + p * 0.3:
					px = mid
				elif d <= R * 1.25 + p * 0.5:
					px = edge
				elif d <= R * 1.7 + p:
					if (x + y + f) % 2 == 0:  # dama tahtası dither: yumuşak hale
						px = halo
				img.set_pixel(f * size + x, y, px)
		# Parlama pikseli (sol üst)
		var h := c + Vector2(-R * 0.45, -R * 0.45)
		img.set_pixel(f * size + int(round(h.x)), int(round(h.y)), Color(1, 1, 1))

	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Dönen piksel hüzmeler: 8 uzun/kısa ışın, 8 karede 45° döner (simetri sayesinde kesintisiz döngü).
## Uzun ışınlar dibinde 2 piksel kalın, uca doğru incelip söner.
func _ray_frames() -> Texture2D:
	var key := "rays_%s_%d" % [color.to_html(), int(radius)]
	if _cache.has(key):
		return _cache[key]
	var R := radius / PIXEL
	var size := int(ceil(R * 8.0)) + 2
	var img := Image.create(size * 8, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) / 2.0 - Vector2(0.5, 0.5)
	var col := color.lightened(0.45)
	for f in 8:
		var base := f * (TAU / 8.0) / 8.0
		for i in 8:
			var ang := base + TAU * i / 8.0
			var dir := Vector2.from_angle(ang)
			var long := i % 2 == 0
			var r0 := R * 1.45
			var r1 := R * (3.7 if long else 2.5)
			var t := r0
			while t <= r1:
				var k := (t - r0) / (r1 - r0)
				var a := (1.0 - k) * (0.95 if long else 0.7)
				_plot_max(img, f * size, size, c + dir * t, Color(col, a))
				if long and k < 0.4:
					_plot_max(img, f * size, size, c + dir * t + dir.orthogonal() * 0.8, Color(col, a * 0.7))
				t += 0.4
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Toplanınca dışa fırlayan 12 hüzme: 6 kare
func _burst_frames() -> Texture2D:
	var key := "burst_%s_%d" % [color.to_html(), int(radius)]
	if _cache.has(key):
		return _cache[key]
	var R := radius / PIXEL
	var size := int(ceil(R * 11.0)) + 2
	var img := Image.create(size * 6, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) / 2.0 - Vector2(0.5, 0.5)
	var col := color.lightened(0.6)
	for f in 6:
		var r0 := R * (1.2 + f * 0.75)
		var r1 := R * (2.2 + f * 1.15)
		var fade := 1.0 - f * 0.15
		for i in 12:
			var dir := Vector2.from_angle(TAU * i / 12.0 + 0.13)
			var t := r0
			while t <= r1:
				_plot_max(img, f * size, size, c + dir * t, Color(col, fade))
				t += 0.4
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Beyaz flaş: içi dolu daire, 3 karede büyür; son karede dither ile seyrelir
func _flash_frames() -> Texture2D:
	var key := "flash_%d" % int(radius)
	if _cache.has(key):
		return _cache[key]
	var R := radius / PIXEL
	var size := int(ceil(R * 5.0)) + 2
	var img := Image.create(size * 3, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) / 2.0 - Vector2(0.5, 0.5)
	for f in 3:
		var rr := R * (1.3 + f * 0.6)
		for y in size:
			for x in size:
				if Vector2(x, y).distance_to(c) <= rr and (f < 2 or (x + y) % 2 == 0):
					img.set_pixel(f * size + x, y, Color(1, 1, 1, 1.0 - f * 0.25))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _plot_max(img: Image, ox: int, size: int, p: Vector2, col: Color) -> void:
	var x := int(round(p.x))
	var y := int(round(p.y))
	if x < 0 or y < 0 or x >= size or y >= size:
		return
	if img.get_pixel(ox + x, y).a < col.a:
		img.set_pixel(ox + x, y, col)


## 4x4 Bayer matrisi: düzenli dither eşiği (0..1). Yumuşak geçişleri piksel desenine çevirir.
const BAYER := [
	[0.0, 8.0, 2.0, 10.0],
	[12.0, 4.0, 14.0, 6.0],
	[3.0, 11.0, 1.0, 9.0],
	[15.0, 7.0, 13.0, 5.0],
]


## Dither'lı piksel parıltı diski çizer: merkezde yoğun, kenara doğru seyrek.
## strength 0..1 arası genel yoğunluk.
static func _dither_disc(img: Image, ox: int, size: int, c: Vector2, rmax: float,
		col: Color, strength: float) -> void:
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(c) / rmax
			if d >= 1.0:
				continue
			var v := pow(1.0 - d, 1.6) * strength          # 0..1 yoğunluk
			var threshold: float = (BAYER[y % 4][x % 4] + 0.5) / 16.0
			if v > threshold:
				# İçte biraz daha opak, dışta soluk: 3 basamak
				var a := 0.5 if v > 0.6 else (0.32 if v > 0.3 else 0.2)
				img.set_pixel(ox + x, y, Color(col, a))


## Topun etrafındaki büyük piksel parıltı: 4 karelik nabız (yarıçap ve yoğunluk atar)
func _aura_frames() -> Texture2D:
	var key := "aura_%s_%d" % [color.to_html(), int(radius)]
	if _cache.has(key):
		return _cache[key]
	var R := radius / PIXEL
	var size := int(ceil(R * 7.4)) + 2
	var img := Image.create(size * 4, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) / 2.0 - Vector2(0.5, 0.5)
	var col := color.lightened(0.15)
	for f in 4:
		_dither_disc(img, f * size, size, c, R * (3.0 + f * 0.22), col, 0.85 + f * 0.05)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Toplanınca dışa yayılan piksel parıltı dalgası: 6 kare, büyüdükçe seyrelir
func _glow_burst_frames() -> Texture2D:
	var key := "glowburst_%s_%d" % [color.to_html(), int(radius)]
	if _cache.has(key):
		return _cache[key]
	var R := radius / PIXEL
	var size := int(ceil(R * 12.0)) + 2
	var img := Image.create(size * 6, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) / 2.0 - Vector2(0.5, 0.5)
	var col := color.lightened(0.35)
	for f in 6:
		_dither_disc(img, f * size, size, c, R * (2.5 + f * 0.75), col, 1.25 - f * 0.2)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


## Toplanınca büyüyen halka: 5 kare, 1 piksel kalınlık
func _ring_frames() -> Texture2D:
	var key := "ring_%s_%d" % [color.to_html(), int(radius)]
	if _cache.has(key):
		return _cache[key]
	var R := radius / PIXEL
	var size := int(ceil(R * 5.0)) + 2
	var img := Image.create(size * 5, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) / 2.0 - Vector2(0.5, 0.5)
	var col := color.lightened(0.5)
	for f in 5:
		var rr := R * (1.0 + f * 0.35)
		var a := 1.0 - f * 0.15
		for y in size:
			for x in size:
				if absf(Vector2(x, y).distance_to(c) - rr) < 0.55:
					img.set_pixel(f * size + x, y, Color(col, a))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## 5x5 "+" yıldızcık: ortası beyaz, kolları renkli
static func _plus_texture() -> Texture2D:
	if _cache.has("plus"):
		return _cache["plus"]
	var img := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	for i in 5:
		var edge := i == 0 or i == 4
		var c := Color(1, 1, 0.85, 0.6) if edge else Color(1, 1, 0.9)
		img.set_pixel(2, i, c)
		img.set_pixel(i, 2, c)
	img.set_pixel(2, 2, Color(1, 1, 1))
	var tex := ImageTexture.create_from_image(img)
	_cache["plus"] = tex
	return tex


## 1x1 beyaz piksel (parçacıklar için; scale ile PIXEL katına büyütülür)
static func _dot_texture() -> Texture2D:
	if _cache.has("dot"):
		return _cache["dot"]
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(1, 1, 1))
	var tex := ImageTexture.create_from_image(img)
	_cache["dot"] = tex
	return tex


func _pixel_sprite(tint: Color, art_px: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _dot_texture()
	s.scale = Vector2.ONE * PIXEL * art_px
	s.self_modulate = tint
	return s


## Basamaklı solma: piksel art'a uygun, yumuşak geçiş yerine 3 adım
static func _step_ramp(c: Color) -> Gradient:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.5, 0.8])
	g.colors = PackedColorArray([Color(c, 1.0), Color(c, 0.6), Color(c, 0.25)])
	return g
