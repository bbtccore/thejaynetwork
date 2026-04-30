<?php require_once 'api.php'; renderHead('Staking - JAY Wallet'); ?>

<div class="header"><h1><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="var(--accent2)" stroke-width="2.5"><polygon points="12 2 2 7 12 12 22 7"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/></svg>Staking</h1></div>

<div class="app fade-in hidden" id="main">
  <div class="bc" style="padding:24px 20px;margin-bottom:16px">
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:14px">
      <div style="text-align:left">
        <div style="font-size:0.72rem;color:var(--dim);font-weight:600;text-transform:uppercase;letter-spacing:0.08em">Total Staked</div>
        <div style="font-size:1.5rem;font-weight:800;background:linear-gradient(135deg,#fff 30%,var(--accent2) 100%);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text" id="totalStaked"><div class="spin"></div></div>
      </div>
      <div style="text-align:right">
        <div style="font-size:0.72rem;color:var(--dim);font-weight:600;text-transform:uppercase;letter-spacing:0.08em">Rewards</div>
        <div style="font-size:1.2rem;font-weight:700;color:var(--green)" id="totalRewards">—</div>
      </div>
    </div>
    <button class="btn btn-p" id="claimBtn" onclick="claimAll()" style="width:100%;padding:14px">Claim All Rewards</button>
  </div>

  <div class="stit">My Delegations</div>
  <div id="myDelegations"><div class="spin"></div></div>

  <div class="stit" style="margin-top:20px">Active Validators</div>
  <div id="valList"><div class="spin"></div></div>
</div>

<!-- Delegate/Undelegate Modal -->
<div class="mo" id="delModal" onclick="if(event.target===this)closeModal('delModal')">
  <div class="modal">
    <div class="mh"><h2 id="delTitle">Delegate</h2><button class="mc" onclick="closeModal('delModal')">✕</button></div>
    <div style="background:rgba(255,255,255,0.03);border:1px solid rgba(255,255,255,0.06);border-radius:var(--rs);padding:14px 16px;margin-bottom:16px">
      <div style="font-size:0.76rem;color:var(--dim)">Validator</div>
      <div style="font-weight:700;font-size:0.92rem;margin-top:2px" id="delValName">—</div>
      <div style="font-size:0.7rem;color:var(--muted);word-break:break-all;margin-top:4px;font-family:'SF Mono','Fira Code',monospace" id="delValAddr">—</div>
    </div>
    <input type="hidden" id="delValAddrIn"><input type="hidden" id="delMode" value="delegate">
    <div class="ig"><label>Amount (JAY)</label><input type="number" class="inp" id="delAmt" placeholder="0.000000" step="0.000001" min="0"></div>
    <div style="background:rgba(255,255,255,0.03);border:1px solid rgba(255,255,255,0.06);border-radius:var(--rs);padding:14px 16px;margin-bottom:16px">
      <div style="display:flex;justify-content:space-between;font-size:0.8rem"><span style="color:var(--dim)">Fee</span><span>0.000750 JAY</span></div>
      <div style="display:flex;justify-content:space-between;font-size:0.8rem;margin-top:6px"><span style="color:var(--dim)">Gas</span><span>300,000</span></div>
    </div>
    <button class="btn btn-p" id="delBtn" onclick="doDelegate()">Delegate</button>
  </div>
</div>

