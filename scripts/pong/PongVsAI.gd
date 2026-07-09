extends PongBase
## Mode "Lawan AI": paddle kiri 100% dikendalikan oleh QLearning (DQN mini,
## reward & punishment sungguhan, lihat scripts/ai/QLearning.gd +
## AIPaddleBrain.gd). AI TERUS belajar walau lagi lawan manusia (online
## learning) -- kalau kamu sering menang, AI akan makin sering dihukum dan
## berubah strategi.
##
## Tombol "Menyerah" HANYA mengakhiri pertandingan (kembali ke menu) --
## TIDAK LAGI memicu mode "iblis".
##
## Mode "iblis" (AI mengambil alih, aura merah, teks diretas) sekarang
## dipicu murni oleh PERFORMA di dalam pertandingan itu sendiri:
##   (a) Rally panjang: bola berhasil dipantulkan bolak-balik sebanyak
##       RALLY_THRESHOLD kali (acak 10-20) tanpa ada yang kebobolan, ATAU
##   (b) AI menang beruntun sebanyak STREAK_THRESHOLD poin (acak 7-10)
##       tanpa kalah sekali pun.
## Begitu salah satu kondisi mendekati ambang batas, efek gelap mulai
## muncul SEDIKIT DEMI SEDIKIT (overlay makin pekat, warna paddle AI makin
## gelap secara bertahap) baru benar-benar penuh saat ambang tercapai.

@onready var surrender_button: Button = %SurrenderButton
@onready var corrupt_overlay: ColorRect = %CorruptOverlay
@onready var corrupt_label: Label = %CorruptLabel
@onready var stats_label: Label = %StatsLabel

var _brain: AIPaddleBrain
var _devil_triggered: bool = false
var _corrupt_timer: Timer

## --- Pelacak pemicu mode iblis ---
var _rally_hits: int = 0
var _ai_win_streak: int = 0
var _rally_threshold: int
var _streak_threshold: int
const OVERLAY_MAX_ALPHA := 0.4
const AI_DARK_COLOR := Color(0.75, 0.08, 0.12)
var _ai_base_color: Color

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

	_rally_threshold = randi_range(10, 20)
	_streak_threshold = randi_range(7, 10)

	surrender_button.pressed.connect(_on_surrender_pressed)
	corrupt_overlay.color.a = 0.0
	corrupt_label.visible = false
	var ai_sprite := left_paddle.get_node_or_null("Sprite") as ColorRect
	_ai_base_color = ai_sprite.color if ai_sprite != null else Color(0.2, 0.65, 1.0)
	QLearning.stats_updated.connect(_update_stats_label)
	_update_stats_label()

func _process(delta: float) -> void:
	QLearning.tick_training_time(delta) # bermain lawan AI juga terhitung sebagai jam terbang belajarnya
	_update_stats_label()

func _update_stats_label() -> void:
	if stats_label == null:
		return
	var s := QLearning.get_stats()
	var mode_txt := "IBLIS" if s["devil_mode"] else "belajar"
	stats_label.text = "AI %s | episode:%d | menang:%d kalah:%d | winrate:%.0f%% | epsilon:%.2f | rally:%d/%d | streak AI:%d/%d" % [
		mode_txt, s["episodes"], s["wins"], s["losses"], s["win_rate"] * 100.0, s["epsilon"],
		_rally_hits, _rally_threshold, _ai_win_streak, _streak_threshold
	]

func _on_hit_paddle(paddle: Node, _offset: float, _ball: BallScript) -> void:
	if paddle == left_paddle:
		_brain.notify_hit()
	if not _devil_triggered:
		_rally_hits += 1
		_update_corruption_buildup()

func _on_scored(side: String, ball: BallScript) -> void:
	# side == "left"  -> bola lewat sisi kiri -> AI (kiri) KEBOBOLAN -> AI kalah rally ini
	# side == "right" -> bola lewat sisi kanan -> player (kanan) kebobolan -> AI MENANG rally ini
	_brain.notify_goal(side == "right")
	if not _devil_triggered:
		_rally_hits = 0
		_ai_win_streak = (_ai_win_streak + 1) if side == "right" else 0
		_update_corruption_buildup()
	super._on_scored(side, ball)

## Menghitung seberapa dekat kita ke salah satu pemicu (0..1), lalu
## menerapkan efek visual SECARA PROPORSIONAL (bertahap) -- baru memicu
## transformasi penuh saat salah satu ambang benar-benar tercapai.
func _update_corruption_buildup() -> void:
	var rally_progress := float(_rally_hits) / float(_rally_threshold)
	var streak_progress := float(_ai_win_streak) / float(_streak_threshold)
	var progress: float = clamp(max(rally_progress, streak_progress), 0.0, 1.0)

	corrupt_overlay.color.a = progress * OVERLAY_MAX_ALPHA
	var ai_sprite := left_paddle.get_node_or_null("Sprite") as ColorRect
	if ai_sprite != null:
		ai_sprite.color = _ai_base_color.lerp(AI_DARK_COLOR, progress)

	if progress >= 1.0 and not _devil_triggered:
		_trigger_devil_mode()

func _trigger_devil_mode() -> void:
	_devil_triggered = true
	QLearning.set_devil_mode(true) # epsilon jadi 0 + AIPaddleBrain otomatis pakai devil_speed_multiplier
	_shake_screen()
	_start_corrupt_text()

func _on_surrender_pressed() -> void:
	# Sekadar menyerah/keluar dari pertandingan -- tidak lagi berdampak
	# apapun ke mode iblis (itu sekarang murni soal performa di lapangan).
	get_tree().change_scene_to_file("res://scenes/LocalMenu.tscn")

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
