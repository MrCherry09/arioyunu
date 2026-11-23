extends Node2D

@onready var message: Label = $HUD/Message
var _won := false


func _ready() -> void:
	message.hide()
	$Goal.body_entered.connect(_on_goal_body_entered)
	# Başa dönünce kamera haritayı kayarak geçmesin, anında ışınlansın
	$Player.respawned.connect(func() -> void: $PlayerCam.teleport_position())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _on_goal_body_entered(body: Node2D) -> void:
	if _won or not body is CharacterBody2D:
		return
	_won = true
	message.text = "Kazandın!"
	message.show()
	await get_tree().create_timer(1.5).timeout
	get_tree().reload_current_scene()
