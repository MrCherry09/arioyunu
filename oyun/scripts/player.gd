extends CharacterBody2D
## Platformer karakteri: yürüme, zıplama (coyote + tampon), çift zıplama,
## dash, duvar kayma/zıplama ve yere çakılma (ground pound).

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

signal respawned

const COLOR_NORMAL := Color(0.95, 0.55, 0.2)
const COLOR_DASH := Color(0.45, 0.9, 1.0)
const COLOR_POUND := Color(1.0, 0.3, 0.3)
const COLOR_WALL := Color(1.0, 0.8, 0.35)

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _spawn: Vector2
var _coyote := 0.0
var _buffer := 0.0
var _air_jumps_left := 0
var _facing := 1.0

var _dash_timer := 0.0
var _dash_cd := 0.0
var _dash_dir := 1.0
var _can_air_dash := true

var _wall_lock := 0.0
var _pounding := false

@onready var _visual: ColorRect = $Visual


func _ready() -> void:
	_setup_inputs()
	_spawn = global_position


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
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
	else:
		_coyote -= delta

	_dash_cd -= delta
	_buffer -= delta
	var jump_pressed := Input.is_action_just_pressed("jump")
	if jump_pressed:
		_buffer = jump_buffer

	# --- Dash: kısa süre yerçekimsiz, sabit hızla ileri atıl ---
	if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0 and _dash_timer <= 0.0 \
			and (on_floor or _can_air_dash):
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

	# --- Yere çakılma: havada aşağı tuşu ---
	if not on_floor and not _pounding and Input.is_action_just_pressed("down"):
		_pounding = true
	if _pounding:
		velocity = Vector2(0.0, pound_speed)
		_finish_move(COLOR_POUND)
		return

	# --- Yerçekimi ve duvarda kayma ---
	var wall_normal := get_wall_normal() if is_on_wall_only() else Vector2.ZERO
	var sliding := wall_normal != Vector2.ZERO and dir != 0.0 \
			and signf(dir) == -signf(wall_normal.x) and velocity.y > 0.0
	if not on_floor:
		velocity.y += gravity * delta
		if sliding:
			velocity.y = minf(velocity.y, wall_slide_speed)

	# --- Zıplama: yer (coyote) > duvar > hava ---
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_buffer = 0.0
		_coyote = 0.0
	elif _buffer > 0.0 and wall_normal != Vector2.ZERO:
		velocity = Vector2(wall_normal.x * wall_jump_push, jump_velocity)
		_facing = signf(wall_normal.x)
		_wall_lock = wall_jump_lock
		_buffer = 0.0
		_air_jumps_left = air_jumps
		_can_air_dash = true
	elif jump_pressed and _air_jumps_left > 0:
		velocity.y = air_jump_velocity
		_air_jumps_left -= 1
		_buffer = 0.0

	# Tuş erken bırakılırsa daha alçak zıpla
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.5

	if _wall_lock <= 0.0:
		if dir != 0.0:
			velocity.x = move_toward(velocity.x, dir * speed, acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	_finish_move(COLOR_WALL if sliding else COLOR_NORMAL)


func _finish_move(color: Color) -> void:
	_visual.color = color
	move_and_slide()
	if global_position.y > fall_limit:
		respawn()


func respawn() -> void:
	global_position = _spawn
	velocity = Vector2.ZERO
	_dash_timer = 0.0
	_pounding = false
	_wall_lock = 0.0
	# Işınlanmayı ara karelerde süzülme olarak göstermesin
	reset_physics_interpolation()
	respawned.emit()


static func _setup_inputs() -> void:
	var map := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE, KEY_W, KEY_UP],
		"down": [KEY_S, KEY_DOWN],
		"dash": [KEY_SHIFT, KEY_K],
		"restart": [KEY_R],
	}
	for action: String in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
