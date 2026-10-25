<?php
/**
 * App demo del servidor ENDURECIDO. Misma app que la vulnerable, pero:
 *   - no delata versión (expose_php = Off),
 *   - no refleja errores al cliente (display_errors = Off),
 *   - incluye una guardia tipo-WAF que CORTA la sonda del escáner.
 *
 * En producción esa guardia vive en tu WAF (Cloudflare / ModSecurity), no en la
 * app. Aquí la ponemos en PHP solo para que el demo sea autocontenido.
 */

$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);

if ($path === '/healthz') {
    header('Content-Type: text/plain');
    echo 'ok';
    exit;
}

// --- Guardia tipo-WAF: deniega la sonda de php2shell antes de tocar nada. -----
if (isset($_POST['PHP_SESSION_UPLOAD_PROGRESS'])) {
    http_response_code(403);               // sin eco, sin estado, sin pista
    header('Content-Type: text/plain');
    echo "403 Forbidden\n";
    exit;
}

// Endpoint-instrumento del laboratorio (solo para comparar en el triaje).
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

http_response_code(200);
?>
<!doctype html>
<html lang="es">
<meta charset="utf-8">
<title>🛒 Tienda Demo (laboratorio endurecido)</title>
<body style="font-family:system-ui;max-width:40rem;margin:4rem auto;color:#1f2733">
  <h1>🛒 Tienda Demo</h1>
  <p>Servidor PHP <strong>endurecido</strong> del laboratorio php2shell.</p>
  <p style="color:#15803d">Sin versión expuesta, sin fugas, sonda bloqueada.</p>
</body>
</html>
