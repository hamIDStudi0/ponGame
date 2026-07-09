extends Node2D
## Layar loading dengan judul "hamIDStudio" + progress bar bergaya pixel.
## Ganti PixelBar texture di editor dengan sprite pixel-art asli untuk hasil terbaik.

@onready var bar: TextureProgressBar = %PixelBar
@onready var studio_label: Label = %StudioLabel

var _fake_progress := 0.0
var _min_time := 1.6 # detik minimum supaya logo studio sempat terbaca
var _elapsed := 0.0

func _ready() -> void:
	studio_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(studio_label, "modulate:a", 1.0, 0.5)
	# efek "flicker" pixel khas boot logo retro
	tw.tween_property(studio_label, "modulate:a", 0.6, 0.06)
	tw.tween_property(studio_label, "modulate:a", 1.0, 0.06)

func _process(delta: float) -> void:
	_elapsed += delta
	_fake_progress = min(100.0, _fake_progress + delta * 70.0)
	bar.value = _fake_progress
	if _fake_progress >= 100.0 and _elapsed >= _min_time:
		set_process(false)
		_go_to_next_scene()

func _go_to_next_scene() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
