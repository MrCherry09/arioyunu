class_name DialogueBox
extends CanvasLayer
## Ekranın üst kısmındaki diyalog kutusu (karakterlerin üstünü kapatmasın diye üstte).
## Satırları daktilo efektiyle yazar. Etkileşim (F / kolda Y) veya zıplama: yazıyı tamamla / devam.
## Konuşma sürerken oyuncu hareket edemez.
##
## Kullanım:
##   box.play([["GRANNY", "Hello"], ["ANGEL", "..."]], bitince_cagrilacak)
##   box.ask("CHILD", "Help me!", ["Help", "Walk away"], func(i): ...)   # sol/sağ ile seç, onayla

signal finished

const CHARS_PER_SEC := 45.0

## Konuşanın adına göre isim rengi
const SPEAKER_COLORS := {
	"ANGEL": Color(1.0, 0.85, 0.4),
	"GRANNY": Color(0.78, 0.62, 0.95),
	"MONK": Color(0.95, 0.65, 0.35),
	"BIRD": Color(0.5, 0.75, 1.0),
	"CHILD": Color(0.95, 0.5, 0.45),
	"CLIMBER": Color(1.0, 0.6, 0.3),
	"SPIRIT": Color(0.75, 0.9, 1.0),
	"GATEKEEPER": Color(1.0, 0.95, 0.75),
}

const OPT_ON := Color(1.0, 0.9, 0.5)
const OPT_OFF := Color(0.6, 0.6, 0.68)

var player: Player
var active := false

var _lines: Array = []
var _index := 0
var _shown := 0.0
var _on_done: Callable
var _choices: Array = []      ## Boş değilse son satır bir soru: seçenekler
var _on_choice: Callable
var _sel := 0
var _panel: Panel
var _name: Label
var _text: Label
var _opts: HBoxContainer
var _next: ColorRect
var _blink := 0.0

# Konuşma sesi (bkz. Voice): yazı çıkarken her ünlü harfte konuşanın sesiyle bip
const BEEP_GAP := 0.045       ## İki bip arası en az süre (sn)
var _voices: Array[AudioStreamPlayer] = []
var _voice_i := 0
var _beep_cd := 0.0
var _typed := 0               ## Sesi çalınmış son karakter
var _speaker := ""
var _opened_frame := -1      ## Diyaloğun açıldığı kare: o karedeki tuş basışı yok sayılır
var beep_count := 0           ## Toplam çalınan bip (test ve hata ayıklama için)
var last_beep := ""           ## Son bip: "KONUŞAN:ünlü"


func _ready() -> void:
	layer = 5
	GameInput.setup()  # tuşlar oyuncusuz sahnelerde de tanımlı olsun (zaten varsa dokunmaz)
	add_to_group("dialogue_box")
	add_to_group("ui_blockers")
	_panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.11, 0.98)
	sb.border_color = Color(0.95, 0.85, 0.55)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(0)  # piksel köşe
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.anchor_left = 0.12
	_panel.anchor_right = 0.88
	_panel.offset_top = 108.0   # HUD başlığının hemen altı
	_panel.offset_bottom = 250.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	_name = Label.new()
	_name.position = Vector2(18, 8)
	_name.add_theme_font_size_override("font_size", 22)
	_panel.add_child(_name)

	_text = Label.new()
	_text.position = Vector2(18, 40)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 20)
	_text.anchor_right = 1.0
	_text.offset_right = -40.0
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_panel.add_child(_text)

	# Seçenekler: alt satırda yan yana; seçili olan "> " ile ve sarı
	_opts = HBoxContainer.new()
	_opts.anchor_top = 1.0
	_opts.anchor_bottom = 1.0
	_opts.offset_left = 18.0
	_opts.offset_top = -40.0
	_opts.offset_bottom = -10.0
	_opts.add_theme_constant_override("separation", 48)
	_panel.add_child(_opts)

	# "Devam" işareti: sağ altta yanıp sönen küçük kare
	_next = ColorRect.new()
	_next.anchor_left = 1.0
	_next.anchor_top = 1.0
	_next.anchor_right = 1.0
	_next.anchor_bottom = 1.0
	_next.offset_left = -26.0
	_next.offset_right = -17.0
	_next.offset_top = -24.0
	_next.offset_bottom = -15.0
	_next.color = Color(0.95, 0.85, 0.55)
	_panel.add_child(_next)
	_panel.hide()

	# Küçük bir oynatıcı havuzu: bipler kısa olduğu için üst üste binebilir
	var bus := "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	for i in 4:
		var ap := AudioStreamPlayer.new()
		ap.bus = bus
		add_child(ap)
		_voices.append(ap)


