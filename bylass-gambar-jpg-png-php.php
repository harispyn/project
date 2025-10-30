<?php

// --- 1. Buat gambar PNG sederhana di memori ---

// Dimensi gambar
 $width = 200;
 $height = 50;

// Buat sumber daya gambar
 $image = imagecreatetruecolor($width, $height);

// Buat warna
 $bgColor = imagecolorallocate($image, 0x2c, 0x3e, 0x50); // Biru-abu tua
 $textColor = imagecolorallocate($image, 0xec, 0xf0, 0xf1); // Abu-abu muda

// Isi latar belakang
imagefill($image, 0, 0, $bgColor);

// Tambahkan beberapa teks
 $text = "Ini adalah PNG.";
 $font = 5; // Ukuran font bawaan
 $textWidth = imagefontwidth($font) * strlen($text);
 $textHeight = imagefontheight($font);
 $x = ($width - $textWidth) / 2;
 $y = ($height - $textHeight) / 2;
imagestring($image, $font, $x, $y, $text, $textColor);

// Tangkap output gambar ke dalam string
// Kami menggunakan output buffering untuk mendapatkan data biner dari PNG
ob_start();
imagepng($image);
 $pngBinaryData = ob_get_clean();

// Bersihkan sumber daya gambar dari memori
imagedestroy($image);


// --- 2. Bangun kode PHP untuk file poliglot ---

// Ini adalah kode PHP yang akan ditulis ke file baru kami.
// Kode ini berisi logika "rahasia" dan data PNG.

 $phpCode = <<<PHP
<?php
// --- KODE PHP RAHASIA ---
// Kode ini akan dieksekusi di server setiap kali file diminta.
// Kode ini sepenuhnya tersembunyi dari pengguna yang hanya melihat gambar.
//
// Contoh: Catat alamat IP pengunjung ke sebuah file.
// Dalam skenario dunia nyata, ini bisa berupa web shell, eksfiltrasi data, dll.
\$logEntry = date('Y-m-d H:i:s') . " - " . \$_SERVER['REMOTE_ADDR'] . "\n";
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

 $filename = 'polyglot_image.png.php';
file_put_contents($filename, $finalPolyglotCode);

// Atur izin yang benar agar server web dapat membacanya
chmod($filename, 0644);

echo "✅ Berhasil! File poliglot '{$filename}' telah dibuat.\n";
echo "🖼️  File akan menampilkan gambar saat diakses melalui browser.\n";
echo "🕵️  File juga akan secara diam-diam mencatat IP pengunjung ke 'secret_access_log.txt'.\n";

?>
