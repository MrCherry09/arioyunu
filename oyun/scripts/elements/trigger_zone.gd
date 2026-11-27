extends Area2D
## Görünmez bölge: oyuncu (veya kuzu gibi bir hayvan) girince entered sinyali verir.
## Teslim noktaları, level çıkışı, Gate gibi yerler için. Orijin sol üst köşede.

signal entered(body: Node2D)

@export var size := Vector2(96, 96)
@export var label_text := ""   ## Doluysa bölgenin üstünde yazar (ör. "Pen")
@export var debug_color := Color(0, 0, 0, 0)  ## Görünür olsun istersen renk ver


func _ready() -> void:
	collision_layer = 0
	monitoring = true
	var shape := RectangleShape2D.new()
	shape.size = size
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = size / 2.0
	add_child(col)
	if debug_color.a > 0.0:
		var r := ColorRect.new()
		r.size = size
		r.color = debug_color
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
	if label_text != "":
		var l := Label.new()
		l.text = label_text
		l.add_theme_font_size_override("font_size", 16)
		l.add_theme_constant_override("outline_size", 5)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		l.position = Vector2(4, -26)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
	body_entered.connect(func(b: Node2D) -> void: entered.emit(b))


## Şu an içinde olan gövdeler arasında koşulu sağlayan var mı
func contains(pred: Callable) -> bool:
	for b in get_overlapping_bodies():
		if pred.call(b):
			return true
	return false
