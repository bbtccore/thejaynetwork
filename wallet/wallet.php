<?php require_once 'api.php'; renderHead('JAY Wallet'); ?>

<div class="header">
  <h1><img src="logo.png" alt="">JAY Wallet</h1>
</div>

<div class="app fade-in hidden" id="main">
  <!-- Balance card -->
  <div class="bc">
    <div style="font-size:0.78rem;color:var(--dim);font-weight:600;margin-bottom:8px">Total Balance</div>
    <div class="amt" id="balance"><div class="spin"></div></div>
    <div class="dn">JAY</div>
  </div>

  <!-- Action buttons -->
  <div class="arow">
    <button class="abtn" onclick="openModal('sendModal')">
      <div class="ic"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="7" y1="17" x2="17" y2="7"/><polyline points="7 7 17 7 17 17"/></svg></div>
      <span>Send</span>
    </button>
    <button class="abtn" onclick="openModal('recvModal')">
      <div class="ic"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="17" y1="7" x2="7" y2="17"/><polyline points="17 17 7 17 7 7"/></svg></div>
      <span>Receive</span>
    </button>
    <a class="abtn" href="staking.php" style="text-decoration:none">
      <div class="ic"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polygon points="12 2 2 7 12 12 22 7"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/></svg></div>
      <span>Stake</span>
    </a>
  </div>

  <!-- Portfolio summary -->
  <div class="stit" style="margin-top:8px">Portfolio</div>
  <div class="rcard" style="margin-bottom:10px">
    <div style="display:flex;align-items:center;gap:12px">
      <div style="width:38px;height:38px;border-radius:50%;background:rgba(52,211,153,0.1);display:flex;align-items:center;justify-content:center;flex-shrink:0">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--green)" stroke-width="2"><polygon points="12 2 2 7 12 12 22 7"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/></svg>
      </div>
      <div><div class="rl" style="font-size:0.78rem;color:var(--dim)">Staked</div></div>
    </div>
    <div class="rv" id="stakedAmt" style="color:var(--green)">—</div>
  </div>
  <div class="rcard">
    <div style="display:flex;align-items:center;gap:12px">
      <div style="width:38px;height:38px;border-radius:50%;background:rgba(171,123,255,0.1);display:flex;align-items:center;justify-content:center;flex-shrink:0">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--accent2)" stroke-width="2"><path d="M12 2v20M17 5H9.5a3.5 3.5 0 000 7h5a3.5 3.5 0 010 7H6"/></svg>
      </div>
      <div><div class="rl" style="font-size:0.78rem;color:var(--dim)">Rewards</div></div>
    </div>
    <div class="rv" id="rewardsAmt" style="color:var(--accent2)">—</div>
  </div>

</div>

<!-- Send Modal -->
<div class="mo" id="sendModal" onclick="if(event.target===this)closeModal('sendModal')">
  <div class="modal">
    <div class="mh"><h2>Send JAY</h2><button class="mc" onclick="closeModal('sendModal')">✕</button></div>
    <div class="ig"><label>Recipient Address</label><div style="display:flex;gap:8px"><input type="text" class="inp" id="sendTo" placeholder="yjay1..." style="flex:1"><button type="button" class="btn btn-s" onclick="startScan()" style="width:48px;padding:0;flex-shrink:0" title="Scan QR"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 7V4h3M20 7V4h-3M4 17v3h3M20 17v3h-3"/><rect x="7" y="7" width="10" height="10" rx="1"/></svg></button></div></div>
    <div class="ig"><label>Amount (JAY)</label><input type="number" class="inp" id="sendAmt" placeholder="0.000000" step="0.000001" min="0"></div>
    <div class="ig"><label>Memo (optional)</label><input type="text" class="inp" id="sendMemo" placeholder=""></div>
    <div style="background:rgba(255,255,255,0.03);border:1px solid rgba(255,255,255,0.06);border-radius:var(--rs);padding:14px 16px;margin-bottom:16px">
      <div style="display:flex;justify-content:space-between;font-size:0.8rem"><span style="color:var(--dim)">Fee</span><span>0.000500 JAY</span></div>
      <div style="display:flex;justify-content:space-between;font-size:0.8rem;margin-top:6px"><span style="color:var(--dim)">Gas</span><span>200,000</span></div>
    </div>
    <button class="btn btn-p" id="sendBtn" onclick="doSend()">Send</button>
  </div>
</div>

<!-- Receive Modal -->
<div class="mo" id="recvModal" onclick="if(event.target===this)closeModal('recvModal')">
  <div class="modal" style="text-align:center">
    <div class="mh"><h2>Receive JAY</h2><button class="mc" onclick="closeModal('recvModal')">✕</button></div>
    <div class="qr-wrap"><img id="recvQR" width="180" height="180" alt="QR"></div>
    <div class="addr-box" id="recvAddr"></div>
    <button class="copy-btn" onclick="copyAddr()">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/></svg>
      Copy Address
    </button>
  </div>
</div>

<div id="qrOverlay" style="display:none;position:fixed;inset:0;background:#000;z-index:300;flex-direction:column;align-items:center;justify-content:center">
  <button onclick="stopScan()" style="position:absolute;top:max(16px,env(safe-area-inset-top));right:16px;z-index:301;background:rgba(255,255,255,0.15);border:none;color:#fff;width:44px;height:44px;border-radius:50%;font-size:1.2rem;cursor:pointer;backdrop-filter:blur(8px)">✕</button>
  <video id="qrVideo" autoplay playsinline muted style="width:100%;height:100%;object-fit:cover"></video>
  <div style="position:absolute;width:220px;height:220px;border:2px solid rgba(171,123,255,0.7);border-radius:20px;pointer-events:none;box-shadow:0 0 40px rgba(171,123,255,0.15)"></div>
  <div style="position:absolute;bottom:max(100px,calc(env(safe-area-inset-bottom) + 80px));color:#fff;font-size:0.85rem;font-weight:600;text-align:center;opacity:0.8">Point camera at a QR code</div>
  <canvas id="qrCanvas" style="display:none"></canvas>
