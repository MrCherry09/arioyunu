extends SceneTree
## Konuşma sesi motoru (Voice + DialogueBox) testleri.
## Çalıştırma (oyun/ klasöründen):
##   godot --headless --path . -s res://tests/voice_test.gd
## Hepsi geçerse çıkış kodu 0, biri bile kalırsa 1.

var _pass := 0
var _fail := 0
var _fails: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(name: String, cond: bool, info: Variant = "") -> void:
	if cond:
		_pass += 1
		print("  OK    ", name)
	else:
		_fail += 1
		_fails.append(name)
		print("  FAIL  ", name, "   -> ", info)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	print("== Voice: harf -> ünlü")
	_test_vowel_of()
	print("== Voice: ses üretimi ve kalite")
	_test_streams()
	print("== Voice: perde, ünlü ayrımı, determinizm, önbellek, hız")
	_test_pitch_and_vowels()
	_test_determinism_cache_perf()
	print("== DialogueBox: oyun içi davranış")
	await _test_dialogue()
	print("\nSONUÇ: %d geçti, %d kaldı" % [_pass, _fail])
	for f in _fails:
		print("  kalan: ", f)
	quit(0 if _fail == 0 else 1)


# =====================================================================
# Voice
# =====================================================================

func _test_vowel_of() -> void:
	var cases := {
		"a": "a", "A": "a", "e": "e", "E": "e", "i": "i", "I": "i", "o": "o", "O": "o",
		"u": "u", "U": "u", "y": "i", "Y": "i", "ı": "i", "İ": "i", "ö": "o", "Ö": "o",
		"ü": "u", "Ü": "u", "b": "", "Z": "", "ş": "", "ç": "", "ğ": "", "1": "", " ": "",
		".": "", "!": "", "(": "", "": "", "ab": "", "🙂": "", "\n": "",
	}
	var wrong := []
	for ch: String in cases:
		if Voice.vowel_of(ch) != cases[ch]:
			wrong.append("%s->%s" % [ch, Voice.vowel_of(ch)])
	check("vowel_of: %d harf doğru eşleniyor" % cases.size(), wrong.is_empty(), wrong)
	check("geçersiz ünlü 'x' -> null (çökmez)", Voice.stream("ANGEL", "x") == null)
	check("boş ünlü '' -> null (çökmez)", Voice.stream("ANGEL", "") == null)


func _samples(w: AudioStreamWAV) -> PackedFloat32Array:
	var n := w.data.size() / 2
	var x := PackedFloat32Array()
	x.resize(n)
	for j in n:
		x[j] = w.data.decode_s16(j * 2) / 32768.0
	return x


func _test_streams() -> void:
	var speakers: Array = Voice.VOICES.keys() + ["UNKNOWN_SPEAKER"]
	var bad := {"null": [], "format": [], "length": [], "silent": [], "peak": [], "click_start": [],
			"click_end": [], "dc": []}
	for sp: String in speakers:
		var voice: Dictionary = Voice.VOICES.get(sp, Voice.DEFAULT_VOICE)
		for v: String in Voice.FORMANTS:
			var tag := "%s:%s" % [sp, v]
			var w := Voice.stream(sp, v)
			if w == null:
				bad["null"].append(tag)
				continue
			if w.format != AudioStreamWAV.FORMAT_16_BITS or w.mix_rate != Voice.RATE or w.stereo:
				bad["format"].append(tag)
			var expect := int(voice["dur"] * Voice.RATE) * 2
			if w.data.size() != expect:
				bad["length"].append("%s %d!=%d" % [tag, w.data.size(), expect])
			var x := _samples(w)
			var peak := 0.0
			var sum := 0.0
			var sq := 0.0
			for s in x:
				peak = maxf(peak, absf(s))
				sum += s
				sq += s * s
			var rms := sqrt(sq / x.size())
			if rms < 0.05:
				bad["silent"].append("%s rms=%.3f" % [tag, rms])
			if peak < 0.8 or peak > 0.87:
				bad["peak"].append("%s peak=%.3f" % [tag, peak])
			if absf(x[0]) > 0.05:
				bad["click_start"].append("%s %.3f" % [tag, x[0]])
			# Son 2 ms neredeyse sessiz olmalı (kesik bitişte "tık" sesi olur)
			var tail := int(0.002 * Voice.RATE)
			var tsq := 0.0
			for j in range(x.size() - tail, x.size()):
				tsq += x[j] * x[j]
			if sqrt(tsq / tail) > 0.03:
				bad["click_end"].append("%s %.3f" % [tag, sqrt(tsq / tail)])
			if absf(sum / x.size()) > 0.03:
				bad["dc"].append("%s %.3f" % [tag, sum / x.size()])
	var total := speakers.size() * Voice.FORMANTS.size()
	check("%d sesin hepsi üretildi" % total, bad["null"].is_empty(), bad["null"])
	check("biçim: 16 bit, %d Hz, mono" % Voice.RATE, bad["format"].is_empty(), bad["format"])
	check("uzunluk = süre x örnek hızı", bad["length"].is_empty(), bad["length"])
	check("hiçbiri sessiz değil", bad["silent"].is_empty(), bad["silent"])
	check("tepe seviyesi 0.80-0.87 (kırpılma yok)", bad["peak"].is_empty(), bad["peak"])
	check("başlangıçta tık yok", bad["click_start"].is_empty(), bad["click_start"])
	check("bitişte tık yok", bad["click_end"].is_empty(), bad["click_end"])
	check("DC kayması yok", bad["dc"].is_empty(), bad["dc"])
	check("bilinmeyen konuşan varsayılan sesle konuşur", Voice.stream("NOBODY", "a") != null \
			and Voice.volume_db("NOBODY") == Voice.DEFAULT_VOICE["vol"])


