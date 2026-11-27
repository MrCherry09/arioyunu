class_name Player
extends CharacterBody2D
## Platformer karakteri.
## Yetenekler: yürüme, zıplama (coyote + tampon + değişken yükseklik), çift zıplama,
## dash, duvar kayma/zıplama, yere çakılma, süzülme, kayma/sürünme,
## tek yönlü platformdan inme. Ortamla etkileşim: zıplama yastığı, rüzgar,
## buz/bant zemin, kırılabilir blok, düşman.

@export_group("Hareket")
@export var speed := 320.0
@export var acceleration := 2400.0
@export var friction := 2800.0
@export var fall_limit := 900.0     ## Bu y değerinin altına düşünce başa dön

@export_group("Zıplama")
@export var jump_velocity := -520.0
@export var coyote_time := 0.1      ## Kenardan düştükten sonra hâlâ zıplanabilen süre
@export var jump_buffer := 0.12     ## Yere değmeden hemen önce basılan zıplamayı hatırlama süresi
@export var air_jumps := 1          ## Havada kaç kez daha zıplanabilir (1 = çift zıplama)
@export var air_jump_velocity := -460.0

@export_group("Dash")
@export var dash_speed := 950.0
@export var dash_time := 0.14
@export var dash_cooldown := 0.45

@export_group("Duvar")
@export var wall_slide_speed := 110.0   ## Duvara tutunurken en fazla düşme hızı
@export var wall_jump_push := 380.0     ## Duvardan zıplarken yatay itiş
@export var wall_jump_lock := 0.16      ## Duvardan zıplayınca yön tuşunun yok sayıldığı süre

@export_group("Yere Çakılma")
@export var pound_speed := 1300.0

@export_group("Süzülme")
@export var glide_fall_speed := 90.0    ## Space basılıyken en fazla düşme hızı
@export var glide_wind_mult := 2.0      ## Süzülürken rüzgardan ne kadar fazla etkilenir
@export var max_rise_in_wind := 380.0
@export var wind_drift := 0.25          ## Yatay rüzgar kuvvetinin ne kadarı yürüme hızına eklenir

@export_group("Kutu")
@export var push_speed := 170.0         ## Kutu iterken yürüme hızı

@export_group("Kayma")
@export var slide_speed := 680.0
@export var slide_time := 0.35
@export var crawl_speed := 160.0        ## Çömelik/alçak tavan altında yürüme hızı

signal respawned
signal died

const COLOR_NORMAL := Color(0.95, 0.55, 0.2)
const COLOR_DASH := Color(0.45, 0.9, 1.0)
const COLOR_POUND := Color(1.0, 0.3, 0.3)
const COLOR_WALL := Color(1.0, 0.8, 0.35)
const COLOR_GLIDE := Color(0.7, 1.0, 0.5)
const COLOR_SLIDE := Color(0.8, 0.5, 1.0)

const STAND_SIZE := Vector2(32, 48)
const SLIDE_SIZE := Vector2(32, 24)
const ONE_WAY_LAYER := 2

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _spawn: Vector2
var _coyote := 0.0
var _buffer := 0.0
var _air_jumps_left := 0
var _facing := 1.0
var _jumping := false           ## Kendi zıplamamız mı (yastık sekmesi değil) → kısa basış kesebilir

var _dash_timer := 0.0
var _dash_cd := 0.0
var _dash_dir := 1.0
var _can_air_dash := true

var _wall_lock := 0.0
var _pounding := false
var _smashed_pound := false     ## Çakılırken blok kırıldı → yere değmiş sayma, düşmeye devam

var _sliding := false
var _slide_timer := 0.0
var _slide_dir := 1.0

var _drop_timer := 0.0
var _floor_body: Object = null
var _winds: Array[Node] = []
var _gliding := false

## Diyalog sırasında true: oyuncu girdileri yok sayılır, karakter yavaşça durur
var input_locked := false

## Hikâye eşyaları: {"rope": 1, "wood": 3}
var items: Dictionary = {}