</div>

<div id="toast"></div>
<?php renderNav('wallet'); ?>

<script type="module">
<?= getJSCrypto() ?>

let ADDR = '', mnemonic = '', balanceUjay = 0;

async function genLocalQR(text) {
  const mod = await import('https://esm.sh/qrcode-generator@1.4.4');
  const qr = mod.default(0, 'M');
  qr.addData(text);
  qr.make();
  return qr.createDataURL(4, 8);
}

async function init() {
  const w = requireAuth();
  if (!w) return;
  mnemonic = w.mnemonic;
  ADDR = w.addr || getAddr();
  document.getElementById('recvAddr').textContent = ADDR;
  genLocalQR(ADDR).then(url => document.getElementById('recvQR').src = url).catch(() => {});
  document.getElementById('main').classList.remove('hidden');
  loadBalance();
  loadStakeInfo();
  setupAutoLock();
}
window.addEventListener('beforeunload', () => { mnemonic = ''; });

async function loadBalance() {
  try {
    const r = await fetch('api.php?a=balance&addr=' + ADDR);
    const d = await r.json();
    const ujay = (d.balances || []).find(b => b.denom === 'ujay');
    balanceUjay = parseInt(ujay?.amount || '0');
    document.getElementById('balance').textContent = fmtJay(balanceUjay);
  } catch { balanceUjay = 0; document.getElementById('balance').textContent = '0'; }
}

async function loadStakeInfo() {
  try {
    const r = await fetch('api.php?a=delegations&addr=' + ADDR); const d = await r.json();
    let t = 0; (d.delegation_responses || []).forEach(x => t += parseInt(x.balance?.amount || 0));
    document.getElementById('stakedAmt').textContent = fmtJay(t) + ' JAY';
  } catch { document.getElementById('stakedAmt').textContent = '0 JAY'; }
  try {
    const r = await fetch('api.php?a=rewards&addr=' + ADDR); const d = await r.json();
    let t = 0; (d.total || []).forEach(x => { if (x.denom === 'ujay') t += parseFloat(x.amount || 0); });
    document.getElementById('rewardsAmt').textContent = fmtJay(Math.floor(t)) + ' JAY';
  } catch { document.getElementById('rewardsAmt').textContent = '0 JAY'; }
}

window.openModal = id => document.getElementById(id).classList.add('show');
window.closeModal = id => document.getElementById(id).classList.remove('show');

window.doSend = async function() {
  const to = document.getElementById('sendTo').value.trim();
  const amt = parseFloat(document.getElementById('sendAmt').value);
  const memo = document.getElementById('sendMemo').value.trim();
  if (!isValidAddr(to)) return toast('Invalid address', false);
  if (!amt || amt <= 0) return toast('Invalid amount', false);
  const sendUjay = Math.floor(amt * 1e6);
  const feeUjay = 500;
  if (balanceUjay === 0) return toast('No balance available', false);
  if (sendUjay + feeUjay > balanceUjay) return toast('Insufficient balance (need ' + fmtJay(sendUjay + feeUjay) + ' JAY incl. fee)', false);
  const btn = document.getElementById('sendBtn');
  btn.disabled = true; btn.textContent = 'Signing...';
  try {
    const msg = msgSend(ADDR, to, 'ujay', Math.floor(amt * 1e6));
    const result = await signAndBroadcast(mnemonic, [msg], memo, 500, 200000);
    if (result.tx_response?.code === 0) {
      toast('Transaction sent!'); closeModal('sendModal');
      document.getElementById('sendTo').value = ''; document.getElementById('sendAmt').value = '';
      setTimeout(loadBalance, 3000);
    } else toast(result.tx_response?.raw_log || 'Failed', false);
  } catch (e) { toast('Error: ' + e.message, false); }
  btn.disabled = false; btn.textContent = 'Send';
};

window.copyAddr = () => navigator.clipboard.writeText(ADDR).then(() => toast('Address copied!'));

let _scanStream = null, _scanTimer = null;
window.startScan = async function() {
  try {
    _scanStream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } });
    const video = document.getElementById('qrVideo');
    video.srcObject = _scanStream;
    document.getElementById('qrOverlay').style.display = 'flex';
    const { default: jsQR } = await import('https://esm.sh/jsqr@1.4.0');
    const canvas = document.getElementById('qrCanvas');
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    _scanTimer = setInterval(() => {
      if (video.readyState < video.HAVE_ENOUGH_DATA) return;
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      ctx.drawImage(video, 0, 0);
      const img = ctx.getImageData(0, 0, canvas.width, canvas.height);
      const code = jsQR(img.data, img.width, img.height);
      if (code && code.data) {
        let addr = code.data.trim();
        if (addr.startsWith('yjay')) {
          document.getElementById('sendTo').value = addr;
          stopScan();
          toast('Address scanned!');
        }
      }
    }, 250);
  } catch {
    toast('Camera not available', false);
  }
};
window.stopScan = function() {
  clearInterval(_scanTimer); _scanTimer = null;
  if (_scanStream) { _scanStream.getTracks().forEach(t => t.stop()); _scanStream = null; }
  document.getElementById('qrVideo').srcObject = null;
  document.getElementById('qrOverlay').style.display = 'none';
};

init();
setInterval(loadBalance, 15000);
</script>
<?php renderFoot(); ?>
