extends Node
## QLearning (Autoload)
## ==========================================================================
## Ini BUKAN simulasi/cerita -- ini implementasi Reinforcement Learning ASLI
## berbasis DQN mini (Deep Q-Network), dengan reward (hadiah) & punishment
## (hukuman) sungguhan, dipakai untuk menggerakkan paddle kiri di mode
## "Lawan AI" dan "Latihan AI".
##
## KENAPA DQN, BUKAN Q-TABLE LAGI?
## Q-table lama menyimpan Q(s,a) per kombinasi state DISKRIT (bucket) di
## dictionary -- makin detail state-nya (posisi, kecepatan, prediksi
## pantulan), makin banyak baris tabel dibutuhkan & makin lambat
## generalisasinya. DQN menggantikan tabel itu dengan jaringan saraf kecil
## (Multi-Layer Perceptron) yang memetakan state KONTINYU (angka desimal,
## bukan bucket) langsung ke 3 nilai Q -- sehingga AI bisa menggeneralisasi
## ke posisi/kecepatan yang belum pernah persis ia temui, dengan memori
## jauh lebih hemat.
##
## DIRANCANG EFISIEN UNTUK HP RAM 4GB / LOW-END:
##   - Jaringan SANGAT kecil: 6 input -> 12 hidden -> 3 output (~120 bobot
##     total, cuma beberapa KB). Forward-pass hanya puluhan perkalian.
##   - Replay buffer (memori pengalaman) dibatasi maks 2000 transisi, lama
##     dibuang otomatis (circular buffer) -- tidak pernah membengkak.
##   - Mini-batch training (16 sample) HANYA dijalankan tiap beberapa tick
##     fisika (TRAIN_EVERY), bukan tiap frame, supaya hemat CPU.
##   - Target network (salinan bobot yang disinkron berkala) dipakai biar
##     belajarnya stabil (tidak "mengejar target yang terus bergerak"),
##     ala DQN klasik (Mnih dkk., 2015) -- tapi versi mini.
##
## CARA KERJA SINGKAT:
##   1. Kondisi permainan diringkas jadi vektor angka (state), termasuk
##      posisi relatif bola, arah mendekat/tidaknya, KECEPATAN bola
##      (prinsip akselerasi), dan PREDIKSI titik pantulan bola nanti
##      (prinsip posisi pantulan, dihitung di AIPaddleBrain).
##   2. Jaringan menghasilkan 3 nilai Q (untuk aksi NAIK/TURUN/DIAM).
##   3. epsilon-greedy: kadang eksplorasi (acak), kadang pakai Q tertinggi.
##   4. Reward (pantulkan bola / cetak poin) atau punishment (kebobolan)
##      disimpan sebagai "pengalaman" (state, aksi, reward, next_state) ke
##      replay buffer -- inilah yang membuat AI "belajar dari kesalahan":
##      kesalahan lama tetap ada di memori dan terus dipakai untuk latihan
##      ulang (experience replay), bukan cuma dipakai sekali lalu dibuang.
##   5. Tiap beberapa tick, ambil sample acak dari buffer & lakukan satu
##      langkah gradient descent (backpropagation manual) memakai rumus
##      Bellman: target = reward + gamma * max(Q_target(next_state)).
##   6. Bobot jaringan disimpan ke disk (user://dqn_save.json) sehingga
##      progres belajarnya PERSISTEN antar sesi.

signal stats_updated

const SAVE_PATH := "user://dqn_save.json"

const ACTION_UP := 0
const ACTION_DOWN := 1
const ACTION_STAY := 2
const ACTION_COUNT := 3

## --- Arsitektur jaringan (SENGAJA kecil biar ringan di HP low-end) ---
const INPUT_SIZE := 6
const HIDDEN_SIZE := 12
const OUTPUT_SIZE := ACTION_COUNT

## --- Hyperparameter RL ---
var alpha: float = 0.05          # learning rate jaringan (lebih kecil dari Q-table karena ini gradient descent)
var gamma: float = 0.90          # discount factor -- seberapa penting reward masa depan
var epsilon: float = 0.9         # peluang eksplorasi (acak) di awal, akan menurun
var epsilon_min: float = 0.04
var epsilon_decay: float = 0.985 # dikalikan tiap episode (rally) selesai

## --- Replay buffer (memori pengalaman / "kesalahan & keberhasilan masa lalu") ---
const BUFFER_CAPACITY := 2000
const BATCH_SIZE := 16
const TRAIN_EVERY := 4        # cuma latihan tiap N kali learn() dipanggil -- hemat CPU
const TARGET_SYNC_EVERY := 300 # tiap N langkah training, target network disinkron ulang

