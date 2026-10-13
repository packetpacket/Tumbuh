# Tumbuh — Aplikasi Perkembangan Anak

Aplikasi web statis untuk profil anak, pengamatan bulanan, riwayat, cadangan JSON, dan laporan Excel (satu sheet per anak). Indikator berasal dari template pengguna: usia 3 bulan–1 tahun, 1–2 tahun, 2–4 tahun, dan 4–6 tahun. Untuk anak di atas 6 tahun, acuan 4–6 tahun mengikuti pilihan pengguna. Untuk anak di bawah 3 bulan, tidak ada indikator yang dibuat.

## Mencoba

Gunakan tautan pratinjau atau jalankan server HTTP di folder `dist`. Membuka index.html melalui file:// tidak didukung karena aplikasi mengambil indikator melalui fetch.

Mode percobaan berisi tiga profil fiktif. Penyimpanannya hanya di browser/perangkat yang sama. Untuk data sebenarnya, gunakan tombol Impor Excel dan pilih `Data_Anak_OKT_Urutan_Usia(1).xlsx`. File perkembangan dengan satu sheet per anak juga didukung: identitas di bagian atas setiap sheet dibaca otomatis. Impor pertama mengganti profil contoh beserta catatan percobaannya setelah konfirmasi. File sumber `DATA ANAK 2026.xlsx` juga didukung: aplikasi mengambil sheet OKT dan berhenti sebelum bagian OUT. Impor memvalidasi seluruh data sebelum menyimpan; baris invalid membatalkan impor. Nama dan tanggal lahir yang sama memperbarui profil tanpa menggandakan data. Tanggal Excel dibaca tanpa menggeser tanggal akibat zona waktu. Template indikator kosong tanpa identitas anak tidak dapat digunakan sebagai daftar anak.

## Hosting gratis

Unggah isi folder `dist` (bukan folder yang berisi data anak) ke repositori GitHub. Pada Cloudflare Pages, hubungkan repositori, pilih tanpa framework, tanpa build command, dan direktori output tempat index.html berada. Untuk GitHub Pages, pilih branch dan folder root yang berisi index.html. PWA dan OAuth memakai URL HTTPS; seluruh path dibuat relatif agar mendukung subfolder GitHub Pages. Untuk layanan pendamping dengan data anak nyata, Cloudflare Pages direkomendasikan. Pilih domain akhir sebelum mendaftarkan passkey.

Kode tidak berisi nama atau tanggal lahir anak sebenarnya. Jangan mengunggah Excel anak, cadangan JSON, atau file SQL berisi profil anak ke repositori publik.

## Menyiapkan Supabase, Google, PIN, dan passkey

