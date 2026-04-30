<?php
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('Referrer-Policy: no-referrer');
header('Permissions-Policy: camera=(self), microphone=(), geolocation=()');

define('REST', 'http://152.53.195.5:1317');

function rateLimit($key, $max = 30, $window = 60) {
    $ip = $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
    $dir = sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'jay_rl';
    @mkdir($dir, 0700, true);
    $f = $dir . DIRECTORY_SEPARATOR . md5($ip . '_' . $key);
    $now = time();
    $hits = [];
    if (file_exists($f)) {
        $hits = json_decode(@file_get_contents($f), true) ?: [];
        $hits = array_values(array_filter($hits, fn($t) => $t > $now - $window));
    }
    if (count($hits) >= $max) {
        header('HTTP/1.1 429 Too Many Requests');
        header('Retry-After: ' . $window);
        die(json_encode(['error' => 'Too many requests']));
    }
    $hits[] = $now;
    @file_put_contents($f, json_encode($hits));
}

function apiCall($path) {
    $ch = curl_init(REST . $path);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 12,
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_FOLLOWLOCATION => true,
    ]);
    $r = curl_exec($ch);
    curl_close($ch);
    return json_decode($r, true);
}

function apiPost($path, $body) {
    $ch = curl_init(REST . $path);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => json_encode($body),
        CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
        CURLOPT_TIMEOUT => 15,
        CURLOPT_SSL_VERIFYPEER => true,
    ]);
    $r = curl_exec($ch);
    curl_close($ch);
    return json_decode($r, true);
}

if (basename($_SERVER['SCRIPT_FILENAME']) === basename(__FILE__) && isset($_GET['a'])) {
    header('Content-Type: application/json');
    $addr = $_GET['addr'] ?? '';
    if ($addr !== '' && !preg_match('/^yjay[a-z0-9]{39}$/', $addr) && !preg_match('/^yjayvaloper[a-z0-9]{39}$/', $addr)) {
        die(json_encode(['error' => 'Invalid address format']));
    }
    $in = json_decode(file_get_contents('php://input'), true) ?: [];

    rateLimit($_GET['a'], $_GET['a'] === 'broadcast' ? 5 : 30);

    switch ($_GET['a']) {
        case 'balance':
            if (!$addr) die(json_encode(['balances' => []]));
            echo json_encode(apiCall('/cosmos/bank/v1beta1/balances/' . $addr) ?: ['balances' => []]);
            break;

        case 'account':
            if (!$addr) die(json_encode([]));
            echo json_encode(apiCall('/cosmos/auth/v1beta1/accounts/' . $addr) ?: []);
            break;

        case 'validators':
            echo json_encode(apiCall('/cosmos/staking/v1beta1/validators?status=BOND_STATUS_BONDED&pagination.limit=100') ?: []);
            break;

        case 'delegations':
            if (!$addr) die(json_encode([]));
            echo json_encode(apiCall('/cosmos/staking/v1beta1/delegations/' . $addr) ?: []);
            break;

        case 'rewards':
            if (!$addr) die(json_encode([]));
            echo json_encode(apiCall('/cosmos/distribution/v1beta1/delegators/' . $addr . '/rewards') ?: []);
            break;

        case 'txs':
            if (!$addr) die(json_encode(['tx_responses' => []]));
            $limit = 20;
            $page = intval($_GET['page'] ?? 1);
            $offset = ($page - 1) * $limit;
            $base = '/cosmos/tx/v1beta1/txs?order_by=ORDER_BY_DESC&pagination.limit=' . $limit . '&pagination.offset=' . $offset;
            $send = apiCall($base . '&query=' . urlencode("message.sender='" . $addr . "'")) ?: ['tx_responses' => []];
            $recv = apiCall($base . '&query=' . urlencode("transfer.recipient='" . $addr . "'")) ?: ['tx_responses' => []];
            $all = array_merge($send['tx_responses'] ?? [], $recv['tx_responses'] ?? []);
            $seen = [];
            $unique = [];
            foreach ($all as $tx) {
                $h = $tx['txhash'] ?? '';
                if ($h && !isset($seen[$h])) { $seen[$h] = true; $unique[] = $tx; }
            }
            usort($unique, function($a, $b) { return intval($b['height'] ?? 0) - intval($a['height'] ?? 0); });
            $unique = array_slice($unique, 0, $limit);
            echo json_encode(['tx_responses' => $unique, 'total' => max(intval($send['total'] ?? 0), intval($recv['total'] ?? 0))]);
            break;

        case 'proposals':
            echo json_encode(apiCall('/cosmos/gov/v1/proposals?pagination.limit=50&pagination.reverse=true') ?: ['proposals' => []]);
            break;

        case 'tally':
            $id = intval($_GET['id'] ?? 0);
            if (!$id) die(json_encode([]));
            echo json_encode(apiCall('/cosmos/gov/v1/proposals/' . $id . '/tally') ?: []);
            break;

        case 'broadcast':
            if (empty($in['tx_bytes'])) die(json_encode(['error' => 'Missing tx_bytes']));
            if (!preg_match('/^[A-Za-z0-9+\/=]+$/', $in['tx_bytes']) || strlen($in['tx_bytes']) > 100000)
                die(json_encode(['error' => 'Invalid tx_bytes']));
            echo json_encode(apiPost('/cosmos/tx/v1beta1/txs', [
                'tx_bytes' => $in['tx_bytes'],
                'mode' => 'BROADCAST_MODE_SYNC'
            ]));
            break;

        default:
            echo json_encode(['error' => 'Unknown']);
    }
    exit;
}

