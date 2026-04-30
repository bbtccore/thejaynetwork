<?php require_once 'api.php'; renderHead('Governance - JAY Wallet'); ?>

<div class="header"><h1><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="var(--accent2)" stroke-width="2.5"><path d="M3 21h18M3 10h18M5 6l7-3 7 3M4 10v11M20 10v11M8 14v3M12 14v3M16 14v3"/></svg>Governance</h1></div>

<div class="app fade-in hidden" id="main">
  <div class="stit">Proposals</div>
  <div id="proposalList"><div class="spin"></div></div>
</div>

<!-- Proposal Detail / Vote Modal -->
<div class="mo" id="propModal" onclick="if(event.target===this)closeModal('propModal')">
  <div class="modal">
    <div class="mh"><h2 id="propTitle" style="font-size:1rem">Proposal</h2><button class="mc" onclick="closeModal('propModal')">✕</button></div>
    <div id="propBody"></div>
    <div id="voteSection" style="display:none">
      <div class="stit" style="margin-top:16px">Cast Your Vote</div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px">
        <button class="btn btn-sm" style="background:rgba(52,211,153,0.1);color:var(--green);border:1px solid rgba(52,211,153,0.2);border-radius:var(--rs);padding:14px" onclick="castVote(1)">Yes</button>
        <button class="btn btn-sm" style="background:rgba(248,113,113,0.1);color:var(--red);border:1px solid rgba(248,113,113,0.2);border-radius:var(--rs);padding:14px" onclick="castVote(3)">No</button>
        <button class="btn btn-sm" style="background:rgba(152,152,184,0.08);color:var(--dim);border:1px solid rgba(152,152,184,0.15);border-radius:var(--rs);padding:14px" onclick="castVote(2)">Abstain</button>
        <button class="btn btn-sm" style="background:rgba(251,191,36,0.08);color:var(--orange);border:1px solid rgba(251,191,36,0.15);border-radius:var(--rs);padding:14px" onclick="castVote(4)">No With Veto</button>
      </div>
    </div>
  </div>
</div>

<div id="toast"></div>
<?php renderNav('gov'); ?>

<script type="module">
<?= getJSCrypto() ?>

let ADDR = '', mnemonic = '', proposals = [];

async function init() {
  const w = requireAuth(); if (!w) return;
  mnemonic = w.mnemonic; ADDR = w.addr || getAddr();
  document.getElementById('main').classList.remove('hidden');
  loadProposals();
  setupAutoLock();
}
window.addEventListener('beforeunload', () => { mnemonic = ''; });

const STATUS_MAP = {
  'PROPOSAL_STATUS_DEPOSIT_PERIOD': ['Deposit', 'rgba(245,158,11,0.15)', '#F59E0B'],
  'PROPOSAL_STATUS_VOTING_PERIOD': ['Voting', 'rgba(124,58,237,0.15)', 'var(--accent2)'],
  'PROPOSAL_STATUS_PASSED': ['Passed', 'rgba(16,185,129,0.15)', 'var(--green)'],
  'PROPOSAL_STATUS_REJECTED': ['Rejected', 'rgba(239,68,68,0.15)', 'var(--red)'],
  'PROPOSAL_STATUS_FAILED': ['Failed', 'rgba(139,139,167,0.15)', 'var(--muted)']
};

function statusBadge(s) {
  const [label, bg, color] = STATUS_MAP[s] || [s, 'var(--card)', 'var(--dim)'];
  return `<span class="tag" style="background:${bg};color:${color}">${label}</span>`;
}

function timeFmt(iso) {
  if (!iso) return '—';
  const d = new Date(iso);
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' }) + ' ' + d.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' });
}

async function loadProposals() {
  try {
    const r = await fetch('api.php?a=proposals');
    const d = await r.json();
    proposals = d.proposals || [];
    if (!proposals.length) {
      document.getElementById('proposalList').innerHTML = '<div class="empty"><div class="ei">📋</div><p>No proposals yet</p></div>';
      return;
    }
    document.getElementById('proposalList').innerHTML = proposals.map(p => {
      const id = p.id || p.proposal_id || '?';
      const title = esc(p.title || p.content?.title || 'Untitled');
      return `<div class="rcard" style="flex-direction:column;align-items:stretch;gap:8px;margin-bottom:8px;cursor:pointer" onclick="showProposal('${id}')">
        <div style="display:flex;justify-content:space-between;align-items:center">
          <span style="font-size:0.75rem;color:var(--muted)">#${id}</span>
          ${statusBadge(p.status)}
        </div>
        <div style="font-weight:700;font-size:0.88rem">${title}</div>
        <div style="font-size:0.70rem;color:var(--dim)">${p.status === 'PROPOSAL_STATUS_VOTING_PERIOD' ? 'Voting ends: ' + timeFmt(p.voting_end_time) : timeFmt(p.submit_time)}</div>
      </div>`;
    }).join('');
  } catch { document.getElementById('proposalList').innerHTML = '<div class="empty"><p>Failed to load</p></div>'; }
}

window.openModal = id => document.getElementById(id).classList.add('show');
window.closeModal = id => document.getElementById(id).classList.remove('show');

let currentPropId = null;

