class_name Level
extends Node2D
## Bütün levellerin ortak tabanı. Level sahnesi (scenes/levels/*.tscn) bu betikten türeyen bir
## betikle açılır; şunları kendisi kurar: oyuncu, melek, kamera (level sınırlarıyla), diyalog kutusu,
## QTE, HUD, pause menüsü, quest kaydı, ışık topu sayacı ve level çıkışı.
##
## Sahnede beklenen düğümler:
##   Ground (TileMapLayer)   katı zemin           OneWay (TileMapLayer)  tek yönlü platformlar
##   Spawn (Marker2D)        oyuncunun başladığı yer
##   Exit (trigger_zone)     varınca level tamamlanır (yoksa level kendisi karar verir)
##   Entities (Node2D)       NPC'ler, eşyalar, bulmaca parçaları (adlarıyla bulunur)
## Türeyen betikler _setup() ve _start() içinde kendi questlerini kurar.

const TILE := 48  ## 16 piksellik tile x 3 ölçek

@export var level_index := 1
@export var level_title := ""
@export var level_subtitle := ""
@export var bounds := Rect2i(0, 0, 100, 20)  ## Tile cinsinden level sınırları (kamera bunlarla sınırlanır)
@export var sky_top := Color(0.3, 0.45, 0.55)
@export var sky_bottom := Color(0.6, 0.75, 0.7)

var player: Player
var angel: Node2D
var cam: Camera2D
var dialogue: DialogueBox
var qte: QTE
var hud: LevelHud
var quests: QuestLog
var light_got := 0.0
var light_total := 0.0
var finished := false

const PlayerScene := preload("res://scenes/player.tscn")
const Angel := preload("res://scripts/angel.gd")
const PauseMenuScene := preload("res://scenes/ui/pause_menu.tscn")


func _ready() -> void:
	GameInput.setup()
	add_to_group("level")
	_make_backdrop()
	if has_node("OneWay"):
		get_node("OneWay").add_to_group("one_way")

	player = PlayerScene.instantiate()
	player.position = get_node("Spawn").position if has_node("Spawn") else Vector2(200, 600)
	player.z_index = 10
	add_child(player)
	player.fall_limit = (bounds.end.y + 8) * TILE
	player.respawned.connect(_on_respawned)

	cam = Camera2D.new()
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	cam.limit_left = bounds.position.x * TILE
	cam.limit_top = bounds.position.y * TILE
	cam.limit_right = bounds.end.x * TILE
	cam.limit_bottom = bounds.end.y * TILE
	player.add_child(cam)
	cam.make_current()

	angel = Angel.new()
	angel.player = player
	add_child(angel)

	dialogue = DialogueBox.new()
	dialogue.player = player
	add_child(dialogue)
	qte = QTE.new()
	qte.player = player
	add_child(qte)
	quests = QuestLog.new()
	add_child(quests)
	hud = LevelHud.new()
	add_child(hud)
	hud.bind(quests)
	_add_pause_menu()

	for orb in find_children("*", "Area2D", true, false):
		if orb.is_in_group("light_orbs") or orb.has_method("_fly_step"):
			light_total += orb.heal_amount
			orb.collected.connect(func(a: float) -> void:
				light_got += a
				hud.set_light(light_got, light_total))
	hud.set_light(light_got, light_total)

	var exit := get_node_or_null("Exit")
	if exit:
		exit.entered.connect(func(b: Node2D) -> void:
			if b is Player:
				_on_exit_reached())

	_setup()
	await get_tree().process_frame
	cam.reset_smoothing()
	_start()


# --- Türeyen levellerin dolduracağı yerler ---

## Questleri, NPC diyaloglarını, sinyalleri bağla (oyuncu ve arayüz hazır)
func _setup() -> void:
	pass


## Level başladığında (ör. açılış sahnesi, başlık)
func _start() -> void:
	hud.show_title(level_title, level_subtitle)


## Çıkışa varınca; varsayılan: level tamamlanır
func _on_exit_reached() -> void:
	complete()


# --- Yardımcılar ---

## Entities altındaki (ya da herhangi bir yerdeki) düğümü adıyla bul
func ent(node_name: String) -> Node:
	var n := get_node_or_null("Entities/" + node_name)
	return n if n else find_child(node_name, true, false)


## Satırları söyle ve bitmesini bekle
func say(lines: Array) -> void:
	if lines.is_empty():
		return
	dialogue.play(lines)
	await dialogue.finished


func story() -> Dictionary:
	var flow := get_node_or_null("/root/GameFlow")
	return flow.story if flow else {}


## Quest ödülü: verilen yerde bir ışık topu belirir (toplanınca meleği iyileştirir)
func reward_orb(pos: Vector2, heal := 10.0) -> void:
	var o: Area2D = load("res://scripts/elements/light_orb.gd").new()
	o.heal_amount = heal
	o.radius = 14.0 if heal <= 10.0 else 20.0
	o.position = pos
	add_child(o)
	light_total += heal
	hud.set_light(light_got, light_total)
	o.collected.connect(func(a: float) -> void:
		light_got += a
		hud.set_light(light_got, light_total))


## Melek takip etmeye başlasın / bıraksın (açılışta melek henüz yanımızda değil)
func set_angel_following(on: bool) -> void:
	angel.visible = on
	angel.player = player if on else null
	if on:
		angel.add_to_group("angel")
		angel.snap_to_player()
	else:
		angel.remove_from_group("angel")  # ışık topları o zamana kadar oyuncuya uçsun


## Level'ı bitir: sonraki geçişe (cutscene + yükleme) geç
func complete() -> void:
	if finished:
		return
	finished = true
	player.input_locked = true
	_before_complete()
	var flow := get_node_or_null("/root/GameFlow")
	if flow:
		flow.complete_level(level_index)


## Level biterken son kontroller (ör. yardım edilmeyenleri kesinleştir)
func _before_complete() -> void:
	pass


func _on_respawned() -> void:
	get_tree().call_group("resettable", "reset")


func _add_pause_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	layer.add_child(PauseMenuScene.instantiate())


## Gökyüzü: level sınırlarını kaplayan dikey renk geçişi
func _make_backdrop() -> void:
	var g := Gradient.new()
	g.colors = PackedColorArray([sky_top, sky_bottom])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 256
	var bg := TextureRect.new()
	bg.texture = tex
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.position = Vector2(bounds.position * TILE)
	bg.size = Vector2(bounds.size * TILE)
	bg.z_index = -50
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)
