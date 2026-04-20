<?php
session_start();
if (!isset($_SESSION['admin'])) {
    header("Location: index.php");
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $empresa = $_POST['empresa'] ?? '';
    $servicio = $_POST['servicio'] ?? '';
    
    if (empty($empresa) || empty($servicio)) {
        die("Error: Faltan datos.");
    }
    
    // API Call
    $url = "http://api:8000/deploy/" . urlencode($empresa) . "/" . urlencode($servicio);
    $token = "supersecrettoken"; // Should be managed securely
    
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        'token: ' . $token
    ]);
    
    $response = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($http_code == 200) {
        echo "Despliegue iniciado correctamente.";
    } else {
        echo "Error en el despliegue. Código: " . $http_code;
    }
    echo "<br><a href='index.php'>Volver al dashboard</a>";
}
?>