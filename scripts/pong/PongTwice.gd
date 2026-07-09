extends PongBase
## Twice: dua bola aktif bersamaan, jadi tidak ada giliran -- kedua pemain
## selalu "memegang" bola (selalu ada bola menuju ke arah mereka).

func _on_ready_extra() -> void:
	# Bola pertama menuju kanan, bola kedua menuju kiri, supaya dari awal
	# kedua pemain langsung punya bola datang ke arah mereka.
	var balls := get_tree().get_nodes_in_group("balls")
	if balls.size() >= 2:
		balls[0].reset_ball(1.0)
		balls[1].reset_ball(-1.0)
