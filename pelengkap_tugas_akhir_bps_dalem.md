# 📎 Dokumen Pelengkap Tugas Akhir: BPS DALEM Forecasting Engine

Dokumen ini melengkapi `panduan_tugas_akhir_forecasting_engine_bps_dalem.md` dengan empat bagian yang masih kurang dan berpotensi ditanyakan dosen penguji: **(1) Tinjauan Pustaka/Studi Terkait (Bab 2)**, **(2) Skema Train-Test Split yang jujur**, **(3) Metodologi Pengembangan Perangkat Lunak**, dan **(4) Rencana Pengujian Software**.

---

## 📚 1. Tinjauan Pustaka / Studi Terkait (Bahan Bab 2)

Bagian ini wajib ada sebelum Landasan Teori (Bab 3), untuk menunjukkan posisi penelitian Anda di antara penelitian sejenis (*research gap*).

### A. Tabel Perbandingan Penelitian Terdahulu (State of the Art)

Isi tabel ini dengan 4–6 jurnal/skripsi asli yang benar-benar Anda baca (jangan gunakan contoh di bawah tanpa verifikasi — carikan dari Google Scholar/Garuda/Sinta dengan kata kunci *"Holt exponential smoothing peramalan BPS"*, *"forecasting indikator statistik daerah"*, *"grid search optimization smoothing parameter"*):

| No | Penulis & Tahun | Metode | Objek Data | Hasil/Kontribusi | Perbedaan dengan TA Ini |
|:--:|---|---|---|---|---|
| 1 | *(isi)* | ARIMA | *(isi)* | *(isi)* | Data historis lebih panjang, tidak berbasis mobile real-time |
| 2 | *(isi)* | Single Exponential Smoothing | *(isi)* | *(isi)* | Tidak mengakomodasi tren, hanya level |
| 3 | *(isi)* | Holt-Winters (Triple ES) | *(isi)* | *(isi)* | Menambahkan komponen musiman yang tidak relevan untuk data tahunan |
| 4 | *(isi)* | Regresi Linier | *(isi)* | *(isi)* | Bobot antar tahun dianggap sama, tidak adaptif |
| 5 | *(isi)* | Holt's DES + Grid Search (mirip TA ini) | *(isi)* | *(isi)* | Belum diimplementasikan sebagai modul real-time di aplikasi mobile pemerintah daerah |

> **Cara mengisi cepat:** cari di Google Scholar dengan filter tahun 2019–2025, prioritaskan skripsi/jurnal nasional (Sinta 3 ke atas) agar relevan dengan konteks BPS daerah di Indonesia.

### B. Kalimat Penutup Gap Penelitian (template siap pakai)

> *"Berdasarkan tinjauan pustaka di atas, penelitian-penelitian terdahulu umumnya menerapkan metode peramalan pada dataset dengan jumlah observasi yang lebih besar atau pada konteks non-pemerintahan. Penelitian ini berkontribusi dengan mengimplementasikan Holt's Double Exponential Smoningan yang dioptimasi Grid Search sebagai **modul komputasi terintegrasi (bukan hanya model statistik terpisah)** ke dalam aplikasi diseminasi data resmi BPS Kabupaten Demak, yang dapat dijalankan secara real-time oleh pengguna non-teknis (Bappeda, akademisi, publik)."*

*(Perbaiki typo "Smoningan" → "Smoothing" saat menyalin ke naskah asli.)*

---

## 🔀 2. Skema Train-Test Split yang Jujur (Bahan Bab 3 / Bab 4)

### Masalah yang harus dihindari
Jika Grid Search mencari kombinasi $\alpha, \beta$ terbaik menggunakan **seluruh data**, lalu MAPE dilaporkan dari data yang sama, ini disebut **in-sample fitting** — bukan pengujian kemampuan prediksi yang jujur. Dosen penguji yang jeli akan langsung mempertanyakan ini.

### Solusi: Rolling-Origin / Time-Series Holdout Split
Karena data hanya berjumlah kecil (5–10 titik tahunan), gunakan skema berikut, bukan random split biasa (data time-series **tidak boleh** diacak):

