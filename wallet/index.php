<?php require_once 'api.php'; renderHead('JAY Wallet'); ?>

<div class="auth-page fade-in" id="authRoot">
  <div style="width:72px;height:72px;border-radius:50%;background:var(--grad);display:flex;align-items:center;justify-content:center;margin-bottom:20px;box-shadow:0 0 48px rgba(124,58,237,0.3)">
    <img src="logo.png" style="width:52px;height:52px;border-radius:50%;object-fit:cover" alt="JAY">
  </div>
  <h1 class="auth-t">JAY Wallet</h1>
  <p class="auth-s">Secure. Self-Custody. Decentralized.</p>

  <!-- Initial choice -->
  <div id="step0" class="hidden" style="width:100%;max-width:360px">
    <button class="btn btn-p" onclick="startCreate()" style="margin-bottom:12px">
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg>
      Create New Wallet
    </button>
    <button class="btn btn-s" onclick="showRestore()">
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="1 4 1 10 7 10"/><path d="M3.51 15a9 9 0 105.64-11.36L1 10"/></svg>
      Import Existing Wallet
    </button>
  </div>

  <!-- Mnemonic display -->
  <div id="step1" class="hidden" style="width:100%;max-width:400px">
    <div class="steps"><div class="sd ok"></div><div class="sd on"></div><div class="sd"></div></div>
    <p style="font-size:0.95rem;font-weight:700;margin-bottom:4px">Recovery Phrase</p>
    <p style="color:var(--dim);font-size:0.78rem;margin-bottom:14px">Write down these 24 words in order. This is the only way to recover your wallet.</p>
    <div class="warn">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="vertical-align:middle;margin-right:4px"><path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
      Never share your recovery phrase with anyone.
    </div>
    <div class="mg" id="mnGrid"></div>
    <button class="btn btn-s" id="copyMnBtn" onclick="copyMnemonic()" style="margin-bottom:12px">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/></svg>
      Copy to Clipboard
    </button>
    <button class="btn btn-p" onclick="goStep2()">I've Saved My Phrase</button>
  </div>

  <!-- Set password -->
  <div id="step2" class="hidden" style="width:100%;max-width:360px">
    <div class="steps"><div class="sd ok"></div><div class="sd ok"></div><div class="sd on"></div></div>
    <p style="font-size:0.95rem;font-weight:700;margin-bottom:4px">Create Password</p>
    <p style="color:var(--dim);font-size:0.78rem;margin-bottom:20px">This password encrypts your wallet locally in this browser.</p>
    <div class="ig">
      <label>Password</label>
      <input type="password" class="inp" id="pw1" placeholder="At least 8 characters">
    </div>
    <div class="ig">
      <label>Confirm Password</label>
      <input type="password" class="inp" id="pw2" placeholder="Re-enter password">
    </div>
    <button class="btn btn-p" id="createBtn" onclick="doCreate()">Create Wallet</button>
  </div>

  <!-- Restore from mnemonic -->
  <div id="stepRestore" class="hidden" style="width:100%;max-width:360px">
    <p style="font-size:0.95rem;font-weight:700;margin-bottom:4px">Import Wallet</p>
    <p style="color:var(--dim);font-size:0.78rem;margin-bottom:20px">Enter your secret recovery phrase to restore your wallet.</p>
    <div class="ig">
      <label>Recovery Phrase</label>
      <textarea class="inp" id="restoreMn" rows="4" placeholder="Enter your 24-word recovery phrase" style="resize:none"></textarea>
    </div>
    <div class="ig">
      <label>New Password</label>
      <input type="password" class="inp" id="restorePw" placeholder="At least 8 characters">
    </div>
    <button class="btn btn-p" id="restoreBtn" onclick="doRestore()" style="margin-bottom:12px">Import Wallet</button>
    <button class="btn btn-s" onclick="show('step0')">Back</button>
  </div>

  <!-- Login -->
  <div id="loginBox" class="hidden" style="width:100%;max-width:360px">
    <div style="display:inline-flex;align-items:center;gap:6px;padding:6px 14px;border-radius:100px;background:rgba(52,211,153,0.08);border:1px solid rgba(52,211,153,0.15);margin-bottom:16px">
      <span style="width:7px;height:7px;border-radius:50%;background:var(--green);display:inline-block"></span>
      <span style="font-size:0.72rem;font-weight:600;color:var(--green)">Self-Custody Wallet</span>
    </div>
    <div class="addr-box" id="loginAddr" style="font-size:0.7rem;margin-bottom:20px"></div>
    <div class="ig">
      <label>Password</label>
      <input type="password" class="inp" id="loginPw" placeholder="Enter your password" onkeydown="if(event.key==='Enter')doLogin()">
    </div>
    <button class="btn btn-p" id="loginBtn" onclick="doLogin()">
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0110 0v4"/></svg>
      Unlock
    </button>
  </div>
