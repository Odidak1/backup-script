# README Skrip Cadangan Otomatis

Skrip ini digunakan untuk melakukan pencadangan otomatis data dan basis data MySQL ke Google Drive menggunakan `rclone`. Skrip ini dapat dijalankan secara manual atau dijadwalkan menggunakan cron.

## Prasyarat

Pastikan Anda telah menginstal `rclone` dan memiliki kredensial Google Drive yang dikonfigurasi di `rclone`.

## Langkah-Langkah Instalasi

1. **Clone Repositori**

   Pertama, clone repositori skrip ini ke server atau mesin lokal Anda:

   ```bash
   git clone https://github.com/Odidak1/backup-script.git
   cd backup-script
   ```

2. **Konfigurasi Skrip**

   Buka skrip `backup.sh` menggunakan teks editor, misalnya `nano`:

   ```bash
   nano backup.sh
   ```

   Ubah pengaturan berikut sesuai dengan kebutuhan Anda:

3. **Beri Izin Eksekusi**

   Agar skrip dapat dijalankan, beri izin eksekusi pada skrip dengan perintah berikut:

   ```bash
   chmod +x backup.sh
   ```

4. **Jalankan Skrip**

   Setelah konfigurasi selesai, jalankan skrip dengan perintah berikut:

   ```bash
   ./backup.sh
   ```

   Skrip ini akan mencadangkan file dari direktori yang ditentukan serta basis data MySQL, dan mengirimkan pemberitahuan status pencadangan melalui webhook (jika URL webhook disediakan).

## Menjadwalkan Pencadangan Otomatis dengan Cron

Untuk menjalankan pencadangan secara otomatis pada waktu tertentu, Anda dapat menggunakan **cron**. Berikut adalah cara menjadwalkan skrip untuk dijalankan setiap hari pukul 2 pagi:

1. Buka crontab dengan perintah:

   ```bash
   crontab -e
   ```

2. Tambahkan baris berikut untuk menjalankan skrip setiap hari pada pukul 02:00:

   ```bash
   0 2 * * * /path/to/your/backup.sh
   ```

   Pastikan untuk mengganti `/path/to/your/backup.sh` dengan path lengkap ke skrip yang telah Anda buat.

## Catatan

- **Dependensi**: Skrip ini akan otomatis menginstal dependensi yang diperlukan saat pertama kali dijalankan, seperti `rclone`, `zip`, `curl`, `bc`, `jq`, dan `mysqldump`.
- **rclone**: Pastikan Anda telah mengonfigurasi **rclone** dan memiliki akses ke Google Drive Anda sebelum menjalankan skrip.
- **MySQL**: Skrip ini juga memerlukan akses ke MySQL untuk mencadangkan basis data.
