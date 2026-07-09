extends PongBase
## Breaker: kebalikan dari pong biasa. Tujuannya BUKAN memantulkan bola supaya
## tidak gol, tapi menghindari bola sama sekali. Kalau paddle tersentuh bola,
## sisi itu kehilangan satu poin (dan lawannya tetap jalan terus / infinity).

func _on_ready_extra() -> void:
	var l_zone: Area2D = left_paddle.get_node("DeathZone")
	var r_zone: Area2D = right_paddle.get_node("DeathZone")
	l_zone.body_entered.connect(_on_hit.bind("left"))
	r_zone.body_entered.connect(_on_hit.bind("right"))

func _on_hit(body: Node, side: String) -> void:
	if not (body is BallScript):
		return
	if side == "left":
		left_score = max(0, left_score - 1)
		right_score += 1
	else:
		right_score = max(0, right_score - 1)
		left_score += 1
	_update_score_labels()
	_check_win()
	var dir := -1.0 if side == "left" else 1.0
	body.reset_ball(dir)
	_flash_death(side)

func _flash_death(side: String) -> void:
	var paddle := left_paddle if side == "left" else right_paddle
	var sprite: Node = paddle.get_node_or_null("Sprite")
	if sprite:
		var tw := create_tween()
		tw.tween_property(sprite, "modulate", Color(1, 0.2, 0.2), 0.1)
		tw.tween_property(sprite, "modulate", Color(1, 1, 1), 0.3)
