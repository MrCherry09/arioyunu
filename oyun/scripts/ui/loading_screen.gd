extends Control
## Yükleme ekranı: GameFlow.pending_scene'i arka planda yükler (load_threaded_request), ilerlemeyi
## gösterir ve yükleme bitince sahneye geçer. Çok hızlı yüklemelerde ekran göz kırpar gibi
## görünmesin diye en az MIN_TIME saniye kalır.

const MIN_TIME := 0.8

var _path := ""
var _elapsed := 0.0
var _bar: ColorRect
var _bar_bg: ColorRect
var _caption: Label
var _dots: Label
var _angel: Sprite2D
var _failed := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var flow := get_node_or_null("/root/GameFlow")
	_path = flow.pending_scene if flow else ""
	var caption: String = flow.pending_caption if flow else ""

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_caption = _label(caption, 30, Vector2(0, -60))
	_dots = _label("Loading", 18, Vector2(0, 40))

	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.2, 0.2, 0.28)
	_bar_bg.anchor_left = 0.5
	_bar_bg.anchor_right = 0.5
	_bar_bg.anchor_top = 0.5
	_bar_bg.anchor_bottom = 0.5
	_bar_bg.offset_left = -200
	_bar_bg.offset_right = 200
	_bar_bg.offset_top = 10
	_bar_bg.offset_bottom = 22
	add_child(_bar_bg)
	_bar = ColorRect.new()
	_bar.color = Color(1.0, 0.85, 0.5)
	_bar.position = Vector2.ZERO
	_bar.size = Vector2(0, 12)
	_bar_bg.add_child(_bar)

	# Köşede süzülen küçük melek
	var lk := PixelArt.look("angel")
	_angel = PixelArt.sprite(lk[0], lk[1])
	add_child(_angel)

	if _path == "" or not ResourceLoader.exists(_path):
		_fail("Scene not found: " + _path)
		return
	ResourceLoader.load_threaded_request(_path)


func _label(text: String, size: int, offset: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.anchor_top = 0.5
	l.anchor_bottom = 0.5
	l.offset_left = -400 + offset.x
	l.offset_right = 400 + offset.x
	l.offset_top = offset.y - 20
	l.offset_bottom = offset.y + 20
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(l)
	return l


func _process(delta: float) -> void:
	_elapsed += delta
	_dots.text = "Loading" + ".".repeat(int(_elapsed * 3.0) % 4)
	var vp := get_viewport_rect().size
	_angel.position = Vector2(vp.x - 90, vp.y - 70 + sin(_elapsed * 3.0) * 6.0)
	if _failed or _path == "":
		return
	var progress := []
	var status := ResourceLoader.load_threaded_get_status(_path, progress)
	var p: float = progress[0] if not progress.is_empty() else 0.0
	# Çubuk hem yüklemeyi hem en kısa süreyi gösterir (ikisi de bitince dolar)
	var shown := minf(p, _elapsed / MIN_TIME)
	_bar.size.x = 400.0 * clampf(shown, 0.0, 1.0)
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			if _elapsed >= MIN_TIME:
				var scene: PackedScene = ResourceLoader.load_threaded_get(_path)
				set_process(false)
				get_tree().change_scene_to_packed(scene)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_fail("Could not load: " + _path)


func _fail(msg: String) -> void:
	_failed = true
	push_error(msg)
	_caption.text = msg
	_dots.text = "Returning to the main menu..."
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
