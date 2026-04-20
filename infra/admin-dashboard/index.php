<?php
session_start();

// Config DB
$db_host = getenv('DB_HOST') ?: 'infra_users_db';
$db_name = getenv('DB_NAME') ?: 'users_db';
$db_user = getenv('DB_USER') ?: 'users_user';
$db_pass = getenv('DB_PASSWORD') ?: 'users_pass';

$conn = mysqli_connect($db_host, $db_user, $db_pass, $db_name);
if (!$conn) {
    die("Error de conexión a BD: " . mysqli_connect_error());
}
mysqli_set_charset($conn, "utf8mb4");

// Verificar si es admin
if (!isset($_SESSION['admin'])) {
    // CSRF token generation
    if (empty($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }

    // Si no hay sesión admin, redirigir a login
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        if (!isset($_POST['csrf_token']) || $_POST['csrf_token'] !== $_SESSION['csrf_token']) {
            die("Error de seguridad: Token CSRF inválido");
        }
        $admin_pass = $_POST['admin_password'] ?? '';
        $admin_user = $_POST['admin_user'] ?? 'admin';
        
        $sql = "SELECT id, hash_password, empresa_id, es_admin FROM usuarios WHERE usuario = ?";
        $stmt = mysqli_prepare($conn, $sql);
        mysqli_stmt_bind_param($stmt, "s", $admin_user);
        mysqli_stmt_execute($stmt);
        $result = mysqli_stmt_get_result($stmt);
        
        if ($row = mysqli_fetch_assoc($result)) {
            if (password_verify($admin_pass, $row['hash_password'])) {
                // Verificar si tiene acceso (es_admin = 1 O empresa_id NOT NULL)
                if ($row['es_admin'] != 1 && is_null($row['empresa_id'])) {
                    $error = "Usuario sin permisos de acceso";
                } else {
                    $_SESSION['admin'] = 1;
                    $_SESSION['admin_id'] = $row['id'];
                    $_SESSION['empresa_id'] = $row['empresa_id'];
                    $_SESSION['es_admin'] = $row['es_admin'];
                    // Log de acceso
                    $ip = $_SERVER['REMOTE_ADDR'];
                    $log_sql = "INSERT INTO access_logs (usuario_id, accion, ip_address) VALUES (?, 'admin_login', ?)";
                    $log_stmt = mysqli_prepare($conn, $log_sql);
                    mysqli_stmt_bind_param($log_stmt, "is", $row['id'], $ip);
                    mysqli_stmt_execute($log_stmt);
                    header("Location: " . $_SERVER['PHP_SELF']);
                    exit;
                }
            }
        }
        $error = "Credenciales de admin inválidas";
    }
    
    // Mostrar formulario login
    ?>
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Admin Dashboard - Login</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
            }
            .login-container {
                background: white;
                padding: 40px;
                border-radius: 10px;
                box-shadow: 0 10px 25px rgba(0,0,0,0.2);
                width: 100%;
                max-width: 400px;
            }
            .login-container h1 {
                color: #333;
                margin-bottom: 30px;
                text-align: center;
            }
            .form-group {
                margin-bottom: 20px;
            }
            .form-group label {
                display: block;
                margin-bottom: 8px;
                color: #555;
                font-weight: 500;
            }
            .form-group input {
                width: 100%;
                padding: 12px;
                border: 1px solid #ddd;
                border-radius: 5px;
                font-size: 14px;
            }
            .form-group input:focus {
                outline: none;
                border-color: #667eea;
                box-shadow: 0 0 0 3px rgba(102,126,234,0.1);
            }
            .btn {
                width: 100%;
                padding: 12px;
                background: #667eea;
                color: white;
                border: none;
                border-radius: 5px;
                font-size: 16px;
                font-weight: 600;
                cursor: pointer;
                transition: background 0.3s;
            }
            .btn:hover { background: #764ba2; }
            .error {
                background: #fee;
                color: #c33;
                padding: 12px;
                border-radius: 5px;
                margin-bottom: 20px;
                border-left: 4px solid #c33;
            }
        </style>
    </head>
    <body>
        <div class="login-container">
            <h1>🔐 Admin Dashboard</h1>
            <?php if (isset($error)): ?>
                <div class="error"><?php echo htmlspecialchars($error); ?></div>
            <?php endif; ?>
            <form method="POST">
                <div class="form-group">
                    <label for="admin_user">Usuario Admin:</label>
                    <input type="text" id="admin_user" name="admin_user" value="admin" required>
                </div>
                <div class="form-group">
                    <label for="admin_password">Contraseña:</label>
                    <input type="password" id="admin_password" name="admin_password" required>
                </div>
                <input type="hidden" name="csrf_token" value="<?php echo htmlspecialchars($_SESSION['csrf_token']); ?>">
                <button type="submit" class="btn">Acceder</button>
            </form>
        </div>
    </body>
    </html>
    <?php
    exit;
}

