extends Node2D

@onready var camera: Camera2D = %Camera2D
@onready var ai_circle: Node2D = %AICircle
@onready var ai_paddle: ColorRect = %AIPaddle
@onready var player_paddle: ColorRect = %PlayerPaddle
@onready var ai_spirit: ColorRect = %AISpirit
@onready var data_layer: Node2D = %DataNodeLayer
@onready var corrupt_overlay: ColorRect = %CorruptOverlay
@onready var skip_button: Button = %SkipButton
@onready var dialogue: DialogueSystem = $DialogueSystem

const CAMERA_AI := Vector2(90, 180)
const CAMERA_PLAYER := Vector2(560, 180)
const CAMERA_WIDE := Vector2(320, 180)

var _line_index := 0
var _node_positions: Array[Vector2] = []
var _prev_node: Node2D = null

func _ready() -> void:
	skip_button.pressed.connect(_skip_to_menu)
	dialogue.line_finished.connect(_on_line_finished)
	dialogue.advanced.connect(_advance_line)

	# --- Resume otomatis dari save, story TIDAK reset walau keluar game ---
	_line_index = SaveManager.get_story_index()
	if SaveManager.is_story_completed():
		_line_index = 0 # boleh ditonton ulang kalau sudah selesai, opsional

	_replay_visual_state_up_to(_line_index)
	_play_current_line()

func _play_current_line() -> void:
	if _line_index >= StoryData.LINES.size():
		SaveManager.mark_story_completed()
		_skip_to_menu()
		return
	var line: Dictionary = StoryData.LINES[_line_index]
	_run_event(line.get("event", "none"))
	dialogue.show_line(line.get("speaker", ""), line.get("text", ""))

func _on_line_finished() -> void:
	pass # menunggu tap player (event "advanced") sebelum lanjut, sesuai gaya visual novel

func _advance_line() -> void:
	_line_index += 1
	SaveManager.set_story_index(_line_index)
	_play_current_line()

func _skip_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

## Memindahkan kamera dengan animasi halus ke titik fokus tertentu.
func _move_camera_to(target: Vector2, duration: float = 0.8) -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(camera, "position", target, duration)

func _fade_in(node: CanvasItem, duration: float = 0.6) -> void:
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", 1.0, duration)

## Menjalankan efek visual sesuai tag event dari StoryData.
func _run_event(event: String) -> void:
	var parts := event.split(":")
	var key := parts[0]
	match key:
		"circle_spawn":
			_move_camera_to(CAMERA_WIDE)
			_fade_in(ai_circle, 1.0)
		"camera_ai":
			_move_camera_to(CAMERA_AI)
		"camera_player":
			_move_camera_to(CAMERA_PLAYER)
		"camera_wide":
			_move_camera_to(CAMERA_WIDE)
		"circle_enter_paddle":
			_move_camera_to(CAMERA_AI)
			var tw := create_tween()
			tw.tween_property(ai_circle, "scale", Vector2(0.2, 0.2), 0.5)
			tw.parallel().tween_property(ai_circle, "position", ai_paddle.position, 0.5)
			tw.tween_callback(func():
				_fade_in(ai_paddle)
				ai_circle.visible = false
			)
		"player_paddle_spawn":
			_move_camera_to(CAMERA_PLAYER)
			_fade_in(player_paddle)
		"match_start":
			_move_camera_to(CAMERA_WIDE)
		"spawn_data_node":
			var label := parts[1] if parts.size() > 1 else "data_%08d" % SaveManager.unlock_next_data_node()
			_spawn_data_node(label, false)
		"open_data_form_network":
			var label2 := parts[1] if parts.size() > 1 else "data_%08d" % SaveManager.unlock_next_data_node()
			_spawn_data_node(label2, true)
		"ai_power_up":
			_move_camera_to(CAMERA_AI)
			var tw2 := create_tween()
			tw2.tween_property(ai_spirit, "color:a", 0.35, 1.2)
			tw2.tween_property(ai_spirit, "color:a", 0.15, 1.2)
			tw2.set_loops(3)
		"ai_corrupt_takeover":
			_move_camera_to(CAMERA_WIDE)
			var tw3 := create_tween()
			tw3.tween_property(corrupt_overlay, "color:a", 0.35, 1.5)
			ai_paddle.color = Color(0.8, 0.1, 0.15)
		_:
			pass

## Menambahkan visual "file data" baru yang muncul di area folder Machine Learning,
## dan kalau connect=true akan digambar garis penghubung antar node (jaringan saraf sederhana).
func _spawn_data_node(label_text: String, connect: bool) -> void:
	var node := ColorRect.new()
	node.color = Color(0.3, 0.9, 0.6)
	node.size = Vector2(10, 10)
	var idx := _node_positions.size()
	var pos := Vector2((idx % 4) * 26, int(idx / 4.0) * 26)
	node.position = pos
	node.modulate.a = 0.0
	data_layer.add_child(node)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.position = Vector2(pos.x - 4, pos.y + 12)
	lbl.modulate.a = 0.0
	data_layer.add_child(lbl)

	var tw := create_tween()
	tw.tween_property(node, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(lbl, "modulate:a", 1.0, 0.4)

	if connect and _prev_node != null:
		var line := Line2D.new()
		line.width = 1.5
		line.default_color = Color(0.3, 0.9, 0.6, 0.5)
		line.add_point(_prev_node.position + Vector2(5, 5))
		line.add_point(pos + Vector2(5, 5))
		data_layer.add_child(line)
		data_layer.move_child(line, 0)

	_prev_node = node
	_node_positions.append(pos)

## Kalau player melanjutkan story dari save (bukan dari awal), kita "lompat" langsung
## ke state visual yang sesuai (paddle sudah muncul, data node sudah ada, dst)
## tanpa memutar ulang semua animasi transisi.
func _replay_visual_state_up_to(target_index: int) -> void:
	if target_index <= 0:
		return
	ai_circle.visible = false
	ai_paddle.modulate.a = 1.0
	player_paddle.modulate.a = 1.0
	camera.position = CAMERA_WIDE
	for i in range(target_index):
		var ev: String = StoryData.LINES[i].get("event", "none")
		if ev.begins_with("spawn_data_node") or ev.begins_with("open_data_form_network"):
			var parts := ev.split(":")
			var label := parts[1] if parts.size() > 1 else "data_%08d" % (i + 1)
			_spawn_data_node(label, ev.begins_with("open_data_form_network"))
		elif ev == "ai_corrupt_takeover":
			corrupt_overlay.color.a = 0.35
			ai_paddle.color = Color(0.8, 0.1, 0.15)
		elif ev == "ai_power_up":
			ai_spirit.color.a = 0.15