<!-- Redelegate Modal -->
<div class="mo" id="redelModal" onclick="if(event.target===this)closeModal('redelModal')">
  <div class="modal">
    <div class="mh"><h2>Redelegate</h2><button class="mc" onclick="closeModal('redelModal')">✕</button></div>
    <div style="background:rgba(255,255,255,0.03);border:1px solid rgba(255,255,255,0.06);border-radius:var(--rs);padding:14px 16px;margin-bottom:16px">
      <div style="font-size:0.76rem;color:var(--dim)">From Validator</div>
      <div style="font-size:0.7rem;color:var(--muted);word-break:break-all;margin-top:4px;font-family:'SF Mono','Fira Code',monospace" id="redelSrcAddr">—</div>
    </div>
    <input type="hidden" id="redelSrcIn">
    <div class="ig"><label>To Validator</label><select class="inp" id="redelDst" style="appearance:auto"></select></div>
    <div class="ig"><label>Amount (JAY)</label><input type="number" class="inp" id="redelAmt" placeholder="0.000000" step="0.000001" min="0"></div>
    <div style="background:rgba(255,255,255,0.03);border:1px solid rgba(255,255,255,0.06);border-radius:var(--rs);padding:14px 16px;margin-bottom:16px">
      <div style="display:flex;justify-content:space-between;font-size:0.8rem"><span style="color:var(--dim)">Fee</span><span>0.001000 JAY</span></div>
      <div style="display:flex;justify-content:space-between;font-size:0.8rem;margin-top:6px"><span style="color:var(--dim)">Gas</span><span>400,000</span></div>
    </div>
    <button class="btn btn-p" id="redelBtn" onclick="doRedel()">Redelegate</button>
  </div>
</div>

<div id="toast"></div>
<?php renderNav('stake'); ?>

<script type="module">
<?= getJSCrypto() ?>

let ADDR = '', mnemonic = '', delegationMap = {}, balanceUjay = 0, validatorsList = [];

async function init() {
  const w = requireAuth(); if (!w) return;
  mnemonic = w.mnemonic; ADDR = w.addr || getAddr();
  document.getElementById('main').classList.remove('hidden');
  loadBalance(); loadDelegations(); loadValidators();
  setupAutoLock();
}
window.addEventListener('beforeunload', () => { mnemonic = ''; });

async function loadBalance() {
  try {
    const r = await fetch('api.php?a=balance&addr=' + ADDR);
    const d = await r.json();
    const ujay = (d.balances || []).find(b => b.denom === 'ujay');
    balanceUjay = parseInt(ujay?.amount || '0');
  } catch { balanceUjay = 0; }
}

async function loadDelegations() {
  try {
    const [dRes, rRes] = await Promise.all([
      fetch('api.php?a=delegations&addr='+ADDR).then(r=>r.json()),
      fetch('api.php?a=rewards&addr='+ADDR).then(r=>r.json())
    ]);
    const dels = dRes.delegation_responses || [];
    const rewardsList = rRes.rewards || [];
    let totalStaked = 0, totalReward = 0;
    (rRes.total || []).forEach(r => { if (r.denom === 'ujay') totalReward += parseFloat(r.amount || 0); });
    delegationMap = {};
    dels.forEach(d => { const va = d.delegation?.validator_address; const amt = parseInt(d.balance?.amount || 0); totalStaked += amt; if (va) delegationMap[va] = amt; });
    document.getElementById('totalStaked').textContent = fmtJay(totalStaked) + ' JAY';
    document.getElementById('totalRewards').textContent = fmtJay(Math.floor(totalReward)) + ' JAY';
    document.getElementById('claimBtn').disabled = totalReward < 1;
    if (dels.length === 0) { document.getElementById('myDelegations').innerHTML = '<div class="empty"><div class="ei">📭</div><p>No delegations yet</p></div>'; return; }
    document.getElementById('myDelegations').innerHTML = dels.map(d => {
      const va = d.delegation?.validator_address || '', amt = parseInt(d.balance?.amount || 0);
      const reward = rewardsList.find(r => r.validator_address === va);
      const rAmt = reward ? (reward.reward || []).reduce((s, r) => s + (r.denom === 'ujay' ? parseFloat(r.amount) : 0), 0) : 0;
      return `<div class="rcard" style="flex-direction:column;align-items:stretch;gap:10px;margin-bottom:10px;padding:16px">
        <div style="display:flex;justify-content:space-between;align-items:center"><div style="font-size:0.78rem;font-weight:600;color:var(--dim);overflow:hidden;text-overflow:ellipsis;white-space:nowrap;max-width:50%;font-family:'SF Mono','Fira Code',monospace">${esc(va.slice(0,16))}...</div><div style="font-weight:800;font-size:0.92rem">${fmtJay(amt)} <span style="font-weight:600;color:var(--dim);font-size:0.78rem">JAY</span></div></div>
        <div style="display:flex;justify-content:space-between;align-items:center"><div style="display:flex;align-items:center;gap:4px"><span style="width:6px;height:6px;border-radius:50%;background:var(--green)"></span><span style="font-size:0.73rem;color:var(--green);font-weight:600">${fmtJay(Math.floor(rAmt))} JAY</span></div><div style="display:flex;gap:8px"><button class="btn btn-s btn-sm" onclick="openRedel('${esc(va)}',${amt})" style="padding:7px 12px;font-size:0.70rem;border-radius:8px">Redelegate</button><button class="btn btn-s btn-sm" onclick="openUndel('${esc(va)}',${amt})" style="padding:7px 12px;font-size:0.70rem;border-radius:8px">Undelegate</button></div></div></div>`;
    }).join('');
  } catch { document.getElementById('myDelegations').innerHTML = '<div class="empty"><p>Failed to load</p></div>'; document.getElementById('totalStaked').textContent = '0 JAY'; }
}

