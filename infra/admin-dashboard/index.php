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
    <html lang="es">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>CloudControl - Login</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: 'Inter', system-ui, -apple-system, sans-serif;
                background: linear-gradient(135deg, #4f46e5 0%, #7c3aed 100%);
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                color: #1e293b;
            }
            .login-container {
                background: rgba(255, 255, 255, 0.95);
                backdrop-filter: blur(10px);
                padding: 3rem;
                border-radius: 1.5rem;
                box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
                width: 100%;
                max-width: 450px;
                border: 1px solid rgba(255, 255, 255, 0.3);
            }
            .login-container h1 {
                font-size: 2rem;
                font-weight: 800;
                margin-bottom: 2rem;
                text-align: center;
                background: linear-gradient(to right, #4f46e5, #7c3aed);
                -webkit-background-clip: text;
                -webkit-text-fill-color: transparent;
                letter-spacing: -0.05em;
            }
            .form-group { margin-bottom: 1.5rem; }
            .form-group label {
                display: block;
                margin-bottom: 0.5rem;
                font-weight: 600;
                font-size: 0.875rem;
                color: #475569;
            }
            .form-group input {
                width: 100%;
                padding: 0.75rem 1rem;
                border: 1.5px solid #e2e8f0;
                border-radius: 0.75rem;
                font-size: 1rem;
                transition: all 0.2s;
            }
            .form-group input:focus {
                outline: none;
                border-color: #4f46e5;
                box-shadow: 0 0 0 4px rgba(79, 70, 229, 0.1);
            }
            .btn {
                width: 100%;
                padding: 0.75rem;
                background: #4f46e5;
                color: white;
                border: none;
                border-radius: 0.75rem;
                font-size: 1rem;
                font-weight: 700;
                cursor: pointer;
                transition: all 0.2s;
                margin-top: 1rem;
            }
            .btn:hover {
                background: #4338ca;
                transform: translateY(-1px);
                box-shadow: 0 4px 12px rgba(79, 70, 229, 0.25);
            }
            .error {
                background: #fef2f2;
                color: #b91c1c;
                padding: 1rem;
                border-radius: 0.75rem;
                margin-bottom: 1.5rem;
                border: 1px solid #fee2e2;
                font-size: 0.875rem;
                font-weight: 500;
            }
        </style>
    </head>
    <body>
        <div class="login-container">
            <h1>🔐 CloudControl Admin</h1>
            <?php if (isset($error)): ?>
                <div class="error"><?php echo htmlspecialchars($error); ?></div>
            <?php endif; ?>
            <form method="POST">
                <div class="form-group">
                    <label for="admin_user">Usuario</label>
                    <input type="text" id="admin_user" name="admin_user" placeholder="admin" required>
                </div>
                <div class="form-group">
                    <label for="admin_password">Contraseña</label>
                    <input type="password" id="admin_password" name="admin_password" placeholder="••••••••" required>
                </div>
                <input type="hidden" name="csrf_token" value="<?php echo htmlspecialchars($_SESSION['csrf_token']); ?>">
                <button type="submit" class="btn">Iniciar Sesión</button>
            </form>
        </div>
    </body>
    </html>
    <?php
    exit;
}

// Obtener estadísticas y datos
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

$where_empresa = $_SESSION['es_admin'] != 1 ? " AND id = ?" : "";
$empresas_sql = "SELECT * FROM empresas WHERE estado = 'activa'" . $where_empresa . " ORDER BY nombre";
$empresas_stmt = mysqli_prepare($conn, $empresas_sql);
if ($_SESSION['es_admin'] != 1) mysqli_stmt_bind_param($empresas_stmt, "i", $_SESSION['empresa_id']);
mysqli_stmt_execute($empresas_stmt);
$empresas_result = mysqli_stmt_get_result($empresas_stmt);

