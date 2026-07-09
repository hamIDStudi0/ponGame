extends CharacterBody2D
class_name BallScript

signal scored(side: String)       # "left" atau "right" = sisi yang kebobolan
signal hit_paddle(paddle: Node, local_hit_offset: float) # offset -1..1 dari tengah paddle

@export var base_speed: float = 220.0
@export var speed_increase_per_hit: float = 12.0
@export var max_speed: float = 620.0
@export var field_top: float = 16.0
@export var field_bottom: float = 344.0
@export var field_left: float = -20.0
@export var field_right: float = 660.0
@export var bounce_off_side_walls: bool = false # true untuk mode Breaker (tidak ada gol, bola mantul semua sisi)

@export var enable_motion_blur: bool = true

var _speed: float
@onready var _sprite: CanvasItem = get_node_or_null("Sprite")
var _blur_state: MotionBlurUtil.BlurState

func _ready() -> void:
	reset_ball()
	if enable_motion_blur and _sprite != null:
		_blur_state = MotionBlurUtil.apply_to(_sprite)

func reset_ball(direction_sign: float = 1.0) -> void:
	_speed = base_speed
	var angle := randf_range(-0.35, 0.35)
	velocity = Vector2(cos(angle), sin(angle)) * _speed * direction_sign
	position = Vector2(320, 180)

func _physics_process(_delta: float) -> void:
	var collision := move_and_collide(velocity * get_physics_process_delta_time())
	if collision:
		var collider := collision.get_collider()
		if collider is PaddleScript:
			_bounce_off_paddle(collider)
		else:
			velocity = velocity.bounce(collision.get_normal())

	if position.y < field_top or position.y > field_bottom:
		velocity.y = -velocity.y

	if bounce_off_side_walls:
		if position.x < field_left or position.x > field_right:
			velocity.x = -velocity.x
	else:
		if position.x < field_left:
			emit_signal("scored", "left")
		elif position.x > field_right:
			emit_signal("scored", "right")

	MotionBlurUtil.update_from_velocity(_blur_state, velocity, max_speed, QLearning.devil_mode)

func _bounce_off_paddle(paddle: Node2D) -> void:
	var offset := (position.y - paddle.position.y) / 30.0 # -1..1 kira-kira
	offset = clamp(offset, -1.0, 1.0)
	_speed = min(_speed + speed_increase_per_hit, max_speed)
	var dir_x := 1.0 if velocity.x < 0 else -1.0
	var angle := offset * 1.0 # radian, dibatasi supaya gak terlalu ekstrim
	velocity = Vector2(dir_x * cos(angle), sin(angle)) * _speed
	emit_signal("hit_paddle", paddle, offset)