var _buffer: Array = [] # Array[Dictionary]: {s, a, r, s2, done}
var _buffer_head: int = 0
var _learn_calls: int = 0
var _train_steps: int = 0

## --- Bobot jaringan utama (dipakai untuk memilih aksi & terus dilatih) ---
var _w1: PackedFloat32Array
var _b1: PackedFloat32Array
var _w2: PackedFloat32Array
var _b2: PackedFloat32Array

## --- Target network: salinan bobot "beku" yang disinkron berkala, dipakai ---
## --- cuma untuk menghitung target Bellman supaya training stabil (trik DQN klasik). ---
var _tw1: PackedFloat32Array
var _tb1: PackedFloat32Array
var _tw2: PackedFloat32Array
var _tb2: PackedFloat32Array

## --- Statistik belajar (buat ditampilkan di UI training) ---
var episodes: int = 0
var wins: int = 0
var losses: int = 0
var total_reward: float = 0.0
var total_training_seconds: float = 0.0 # akumulasi waktu latihan NYATA (real-time, tidak kena speed-up)
var _recent_results: Array = [] # rolling window menang(true)/kalah(false) untuk winrate
const RECENT_WINDOW := 25

## Target "matang": disarankan minimal 4 jam latihan biar AI benar-benar
## sepintar mungkin (belajar dari banyak kesalahan berulang lewat replay buffer).
const MATURE_TRAINING_SECONDS := 4.0 * 3600.0

## --- Mode "iblis": AI berhenti bereksplorasi (full-exploit) & jadi lebih
## --- cepat/tajam. Sekarang dipicu oleh performa dalam pertandingan
## --- (rally panjang / kemenangan beruntun), BUKAN tombol menyerah -- lihat
## --- PongVsAI.gd untuk logika pemicunya.
var devil_mode: bool = false

func _ready() -> void:
	randomize()
	_init_weights()
	load_table()

## ---------------------------------------------------------------------
## Inisialisasi bobot (Xavier-ish: kecil & seimbang biar training stabil
## dari awal, tidak meledak/hilang gradiennya).
## ---------------------------------------------------------------------
func _init_weights() -> void:
	_w1 = _rand_weights(INPUT_SIZE * HIDDEN_SIZE, INPUT_SIZE)
	_b1 = PackedFloat32Array()
	_b1.resize(HIDDEN_SIZE)
	_w2 = _rand_weights(HIDDEN_SIZE * OUTPUT_SIZE, HIDDEN_SIZE)
	_b2 = PackedFloat32Array()
	_b2.resize(OUTPUT_SIZE)
	_sync_target_network()

func _rand_weights(count: int, fan_in: int) -> PackedFloat32Array:
	var limit := 1.0 / sqrt(float(max(fan_in, 1)))
	var arr := PackedFloat32Array()
	arr.resize(count)
	for i in range(count):
		arr[i] = randf_range(-limit, limit)
	return arr

func _sync_target_network() -> void:
	_tw1 = _w1.duplicate()
	_tb1 = _b1.duplicate()
	_tw2 = _w2.duplicate()
	_tb2 = _b2.duplicate()

## ---------------------------------------------------------------------
## Forward pass (hitung Q-values dari sebuah state). use_target=true kalau
## mau memakai target network (dipakai internal saat menghitung target Bellman).
## Mengembalikan Dictionary berisi hidden_pre/hidden/output supaya backprop
## bisa dipakai lagi tanpa hitung ulang (efisien).
## ---------------------------------------------------------------------
func _forward(state: Array, use_target: bool = false) -> Dictionary:
	var w1 := _tw1 if use_target else _w1
	var b1 := _tb1 if use_target else _b1
	var w2 := _tw2 if use_target else _w2
	var b2 := _tb2 if use_target else _b2

	var hidden_pre := PackedFloat32Array()
	hidden_pre.resize(HIDDEN_SIZE)
	var hidden := PackedFloat32Array()
	hidden.resize(HIDDEN_SIZE)
	for j in range(HIDDEN_SIZE):
		var sum: float = b1[j]
		for i in range(INPUT_SIZE):
			sum += float(state[i]) * w1[i * HIDDEN_SIZE + j]
		hidden_pre[j] = sum
		hidden[j] = max(0.0, sum) # ReLU

	var output := PackedFloat32Array()
	output.resize(OUTPUT_SIZE)
	for k in range(OUTPUT_SIZE):
		var sum2: float = b2[k]
		for j in range(HIDDEN_SIZE):
			sum2 += hidden[j] * w2[j * OUTPUT_SIZE + k]
		output[k] = sum2

	return {"hidden_pre": hidden_pre, "hidden": hidden, "output": output}

