<?php require_once 'api.php'; renderHead('Settings - JAY Wallet'); ?>

<div class="header"><h1><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="var(--accent2)" stroke-width="2.5"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 01-2.83 2.83l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 01-4 0v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 01-2.83-2.83l.06-.06A1.65 1.65 0 004.68 15a1.65 1.65 0 00-1.51-1H3a2 2 0 010-4h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 012.83-2.83l.06.06A1.65 1.65 0 009 4.68a1.65 1.65 0 001-1.51V3a2 2 0 014 0v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 012.83 2.83l-.06.06A1.65 1.65 0 0019.4 9a1.65 1.65 0 001.51 1H21a2 2 0 010 4h-.09a1.65 1.65 0 00-1.51 1z"/></svg>Settings</h1></div>

<div class="app fade-in hidden" id="main">
  <!-- Security -->
  <div class="stit">Security</div>
  <div class="rcard" style="cursor:pointer;padding:18px 16px" onclick="showMnemonic()">
    <div style="display:flex;align-items:center;gap:12px;flex:1">
      <div style="width:40px;height:40px;border-radius:12px;background:linear-gradient(135deg,rgba(124,58,237,0.15),rgba(171,123,255,0.08));display:flex;align-items:center;justify-content:center;flex-shrink:0">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--accent2)" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0110 0v4"/></svg>
      </div>
      <div><div style="font-weight:700;font-size:0.88rem">Recovery Phrase</div><div style="font-size:0.72rem;color:var(--dim);margin-top:1px">View your 24-word secret phrase</div></div>
    </div>
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--muted)" stroke-width="2"><polyline points="9 18 15 12 9 6"/></svg>
  </div>

  <!-- Backup -->
  <div class="stit" style="margin-top:20px">Backup & Restore</div>
  <div class="rcard" style="cursor:pointer;padding:18px 16px;margin-bottom:10px" onclick="exportBackup()">
    <div style="display:flex;align-items:center;gap:12px;flex:1">
      <div style="width:40px;height:40px;border-radius:12px;background:rgba(52,211,153,0.1);display:flex;align-items:center;justify-content:center;flex-shrink:0">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--green)" stroke-width="2"><path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
      </div>
      <div><div style="font-weight:700;font-size:0.88rem">Export Backup</div><div style="font-size:0.72rem;color:var(--dim);margin-top:1px">Download encrypted .jay file</div></div>
    </div>
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--muted)" stroke-width="2"><polyline points="9 18 15 12 9 6"/></svg>
  </div>
  <div class="rcard" style="cursor:pointer;padding:18px 16px" onclick="openModal('importModal')">
    <div style="display:flex;align-items:center;gap:12px;flex:1">
      <div style="width:40px;height:40px;border-radius:12px;background:rgba(99,102,241,0.1);display:flex;align-items:center;justify-content:center;flex-shrink:0">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#818CF8" stroke-width="2"><path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>
      </div>
      <div><div style="font-weight:700;font-size:0.88rem">Import Backup</div><div style="font-size:0.72rem;color:var(--dim);margin-top:1px">Restore from .jay file</div></div>
    </div>
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--muted)" stroke-width="2"><polyline points="9 18 15 12 9 6"/></svg>
  </div>

  <!-- Session -->
  <div class="stit" style="margin-top:24px;color:var(--red)">Session</div>
  <button class="btn btn-d" onclick="doLogout()" style="margin-bottom:10px">
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>
    Lock Wallet
  </button>
</div>

<!-- Password Confirm Modal -->
<div class="mo" id="pwModal" onclick="if(event.target===this)closeModal('pwModal')">
  <div class="modal">
    <div class="mh"><h2>Verify Password</h2><button class="mc" onclick="closeModal('pwModal')">✕</button></div>
    <p style="font-size:0.85rem;color:var(--dim);margin-bottom:16px">Enter your password to view the recovery phrase.</p>
    <div class="ig">
      <label>Password</label>
      <input type="password" class="inp" id="mnPw" placeholder="Enter your password" onkeydown="if(event.key==='Enter')verifyAndShowMn()">
    </div>
    <button class="btn btn-p" id="mnPwBtn" onclick="verifyAndShowMn()">Verify</button>
  </div>
</div>

