extends Control
## OptionsMenu — Tekrar kullanılabilir ayar paneli.
##
## Hem ana menüden hem pause menüden açılabilir. Kod ile kurulur (sahne
## dosyası gerekmez). CenterContainer kullanarak ekranın tam ortasına yerleşir.
## SettingsManager üzerinden değerleri okur/yazar; değişiklikler anında uygulanır
## ve diske kaydedilir.

# ── Sinyaller ─────────────────────────────────────────────────────────
## Kullanıcı "Back" düğmesine bastığında tetiklenir.
signal back_pressed

const SettingsManagerScript := preload("res://scripts/managers/settings_manager.gd")

# ── Referanslar ──────────────────────────────────────────────────────
var _settings_node: Node = null

var _master_slider: HSlider
var _music_slider: HSlider
var _sfx_slider: HSlider
var _fullscreen_check: CheckBox
var _vsync_check: CheckBox
var _res_scale_slider: HSlider
var _res_scale_label: Label
var _screenshake_check: CheckBox


func _ready() -> void:
	# Pause menüde bile çalışsın
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Tüm ekranı kapla
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

	_build_ui()
	_sync_from_settings()
	_master_slider.grab_focus.call_deferred()  # kol/klavye ile gezinme

	# Ayarlar dışarıdan değişirse senkronize ol
	var sm := _get_settings()
	if sm != null and sm.has_signal("settings_changed"):
		sm.settings_changed.connect(_sync_from_settings)


## SettingsManager düğümüne güvenli erişim (autoload yoksa bile çökmez).
func _get_settings() -> Node:
	if _settings_node != null and is_instance_valid(_settings_node):
		return _settings_node
	if has_node("/root/SettingsManager"):
		_settings_node = get_node("/root/SettingsManager")
		return _settings_node
	# Autoload henüz yüklenmemişse yedek örnek oluştur
	_settings_node = SettingsManagerScript.new()
	add_child(_settings_node)
	return _settings_node


# ── UI Oluşturucu ────────────────────────────────────────────────────

func _build_ui() -> void:
	# Yarı-saydam arka plan (arka planı karartır ve tıklamaları yutar)
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	overlay.color = Color(0.0, 0.0, 0.0, 0.75)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# CenterContainer — İçindeki paneli her zaman ekranın tam ortasında tutar
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

	# Ana panel kutusu
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.15, 0.98)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 32.0
	style.content_margin_right = 32.0
	style.content_margin_top = 24.0
	style.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# ── Başlık ──
	_section_title(vbox, "Settings")

	# ── Ses ──
	_section_header(vbox, "Audio")
	_master_slider = _add_slider(vbox, "Master Volume", 0, 100)
	_master_slider.value_changed.connect(func(v: float) -> void:
		_get_settings().set_setting("audio_master", v))
	_music_slider = _add_slider(vbox, "Music", 0, 100)
	_music_slider.value_changed.connect(func(v: float) -> void:
		_get_settings().set_setting("audio_music", v))
	_sfx_slider = _add_slider(vbox, "Sound Effects", 0, 100)
	_sfx_slider.value_changed.connect(func(v: float) -> void:
		_get_settings().set_setting("audio_sfx", v))

	# ── Görüntü ──
	_section_header(vbox, "Display")
	_fullscreen_check = _add_check(vbox, "Fullscreen")
	_fullscreen_check.toggled.connect(func(on: bool) -> void:
		_get_settings().set_setting("fullscreen", on))
	_vsync_check = _add_check(vbox, "V-Sync")
	_vsync_check.toggled.connect(func(on: bool) -> void:
		_get_settings().set_setting("vsync", on))

	var res_row := _make_row(vbox, "Resolution Scale")
	_res_scale_slider = HSlider.new()
	_res_scale_slider.min_value = 0.5
	_res_scale_slider.max_value = 2.0
	_res_scale_slider.step = 0.1
	_res_scale_slider.custom_minimum_size.x = 180
	res_row.add_child(_res_scale_slider)
	_res_scale_label = Label.new()
	_res_scale_label.text = "1.0"
	_res_scale_label.custom_minimum_size.x = 36
	res_row.add_child(_res_scale_label)
	_res_scale_slider.value_changed.connect(func(v: float) -> void:
		_res_scale_label.text = "%.1f" % v
		_get_settings().set_setting("resolution_scale", v))

	# ── Oynanış ──
	_section_header(vbox, "Gameplay")
	_screenshake_check = _add_check(vbox, "Screen Shake")
	_screenshake_check.toggled.connect(func(on: bool) -> void:
		_get_settings().set_setting("screenshake", on))

	# ── Alt Düğmeler ──
	vbox.add_child(_spacer(14))
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 24)
	vbox.add_child(btns)

	var reset_btn := Button.new()
	reset_btn.text = "Reset to Defaults"
	reset_btn.custom_minimum_size = Vector2(160, 38)
	reset_btn.pressed.connect(func() -> void:
		_get_settings().reset_to_defaults()
		_sync_from_settings())
	btns.add_child(reset_btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(110, 38)
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	btns.add_child(back_btn)


# ── Ayarları UI'a Yansıt ─────────────────────────────────────────────

func _sync_from_settings() -> void:
	var sm := _get_settings()
	if sm == null:
		return
	_master_slider.set_value_no_signal(sm.get_setting("audio_master"))
	_music_slider.set_value_no_signal(sm.get_setting("audio_music"))
	_sfx_slider.set_value_no_signal(sm.get_setting("audio_sfx"))
	_fullscreen_check.set_pressed_no_signal(sm.get_setting("fullscreen"))
	_vsync_check.set_pressed_no_signal(sm.get_setting("vsync"))
	var scale_val: float = sm.get_setting("resolution_scale")
	_res_scale_slider.set_value_no_signal(scale_val)
	_res_scale_label.text = "%.1f" % scale_val
	_screenshake_check.set_pressed_no_signal(sm.get_setting("screenshake"))


# ── UI Yardımcıları ──────────────────────────────────────────────────

func _section_title(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 28)
	parent.add_child(l)
	parent.add_child(_spacer(4))


func _section_header(parent: Control, text: String) -> void:
	parent.add_child(_spacer(4))
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	parent.add_child(l)


func _add_slider(parent: Control, label_text: String, min_v: float, max_v: float) -> HSlider:
	var row := _make_row(parent, label_text)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = 1.0
	slider.custom_minimum_size.x = 200
	row.add_child(slider)
	return slider


func _add_check(parent: Control, label_text: String) -> CheckBox:
	var row := _make_row(parent, label_text)
	var cb := CheckBox.new()
	row.add_child(cb)
	return cb


func _make_row(parent: Control, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 180
	row.add_child(lbl)
	parent.add_child(row)
	return row


func _spacer(h: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size.y = h
	return s
