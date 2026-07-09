# ponGame — Tutorial Lengkap (hamIDStudio)

Game Pong pixel-art dengan story mode tentang Machine Learning/AI, dibangun di
**Godot 4.3**, ditulis dalam **GDScript**, dan di-build otomatis jadi APK Android
lewat **GitHub Actions**.

---

## 1. Isi folder ini

```
ponGame/
├── project.godot              # konfigurasi project + input map (p1_up/p1_down/p2_up/p2_down)
├── export_presets.cfg         # preset export Android, dipakai CI
├── icon.svg                   # placeholder icon, ganti dengan pixel art asli
├── scenes/
│   ├── Loading.tscn           # loading screen "hamIDStudio"
│   ├── MainMenu.tscn          # Story / Local / About
│   ├── About.tscn
│   ├── Story.tscn             # scene story mode
│   ├── LocalMenu.tscn         # pilih varian pong 2P
│   └── pong/
│       ├── PongClassic.tscn
│       ├── PongTwice.tscn
│       ├── PongGravity.tscn
│       ├── PongAnime.tscn
│       └── PongBreaker.tscn
├── scripts/
│   ├── autoload/
│   │   ├── SaveManager.gd     # simpan progress story ke user://save.json (persisten)
│   │   └── GameState.gd       # state runtime (mode yang dipilih dll)
│   ├── story/
│   │   ├── StoryData.gd       # semua baris dialog + tag event visual
│   │   └── DialogueSystem.gd  # kotak dialog dengan efek mengetik (typewriter)
│   ├── pong/
│   │   ├── PaddleScript.gd    # gerak paddle: keyboard (WS/panah) + touch drag (Android) + AI (player_id=0)
│   │   ├── BallScript.gd      # fisika bola, pantulan, skor, motion blur
│   │   ├── SparringBot.gd     # bot heuristik (BUKAN ML) lawan latihan AI
│   │   ├── PongBase.gd        # logika dasar bersama semua varian
│   │   ├── PongVsAI.gd        # mode Lawan AI (Q-learning asli) + tombol Menyerah/iblis
│   │   ├── PongClassic.gd
│   │   ├── PongTwice.gd
│   │   ├── PongGravity.gd
│   │   ├── PongAnime.gd
│   │   └── PongBreaker.gd
│   ├── ai/
│   │   ├── QLearning.gd       # AUTOLOAD -- Q-table asli, reward/punishment, persisten
│   │   ├── AIPaddleBrain.gd   # jembatan state bola/paddle <-> QLearning
│   │   ├── MLQuotes.gd        # kutipan edukasi ML utk fase latihan
│   │   ├── MotionBlurUtil.gd  # afterimage trail motion blur
│   │   └── MotionGhost.gd
│   ├── Loading.gd / MainMenu.gd / About.gd / LocalMenu.gd / Story.gd / Training.gd
└── .github/workflows/build.yml   # CI: build APK Android tiap push ke `main`
```

## 1.1 Sistem Machine Learning (Q-Learning asli, bukan cuma story)

Sebelumnya paddle "AI" 100% dikendalikan keyboard `p1_up/p1_down` -- tidak ada
pembelajaran sungguhan. Sekarang ada implementasi **tabular Q-learning**
sungguhan di `scripts/ai/QLearning.gd` (autoload):

- **State**: posisi bola relatif ke paddle, arah bola mendekat/menjauh, arah
  vertikal bola, jarak horizontal -- diringkas jadi satu string key.
- **Aksi**: naik / turun / diam.
- **Reward (hadiah)**: +3 saat berhasil memantulkan bola, +5 saat mencetak poin.
- **Punishment (hukuman)**: -5 saat kebobolan, plus hukuman kecil tiap tick
  kalau posisi paddle jauh dari lintasan bola yang sedang mendekat.
- **Epsilon-greedy**: AI mulai dengan banyak eksplorasi (aksi acak), lalu
  epsilon menurun tiap rally selesai sehingga AI makin mengandalkan strategi
  yang sudah terbukti bagus.
- **Persisten**: Q-table disimpan ke `user://qtable_save.json`, jadi progres
  belajar AI tidak hilang walau game ditutup.

**Menu baru** di Main Menu:
- `LATIH AI (ML)` -> `Training.tscn`: pertandingan dipercepat (`Engine.time_scale`)
  melawan `SparringBot` (bot heuristik sederhana, BUKAN ML, cuma sparring
  partner), sambil menampilkan kutipan edukasi Q-learning acak dan progress
  bar menuju "cukup pintar" (winrate & jumlah episode).
- `LAWAN AI` -> `PongVsAI.tscn`: main melawan AI yang sudah/masih belajar
  (online learning tetap jalan walau lawan manusia asli). Ada tombol
  **Menyerah** -- kalau ditekan, `QLearning.set_devil_mode(true)` diaktifkan
  (epsilon = 0, AI full-exploit kebijakan terbaiknya + lebih cepat), disertai
  efek visual: overlay merah gelap, layar berguncang, paddel AI berubah warna,
  dan teks "diretas" yang bergletch sebelum menampilkan kalimat final ala iblis data.

## 1.2 Cara reset pembelajaran AI (kalau ingin mulai dari nol)

Panggil `QLearning.reset_learning()` (misalnya dari tombol debug), atau hapus
file `user://qtable_save.json` di folder data Godot.



## 2. Cara membuka & menjalankan di komputer

1. Install **Godot 4.3** (Standard, bukan .NET) dari https://godotengine.org/download
2. Buka Godot → **Import** → pilih file `project.godot` di folder ini.
3. Tekan **F5** (Run) — scene pertama otomatis `Loading.tscn`.
4. Kontrol default (testing di PC):
   - Paddle kiri (AI/P1): `W` / `S`
   - Paddle kanan (Player/P2): `↑` / `↓`
   - Di Android: sentuh & geser di sisi layar masing-masing.