async function loadValidators() {
  try {
    const r = await fetch('api.php?a=validators'); const d = await r.json();
    const vals = (d.validators || []).sort((a, b) => parseInt(b.tokens || 0) - parseInt(a.tokens || 0));
    validatorsList = vals;
    if (!vals.length) { document.getElementById('valList').innerHTML = '<div class="empty"><p>No validators</p></div>'; return; }
    document.getElementById('valList').innerHTML = vals.map((v, i) => {
      const name = v.description?.moniker || 'Unknown', tokens = parseInt(v.tokens || 0);
      const comm = (parseFloat(v.commission?.commission_rates?.rate || 0) * 100).toFixed(1);
      return `<div class="vi" onclick="openDel('${esc(v.operator_address)}','${esc(name)}')"><div class="vr"><img src="logo.png" alt="" style="width:100%;height:100%;object-fit:cover"></div><div class="vinfo"><div class="vn">${esc(name)}</div><div class="vp">${fmtJay(tokens)} JAY · ${comm}%</div></div><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--muted)" stroke-width="2"><polyline points="9 18 15 12 9 6"/></svg></div>`;
    }).join('');
  } catch { document.getElementById('valList').innerHTML = '<div class="empty"><p>Failed to load</p></div>'; }
}

window.openModal = id => document.getElementById(id).classList.add('show');
window.closeModal = id => document.getElementById(id).classList.remove('show');

window.openDel = function(va, name) {
  document.getElementById('delTitle').textContent = 'Delegate';
  document.getElementById('delValName').textContent = name;
  document.getElementById('delValAddr').textContent = va;
  document.getElementById('delValAddrIn').value = va;
  document.getElementById('delMode').value = 'delegate';
  document.getElementById('delAmt').value = '';
  document.getElementById('delBtn').textContent = 'Delegate';
  openModal('delModal');
};

window.openUndel = function(va, staked) {
  document.getElementById('delTitle').textContent = 'Undelegate';
  document.getElementById('delValName').textContent = va.slice(0, 24) + '...';
  document.getElementById('delValAddr').textContent = va;
  document.getElementById('delValAddrIn').value = va;
  document.getElementById('delMode').value = 'undelegate';
  document.getElementById('delAmt').value = '';
  document.getElementById('delAmt').placeholder = 'Max: ' + fmtJay(staked);
  document.getElementById('delBtn').textContent = 'Undelegate';
  openModal('delModal');
};

