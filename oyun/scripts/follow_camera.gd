extends Camera2D
## Platformer için yumuşak takip kamerası. Uygulanan teknikler:
## - Physics interpolation (project.godot'ta açık): kamera ve oyuncu fizik adımında hareket
##   eder, motor ara kareleri doldurur. Yüksek Hz monitörlerde titremeyi yok eder.
## - Kare hızından bağımsız üstel yumuşatma (1 - exp(-hız * delta)).
## - Lookahead: kamera, gidilen yöne doğru biraz ileriye bakar.
## - Platform snapping: zıplarken kamera dikeyde sabit kalır, yalnızca oyuncu
##   yere basınca ya da bir sınırı aşınca dikeyde hareket eder.
## - Hızlı düşüşte dikey yakalama hızlanır, oyuncu ekrandan kaçmaz.
## - Yatay ölü bölge: küçük kıpırdamalarda kamera oynamaz.

@export_group("Takip")
@export var follow_speed_x := 7.0
@export var follow_speed_y := 4.0
@export var fall_follow_speed_y := 10.0   ## Hızlı düşerken kullanılacak dikey hız
@export var fall_speed_threshold := 450.0
@export var dead_zone_x := 12.0
@export var vertical_offset := -60.0      ## Negatif: kamera oyuncunun biraz üstüne bakar

@export_group("Lookahead")
@export var lookahead_distance := 90.0
@export var lookahead_speed := 2.5
@export var lookahead_min_velocity := 40.0

@export_group("Dikey sabitleme")
@export var air_margin_up := 140.0        ## Havada bu kadar yükselirse kamera da çıkar
@export var air_margin_down := 60.0       ## Havada zemin seviyesinin bu kadar altına inerse takip eder

@export_group("Diğer")
@export var snap_distance := 600.0        ## Bundan büyük sıçramalarda (respawn) anında ışınlan

var _target: CharacterBody2D
var _lookahead := 0.0
var _facing := 1.0
var _anchor_y := 0.0
var _focus := Vector2.ZERO
var _last_pos := Vector2.ZERO


func _ready() -> void:
	_target = get_parent() as CharacterBody2D
	top_level = true
	# 2D physics interpolation açıkken kamera fizik adımında hareket etmeli;
	# ara karelerdeki yumuşak konumu motor kendisi hesaplar.
	position_smoothing_enabled = false
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	snap_to_target()


func snap_to_target() -> void:
	var p := _target_pos()
	_anchor_y = p.y
	_lookahead = 0.0
	_focus = p
	_last_pos = p
	global_position = Vector2(p.x, p.y + vertical_offset)
	reset_smoothing()
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if _target == null:
		return
	var p := _target_pos()

	if p.distance_to(_last_pos) > snap_distance:
		snap_to_target()
		return
	_last_pos = p

	# Yatay ölü bölge
	if absf(p.x - _focus.x) > dead_zone_x:
		_focus.x = p.x - signf(p.x - _focus.x) * dead_zone_x

	# Lookahead: son hareket yönüne doğru yumuşakça kay
	var vx := _target.velocity.x
	if absf(vx) > lookahead_min_velocity:
		_facing = signf(vx)
	_lookahead = lerpf(_lookahead, _facing * lookahead_distance, _damp(lookahead_speed, delta))

	# Dikey: yerdeyken zemine kilitlen, havadayken sadece sınır aşılırsa takip et
	if _target.is_on_floor():
		_anchor_y = p.y
	elif p.y < _anchor_y - air_margin_up:
		_anchor_y = p.y + air_margin_up
	elif p.y > _anchor_y + air_margin_down:
		_anchor_y = p.y - air_margin_down

	var speed_y := follow_speed_y
	if _target.velocity.y > fall_speed_threshold:
		speed_y = fall_follow_speed_y

	var goal := Vector2(_focus.x + _lookahead, _anchor_y + vertical_offset)
	global_position = Vector2(
		lerpf(global_position.x, goal.x, _damp(follow_speed_x, delta)),
		lerpf(global_position.y, goal.y, _damp(speed_y, delta)),
	)


func _target_pos() -> Vector2:
	return _target.global_position


static func _damp(speed: float, delta: float) -> float:
	return 1.0 - exp(-speed * delta)
