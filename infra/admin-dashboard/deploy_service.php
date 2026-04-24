<?php
session_start();
if (!isset($_SESSION['admin'])) {
    header("Location: index.php");
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Validar CSRF
    if (!isset($_POST['csrf_token']) || $_POST['csrf_token'] !== $_SESSION['csrf_token']) {
        die("Error de seguridad: Token CSRF inválido o ausente.");
    }

    $empresa = $_POST['empresa'] ?? '';
    $servicio = $_POST['servicio'] ?? '';
    
    if (empty($empresa) || empty($servicio)) {
        die("Error: Faltan datos.");
    }
    
    // API Call
    $url = "http://api:8000/deploy/" . urlencode($empresa) . "/" . urlencode($servicio);
    $token = getenv('API_TOKEN') ?: "d7f3e8b1a9c4d2e5f6a7b8c9d0e1f2a3"; 
    
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
    
    $data = json_decode($response, true);
    
    echo "<!DOCTYPE html><html><head><title>Estado de Despliegue</title>";
    echo "<style>body{font-family:sans-serif; padding:50px; background:#f8fafc; color:#333;} .card{background:white; padding:30px; border-radius:15px; box-shadow:0 4px 6px rgba(0,0,0,0.1); max-width:800px; margin:auto;} .success{color:#166534; background:#dcfce7; padding:15px; border-radius:10px;} .error{color:#991b1b; background:#fee2e2; padding:15px; border-radius:10px;} pre{background:#1e293b; color:#f8fafc; padding:15px; border-radius:8px; overflow-x:auto; font-size:12px;}</style></head><body>";
    echo "<div class='card'>";
    
    if ($http_code == 200 && isset($data['status']) && $data['status'] == 'success') {
        echo "<h2 class='success'>✅ Despliegue completado con éxito</h2>";
        echo "<p>El servicio <strong>$servicio</strong> para la empresa <strong>$empresa</strong> ya está operativo.</p>";
    } else {
        echo "<h2 class='error'>❌ Error en el despliegue</h2>";
        if (isset($data['stderr']) && !empty($data['stderr'])) {
            echo "<p>Detalles del error:</p>";
            echo "<pre>" . htmlspecialchars($data['stderr']) . "</pre>";
        } elseif (isset($data['detail'])) {
            echo "<p>Error de la API: " . htmlspecialchars($data['detail']) . "</p>";
        } else {
            echo "<p>Código de respuesta: $http_code</p>";
        }
    }
    
    echo "<br><a href='index.php' style='display:inline-block; padding:10px 20px; background:#4f46e5; color:white; text-decoration:none; border-radius:8px;'>Volver al Dashboard</a>";
    echo "</div></body></html>";
}
?>
