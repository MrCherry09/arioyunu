extends Node
## GameFlow (autoload): oyunun genel akışı.
##   Yeni oyun  -> yükleme ekranı -> Level 1 (Orman)
##   Level biter -> geçiş cutscene'i -> yükleme ekranı -> sonraki level
## Hikâye seçimleri (kime yardım edildi) leveller arasında burada taşınır. Kayıt sistemi henüz yok:
## bu bilgiler sadece oyun açıkken tutulur.
##
## Gizli debug tuşları (normal oyuncu akışında görünmez, her yerde çalışır):
##   Ctrl + Shift + T       test odaları
##   Ctrl + Shift + 1/2/3   doğrudan o level
##   Ctrl + Shift + N       bulunduğun level'ı bitir (geçişi dene)

const LEVELS := [
	"res://scenes/levels/level_1_forest.tscn",
	"res://scenes/levels/level_2_mountain.tscn",
	"res://scenes/levels/level_3_clouds.tscn",
]
const LEVEL_NAMES := ["Part 1 - The Forest", "Part 2 - The Mountain", "Part 3 - Above the Clouds"]
## Level n bitince oynayacak cutscene
const TRANSITIONS := {1: "forest_to_mountain", 2: "mountain_to_clouds"}

const LOADING_SCENE := "res://scenes/ui/loading_screen.tscn"
const CUTSCENE_SCENE := "res://scenes/cutscenes/cutscene.tscn"
const TEST_ROOMS := "res://scenes/test_rooms.tscn"
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"

## Oturum boyunca hikâye durumu: {"child": "helped"/"skipped"/..., "climber": ..., "spirit": ...}
var story := {}
var current_level := 0

## Yükleme ekranı ve cutscene bu değerleri okur
var pending_scene := ""
var pending_caption := ""
var pending_cutscene := ""
var _after_cutscene_level := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func start_new_game() -> void:
	story = {}
	goto_level(1)


func goto_level(n: int) -> void:
	current_level = clampi(n, 1, LEVELS.size())
	load_scene(LEVELS[current_level - 1], LEVEL_NAMES[current_level - 1])


## Level n tamamlandı: varsa geçiş cutscene'i, sonra sonraki level
func complete_level(n: int) -> void:
	if not TRANSITIONS.has(n):
		return  # son level: Gate'ten sonrası henüz yok (level kendisi gösterir)
	play_cutscene(TRANSITIONS[n], n + 1)


func play_cutscene(id: String, then_level: int) -> void:
	pending_cutscene = id
	_after_cutscene_level = then_level
	get_tree().paused = false
	get_tree().change_scene_to_file(CUTSCENE_SCENE)


## Cutscene bitince (ya da atlanınca) çağrılır
func cutscene_finished() -> void:
	pending_cutscene = ""
	if _after_cutscene_level > 0:
		goto_level(_after_cutscene_level)
	else:
		load_scene(MAIN_MENU)


## Sahneyi yükleme ekranı üzerinden aç (arka planda yüklenir)
func load_scene(path: String, caption := "") -> void:
	pending_scene = path
	pending_caption = caption
	get_tree().paused = false
	get_tree().change_scene_to_file(LOADING_SCENE)


func go_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)


# --- Gizli debug erişimi ---

func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or not (k.ctrl_pressed and k.shift_pressed):
		return
	match k.physical_keycode:
		KEY_T:
			load_scene(TEST_ROOMS, "Test rooms")
		KEY_1:
			goto_level(1)
		KEY_2:
			goto_level(2)
		KEY_3:
			goto_level(3)
		KEY_N:
			var lv := get_tree().get_first_node_in_group("level")
			if lv:
				lv.complete()
		_:
			return
	get_viewport().set_input_as_handled()