## Sahneden çıkarken çalan bipleri durdur: aksi hâlde oyun kapanırken
## ses sunucusunda yarım kalan çalma "sızıntı" uyarısı verir
func _exit_tree() -> void:
	for ap in _voices:
		ap.stop()
		ap.stream = null


func play(lines: Array, on_done := Callable()) -> void:
	if lines.is_empty():
		if on_done.is_valid():
			on_done.call()
		return
	_start(lines, [], Callable(), on_done)


## Diyalog ağacını çalıştırır. Ağaç: { "düğüm_id": düğüm }. Düğüm alanları:
##   "lines":   [["SPEAKER", "text"], ...]        (isteğe bağlı) önce söylenenler
##   "ask":     ["SPEAKER", "question"]            (isteğe bağlı) soru; varsa "options" gerekir
##   "options": [{"text": "...", "next": "id", "action": "..."}, ...]
##   "next":    "id"                               (soru yoksa) sonra gidilecek düğüm
##   "action":  "..."                              (soru yoksa) bitince tetiklenecek eylem
## Eylemler on_action(action) ile bildirilir (ör. "accept", "skip"); hikâye mantığını çağıran yapar.
func run(tree: Dictionary, node_id := "start", on_action := Callable()) -> void:
	if not tree.has(node_id):
		return
	var node: Dictionary = tree[node_id]
	var lines: Array = node.get("lines", [])
	if node.has("ask"):
		var opts: Array = node["options"]
		var texts := []
		for o: Dictionary in opts:
			texts.append(o["text"])
		ask(node["ask"][0], node["ask"][1], texts, _on_tree_choice.bind(tree, opts, on_action), lines)
	else:
		play(lines, _on_tree_lines_done.bind(tree, node, on_action))


func _on_tree_choice(i: int, tree: Dictionary, opts: Array, on_action: Callable) -> void:
	var o: Dictionary = opts[i]
	if o.has("action") and on_action.is_valid():
		on_action.call(o["action"])
	if o.get("next", "") != "":
		run(tree, o["next"], on_action)


func _on_tree_lines_done(tree: Dictionary, node: Dictionary, on_action: Callable) -> void:
	if node.has("action") and on_action.is_valid():
		on_action.call(node["action"])
	if node.get("next", "") != "":
		run(tree, node["next"], on_action)


## Önce lead_lines (varsa), sonra soru satırı ve seçenekler. Seçim yapılınca on_choice(index).
func ask(speaker: String, question: String, options: Array, on_choice: Callable,
		lead_lines := []) -> void:
	var lines := lead_lines.duplicate()
	lines.append([speaker, question])
	_start(lines, options, on_choice, Callable())


func _start(lines: Array, choices: Array, on_choice: Callable, on_done: Callable) -> void:
	_lines = lines
	_index = 0
	_choices = choices
	_on_choice = on_choice
	_on_done = on_done
	_sel = 0
	# Konuşmayı açan tuş (NPC'ye F/Y) aynı karede bu kutuya da "tamamla" olarak
	# görünür; yok sayılmazsa yazı direkt gelir ve ses hiç çalmaz
	_opened_frame = Engine.get_process_frames()
	active = true
	if player:
		player.input_locked = true
	_panel.show()
	_show_line()


func _show_line() -> void:
	var speaker: String = _lines[_index][0]
	_name.text = speaker
	_name.add_theme_color_override("font_color", SPEAKER_COLORS.get(speaker, Color.WHITE))
	_text.text = _lines[_index][1]
	_shown = 0.0
	_typed = 0
	_text.visible_characters = 0
	_opts.hide()
	if speaker != _speaker:
		_speaker = speaker
		Voice.warm_up(speaker)


