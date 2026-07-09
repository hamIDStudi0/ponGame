extends RefCounted
class_name MLQuotes
## Kutipan/fakta singkat seputar Reinforcement Learning & Q-learning,
## ditampilkan acak selama fase pelatihan serius supaya training terasa
## edukatif, bukan cuma bar loading kosong.

const QUOTES := [
	"Q-Learning menyimpan nilai Q(s,a): perkiraan seberapa bagus sebuah aksi 'a' diambil pada kondisi 's'.",
	"Reward (hadiah) memberi sinyal positif saat AI melakukan hal yang benar, memperkuat perilaku itu.",
	"Punishment (hukuman) berupa nilai negatif membuat AI menghindari mengulangi kesalahan yang sama.",
	"Epsilon-greedy adalah strategi menyeimbangkan eksplorasi (coba hal baru) dan eksploitasi (pakai yang sudah terbukti bagus).",
	"Semakin banyak episode dilalui, nilai epsilon menurun -- AI berangsur berhenti coba-coba dan mulai percaya diri.",
	"Learning rate (alpha) menentukan seberapa besar satu pengalaman baru mengubah keyakinan lama AI.",
	"Discount factor (gamma) membuat AI mempertimbangkan reward masa depan, bukan cuma untung sesaat.",
	"Persamaan Bellman adalah inti Q-learning: nilai suatu aksi = reward sekarang + estimasi reward terbaik di masa depan.",
	"Q-learning disebut 'model-free' karena AI tidak perlu tahu rumus fisika bola -- ia belajar murni dari coba-coba.",
	"Setiap rally yang berakhir dianggap satu episode; AI memperbarui tabelnya setelah tahu hasilnya menang atau kalah.",
	"Tabel Q bisa disimpan ke disk, sehingga pembelajaran AI ini bersifat permanen, bukan direset tiap kali dibuka.",
	"Semakin sering suatu kondisi ditemui, semakin akurat estimasi Q-value pada kondisi tersebut.",
	"AI ini tidak dihardcode untuk menang -- ia menemukan strategi terbaiknya sendiri lewat jutaan iterasi kecil.",
	"Temporal-Difference learning memperbarui perkiraan nilai tanpa harus menunggu keseluruhan permainan selesai.",
]

static func random_quote() -> String:
	return QUOTES[randi() % QUOTES.size()]
