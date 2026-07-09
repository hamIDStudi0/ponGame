extends Node
## SaveManager (Autoload)
## Menyimpan progress story & pengaturan game secara persisten di user://save.json
## sehingga saat game ditutup dan dibuka lagi, story TIDAK mengulang dari awal.

const SAVE_PATH := "user://save.json"

var data: Dictionary = {
	"story_index": 0,        # index baris dialog terakhir yang sudah dilihat
	"story_completed": false,
	"data_nodes_unlocked": 0, # berapa banyak "data_0000000X" yang sudah muncul
	"settings": {
		"music_volume": 0.8,
		"sfx_volume": 1.0,
		"first_launch": true
	},
	"local_highscores": {
		"classic": 0,
		"twice": 0,
		"gravity": 0,
		"anime": 0,
		"breaker": 0
	}
}

func _ready() -> void:
	load_game()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		save_game() # buat file baru dengan default
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		# merge supaya field baru di update game tidak hilang saat load save lama
		for key in parsed.keys():
			data[key] = parsed[key]

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func set_story_index(index: int) -> void:
	data["story_index"] = index
	save_game()

func get_story_index() -> int:
	return data.get("story_index", 0)

func mark_story_completed() -> void:
	data["story_completed"] = true
	save_game()

func is_story_completed() -> bool:
	return data.get("story_completed", false)

func unlock_next_data_node() -> int:
	data["data_nodes_unlocked"] += 1
	save_game()
	return data["data_nodes_unlocked"]

func set_highscore(mode: String, score: int) -> void:
	if score > int(data["local_highscores"].get(mode, 0)):
		data["local_highscores"][mode] = score
		save_game()

func reset_story_progress() -> void:
	# dipakai kalau user sengaja mau mengulang story dari menu (opsional, bukan otomatis)
	data["story_index"] = 0
	data["story_completed"] = false
	data["data_nodes_unlocked"] = 0
	save_game()
