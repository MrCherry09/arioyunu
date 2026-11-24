extends Area2D
## Konuşulabilen NPC. Yanındayken etkileşim tuşu (F / kolda Y) ile konuşma başlar.
## Konuşma bir diyalog ağacıdır (bkz. DialogueBox.run). Ağaç seçenekli olabilir:
## düz hikâye NPC'lerinde sadece sohbet seçenekleri, yardım NPC'lerinde "help/skip" eylemleri.
## tree_provider ayarlıysa ağaç her konuşmada ondan alınır (duruma göre değişen konuşmalar için).
## Orijin ayak hizasında.

signal action(npc: Node, action_name: String)

@export var npc_id := ""
@export var hop := false      ## Kuş gibi ara sıra zıplasın mı
@export var shiver := false   ## Üşüyen gibi titresin mi

var tree: Dictionary = {}
var tree_provider: Callable   ## func(npc) -> Dictionary
var state := ""               ## Hikâye durumu: "", "accepted", "helped", "skipped"
var template: Array = []
var palette: Dictionary = {}

var sprite: Sprite2D
var _prompt: Label
var _mark: Label
var _t := 0.0
var _talked := false


func _ready() -> void:
	add_to_group("story_npcs")
	collision_layer = 0
	sprite = PixelArt.sprite(template, palette)
	add_child(sprite)

	var h := template.size() * PixelArt.PIXEL
	_prompt = _label("F / Y: Talk", 15, Color.WHITE, Vector2(-40, -h - 30))
	_prompt.hide()
	# Henüz konuşulmadıysa başının üstünde "!" belirir
	_mark = _label("!", 22, Color(1.0, 0.85, 0.4), Vector2(-4, -h - 34))

	# Konuşma alanı ayakların 60px altına da uzanır: direk/çıkıntı üstündeki NPC'lerle yerden konuşulabilsin
	var shape := RectangleShape2D.new()
	shape.size = Vector2(96, h + 80)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -(h + 20) / 2.0 + 30.0)
	add_child(col)


func _label(text: String, size: int, color: Color, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _process(delta: float) -> void:
	_t += delta
	# Piksel adımlı nefes / zıplama / titreme animasyonu
	if hop:
		sprite.position.y = -PixelArt.PIXEL * 3 if fmod(_t, 1.6) < 0.12 else 0.0
	else:
		sprite.position.y = -PixelArt.PIXEL if fmod(_t, 1.2) < 0.6 else 0.0
	sprite.position.x = (PixelArt.PIXEL if int(_t * 14.0) % 2 == 0 else 0.0) if shiver else 0.0

	var box := _box()
	var near := false
	for b in get_overlapping_bodies():
		if b is Player:
			near = true
			sprite.flip_h = b.global_position.x < global_position.x  # oyuncuya dön
	# Diyalog açıkken veya yeni kapandıysa (oyuncu hâlâ kilitli) yeniden başlatma
	var busy := box == null or box.active or (box.player != null and box.player.input_locked)
	_prompt.visible = near and not busy and visible
	_mark.visible = not _talked and not (near and not busy)
	if near and not busy and visible and Input.is_action_just_pressed("interact"):
		_talked = true
		talk(box)


func talk(box: DialogueBox) -> void:
	var t: Dictionary = tree_provider.call(self) if tree_provider.is_valid() else tree
	box.run(t, "start", func(a: String) -> void: action.emit(self, a))


func reset() -> void:
	state = ""
	_talked = false
	show()


func _box() -> DialogueBox:
	var boxes := get_tree().get_nodes_in_group("dialogue_box")
	return boxes[0] if not boxes.is_empty() else null