@onready var _visual: ColorRect = $Visual  ## Eski renkli kutu: gizli, sprite yoksa yedek
var _sprite: Sprite2D
var _frames := {}
@onready var _col: CollisionShape2D = $Shape
var _shape: RectangleShape2D


func _ready() -> void:
	GameInput.setup()
	_spawn = global_position
	_make_sprite()
	# Kayarken boyutu değiştireceğiz; sahnedeki paylaşılan şekli bozmamak için kopyala
	_shape = (_col.shape as RectangleShape2D).duplicate()
	_col.shape = _shape
	set_collision_mask_value(ONE_WAY_LAYER, true)


# --- Dışarıdan çağrılanlar (seviye elemanları) ---

func set_spawn(pos: Vector2) -> void:
	_spawn = pos


func is_attacking() -> bool:
	return _dash_timer > 0.0 or _pounding


## Zıplama yastığı / düşman üstü sekmesi. Hava hakları yenilenir.
func bounce(strength: float) -> void:
	velocity.y = -strength
	_pounding = false
	_dash_timer = 0.0
	_jumping = false
	_coyote = 0.0
	_buffer = 0.0
	_air_jumps_left = air_jumps
	_can_air_dash = true


func die() -> void:
	died.emit()
	respawn()


func add_wind(zone: Node) -> void:
	if zone not in _winds:
		_winds.append(zone)


func remove_wind(zone: Node) -> void:
	_winds.erase(zone)


# --- Fizik ---

