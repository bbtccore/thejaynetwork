<?php require_once 'api.php'; renderHead('Activity - JAY Wallet'); ?>

<div class="header"><h1><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="var(--accent2)" stroke-width="2.5"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>Activity</h1></div>

<div class="app fade-in hidden" id="main">
  <div id="txList"><div class="spin"></div></div>
  <div id="loadMoreWrap" class="hidden" style="text-align:center;padding:8px 0 16px">
    <button class="btn btn-s btn-sm" id="loadMoreBtn" onclick="loadMore()">Load More</button>
  </div>
</div>

<!-- Tx Detail Modal -->
<div class="mo" id="txModal" onclick="if(event.target===this)closeTxModal()">
  <div class="modal">
    <div class="mh"><h2>Transaction Details</h2><button class="mc" onclick="closeTxModal()">✕</button></div>
    <div id="txDetail"></div>
  </div>
</div>

<div id="toast"></div>
<?php renderNav('activity'); ?>

<script type="module">
<?= getJSCrypto() ?>

let ADDR = '', currentPage = 1, allLoaded = false, txCache = [];

(function init() {
  const w = requireAuth(); if (!w) return;
  ADDR = w.addr || getAddr();
  document.getElementById('main').classList.remove('hidden');
  loadTxs();
  setupAutoLock();
})();

async function loadTxs() {
  const el = document.getElementById('txList');
  try {
    const r = await fetch('api.php?a=txs&addr=' + ADDR + '&page=' + currentPage);
    const d = await r.json();
    const txs = d.tx_responses || [];
    if (!txs.length && currentPage === 1) {
      el.innerHTML = '<div class="empty"><div class="ei">📋</div><p>No transactions yet</p></div>';
      return;
    }
    txCache = txCache.concat(txs);
    const html = txs.map(tx => renderTx(tx)).join('');
    if (currentPage === 1) el.innerHTML = html; else el.innerHTML += html;
    if (txs.length < 20) { allLoaded = true; document.getElementById('loadMoreWrap').classList.add('hidden'); }
    else document.getElementById('loadMoreWrap').classList.remove('hidden');
  } catch { if (currentPage === 1) el.innerHTML = '<div class="empty"><p>Failed to load transactions</p></div>'; }
}

function parseTx(tx) {
  const ok = tx.code === 0 || tx.code === undefined;
  const msgs = tx.tx?.body?.messages || [];
  const firstMsg = msgs[0] || {};
  const typeRaw = firstMsg['@type'] || '';
  const type = typeRaw.split('.').pop().replace('Msg', '');
  const height = tx.height || '—';
  const hash = tx.txhash || '';
  const time = tx.timestamp || '';
  const memo = tx.tx?.body?.memo || '';
  const gasWanted = tx.gas_wanted || '0';
  const gasUsed = tx.gas_used || '0';
  const fee = tx.tx?.auth_info?.fee?.amount || [];

  let detail = '', amount = '';
  const isSend = type === 'Send' && firstMsg.from_address === ADDR;
  const isRecv = type === 'Send' && firstMsg.to_address === ADDR;

  if (type === 'Send') {
    const peer = isSend ? firstMsg.to_address : firstMsg.from_address;
    const amt = (firstMsg.amount || []).find(a => a.denom === 'ujay');
    amount = amt ? fmtJay(amt.amount) + ' JAY' : '';
    detail = (isSend ? '→ ' : '← ') + (peer ? esc(peer.slice(0,10)) + '...' : '') + (amt ? ' ' + esc(amount) : '');
  } else if (type === 'Delegate' || type === 'Undelegate') {
    const amt = firstMsg.amount;
    amount = amt ? fmtJay(amt.amount) + ' JAY' : '';
    detail = esc(amount) + (firstMsg.validator_address ? ' → ' + esc(firstMsg.validator_address.slice(0,14)) + '...' : '');
  } else if (type === 'WithdrawDelegatorReward') {
    detail = 'Claimed rewards';
  } else {
    detail = esc(type) || 'Transaction';
  }

  return { ok, type, height, hash, time, memo, gasWanted, gasUsed, fee, detail, amount, isSend, isRecv, firstMsg, msgs };
}

function renderTx(tx) {
  const p = parseTx(tx);
  const iconBg = p.isRecv ? 'rgba(52,211,153,0.1)' : p.isSend ? 'rgba(248,113,113,0.1)' : 'rgba(171,123,255,0.1)';
  const icon = p.isRecv
    ? '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--green)" stroke-width="2.5"><line x1="17" y1="7" x2="7" y2="17"/><polyline points="17 17 7 17 7 7"/></svg>'
    : p.isSend
    ? '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--red)" stroke-width="2.5"><line x1="7" y1="17" x2="17" y2="7"/><polyline points="7 7 17 7 17 17"/></svg>'
    : '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--accent2)" stroke-width="2.5"><polygon points="12 2 2 7 12 12 22 7"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/></svg>';
  const timeFmt = p.time ? new Date(p.time).toLocaleString(undefined, {month:'short',day:'numeric',hour:'2-digit',minute:'2-digit'}) : '';

  return `<div class="rcard" style="gap:12px;margin-bottom:8px;cursor:pointer;padding:14px 16px" onclick="showTxDetail('${esc(p.hash)}')">
    <div style="display:flex;align-items:center;gap:12px;flex:1;min-width:0">
      <div style="width:40px;height:40px;border-radius:50%;background:${iconBg};display:flex;align-items:center;justify-content:center;flex-shrink:0">${icon}</div>
      <div style="min-width:0;flex:1">
        <div style="display:flex;justify-content:space-between;align-items:center">
          <span style="font-weight:700;font-size:0.85rem">${p.isRecv ? 'Receive' : p.isSend ? 'Send' : p.type === 'WithdrawDelegatorReward' ? 'Claim Rewards' : esc(p.type) || 'Tx'}</span>
          <span style="font-size:0.66rem;color:${p.ok?'var(--green)':'var(--red)'};font-weight:600;padding:2px 8px;border-radius:100px;background:${p.ok?'rgba(52,211,153,0.08)':'rgba(248,113,113,0.08)'}">${p.ok?'Success':'Failed'}</span>
        </div>
        <div style="font-size:0.75rem;color:var(--dim);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;margin-top:2px">${p.detail}</div>
        <div style="display:flex;justify-content:space-between;margin-top:4px">
          <span style="font-size:0.65rem;color:var(--muted)">${esc(timeFmt)}</span>
          <span style="font-size:0.65rem;color:var(--muted)">Block ${esc(p.height)}</span>
        </div>
      </div>
    </div>
  </div>`;
}

