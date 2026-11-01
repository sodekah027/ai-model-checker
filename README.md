# AI Model Checker & Tester (`scriptai.sh`)

Script Bash interaktif yang mudah dan cepat untuk memvalidasi dan menguji daftar model AI pada endpoint OpenAI-compatible (OpenAI, OpenRouter, DeepSeek, Ollama, vLLM, LocalAI, dll).

---

## Fitur Utama

- **Otomatis Mengambil Daftar Model (`GET /models`)**: Menemukan semua model yang tersedia di provider AI Anda secara otomatis.
- **Pengujian Chat Nyata (`POST /chat/completions`)**: Mengirim pesan chat pengujian (default: `"hai"`) ke setiap model untuk memastikan model benar-benar aktif dan merespon.
- **Indikator Status & Latensi**: Menampilkan waktu respon (dalam detik) dan preview balasan AI secara real-time.
- **Deteksi Error Cerdas**: Menampilkan pesan error spesifik jika model gagal (misal: rate limit, token invalid, atau butuh `max_completion_tokens`).
- **Penyimpanan Hasil Otomatis**:
  - `model_aktif.txt`: Daftar ID model yang sukses merespon (1 baris per model, siap disalin).
  - `laporan_test_model.txt`: Laporan detail pengujian beserta durasi dan pesan balasan.
  - `riwayat_test.txt`: Riwayat **semua provider** per-run (ditambahkan, tidak ditimpa) — berisi WAKTU + BASE URL + TOKEN + daftar model yang werk. Cocok jika Anda sering mengecek banyak provider berbeda.
- **Simpan Konfigurasi Otomatis**: Menyimpan Base URL & Token secara lokal di `~/.scriptai.conf` (ditampilkan penuh di menu dan diabaikan dari Git).
- **Kompatibel Universal**: Berjalan mulus di Termux (Android), Linux (Ubuntu/Debian/Arch/CentOS), dan macOS.

---

## Persyaratan (Prerequisites)

Pastikan `curl` dan `jq` sudah terpasang.

### Di Termux:
```bash
pkg update && pkg install curl jq -y
```

### Di Ubuntu / Debian:
```bash
sudo apt update && sudo apt install curl jq -y
```

---

## Cara Penggunaan

1. Clone repository ini:
   ```bash
   git clone https://github.com/sodekah027/ai-model-checker.git
   cd ai-model-checker
   ```

2. Berikan izin eksekusi (jika belum):
   ```bash
   chmod +x scriptai.sh
   ```

3. Jalankan script:
   ```bash
   ./scriptai.sh
   ```

4. Pada menu utama:
   - Pilih **`[1]` Mulai Test Semua Model**.
   - Masukkan **Base URL** (contoh: `https://api.openai.com/v1` atau `https://openrouter.ai/api/v1`).
   - Masukkan **API Key / Token**.
   - Script akan otomatis mengecek model dan menampilkan hasil pengetesan.

---

## Pilihan Menu

```text
========================================================
        AI MODEL TESTER & CHECKER (Bash Script)         
========================================================
 Base URL  : https://api.openai.com/v1
 Token/Key : sk-proj-abcdef1234567890
 Pesan Tes : "hai"
========================================================
 [1] Mulai Test Semua Model (Auto Base URL -> Token -> Test)
 [2] Test 1 Model Tertentu (Ketik nama model manual)
 [3] Atur / Ganti Base URL
 [4] Atur / Ganti Token / API Key
 [5] Atur Pesan Chat Test (Default: "hai")
 [6] Lihat Daftar Model Saja (Tanpa Chat)
 [7] Lihat Daftar Model yang Sukses Sebelumnya
 [8] Lihat Riwayat Semua Provider (Base URL + Token + Model Work)
 [0] Keluar
========================================================
```

---

## Lisensi

Didistribusikan untuk penggunaan pribadi. Bebas dimodifikasi sesuai kebutuhan.
