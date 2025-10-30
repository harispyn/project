<?php

// --- Periksa apakah ekstensi Imagick terpasang ---
if (!extension_loaded('imagick')) {
    die("Error: Ekstensi Imagick untuk PHP tidak terpasang. Silakan instal terlebih dahulu.\n");
}

// --- 1. Buat gambar PNG menggunakan ImageMagick (Imagick) ---

// Dimensi gambar
 $width = 300;
 $height = 75;

// Buat objek Imagick
 $image = new Imagick();

// Buat objek piksel untuk warna
 $bgColor = new ImagickPixel('#3498db'); // Biru terang
 $textColor = new ImagickPixel('#ffffff'); // Putih

// Buat kanvas baru dengan warna latar belakang dan format PNG
 $image->newImage($width, $height, $bgColor, 'png');

// Buat objek untuk menggambar teks
 $draw = new ImagickDraw();
 $draw->setFillColor($textColor);
 $draw->setFontSize(25); // Ukuran font dalam poin
 $draw->setTextAlignment(Imagick::ALIGN_CENTER); // Rata tengah teks
 $draw->setFont('Arial'); // Coba gunakan font Arial, jika tidak ada akan menggunakan font default

// Tambahkan teks ke gambar
 $text = "Dibuat dengan ImageMagick";
// annotateImage(objek_gambar, x, y, sudut, teks)
 $image->annotateImage($draw, $width / 2, $height / 2 + 10, 0, $text);

// Dapatkan data biner gambar langsung sebagai string
// Metode ini lebih sederhana daripada output buffering di GD
 $pngBinaryData = $image->getImagesBlob();

// Bersihkan objek dari memori
 $image->clear();
 $image->destroy();


// --- 2. Bangun kode PHP untuk file poliglot ---
// (Bagian ini sama persis dengan versi GD, karena logika poliglotnya tidak berubah)

 $phpCode = <<<PHP
<?php
// --- KODE PHP RAHASIA ---
// Kode ini akan dieksekusi di server setiap kali file diminta.
// Kode ini sepenuhnya tersembunyi dari pengguna yang hanya melihat gambar.
//
// Contoh: Catat alamat IP pengunjung ke sebuah file.
// Dalam skenario dunia nyata, ini bisa berupa web shell, eksfiltrasi data, dll.
\$logEntry = date('Y-m-d H:i:s') . " - " . \$_SERVER['REMOTE_ADDR'] . " (ImageMagick Version)\n";
file_put_contents('secret_access_log.txt', \$logEntry, FILE_APPEND | LOCK_EX);
// --- AKHIR KODE RAHASIA ---


// --- OUTPUT GAMBAR ---
// Sekarang, kami kirim header yang benar dan keluarkan data PNG.
// Browser akan menginterpretasikan ini sebagai gambar yang valid.
header('Content-Type: image/png');
header('Content-Length: ' . strlen('PNG_DATA_PLACEHOLDER'));

// Gunakan "nowdoc" untuk mencetak data biner mentah dari PNG dengan aman.
// Ini seperti heredoc, tetapi tidak mem-parsing variabel di dalamnya.
echo <<<'PNG'
PNG_DATA_PLACEHOLDER
PNG;

// Skrip berakhir di sini. Browser telah menerima gambarnya.
PHP;


// --- 3. Gabungkan kode PHP dan data PNG ---

// Ganti placeholder dengan data biner PNG yang sebenarnya.
 $finalPolyglotCode = str_replace('PNG_DATA_PLACEHOLDER', $pngBinaryData, $phpCode);


// --- 4. Tulis file poliglot ke disk ---

 $filename = 'polyglot_imagemagick.png.php';
file_put_contents($filename, $finalPolyglotCode);

// Atur izin yang benar agar server web dapat membacanya
chmod($filename, 0644);

echo "✅ Sukses! File poliglot '{$filename}' telah dibuat menggunakan ImageMagick.\n";
echo "🖼️  File akan menampilkan gambar saat diakses melalui browser.\n";
echo "🕵️  File juga akan secara diam-diam mencatat IP pengunjung ke 'secret_access_log.txt'.\n";

?>
