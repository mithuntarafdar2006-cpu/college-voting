// Point this at the backend you deployed: 'php/api.php', 'jsp/api.jsp' or 'asp/api.asp'
const API = 'php/api.php';

const $ = s => document.querySelector(s);
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let state = null;

async function api(action, data) {
  const opt = data ? { method: 'POST', body: new URLSearchParams(data) } : {};
  const res = await fetch(`${API}?action=${action}`, { credentials: 'same-origin', ...opt });
  const json = await res.json().catch(() => ({ error: 'Unexpected server response.' }));
  if (!res.ok) throw new Error(json.error || 'Request failed.');
  return json;
}

const isOpen = () => Number(state.election.is_open) === 1;
const showView = v => { for (const id of ['login', 'register', 'app']) $('#' + id).hidden = v !== id; };

async function boot() {
  try { state = await api('me'); } catch { return showView('login'); }
  showView('app'); renderHeader(); openTab('ballot');
}

function renderHeader() {
  const { user, election } = state, open = isOpen();
  $('#title').textContent = election.title;
  $('#status').textContent = open ? 'Voting is open' : 'Voting is closed';
  $('#status').className = 'badge ' + (open ? 'open' : 'closed');
  $('#who').textContent = `${user.name} (${user.student_id})`;
  $('#adminTab').hidden = user.role !== 'admin';
  $('#toggle').textContent = open ? 'Close voting' : 'Open voting';
}

async function openTab(tab) {
  document.querySelectorAll('.tab').forEach(b => b.classList.toggle('active', b.dataset.tab === tab));
  document.querySelectorAll('.panel').forEach(p => p.hidden = p.id !== tab);
  if (tab === 'ballot') await renderBallot();
  if (tab === 'results') await renderResults();
}

async function renderBallot() {
  const el = $('#ballot'), note = (t, cls = 'muted') => { el.innerHTML = `<div class="sheet ${cls}">${t}</div>`; };
  if (state.user.role === 'admin') return note('Admins cannot vote. Use the Admin tab to manage the election.');
  if (state.has_voted) return note('<h2>Vote recorded</h2><p>Thank you. Ballots are anonymous and cannot be changed.</p>', 'ok');
  if (!isOpen()) return note('Voting is closed.');
  let list;
  try { list = await api('candidates'); } catch (e) { return note(esc(e.message)); }
  if (!list.length) return note('No candidates have been added yet.');

  el.innerHTML = `<form id="voteForm"><p class="muted">Choose one candidate, then cast your vote.</p>` +
    list.map(c => `<label class="cand"><input type="radio" name="candidate_id" value="${esc(c.id)}" required><span class="bubble"></span>
      <span><strong>${esc(c.name)}</strong><span class="tag">${esc(c.post)}${c.department ? ', ' + esc(c.department) : ''}</span>
      <p>${esc(c.manifesto)}</p></span></label>`).join('') +
    `<button class="primary">Cast vote</button><p class="msg" role="alert" id="voteMsg"></p></form>`;

  $('#voteForm').onsubmit = async e => {
    e.preventDefault();
    if (!confirm('Cast this vote? You cannot change it afterwards.')) return;
    try { await api('vote', new FormData(e.target)); state.has_voted = true; renderBallot(); }
    catch (err) { $('#voteMsg').textContent = err.message; }
  };
}

async function renderResults() {
  const el = $('#results');
  try {
    const rows = await api('results'), total = rows.reduce((s, r) => s + Number(r.votes), 0);
    el.innerHTML = `<div class="sheet"><h2>Results (${total} vote${total === 1 ? '' : 's'})</h2>` + rows.map(r => {
      const v = Number(r.votes), pct = total ? Math.round(v * 100 / total) : 0;
      return `<div class="row"><div class="rowhead"><span>${esc(r.name)} <small class="muted">${esc(r.post)}</small></span>
        <span>${v} (${pct}%)</span></div><div class="bar"><i style="width:${pct}%"></i></div></div>`;
    }).join('') + '</div>';
  } catch (e) { el.innerHTML = `<div class="sheet muted">${esc(e.message)}</div>`; }
}

$('#loginForm').onsubmit = async e => {
  e.preventDefault(); $('#loginMsg').textContent = '';
  try { await api('login', new FormData(e.target)); e.target.reset(); boot(); }
  catch (err) { $('#loginMsg').textContent = err.message; }
};
document.querySelectorAll('[data-view]').forEach(b => b.onclick = () => showView(b.dataset.view));
$('#registerForm').onsubmit = async e => {
  e.preventDefault(); const m = $('#regMsg'); m.textContent = '';
  const f = new FormData(e.target);
  if (f.get('password') !== f.get('confirm')) { m.textContent = 'Passwords do not match.'; return; }
  try {
    await api('register', f);
    await api('login', { student_id: f.get('student_id').trim(), password: f.get('password') });
    e.target.reset(); boot();
  } catch (err) { m.textContent = err.message; }
};
$('#logout').onclick = async () => { await api('logout', {}).catch(() => {}); showView('login'); };
document.querySelectorAll('.tab').forEach(b => b.onclick = () => openTab(b.dataset.tab));
document.querySelectorAll('form[data-action]').forEach(f => f.onsubmit = async e => {
  e.preventDefault(); const m = f.querySelector('.msg');
  try { await api(f.dataset.action, new FormData(f)); f.reset(); m.style.color = 'var(--accent)'; m.textContent = 'Saved.'; }
  catch (err) { m.style.color = ''; m.textContent = err.message; }
});
$('#toggle').onclick = async () => {
  try { state.election = await api('toggle_election', {}); renderHeader(); } catch (err) { alert(err.message); }
};

boot();