// Usuario autenticado - Obtener datos del dashboard
$where_empresa = "";
$params = [];
$types = "";

if ($_SESSION['es_admin'] != 1) {
    $where_empresa = " AND id = ?";
    $params[] = $_SESSION['empresa_id'];
    $types .= "i";
}

$empresas_sql = "SELECT * FROM empresas WHERE estado = 'activa'" . $where_empresa . " ORDER BY nombre";
$empresas_stmt = mysqli_prepare($conn, $empresas_sql);
if (!empty($params)) {
    mysqli_stmt_bind_param($empresas_stmt, $types, ...$params);
}
mysqli_stmt_execute($empresas_stmt);
$empresas_result = mysqli_stmt_get_result($empresas_stmt);
$empresas = [];
while ($row = mysqli_fetch_assoc($empresas_result)) {
    $empresas[] = $row;
}

// Obtener servicios por empresa
$servicios_por_empresa = [];
foreach ($empresas as $empresa) {
    $srv_sql = "SELECT * FROM servicios_contratados WHERE empresa_id = ? AND estado = 'activo'";
    $srv_stmt = mysqli_prepare($conn, $srv_sql);
    mysqli_stmt_bind_param($srv_stmt, "i", $empresa['id']);
    mysqli_stmt_execute($srv_stmt);
    $srv_result = mysqli_stmt_get_result($srv_stmt);
    $servicios_por_empresa[$empresa['id']] = [];
    while ($row = mysqli_fetch_assoc($srv_result)) {
        $servicios_por_empresa[$empresa['id']][] = $row;
    }
}

// Estadísticas
if ($_SESSION['es_admin'] == 1) {
    $stats_sql = "SELECT 
        (SELECT COUNT(*) FROM empresas WHERE estado = 'activa') as total_empresas,
        (SELECT COUNT(*) FROM usuarios WHERE estado = 'activo') as total_usuarios,
        (SELECT COUNT(*) FROM servicios_contratados WHERE estado = 'activo') as total_servicios";
    $stats = mysqli_fetch_assoc(mysqli_query($conn, $stats_sql));
} else {
    $emp_id = $_SESSION['empresa_id'];
    $stats_sql = "SELECT 
        (SELECT COUNT(*) FROM empresas WHERE id = ? AND estado = 'activa') as total_empresas,
        (SELECT COUNT(*) FROM usuarios WHERE empresa_id = ? AND estado = 'activo') as total_usuarios,
        (SELECT COUNT(*) FROM servicios_contratados WHERE empresa_id = ? AND estado = 'activo') as total_servicios";
    $stmt = mysqli_prepare($conn, $stats_sql);
    mysqli_stmt_bind_param($stmt, "iii", $emp_id, $emp_id, $emp_id);
    mysqli_stmt_execute($stmt);
    $stats = mysqli_fetch_assoc(mysqli_stmt_get_result($stmt));
}

