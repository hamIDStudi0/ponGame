extends PongBase
## Anime: animasi dramatis tergantung titik pukul.
## - Pinggir paddle (|offset| besar) -> efek "pukul tongkat bisbol": paddle
##   berotasi cepat seperti ayunan, bola melesat lebih kencang ke arah sudut tajam.
## - Tengah paddle (|offset| kecil) -> efek "trampolin": paddle melengkung/menekuk
##   lalu memantul balik dengan tenaga penuh (bola lurus & sangat cepat).

const EDGE_THRESHOLD := 0.6
const CENTER_THRESHOLD := 0.25
const EDGE_BOOST := 1.5
const CENTER_BOOST := 1.9

func _on_hit_paddle(paddle: Node, offset: float, ball: BallScript) -> void:
	var sprite: Node = paddle.get_node_or_null("Sprite")
	if abs(offset) >= EDGE_THRESHOLD:
		_bat_swing(paddle, sprite)
		ball.velocity *= EDGE_BOOST
		# sudut makin tajam mengarah ke pojok
		ball.velocity.y += sign(offset) * 120.0
	elif abs(offset) <= CENTER_THRESHOLD:
		_trampoline_bounce(paddle, sprite)
		var dir_x := sign(ball.velocity.x)
		ball.velocity = Vector2(dir_x, 0).normalized() * ball.velocity.length() * CENTER_BOOST

func _bat_swing(paddle: Node, sprite: Node) -> void:
	if sprite == null:
		return
	var tw := create_tween()
	tw.tween_property(sprite, "rotation", deg_to_rad(35), 0.08)
	tw.tween_property(sprite, "rotation", 0.0, 0.16)

func _trampoline_bounce(paddle: Node, sprite: Node) -> void:
	if sprite == null:
		return
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.4, 0.55), 0.08)
	tw.tween_property(sprite, "scale", Vector2(0.85, 1.2), 0.08)
	tw.tween_property(sprite, "scale", Vector2(1, 1), 0.12)
