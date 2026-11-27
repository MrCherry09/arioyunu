extends Area2D
## Etkileşimli nesne: yanındayken F (kolda Y) ile kullanılır, auto açıksa dokununca tetiklenir.
## Hikâye taşı okumak, çan çalmak, fener yakmak gibi işler için. Ne olacağına level betiği karar verir
## (used sinyali). Görünüm PixelArt.look(look) ile bulunur. Orijin ayak hizasında.

signal used(node: Node)

@export var look := "stone"
@export var verb := "Use"         ## Yanında beliren yazı: "F / Y: <verb>"
@export var one_shot := true      ## Bir kez kullanılınca kapanır
@export var auto := false         ## Dokununca kendiliğinden tetiklen (yavru kuş, eşya gibi)
@export var glow := false         ## Hafifçe parlasın (dikkat çeksin)
@export var bob := false          ## Yukarı aşağı süzülsün

var done := false
var _sprite: Sprite2D
var _prompt: Label
var _t := 0.0


func _ready() -> void:
	collision_layer = 0
	add_to_group("interactables")
	_t = randf() * 3.0
	_sprite = Sprite2D.new()
	add_child(_sprite)
	set_look(look)
	var h := 48.0
	if _sprite.texture:
		h = _sprite.texture.get_height() * PixelArt.PIXEL
	_prompt = Label.new()
	_prompt.text = "F / Y: " + verb
	_prompt.add_theme_font_size_override("font_size", 15)
	_prompt.add_theme_constant_override("outline_size", 5)
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_prompt.position = Vector2(-44, -h - 28)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.hide()
	add_child(_prompt)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(maxf(72.0, h), h + 40)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -h / 2.0)
	add_child(col)
	if auto:
		body_entered.connect(func(b: Node2D) -> void:
			if b is Player and not done:
				_use())


## Görünümü değiştir (ör. sönük fener -> yanan fener)
func set_look(id: String) -> void:
	look = id
	var lk := PixelArt.look(id)
	if lk.is_empty() or _sprite == null:
		return
	var s := PixelArt.sprite(lk[0], lk[1])
	_sprite.texture = s.texture
	_sprite.texture_filter = s.texture_filter
	_sprite.scale = s.scale
	_sprite.offset = s.offset
	s.free()


func _process(delta: float) -> void:
	_t += delta
	if bob:
		_sprite.position.y = -PixelArt.PIXEL * 2 if fmod(_t, 1.0) < 0.5 else 0.0
	if glow and not done:
		var k := 1.15 + 0.15 * sin(_t * 4.0)
		_sprite.self_modulate = Color(k, k, k)
	if auto or done and one_shot:
		_prompt.hide()
		return
	var near := false
	for b in get_overlapping_bodies():
		if b is Player:
			near = true
	var busy := DialogueBox.ui_busy(get_tree())
	var p := get_tree().get_first_node_in_group("player") as Player
	if p and p.input_locked:
		busy = true
	_prompt.visible = near and not busy and visible
	if near and not busy and visible and Input.is_action_just_pressed("interact"):
		_use()


func _use() -> void:
	if one_shot:
		done = true
		_sprite.self_modulate = Color.WHITE
	used.emit(self)


func reset_state() -> void:
	done = false
