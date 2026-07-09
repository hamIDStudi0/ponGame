extends PongBase
## Fase "Latihan Serius": AI (paddle kiri) berlatih DQN mini melawan
## SparringBot (bot heuristik, bukan ML) dengan waktu simulasi dipercepat,
## sambil menampilkan fakta ML acak dan progress menuju "pintar". Bobot
## jaringan yang dipelajari di sini AKAN dipakai juga saat mode "Lawan AI"
## (persisten, tersimpan di disk).
##
## Catatan waktu latihan: walau simulasi dipercepat lewat slider, progress
## "menuju 4 jam latihan" (QLearning.tick_training_time) memakai waktu NYATA
## (real-time), bukan waktu yang sudah dikali speed-up, biar jujur.

@onready var quote_label: Label = %QuoteLabel
@onready var stats_label: Label = %StatsLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var finish_button: Button = %FinishButton
@onready var speed_slider: HSlider = %SpeedSlider

var _brain: AIPaddleBrain
var _quote_timer: float = 0.0
const QUOTE_INTERVAL := 5.5

func _on_ready_extra() -> void:
	_brain = AIPaddleBrain.new()
	_brain.paddle_side = -1
	_brain.devil_speed_multiplier = 1.0 # tidak ada mode iblis selama latihan murni
	left_paddle.add_child(_brain)
	_brain.setup(left_paddle, left_paddle.field_top, left_paddle.field_bottom)

	finish_button.pressed.connect(_on_finish_pressed)
	speed_slider.value_changed.connect(func(v): Engine.time_scale = v)
	Engine.time_scale = speed_slider.value

	quote_label.text = MLQuotes.random_quote()
	_update_hud()

func _process(delta: float) -> void:
	# delta di sini sudah kena Engine.time_scale, jadi progress kutipan ikut
	# terasa lebih cepat juga saat training dipercepat -- disengaja.
	_quote_timer += delta
	if _quote_timer >= QUOTE_INTERVAL:
		_quote_timer = 0.0
		quote_label.text = MLQuotes.random_quote()

	# Waktu latihan "menuju 4 jam" memakai delta NYATA (dibagi time_scale
	# supaya tidak ikut dipercepat oleh slider) -- lihat catatan di atas.
	var real_delta := delta / max(Engine.time_scale, 0.0001)
	QLearning.tick_training_time(real_delta)

	_update_hud()

func _update_hud() -> void:
	var s := QLearning.get_stats()
	var jam := int(s["training_seconds"] / 3600.0)
	var menit := int(fmod(s["training_seconds"], 3600.0) / 60.0)
	stats_label.text = "Episode: %d   Menang: %d   Kalah: %d   Winrate: %.0f%%   Epsilon: %.2f   Replay buffer: %d\nWaktu latihan: %dj %dm menuju target 4 jam (%.0f%%)%s" % [
		s["episodes"], s["wins"], s["losses"], s["win_rate"] * 100.0, s["epsilon"], s["table_size"],
		jam, menit, s["training_progress"] * 100.0, "  [AI SUDAH MATANG]" if s["mature"] else ""
	]
	progress_bar.value = clamp(s["win_rate"] * 100.0, 0, 100)
	if s["smart"]:
		finish_button.text = "AI SUDAH CUKUP PINTAR -- Lanjut ke Lawan AI"
	else:
		finish_button.text = "Selesai Latihan (masih %.0f%% menuju siap)" % [min(s["win_rate"] / 0.55, 1.0) * 100.0]

func _on_hit_paddle(paddle: Node, _offset: float, _ball: BallScript) -> void:
	if paddle == left_paddle:
		_brain.notify_hit()

func _on_scored(side: String, ball: BallScript) -> void:
	_brain.notify_goal(side == "right")
	# infinity mode: skor terus di-reset ringan biar training bisa jalan lama
	# tanpa munculnya layar "menang" di tengah proses belajar.
	super._on_scored(side, ball)

func _check_win() -> void:
	pass # di training, tidak ada "pemenang" pertandingan -- ini soal belajar terus-menerus

func _on_finish_pressed() -> void:
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/pong/PongVsAI.tscn")

func _on_back() -> void:
	Engine.time_scale = 1.0
	super._on_back()
