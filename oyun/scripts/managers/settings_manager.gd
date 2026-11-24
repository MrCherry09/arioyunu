extends Node
## SettingsManager — Oyun ayarlarını yönetir ve diske kaydeder (autoload).
##
## Ayarlar anında uygulanır ve user://settings.cfg dosyasına yazılır,
## böylece bir sonraki açılışta otomatik geri yüklenir.
##
## Desteklenen ayarlar:
##   • Ses: master, müzik, efekt kanalları (0 – 100 arası)
##   • Görüntü: tam ekran, V-Sync, çözünürlük ölçeği
##   • Oynanış: ekran sallama (screenshake)

# ── Sinyaller ─────────────────────────────────────────────────────────
## Herhangi bir ayar değiştiğinde tetiklenir (UI yenileme için).
signal settings_changed

# ── Sabitler ──────────────────────────────────────────────────────────
const SETTINGS_PATH := "user://settings.cfg"

## Bus isimleri – Godot'ta varsayılan "Master" bus'ı her zaman vardır;
## "Music" ve "SFX" bus'larını AudioServer'da oluşturman gerekir
## (ya da aşağıdaki kod eksik bus'ı sessizce atlar).
const BUS_MASTER := "Master"
const BUS_MUSIC  := "Music"
const BUS_SFX    := "SFX"

# ── Varsayılan Değerler ──────────────────────────────────────────────
## Her ayarın varsayılanı. Yeni ayar eklemek için buraya bir satır yeter.
const DEFAULTS: Dictionary = {
	# --- Ses (0–100) ---
	"audio_master":   80,
	"audio_music":    70,
	"audio_sfx":      90,
	# --- Görüntü ---
	"fullscreen":     false,
	"vsync":          true,
	"resolution_scale": 1.0,   # 0.5 – 2.0 arası
	# --- Oynanış ---
	"screenshake":    true,
}

# ── Durum ─────────────────────────────────────────────────────────────
## Şu an aktif olan ayarlar sözlüğü.
var _settings: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_settings = DEFAULTS.duplicate(true)
	load_settings()
	_apply_all()


# ── Dışa Açık API ────────────────────────────────────────────────────

## Bir ayarın güncel değerini döndürür.
func get_setting(key: String) -> Variant:
	return _settings.get(key, DEFAULTS.get(key))


## Bir ayarı değiştirir, uygular ve diske yazar.
func set_setting(key: String, value: Variant) -> void:
	_settings[key] = value
	_apply_setting(key, value)
	save_settings()
	settings_changed.emit()


## Tüm ayarları varsayılana sıfırlar.
func reset_to_defaults() -> void:
	_settings = DEFAULTS.duplicate(true)
	_apply_all()
	save_settings()
	settings_changed.emit()


# ── Kaydet / Yükle ───────────────────────────────────────────────────

## Ayarları diske yazar.
func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key: String in _settings:
		cfg.set_value("settings", key, _settings[key])
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("SettingsManager: Ayarlar kaydedilemedi – %s" % error_string(err))


## Ayarları diskten okur (dosya yoksa varsayılanlar kalır).
func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return   # Dosya yok → varsayılanlarla devam
	for key: String in DEFAULTS:
		if cfg.has_section_key("settings", key):
			_settings[key] = cfg.get_value("settings", key)


# ── Uygulama Yardımcıları ────────────────────────────────────────────

## Tüm ayarları motora / ses sistemine uygular.
func _apply_all() -> void:
	for key: String in _settings:
		_apply_setting(key, _settings[key])


## Tek bir ayarı motora uygular.
func _apply_setting(key: String, value: Variant) -> void:
	match key:
		# ---- Ses ----
		"audio_master":
			_set_bus_volume(BUS_MASTER, value as float)
		"audio_music":
			_set_bus_volume(BUS_MUSIC, value as float)
		"audio_sfx":
			_set_bus_volume(BUS_SFX, value as float)
		# ---- Görüntü ----
		"fullscreen":
			if value:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		"vsync":
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED
			)
		"resolution_scale":
			# 3D çözünürlük ölçeği; 2D canvas_items stretch'te etkisiz ama ileride işe yarar
			get_viewport().scaling_3d_scale = clampf(value as float, 0.5, 2.0)


## Ses bus'ının hacmini ayarlar (0–100 arası değer alır).
func _set_bus_volume(bus_name: String, percent: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return   # Bus tanımlı değilse sessizce geç
	# 0 → sessiz (mute), 1-100 → dB'ye çevir
	if percent <= 0.0:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(percent / 100.0))
