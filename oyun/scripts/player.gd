extends CharacterBody2D
## Basit platformer karakteri: yürüme, zıplama, coyote time, zıplama tamponu.

@export var speed := 320.0
@export var acceleration := 2400.0
@export var friction := 2800.0
@export var jump_velocity := -520.0
@export var coyote_time := 0.1      ## Kenardan düştükten sonra hâlâ zıplanabilen süre
@export var jump_buffer := 0.12     ## Yere değmeden hemen önce basılan zıplamayı hatırlama süresi
@export var fall_limit := 900.0     ## Bu y değerinin altına düşünce başa dön

signal respawned

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _spawn: Vector2
var _coyote := 0.0
var _buffer := 0.0
var jump_count = 0


func _ready() -> void:
	_setup_inputs()
	_spawn = global_position


func _physics_process(delta: float) -> void:
	
	if jump_count > 1:
		_buffer = jump_buffer
		jump_count += 1

	if not is_on_floor():
		velocity.y += gravity * delta
		_coyote -= delta
	else:
		_coyote = coyote_time
		jump_count = 0

	_buffer -= delta
	if Input.is_action_just_pressed("jump") and jump_count < 2:
		jump_count += 1
		_buffer = jump_buffer

	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_buffer = 0.0
		_coyote = 0.0

	# Tuş erken bırakılırsa daha alçak zıpla
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.5

	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		velocity.x = move_toward(velocity.x, dir * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	move_and_slide()

	if global_position.y > fall_limit:
		respawn()


func respawn() -> void:
	global_position = _spawn
	velocity = Vector2.ZERO
	# Işınlanmayı ara karelerde süzülme olarak göstermesin
	reset_physics_interpolation()
	respawned.emit()


static func _setup_inputs() -> void:
	var map := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE, KEY_W, KEY_UP],
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
