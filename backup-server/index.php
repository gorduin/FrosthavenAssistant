<?php
// X-haven Assistant (gorduin/tv) — state backup endpoint.
//
//   POST /            body: backup JSON       -> saves it, keeps the newest MAX_FILES
//   GET  /?list       -> newest backups with their summary
//   GET  /?file=NAME  -> one backup (NAME from the list, or "latest")
//
// Every request needs the header  X-Backup-Key: <BACKUP_KEY from config.php>.

declare(strict_types=1);

require __DIR__ . '/config.php';

const MAX_BYTES = 5 * 1024 * 1024;
const MAX_FILES = 200;
const LIST_LIMIT = 60;

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

function reply(int $code, array $data): void
{
    http_response_code($code);
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

$key = $_SERVER['HTTP_X_BACKUP_KEY'] ?? '';
if (!defined('BACKUP_KEY') || strlen(BACKUP_KEY) < 24 || !hash_equals(BACKUP_KEY, $key)) {
    reply(403, ['error' => 'forbidden']);
}

$dir = __DIR__ . '/data';
if (!is_dir($dir) && !mkdir($dir, 0700, true)) {
    reply(500, ['error' => 'storage']);
}

/** @return string[] backup file names, newest first */
function backups(string $dir): array
{
    $files = glob($dir . '/backup-*.json') ?: [];
    $names = array_map('basename', $files);
    rsort($names, SORT_STRING); // names start with a UTC timestamp
    return $names;
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($method === 'POST') {
    $body = file_get_contents('php://input', false, null, 0, MAX_BYTES + 1);
    if ($body === false || $body === '') {
        reply(400, ['error' => 'empty']);
    }
    if (strlen($body) > MAX_BYTES) {
        reply(413, ['error' => 'too large']);
    }
    $data = json_decode($body, true);
    if (!is_array($data) || !isset($data['gameState']) || !is_string($data['gameState'])) {
        reply(400, ['error' => 'not a backup']);
    }
    $name = 'backup-' . gmdate('Ymd-His') . '-' . bin2hex(random_bytes(3)) . '.json';
    if (file_put_contents($dir . '/' . $name, $body, LOCK_EX) === false) {
        reply(500, ['error' => 'write']);
    }
    @copy($dir . '/' . $name, $dir . '/latest.json');
    foreach (array_slice(backups($dir), MAX_FILES) as $old) {
        @unlink($dir . '/' . $old);
    }
    reply(200, ['ok' => true, 'name' => $name]);
}

if ($method === 'GET' && isset($_GET['list'])) {
    $out = [];
    foreach (array_slice(backups($dir), 0, LIST_LIMIT) as $name) {
        $d = json_decode((string) file_get_contents($dir . '/' . $name), true);
        $out[] = [
            'name' => $name,
            'size' => filesize($dir . '/' . $name),
            'created' => $d['created'] ?? null,
            'reason' => $d['reason'] ?? null,
            'scenario' => $d['scenario'] ?? null,
            'round' => $d['round'] ?? null,
            'campaign' => $d['campaign'] ?? null,
        ];
    }
    reply(200, ['backups' => $out]);
}

if ($method === 'GET' && isset($_GET['file'])) {
    $name = (string) $_GET['file'];
    if ($name !== 'latest.json' && $name !== 'latest'
        && !preg_match('/^backup-\d{8}-\d{6}-[0-9a-f]{6}\.json$/', $name)) {
        reply(400, ['error' => 'bad name']);
    }
    if ($name === 'latest') {
        $name = 'latest.json';
    }
    $path = $dir . '/' . $name;
    if (!is_file($path)) {
        reply(404, ['error' => 'not found']);
    }
    readfile($path);
    exit;
}

reply(400, ['error' => 'bad request']);