<!-- Mnemonic Modal -->
<div class="mo" id="mnModal" onclick="if(event.target===this)closeModal('mnModal')">
  <div class="modal">
    <div class="mh"><h2>Recovery Phrase</h2><button class="mc" onclick="closeModal('mnModal')">✕</button></div>
    <div class="warn">Anyone with these words can steal your funds. Never share them.</div>
    <div class="mg" id="mnWords"></div>
    <button class="copy-btn" onclick="copyMn()" style="margin-top:8px">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/></svg>
      Copy Phrase
    </button>
  </div>
</div>

<!-- Import Modal -->
<div class="mo" id="importModal" onclick="if(event.target===this)closeModal('importModal')">
  <div class="modal">
    <div class="mh"><h2>Import Backup</h2><button class="mc" onclick="closeModal('importModal')">✕</button></div>
    <p style="font-size:0.85rem;color:var(--dim);margin-bottom:16px">Select a .jay backup file and enter its password.</p>
    <div class="ig"><label>Backup File</label><input type="file" class="inp" id="backupFile" accept=".jay,.txt" style="padding:10px"></div>
    <div class="ig"><label>Backup Password</label><input type="password" class="inp" id="importPw" placeholder="Password of the backup"></div>
    <button class="btn btn-p" id="importBtn" onclick="doImport()">Restore Wallet</button>
  </div>
</div>

<div id="toast"></div>
<?php renderNav('backup'); ?>

<script type="module">
<?= getJSCrypto() ?>

let mnCache = '';

async function init() {
  const w = requireAuth(); if (!w) return;
  mnCache = w.mnemonic;
  document.getElementById('main').classList.remove('hidden');
  setupAutoLock();
}
window.addEventListener('beforeunload', () => { mnCache = ''; });

window.openModal = id => document.getElementById(id).classList.add('show');
window.closeModal = id => document.getElementById(id).classList.remove('show');

window.showMnemonic = function() {
  if (!mnCache) return toast('Not available', false);
  document.getElementById('mnPw').value = '';
  openModal('pwModal');
};

window.verifyAndShowMn = function() {
  const pw = document.getElementById('mnPw').value;
  if (!pw) return toast('Enter your password', false);
  const vault = getVault();
  const json = aesDecrypt(vault, pw);
  if (!json) return toast('Wrong password', false);
  closeModal('pwModal');
  document.getElementById('mnWords').innerHTML = mnCache.split(' ').map((w, i) =>
    `<div class="mw"><span class="n">${i+1}</span>${w}</div>`).join('');
  openModal('mnModal');
};

window.copyMn = () => navigator.clipboard.writeText(mnCache).then(() => toast('Phrase copied!'));

window.exportBackup = function() {
  const vault = getVault();
  if (!vault) return toast('No wallet data', false);
  const blob = new Blob([vault], {type: 'text/plain'});
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'jay-wallet-' + new Date().toISOString().slice(0, 10) + '.jay';
  document.body.appendChild(a); a.click(); document.body.removeChild(a);
  URL.revokeObjectURL(url);
  toast('Backup downloaded!');
};

window.doImport = async function() {
  const fileInput = document.getElementById('backupFile');
  const pw = document.getElementById('importPw').value;
  if (!fileInput.files.length) return toast('Select a backup file', false);
  if (!pw) return toast('Enter password', false);
  const btn = document.getElementById('importBtn');
  btn.disabled = true; btn.textContent = 'Decrypting...';
  try {
    const fileData = (await fileInput.files[0].text()).trim();
    const json = aesDecrypt(fileData, pw);
    if (!json) { toast('Wrong password or invalid file', false); btn.disabled = false; btn.textContent = 'Restore Wallet'; return; }
    const w = JSON.parse(json);
    if (!w.mnemonic) throw new Error('Invalid wallet data');
    const reEncrypted = fileData.startsWith('v2:') ? fileData : aesEncrypt(json, pw);
    saveVault(reEncrypted, w.addr);
    setSession(pw);
    toast('Wallet restored!');
    setTimeout(() => window.location.href = 'wallet.php', 1500);
  } catch (e) { toast('Error: ' + e.message, false); }
  btn.disabled = false; btn.textContent = 'Restore Wallet';
};

window.doLogout = function() {
  clearSession();
  window.location.href = 'index.php';
};

init();
</script>
<?php renderFoot(); ?>
