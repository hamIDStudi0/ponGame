extends Node2D
class_name PixelGlowCircle
## Lingkaran kekuatan biru bercahaya bergaya PIKSEL (bukan lingkaran vektor
## mulus) supaya konsisten dengan estetika seluruh game ini yang serba
## ColorRect/kotak-kotak. Efisien secara sengaja:
##   - Titik-titik piksel dihitung & digambar SEKALI saja (_draw dipanggil
##     sekali saat _ready, bukan tiap frame).
##   - Efek "berkedip/bercahaya" dilakukan cuma dengan animasi `modulate`
##     (alpha & sedikit warna), yang TIDAK butuh redraw sama sekali karena
##     ditangani langsung oleh renderer -- jadi walau terlihat hidup, biaya
##     CPU-nya nyaris nol. Cocok dipakai di HP dengan spek rendah.

@export var radius: float = 30.0
@export var pixel_size: float = 3.5
@export var base_color: Color = Color(0.30, 0.70, 1.0)

var _points: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	_generate_points()
	queue_redraw()
	_start_pulse()

func _generate_points() -> void:
	_points.clear()
	var step: float = pixel_size * 1.7
	var r2: float = radius * radius
	var y := -radius
	while y <= radius:
		var x := -radius
		while x <= radius:
			if x * x + y * y <= r2:
				_points.append(Vector2(x, y))
			x += step
		y += step

func _draw() -> void:
	var half := Vector2(pixel_size, pixel_size) * 0.5
	for p in _points:
		draw_rect(Rect2(p - half, Vector2(pixel_size, pixel_size)), base_color)

## Animasi "bercahaya" murah: cuma naik-turun alpha lewat satu Tween loop,
## tidak ada perhitungan/redraw tambahan tiap frame.
func _start_pulse() -> void:
	var tw := create_tween()
	tw.set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "modulate:a", 0.55, 0.9)
	tw.tween_property(self, "modulate:a", 1.0, 0.9)