## Otokorelasyonla temel perde tahmini (Hz)
func _pitch(x: PackedFloat32Array, lo: float, hi: float) -> float:
	var a := int(x.size() * 0.2)
	var b := int(x.size() * 0.7)
	var best := 0.0
	var best_lag := 0
	for lag in range(int(Voice.RATE / hi), int(Voice.RATE / lo) + 1):
		var c := 0.0
		for j in range(a, b - lag):
			c += x[j] * x[j + lag]
		if c > best:
			best = c
			best_lag = lag
	return Voice.RATE / float(best_lag) if best_lag > 0 else 0.0


## Ünlünün spektral ağırlık merkezi (Hz)
func _centroid(x: PackedFloat32Array) -> float:
	var num := 0.0
	var den := 0.0
	var f := 100.0
	while f < 4000.0:
		var re := 0.0
		var im := 0.0
		for j in range(0, x.size(), 2):
			var ph := TAU * f * j / Voice.RATE
			re += x[j] * cos(ph)
			im += x[j] * sin(ph)
		var mag := sqrt(re * re + im * im)
		num += f * mag
		den += mag
		f += 50.0
	return num / den


func _test_pitch_and_vowels() -> void:
	var off_pitch := []
	var order := []
	var spread := []
	for sp: String in Voice.VOICES:
		var voice: Dictionary = Voice.VOICES[sp]
		var expect: float = voice["f0"] * (1.0 + voice["sweep"] * 0.45)
		var got := _pitch(_samples(Voice.stream(sp, "a")), expect * 0.5, expect * 1.6)
		var tol := 0.15 if voice["breath"] > 0.2 else 0.1
		if absf(got - expect) / expect > tol:
			off_pitch.append("%s beklenen~%d ölçülen=%d" % [sp, int(expect), int(got)])
		var c := {}
		for v in Voice.FORMANTS:
			c[v] = _centroid(_samples(Voice.stream(sp, v)))
		# Kalın ünlüler (o, u) ince ünlülerden (e) koyu olmalı
		if not (c["u"] < c["e"] and c["o"] < c["e"]):
			order.append("%s %s" % [sp, c])
		var vals: Array = c.values()
		if vals.max() - vals.min() < 150.0:
			spread.append("%s fark=%d" % [sp, int(vals.max() - vals.min())])
	check("her karakter kendi perdesinde konuşuyor (±10%)", off_pitch.is_empty(), off_pitch)
	check("o/u koyu, e parlak (ünlü tınıları doğru)", order.is_empty(), order)
	check("ünlüler birbirinden belirgin farklı (>150 Hz)", spread.is_empty(), spread)
	# Karakterler birbirinden ayırt edilebilmeli: perdeler sıralı ve farklı
	var pitches := []
	for sp: String in Voice.VOICES:
		pitches.append(Voice.VOICES[sp]["f0"])
	var unique := {}
	for p in pitches:
		unique[p] = true
	check("8 karakterin perdesi birbirinden farklı", unique.size() == pitches.size(), pitches)