## 3. Alur permainan (sudah diimplementasikan)

- **Loading** → tampil "hamIDStudio" dengan progress bar pixel, fade ke Main Menu.
- **Main Menu** → tombol *Story*, *Local*, *About*. Tombol Story otomatis berubah
  jadi "LANJUTKAN STORY" kalau progress lama masih ada.
- **Story** → dialog mengetik huruf-per-huruf, kamera berpindah fokus (AI → player →
  wide), lingkaran biru masuk ke paddle, spawn "file data" bernomor (data_00000001,
  dst) yang lama-lama membentuk jaringan node terhubung, efek "roh" opacity rendah
  saat AI jadi kuat, lalu overlay merah gelap + AI mengambil alih dialog.
  **Progress disimpan otomatis setiap baris** ke `user://save.json`, jadi story
  TIDAK reset walau aplikasi ditutup.
- **Local (2P)** → 5 varian sesuai desain:
  - `classic` — pong standar.
  - `twice` — dua bola aktif sekaligus, kedua sisi selalu punya bola.
  - `gravity` — magnet di tengah menarik bola; kalau bola "tertelan" saat baru
    dipantulkan salah satu paddle, paddle itu kehilangan 1 poin.
  - `anime` — pukul di pinggir paddle = efek ayunan tongkat + bola melesat tajam;
    pukul di tengah = efek trampolin + bola meluncur lurus full power.
  - `breaker` — dibalik: menyentuh bola = poin lawan bertambah (menghindar, bukan
    memantulkan). Bola memantul di semua sisi lapangan.
  - Semua mode default main sampai **infinity** (`GameState.score_target = -1`).
    Ubah nilai itu di `LocalMenu.gd` kalau mau ada target poin tertentu.
- **About** → "hamIDStudio mempersembahkan ponGame".

## 4. Yang masih placeholder / perlu kamu perbaiki

Karena saya tidak bisa menggambar aset pixel-art asli dari sini, semua visual
sekarang pakai `ColorRect` (kotak warna polos) sebagai penanda posisi & ukuran:

- Ganti node `Sprite` di tiap paddle/ball dengan `AnimatedSprite2D` + spritesheet
  pixel-art kamu (16x16 / 32x32, import filter **Nearest** biar tetap tajam).
- Tambahkan `CPUParticles2D` untuk percikan saat bola memantul.
- Tambahkan `AudioStreamPlayer` untuk SFX pukulan/gol dan musik latar.
- Untuk shader cahaya/shadow: buat `CanvasModulate` + `Light2D` dengan texture
  pixel-art custom, atau shader `.gdshader` sederhana (bloom/glow) di `CorruptOverlay`
  dan `AISpirit` supaya efeknya lebih hidup.
- `icon.svg` ganti dengan icon pixel asli.
- Pivot `ColorRect` di `PongAnime.gd` ada di kiri-atas; set `pivot_offset` ke
  tengah sprite supaya rotasi/scale animasi kelihatan natural.

Semua bagian logika (skor, fisika, save system, alur cerita) sudah jalan penuh —
yang perlu ditambah hanya lapisan visual/audio di atasnya.

## 5. Build otomatis lewat GitHub Actions

File `.github/workflows/build.yml` akan:
1. Download Godot 4.3 headless + export templates.
2. Setup Android SDK & Java 17.
3. Generate debug keystore otomatis (jadi tidak perlu setup manual untuk APK debug).
4. Export APK debug ke `build/android/ponGame-debug.apk`.
5. Upload APK sebagai **artifact** — bisa didownload dari tab **Actions** di repo
   GitHub setelah workflow selesai (klik run terakhir → bagian *Artifacts*).

### Cara pakai:
1. Buat repo GitHub baru, push seluruh folder `ponGame/` ke branch `main`.
2. Buka tab **Actions** di repo → workflow "Build ponGame Android APK" otomatis
   jalan tiap kali kamu push.
3. Tunggu sampai selesai (±5-10 menit), lalu download APK dari artifact.
4. Install APK di HP Android (aktifkan "Install dari sumber tidak dikenal" dulu).

### Untuk build **release** (bukan debug) nanti:
- Buat keystore release sendiri (`keytool -genkey ...`).
- Simpan keystore & password sebagai **GitHub Secrets** (jangan taruh di repo).
- Tambahkan step di `build.yml` untuk decode secret jadi file keystore, lalu
  ganti `--export-debug` jadi `--export-release` dan update `export_presets.cfg`
  bagian `keystore/release`.

## 6. Menambah / mengedit cerita

Semua baris dialog ada di `scripts/story/StoryData.gd` dalam array `LINES`.
Tiap baris punya `speaker`, `text`, dan `event` (opsional) yang memicu animasi.
Tinggal tambah/edit entri array itu — `Story.gd` otomatis menjalankan event yang
cocok lewat fungsi `_run_event()`.

## 7. Menambah varian pong baru

1. Duplikat salah satu `.tscn` di `scenes/pong/` (paling gampang copy `PongClassic.tscn`).
2. Buat script baru `extends PongBase` di `scripts/pong/`.
3. Override hook yang tersedia: `_on_ready_extra()`, `_after_goal()`, `_on_hit_paddle()`.
4. Daftarkan mode baru di enum `GameState.PongMode` dan `GameState.SCENE_MAP`.
5. Tambah tombol baru di `LocalMenu.tscn` + `LocalMenu.gd`.

---

Selamat berkarya! — dari hamIDStudio 🎮
