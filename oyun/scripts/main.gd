extends Node2D

@onready var level: Node2D = $Level
@onready var player: CharacterBody2D = $Player
@onready var pcam: Node2D = $PlayerCam
@onready var message: Label = $HUD/Message
@onready var stats: Label = $HUD/Stats

var _time := 0.0
var _deaths := 0
var _cp := 0
var _cp_total := 0
var _won := false
var _msg_tween: Tween


func _ready() -> void:
	message.hide()

	# Herhangi bir katmana boyanmış çöken tile'ları çalışan platformlara çevir
	CrumbleTiles.convert_all(level)

	# Oyuncuyu bölümdeki Spawn noktasına koy
	var spawn := level.get_node("Spawn") as Node2D
	player.global_position = spawn.global_position + Vector2(0, -25)
	player.set_spawn(player.global_position)
	player.reset_physics_interpolation()

	# Bölümün en alt tile'ının biraz altına düşünce başa dön
	var ground := level.get_node("Ground") as TileMapLayer
	player.fall_limit = (ground.get_used_rect().end.y + 4) * ground.tile_set.tile_size.y

	player.respawned.connect(_on_player_respawned)
	level.get_node("Goal").body_entered.connect(_on_goal_body_entered)

	var checkpoints := get_tree().get_nodes_in_group("checkpoint")
	_cp_total = checkpoints.size()
	for cp in checkpoints:
		cp.activated.connect(_on_checkpoint_activated)

	pcam.teleport_position.call_deferred()


func _process(delta: float) -> void:
	if not _won:
		_time += delta
	stats.text = "Süre %.1f   Ölüm %d   Checkpoint %d/%d" % [_time, _deaths, _cp, _cp_total]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and not _won:
		player.respawn()


func _on_player_respawned() -> void:
	_deaths += 1
	# Kamera haritayı kayarak geçmesin, anında ışınlansın
	pcam.teleport_position()


func _on_checkpoint_activated(cp: Area2D) -> void:
	_cp += 1
	player.set_spawn(cp.spawn_position())
	_flash("Checkpoint!")


func _on_goal_body_entered(body: Node2D) -> void:
	if _won or not body is CharacterBody2D:
		return
	_won = true
	_flash("Bitti!  %.1f sn, %d ölüm" % [_time, _deaths], 3.0)
	await get_tree().create_timer(3.5).timeout
	get_tree().reload_current_scene()


func _flash(text: String, hold := 1.0) -> void:
	if _msg_tween:
		_msg_tween.kill()
	message.text = text
	message.modulate.a = 1.0
	message.show()
	_msg_tween = create_tween()
	_msg_tween.tween_interval(hold)
	_msg_tween.tween_property(message, "modulate:a", 0.0, 0.4)