/* ======================== SHARED RENDERING ======================== */

function renderHead($title = 'JAY Wallet') { ?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=no,viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="theme-color" content="#0B0B1E">
<meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self' 'unsafe-inline' https://esm.sh; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' https://esm.sh http://152.53.195.5:1317 http://152.53.195.105:1317 http://152.53.194.128:1317; font-src 'self'">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-title" content="JAY Wallet">
<meta name="application-name" content="JAY Wallet">
<link rel="manifest" href="manifest.json">
<link rel="apple-touch-icon" href="logo.png">
<title><?= htmlspecialchars($title) ?></title>
<link rel="icon" type="image/png" href="logo.png">
<script>if('serviceWorker' in navigator)navigator.serviceWorker.register('sw.js');</script>
<style>
:root{--bg:#09090f;--bg2:#13131d;--bg3:#1a1a2e;--card:rgba(255,255,255,0.05);--card-h:rgba(255,255,255,0.08);--card-b:rgba(255,255,255,0.08);--accent:#AB7BFF;--accent2:#C4A1FF;--accent-d:#7C3AED;--grad:linear-gradient(135deg,#7C3AED 0%,#AB7BFF 50%,#C4A1FF 100%);--grad2:linear-gradient(135deg,#4F46E5 0%,#7C3AED 100%);--text:#F5F5FF;--dim:#9898B8;--muted:#5C5C7A;--green:#34D399;--red:#F87171;--orange:#FBBF24;--r:20px;--rs:14px;--rr:28px}
*{margin:0;padding:0;box-sizing:border-box;-webkit-tap-highlight-color:transparent}
html{touch-action:manipulation;overscroll-behavior:none;overflow:hidden;height:100%}
body{font-family:-apple-system,BlinkMacSystemFont,'SF Pro Display','Inter','Segoe UI',sans-serif;background:var(--bg);color:var(--text);font-size:16px;line-height:1.5;height:100%;overflow-x:hidden;overflow-y:auto;overscroll-behavior-y:none;-webkit-font-smoothing:antialiased}

.app{max-width:480px;margin:0 auto;padding:calc(64px + env(safe-area-inset-top,0px)) 20px calc(80px + env(safe-area-inset-bottom,0px));min-height:100vh}

/* Header - Phantom style frosted glass */
.header{position:fixed;top:0;left:0;right:0;height:calc(56px + env(safe-area-inset-top,0px));padding:env(safe-area-inset-top,0px) 20px 0;display:flex;align-items:center;justify-content:center;background:rgba(9,9,15,0.85);backdrop-filter:blur(24px) saturate(180%);-webkit-backdrop-filter:blur(24px) saturate(180%);border-bottom:1px solid rgba(255,255,255,0.06);z-index:100}
.header h1{font-size:1.05rem;font-weight:700;letter-spacing:-0.01em;display:flex;align-items:center;gap:8px}
.header img{width:26px;height:26px;border-radius:50%;object-fit:cover}

/* Bottom nav - MetaMask tab style */
.bnav{position:fixed;bottom:0;left:0;right:0;height:calc(72px + env(safe-area-inset-bottom,0px));padding-bottom:env(safe-area-inset-bottom,0px);display:flex;align-items:center;justify-content:space-around;background:rgba(9,9,15,0.92);backdrop-filter:blur(24px) saturate(180%);-webkit-backdrop-filter:blur(24px) saturate(180%);border-top:1px solid rgba(255,255,255,0.06);z-index:100}
.ni{display:flex;flex-direction:column;align-items:center;gap:4px;text-decoration:none;color:var(--muted);font-size:0.62rem;font-weight:600;letter-spacing:0.02em;padding:8px 16px;border-radius:12px;transition:all .25s ease}
.ni.on{color:var(--accent2);background:rgba(171,123,255,0.08)}
.ni svg{width:22px;height:22px;transition:transform .2s}
.ni:active svg{transform:scale(0.9)}

/* Balance card - Phantom gradient style */
.card{background:var(--card);border:1px solid var(--card-b);border-radius:var(--r);padding:20px;margin-bottom:14px;transition:all .2s}
.bc{text-align:center;padding:32px 24px;background:linear-gradient(160deg,rgba(124,58,237,0.12) 0%,rgba(171,123,255,0.06) 50%,rgba(79,70,229,0.08) 100%);border:1px solid rgba(171,123,255,0.15);border-radius:var(--rr);position:relative;overflow:hidden}
.bc::before{content:'';position:absolute;top:-50%;right:-50%;width:100%;height:100%;background:radial-gradient(circle,rgba(171,123,255,0.08) 0%,transparent 70%);pointer-events:none}
.bc .amt{font-size:2.8rem;font-weight:800;letter-spacing:-0.03em;margin-bottom:2px;background:linear-gradient(135deg,#fff 30%,var(--accent2) 100%);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text}
.bc .dn{color:var(--dim);font-size:0.85rem;font-weight:600;display:flex;align-items:center;justify-content:center;gap:6px}
.bc .dn img{width:18px;height:18px;border-radius:50%}

/* Action buttons - MetaMask circle style */
.arow{display:flex;justify-content:center;gap:32px;padding:20px 0 12px}
.abtn{display:flex;flex-direction:column;align-items:center;gap:8px;background:none;border:none;color:var(--text);cursor:pointer;transition:transform .2s}
.abtn:active{transform:scale(0.92)}
.abtn .ic{width:52px;height:52px;border-radius:50%;background:var(--grad2);display:flex;align-items:center;justify-content:center;box-shadow:0 4px 20px rgba(124,58,237,0.3);transition:all .25s}
.abtn:active .ic{box-shadow:0 2px 10px rgba(124,58,237,0.2)}
.abtn .ic svg{color:#fff;stroke:#fff}
.abtn span{font-size:0.72rem;font-weight:600;color:var(--dim)}

/* Buttons - Phantom rounded style */
.btn{display:flex;align-items:center;justify-content:center;gap:8px;width:100%;padding:16px;border-radius:var(--rs);font-size:0.92rem;font-weight:700;cursor:pointer;border:none;transition:all .2s;letter-spacing:-0.01em}
.btn:active{transform:scale(0.98)}
.btn:disabled{opacity:0.35;pointer-events:none}
.btn-p{background:var(--grad2);color:#fff;box-shadow:0 4px 16px rgba(124,58,237,0.25)}
.btn-p:active{box-shadow:0 2px 8px rgba(124,58,237,0.2)}
.btn-s{background:rgba(255,255,255,0.06);color:var(--text);border:1px solid rgba(255,255,255,0.1)}
.btn-s:hover{background:rgba(255,255,255,0.09)}
.btn-d{background:rgba(248,113,113,0.1);color:var(--red);border:1px solid rgba(248,113,113,0.2)}
.btn-sm{padding:10px 16px;font-size:0.82rem;width:auto;border-radius:10px}

/* Form inputs - MetaMask style */
.ig{margin-bottom:16px}
.ig label{display:block;font-size:0.76rem;font-weight:600;color:var(--dim);margin-bottom:6px;letter-spacing:0.02em}
.inp{width:100%;padding:14px 16px;background:rgba(255,255,255,0.04);border:1.5px solid rgba(255,255,255,0.08);border-radius:var(--rs);color:var(--text);font-size:0.9rem;outline:none;transition:all .25s;font-family:inherit}
.inp:focus{border-color:var(--accent);background:rgba(171,123,255,0.04);box-shadow:0 0 0 3px rgba(171,123,255,0.08)}
.inp::placeholder{color:var(--muted)}

/* Modal - Phantom bottom sheet */
.mo{display:none;position:fixed;inset:0;background:rgba(0,0,0,0.65);backdrop-filter:blur(8px);z-index:200;align-items:flex-end;justify-content:center}
.mo.show{display:flex}
.modal{width:100%;max-width:480px;max-height:92vh;overflow-y:auto;background:var(--bg2);border-radius:var(--rr) var(--rr) 0 0;padding:8px 20px calc(24px + env(safe-area-inset-bottom,0px));animation:su .35s cubic-bezier(0.32,0.72,0,1)}
.modal::before{content:'';display:block;width:36px;height:4px;border-radius:2px;background:rgba(255,255,255,0.15);margin:8px auto 20px}
@keyframes su{from{transform:translateY(100%)}to{transform:translateY(0)}}
.mh{display:flex;align-items:center;justify-content:space-between;margin-bottom:20px}
.mh h2{font-size:1.1rem;font-weight:700;letter-spacing:-0.01em}
.mc{width:32px;height:32px;border-radius:50%;background:rgba(255,255,255,0.06);border:none;color:var(--dim);font-size:1rem;cursor:pointer;display:flex;align-items:center;justify-content:center;transition:background .2s}
.mc:active{background:rgba(255,255,255,0.1)}

/* List items */
.li{display:flex;align-items:center;justify-content:space-between;padding:14px 0;border-bottom:1px solid rgba(255,255,255,0.05)}
.li:last-child{border-bottom:none}

/* Toast - Phantom notification */
.toast{position:fixed;bottom:calc(88px + env(safe-area-inset-bottom,0px));left:20px;right:20px;max-width:440px;margin:0 auto;padding:14px 20px;border-radius:var(--rs);font-size:0.82rem;font-weight:600;text-align:center;z-index:300;animation:fiu .35s cubic-bezier(0.32,0.72,0,1);display:none;backdrop-filter:blur(16px)}
.toast.show{display:block}
.t-ok{background:rgba(52,211,153,0.12);color:var(--green);border:1px solid rgba(52,211,153,0.2)}
.t-err{background:rgba(248,113,113,0.12);color:var(--red);border:1px solid rgba(248,113,113,0.2)}
@keyframes fiu{from{opacity:0;transform:translateY(16px)}to{opacity:1;transform:translateY(0)}}

/* Mnemonic grid */
.mg{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin:16px 0}
.mw{background:rgba(255,255,255,0.04);border:1px solid rgba(255,255,255,0.08);border-radius:10px;padding:10px 8px;text-align:center;font-size:0.78rem;font-weight:600;transition:background .2s}
.mw .n{color:var(--muted);font-size:0.6rem;display:block;margin-bottom:2px}

/* Spinner */
.spin{width:24px;height:24px;border:2.5px solid rgba(255,255,255,0.06);border-top:2.5px solid var(--accent);border-radius:50%;animation:sp .7s linear infinite;margin:24px auto}
@keyframes sp{to{transform:rotate(360deg)}}

/* Validator item - Phantom list style */
.vi{display:flex;align-items:center;gap:12px;padding:14px;margin-bottom:8px;background:rgba(255,255,255,0.03);border:1px solid rgba(255,255,255,0.06);border-radius:var(--rs);cursor:pointer;transition:all .25s}
.vi:active{background:rgba(255,255,255,0.06);border-color:rgba(171,123,255,0.3)}
.vr{width:36px;height:36px;border-radius:50%;background:linear-gradient(135deg,rgba(124,58,237,0.2),rgba(171,123,255,0.1));color:var(--accent2);display:flex;align-items:center;justify-content:center;font-size:0.72rem;font-weight:800;flex-shrink:0;overflow:hidden}
.vinfo{flex:1;min-width:0}
.vn{font-weight:700;font-size:0.88rem;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.vp{font-size:0.73rem;color:var(--dim);margin-top:2px}

/* Section title */
.stit{font-size:0.72rem;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:0.1em;margin-bottom:12px}

/* Empty state */
.empty{text-align:center;padding:48px 20px;color:var(--muted)}
.empty .ei{font-size:2.4rem;margin-bottom:10px;filter:grayscale(0.3)}

/* Status tags */
.tag{display:inline-flex;align-items:center;gap:4px;padding:4px 10px;border-radius:100px;font-size:0.66rem;font-weight:700;letter-spacing:0.02em}
.tag-g{background:rgba(52,211,153,0.1);color:var(--green)}

/* Auth page - Phantom onboarding style */
.auth-page{display:flex;flex-direction:column;align-items:center;justify-content:center;min-height:100vh;padding:40px 24px;text-align:center;background:radial-gradient(ellipse at 50% 0%,rgba(124,58,237,0.1) 0%,transparent 60%)}
.auth-logo{width:96px;height:96px;border-radius:28px;margin-bottom:20px;box-shadow:0 0 60px rgba(124,58,237,0.25),0 0 120px rgba(171,123,255,0.1);transition:transform .3s}
.auth-logo:hover{transform:scale(1.05)}
.auth-t{font-size:1.6rem;font-weight:800;letter-spacing:-0.02em;margin-bottom:4px}
.auth-s{color:var(--dim);font-size:0.88rem;margin-bottom:32px}

/* Step indicators - MetaMask progress */
.steps{display:flex;gap:8px;justify-content:center;margin-bottom:24px}
.sd{width:32px;height:4px;border-radius:2px;background:rgba(255,255,255,0.08);transition:all .3s}
.sd.on{background:var(--grad);width:40px}
.sd.ok{background:var(--green)}

.fade-in{animation:fi .5s cubic-bezier(0.32,0.72,0,1)}
@keyframes fi{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:translateY(0)}}

/* Address box - Phantom mono style */
.addr-box{background:rgba(255,255,255,0.03);border:1px solid rgba(255,255,255,0.06);border-radius:var(--rs);padding:14px 16px;word-break:break-all;font-family:'SF Mono','Fira Code','JetBrains Mono',monospace;font-size:0.78rem;text-align:center;margin:12px 0;color:var(--dim);letter-spacing:0.01em}

/* QR code */
.qr-wrap{display:flex;justify-content:center;margin:20px 0}
.qr-wrap img{border-radius:16px;background:#fff;padding:14px}

/* Copy button */
.copy-btn{background:rgba(255,255,255,0.05);border:1px solid rgba(255,255,255,0.08);color:var(--accent2);padding:12px 20px;border-radius:var(--rs);font-size:0.82rem;font-weight:600;cursor:pointer;transition:all .2s;display:flex;align-items:center;justify-content:center;gap:6px;width:100%}
.copy-btn:active{transform:scale(0.97);background:rgba(171,123,255,0.08)}

/* Row card - info rows */
.rcard{background:rgba(255,255,255,0.03);border:1px solid rgba(255,255,255,0.06);border-radius:var(--rs);padding:16px;margin-bottom:10px;display:flex;align-items:center;justify-content:space-between;transition:all .2s}
.rcard:active{background:rgba(255,255,255,0.05)}
.rcard .rl{font-size:0.82rem;color:var(--dim);font-weight:600}
.rcard .rv{font-size:0.95rem;font-weight:700}

/* Warning */
.warn{background:rgba(251,191,36,0.08);border:1px solid rgba(251,191,36,0.15);color:var(--orange);border-radius:var(--rs);padding:14px 16px;font-size:0.8rem;margin-bottom:16px;line-height:1.6}
.hidden{display:none}
</style>
<script type="importmap">
{"imports":{"@scure/bip39":"https://esm.sh/@scure/bip39@1.5.4","@scure/bip39/wordlists/english":"https://esm.sh/@scure/bip39@1.5.4/wordlists/english","@scure/bip32":"https://esm.sh/@scure/bip32@1.6.2","@noble/curves/secp256k1":"https://esm.sh/@noble/curves@1.8.1/secp256k1","@noble/hashes/sha256":"https://esm.sh/@noble/hashes@1.7.1/sha256","@noble/hashes/ripemd160":"https://esm.sh/@noble/hashes@1.7.1/ripemd160","@noble/hashes/pbkdf2":"https://esm.sh/@noble/hashes@1.7.1/pbkdf2","@noble/ciphers/aes":"https://esm.sh/@noble/ciphers@1.2.1/aes","bech32":"https://esm.sh/bech32@2.0.0"}}
</script>
</head>
<body>
<?php }

function renderNav($active = 'wallet') { ?>
<nav class="bnav">
  <a href="wallet.php" class="ni <?= $active==='wallet'?'on':'' ?>">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="<?= $active==='wallet'?'2.5':'1.8' ?>"><path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>
    Wallet
  </a>
  <a href="txs.php" class="ni <?= $active==='activity'?'on':'' ?>">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="<?= $active==='activity'?'2.5':'1.8' ?>"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>
    Activity
  </a>
  <a href="staking.php" class="ni <?= $active==='stake'?'on':'' ?>">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="<?= $active==='stake'?'2.5':'1.8' ?>"><polygon points="12 2 2 7 12 12 22 7"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/></svg>
    Stake
  </a>
  <a href="gov.php" class="ni <?= $active==='gov'?'on':'' ?>">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="<?= $active==='gov'?'2.5':'1.8' ?>"><path d="M3 21h18M3 10h18M5 6l7-3 7 3M4 10v11M20 10v11M8 14v3M12 14v3M16 14v3"/></svg>
    Gov
  </a>
  <a href="backup.php" class="ni <?= $active==='backup'?'on':'' ?>">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="<?= $active==='backup'?'2.5':'1.8' ?>"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 01-2.83 2.83l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 01-4 0v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 01-2.83-2.83l.06-.06A1.65 1.65 0 004.68 15a1.65 1.65 0 00-1.51-1H3a2 2 0 010-4h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 012.83-2.83l.06.06A1.65 1.65 0 009 4.68a1.65 1.65 0 001-1.51V3a2 2 0 014 0v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 012.83 2.83l-.06.06A1.65 1.65 0 0019.4 9a1.65 1.65 0 001.51 1H21a2 2 0 010 4h-.09a1.65 1.65 0 00-1.51 1z"/></svg>
    Settings
  </a>
</nav>
<?php }

function renderFoot() { echo '</body></html>'; }

function getJSCrypto() {
    return <<<'JSEND'
import{generateMnemonic,mnemonicToSeedSync,validateMnemonic}from'@scure/bip39';
import{wordlist}from'@scure/bip39/wordlists/english';
import{HDKey}from'@scure/bip32';
import{secp256k1}from'@noble/curves/secp256k1';
import{sha256}from'@noble/hashes/sha256';
import{ripemd160}from'@noble/hashes/ripemd160';
import{pbkdf2}from'@noble/hashes/pbkdf2';
import{gcm}from'@noble/ciphers/aes';
import{bech32}from'bech32';

/* ---- Protobuf encoder ---- */
class PB{
  constructor(){this.b=[];}
  varint(v){v=Math.floor(Number(v)||0);if(v<0)v=0;do{let byte=v%128;v=Math.floor(v/128);if(v>0)byte+=128;this.b.push(byte);}while(v>0);return this;}
  tag(fn,wt){return this.varint((fn<<3)|wt);}
  bytes(fn,d){if(typeof d==='string')d=new TextEncoder().encode(d);this.tag(fn,2);this.varint(d.length);for(const x of d)this.b.push(x);return this;}
  uint64(fn,v){v=Math.floor(Number(v)||0);if(v===0)return this;this.tag(fn,0);this.varint(v);return this;}
  done(){return new Uint8Array(this.b);}
}
function coin(d,a){return new PB().bytes(1,d).bytes(2,String(a)).done();}
function any(url,val){return new PB().bytes(1,url).bytes(2,val).done();}
function msgSend(from,to,denom,amount){return{typeUrl:'/cosmos.bank.v1beta1.MsgSend',value:new PB().bytes(1,from).bytes(2,to).bytes(3,coin(denom,amount)).done()};}
function msgDelegate(del,val,denom,amount){return{typeUrl:'/cosmos.staking.v1beta1.MsgDelegate',value:new PB().bytes(1,del).bytes(2,val).bytes(3,coin(denom,amount)).done()};}
function msgUndelegate(del,val,denom,amount){return{typeUrl:'/cosmos.staking.v1beta1.MsgUndelegate',value:new PB().bytes(1,del).bytes(2,val).bytes(3,coin(denom,amount)).done()};}
function msgWithdrawRewards(del,val){return{typeUrl:'/cosmos.distribution.v1beta1.MsgWithdrawDelegatorReward',value:new PB().bytes(1,del).bytes(2,val).done()};}
function msgRedelegate(del,valSrc,valDst,denom,amount){return{typeUrl:'/cosmos.staking.v1beta1.MsgBeginRedelegate',value:new PB().bytes(1,del).bytes(2,valSrc).bytes(3,valDst).bytes(4,coin(denom,amount)).done()};}
function msgVote(id,voter,option){return{typeUrl:'/cosmos.gov.v1beta1.MsgVote',value:new PB().uint64(1,id).bytes(2,voter).uint64(3,option).done()};}

function buildTx(msgs,memo,pubKey,seq,feeAmt,gas){
  const body=new PB();msgs.forEach(m=>body.bytes(1,any(m.typeUrl,m.value)));if(memo)body.bytes(2,memo);
  const bodyBytes=body.done();
  const pk=new PB().bytes(1,pubKey).done();
  const pkAny=any('/cosmos.crypto.secp256k1.PubKey',pk);
  const modeInfo=new PB().bytes(1,new PB().uint64(1,1).done()).done();
  const signerInfo=new PB().bytes(1,pkAny).bytes(2,modeInfo).uint64(3,seq).done();
  const fee=new PB().bytes(1,coin('ujay',feeAmt)).uint64(2,gas).done();
  const authInfo=new PB().bytes(1,signerInfo).bytes(2,fee).done();
  return{bodyBytes,authInfoBytes:authInfo};
}

/* ---- Key derivation ---- */
function deriveKeys(mnemonic){
  const seed=mnemonicToSeedSync(mnemonic);
  const hd=HDKey.fromMasterSeed(seed).derive("m/44'/118'/0'/0/0");
  const priv=hd.privateKey;const pub=secp256k1.getPublicKey(priv,true);
  const h=ripemd160(sha256(pub));
  return{priv,pub,addr:bech32.encode('yjay',bech32.toWords(h))};
}

/* ---- Client-side AES with versioned PBKDF2 ---- */
function deriveAesKey(password,salt,iters){
  return pbkdf2(sha256,new TextEncoder().encode(password),salt,{c:iters,dkLen:32});
}
function aesEncrypt(plaintext,password){
  const salt=crypto.getRandomValues(new Uint8Array(16));
  const key=deriveAesKey(password,salt,600000);
  const iv=crypto.getRandomValues(new Uint8Array(12));
  const cipher=gcm(key,iv);
  const ct=cipher.encrypt(new TextEncoder().encode(plaintext));
  const buf=new Uint8Array(16+12+ct.length);
  buf.set(salt);buf.set(iv,16);buf.set(ct,28);
  return 'v2:'+btoa(String.fromCharCode(...buf));
}
function aesDecrypt(data,password){
  let iters=600000,raw=data;
  if(data.startsWith('v2:'))raw=data.slice(3);
  else iters=100000;
  try{
    const bytes=Uint8Array.from(atob(raw),c=>c.charCodeAt(0));
    const salt=bytes.slice(0,16),iv=bytes.slice(16,28),ct=bytes.slice(28);
    const key=deriveAesKey(password,salt,iters);
    const cipher=gcm(key,iv);
    return new TextDecoder().decode(cipher.decrypt(ct));
  }catch{return null;}
}

/* ---- localStorage self-custody ---- */
function getVault(){return localStorage.getItem('jay_vault');}
function getAddr(){return localStorage.getItem('jay_addr');}
function saveVault(encrypted,addr){localStorage.setItem('jay_vault',encrypted);localStorage.setItem('jay_addr',addr);}
function vaultExists(){return!!localStorage.getItem('jay_vault');}
function clearVault(){localStorage.removeItem('jay_vault');localStorage.removeItem('jay_addr');}

/* ---- sessionStorage (tab-scoped, auto-clears on close) ---- */
function setSession(pw){sessionStorage.setItem('jay_pw',pw);}
function getSession(){return sessionStorage.getItem('jay_pw');}
function clearSession(){sessionStorage.removeItem('jay_pw');}
function isLoggedIn(){return!!getSession()&&vaultExists();}

function unlockWallet(){
  const pw=getSession();if(!pw)return null;
  const vault=getVault();if(!vault)return null;
  const json=aesDecrypt(vault,pw);
  if(!json){clearSession();return null;}
  if(!vault.startsWith('v2:')){const d=JSON.parse(json);saveVault(aesEncrypt(json,pw),d.addr);}
  return JSON.parse(json);
}

/* ---- Signing ---- */
async function getAccountInfo(addr){
  try{const r=await fetch('api.php?a=account&addr='+addr);const d=await r.json();
    if(d.account)return{num:parseInt(d.account.account_number||'0'),seq:parseInt(d.account.sequence||'0')};
  }catch{}return{num:0,seq:0};
}

async function signAndBroadcast(mnemonic,msgs,memo='',feeAmt=500,gas=200000){
  const{priv,pub,addr}=deriveKeys(mnemonic);
  const acc=await getAccountInfo(addr);
  const{bodyBytes,authInfoBytes}=buildTx(msgs,memo,pub,acc.seq,feeAmt,gas);
  const signDoc=new PB().bytes(1,bodyBytes).bytes(2,authInfoBytes).bytes(3,'thejaynetwork').uint64(4,acc.num).done();
  const hash=sha256(signDoc);
  const sig=secp256k1.sign(hash,priv);
  const txRaw=new PB().bytes(1,bodyBytes).bytes(2,authInfoBytes).bytes(3,sig.toCompactRawBytes()).done();
  const b64=btoa(String.fromCharCode(...txRaw));
  const res=await fetch('api.php?a=broadcast',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({tx_bytes:b64})});
  return res.json();
}

/* ---- Helpers ---- */
function newMnemonic(){return generateMnemonic(wordlist,256);}
function validMn(mn){return validateMnemonic(mn,wordlist);}
function addrFromMn(mn){return deriveKeys(mn).addr;}
function fmtJay(ujay){return(parseInt(ujay||0)/1e6).toLocaleString(undefined,{maximumFractionDigits:6});}
function esc(s){const d=document.createElement('div');d.textContent=String(s);return d.innerHTML;}

function toast(msg,ok=true){
  let t=document.getElementById('toast');
  if(!t){t=document.createElement('div');t.id='toast';document.body.appendChild(t);}
  t.className='toast show '+(ok?'t-ok':'t-err');t.textContent=msg;
  setTimeout(()=>t.classList.remove('show'),3000);
}

function requireAuth(){
  if(!isLoggedIn()){window.location.href='index.php';return null;}
  return unlockWallet();
}

/* ---- Brute-force protection ---- */
const _MAX_ATTEMPTS=5,_LOCKOUT_MS=300000;
function getLoginAttempts(){
  try{const d=JSON.parse(localStorage.getItem('jay_la')||'{}');
    if(d.u&&Date.now()>=d.u){localStorage.removeItem('jay_la');return{c:0};}
    return d;
  }catch{return{c:0};}
}
function recordFailedAttempt(){
  const d=getLoginAttempts();d.c=(d.c||0)+1;
  if(d.c>=_MAX_ATTEMPTS)d.u=Date.now()+_LOCKOUT_MS;
  localStorage.setItem('jay_la',JSON.stringify(d));return d;
}
function clearLoginAttempts(){localStorage.removeItem('jay_la');}
function isLockedOut(){const d=getLoginAttempts();return!!(d.u&&Date.now()<d.u);}
function lockoutSeconds(){const d=getLoginAttempts();return d.u?Math.max(0,Math.ceil((d.u-Date.now())/1000)):0;}

/* ---- Auto-lock (5 min inactivity) ---- */
let _alt;
function setupAutoLock(){
  const reset=()=>{clearTimeout(_alt);if(isLoggedIn())_alt=setTimeout(()=>{clearSession();window.location.href='index.php';},300000);};
  ['click','keydown','touchstart','scroll'].forEach(e=>document.addEventListener(e,reset,{passive:true}));
  reset();
}

/* ---- Address validation ---- */
function isValidAddr(addr,prefix='yjay'){
  try{const d=bech32.decode(addr);return d.prefix===prefix&&d.words.length>0;}catch{return false;}
}

export{newMnemonic,validMn,addrFromMn,deriveKeys,signAndBroadcast,msgSend,msgDelegate,msgUndelegate,msgWithdrawRewards,msgRedelegate,msgVote,fmtJay,esc,toast,
  aesEncrypt,aesDecrypt,getVault,getAddr,saveVault,vaultExists,clearVault,setSession,getSession,clearSession,isLoggedIn,unlockWallet,requireAuth,
  getLoginAttempts,recordFailedAttempt,clearLoginAttempts,isLockedOut,lockoutSeconds,setupAutoLock,isValidAddr};
JSEND;
}