1. Buat proyek Supabase khusus aplikasi ini. Proyek lain tidak diubah oleh pembuatan aplikasi.
2. Jalankan `supabase-schema.sql`, kemudian `supabase-security.sql` lewat SQL Editor. Untuk aplikasi lama yang sudah memiliki tabel/data, cukup jalankan SQL keamanan setelah memastikan SQL dasar pernah dijalankan. Semua tabel data memiliki RLS. PIN dan izin buka sesi berada di schema private; jangan tambahkan `tumbuh_private` ke Exposed schemas.
3. Pada Google Cloud / Google Auth Platform, siapkan branding dan audience. Buat OAuth client jenis Web application. Authorized JavaScript origins = origin domain aplikasi (tanpa subfolder). Authorized redirect URI = callback Supabase `https://PROJECT-REF.supabase.co/auth/v1/callback` yang ditampilkan pada konfigurasi provider Google. Simpan Client ID dan Client Secret **hanya** pada Authentication → Sign In / Providers → Google di Supabase, bukan di config.js atau GitHub. Dalam mode Google testing, tambahkan email pendamping ke daftar test users.
4. Di Supabase Authentication → URL Configuration, Site URL = URL aplikasi lengkap. Tambahkan URL lengkap itu beserta varian `?reset_pin=1` ke Redirect URLs. Untuk GitHub Pages gunakan trailing slash dan subfolder, misalnya `https://username.github.io/tumbuh/` dan `https://username.github.io/tumbuh/?reset_pin=1`.
5. Aktifkan provider Google. Untuk proyek khusus versi ini, matikan login email/password dan provider OAuth lain; pembuatan/reset PIN memakai autentikasi OAuth baru, dengan Google sebagai satu-satunya provider OAuth yang diaktifkan. Izinkan pembuatan akun Google pada login pertama. Akun baru **belum** dapat membaca data sampai admin memberinya membership.
6. Buka Pengaturan aplikasi. Isi Project URL dan publishable key atau legacy anon key. Jangan memakai service_role/secret key. Klik Hubungkan Supabase, lalu masuk dengan Google.
7. Setelah login pertama, akun muncul di Authentication → Users. Salin UUID akun, lalu admin jalankan `insert into public.tumbuh_staff(user_id,role) values ('UUID-AKUN','admin');`. Untuk pendamping lain gunakan `caregiver`. Admin menambah/mengimpor anak; caregiver membaca dan mengisi penilaian. Muat ulang aplikasi setelah diberi akses.
8. Pengguna membuat PIN 6 angka dalam lima menit setelah login Google. Jika sesi Google sudah lama, keluar dan masuk ulang Google. PIN berlaku per akun di semua perangkat, disimpan sebagai hash bcrypt. Setelah PIN tersimpan, impor Excel ketika mode Supabase aktif.
9. Opsional: Authentication → Passkeys → Enable. Fitur native passkey Supabase saat ini **eksperimental**. RP Display Name = Tumbuh. RP ID = hostname domain akhir tanpa https/path/port. Origins = origin HTTPS domain tersebut. Pada GitHub Pages RP ID = `username.github.io`, origin = `https://username.github.io`. Setelah pindah domain/RP ID, daftarkan ulang passkey.
10. Setelah akun dibuka, Pengaturan → Keamanan akun → Aktifkan sidik jari / Face ID. Browser/OS menyimpan passkey; Supabase memverifikasi tantangan dan tanda tangan. Perangkat dapat memakai sidik jari, Face ID, kode layar, atau security key. Web tidak dapat memaksa biometrik tertentu. Kelola passkey untuk menghapus perangkat lama; PIN tetap tersedia.

