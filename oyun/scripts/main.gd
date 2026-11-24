extends Node2D

const PauseMenuScene := preload("res://scenes/ui/pause_menu.tscn")

@onready var message: Label = $HUD/Message
var _won := false


func _ready() -> void:
	message.hide()
	$Goal.body_entered.connect(_on_goal_body_entered)
	# Başa dönünce kamera haritayı kayarak geçmesin, anında ışınlansın
	$Player.respawned.connect(func() -> void: $PlayerCam.teleport_position())
	# Pause menüyü ekle
	_add_pause_menu()
	# Escape tuşunu kaydet (yoksa)
	_setup_pause_input()


## Pause menü sahnesini CanvasLayer olarak ekler.
func _add_pause_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var pm := PauseMenuScene.instantiate()
	layer.add_child(pm)


## "pause" input action'ını kaydet (henüz tanımlı değilse).
static func _setup_pause_input() -> void:
	if InputMap.has_action("pause"):
		return
	InputMap.add_action("pause")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	InputMap.action_add_event("pause", ev)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _on_goal_body_entered(body: Node2D) -> void:
	if _won or not body is CharacterBody2D:
		return
	_won = true
	message.text = "You Win!"
	message.show()
	await get_tree().create_timer(1.5).timeout
	get_tree().reload_current_scene()
