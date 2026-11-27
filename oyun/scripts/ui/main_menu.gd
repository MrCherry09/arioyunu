extends Control
## MainMenu — Oyunun açılış ekranı.
##
## Oyun başlatıldığında gösterilen ana menü. Düğmeler:
##   • Play       → Level 1 (Orman) başlar
##   • Continue   → (kayıt varsa) kayıttan devam eder
##   • Settings   → OptionsMenu panelini açar
##   • Quit       → uygulamayı kapatır

const OptionsMenu := preload("res://scripts/ui/options_menu.gd")

var _btn_container: VBoxContainer
var _options_panel: Control = null
var _center: CenterContainer
var _settings_btn: Button


func _ready() -> void:
	get_tree().paused = false
	GameInput.setup()  # menüde de kol tuşları tanımlı olsun (A: onay, B: geri)
	_build_ui()
	# Kol/klavye ile gezinebilmek için ilk düğme seçili başlasın
	_btn_container.get_child(0).grab_focus.call_deferred()


# ── UI Oluşturucu ────────────────────────────────────────────────────

func _build_ui() -> void:
	# Tam ekran arka plan
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bg.grow_vertical = Control.GROW_DIRECTION_BOTH
	bg.color = Color(0.08, 0.09, 0.13, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Orta panel
	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.anchor_right = 1.0
	_center.anchor_bottom = 1.0
	_center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_center.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_center.add_child(vbox)

	# ── Başlık ──
	var title := Label.new()
	title.text = "From the Heavens"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	vbox.add_child(title)

	# Boşluk
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 32
	vbox.add_child(spacer)

	# ── Düğmeler ──
	_btn_container = VBoxContainer.new()
	_btn_container.add_theme_constant_override("separation", 10)
	_btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_btn_container)

	_add_button("Play", _on_play)

	# Kayıt varsa "Continue" düğmesi göster
	var has_save := false
	if has_node("/root/GameManager"):
		has_save = get_node("/root/GameManager").has_save()
	elif FileAccess.file_exists("user://savegame.json"):
		has_save = true

	if has_save:
		_add_button("Continue", _on_continue)

	_settings_btn = _add_button("Settings", _on_settings)
	_add_button("Quit", _on_quit)

	# ── Alt bilgi ──
	var version_label := Label.new()
	version_label.text = "v0.1  —  Godot 4.7"
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.add_theme_font_size_override("font_size", 14)
	version_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	version_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	version_label.anchor_top = 1.0
	version_label.anchor_bottom = 1.0
	version_label.offset_top = -32.0
	add_child(version_label)


func _add_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(260, 48)
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(callback)
	_btn_container.add_child(btn)
	return btn


# ── Düğme İşleyicileri ───────────────────────────────────────────────

func _on_play() -> void:
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").start_game()
	else:
		get_tree().change_scene_to_file("res://scenes/levels/level_1_forest.tscn")


func _on_continue() -> void:
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		gm.load_game()
		gm.start_game()
	else:
		get_tree().change_scene_to_file("res://scenes/levels/level_1_forest.tscn")


func _on_settings() -> void:
	if _options_panel != null:
		return
	_center.hide()
	_options_panel = OptionsMenu.new()
	_options_panel.back_pressed.connect(_on_options_back)
	add_child(_options_panel)


func _on_options_back() -> void:
	if _options_panel:
		_options_panel.queue_free()
		_options_panel = null
	_center.show()
	_settings_btn.grab_focus.call_deferred()


func _on_quit() -> void:
	get_tree().quit()
