extends Node
## QLearning (Autoload)
## ==========================================================================
## Ini BUKAN simulasi/cerita -- ini implementasi Reinforcement Learning asli
## berbasis Q-Table (tabular Q-learning), dengan reward (hadiah) & punishment
## (hukuman) sungguhan, yang dipakai untuk menggerakkan paddle kiri di mode
## "Lawan AI" dan "Latihan AI".
##
## Cara kerja singkat (biar jelas ini bukan cuma story):
##   1. Kondisi permainan saat ini diringkas jadi sebuah "state" (string key).
##   2. Q-table menyimpan nilai Q(s,a) = perkiraan "seberapa bagus" aksi a
##      dilakukan di state s. Awalnya semua 0 (AI belum tahu apa-apa).
##   3. Setiap tick, AI pilih aksi lewat epsilon-greedy:
##        - dengan peluang epsilon -> aksi acak (eksplorasi / coba-coba)
##        - selainnya -> aksi dengan Q tertinggi (eksploitasi / pakai yang sudah dipelajari)
##   4. Setelah aksi dijalankan, ia dapat reward (pantulkan bola = hadiah kecil,
##      cetak poin = hadiah besar) atau punishment (kebobolan = hukuman/nilai negatif).
##   5. Q-value diupdate pakai rumus Bellman (Temporal-Difference learning):
##        Q(s,a) <- Q(s,a) + alpha * ( reward + gamma * max(Q(s', .)) - Q(s,a) )
##   6. epsilon perlahan menurun tiap episode (rally) -> AI makin percaya diri
##      pada apa yang sudah dipelajari, makin jarang coba-coba random.
##   7. Q-table disimpan ke disk (user://qtable_save.json) sehingga progres
##      belajarnya PERSISTEN -- AI tetap "ingat" walau game ditutup & dibuka lagi.

signal stats_updated

const SAVE_PATH := "user://qtable_save.json"

const ACTION_UP := 0
const ACTION_DOWN := 1
const ACTION_STAY := 2
const ACTION_COUNT := 3

## --- Hyperparameter RL (silakan dieksperimenkan) ---
var alpha: float = 0.18          # learning rate -- seberapa besar tiap update mengubah Q-value
var gamma: float = 0.90          # discount factor -- seberapa penting reward masa depan
var epsilon: float = 0.9         # peluang eksplorasi (acak) di awal, akan menurun
var epsilon_min: float = 0.04
var epsilon_decay: float = 0.985 # dikalikan tiap episode (rally) selesai

## --- Statistik belajar (buat ditampilkan di UI training) ---
var episodes: int = 0
var wins: int = 0
var losses: int = 0
var total_reward: float = 0.0
var _recent_results: Array = [] # rolling window menang(true)/kalah(false) untuk winrate
const RECENT_WINDOW := 25

## --- Mode "iblis": dipicu saat player menekan tombol Menyerah.
## AI berhenti bereksplorasi (full-exploit dari kebijakan terbaik yang sudah
## dipelajari) dan dianggap sudah "menguasai" permainan sepenuhnya.
var devil_mode: bool = false

var q_table: Dictionary = {} # state_key(String) -> Array[float] ukuran ACTION_COUNT

func _ready() -> void:
	load_table()

## Mengambil (atau membuat baru kalau belum ada) baris Q untuk sebuah state.
func _row(state: String) -> Array:
	if not q_table.has(state):
		q_table[state] = [0.0, 0.0, 0.0]
	return q_table[state]

## Pilih aksi dengan strategi epsilon-greedy. Kembalikan ACTION_UP/DOWN/STAY.
func choose_action(state: String) -> int:
	var row: Array = _row(state)
	var explore_chance := 0.0 if devil_mode else epsilon
	if randf() < explore_chance:
		return randi() % ACTION_COUNT
	# eksploitasi: pilih aksi dengan Q-value tertinggi (kalau seri, pilih acak di antara yang seri)
	var best_val: float = row.max()
	var best_actions: Array = []
	for a in range(ACTION_COUNT):
		if is_equal_approx(row[a], best_val):
			best_actions.append(a)
	return best_actions[randi() % best_actions.size()]

## Update Q-table pakai rumus Bellman/TD-learning. Ini jantung dari "belajar"-nya.
func learn(state: String, action: int, reward: float, next_state: String) -> void:
	var row: Array = _row(state)
	var next_row: Array = _row(next_state)
	var best_next: float = next_row.max()
	var td_target := reward + gamma * best_next
	var td_error := td_target - row[action]
	row[action] += alpha * td_error
	total_reward += reward

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

func recent_win_rate() -> float:
	if _recent_results.is_empty():
		return 0.0
	var w := 0
	for r in _recent_results:
		if r:
			w += 1
	return float(w) / float(_recent_results.size())

## AI dianggap "sudah pintar" kalau sudah cukup banyak episode DAN winrate
## belakangan cukup tinggi. Dipakai training scene buat tahu kapan berhenti.
func is_smart_enough() -> bool:
	return episodes >= 60 and recent_win_rate() >= 0.55

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
		"table_size": q_table.size(),
		"smart": is_smart_enough(),
		"devil_mode": devil_mode,
	}

## Reset total (kalau user ingin AI belajar dari nol lagi).
func reset_learning() -> void:
	q_table.clear()
	episodes = 0
	wins = 0
	losses = 0
	total_reward = 0.0
	_recent_results.clear()
	epsilon = 0.9
	devil_mode = false
	save_table()

func save_table() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	var payload := {
		"q_table": q_table,
		"epsilon": epsilon,
		"episodes": episodes,
		"wins": wins,
		"losses": losses,
		"total_reward": total_reward,
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
	q_table = parsed.get("q_table", {})
	epsilon = parsed.get("epsilon", epsilon)
	episodes = parsed.get("episodes", 0)
	wins = parsed.get("wins", 0)
	losses = parsed.get("losses", 0)
	total_reward = parsed.get("total_reward", 0.0)
	_recent_results = parsed.get("recent_results", [])