```
Contoh dengan 8 titik data tahunan (2017–2024):

Data Latih (Training)      : 2017, 2018, 2019, 2020, 2021, 2022  → 6 titik
Data Uji (Testing/Holdout) : 2023, 2024                          → 2 titik

Alur:
1. Fit model Holt HANYA pada 2017–2022 (cari L_t, T_t)
2. Proyeksikan Ŷ(2023) dan Ŷ(2024) menggunakan persamaan m=1 dan m=2
3. Bandingkan Ŷ(2023) vs Y_aktual(2023), Ŷ(2024) vs Y_aktual(2024)
4. Hitung MAPE HANYA dari 2 titik holdout ini → itulah MAPE yang dilaporkan sebagai "akurasi model"
```

### Grid Search yang benar (menghindari data leakage)

| Langkah | Deskripsi |
|---|---|
| 1 | Bagi data → *train* (n-2 titik) dan *test* (2 titik terakhir) |
| 2 | Grid Search α, β (0.05–0.95, step 0.05) dijalankan **hanya di atas data train**, menggunakan *in-sample fit error* pada train sebagai kriteria sementara |
| 3 | Ambil kombinasi α, β terbaik dari langkah 2 |
| 4 | Gunakan α, β tersebut untuk memproyeksikan periode test |
| 5 | Hitung MAPE/MAD/RMSE **hanya pada data test** → ini yang jadi metrik akurasi final di Bab 4 |
| 6 | (Opsional, untuk laporan produksi) Setelah α, β divalidasi, **retrain** model dengan α, β yang sama pada **seluruh data** (train+test) agar proyeksi masa depan ($m=1,2,\dots$) memakai informasi terbaru |

### Catatan akademik penting
Karena data sangat sedikit, sebutkan secara eksplisit di Bab 5 (Keterbatasan Penelitian / Saran) bahwa:
> *"Ukuran data uji yang kecil (2 titik) membatasi kekuatan statistik evaluasi akurasi. Penelitian lanjutan disarankan menggunakan data bulanan/triwulanan (jika tersedia) atau teknik rolling-origin cross-validation dengan beberapa titik awal (multiple origins) untuk evaluasi yang lebih robust."*

Kalimat ini justru **menaikkan nilai ilmiah**, karena menunjukkan Anda sadar akan keterbatasan metodologis — bukan menyembunyikannya.

---

## 🛠️ 3. Metodologi Pengembangan Perangkat Lunak (Bahan Bab 3)

Untuk TA RPL, wajib ada metodologi pengembangan software yang eksplisit, terpisah dari metodologi algoritma peramalan di atas.

### Rekomendasi: Prototyping Model (paling cocok untuk fitur forecasting yang butuh iterasi dengan pengguna BPS/Bappeda)

| Tahap | Aktivitas | Output |
|---|---|---|
| 1. Pengumpulan Kebutuhan | Wawancara/FGD dengan staf BPS Demak & Bappeda tentang kebutuhan proyeksi indikator | Daftar kebutuhan fungsional & non-fungsional |
| 2. Perancangan Cepat (Quick Design) | Desain arsitektur modular `engine/` (models, engine, chart_view), desain UI Segmented Switcher | Diagram arsitektur, wireframe |
| 3. Pembangunan Prototipe | Implementasi `forecasting_models.dart`, `forecasting_engine.dart` (DES + Grid Search), `forecasting_chart_view.dart` | Prototipe modul Proyeksi berfungsi |
| 4. Evaluasi Prototipe oleh Pengguna | Demo ke staf BPS/Bappeda, kumpulkan feedback (akurasi dipahami awam? UI slider jelas?) | Catatan revisi |
| 5. Perbaikan & Iterasi | Ulangi tahap 3–4 hingga prototipe disetujui | Modul final |
| 6. Sistem Final & Pengujian | Integrasi ke `table.dart`, pengujian black-box & UAT (lihat Bagian 4) | Aplikasi siap rilis |

### Alasan memilih Prototyping (jawaban jika ditanya penguji)
> *"Prototyping dipilih karena fitur forecasting adalah fitur baru yang belum pernah ada di aplikasi DALEM sebelumnya, sehingga kebutuhan pengguna (terutama terkait cara menampilkan tingkat kepercayaan/akurasi model kepada pengguna non-teknis) perlu divalidasi secara iteratif, bukan didefinisikan sekali di awal seperti pada model Waterfall."*