func _asking() -> bool:
	return not _choices.is_empty() and _index == _lines.size() - 1


func _build_options() -> void:
	# Eski seçenekleri hemen kaldır: queue_free kare sonuna kadar bekler ve
	# 3 seçenekten 2 seçeneğe geçince sayım şaşar (index hatası)
	for c in _opts.get_children():
		_opts.remove_child(c)
		c.queue_free()
	for i in _choices.size():
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 20)
		_opts.add_child(l)
	_refresh_options()
	_opts.show()


func _refresh_options() -> void:
	for i in mini(_opts.get_child_count(), _choices.size()):
		var l: Label = _opts.get_child(i)
		var on := i == _sel
		l.text = ("> " if on else "  ") + str(_choices[i])
		l.add_theme_color_override("font_color", OPT_ON if on else OPT_OFF)


func _process(delta: float) -> void:
	if not active:
		return
	var total := _text.get_total_character_count()
	var typing := _shown < total
	_beep_cd -= delta
	if typing:
		_shown += CHARS_PER_SEC * delta
		_text.visible_characters = int(_shown)
		_speak_new_chars(mini(int(_shown), total))
		if _shown >= total and _asking():
			_build_options()
	_blink += delta
	_next.visible = not typing and not _asking() and fmod(_blink, 0.6) < 0.35

	var confirm := (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump")) \
			and Engine.get_process_frames() != _opened_frame
	if typing:
		if confirm:
			_shown = total
			_text.visible_characters = -1
			if _asking():
				_build_options()
		return

	if _asking():
		if Input.is_action_just_pressed("move_left"):
			_sel = (_sel - 1 + _choices.size()) % _choices.size()
			_refresh_options()
		elif Input.is_action_just_pressed("move_right"):
			_sel = (_sel + 1) % _choices.size()
			_refresh_options()
		elif confirm:
			var picked := _sel
			var cb := _on_choice
			_close()
			if cb.is_valid():
				cb.call(picked)
		return

	if confirm:
		_index += 1
		if _index >= _lines.size():
			var cb := _on_done
			_close()
			if cb.is_valid():
				cb.call()
		else:
			_show_line()


## Diyaloğu hemen kapat (ör. oda değişince); geri çağrılar çalışmaz
func stop() -> void:
	if not active:
		return
	active = false
	_panel.hide()
	if player:
		player.input_locked = false


## Yeni görünen karakterlerde ünlü varsa bip çal. Parantez içi (sahne yönergesi) sessiz.
func _speak_new_chars(upto: int) -> void:
	var txt := _text.text
	while _typed < upto and _typed < txt.length():
		var ch := txt[_typed]
		_typed += 1
		if _in_parentheses(txt, _typed - 1):
			continue
		var v := Voice.vowel_of(ch)
		if v != "" and _beep_cd <= 0.0:
			_beep(v)


func _in_parentheses(txt: String, idx: int) -> bool:
	var open := txt.rfind("(", idx)
	return open != -1 and txt.find(")", open) >= idx


func _beep(vowel: String) -> void:
	var st := Voice.stream(_speaker, vowel)
	if st == null or _voices.is_empty():
		return
	var ap := _voices[_voice_i]
	_voice_i = (_voice_i + 1) % _voices.size()
	ap.stream = st
	ap.volume_db = Voice.volume_db(_speaker)
	ap.pitch_scale = randf_range(0.96, 1.04)  # her bip birebir aynı olmasın
	ap.play()
	_beep_cd = BEEP_GAP
	beep_count += 1
	last_beep = _speaker + ":" + vowel


func _close() -> void:
	active = false
	_panel.hide()
	finished.emit()
	# Kapatan tuş basışı oyuncuya zıplama/etkileşim olarak geçmesin.
	# Geri çağrı hemen yeni bir diyalog açarsa (active tekrar true) kilit açılmaz.
	await get_tree().create_timer(0.15).timeout
	if player and not ui_busy(get_tree()):
		player.input_locked = false


## Diyalog veya QTE gibi oyuncuyu kilitleyen bir arayüz açık mı?
static func ui_busy(tree: SceneTree) -> bool:
	for n in tree.get_nodes_in_group("ui_blockers"):
		if n.active:
			return true
	return false
