extends PongBase
## Gravity: ada tarikan magnet kecil di tengah lapangan yang mengganggu arah bola.
## Kalau bola sampai tertarik masuk ke gravity (blackhole) SAAT sedang dipegang
## (baru saja dipantulkan) oleh salah satu paddle, paddle pemegang awal itu
## yang kehilangan satu poin (bukan lawannya) -- sesuai desain.

@export var pull_strength: float = 4200.0
@export var swallow_radius: float = 10.0

@onready var well: Area2D = %GravityWell

# side terakhir yang memantulkan tiap bola: "left" / "right" / ""
var _last_hit_side: Dictionary = {}

func _physics_process(_delta: float) -> void:
	for ball in get_tree().get_nodes_in_group("balls"):
		var to_well: Vector2 = well.position - ball.position
		var dist := to_well.length()
		if dist < swallow_radius:
			_swallow(ball)
			continue
		if dist < 140.0: # radius pengaruh gravitasi
			var pull := to_well.normalized() * (pull_strength / max(dist, 20.0))
			ball.velocity += pull * _delta_safe()

func _delta_safe() -> float:
	return get_physics_process_delta_time()

func _on_hit_paddle(_paddle: Node, _offset: float, ball: BallScript) -> void:
	_last_hit_side[ball.get_instance_id()] = "left" if _paddle == left_paddle else "right"

func _swallow(ball: BallScript) -> void:
	# Sesuai desain: bola yang tertelan blackhole membuat SI PEMEGANG AWAL
	# (paddle yang barusan memantulkannya) kehilangan satu poin.
	var side: String = _last_hit_side.get(ball.get_instance_id(), "")
	if side == "left":
		left_score = max(0, left_score - 1)
	elif side == "right":
		right_score = max(0, right_score - 1)
	_update_score_labels()
	var dir := 1.0 if side == "right" else -1.0
	ball.reset_ball(dir)
	_last_hit_side.erase(ball.get_instance_id())
