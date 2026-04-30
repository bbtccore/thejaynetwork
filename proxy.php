<?php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

$nodes = [
    'http://152.53.195.5',
    'http://152.53.195.105',
    'http://152.53.194.128',
];

$type = $_GET['t'] ?? '';
$path = $_GET['p'] ?? '';

if (!$path || !preg_match('#^/[a-zA-Z0-9_./?&=\-:%]+$#', $path)) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid path']);
    exit;
}

$port = ($type === 'rpc') ? 26657 : 1317;

$result = null;
foreach ($nodes as $node) {
    $url = $node . ':' . $port . $path;
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 20,
        CURLOPT_FOLLOWLOCATION => true,
    ]);

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $body = file_get_contents('php://input');
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $body);
        curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
    }

    $result = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($result !== false && $code >= 200 && $code < 500) {
        http_response_code($code);
        echo $result;
        exit;
    }
}

http_response_code(502);
echo json_encode(['error' => 'All nodes unreachable']);