## Pilih aksi dengan strategi epsilon-greedy berdasarkan state (Array angka).
func choose_action(state: Array) -> int:
	var explore_chance := 0.0 if devil_mode else epsilon
	if randf() < explore_chance:
		return randi() % ACTION_COUNT
	var out: PackedFloat32Array = _forward(state)["output"]
	var best_idx := 0
	var best_val: float = out[0]
	for a in range(1, ACTION_COUNT):
		if out[a] > best_val:
			best_val = out[a]
			best_idx = a
	return best_idx

## Menyimpan satu pengalaman (state, aksi, reward, next_state) ke replay
## buffer -- inilah "ingatan atas kesalahan/keberhasilan" AI -- lalu memicu
## satu langkah training mini-batch tiap TRAIN_EVERY panggilan (efisien,
## tidak setiap tick fisika supaya hemat CPU di HP low-end).
func learn(state: Array, action: int, reward: float, next_state: Array, done: bool = false) -> void:
	_push_experience(state, action, reward, next_state, done)
	total_reward += reward
	_learn_calls += 1
	if _learn_calls % TRAIN_EVERY == 0:
		_train_batch()

func _push_experience(state: Array, action: int, reward: float, next_state: Array, done: bool) -> void:
	var exp := {"s": state.duplicate(), "a": action, "r": reward, "s2": next_state.duplicate(), "done": done}
	if _buffer.size() < BUFFER_CAPACITY:
		_buffer.append(exp)
	else:
		# circular buffer: timpa yang paling lama secara berurutan, O(1), tidak pernah membengkak
		_buffer[_buffer_head] = exp
		_buffer_head = (_buffer_head + 1) % BUFFER_CAPACITY

## Satu langkah mini-batch gradient descent (backpropagation manual, tanpa
## library eksternal -- jaringan cukup kecil sehingga ini murah secara CPU).
func _train_batch() -> void:
	if _buffer.size() < 8:
		return
	var batch_n: int = min(BATCH_SIZE, _buffer.size())

	# Akumulator gradien (rata-rata di seluruh batch sebelum diterapkan).
	var g_w1 := PackedFloat32Array(); g_w1.resize(_w1.size())
	var g_b1 := PackedFloat32Array(); g_b1.resize(_b1.size())
	var g_w2 := PackedFloat32Array(); g_w2.resize(_w2.size())
	var g_b2 := PackedFloat32Array(); g_b2.resize(_b2.size())

	for _n in range(batch_n):
		var exp: Dictionary = _buffer[randi() % _buffer.size()]
		var fwd := _forward(exp["s"])
		var hidden: PackedFloat32Array = fwd["hidden"]
		var hidden_pre: PackedFloat32Array = fwd["hidden_pre"]
		var output: PackedFloat32Array = fwd["output"]

		var next_max: float = 0.0
		if not exp["done"]:
			var next_out: PackedFloat32Array = _forward(exp["s2"], true)["output"] # target network -> stabil
			next_max = next_out[0]
			for a in range(1, ACTION_COUNT):
				next_max = max(next_max, next_out[a])
		var target: float = exp["r"] + (0.0 if exp["done"] else gamma * next_max)

		var action: int = exp["a"]
		var td_error: float = output[action] - target
		td_error = clamp(td_error, -5.0, 5.0) # gradient clipping -- backprop manual, jaga stabilitas

		# --- Backprop lapisan output (hanya neuron `action` yang punya error) ---
		for j in range(HIDDEN_SIZE):
			g_w2[j * OUTPUT_SIZE + action] += hidden[j] * td_error
		g_b2[action] += td_error

		# --- Backprop ke hidden layer (lewat turunan ReLU) ---
		for j in range(HIDDEN_SIZE):
			if hidden_pre[j] <= 0.0:
				continue # turunan ReLU = 0 untuk pre-aktivasi negatif
			var d_h: float = _w2[j * OUTPUT_SIZE + action] * td_error
			for i in range(INPUT_SIZE):
				g_w1[i * HIDDEN_SIZE + j] += float(exp["s"][i]) * d_h
			g_b1[j] += d_h

	# --- Terapkan gradient descent (rata-rata batch) ---
	var lr := alpha / float(batch_n)
	for i in range(_w1.size()):
		_w1[i] -= lr * g_w1[i]
	for i in range(_b1.size()):
		_b1[i] -= lr * g_b1[i]
	for i in range(_w2.size()):
		_w2[i] -= lr * g_w2[i]
	for i in range(_b2.size()):
		_b2[i] -= lr * g_b2[i]

	_train_steps += 1
	if _train_steps % TARGET_SYNC_EVERY == 0:
		_sync_target_network()