func _physics_process(delta: float) -> void:
	if input_locked:
		if not is_on_floor():
			velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		_finish_move(COLOR_NORMAL)
		return

	var on_floor := is_on_floor() and not _smashed_pound
	_smashed_pound = false

	var dir := Input.get_axis("move_left", "move_right")
	if _wall_lock > 0.0:
		_wall_lock -= delta
		dir = 0.0
	if dir != 0.0:
		_facing = signf(dir)

	if on_floor:
		_coyote = coyote_time
		_air_jumps_left = air_jumps
		_can_air_dash = true
		_pounding = false
		_jumping = false
	else:
		_coyote -= delta

	_dash_cd -= delta
	_buffer -= delta
	if _drop_timer > 0.0:
		_drop_timer -= delta
		if _drop_timer <= 0.0:
			set_collision_mask_value(ONE_WAY_LAYER, true)

	var jump_pressed := Input.is_action_just_pressed("jump")
	if jump_pressed:
		_buffer = jump_buffer

	# --- Tek yönlü platformdan in: S basılıyken Space ---
	if on_floor and jump_pressed and Input.is_action_pressed("down") and _on_one_way():
		_drop_timer = 0.25
		set_collision_mask_value(ONE_WAY_LAYER, false)
		_buffer = 0.0
		_coyote = 0.0
		jump_pressed = false

	# --- Dash: kısa süre yerçekimsiz, sabit hızla ileri atıl ---
	if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0 and _dash_timer <= 0.0 \
			and (on_floor or _can_air_dash) and _can_stand():
		_end_slide()
		_dash_timer = dash_time
		_dash_cd = dash_cooldown
		_dash_dir = signf(dir) if dir != 0.0 else _facing
		_pounding = false
		if not on_floor:
			_can_air_dash = false

	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity = Vector2(_dash_dir * dash_speed, 0.0)
		if _dash_timer <= 0.0:
			velocity.x = _dash_dir * speed  # dash bitince hızı normale indir
		_finish_move(COLOR_DASH)
		return

	# --- Yere çakılma: havada S ---
	if not on_floor and not _pounding and not _sliding and Input.is_action_just_pressed("down"):
		_pounding = true
	if _pounding:
		velocity = Vector2(0.0, pound_speed)
		_finish_move(COLOR_POUND)
		return

	# --- Kayma: yerde S. Alçak tavan altında kalırsa sürünmeye devam eder ---
	if on_floor and not _sliding and Input.is_action_just_pressed("down") \
			and not Input.is_action_pressed("jump"):
		_start_slide(dir)
	if _sliding:
		_slide_timer -= delta
		if jump_pressed and _can_stand():
			_end_slide()  # aşağıdaki normal zıplama devralır
		elif _slide_timer <= 0.0 and not Input.is_action_pressed("down") and _can_stand():
			_end_slide()
		else:
			if _slide_timer > 0.0:
				var t := _slide_timer / slide_time
				velocity.x = _slide_dir * lerpf(crawl_speed, slide_speed, t)
			else:
				# Kayma bitti ama S basılı veya tavan alçak: çömelerek yürü
				velocity.x = dir * crawl_speed
			if not on_floor:
				velocity.y += gravity * delta
			_finish_move(COLOR_SLIDE)
			return

	# --- Yerçekimi, duvarda kayma, süzülme ---
	var wall_normal := get_wall_normal() if is_on_wall_only() else Vector2.ZERO
	var wall_sliding := wall_normal != Vector2.ZERO and dir != 0.0 \
			and signf(dir) == -signf(wall_normal.x) and velocity.y > 0.0
	var wind := _wind_force()
	# Süzülme: Space basılı ve havada. Zıplamanın tepesine yaklaşınca ya da yukarı akımdayken
	# başlar; başladıktan sonra Space bırakılana kadar sürer (akım yukarı itse bile kesilmez).
	var gliding := not on_floor and not wall_sliding and Input.is_action_pressed("jump") \
			and (_gliding or velocity.y > -60.0 or wind.y < 0.0)
	if not on_floor:
		velocity.y += gravity * delta
		if wall_sliding:
			velocity.y = minf(velocity.y, wall_slide_speed)
		elif gliding:
			velocity.y = minf(velocity.y, glide_fall_speed)

	# --- Rüzgar ---
	# Dikey: ivme olarak etki eder (yukarı akım). Yatay: yürüme hedef hızını kaydırır,
	# böylece karşı rüzgarda yavaşlar, rüzgar yönünde hızlanır, dururken sürüklenirsin.
	var wind_mult := glide_wind_mult if gliding else 1.0
	var drift := wind.x * wind_mult * wind_drift
	if wind.y != 0.0 and not (on_floor and wind.y < 0.0):  # yerde dururken titremesin
		velocity.y += wind.y * wind_mult * delta
		if wind.y < 0.0:
			velocity.y = maxf(velocity.y, -max_rise_in_wind)

	# --- Zıplama: yer (coyote) > duvar > hava ---
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_buffer = 0.0
		_coyote = 0.0
		_jumping = true
	elif _buffer > 0.0 and wall_normal != Vector2.ZERO:
		velocity = Vector2(wall_normal.x * wall_jump_push, jump_velocity)
		_facing = signf(wall_normal.x)
		_wall_lock = wall_jump_lock
		_buffer = 0.0
		_air_jumps_left = air_jumps
		_can_air_dash = true
		_jumping = true
	elif jump_pressed and _air_jumps_left > 0:
		velocity.y = air_jump_velocity
		_air_jumps_left -= 1
		_buffer = 0.0
		_jumping = true

	# Tuş erken bırakılırsa daha alçak zıpla
	if Input.is_action_just_released("jump") and velocity.y < 0.0 and _jumping:
		velocity.y *= 0.5
		_jumping = false

	# --- Yatay hareket (buzda kayganlık zeminden gelir) ---
	if _wall_lock <= 0.0:
		var grip := 1.0
		if on_floor and _floor_body != null:
			var f = _floor_body.get("friction_mult")
			if f != null:
				grip = f
		if dir != 0.0:
			velocity.x = move_toward(velocity.x, dir * speed + drift, acceleration * grip * delta)
		else:
			velocity.x = move_toward(velocity.x, drift, friction * grip * delta)

	_gliding = gliding
	var color := COLOR_NORMAL
	if wall_sliding:
		color = COLOR_WALL
	elif gliding:
		color = COLOR_GLIDE
	_finish_move(color)


