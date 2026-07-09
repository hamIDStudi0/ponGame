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
var _glow_circle: PixelGlowCircle

## --- Animasi intro "mengetik kode" ---
## Potongan kode Python singkat yang menggambarkan inti dari Machine
## Learning: belajar dari kesalahan lewat gradient descent. Sengaja pendek
## supaya animasi ketiknya cepat & efisien (tidak memotong banyak waktu),
## dengan sedikit pewarnaan sintaks (bbcode) biar terasa seperti editor kode.
const CODE_SNIPPET_BBCODE := "[color=#7fd9ff]class[/color] [color=#bdeeff]Model[/color]:\n    [color=#7fd9ff]def[/color] [color=#9df2c2]fit[/color](self, mistake):\n        [color=#6b7b85]# belajar dari kesalahan[/color]\n        self.w [color=#ffb86b]-=[/color] lr [color=#ffb86b]*[/color] grad(mistake)\n        [color=#7fd9ff]return[/color] [color=#ffe08a]\"berhasil dipelajari\"[/color]"
const CODE_TYPE_DURATION := 1.1
const CODE_HOLD_DURATION := 0.25
const CODE_MORPH_DURATION := 0.5

var _code_label: RichTextLabel

func _ready() -> void:
	skip_button.pressed.connect(_skip_to_menu)
	dialogue.line_finished.connect(_on_line_finished)
	dialogue.advanced.connect(_advance_line)

	_build_code_label()
	_glow_circle = PixelGlowCircle.new()
	ai_circle.add_child(_glow_circle)

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
		"code_typing_intro":
			_move_camera_to(CAMERA_WIDE)
			_play_code_typing_intro()
		"circle_spawn": # dipertahankan untuk kompatibilitas kalau dipanggil manual
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
			var detail := parts[2] if parts.size() > 2 else ""
			_spawn_data_node(label, false, detail)
		"open_data_form_network":
			var label2 := parts[1] if parts.size() > 1 else "data_%08d" % SaveManager.unlock_next_data_node()
			var detail2 := parts[2] if parts.size() > 2 else ""
			_spawn_data_node(label2, true, detail2)
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

## ---------------------------------------------------------------------
## Intro "mengetik kode": menampilkan potongan kode Python singkat (model
## belajar dari kesalahan) yang diketik cepat & efisien (satu Tween pada
## visible_ratio -- BUKAN loop per-karakter, jadi murah secara CPU), lalu
## bermetamorfosis (cross-fade + scale pop) menjadi lingkaran biru bercahaya.
## ---------------------------------------------------------------------
func _build_code_label() -> void:
	_code_label = RichTextLabel.new()
	_code_label.bbcode_enabled = true
	_code_label.fit_content = true
	_code_label.scroll_active = false
	_code_label.modulate.a = 0.0
	_code_label.visible_ratio = 0.0
	_code_label.add_theme_font_size_override("normal_font_size", 12)
	_code_label.position = Vector2(170, 90)
	_code_label.size = Vector2(300, 130)
	_code_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_code_label.text = CODE_SNIPPET_BBCODE
	add_child(_code_label)

func _play_code_typing_intro() -> void:
	_code_label.visible_ratio = 0.0
	ai_circle.modulate.a = 0.0
	ai_circle.scale = Vector2(0.4, 0.4)

	var tw := create_tween()
	tw.tween_property(_code_label, "modulate:a", 1.0, 0.15) # kode langsung muncul, cepat
	tw.tween_property(_code_label, "visible_ratio", 1.0, CODE_TYPE_DURATION).set_trans(Tween.TRANS_LINEAR)
	tw.tween_interval(CODE_HOLD_DURATION) # jeda sebentar biar sempat "dibaca" sekilas
	# --- Morph: kode memudar barengan lingkaran biru bercahaya muncul & "pop" ---
	tw.tween_property(_code_label, "modulate:a", 0.0, CODE_MORPH_DURATION)
	tw.parallel().tween_property(ai_circle, "modulate:a", 1.0, CODE_MORPH_DURATION)
	tw.parallel().tween_property(ai_circle, "scale", Vector2(1.0, 1.0), CODE_MORPH_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Menambahkan visual "file data" baru yang muncul di area folder Machine Learning,
## kalau connect=true akan digambar garis penghubung antar node (jaringan saraf sederhana),
## dan detail_text (kalau ada) menampilkan sekilas isi "dalaman" data itu -- misalnya
## reward/punishment yang diterima & di posisi/kondisi apa itu terjadi.
func _spawn_data_node(label_text: String, connect: bool, detail_text: String = "") -> void:
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

	if detail_text != "":
		var detail_lbl := Label.new()
		detail_lbl.text = detail_text
		detail_lbl.add_theme_font_size_override("font_size", 7)
		detail_lbl.modulate = Color(0.75, 0.95, 0.85, 0.0)
		detail_lbl.position = Vector2(pos.x - 4, pos.y + 22)
		data_layer.add_child(detail_lbl)
		var tw_detail := create_tween()
		tw_detail.tween_interval(0.3) # muncul sesaat setelah label utama, biar terbaca berurutan
		tw_detail.tween_property(detail_lbl, "modulate:a", 0.9, 0.35)

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
	_code_label.visible = false
	ai_circle.visible = false
	ai_paddle.modulate.a = 1.0
	player_paddle.modulate.a = 1.0
	camera.position = CAMERA_WIDE
	for i in range(target_index):
		var ev: String = StoryData.LINES[i].get("event", "none")
		if ev.begins_with("spawn_data_node") or ev.begins_with("open_data_form_network"):
			var parts := ev.split(":")
			var label := parts[1] if parts.size() > 1 else "data_%08d" % (i + 1)
			var detail := parts[2] if parts.size() > 2 else ""
			_spawn_data_node(label, ev.begins_with("open_data_form_network"), detail)
		elif ev == "ai_corrupt_takeover":
			corrupt_overlay.color.a = 0.35
			ai_paddle.color = Color(0.8, 0.1, 0.15)
		elif ev == "ai_power_up":
			ai_spirit.color.a = 0.15
