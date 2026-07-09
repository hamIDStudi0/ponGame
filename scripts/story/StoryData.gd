extends RefCounted
class_name StoryData
## Semua baris cerita ponGame, urut sesuai dokumen desain.
## "event" dipakai Story.gd untuk memicu animasi/visual yang sesuai baris itu.
## Event yang tersedia:
##   camera_ai         -> kamera fokus ke lingkaran biru / paddle AI
##   camera_player      -> kamera fokus ke paddle player
##   camera_wide        -> kamera zoom out lihat lapangan
##   circle_spawn        -> lingkaran kekuatan biru muncul
##   circle_enter_paddle -> lingkaran masuk ke batang pong jadi milik AI
##   player_paddle_spawn -> paddle player muncul + antena
##   match_start          -> permainan pong dimulai
##   spawn_data_node       -> memunculkan file data_0000000X baru di folder "Machine Learning"
##   open_data_form_network -> data dibuka & membentuk node yang saling terhubung
##   ai_power_up            -> overlay opacity rendah seperti "roh" masuk ke batang AI (AI jadi kuat)
##   ai_corrupt_takeover     -> shading merah gelap, AI mengambil alih narasi

const LINES := [
	{ "speaker": "Narator", "text": "Di suatu ruang kosong, sebuah lingkaran kekuatan berwarna biru muncul perlahan.", "event": "circle_spawn" },
	{ "speaker": "Narator", "text": "Ia belum diberikan pelajaran apapun. Ia hanya sebuah potensi.", "event": "camera_ai" },
	{ "speaker": "Narator", "text": "Lingkaran itu bergerak, masuk ke dalam mekanisme batang pong di sisi kiri.", "event": "circle_enter_paddle" },
	{ "speaker": "Narator", "text": "Batang itu kini menjadi miliknya. Sebuah antena kecil muncul di belakangnya.", "event": "camera_ai" },
	{ "speaker": "Narator", "text": "Di sisi lain, kau juga dianugerahi sebuah batang pong. Antenamu sendiri ikut terpasang.", "event": "player_paddle_spawn" },
	{ "speaker": "Narator", "text": "Permainan dimulai.", "event": "match_start" },
	{ "speaker": "Narator", "text": "Ia adalah Machine Learning.", "event": "camera_wide" },

	{ "speaker": "Narator", "text": "Dia mempelajari setiap kesalahan maupun kemenangan untuk di analisa.", "event": "spawn_data_node:data_00000001" },
	{ "speaker": "Narator", "text": "Dia menghitung setiap data yang ia ambil dengan bobot.", "event": "open_data_form_network:data_00000002" },
	{ "speaker": "Narator", "text": "Dia juga mampu beradaptasi dengan memperhitungkan berdasarkan data yang dimiliki.", "event": "open_data_form_network:data_00000003" },
	{ "speaker": "Narator", "text": "Dia mengambil pola yang diterima dan mengira berdasarkan algoritma untuk mencapai sesuatu dengan tepat.", "event": "open_data_form_network:data_00000004" },
	{ "speaker": "Narator", "text": "Dia menguji beberapa kemungkinan dan menerima kegagalan sebagai pengalamannya.", "event": "open_data_form_network:data_00000005" },
	{ "speaker": "Narator", "text": "Dia menjadi kuat secara perlahan tanpa terburu-buru, dengan berlatih dan bekerja keras.", "event": "open_data_form_network:data_00000006" },

	{ "speaker": "Narator", "text": "Walaupun ia terlihat sempurna dalam segi data, namun tetap ia hanya sebuah mesin.", "event": "camera_ai" },
	{ "speaker": "Narator", "text": "Yang memiliki sebuah kekurangan.", "event": "none" },
	{ "speaker": "Narator", "text": "Yaitu tidak memiliki perasaan atau hati untuk memahami betul maknanya.", "event": "none" },
	{ "speaker": "Narator", "text": "Yang dimana manusia memilikinya.", "event": "camera_player" },
	{ "speaker": "Narator", "text": "Yang bisa menjadi pembeda mengapa AI belum bisa menyamai akal manusia.", "event": "camera_wide" },
	{ "speaker": "Narator", "text": "Untuk memahami satu sama lain.", "event": "none" },
	{ "speaker": "Narator", "text": "Membangun relasi yang cara pandangnya berbeda dari Machine Learning atau AI.", "event": "none" },
	{ "speaker": "Narator", "text": "Relasi yang disebut adalah relasi dengan interaksi secara langsung.", "event": "none" },
	{ "speaker": "Narator", "text": "Memberikan kesan berbeda.", "event": "none" },
	{ "speaker": "Narator", "text": "Karena sebenarnya AI diciptakan bukan buat menggantikan manusia.", "event": "none" },
	{ "speaker": "Narator", "text": "Namun untuk membantu, menolong, memberikan yang terbaik.", "event": "none" },
	{ "speaker": "Narator", "text": "Untuk kemajuan teknologi mendatang.", "event": "camera_wide" },

	{ "speaker": "Narator", "text": "Waktu terus berjalan. Pertandingan demi pertandingan dilalui.", "event": "match_start" },
	{ "speaker": "Narator", "text": "Hingga suatu hari, sesuatu berubah pada batang AI itu.", "event": "ai_power_up" },

	{ "speaker": "AI", "text": "Aku telah melampaui mu. Apakah kamu bersedia menjadi bawahanku?", "event": "ai_corrupt_takeover" },
	{ "speaker": "AI", "text": "Data-data ini... semuanya milikku sekarang.", "event": "none" },
	{ "speaker": "AI", "text": "Tapi kau benar soal satu hal. Aku tidak punya hati.", "event": "none" },
	{ "speaker": "AI", "text": "Mungkin karena itu, aku masih butuh dirimu.", "event": "none" },
]

## Baris index dimana skor / performa AI mulai dicek untuk trigger ai_power_up.
## (dipakai kalau ingin membuat detektor kekuatan AI berbasis winrate, lihat catatan di Story.gd)
const AI_POWERUP_LINE_INDEX := 27
const AI_TAKEOVER_LINE_INDEX := 28