func _finish_move(color: Color) -> void:
	_update_sprite(color)
	move_and_slide()

	_floor_body = null
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var body := c.get_collider()
		if body == null:
			continue
		if c.get_normal().y < -0.7:
			_floor_body = body
		# Kutuyu yandan it (üstündeyken değil)
		if absf(c.get_normal().x) > 0.7 and body.has_method("push"):
			var push_dir := -signf(c.get_normal().x)
			body.push(push_dir * push_speed)
			if _dash_timer <= 0.0:
				velocity.x = push_dir * push_speed  # kutuya takılıp durmasın, onunla birlikte ilerlesin
		if is_attacking() and body.has_method("smash"):
			body.smash()
			if _pounding:
				_smashed_pound = true

	if global_position.y > fall_limit:
		die()


# --- Görünüm (piksel art yolcu) ---

func _make_sprite() -> void:
	for key: String in ["idle", "walk1", "walk2", "jump", "slide"]:
		var rows: Array = {
			"idle": PixelArt.PLAYER_IDLE, "walk1": PixelArt.PLAYER_WALK_1, "walk2": PixelArt.PLAYER_WALK_2,
			"jump": PixelArt.PLAYER_JUMP, "slide": PixelArt.PLAYER_SLIDE,
		}[key]
		_frames[key] = PixelArt.texture(rows, PixelArt.PLAYER_PAL)
	_sprite = PixelArt.sprite(PixelArt.PLAYER_IDLE, PixelArt.PLAYER_PAL)
	_sprite.position = Vector2(0, STAND_SIZE.y / 2.0)  # ayaklar çarpışma kutusunun altında
	add_child(_sprite)
	_visual.hide()


## Duruma göre kare seç; özel durumlar (dash, çakılma, süzülme...) hafif renk tonu olarak görünür
func _update_sprite(state_color: Color) -> void:
	_visual.color = state_color
	if _sprite == null:
		return
	var key := "idle"
	if _sliding:
		key = "slide"
	elif not is_on_floor():
		key = "jump"
	elif absf(velocity.x) > 30.0:
		key = "walk1" if (Time.get_ticks_msec() / 130) % 2 == 0 else "walk2"
	_sprite.texture = _frames[key]
	_sprite.flip_h = _facing < 0.0
	_sprite.modulate = Color.WHITE if state_color == COLOR_NORMAL else Color.WHITE.lerp(state_color, 0.55)


func _wind_force() -> Vector2:
	var total := Vector2.ZERO
	for z in _winds:
		if is_instance_valid(z):
			total += z.get("force")
	return total


func _on_one_way() -> bool:
	return _floor_body is Node and (_floor_body as Node).is_in_group("one_way")


# --- Kayma yardımcıları ---

func _start_slide(dir: float) -> void:
	_sliding = true
	_slide_timer = slide_time
	_slide_dir = signf(dir) if dir != 0.0 else _facing
	_set_small(true)


func _end_slide() -> void:
	if not _sliding:
		return
	_sliding = false
	_set_small(false)


func _set_small(small: bool) -> void:
	# Ayak hizası aynı kalır, sadece üst kısım alçalır
	_shape.size = SLIDE_SIZE if small else STAND_SIZE
	_col.position.y = (STAND_SIZE.y - SLIDE_SIZE.y) / 2.0 if small else 0.0
	_visual.offset_top = 0.0 if small else -STAND_SIZE.y / 2.0


func _can_stand() -> bool:
	if not _sliding:
		return true
	return not test_move(global_transform, Vector2(0, -(STAND_SIZE.y - SLIDE_SIZE.y)))


func respawn() -> void:
	global_position = _spawn
	velocity = Vector2.ZERO
	_dash_timer = 0.0
	_pounding = false
	_wall_lock = 0.0
	_jumping = false
	_end_slide()
	_drop_timer = 0.0
	set_collision_mask_value(ONE_WAY_LAYER, true)
	# Işınlanmayı ara karelerde süzülme olarak göstermesin
	reset_physics_interpolation()
	respawned.emit()