?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Admin Dashboard - Sistema SaaS</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: #f5f7fa;
            color: #333;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px 40px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .header h1 { font-size: 28px; }
        .header-actions { display: flex; gap: 15px; align-items: center; }
        .logout-btn {
            background: rgba(255,255,255,0.2);
            color: white;
            padding: 10px 20px;
            border: 1px solid white;
            border-radius: 5px;
            cursor: pointer;
            font-size: 14px;
            transition: background 0.3s;
        }
        .logout-btn:hover { background: rgba(255,255,255,0.3); }
        
        .container { max-width: 1400px; margin: 0 auto; padding: 30px 20px; }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 40px;
        }
        .stat-card {
            background: white;
            padding: 25px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            text-align: center;
            border-top: 4px solid #667eea;
        }
        .stat-card h3 { color: #999; font-size: 14px; margin-bottom: 10px; text-transform: uppercase; }
        .stat-card .value { font-size: 36px; font-weight: bold; color: #667eea; }
        
        .empresas-section h2 { margin-bottom: 25px; color: #333; }
        
        .empresa-card {
            background: white;
            border-radius: 10px;
            margin-bottom: 30px;
            overflow: hidden;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            border-left: 5px solid #667eea;
        }
        .empresa-header {
            background: linear-gradient(135deg, #667eea15 0%, #764ba215 100%);
            padding: 20px;
            border-bottom: 1px solid #eee;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .empresa-header h3 { font-size: 20px; color: #333; }
        .empresa-status {
            display: inline-block;
            padding: 5px 12px;
            background: #28a745;
            color: white;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
        }
        
        .servicios-container {
            padding: 20px;
        }
        .servicios-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
            gap: 15px;
        }
        .servicio-item {
            border: 1px solid #ddd;
            border-radius: 8px;
            padding: 15px;
            background: #fafbfc;
            transition: all 0.3s;
            cursor: pointer;
        }
        .servicio-item:hover {
            border-color: #667eea;
            box-shadow: 0 4px 12px rgba(102,126,234,0.2);
            transform: translateY(-2px);
        }
        .servicio-item h4 {
            color: #667eea;
            margin-bottom: 8px;
            font-size: 16px;
        }
        .servicio-item p {
            font-size: 13px;
            color: #666;
            margin: 4px 0;
        }
        .servicio-tipo {
            display: inline-block;
            background: #e7f3ff;
            color: #0066cc;
            padding: 3px 8px;
            border-radius: 3px;
            font-size: 12px;
            margin-top: 10px;
        }
        .servicio-actions {
            margin-top: 12px;
            display: flex;
            gap: 10px;
        }
        .servicio-btn {
            flex: 1;
            padding: 8px 12px;
            background: #667eea;
            color: white;
            border: none;
            border-radius: 5px;
            font-size: 12px;
            cursor: pointer;
            text-decoration: none;
            text-align: center;
            transition: background 0.3s;
        }
        .servicio-btn:hover { background: #764ba2; }
        
        .empty-state {
            text-align: center;
            padding: 40px;
            color: #999;
        }
        .empty-state p { font-size: 16px; }
        
        @media (max-width: 768px) {
            .header { flex-direction: column; gap: 15px; }
            .stats-grid { grid-template-columns: 1fr; }
            .servicios-grid { grid-template-columns: 1fr; }
            .empresa-header { flex-direction: column; gap: 10px; align-items: flex-start; }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>📊 Dashboard Admin - SaaS MultiEmpresa</h1>
        <div class="header-actions">
            <span>Conectado: <?php echo htmlspecialchars($_SESSION['admin_id'] ?? 'N/A'); ?></span>
            <form method="GET" style="margin: 0;">
                <button type="submit" name="logout" value="1" class="logout-btn">Cerrar sesión</button>
            </form>
        </div>
    </div>

    <div class="container">
        <!-- Estadísticas -->
        <div class="stats-grid">
            <div class="stat-card">
                <h3>Empresas Activas</h3>
                <div class="value"><?php echo $stats['total_empresas'] ?? 0; ?></div>
            </div>
            <div class="stat-card">
                <h3>Usuarios Registrados</h3>
                <div class="value"><?php echo $stats['total_usuarios'] ?? 0; ?></div>
            </div>
            <div class="stat-card">
                <h3>Servicios Contratados</h3>
                <div class="value"><?php echo $stats['total_servicios'] ?? 0; ?></div>
            </div>
        </div>

        <!-- Empresas y Servicios -->
        <div class="empresas-section">
            <h2>🏢 Empresas y Servicios Contratados</h2>
            
            <?php if (empty($empresas)): ?>
                <div class="empty-state">
                    <p>No hay empresas activas en el sistema.</p>
                </div>
            <?php else: ?>
                <?php foreach ($empresas as $empresa): ?>
                    <div class="empresa-card">
                                <div class="empresa-header">
                                    <div>
                                        <h3><?php echo htmlspecialchars($empresa['nombre']); ?></h3>
                                        <?php if ($empresa['descripcion']): ?>
                                            <p style="font-size: 13px; color: #666; margin-top: 5px;">
                                                <?php echo htmlspecialchars($empresa['descripcion']); ?>
                                            </p>
                                        <?php endif; ?>
                                    </div>
                                    <form method="POST" action="deploy_service.php" style="display:flex; gap:10px;">
                                        <input type="hidden" name="empresa" value="<?php echo htmlspecialchars($empresa['nombre']); ?>">
                                        <input type="text" name="servicio" placeholder="Nombre servicio" required style="padding:5px; border-radius:5px; border:1px solid #ccc;">
                                        <button type="submit" class="logout-btn" style="padding:5px 10px; cursor:pointer;">Desplegar</button>
                                    </form>
                                    <span class="empresa-status">✓ Activa</span>
                                </div>
                        
                        <div class="servicios-container">
                            <?php if (empty($servicios_por_empresa[$empresa['id']])): ?>
                                <div class="empty-state">
                                    <p>No tiene servicios contratados aún</p>
                                </div>
                            <?php else: ?>
                                <div class="servicios-grid">
                                    <?php foreach ($servicios_por_empresa[$empresa['id']] as $servicio): ?>
                                        <div class="servicio-item">
                                            <h4>📦 <?php echo htmlspecialchars($servicio['nombre_servicio']); ?></h4>
                                            <?php if ($servicio['tipo']): ?>
                                                <p><strong>Tipo:</strong> <?php echo htmlspecialchars($servicio['tipo']); ?></p>
                                            <?php endif; ?>
                                            <?php if ($servicio['puerto']): ?>
                                                <p><strong>Puerto:</strong> <?php echo $servicio['puerto']; ?></p>
                                            <?php endif; ?>
                                            <?php if ($servicio['fecha_contratacion']): ?>
                                                <p><strong>Contratación:</strong> <?php echo date('d/m/Y', strtotime($servicio['fecha_contratacion'])); ?></p>
                                            <?php endif; ?>
                                            <span class="servicio-tipo"><?php echo ucfirst($servicio['tipo'] ?? 'General'); ?></span>
                                            <div class="servicio-actions">
                                                <?php if ($servicio['url_admin']): ?>
                                                    <a href="<?php echo htmlspecialchars($servicio['url_admin']); ?>" 
                                                       target="_blank" class="servicio-btn">
                                                       Panel Admin
                                                    </a>
                                                <?php else: ?>
                                                    <span class="servicio-btn" style="background: #ccc; cursor: default;">No disponible</span>
                                                <?php endif; ?>
                                            </div>
                                        </div>
                                    <?php endforeach; ?>
                                </div>
                            <?php endif; ?>
                        </div>
                    </div>
                <?php endforeach; ?>
            <?php endif; ?>
        </div>
    </div>

    <?php
    if (isset($_GET['logout'])) {
        session_destroy();
        header("Location: " . $_SERVER['PHP_SELF']);
        exit;
    }
    ?>
</body>
</html>
<?php
mysqli_close($conn);
?>
