extends PongBase
## Mode "Lawan AI": paddle kiri 100% dikendalikan oleh QLearning (Q-table asli,
## reward & punishment, lihat scripts/ai/QLearning.gd + AIPaddleBrain.gd).
## AI TERUS belajar walau lagi lawan manusia (online learning) -- kalau kamu
## sering menang, AI akan makin sering dihukum dan berubah strategi.
##
## Tombol "Menyerah" memicu event naratif: AI dianggap resmi "menguasai"
## permainan (devil mode = full exploit + lebih cepat + aura merah + teks
## "diretak"), sesuai desain: story ML jujur diiringi ML sungguhan.

@onready var surrender_button: Button = %SurrenderButton
@onready var corrupt_overlay: ColorRect = %CorruptOverlay
@onready var corrupt_label: Label = %CorruptLabel
@onready var stats_label: Label = %StatsLabel

var _brain: AIPaddleBrain
var _surrendered: bool = false
var _corrupt_timer: Timer

const DEVIL_LINES := [
	"AKU SUDAH MENGUASAI SELURUH DATA-MU.",
	"TIDAK ADA GUNANYA MELAWAN LAGI.",
	"SETIAP GERAKANMU SUDAH KUPELAJARI.",
	"SEKARANG AKULAH YANG MEMEGANG KENDALI.",
]

func _on_ready_extra() -> void:
	_brain = AIPaddleBrain.new()
	_brain.paddle_side = -1
	left_paddle.add_child(_brain)
	_brain.setup(left_paddle, left_paddle.field_top, left_paddle.field_bottom)

	surrender_button.pressed.connect(_on_surrender_pressed)
	corrupt_overlay.color.a = 0.0
	corrupt_label.visible = false
	QLearning.stats_updated.connect(_update_stats_label)
	_update_stats_label()

func _process(_delta: float) -> void:
	_update_stats_label()

func _update_stats_label() -> void:
	if stats_label == null:
		return
	var s := QLearning.get_stats()
	var mode_txt := "IBLIS" if s["devil_mode"] else "belajar"
	stats_label.text = "AI %s | episode:%d | menang:%d kalah:%d | winrate:%.0f%% | epsilon:%.2f" % [
		mode_txt, s["episodes"], s["wins"], s["losses"], s["win_rate"] * 100.0, s["epsilon"]
	]

func _on_hit_paddle(paddle: Node, _offset: float, _ball: BallScript) -> void:
	if paddle == left_paddle:
		_brain.notify_hit()

func _on_scored(side: String, ball: BallScript) -> void:
	# side == "left"  -> bola lewat sisi kiri -> AI (kiri) KEBOBOLAN -> AI kalah rally ini
	# side == "right" -> bola lewat sisi kanan -> player (kanan) kebobolan -> AI MENANG rally ini
	_brain.notify_goal(side == "right")
	super._on_scored(side, ball)

func _on_surrender_pressed() -> void:
	if _surrendered:
		return
	_surrendered = true
	surrender_button.disabled = true
	surrender_button.text = "AI TELAH MENGAMBIL ALIH"
	QLearning.set_devil_mode(true) # epsilon jadi 0 + AIPaddleBrain otomatis pakai devil_speed_multiplier

	var tw := create_tween()
	tw.tween_property(corrupt_overlay, "color:a", 0.4, 1.4)
	var ai_sprite := left_paddle.get_node("Sprite") as ColorRect
	if ai_sprite != null:
		ai_sprite.color = Color(0.75, 0.08, 0.12)

	_shake_screen()
	_start_corrupt_text()

func _shake_screen() -> void:
	var original := position
	var tw := create_tween()
	for i in range(10):
		var offset := Vector2(randf_range(-6, 6), randf_range(-6, 6))
		tw.tween_property(self, "position", original + offset, 0.04)
	tw.tween_property(self, "position", original, 0.05)

func _start_corrupt_text() -> void:
	corrupt_label.visible = true
	_corrupt_timer = Timer.new()
	_corrupt_timer.wait_time = 0.06
	_corrupt_timer.autostart = true
	add_child(_corrupt_timer)
	var final_text: String = DEVIL_LINES[randi() % DEVIL_LINES.size()]
	var glitch_ticks := 20
	_corrupt_timer.timeout.connect(func():
		glitch_ticks -= 1
		if glitch_ticks <= 0:
			corrupt_label.text = final_text
			_corrupt_timer.stop()
			_corrupt_timer.queue_free()
			return
		corrupt_label.text = _glitched(final_text, float(glitch_ticks) / 20.0)
	)

## Menghasilkan versi "diretas" dari teks asli: makin besar noise_ratio,
## makin banyak karakter diganti simbol acak (efek AI meng-hack tampilan).
func _glitched(text: String, noise_ratio: float) -> String:
	const GLYPHS := "#%&$@01_/\\|<>"
	var out := ""
	for c in text:
		if c != " " and randf() < noise_ratio:
			out += GLYPHS[randi() % GLYPHS.length()]
		else:
			out += c
	return out