</div>

<div id="toast"></div>

<script type="module">
<?= getJSCrypto() ?>

let mnemonic = '';

window.show = function(id) {
  ['step0','step1','step2','stepRestore','loginBox'].forEach(s => document.getElementById(s).classList.add('hidden'));
  document.getElementById(id).classList.remove('hidden');
};

if (isLoggedIn()) { window.location.href = 'wallet.php'; }
else if (vaultExists()) {
  show('loginBox');
  const a = getAddr();
  if (a) document.getElementById('loginAddr').textContent = a;
} else {
  show('step0');
}

window.startCreate = function() {
  mnemonic = newMnemonic();
  document.getElementById('mnGrid').innerHTML = mnemonic.split(' ').map((w, i) =>
    `<div class="mw"><span class="n">${i+1}</span>${w}</div>`).join('');
  show('step1');
};

window.goStep2 = () => show('step2');
window.showRestore = () => show('stepRestore');

window.copyMnemonic = function() {
  navigator.clipboard.writeText(mnemonic).then(() => {
    const btn = document.getElementById('copyMnBtn');
    btn.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--green)" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg> Copied!';
    setTimeout(() => {
      btn.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/></svg> Copy to Clipboard';
    }, 2000);
  }).catch(() => toast('Failed to copy', false));
};

window.doCreate = function() {
  const pw1 = document.getElementById('pw1').value;
  const pw2 = document.getElementById('pw2').value;
  if (pw1.length < 8) return toast('Password must be at least 8 characters', false);
  if (pw1 !== pw2) return toast('Passwords do not match', false);
  const btn = document.getElementById('createBtn');
  btn.disabled = true; btn.textContent = 'Encrypting...';
  try {
    const addr = addrFromMn(mnemonic);
    const encrypted = aesEncrypt(JSON.stringify({mnemonic, addr}), pw1);
    saveVault(encrypted, addr);
    setSession(pw1);
    window.location.href = 'wallet.php';
  } catch(e) { toast('Error: ' + e.message, false); btn.disabled = false; btn.textContent = 'Create Wallet'; }
};

window.doRestore = function() {
  const mn = document.getElementById('restoreMn').value.trim().toLowerCase().replace(/\s+/g, ' ');
  const pw = document.getElementById('restorePw').value;
  if (!validMn(mn)) return toast('Invalid mnemonic phrase', false);
  if (pw.length < 8) return toast('Password must be at least 8 characters', false);
  const btn = document.getElementById('restoreBtn');
  btn.disabled = true; btn.textContent = 'Encrypting...';
  try {
    const addr = addrFromMn(mn);
    const encrypted = aesEncrypt(JSON.stringify({mnemonic: mn, addr}), pw);
    saveVault(encrypted, addr);
    setSession(pw);
    window.location.href = 'wallet.php';
  } catch(e) { toast('Error: ' + e.message, false); btn.disabled = false; btn.textContent = 'Import Wallet'; }
};

window.doLogin = function() {
  if (isLockedOut()) return toast('Too many attempts. Try again in ' + lockoutSeconds() + 's', false);
  const pw = document.getElementById('loginPw').value;
  if (!pw) return toast('Enter your password', false);
  const btn = document.getElementById('loginBtn');
  btn.disabled = true; btn.innerHTML = 'Decrypting...';
  const vault = getVault();
  const json = aesDecrypt(vault, pw);
  if (!json) {
    const d = recordFailedAttempt();
    const left = _MAX_ATTEMPTS - (d.c || 0);
    toast(left > 0 ? 'Wrong password (' + left + ' attempts left)' : 'Locked for 5 minutes', false);
    btn.disabled = false; btn.innerHTML = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0110 0v4"/></svg> Unlock'; return;
  }
  clearLoginAttempts();
  if (!vault.startsWith('v2:')) { const d = JSON.parse(json); saveVault(aesEncrypt(json, pw), d.addr); }
  setSession(pw);
  window.location.href = 'wallet.php';
};
</script>
<?php renderFoot(); ?>