func _test_determinism_cache_perf() -> void:
	var a := Voice.stream("SPIRIT", "o")
	check("önbellek aynı nesneyi döndürür", Voice.stream("SPIRIT", "o") == a)
	var before := a.data
	Voice._cache.clear()
	var b := Voice.stream("SPIRIT", "o")
	check("yeniden üretim birebir aynı (nefesli ses dahil)", b.data == before)
	Voice._cache.clear()
	var t0 := Time.get_ticks_msec()
	for sp: String in Voice.VOICES:
		Voice.warm_up(sp)
	var ms := Time.get_ticks_msec() - t0
	check("tüm sesleri üretmek < 400 ms (ölçülen %d ms)" % ms, ms < 400, ms)
	check("warm_up 5 ünlüyü hazırlar", Voice._cache.size() == Voice.VOICES.size() * 5, Voice._cache.size())


# =====================================================================
# DialogueBox
# =====================================================================

func _new_box() -> DialogueBox:
	var d := DialogueBox.new()
	root.add_child(d)
	return d


## Satırı yazdır, yazı bitene kadar bekle; çalan bip sayısını döndür
func _type(d: DialogueBox, speaker: String, text: String) -> int:
	var start := d.beep_count
	d.play([[speaker, text]])
	for i in 600:
		await process_frame
		if d._shown >= d._text.get_total_character_count():
			break
	return d.beep_count - start


