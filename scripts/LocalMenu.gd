extends Node2D

@onready var classic_btn: Button = %ClassicButton
@onready var twice_btn: Button = %TwiceButton
@onready var gravity_btn: Button = %GravityButton
@onready var anime_btn: Button = %AnimeButton
@onready var breaker_btn: Button = %BreakerButton
@onready var back_btn: Button = %BackButton

func _ready() -> void:
	classic_btn.pressed.connect(func(): _start(GameState.PongMode.CLASSIC))
	twice_btn.pressed.connect(func(): _start(GameState.PongMode.TWICE))
	gravity_btn.pressed.connect(func(): _start(GameState.PongMode.GRAVITY))
	anime_btn.pressed.connect(func(): _start(GameState.PongMode.ANIME))
	breaker_btn.pressed.connect(func(): _start(GameState.PongMode.BREAKER))
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))

func _start(mode: int) -> void:
	GameState.selected_mode = mode
	GameState.score_target = -1 # infinity by default; bisa dibuat UI pilih target nanti
	get_tree().change_scene_to_file(GameState.get_scene_path_for_mode(mode))