window.showTxDetail = function(hash) {
  const tx = txCache.find(t => t.txhash === hash);
  if (!tx) return;
  const p = parseTx(tx);
  const timeFull = p.time ? new Date(p.time).toLocaleString() : '—';
  const feeStr = p.fee.map(f => fmtJay(f.amount) + ' ' + (f.denom === 'ujay' ? 'JAY' : f.denom)).join(', ') || '—';
  const rawLog = tx.raw_log || (p.ok ? '' : '—');

  let rows = [
    ['Status', `<span style="color:${p.ok?'var(--green)':'var(--red)'};font-weight:700">${p.ok?'Success':'Failed'}</span>`],
    ['Type', p.isRecv ? 'Receive' : p.isSend ? 'Send' : p.type === 'WithdrawDelegatorReward' ? 'Claimed staking rewards' : esc(p.type)],
    ['Height', esc(p.height)],
    ['Time', esc(timeFull)],
    ['Tx Hash', `<span id="txHashText" style="font-family:'SF Mono','Fira Code',monospace;font-size:0.7rem;word-break:break-all;cursor:pointer;color:var(--accent2)" onclick="const el=this,orig=el.textContent;navigator.clipboard.writeText('${esc(p.hash)}');el.textContent='Copied!';el.style.color='var(--green)';setTimeout(()=>{el.textContent=orig;el.style.color='var(--accent2)'},500)">${esc(p.hash)}</span>`],
  ];

  if (p.type === 'Send') {
    rows.push(['From', `<span style="font-size:0.72rem;word-break:break-all">${esc(p.firstMsg.from_address)}</span>`]);
    rows.push(['To', `<span style="font-size:0.72rem;word-break:break-all">${esc(p.firstMsg.to_address)}</span>`]);
    rows.push(['Amount', esc(p.amount)]);
  } else if (p.type === 'Delegate' || p.type === 'Undelegate') {
    rows.push(['Delegator', `<span style="font-size:0.72rem;word-break:break-all">${esc(p.firstMsg.delegator_address)}</span>`]);
    rows.push(['Validator', `<span style="font-size:0.72rem;word-break:break-all">${esc(p.firstMsg.validator_address)}</span>`]);
    if (p.amount) rows.push(['Amount', esc(p.amount)]);
  } else if (p.type === 'WithdrawDelegatorReward') {
    rows.push(['Delegator', `<span style="font-size:0.72rem;word-break:break-all">${esc(p.firstMsg.delegator_address)}</span>`]);
    rows.push(['Validator', `<span style="font-size:0.72rem;word-break:break-all">${esc(p.firstMsg.validator_address)}</span>`]);
  }

  rows.push(['Fee', esc(feeStr)]);
  rows.push(['Gas', `${parseInt(p.gasUsed).toLocaleString()} / ${parseInt(p.gasWanted).toLocaleString()}`]);
  if (p.memo) rows.push(['Memo', esc(p.memo)]);
  if (rawLog && !p.ok) rows.push(['Error', `<span style="color:var(--red);font-size:0.75rem">${esc(rawLog)}</span>`]);

  const html = rows.map(([k, v]) =>
    `<div style="display:flex;justify-content:space-between;padding:10px 0;border-bottom:1px solid var(--card-b);gap:12px">
      <span style="color:var(--dim);font-size:0.78rem;font-weight:600;flex-shrink:0">${k}</span>
      <span style="font-size:0.82rem;text-align:right;min-width:0">${v}</span>
    </div>`
  ).join('') +
  `<a href="https://jayscan.duckdns.org" target="_blank" rel="noopener" class="btn btn-p" style="margin-top:16px;text-decoration:none">
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 13v6a2 2 0 01-2 2H5a2 2 0 01-2-2V8a2 2 0 012-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>
    View on Explorer
  </a>`;

  document.getElementById('txDetail').innerHTML = html;
  document.getElementById('txModal').classList.add('show');
};

window.closeTxModal = () => document.getElementById('txModal').classList.remove('show');

window.loadMore = function() {
  if (allLoaded) return;
  currentPage++;
  const btn = document.getElementById('loadMoreBtn');
  btn.disabled = true; btn.textContent = 'Loading...';
  loadTxs().then(() => { btn.disabled = false; btn.textContent = 'Load More'; });
};
</script>
<?php renderFoot(); ?>
