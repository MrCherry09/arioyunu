class_name Voice
## Undertale tarzı konuşma sesi, ama ünlü harflere göre: her ünlü (a, e, i, o, u) kendi tınısıyla
## çalar, böylece karakter anlamsız ama "konuşuyormuş gibi" duyulur. Ses dosyası yok; her ses
## formant sentezi ile koddan üretilir: temel perdenin harmonikleri, o ünlünün formant
## frekanslarına (insan sesindeki rezonanslara) göre güçlendirilir.
##
## Her konuşanın kendi sesi var (VOICES): perde, süre, titreme (vibrato), nefes, cıvıltı.
## Yeni bir karakter eklemek için VOICES'a bir satır eklemen yeterli.

const RATE := 22050

## Ünlü formantları (Hz): F1, F2, F3. Açık "a"dan kapalı "i/u"ya.
const FORMANTS := {
	"a": [750.0, 1200.0, 2500.0],
	"e": [500.0, 1900.0, 2600.0],
	"i": [300.0, 2300.0, 3000.0],
	"o": [500.0, 850.0, 2400.0],
	"u": [330.0, 800.0, 2300.0],
}

## f0: temel perde (Hz), dur: bip süresi (sn), vib: [hız Hz, derinlik], breath: nefes gürültüsü,
## sweep: bip boyunca perde değişimi (+ yukarı kayar), vol: ses düzeyi (dB)
const VOICES := {
	"ANGEL":      {"f0": 300.0, "dur": 0.075, "vib": [0.0, 0.0],   "breath": 0.0,  "sweep": -0.04, "vol": -9.0},
	"GRANNY":     {"f0": 230.0, "dur": 0.085, "vib": [6.0, 0.045], "breath": 0.05, "sweep": -0.03, "vol": -9.0},
	"MONK":       {"f0": 110.0, "dur": 0.095, "vib": [0.0, 0.0],   "breath": 0.0,  "sweep": -0.03, "vol": -7.0},
	"BIRD":       {"f0": 640.0, "dur": 0.05,  "vib": [0.0, 0.0],   "breath": 0.0,  "sweep": 0.25,  "vol": -12.0},
	"CHILD":      {"f0": 410.0, "dur": 0.06,  "vib": [0.0, 0.0],   "breath": 0.0,  "sweep": 0.03,  "vol": -10.0},
	"CLIMBER":    {"f0": 150.0, "dur": 0.075, "vib": [13.0, 0.04], "breath": 0.08, "sweep": -0.02, "vol": -8.0},
	"SPIRIT":     {"f0": 260.0, "dur": 0.11,  "vib": [3.0, 0.02],  "breath": 0.35, "sweep": 0.0,   "vol": -12.0},
	"FARMER":     {"f0": 275.0, "dur": 0.07,  "vib": [0.0, 0.0],   "breath": 0.0,  "sweep": 0.02,  "vol": -9.0},
	"SHEPHERD":   {"f0": 135.0, "dur": 0.085, "vib": [4.0, 0.02],  "breath": 0.04, "sweep": -0.03, "vol": -8.0},
	"MILLER":     {"f0": 118.0, "dur": 0.09,  "vib": [0.0, 0.0],   "breath": 0.0,  "sweep": -0.02, "vol": -8.0},
	"MINER":      {"f0": 160.0, "dur": 0.075, "vib": [0.0, 0.0],   "breath": 0.05, "sweep": -0.04, "vol": -8.0},
	"STONE":      {"f0": 95.0,  "dur": 0.12,  "vib": [2.0, 0.03],  "breath": 0.3,  "sweep": 0.0,   "vol": -14.0},
	"GATEKEEPER": {"f0": 80.0,  "dur": 0.11,  "vib": [0.0, 0.0],   "breath": 0.03, "sweep": -0.05, "vol": -6.0},
}
const DEFAULT_VOICE := {"f0": 200.0, "dur": 0.07, "vib": [0.0, 0.0], "breath": 0.0, "sweep": 0.0, "vol": -9.0}

static var _cache := {}


## Harfin ünlü karşılığı ("" = ünsüz, ses yok). Türkçe ünlüler de en yakın ünlüye eşlenir.
static func vowel_of(ch: String) -> String:
	if ch == "İ":  # to_lower() bunu "i" + birleşik nokta yapar, eşleşmez
		return "i"
	match ch.to_lower():
		"a":
			return "a"
		"e":
			return "e"
		"i", "y", "ı":
			return "i"
		"o", "ö":
			return "o"
		"u", "ü":
			return "u"
	return ""


static func volume_db(speaker: String) -> float:
	return VOICES.get(speaker, DEFAULT_VOICE)["vol"]


## Tanımsız ünlüde null döner (çağıran sessiz geçer)
static func stream(speaker: String, vowel: String) -> AudioStreamWAV:
	if not FORMANTS.has(vowel):
		return null
	var key := speaker + ":" + vowel
	if not _cache.has(key):
		_cache[key] = _synth(VOICES.get(speaker, DEFAULT_VOICE), FORMANTS[vowel])
	return _cache[key]


## Bir konuşanın 5 ünlüsünü önceden hazırla (ilk satırda takılma olmasın)
static func warm_up(speaker: String) -> void:
	for v in FORMANTS:
		stream(speaker, v)


static func _synth(voice: Dictionary, formants: Array) -> AudioStreamWAV:
	var f0: float = voice["f0"]
	var dur: float = voice["dur"]
	var vib_rate: float = voice["vib"][0]
	var vib_depth: float = voice["vib"][1]
	var breath: float = voice["breath"]
	var sweep: float = voice["sweep"]
	var n := int(dur * RATE)

	# Harmonik genlikleri: her harmonik, formantlara yakınlığına göre güçlenir
	var harmonics: Array[float] = []
	var k := 1
	while k * f0 < 4200.0:
		var hf := k * f0
		var a := 0.0
		var gains := [1.0, 0.55, 0.2]
		var widths := [90.0, 120.0, 160.0]
		for fi in 3:
			var dfreq: float = hf - formants[fi]
			a += gains[fi] * exp(-(dfreq * dfreq) / (2.0 * widths[fi] * widths[fi]))
		a += 0.08 / k  # formant dışında da hafif gövde sesi
		harmonics.append(a)
		k += 1

	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	var peak := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f0 * 1000.0) + formants[0] as int  # her seferinde aynı ses
	var noise_lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var prog := float(i) / n
		var f := f0 * (1.0 + sweep * prog) * (1.0 + vib_depth * sin(TAU * vib_rate * t))
		phase += TAU * f / RATE
		var s := 0.0
		for h in harmonics.size():
			s += harmonics[h] * sin((h + 1) * phase)
		if breath > 0.0:
			noise_lp = lerpf(noise_lp, rng.randf_range(-1.0, 1.0), 0.35)  # yumuşatılmış gürültü
			s = s * (1.0 - breath) + noise_lp * breath * 2.5
		# Zarf: 5 ms yükseliş, sonra yumuşak sönüm (tık sesi olmasın)
		var env := minf(t / 0.005, 1.0) * pow(1.0 - prog, 1.6)
		s *= env
		samples[i] = s
		peak = maxf(peak, absf(s))

	var data := PackedByteArray()
	data.resize(n * 2)
	var norm := 0.85 / maxf(peak, 0.0001)
	for i in n:
		data.encode_s16(i * 2, int(clampf(samples[i] * norm, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
