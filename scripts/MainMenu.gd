extends Node2D

@onready var story_btn: Button = %StoryButton
@onready var local_btn: Button = %LocalButton
@onready var train_btn: Button = %TrainButton
@onready var vs_ai_btn: Button = %VsAiButton
@onready var about_btn: Button = %AboutButton

func _ready() -> void:
	story_btn.pressed.connect(_on_story)
	local_btn.pressed.connect(_on_local)
	train_btn.pressed.connect(_on_train)
	vs_ai_btn.pressed.connect(_on_vs_ai)
	about_btn.pressed.connect(_on_about)

	# Kalau AI sudah dianggap cukup pintar dari sesi latihan sebelumnya
	# (Q-table persisten), tandai di label supaya user tahu progresnya nyata.
	var stats := QLearning.get_stats()
	if stats["smart"]:
		vs_ai_btn.text = "LAWAN AI (sudah pintar)"
	elif stats["episodes"] > 0:
		vs_ai_btn.text = "LAWAN AI (masih belajar)"

	# Kalau story sudah pernah dimulai tapi belum selesai, ubah label tombol
	# jadi "LANJUTKAN" -- progress TIDAK pernah reset otomatis (sesuai requirement).
	if SaveManager.get_story_index() > 0 and not SaveManager.is_story_completed():
		story_btn.text = "LANJUTKAN STORY"
	elif SaveManager.is_story_completed():
		story_btn.text = "STORY (SELESAI)"

func _on_story() -> void:
	get_tree().change_scene_to_file("res://scenes/Story.tscn")

func _on_local() -> void:
	get_tree().change_scene_to_file("res://scenes/LocalMenu.tscn")

func _on_train() -> void:
	get_tree().change_scene_to_file("res://scenes/Training.tscn")

func _on_vs_ai() -> void:
	get_tree().change_scene_to_file("res://scenes/pong/PongVsAI.tscn")

func _on_about() -> void:
	get_tree().change_scene_to_file("res://scenes/About.tscn")