window.doDelegate = async function() {
  const va = document.getElementById('delValAddrIn').value;
  const amt = parseFloat(document.getElementById('delAmt').value);
  const mode = document.getElementById('delMode').value;
  if (!amt || amt <= 0) return toast('Invalid amount', false);
  const ujay = Math.floor(amt * 1e6);
  const feeUjay = 750;
  if (mode === 'delegate') {
    if (balanceUjay === 0) return toast('No balance available', false);
    if (ujay + feeUjay > balanceUjay) return toast('Insufficient balance (need ' + fmtJay(ujay + feeUjay) + ' JAY incl. fee)', false);
  } else {
    if (balanceUjay < feeUjay) return toast('Insufficient balance for fee (need ' + fmtJay(feeUjay) + ' JAY)', false);
  }
  const btn = document.getElementById('delBtn');
  btn.disabled = true; btn.textContent = 'Signing...';
  try {
    const msg = mode === 'delegate' ? msgDelegate(ADDR, va, 'ujay', ujay) : msgUndelegate(ADDR, va, 'ujay', ujay);
    const result = await signAndBroadcast(mnemonic, [msg], '', 750, 300000);
    if (result.tx_response?.code === 0) { toast(mode === 'delegate' ? 'Delegated!' : 'Undelegation started!'); closeModal('delModal'); setTimeout(loadDelegations, 3000); }
    else toast(result.tx_response?.raw_log || 'Failed', false);
  } catch (e) { toast('Error: ' + e.message, false); }
  btn.disabled = false; btn.textContent = document.getElementById('delMode').value === 'delegate' ? 'Delegate' : 'Undelegate';
};

window.openRedel = function(srcVa, staked) {
  document.getElementById('redelSrcAddr').textContent = srcVa;
  document.getElementById('redelSrcIn').value = srcVa;
  document.getElementById('redelAmt').value = '';
  document.getElementById('redelAmt').placeholder = 'Max: ' + fmtJay(staked);
  const sel = document.getElementById('redelDst');
  sel.innerHTML = validatorsList.filter(v => v.operator_address !== srcVa).map(v => {
    const name = v.description?.moniker || 'Unknown';
    return `<option value="${esc(v.operator_address)}">${esc(name)}</option>`;
  }).join('');
  openModal('redelModal');
};

window.doRedel = async function() {
  const srcVa = document.getElementById('redelSrcIn').value;
  const dstVa = document.getElementById('redelDst').value;
  const amt = parseFloat(document.getElementById('redelAmt').value);
  if (!dstVa) return toast('Select destination validator', false);
  if (!amt || amt <= 0) return toast('Invalid amount', false);
  const ujay = Math.floor(amt * 1e6);
  const feeUjay = 1000;
  if (balanceUjay < feeUjay) return toast('Insufficient balance for fee (need ' + fmtJay(feeUjay) + ' JAY)', false);
  const btn = document.getElementById('redelBtn');
  btn.disabled = true; btn.textContent = 'Signing...';
  try {
    const msg = msgRedelegate(ADDR, srcVa, dstVa, 'ujay', ujay);
    const result = await signAndBroadcast(mnemonic, [msg], '', 1000, 400000);
    if (result.tx_response?.code === 0) { toast('Redelegation started!'); closeModal('redelModal'); setTimeout(loadDelegations, 3000); }
    else toast(result.tx_response?.raw_log || 'Failed', false);
  } catch (e) { toast('Error: ' + e.message, false); }
  btn.disabled = false; btn.textContent = 'Redelegate';
};

window.claimAll = async function() {
  const addrs = Object.keys(delegationMap).filter(a => delegationMap[a] > 0);
  if (!addrs.length) return toast('No delegations', false);
  const gas = 200000 + addrs.length * 100000, fee = Math.ceil(gas * 0.0025);
  if (balanceUjay < fee) return toast('Insufficient balance for fee (need ' + fmtJay(fee) + ' JAY)', false);
  const btn = document.getElementById('claimBtn');
  btn.disabled = true; btn.textContent = 'Claiming...';
  try {
    const msgs = addrs.map(va => msgWithdrawRewards(ADDR, va));
    const result = await signAndBroadcast(mnemonic, msgs, '', fee, gas);
    if (result.tx_response?.code === 0) { toast('Rewards claimed!'); setTimeout(loadDelegations, 3000); }
    else toast(result.tx_response?.raw_log || 'Failed', false);
  } catch (e) { toast('Error: ' + e.message, false); }
  btn.disabled = false; btn.textContent = 'Claim All Rewards';
};

init();
</script>
<?php renderFoot(); ?>
