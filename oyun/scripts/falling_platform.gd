extends TileMapLayer
## Üstüne basılınca titreyip düşen, bir süre sonra yerine geri gelen tile platform.
## Oyuncu üstüne indiğinde player.gd `on_player_landed()` çağırır.

@export var shake_time := 0.45
@export var respawn_time := 2.5
@export var fall_gravity := 1600.0

enum State { IDLE, SHAKING, FALLING, GONE }

var _state := State.IDLE
var _timer := 0.0
var _vel := 0.0
var _origin: Vector2


func _ready() -> void:
	use_kinematic_bodies = true
	_origin = position


func on_player_landed() -> void:
	if _state == State.IDLE:
		_state = State.SHAKING
		_timer = shake_time


func _physics_process(delta: float) -> void:
	match _state:
		State.SHAKING:
			_timer -= delta
			# Yanıp sönerek uyar
			var blink := 0.55 + 0.45 * absf(sin(_timer * 30.0))
			modulate = Color(1.0, blink, blink)
			if _timer <= 0.0:
				modulate = Color.WHITE
				_state = State.FALLING
				_vel = 0.0
				_timer = 0.9
		State.FALLING:
			_vel += fall_gravity * delta
			position.y += _vel * delta
			_timer -= delta
			if _timer <= 0.0:
				visible = false
				collision_enabled = false
				_state = State.GONE
				_timer = respawn_time
		State.GONE:
			_timer -= delta
			if _timer <= 0.0:
				position = _origin
				reset_physics_interpolation()
				visible = true
				collision_enabled = true
				_state = State.IDLE
