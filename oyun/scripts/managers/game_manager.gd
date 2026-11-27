extends Node
## GameManager — Oyunun genel durumunu yöneten global tekil (autoload).
##
## Şu an oyunun kaydetme ihtiyacı yok, ama altyapı hazır bırakıldı:
##   • save_game()  → user://savegame.json  dosyasına yazar
##   • load_game()  → dosyadan okur ve sinyalle bildirir
##   • delete_save()
##   • has_save()
##
## İleride seviye ilerlemesi, envanter, istatistik vb. eklemek için
## `game_data` sözlüğünü genişletmek yeterli.

# ── Sinyaller ─────────────────────────────────────────────────────────
## Oyun verileri diskten yüklendiğinde tetiklenir.
signal game_loaded(data: Dictionary)
## Oyun verileri diske yazıldığında tetiklenir.
signal game_saved
## Sahne değiştiğinde tetiklenir (geçiş efektleri için kullanılabilir).
signal scene_changing(scene_path: String)

# ── Sabitler ──────────────────────────────────────────────────────────
const SAVE_PATH := "user://savegame.json"

# ── Durum ─────────────────────────────────────────────────────────────
## Oyunun kayıt verileri. İleride büyütülecek.
var game_data: Dictionary = {
	"version": 1,                     # Kayıt formatı sürümü
	"last_room": 0,                   # Son bulunulan oda
	"feathers_collected": 0,          # Toplanan melek tüyü
	"total_play_time_sec": 0.0,       # Toplam oynama süresi
	"checkpoints_reached": [],        # Ulaşılan kontrol noktaları
}

## Oyun başlangıcından bu yana geçen süre (kaydetme için birikir).
var _session_start := 0.0


func _ready() -> void:
	# Sahne ağacı her zaman çalışsın (pause menüde bile autoload'lar durmaz)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_session_start = Time.get_ticks_msec() / 1000.0


# ── Kaydetme / Yükleme ───────────────────────────────────────────────

## Mevcut `game_data`'yı diske yazar.
func save_game() -> void:
	# Oturum süresini ekle
	var now := Time.get_ticks_msec() / 1000.0
	game_data["total_play_time_sec"] += now - _session_start
	_session_start = now

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("GameManager: Kayıt dosyası açılamadı – %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(game_data, "\t"))
	file.close()
	game_saved.emit()
	print("GameManager: Oyun kaydedildi → ", SAVE_PATH)


## Diskten okuyup `game_data`'yı günceller. Başarılıysa `true` döner.
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		push_warning("GameManager: Kayıt dosyası bulunamadı.")
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("GameManager: Kayıt okunamadı – %s" % error_string(FileAccess.get_open_error()))
		return false

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("GameManager: JSON ayrıştırma hatası – %s" % json.get_error_message())
		return false

	game_data = json.data as Dictionary
	_session_start = Time.get_ticks_msec() / 1000.0
	game_loaded.emit(game_data)
	print("GameManager: Oyun yüklendi ← ", SAVE_PATH)
	return true


## Kayıt dosyası var mı?
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Kayıt dosyasını siler.
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("GameManager: Kayıt silindi.")


# ── Sahne Geçişi ─────────────────────────────────────────────────────

## Verilen sahneye geçer. İleride fade-in/out efekti eklenebilir.
func change_scene(scene_path: String) -> void:
	scene_changing.emit(scene_path)
	# Pause kaldır (menüden oyuna geçerken)
	get_tree().paused = false
	get_tree().change_scene_to_file(scene_path)


## Ana menüye döner.
func go_to_main_menu() -> void:
	change_scene("res://scenes/ui/main_menu.tscn")


## Oyuna başlar: Level 1 (Orman), yükleme ekranı üzerinden (bkz. GameFlow).
## Test odalarına normal akıştan girilmez; gizli debug tuşu: Ctrl+Shift+T.
func start_game() -> void:
	var flow := get_node_or_null("/root/GameFlow")
	if flow:
		get_tree().paused = false
		flow.start_new_game()
	else:
		change_scene("res://scenes/levels/level_1_forest.tscn")
