extends Node
class_name AIPaddleBrain
## Menjembatani dunia game (posisi bola & paddle) dengan otak QLearning.
## Pasang sebagai child dari paddle (CharacterBody2D, biasanya PaddleScript
## dengan player_id = 0), lalu panggil notify_hit() / notify_goal() dari
## PongBase saat event terjadi supaya reward/punishment beneran dihitung.

@export var paddle_side: int = -1   # -1 kalau paddle ini di kiri layar, 1 kalau di kanan
@export var move_speed: float = 250.0
@export var devil_speed_multiplier: float = 1.35 # AI jadi lebih cepat & tajam pas mode iblis
@export var dead_zone_px: float = 6.0

var paddle: CharacterBody2D
var field_top: float = 20.0
var field_bottom: float = 340.0

var _last_state: String = ""
var _last_action: int = QLearning.ACTION_STAY
var _pending_reward: float = 0.0
var _has_last_state: bool = false

func setup(p_paddle: CharacterBody2D, p_field_top: float, p_field_bottom: float) -> void:
	paddle = p_paddle
	field_top = p_field_top
	field_bottom = p_field_bottom

func _physics_process(delta: float) -> void:
	if paddle == null:
		return
	var ball: CharacterBody2D = _find_relevant_ball()
	if ball == null:
		return

	var state := _encode_state(ball)

	# --- Reward shaping tiap tick: hukuman kecil kalau posisi paddle jauh dari ---
	# --- garis lintasan bola SAAT bola sedang mendekat (bukan pas menjauh). ---
	var approaching := _is_approaching(ball)
	var step_reward := 0.0
	if approaching:
		var dy := ball.position.y - paddle.position.y
		step_reward = -clamp(abs(dy) / 300.0, 0.0, 1.0) * 0.05
	step_reward += _pending_reward
	_pending_reward = 0.0

	if _has_last_state:
		QLearning.learn(_last_state, _last_action, step_reward, state)

	var action := QLearning.choose_action(state)
	_last_state = state
	_last_action = action
	_has_last_state = true

	_apply_action(action, delta)

func _apply_action(action: int, delta: float) -> void:
	var dir := 0.0
	if action == QLearning.ACTION_UP:
		dir = -1.0
	elif action == QLearning.ACTION_DOWN:
		dir = 1.0

	var speed := move_speed * (devil_speed_multiplier if QLearning.devil_mode else 1.0)
	paddle.velocity.y = dir * speed
	paddle.velocity.x = 0
	paddle.move_and_slide()
	paddle.position.y = clamp(paddle.position.y, field_top, field_bottom)

## Dipanggil dari luar (PongBase hook) saat paddle AI berhasil memantulkan bola.
func notify_hit() -> void:
	_pending_reward += 3.0 # hadiah

## Dipanggil dari luar saat terjadi gol. won = true kalau AI yg mencetak.
func notify_goal(won: bool) -> void:
	_pending_reward += (5.0 if won else -5.0) # hadiah besar / hukuman
	QLearning.end_episode(won)
	_has_last_state = false # rally baru = state lama tidak relevan lagi

func _find_relevant_ball() -> CharacterBody2D:
	var balls := paddle.get_tree().get_nodes_in_group("balls")
	if balls.is_empty():
		return null
	# Pilih bola yang paling dekat & mendekati sisi paddle ini.
	var best: CharacterBody2D = null
	var best_dist := INF
	for b in balls:
		var body := b as CharacterBody2D
		if body == null:
			continue
		var d: float = abs(body.position.x - paddle.position.x)
		if d < best_dist:
			best_dist = d
			best = body
	return best

func _is_approaching(ball: CharacterBody2D) -> bool:
	var vx: float = ball.velocity.x
	return (paddle_side < 0 and vx < 0) or (paddle_side > 0 and vx > 0)

## Meringkas kondisi permainan jadi sebuah state key diskrit untuk Q-table.
## dy_bucket   : posisi vertikal bola relatif ke paddle (dibagi 15px per bucket)
## approaching : apakah bola sedang menuju ke arah paddle ini (0/1)
## vy_sign     : arah vertikal bola (-1/0/1)
## dist_bucket : seberapa jauh bola secara horizontal (0..5)
func _encode_state(ball: CharacterBody2D) -> String:
	var dy := ball.position.y - paddle.position.y
	var dy_bucket := clampi(int(round(dy / 15.0)), -12, 12)
	var approaching := 1 if _is_approaching(ball) else 0
	var vy_sign := int(sign(ball.velocity.y))
	var dist_bucket := clampi(int(abs(ball.position.x - paddle.position.x) / 100.0), 0, 5)
	return "%d|%d|%d|%d" % [dy_bucket, approaching, vy_sign, dist_bucket]