func _test_dialogue() -> void:
	var d := _new_box()
	await frames(2)
	check("4 oynatıcılık havuz kuruldu, SFX kanalında",
			d._voices.size() == 4 and d._voices[0].bus == "SFX", [d._voices.size(), d._voices[0].bus])

	# Konuşmayı açan tuş (F) aynı karede yazıyı atlatmamalı: NPC'ye F'ye basınca
	# diyalog aynı karede açılıyor; kutu bu basışı "tamamla" sanırsa yazı direkt gelir, ses çalmaz
	Input.action_press("interact")
	d.play([["GRANNY", "Well, well... who's that with you, dear?"]])
	await frames(1)
	Input.action_release("interact")
	await frames(4)
	check("açan tuş yazıyı atlatmıyor (daktilo sürüyor)",
			d._shown < d._text.get_total_character_count(), [d._shown, d._text.get_total_character_count()])
	await frames(30)
	check("açan tuştan sonra ses çalıyor", d.beep_count > 0, d.beep_count)
	d.stop()
	# Aynı durum zıplama tuşuyla (kolda A) açılırsa
	var jb := d.beep_count
	Input.action_press("jump")
	d.play([["MONK", "But some don't fall. They are pushed."]])
	await frames(1)
	Input.action_release("jump")
	await frames(30)
	check("zıplama tuşuyla açılınca da atlamıyor", d.beep_count > jb and d._shown < d._text.get_total_character_count() + 1, d.beep_count - jb)
	d.stop()

	var n := await _type(d, "ANGEL", "Hmm. Shh! 123 -- ...")
	check("ünsüz/rakam/noktalama: hiç bip yok", n == 0, n)
	d.stop()

	n = await _type(d, "ANGEL", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")  # 30 harf ~0.67 sn
	var max_beeps := int(ceil(30.0 / DialogueBox.CHARS_PER_SEC / DialogueBox.BEEP_GAP)) + 1
	check("ünlülerde bip var ama %d ms aralık korunuyor (%d bip, en fazla %d)" \
			% [int(DialogueBox.BEEP_GAP * 1000), n, max_beeps], n > 5 and n <= max_beeps, n)
	d.stop()

	n = await _type(d, "ANGEL", "(whispering aeiou)")
	check("parantez içi sahne yönergesi sessiz", n == 0, n)
	d.stop()
	n = await _type(d, "MONK", "(aaa) bo")
	check("parantezden sonraki ünlü konuşulur (tam 1 bip)", n == 1 and d.last_beep == "MONK:o", [n, d.last_beep])
	d.stop()
	n = await _type(d, "MONK", "unclosed ( paren aeiou")
	check("kapanmamış parantez çökertmez", n > 0, n)
	d.stop()

	# Hızlı geçiş: yazı tamamlanınca bip durur
	d.play([["BIRD", "a".repeat(300)]])
	await frames(5)
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	var after := d.beep_count
	await frames(30)
	check("yazı tuşla tamamlanınca bip kesiliyor", d.beep_count == after, [after, d.beep_count])
	d.stop()

	# Takılma (lag) karesi: tek karede çok harf açılsa da tek bip
	d.play([["CHILD", "a".repeat(200)]])
	await frames(1)
	var c0 := d.beep_count
	d._process(2.0)
	check("2 sn'lik takılma karesinde en fazla 1 bip", d.beep_count - c0 <= 1, d.beep_count - c0)
	check("yazı imleci metni aşmıyor", d._typed <= d._text.text.length(), [d._typed, d._text.text.length()])
	d.stop()

	# Konuşan değişince ses değişir
	d.play([["MONK", "aaa"], ["BIRD", "ooo"]])
	await frames(40)
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(40)
	var last_ap: AudioStreamPlayer = d._voices[(d._voice_i - 1 + d._voices.size()) % d._voices.size()]
	check("konuşan değişince onun sesi çalar", d.last_beep == "BIRD:o" \
			and last_ap.stream == Voice.stream("BIRD", "o"), d.last_beep)
	check("ses düzeyi konuşana göre", is_equal_approx(last_ap.volume_db, Voice.volume_db("BIRD")), last_ap.volume_db)
	check("perde %±4 içinde rastgele", last_ap.pitch_scale >= 0.96 and last_ap.pitch_scale <= 1.04, last_ap.pitch_scale)
	d.stop()

	n = await _type(d, "GRANNY", "Şüphesiz İzmir'den ığdıra, öğle ÜZÜM 🙂 ok")
	check("Türkçe karakter ve emoji: çökmez, konuşur", n > 0, n)
	d.stop()
	n = await _type(d, "ANGEL", "")
	check("boş satır çökertmez", n == 0)
	d.stop()
	n = await _type(d, "SOMEONE_NEW", "hello there")
	check("tanımsız konuşan varsayılan sesle konuşur", n > 0 and d.last_beep.begins_with("SOMEONE_NEW"), d.last_beep)
	d.stop()

	# stop() yazarken: bip durur
	d.play([["ANGEL", "a".repeat(300)]])
	await frames(10)
	d.stop()
	var s0 := d.beep_count
	await frames(30)
	check("stop() sonrası bip yok", d.beep_count == s0)

	# Soru satırı da konuşur
	var s1 := d.beep_count
	d.ask("CLIMBER", "Could you spare a moment?", ["Yes", "No"], func(_i: int) -> void: pass)
	await frames(90)
	check("soru (seçenekli) satırı da konuşur", d.beep_count > s1, d.beep_count - s1)
	d.stop()

	# Havuz dönüşümü
	var i0 := d._voice_i
	var b0 := d.beep_count
	await _type(d, "ANGEL", "a e i o u a e i o u")
	check("oynatıcı havuzu sırayla dönüyor", d._voice_i == (i0 + d.beep_count - b0) % 4, [i0, d._voice_i])
	d.stop()

	# Oyun duraklatılınca bip yok
	d.play([["ANGEL", "a".repeat(300)]])
	await frames(3)
	paused = true
	var p0 := d.beep_count
	await frames(30)
	check("oyun duraklatılınca (pause) bip yok", d.beep_count == p0, d.beep_count - p0)
	paused = false
	await frames(30)
	check("devam edince bip sürüyor", d.beep_count > p0)
	d.stop()

	# Uzun kullanım: oynatıcı sayısı sabit, düğüm sızıntısı yok
	var nodes0 := d.get_child_count()
	for k in 200:
		d.play([["ANGEL", "quick line %d aeiou" % k]])
		d._process(0.05)
		d.stop()
	await frames(5)
	check("200 aç/kapa sonrası düğüm sayısı sabit", d.get_child_count() == nodes0, [nodes0, d.get_child_count()])
	d.queue_free()
	await frames(2)

	# SFX kanalı yoksa Master'a düşer
	var sfx := AudioServer.get_bus_index("SFX")
	AudioServer.remove_bus(sfx)
	var d2 := _new_box()
	await frames(2)
	check("SFX kanalı yoksa Master'a düşer", d2._voices[0].bus == "Master", d2._voices[0].bus)
	n = await _type(d2, "ANGEL", "aeiou")
	check("Master kanalında da çalar", n > 0, n)
	d2.queue_free()
	AudioServer.add_bus(sfx)
	AudioServer.set_bus_name(sfx, "SFX")
	await frames(2)