Referensi resmi: [Google OAuth](https://supabase.com/docs/guides/auth/social-login/auth-google), [passkeys](https://supabase.com/docs/guides/auth/passkeys).

Untuk konfigurasi bawaan, edit `config.js`. URL dan publishable key memang tersedia bagi frontend; izin data ditentukan database. Aplikasi tidak membuat/mengonfigurasi proyek Supabase Anda otomatis.

## Pemakaian keamanan akun

- Login Google pertama, kemudian masukkan PIN atau passkey akun tersebut. Jika sesi Google masih tersimpan pada perangkat, tahap berikutnya langsung meminta PIN/passkey. PIN dan sidik jari tidak diaktifkan pada mode percobaan.
- Akun dikunci 30 menit setelah verifikasi berhasil atau melalui Kunci akun. Saat membuka ulang halaman, aplikasi kembali meminta PIN/passkey. Data cloud tidak disimpan ke localStorage/cache service worker.
- Lima PIN salah mengunci percobaan PIN selama 15 menit pada database. Passkey atau verifikasi ulang Google untuk reset PIN tetap tersedia. Percobaan serentak antarperangkat diserialkan per akun.
- Ubah PIN membutuhkan PIN saat ini. Lupa PIN? masuk ulang Google lalu tentukan PIN baru. Google harus baru diverifikasi (AMR OAuth maksimum lima menit); refresh token tidak dihitung sebagai login ulang. Reset/ubah PIN membatalkan izin buka semua sesi akun.
- RLS membatasi pembacaan/penulisan profil dan penilaian sampai sesi punya izin buka yang belum kedaluwarsa. Passkey membuka sesi hanya dengan AMR `passkey` yang baru diverifikasi Supabase (maksimum dua menit), bukan boolean dari browser.
- Kunci otomatis membuang formulir belum tersimpan. Simpan draf secara berkala. PIN ini lapisan penguncian aplikasi; bukan pengganti MFA tingkat akun Google/Supabase.
- Keluar menghapus sesi Supabase dari browser. Admin mencabut akses dengan menghapus membership `tumbuh_staff`.

## Memasang sebagai PWA

Buka alamat HTTPS aplikasi langsung di browser HP. Android/desktop Chrome: Pengaturan → Pasang aplikasi, atau menu browser → Instal aplikasi. iPhone/iPad: Safari → Bagikan → Tambahkan ke Layar Utama. Instalasi dari browser di dalam aplikasi lain mungkin tidak tersedia; buka di Chrome/Safari.

Manifest, ikon 192/512, dan service worker sudah disertakan. App shell dan indikator dapat dicache. OAuth callback, API, dan data anak Supabase tidak dicache; mode Supabase tetap memerlukan internet. Mode percobaan bekerja offline setelah cache awal tersedia, pada perangkat/browser yang menyimpan datanya. Saat ada versi baru, tutup semua jendela aplikasi lalu buka lagi untuk mengambil service worker baru. Hosting privat ini juga memakai akses ChatGPT sebelum aplikasi; untuk penggunaan tim mandiri, pasang berkas di domain hosting sendiri.

## Penilaian dan laporan

Pilih anak dan periode bulan. Untuk bulan berjalan, usia acuan dihitung pada tanggal pengamatan pertama. Bulan sebelumnya memakai akhir bulan. Setelah draf pertama disimpan, indikator dan tanggal acuan menjadi snapshot yang tetap dipakai pada periode itu. Riwayat tidak berubah ketika anak berpindah kelompok usia. Usia saat ini tetap dihitung setiap kali membuka aplikasi.

Kolom hasil menggunakan BB, MB, BSH, BSB, atau Belum diamati. Semua kolom keterangan dan tindak lanjut dari template tersedia. Simpan Draf dapat dilakukan kapan saja. Simpan Selesai memerlukan konfirmasi bila masih ada hasil kosong; pengamatan tidak dibuat secara otomatis. Perubahan belum tersimpan ditandai dan diperingatkan saat berpindah halaman.

Ekspor laporan sesuai bulan yang dipilih. Satu anak menghasilkan satu sheet; semua anak diurutkan dari termuda ke tertua. Sel kelompok usia/perkembangan/aspek digabung, ditebalkan, dan rata tengah. Tanggal lahir sejajar dengan usia anak. Kolom usia memakai rumus TODAY(). Arsip penilaian mengikuti periode yang dipilih, sementara usia di header menampilkan usia saat ini.

Cadangan JSON mencakup semua profil dan riwayat. Pada versi awal ini, JSON disediakan sebagai cadangan lengkap untuk pemulihan manual; belum ada tombol pemulihan otomatis.

## Batas versi awal

- Supabase belum terhubung ke proyek pengguna. Google OAuth, PIN database, dan passkey nyata baru aktif setelah konfigurasi di atas. Pengujian perangkat biometrik dan OAuth nyata memerlukan proyek tersebut.
- Tidak ada foto, notifikasi, atau pengisian offline cloud pada versi awal.
- Cloud memakai pemeriksaan revision saat update untuk mendeteksi perubahan pendamping lain. Jika terjadi konflik, simpan/salin pengamatan yang belum tersimpan lalu muat ulang.
- Cadangkan secara berkala. Penyimpanan browser tidak menggantikan database bersama.

Dependensi browser: ExcelJS 4.4.0 (ekspor), SheetJS 0.20.3 (impor), dan supabase-js 2.117.3, disertakan pada vendor agar fitur inti tidak bergantung pada CDN saat dijalankan. Font daring memiliki fallback Arial.
