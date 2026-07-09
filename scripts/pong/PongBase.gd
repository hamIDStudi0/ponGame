extends Node2D
class_name PongBase
## Base class untuk semua varian pong (classic/twice/gravity/anime/breaker).
## Scene turunan wajib punya node ber-nama:
##   %LeftScoreLabel, %RightScoreLabel, %BackButton, %LeftPaddle, %RightPaddle
## dan bola-bola (BallScript) dimasukkan ke group "balls".

@export var mode_name: String = "classic"

var left_score := 0
var right_score := 0

@onready var left_score_label: Label = %LeftScoreLabel
@onready var right_score_label: Label = %RightScoreLabel
@onready var back_button: Button = %BackButton
@onready var left_paddle: PaddleScript = %LeftPaddle
@onready var right_paddle: PaddleScript = %RightPaddle

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	_update_score_labels()
	for b in get_tree().get_nodes_in_group("balls"):
		_connect_ball(b)
	_on_ready_extra()

## Hook untuk varian: setup tambahan (misal spawn bola kedua, gravity well, dsb).
func _on_ready_extra() -> void:
	pass

func _connect_ball(ball: BallScript) -> void:
	ball.scored.connect(_on_scored.bind(ball))
	ball.hit_paddle.connect(_on_hit_paddle.bind(ball))

func _on_scored(side: String, ball: BallScript) -> void:
	if side == "left":
		right_score += 1 # bola lewat kiri = kanan yang cetak skor
	else:
		left_score += 1
	_update_score_labels()
	_check_win()
	ball.reset_ball(1.0 if side == "left" else -1.0)
	_after_goal(side, ball)

## Hook: dipanggil setelah gol, sebelum bola direset ulang. Override untuk mode gravity/breaker.
func _after_goal(_side: String, _ball: BallScript) -> void:
	pass

## Hook: override untuk efek anime (pukulan/trampolin) atau tracking di mode gravity.
func _on_hit_paddle(_paddle: Node, _offset: float, _ball: BallScript) -> void:
	pass

func _update_score_labels() -> void:
	left_score_label.text = str(left_score)
	right_score_label.text = str(right_score)

func _check_win() -> void:
	if GameState.score_target <= 0:
		return # infinity mode, tidak pernah berhenti sendiri
	if left_score >= GameState.score_target or right_score >= GameState.score_target:
		var winner := "Kiri (AI)" if left_score > right_score else "Kanan (Player)"
		SaveManager.set_highscore(mode_name, max(left_score, right_score))
		_show_winner(winner)

func _show_winner(winner_text: String) -> void:
	var lbl := Label.new()
	lbl.text = "%s menang!" % winner_text
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.anchor_left = 0.5
	lbl.anchor_top = 0.5
	add_child(lbl)
	get_tree().paused = true

func _on_back() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/LocalMenu.tscn")