$servicios_por_empresa = [];
$empresas = [];
while ($row = mysqli_fetch_assoc($empresas_result)) {
    $empresas[] = $row;
    $srv_sql = "SELECT * FROM servicios_contratados WHERE empresa_id = ? AND estado = 'activo'";
    $srv_stmt = mysqli_prepare($conn, $srv_sql);
    mysqli_stmt_bind_param($srv_stmt, "i", $row['id']);
    mysqli_stmt_execute($srv_stmt);
    $servicios_por_empresa[$row['id']] = mysqli_fetch_all(mysqli_stmt_get_result($srv_stmt), MYSQLI_ASSOC);
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CloudControl - Admin Dashboard</title>
    <style>
        :root {
            --primary: #4f46e5;
            --primary-hover: #4338ca;
            --bg: #f8fafc;
            --card-bg: #ffffff;
            --text-main: #1e293b;
            --text-muted: #64748b;
            --border: #e2e8f0;
            --shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1);
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Inter', system-ui, -apple-system, sans-serif;
            background: var(--bg);
            color: var(--text-main);
        }

        .header {
            background: rgba(255, 255, 255, 0.8);
            backdrop-filter: blur(12px);
            padding: 1rem 2rem;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid var(--border);
            position: sticky;
            top: 0;
            z-index: 50;
        }

        .header h1 { font-size: 1.25rem; font-weight: 800; background: linear-gradient(to right, #4f46e5, #7c3aed); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
        
        .container { max-width: 1280px; margin: 2rem auto; padding: 0 1.5rem; }

        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 1.5rem;
            margin-bottom: 3rem;
        }

        .stat-card {
            background: var(--card-bg);
            padding: 1.5rem;
            border-radius: 1rem;
            box-shadow: var(--shadow);
            border: 1px solid var(--border);
        }
        .stat-card h3 { font-size: 0.75rem; font-weight: 600; color: var(--text-muted); text-transform: uppercase; margin-bottom: 0.5rem; }
        .stat-card .value { font-size: 2.25rem; font-weight: 800; color: var(--primary); }

        .empresa-card {
            background: var(--card-bg);
            border-radius: 1.25rem;
            box-shadow: var(--shadow);
            margin-bottom: 2.5rem;
            overflow: hidden;
            border: 1px solid var(--border);
        }

        .empresa-header {
            padding: 1.5rem 2rem;
            background: #f8fafc;
            border-bottom: 1px solid var(--border);
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 1rem;
        }

        .empresa-info h3 { font-size: 1.25rem; font-weight: 700; margin-bottom: 0.25rem; }
        
        .deploy-form {
            display: flex;
            gap: 0.5rem;
            background: white;
            padding: 0.375rem;
            border-radius: 0.75rem;
            border: 1px solid #cbd5e1;
            width: 100%;
            max-width: 400px;
        }

        .deploy-form input {
            flex: 1;
            border: none;
            padding: 0.5rem 0.75rem;
            outline: none;
            font-size: 0.875rem;
        }

        .btn-deploy {
            background: var(--primary);
            color: white;
            border: none;
            padding: 0.5rem 1rem;
            border-radius: 0.5rem;
            font-weight: 600;
            font-size: 0.875rem;
            cursor: pointer;
            transition: all 0.2s;
        }
        .btn-deploy:hover { background: var(--primary-hover); transform: translateY(-1px); }

        .servicios-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 1.5rem;
            padding: 2rem;
        }

        .servicio-item {
            background: #ffffff;
            padding: 1.5rem;
            border-radius: 1rem;
            border: 1px solid var(--border);
            transition: all 0.2s;
            position: relative;
        }
        .servicio-item:hover { border-color: var(--primary); box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1); }

        .servicio-item h4 { color: var(--text-main); font-size: 1.125rem; font-weight: 700; margin-bottom: 1rem; display: flex; align-items: center; justify-content: space-between; }
        
        .badge-status {
            font-size: 0.625rem;
            padding: 0.25rem 0.625rem;
            background: #dcfce7;
            color: #166534;
            border-radius: 9999px;
            text-transform: uppercase;
            font-weight: 700;
        }

        .servicio-meta { font-size: 0.875rem; color: var(--text-muted); margin-bottom: 1rem; }
        .servicio-meta p { display: flex; justify-content: space-between; margin-bottom: 0.25rem; }
        .servicio-meta strong { color: var(--text-main); }

        .btn-panel {
            display: block;
            width: 100%;
            text-align: center;
            padding: 0.625rem;
            background: #f1f5f9;
            color: var(--text-main);
            text-decoration: none;
            border-radius: 0.5rem;
            font-size: 0.875rem;
            font-weight: 600;
            transition: all 0.2s;
        }
        .btn-panel:hover { background: #e2e8f0; color: var(--primary); }

        .btn-logout {
            padding: 0.5rem 1rem;
            background: #f1f5f9;
            color: #475569;
            text-decoration: none;
            border-radius: 0.5rem;
            font-size: 0.875rem;
            font-weight: 600;
            transition: all 0.2s;
        }
        .btn-logout:hover { background: #fee2e2; color: #b91c1c; }

        @media (max-width: 640px) {
            .header { flex-direction: column; gap: 1rem; padding: 1rem; }
            .stats-grid { grid-template-columns: 1fr; }
            .deploy-form { max-width: 100%; }
        }
    </style>
</head>
<body>
    <header class="header">
        <h1>🚀 CloudControl Dashboard</h1>
        <div style="display: flex; align-items: center; gap: 1.5rem;">
            <div style="text-align: right; line-height: 1;">
                <p style="font-size: 0.75rem; color: var(--text-muted); font-weight: 600;">ADMINISTRADOR</p>
                <p style="font-size: 0.875rem; font-weight: 700;"><?php echo htmlspecialchars($_SESSION['admin_id']); ?></p>
            </div>
            <a href="?logout=1" class="btn-logout">Salir</a>
        </div>
    </header>

    <main class="container">
        <section class="stats-grid">
            <div class="stat-card">
                <h3>Empresas Gestionadas</h3>
                <div class="value"><?php echo $stats['total_empresas']; ?></div>
            </div>
            <div class="stat-card">
                <h3>Servicios Desplegados</h3>
                <div class="value"><?php echo $stats['total_servicios']; ?></div>
            </div>
            <div class="stat-card">
                <h3>Usuarios del Sistema</h3>
                <div class="value"><?php echo $stats['total_usuarios']; ?></div>
            </div>
        </section>

        <section>
            <h2 style="font-size: 1.5rem; font-weight: 800; margin-bottom: 1.5rem; letter-spacing: -0.025em;">Infraestructura Multiempresa</h2>
            
            <?php if (empty($empresas)): ?>
                <div style="background: white; padding: 4rem; text-align: center; border-radius: 1rem; border: 1px dashed #cbd5e1;">
                    <p style="color: var(--text-muted);">No hay empresas activas en este momento.</p>
                </div>
            <?php else: ?>
                <?php foreach ($empresas as $empresa): ?>
                    <article class="empresa-card">
                        <div class="empresa-header">
                            <div class="empresa-info">
                                <h3><?php echo htmlspecialchars($empresa['nombre']); ?></h3>
                                <p style="font-size: 0.875rem; color: var(--text-muted);"><?php echo htmlspecialchars($empresa['descripcion'] ?: 'Cliente Corporativo SaaS'); ?></p>
                            </div>
                            
                            <form method="POST" action="deploy_service.php" class="deploy-form">
                                <input type="hidden" name="empresa" value="<?php echo htmlspecialchars($empresa['nombre']); ?>">
                                <input type="hidden" name="csrf_token" value="<?php echo htmlspecialchars($_SESSION['csrf_token']); ?>">
                                <input type="text" name="servicio" placeholder="Nombre del nuevo servicio..." required>
                                <button type="submit" class="btn-deploy">Desplegar</button>
                            </form>
                        </div>
                        
                        <div class="servicios-grid">
                            <?php if (empty($servicios_por_empresa[$empresa['id']])): ?>
                                <p style="grid-column: 1/-1; text-align: center; color: var(--text-muted); padding: 1rem; font-size: 0.875rem; font-style: italic;">Sin servicios activos.</p>
                            <?php else: ?>
                                <?php foreach ($servicios_por_empresa[$empresa['id']] as $servicio): ?>
                                    <div class="servicio-item">
                                        <h4>
                                            <span>📦 <?php echo htmlspecialchars($servicio['nombre_servicio']); ?></span>
                                            <span class="badge-status">Running</span>
                                        </h4>
                                        <div class="servicio-meta">
                                            <p><span>ID:</span> <strong>#<?php echo $servicio['id']; ?></strong></p>
                                            <p><span>Infraestructura:</span> <strong>Docker Container</strong></p>
                                            <p><span>Puerto Asignado:</span> <strong><?php echo $servicio['puerto']; ?></strong></p>
                                        </div>
                                        <?php if ($servicio['url_admin']): ?>
                                            <a href="<?php echo htmlspecialchars($servicio['url_admin']); ?>" target="_blank" class="btn-panel">Acceder al Panel</a>
                                        <?php else: ?>
                                            <button class="btn-panel" style="opacity: 0.5; cursor: not-allowed;" disabled>Panel no disponible</button>
                                        <?php endif; ?>
                                    </div>
                                <?php endforeach; ?>
                            <?php endif; ?>
                        </div>
                    </article>
                <?php endforeach; ?>
            <?php endif; ?>
        </section>
    </main>

    <?php if (isset($_GET['logout'])) { session_destroy(); header("Location: " . $_SERVER['PHP_SELF']); exit; } ?>
</body>
</html>
<?php mysqli_close($conn); ?>
