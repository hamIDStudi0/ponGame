extends Node
class_name AIPaddleBrain
## Menjembatani dunia game (posisi bola & paddle) dengan otak QLearning (DQN
## mini). Pasang sebagai child dari paddle (CharacterBody2D, biasanya
## PaddleScript dengan player_id = 0), lalu panggil notify_hit() /
## notify_goal() dari PongBase saat event terjadi supaya reward/punishment
## beneran dihitung.
##
## State yang dikirim ke DQN sekarang berupa VEKTOR ANGKA (6 fitur), bukan
## string bucket seperti Q-table lama:
##   [0] dy_norm         -> posisi vertikal bola relatif ke paddle (-1..1)
##   [1] approaching     -> apakah bola sedang menuju paddle ini (0/1)
##   [2] vy_sign         -> arah vertikal bola (-1/0/1)
##   [3] dist_norm       -> jarak horizontal bola ke paddle (0..1)
##   [4] speed_norm      -> KECEPATAN bola saat ini (0..1) -- prinsip akselerasi:
##                          makin cepat bola, makin AI harus bersiap lebih awal
##   [5] predicted_dy_norm -> PREDIKSI posisi Y bola nanti saat sampai di garis
##                          paddle ini, dengan mensimulasikan pantulan dinding
##                          atas/bawah (prinsip posisi pantulan)

@export var paddle_side: int = -1   # -1 kalau paddle ini di kiri layar, 1 kalau di kanan
@export var move_speed: float = 250.0
@export var devil_speed_multiplier: float = 1.35 # AI jadi lebih cepat & tajam pas mode iblis
@export var dead_zone_px: float = 6.0
@export var reference_max_ball_speed: float = 620.0 # samakan dengan BallScript.max_speed

var paddle: CharacterBody2D
var field_top: float = 20.0
var field_bottom: float = 340.0

var _last_state: Array = []
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
	# --- prediksi titik pantulan bola SAAT bola sedang mendekat (bukan pas menjauh). ---
	var approaching := _is_approaching(ball)
	var step_reward := 0.0
	if approaching:
		var predicted_y := _predict_intercept_y(ball)
		var dy := predicted_y - paddle.position.y
		step_reward = -clamp(abs(dy) / 300.0, 0.0, 1.0) * 0.05
	step_reward += _pending_reward
	_pending_reward = 0.0

	if _has_last_state:
		QLearning.learn(_last_state, _last_action, step_reward, state, false)

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
## Rally berakhir di sini (done=true) -- state Bellman tidak menjalar lewat
## batas rally, cocok dengan gaya episodic RL.
func notify_goal(won: bool) -> void:
	_pending_reward += (5.0 if won else -5.0) # hadiah besar / hukuman
	if _has_last_state:
		QLearning.learn(_last_state, _last_action, _pending_reward, _last_state, true)
	_pending_reward = 0.0
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

## Mensimulasikan lintasan lurus bola + pantulan dinding atas/bawah lapangan
## untuk memprediksi di posisi Y berapa bola akan tiba saat mencapai garis
## horizontal paddle ini. Ini "prinsip posisi pantulan" yang diminta --
## murah secara komputasi (cuma aljabar, tanpa loop simulasi tiap frame).
func _predict_intercept_y(ball: CharacterBody2D) -> float:
	if abs(ball.velocity.x) < 1.0:
		return ball.position.y
	var dist_x: float = paddle.position.x - ball.position.x
	var t: float = dist_x / ball.velocity.x
	if t < 0.0:
		return ball.position.y # bola sudah lewat / menjauh, prediksi tidak relevan
	var raw_y: float = ball.position.y + ball.velocity.y * t
	var span: float = max(field_bottom - field_top, 1.0)
	# "Lipat" y ke rentang [field_top, field_bottom] ala pantulan cermin berulang.
	var rel: float = fmod(raw_y - field_top, 2.0 * span)
	if rel < 0.0:
		rel += 2.0 * span
	if rel > span:
		rel = 2.0 * span - rel
	return field_top + rel

## Meringkas kondisi permainan jadi vektor 6-angka untuk DQN.
func _encode_state(ball: CharacterBody2D) -> Array:
	var dy_norm := clamp((ball.position.y - paddle.position.y) / 300.0, -1.0, 1.0)
	var approaching := 1.0 if _is_approaching(ball) else 0.0
	var vy_sign := float(sign(ball.velocity.y))
	var dist_norm := clamp(abs(ball.position.x - paddle.position.x) / 640.0, 0.0, 1.0)
	var speed_norm := clamp(ball.velocity.length() / reference_max_ball_speed, 0.0, 1.0)
	var predicted_y := _predict_intercept_y(ball)
	var predicted_dy_norm := clamp((predicted_y - paddle.position.y) / 300.0, -1.0, 1.0)
	return [dy_norm, approaching, vy_sign, dist_norm, speed_norm, predicted_dy_norm]
