extends CharacterBody2D
class_name SparringBot
## Lawan tanding untuk fase LATIHAN (Training.tscn). Ini SENGAJA bukan ML --
## cuma bot heuristik sederhana yang mengikuti bola dengan reaksi lambat dan
## sedikit "human error", supaya QLearning agent (paddle kiri) punya lawan
## yang mengalahkan-nya cukup sering di awal, tapi bisa dikalahkan seiring
## AI belajar. Ini yang membuat proses training terasa seperti "berlatih
## melawan manusia" sebelum benar-benar melawan manusia asli.

@export var speed: float = 210.0
@export var reaction_error: float = 26.0 # px, offset acak biar tidak sempurna
@export var field_top: float = 20.0
@export var field_bottom: float = 340.0

var _target_y: float
var _retarget_timer: float = 0.0

func _physics_process(delta: float) -> void:
	var ball := _find_ball()
	_retarget_timer -= delta
	if ball != null and _retarget_timer <= 0.0:
		_retarget_timer = randf_range(0.12, 0.32) # simulasi delay reaksi manusia
		_target_y = ball.position.y + randf_range(-reaction_error, reaction_error)

	var dy := _target_y - position.y
	var dir := 0.0
	if abs(dy) > 4.0:
		dir = sign(dy)
	velocity.y = dir * speed
	velocity.x = 0
	move_and_slide()
	position.y = clamp(position.y, field_top, field_bottom)

func _find_ball() -> Node2D:
	var balls := get_tree().get_nodes_in_group("balls")
	if balls.is_empty():
		return null
	var best: Node2D = null
	var best_dist := INF
	for b in balls:
		var body := b as Node2D
		if body == null:
			continue
		var d: float = abs(body.position.x - position.x)
		if d < best_dist:
			best_dist = d
			best = body
	return best
