class_name LevelHud
extends CanvasLayer
## Level arayüzü: level başlığı, aktif questler, bildirimler, ışık sayacı, zamanlayıcı, tuş yardımı,
## ve ortada büyük mesaj (ör. Gate'e varınca). Diyalog açıkken quest listesi gizlenir (çakışmasın).

const HELP_KEYS := "A/D move · Space jump (hold: glide) · Shift dash · S: slide / pound · " \
		+ "S+Space: drop · F talk/use · Esc pause"
const HELP_PAD := "Left stick move · A jump (hold: glide) · X/RT dash · Down: slide / pound · " \
		+ "Down+A: drop · Y talk/use · Start pause"

var quests: QuestLog

var _title: Label
var _subtitle: Label
var _tracker: Label
var _light: Label
var _toast: Label
var _timer: Label
var _help: Label
var _center: Label
var _toasts: Array[String] = []
var _toast_busy := false
var _pad := false


func _ready() -> void:
	layer = 4
	_title = _label(Vector2(0, 150), 40)
	_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_center_h(_title, 900)
	_subtitle = _label(Vector2(0, 200), 20)
	_subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_center_h(_subtitle, 900)
	_subtitle.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))

	_light = _label(Vector2(0, 10), 20)
	_light.anchor_left = 1.0
	_light.anchor_right = 1.0
	_light.offset_left = -200.0
	_light.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))

	_tracker = _label(Vector2(0, 40), 15)
	_tracker.anchor_left = 1.0
	_tracker.anchor_right = 1.0
	_tracker.offset_left = -330.0
	_tracker.offset_right = -14.0
	_tracker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_toast = _label(Vector2(0, 60), 20)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_center_h(_toast, 800)
	_toast.add_theme_color_override("font_color", Color(0.7, 1.0, 0.75))
	_toast.hide()

	_timer = _label(Vector2(0, 94), 30)
	_timer.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_center_h(_timer, 300)
	_timer.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	_timer.hide()

	_help = _label(Vector2(16, 0), 15)
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.offset_top = -30.0
	_help.text = HELP_KEYS

	_center = _label(Vector2.ZERO, 34)
	_center.anchor_left = 0.5
	_center.anchor_right = 0.5
	_center.anchor_top = 0.5
	_center.anchor_bottom = 0.5
	_center.offset_left = -520.0
	_center.offset_right = 520.0
	_center.offset_top = -120.0
	_center.offset_bottom = 120.0
	_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_center.hide()


func bind(q: QuestLog) -> void:
	quests = q
	quests.changed.connect(_refresh_tracker)
	quests.notify.connect(toast)
	_refresh_tracker()


func _label(pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _center_h(l: Label, width: float) -> void:
	l.offset_left = -width / 2.0
	l.offset_right = width / 2.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _process(_delta: float) -> void:
	# Diyalog/QTE açıkken quest listesi ve bildirim diyalog kutusuyla çakışmasın
	var busy := DialogueBox.ui_busy(get_tree())
	_tracker.visible = not busy and _tracker.text != ""
	if busy:
		_toast.hide()


func _input(event: InputEvent) -> void:
	# Yardım yazısı en son kullanılan cihaza göre (klavye / kol)
	var pad := _pad
	if event is InputEventKey:
		pad = false
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		pad = true
	if pad != _pad:
		_pad = pad
		_help.text = HELP_PAD if pad else HELP_KEYS


## Level başlığını birkaç saniye göster
func show_title(title: String, subtitle := "") -> void:
	_title.text = title
	_subtitle.text = subtitle
	for l in [_title, _subtitle]:
		l.modulate.a = 0.0
		l.show()
	var tw := create_tween()
	tw.tween_property(_title, "modulate:a", 1.0, 0.6)
	tw.parallel().tween_property(_subtitle, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.4)
	tw.tween_property(_title, "modulate:a", 0.0, 0.8)
	tw.parallel().tween_property(_subtitle, "modulate:a", 0.0, 0.8)


func set_light(got: float, total: float) -> void:
	_light.text = "Light: %d/%d" % [got, total] if total > 0.0 else ""


func set_timer(seconds: float) -> void:
	_timer.visible = seconds > 0.0
	_timer.text = "%.1f" % seconds


## Ortada büyük mesaj (boş metin gizler)
func show_center(text: String) -> void:
	_center.text = text
	_center.visible = text != ""


## Kısa bildirim; art arda gelenler sıraya girer
func toast(text: String) -> void:
	_toasts.append(text)
	if not _toast_busy:
		_next_toast()


func _next_toast() -> void:
	if _toasts.is_empty():
		_toast_busy = false
		return
	_toast_busy = true
	_toast.text = _toasts.pop_front()
	_toast.modulate.a = 1.0
	_toast.visible = not DialogueBox.ui_busy(get_tree())
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_next_toast)


func _refresh_tracker() -> void:
	if quests == null:
		return
	var lines := []
	for q: Dictionary in quests.active_list():
		var prog := ""
		if q["total"] > 0:
			prog = "  (%d/%d)" % [q["count"], q["total"]]
		lines.append("> %s%s\n   %s" % [q["title"], prog, q["objective"]])
	_tracker.text = "\n".join(lines)