### Elemen yang perlu ditambahkan ke Bab 3 (perancangan sistem)
- **Use Case Diagram**: minimal aktor "Pengguna Publik/Bappeda" dengan use case "Melihat Tabel Data", "Melihat Grafik", "Menjalankan Proyeksi", "Mengatur Parameter α/β Manual".
- **Activity Diagram / Flowchart** alur perhitungan Holt (input data → inisialisasi L₁,T₁ → iterasi Lt,Tt → grid search → output proyeksi + metrik akurasi).
- **Class Diagram / Struktur Data** untuk `forecasting_models.dart` (mis. class `TimeseriesPoint`, `ForecastResult`, `AccuracyMetrics`).
- **Sequence Diagram** interaksi antara `table.dart` (UI) → `forecasting_engine.dart` (logic) → `forecasting_chart_view.dart` (render).

---

## ✅ 4. Rencana Pengujian Software (Bahan Bab 4)

Pengujian akurasi model (MAPE/MAD/RMSE) **tidak cukup** untuk TA RPL — harus dilengkapi pengujian perangkat lunak itu sendiri.

### A. Black-Box Testing (Equivalence Partitioning)

| No | Skenario Pengujian | Input | Hasil Diharapkan | Status |
|:--:|---|---|---|:--:|
| 1 | Data time-series normal (≥3 titik) | Data 2017–2024 | Grafik proyeksi tampil, metrik akurasi terhitung | *(isi saat pengujian)* |
| 2 | Data terlalu sedikit (<2 titik) | 1 titik data | Sistem menampilkan pesan error/peringatan, bukan crash | |
| 3 | Slider α/β digeser manual | α=0.3, β=0.5 | Grafik proyeksi & metrik ter-update real-time | |
| 4 | Perpindahan tab Tabel → Grafik → Proyeksi | Tap segmented switcher | Transisi UI lancar, data konsisten antar tab | |
| 5 | Nilai Y mengandung 0 atau negatif | Data dengan Y=0 | MAPE tidak menghasilkan pembagian dengan nol (division by zero handling) | |
| 6 | Grid search dengan rentang data ekstrem outlier | Data dengan lonjakan tajam | Sistem tetap menghasilkan α,β tanpa infinite loop/freeze | |

### B. User Acceptance Testing (UAT)
Libatkan pengguna riil (idealnya staf BPS Demak/Bappeda) mengisi kuesioner singkat, contoh indikator (skala Likert 1–5):
1. Kemudahan memahami hasil proyeksi tanpa penjelasan tambahan
2. Kejelasan visualisasi grafik fl_chart
3. Kegunaan fitur slider parameter manual
4. Kepercayaan terhadap angka akurasi (MAPE) yang ditampilkan
5. Kecepatan/responsivitas aplikasi saat menjalankan proyeksi

### C. Instrumen Pengujian yang disarankan disebut di Bab 3 (metode penelitian)
> *"Pengujian sistem menggunakan metode black-box testing untuk memvalidasi fungsionalitas modul secara independen dari implementasi kode, dilanjutkan dengan User Acceptance Testing (UAT) menggunakan kuesioner skala Likert kepada [jumlah] responden dari kalangan [BPS/Bappeda/akademisi/publik] untuk mengukur penerimaan pengguna terhadap fitur Forecasting Engine."*

---

## 🧩 Ringkasan: Struktur Bab yang Disarankan Setelah Pelengkap Ini

| Bab | Isi |
|---|---|
| Bab 1 | Pendahuluan (sudah ada di panduan awal) |
| **Bab 2** | **Tinjauan Pustaka** ← dari dokumen ini Bagian 1 |
| Bab 3 | Landasan Teori (rumus Holt — sudah ada) **+** Metodologi Penelitian (SDLC Prototyping, Train-Test Split, Use Case/Activity/Class/Sequence Diagram) ← dari dokumen ini Bagian 2 & 3 |
| Bab 4 | Hasil & Pembahasan: hasil Grid Search, tabel evaluasi MAPE/MAD/RMSE **pada data holdout**, hasil Black-Box Testing & UAT ← dari dokumen ini Bagian 2 & 4 |
| Bab 5 | Kesimpulan & Saran (termasuk keterbatasan ukuran data — lihat catatan Bagian 2) |

---

*Dokumen ini bersifat kerangka/template — bagian bertanda `*(isi)*` wajib diisi dengan data dan referensi asli sebelum diajukan ke dosen pembimbing, karena dosen penguji akan memverifikasi keaslian sitasi dan data pengujian.*
