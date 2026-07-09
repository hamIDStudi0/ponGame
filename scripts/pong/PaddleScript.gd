extends CharacterBody2D
class_name PaddleScript
## Dipakai oleh semua varian pong. Mendukung keyboard (W/S dan panah, untuk testing
## desktop) DAN touch drag (untuk build Android) -- sentuh & geser di sisi layar
## paddle masing-masing untuk menggerakkannya naik/turun.

@export var player_id: int = 1 # 0 = kiri/dikendalikan AI (QLearning), 1 = kiri/keyboard, 2 = kanan/player
@export var speed: float = 260.0
@export var acceleration: float = 2000.0   # px/s^2 -- capai top speed ±0.13s, cuma buat menghaluskan gerakan
@export var deceleration: float = 2600.0   # berhenti sedikit lebih cepat dari mulai gerak, biar gak berasa "licin"
@export var field_top: float = 20.0
@export var field_bottom: float = 340.0
@export var enable_motion_blur: bool = true

var _touch_index: int = -1
@onready var _sprite: CanvasItem = get_node_or_null("Sprite")
var _blur_state: MotionBlurUtil.BlurState

func _ready() -> void:
	if enable_motion_blur and _sprite != null:
		_blur_state = MotionBlurUtil.apply_to(_sprite)

func _physics_process(delta: float) -> void:
	# player_id == 0 berarti paddle ini dikendalikan sepenuhnya oleh AIPaddleBrain
	# (lihat scripts/ai/AIPaddleBrain.gd) -- jangan proses input keyboard sama sekali,
	# biar tidak bentrok dengan gerakan yang didorong oleh hasil Q-learning.
	if player_id == 0:
		_update_motion_effect(delta)
		MotionBlurUtil.update_from_velocity(_blur_state, velocity, speed, QLearning.devil_mode)
		return

	var dir := 0.0
	if player_id == 1:
		if Input.is_action_pressed("p1_up"):
			dir -= 1.0
		if Input.is_action_pressed("p1_down"):
			dir += 1.0
	else:
		if Input.is_action_pressed("p2_up"):
			dir -= 1.0
		if Input.is_action_pressed("p2_down"):
			dir += 1.0

	var target_speed := dir * speed
	var accel := acceleration if dir != 0.0 else deceleration
	velocity.y = move_toward(velocity.y, target_speed, accel * delta)
	velocity.x = 0
	move_and_slide()
	position.y = clamp(position.y, field_top, field_bottom)

	_update_motion_effect(delta)
	MotionBlurUtil.update_from_velocity(_blur_state, velocity, speed, QLearning.devil_mode)

## Efek visual ringan (squash & stretch) yang mengikuti kecepatan gerak paddle,
## kayak motion effect di game-game pixel -- makin cepat geraknya, makin
## "memanjang" ke arah gerak lalu balik normal saat berhenti.
func _update_motion_effect(delta: float) -> void:
	if _sprite == null:
		return
	var speed_ratio := clamp(abs(velocity.y) / speed, 0.0, 1.0)
	var target_scale := Vector2(1.0 - speed_ratio * 0.18, 1.0 + speed_ratio * 0.28)
	_sprite.scale = _sprite.scale.lerp(target_scale, clamp(delta * 14.0, 0.0, 1.0))

func _unhandled_input(event: InputEvent) -> void:
	# Touch drag: sisi kiri layar menggerakkan paddle kiri, sisi kanan menggerakkan paddle kanan.
	if event is InputEventScreenTouch:
		var on_my_side := (event.position.x < get_viewport_rect().size.x / 2.0) == (player_id == 1)
		if event.pressed and on_my_side and _touch_index == -1:
			_touch_index = event.index
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
	elif event is InputEventScreenDrag and event.index == _touch_index:
		position.y = clamp(position.y + event.relative.y, field_top, field_bottom)

## Dipanggil oleh mode "anime" untuk memicu efek pukulan/trampolin dari luar.
func bounce_flash(color: Color) -> void:
	var tw := create_tween()
	modulate = color
	tw.tween_property(self, "modulate", Color(1, 1, 1), 0.25)
