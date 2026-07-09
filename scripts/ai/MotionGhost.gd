extends Node2D
class_name MotionGhost
## Satu "jejak bayangan" (afterimage) untuk efek motion blur retro.
## Digambar manual (bukan pakai shader) supaya jalan mulus di ColorRect biasa.

var rect_size: Vector2 = Vector2(10, 10)
var base_color: Color = Color(1, 1, 1)

func _draw() -> void:
	draw_rect(Rect2(-rect_size / 2.0, rect_size), base_color)