window.showProposal = async function(id) {
  currentPropId = id;
  const p = proposals.find(x => (x.id || x.proposal_id) == id);
  if (!p) return;

  const title = esc(p.title || p.content?.title || 'Untitled');
  const summary = esc(p.summary || p.content?.description || '');
  document.getElementById('propTitle').textContent = '#' + id + ' ' + (p.title || 'Proposal');

  let tallyHtml = '';
  try {
    const tr = await fetch('api.php?a=tally&id=' + id);
    const td = await tr.json();
    const tally = td.tally || p.final_tally_result || {};
    const yes = parseInt(tally.yes_count || tally.yes || 0);
    const no = parseInt(tally.no_count || tally.no || 0);
    const abstain = parseInt(tally.abstain_count || tally.abstain || 0);
    const veto = parseInt(tally.no_with_veto_count || tally.no_with_veto || 0);
    const total = yes + no + abstain + veto || 1;
    const pct = v => (v / total * 100).toFixed(1);
    tallyHtml = `<div style="margin-top:16px;background:rgba(255,255,255,0.03);border:1px solid rgba(255,255,255,0.06);border-radius:var(--rs);padding:16px">
      <div style="font-size:0.72rem;font-weight:700;color:var(--dim);margin-bottom:10px;text-transform:uppercase;letter-spacing:0.08em">Vote Tally</div>
      <div style="height:10px;border-radius:5px;overflow:hidden;display:flex;background:rgba(255,255,255,0.04);margin-bottom:12px">
        <div style="width:${pct(yes)}%;background:var(--green);transition:width .5s"></div>
        <div style="width:${pct(no)}%;background:var(--red);transition:width .5s"></div>
        <div style="width:${pct(abstain)}%;background:var(--muted);transition:width .5s"></div>
        <div style="width:${pct(veto)}%;background:var(--orange);transition:width .5s"></div>
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;font-size:0.74rem">
        <div style="display:flex;align-items:center;gap:6px"><span style="width:8px;height:8px;border-radius:50%;background:var(--green);flex-shrink:0"></span>Yes ${pct(yes)}%</div>
        <div style="display:flex;align-items:center;gap:6px"><span style="width:8px;height:8px;border-radius:50%;background:var(--red);flex-shrink:0"></span>No ${pct(no)}%</div>
        <div style="display:flex;align-items:center;gap:6px"><span style="width:8px;height:8px;border-radius:50%;background:var(--muted);flex-shrink:0"></span>Abstain ${pct(abstain)}%</div>
        <div style="display:flex;align-items:center;gap:6px"><span style="width:8px;height:8px;border-radius:50%;background:var(--orange);flex-shrink:0"></span>Veto ${pct(veto)}%</div>
      </div>
    </div>`;
  } catch {}

  const rows = [
    ['Status', statusBadge(p.status)],
    ['Submitted', timeFmt(p.submit_time)],
    p.voting_start_time ? ['Voting Start', timeFmt(p.voting_start_time)] : null,
    p.voting_end_time ? ['Voting End', timeFmt(p.voting_end_time)] : null,
  ].filter(Boolean);

  document.getElementById('propBody').innerHTML =
    rows.map(([k, v]) => `<div style="display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid var(--card-b);gap:12px;align-items:center"><span style="color:var(--dim);font-size:0.78rem;font-weight:600;flex-shrink:0">${k}</span><span style="font-size:0.82rem;text-align:right">${v}</span></div>`).join('') +
    (summary ? `<div style="margin-top:12px;font-size:0.82rem;color:var(--dim);line-height:1.6;word-break:break-word">${summary}</div>` : '') +
    tallyHtml;

  const isVoting = p.status === 'PROPOSAL_STATUS_VOTING_PERIOD';
  document.getElementById('voteSection').style.display = isVoting ? 'block' : 'none';
  openModal('propModal');
};

window.castVote = async function(option) {
  if (!currentPropId) return;
  const optNames = { 1: 'Yes', 2: 'Abstain', 3: 'No', 4: 'No With Veto' };
  const feeUjay = 500;
  if (balanceUjay < feeUjay) return toast('Insufficient balance for fee', false);
  const btns = document.querySelectorAll('#voteSection button');
  btns.forEach(b => { b.disabled = true; });
  try {
    const msg = msgVote(parseInt(currentPropId), ADDR, option);
    const result = await signAndBroadcast(mnemonic, [msg], '', 500, 200000);
    if (result.tx_response?.code === 0) { toast('Voted ' + optNames[option] + '!'); closeModal('propModal'); }
    else toast(result.tx_response?.raw_log || 'Vote failed', false);
  } catch (e) { toast('Error: ' + e.message, false); }
  btns.forEach(b => { b.disabled = false; });
};

let balanceUjay = 0;
async function loadBalance() {
  try {
    const r = await fetch('api.php?a=balance&addr=' + ADDR);
    const d = await r.json();
    const ujay = (d.balances || []).find(b => b.denom === 'ujay');
    balanceUjay = parseInt(ujay?.amount || '0');
  } catch { balanceUjay = 0; }
}

async function start() { await init(); loadBalance(); }
start();
</script>
<?php renderFoot(); ?>