## Dipanggil tiap satu rally/poin selesai (1 "episode" RL).
## won = true kalau AI yang mencetak poin, false kalau AI kebobolan.
func end_episode(won: bool) -> void:
	episodes += 1
	if won:
		wins += 1
	else:
		losses += 1
	_recent_results.append(won)
	if _recent_results.size() > RECENT_WINDOW:
		_recent_results.pop_front()
	if not devil_mode:
		epsilon = max(epsilon_min, epsilon * epsilon_decay)
	stats_updated.emit()
	save_table()

## Ditambahkan tiap frame dari scene training/pertandingan pakai waktu NYATA
## (bukan delta yang sudah dikali Engine.time_scale) supaya progress "menuju
## 4 jam latihan" jujur mencerminkan waktu asli, walau simulasi dipercepat.
func tick_training_time(real_delta_seconds: float) -> void:
	total_training_seconds += real_delta_seconds

func is_mature() -> bool:
	return total_training_seconds >= MATURE_TRAINING_SECONDS

func training_progress_ratio() -> float:
	return clamp(total_training_seconds / MATURE_TRAINING_SECONDS, 0.0, 1.0)

func recent_win_rate() -> float:
	if _recent_results.is_empty():
		return 0.0
	var w := 0
	for r in _recent_results:
		if r:
			w += 1
	return float(w) / float(_recent_results.size())

## AI dianggap "sudah cukup pintar untuk bertanding" kalau sudah cukup
## banyak episode DAN winrate belakangan cukup tinggi. (Ini gerbang minimal
## supaya sesi training tidak wajib menunggu 4 jam penuh sebelum bisa main --
## progres menuju "matang" 4 jam tetap terus terakumulasi & ditampilkan terpisah.)
func is_smart_enough() -> bool:
	return episodes >= 80 and recent_win_rate() >= 0.55

func set_devil_mode(active: bool) -> void:
	devil_mode = active
	if active:
		epsilon = 0.0 # tidak ada lagi coba-coba, murni pakai kebijakan terbaik yang sudah dipelajari

func get_stats() -> Dictionary:
	return {
		"episodes": episodes,
		"wins": wins,
		"losses": losses,
		"epsilon": epsilon,
		"win_rate": recent_win_rate(),
		"table_size": _buffer.size(), # nama field dipertahankan demi kompatibilitas UI lama = ukuran replay buffer
		"smart": is_smart_enough(),
		"devil_mode": devil_mode,
		"training_seconds": total_training_seconds,
		"training_progress": training_progress_ratio(),
		"mature": is_mature(),
	}

## Reset total (kalau user ingin AI belajar dari nol lagi).
func reset_learning() -> void:
	_buffer.clear()
	_buffer_head = 0
	_learn_calls = 0
	_train_steps = 0
	_init_weights()
	episodes = 0
	wins = 0
	losses = 0
	total_reward = 0.0
	total_training_seconds = 0.0
	_recent_results.clear()
	epsilon = 0.9
	devil_mode = false
	save_table()

## Hanya bobot jaringan (kecil, beberapa KB) + statistik yang disimpan --
## replay buffer SENGAJA tidak disimpan ke disk (akan terisi ulang otomatis
## selama bermain) supaya file save tetap kecil & hemat, cocok untuk HP low-end.
func save_table() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	var payload := {
		"w1": Array(_w1), "b1": Array(_b1), "w2": Array(_w2), "b2": Array(_b2),
		"epsilon": epsilon,
		"episodes": episodes,
		"wins": wins,
		"losses": losses,
		"total_reward": total_reward,
		"total_training_seconds": total_training_seconds,
		"recent_results": _recent_results,
	}
	f.store_string(JSON.stringify(payload))
	f.close()

func load_table() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	if parsed.has("w1") and parsed.has("w2"):
		_w1 = PackedFloat32Array(parsed["w1"])
		_b1 = PackedFloat32Array(parsed["b1"])
		_w2 = PackedFloat32Array(parsed["w2"])
		_b2 = PackedFloat32Array(parsed["b2"])
		_sync_target_network()
	epsilon = parsed.get("epsilon", epsilon)
	episodes = parsed.get("episodes", 0)
	wins = parsed.get("wins", 0)
	losses = parsed.get("losses", 0)
	total_reward = parsed.get("total_reward", 0.0)
	total_training_seconds = parsed.get("total_training_seconds", 0.0)
	_recent_results = parsed.get("recent_results", [])
