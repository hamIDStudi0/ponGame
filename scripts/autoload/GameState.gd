extends Node
## GameState (Autoload)
## Menyimpan state runtime (bukan disk) seperti mode pong yang dipilih.

enum PongMode { CLASSIC, TWICE, GRAVITY, ANIME, BREAKER }

var selected_mode: int = PongMode.CLASSIC
var score_target: int = -1  # -1 artinya infinity / tidak ada batas, main terus sampai keluar

const SCENE_MAP := {
	PongMode.CLASSIC: "res://scenes/pong/PongClassic.tscn",
	PongMode.TWICE: "res://scenes/pong/PongTwice.tscn",
	PongMode.GRAVITY: "res://scenes/pong/PongGravity.tscn",
	PongMode.ANIME: "res://scenes/pong/PongAnime.tscn",
	PongMode.BREAKER: "res://scenes/pong/PongBreaker.tscn",
}

func get_scene_path_for_mode(mode: int) -> String:
	return SCENE_MAP.get(mode, SCENE_MAP[PongMode.CLASSIC])
