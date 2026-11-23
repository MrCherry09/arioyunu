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


func _ready() -> void:
	_setup_inputs()
	_spawn = global_position
	# Aşağı inen hareketli platformlarda zeminden kopmasın
	floor_snap_length = 10.0


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		_coyote -= delta
	else:
		_coyote = coyote_time

	_buffer -= delta
	if Input.is_action_just_pressed("jump"):
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
		return

	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider() as Node
		if other == null:
			continue
		if other.is_in_group("hazard") or _is_hazard_tile(other, col):
			respawn()
			return
		# Çöken platform gibi üstüne basılınca tepki veren şeyler
		if col.get_normal().y < -0.5 and other.has_method("on_player_landed"):
			other.on_player_landed()


## TileSet'te "hazard" özel verisi işaretli bir tile'a mı çarptık?
func _is_hazard_tile(other: Node, col: KinematicCollision2D) -> bool:
	var layer := other as TileMapLayer
	if layer == null or layer.tile_set == null:
		return false
	# Çarpışma noktasından tile'ın içine doğru biraz ilerleyip o hücreye bak
	var point := col.get_position() - col.get_normal() * 2.0
	var data := layer.get_cell_tile_data(layer.local_to_map(layer.to_local(point)))
	return data != null and data.get_custom_data("hazard") == true


func set_spawn(pos: Vector2) -> void:
	_spawn = pos


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
