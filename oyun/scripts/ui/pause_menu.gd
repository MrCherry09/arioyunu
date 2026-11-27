extends Control
## PauseMenu — Oyun içi duraklama menüsü.
##
## Escape tuşuna basıldığında oyunu duraklatır ve şu seçenekleri sunar:
##   • Resume    → menüyü kapat, oyuna dön
##   • Settings  → OptionsMenu panelini aç
##   • Main Menu → ana menüye dön
##   • Quit      → uygulamayı kapat
##
## CenterContainer kullanarak ekranın tam ortasına yerleşir.
## PROCESS_MODE_ALWAYS ile duraklatıldığında bile çalışır.

const OptionsMenu := preload("res://scripts/ui/options_menu.gd")

var _btn_container: VBoxContainer
var _options_panel: Control = null
var _overlay: ColorRect
var _panel: PanelContainer
var _resume_btn: Button
var _settings_btn: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameInput.setup()  # "pause" ve menü tuşları (kolda Start, A, B) tanımlı olsun
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			resume()
		else:
			pause()
		get_viewport().set_input_as_handled()


# ── Aç / Kapat ───────────────────────────────────────────────────────

## Oyunu duraklatıp menüyü gösterir.
func pause() -> void:
	_close_options()
	visible = true
	get_tree().paused = true
	_resume_btn.grab_focus.call_deferred()  # kol/klavye ile gezinme


## Menüyü kapatıp oyuna devam eder.
func resume() -> void:
	_close_options()
	visible = false
	get_tree().paused = false


# ── UI Oluşturucu ────────────────────────────────────────────────────

func _build_ui() -> void:
	# Yarı-saydam koyu arka plan
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.anchor_right = 1.0
	_overlay.anchor_bottom = 1.0
	_overlay.offset_left = 0.0
	_overlay.offset_top = 0.0
	_overlay.offset_right = 0.0
	_overlay.offset_bottom = 0.0
	_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	_overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# CenterContainer — Paneli her zaman ekranın ortasında tutar
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.offset_left = 0.0
	center.offset_top = 0.0
	center.offset_right = 0.0
	center.offset_bottom = 0.0
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# Merkezdeki panel
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(300, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.15, 0.96)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 22.0
	style.content_margin_bottom = 22.0
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	# Başlık
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 12
	vbox.add_child(spacer)

	# Düğmeler
	_btn_container = VBoxContainer.new()
	_btn_container.add_theme_constant_override("separation", 8)
	_btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_btn_container)

	_resume_btn = _add_button("Resume", resume)
	_settings_btn = _add_button("Settings", _on_settings)
	_add_button("Main Menu", _on_main_menu)
	_add_button("Quit", _on_quit)


func _add_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(240, 44)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(callback)
	_btn_container.add_child(btn)
	return btn


# ── Düğme İşleyicileri ───────────────────────────────────────────────

func _on_settings() -> void:
	if _options_panel != null:
		return
	_panel.hide()
	_options_panel = OptionsMenu.new()
	_options_panel.back_pressed.connect(_on_options_back)
	add_child(_options_panel)


func _on_options_back() -> void:
	_close_options()
	_settings_btn.grab_focus.call_deferred()


func _close_options() -> void:
	if _options_panel:
		_options_panel.queue_free()
		_options_panel = null
	if _panel:
		_panel.show()


func _on_main_menu() -> void:
	resume()   # Unpause first
	# GameManager autoload üzerinden veya doğrudan sahne değiştir
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").go_to_main_menu()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_quit() -> void:
	get_tree().quit()
