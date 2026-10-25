<?php
/**
 * App demo del servidor DÉBIL. Representa cualquier CMS/app PHP sin endurecer.
 *
 * IMPORTANTE: aquí NO hay exploit ni RCE. Solo reproducimos la SUPERFICIE que
 * un escáner usa para decidir si vales la pena como objetivo:
 *   1) delata su versión (expose_php = On),
 *   2) refleja estado/errores al cliente (display_errors = On),
 *   3) revienta en OOM de forma visible (memory_limit minúsculo).
 */

$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);

// Sonda de salud para el healthcheck del compose.
if ($path === '/healthz') {
    header('Content-Type: text/plain');
    echo 'ok';
    exit;
}

// Endpoint-instrumento del laboratorio: expone la config para el triaje.
// (Un servidor real NO tendría esto; aquí nos sirve para comparar lado a lado.)
if ($path === '/triage.php') {
    header('Content-Type: application/json');
    echo json_encode([
        'php_version'                     => PHP_VERSION,
        'expose_php'                      => ini_get('expose_php'),
        'display_errors'                  => ini_get('display_errors'),
        'session.upload_progress.enabled' => ini_get('session.upload_progress.enabled'),
        'session.use_strict_mode'         => ini_get('session.use_strict_mode'),
        'memory_limit'                    => ini_get('memory_limit'),
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
    exit;
}

// Así reacciona un servidor DÉBIL a la sonda del escáner: refleja el marcador
// (fuga de estado) y, con memory_limit minúsculo, al trabajar revienta en un
// Fatal error que display_errors=On entrega directo al atacante.
if (isset($_POST['PHP_SESSION_UPLOAD_PROGRESS'])) {
    echo 'reflected: ' . htmlspecialchars((string) $_POST['PHP_SESSION_UPLOAD_PROGRESS']) . "\n";
    // Forzamos OOM de forma inofensiva (solo tumba ESTE request del laboratorio).
    $buffer = '';
    while (true) {
        $buffer .= str_repeat('A', 1024 * 1024);
    }
}

http_response_code(200);
?>
<!doctype html>
<html lang="es">
<meta charset="utf-8">
<title>🛒 Tienda Demo (laboratorio vulnerable)</title>
<body style="font-family:system-ui;max-width:40rem;margin:4rem auto;color:#1f2733">
  <h1>🛒 Tienda Demo</h1>
  <p>Servidor PHP <strong>mal configurado</strong> del laboratorio php2shell.</p>
  <p style="color:#b91c1c">Este host delata su versión y refleja estado interno.</p>
</body>
</html>
