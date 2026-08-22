/* ──────────────────────────────────────────────
   Atlanta Angels · Wish List — caregiver side
   Five steps: household, children, a list per child, payout, review.
   The list step is the one that has to feel good, so it is the only one
   that gets a picker; everything else is short and plain.
   ────────────────────────────────────────────── */

const $  = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const money = n => '$' + Math.round(n).toLocaleString();
const CAP = 300; // per child, the number Angels asks donors to expect

let step = 0;
let cur = 0;   // which child's list is open on step 2

const H = { caregiver:'', email:'', phone:'', county:'', street:'', city:'', zip:'' };
let CHILDREN = [];
const PAY = { method:'', connected:false, bank:'', mailName:'', mailAddr:'' };

const uid = () => 'n' + Math.random().toString(36).slice(2, 7);

/* Donors never see a legal first name, so the system assigns the stand-in
   rather than asking a caregiver to invent one under time pressure. */
const ALIAS_POOL = ['Maya','Theo','Nova','Beau','Rowan','Sage','Micah','Wren','Ezra','Iris',
                    'Juno','Levi','Nia','Otis','Poppy','Quinn','Reese','Sol','Tess','Vera'];
function nextAlias(){
  const taken = new Set(CHILDREN.map(c => c.alias));
  return ALIAS_POOL.find(n => !taken.has(n)) || 'Child ' + (CHILDREN.length + 1);
}

/* Caregivers paste whatever the browser gave them, so accept a bare domain and
   drop anything that is not a link at all. */
function tidyLink(v){
  const t = (v || '').trim();
  if (!t) return null;
  if (/^https?:\/\//i.test(t)) return t;
  return /^[\w-]+(\.[\w-]+)+\//.test(t) || /^[\w-]+(\.[\w-]+)+$/.test(t) ? 'https://' + t : null;
}
const linkHost = u => { try { return new URL(u).hostname.replace(/^www\./, ''); } catch (e) { return 'the link'; } };
const art = (catId, cat, icon, cls) => photoFor(catId)
  ? `<div class="${cls} has-photo"><img src="${photoFor(catId)}" alt="" loading="lazy"></div>`
  : `<div class="${cls} ${catById[cat].tint}">${icon}</div>`;
const newChild = () => ({ id:uid(), alias:nextAlias(), first:'', age:'', gender:'', hh:'new',
  interests:[], note:'', items:[] });

const childTotal = c => c.items.reduce((s, i) => s + i.price, 0);
const allTotal   = () => CHILDREN.reduce((s, c) => s + childTotal(c), 0);

const STEPS = ['Your home', 'The children', 'Their lists', 'Getting paid', 'Review'];

/* ── Frame ── */
function render(){
  $('#introView').hidden = true;
  $('#flowView').hidden = false;
  $('#steps').innerHTML = STEPS.map((s, i) => `
    <div class="step ${i === step ? 'on' : ''} ${i < step ? 'done' : ''}">
      <span class="n">${i < step ? '<i class="fa-solid fa-check"></i>' : i + 1}</span>${s}
    </div>`).join('');
  const S = [stepHome, stepKids, stepLists, stepPay, stepReview, stepDone][step];
  $('#screen').innerHTML = S();
  ([bindHome, bindKids, bindLists, bindPay, bindReview, bindDone][step])();
  window.scrollTo({ top:0, behavior:'smooth' });
}

function foot(html){
  const f = $('#foot');
  if (!html){ f.hidden = true; return; }
  f.hidden = false;
  $('#footIn').innerHTML = html;
}

/* Every step gets the same centred header block. */
const stepHeader = (title, lede) => `
  <header class="step-header">
    <h1>${title}</h1>
    ${lede ? `<p class="step-lede">${lede}</p>` : ''}
  </header>`;

/* ── Step 1 · household ── */
function stepHome(){
  return `
  ${stepHeader('Start with your home',
     'This is how Atlanta Angels verifies your household and how we pay you. None of it is ever shown to a donor.')}
  <div class="panel form-card">
    <div class="row2">
      <div class="field"><label class="f" for="h_caregiver">Your name</label>
        <input class="i" id="h_caregiver" value="${H.caregiver}" placeholder="Denise Brooks"></div>
      <div class="field"><label class="f" for="h_email">Email</label>
        <input class="i" id="h_email" type="email" value="${H.email}" placeholder="denise@example.com"></div>
    </div>
    <div class="row2">
      <div class="field"><label class="f" for="h_phone">Mobile number</label>
        <input class="i" id="h_phone" value="${H.phone}" placeholder="(404) 555-0134">
        <p class="hint">We text you when your lists are funded.</p></div>
      <div class="field"><label class="f" for="h_county">County</label>
        <select class="i" id="h_county">
          <option value="">Choose one</option>
          ${['Clayton','Cobb','DeKalb','Douglas','Fulton','Gwinnett','Henry','Rockdale','South Fulton']
            .map(c => `<option ${H.county === c ? 'selected' : ''}>${c}</option>`).join('')}
        </select></div>
    </div>
    <div class="field"><label class="f" for="h_street">Home address</label>
      <input class="i" id="h_street" value="${H.street}" placeholder="1420 Peachtree Way">
      <p class="hint">Only used if you choose a mailed gift card instead of direct deposit.</p></div>
    <div class="row2">
      <div class="field"><label class="f" for="h_city">City</label>
        <input class="i" id="h_city" value="${H.city}" placeholder="Jonesboro"></div>
      <div class="field"><label class="f" for="h_zip">ZIP</label>
        <input class="i" id="h_zip" value="${H.zip}" placeholder="30236"></div>
    </div>
  </div>
  <div class="disclosure form-card mt-4">
    We confirm your placement with Atlanta Angels before your lists go live. It usually takes a day.
  </div>`;
}
function bindHome(){
  Object.keys(H).forEach(k => {
    const el = $('#h_' + k);
    if (el) el.oninput = () => { H[k] = el.value; check(); };
  });
  const ok = () => H.caregiver && H.email && H.county;
  const check = () => { const b = $('#next'); if (b) b.disabled = !ok(); };
  foot(`<span class="tiny muted">Nothing here is shown to donors.</span>
        <button class="btn btn-primary" id="next" ${ok() ? '' : 'disabled'}>Continue <i class="fa-solid fa-arrow-right"></i></button>`);
  $('#next').onclick = () => { if (!CHILDREN.length) CHILDREN.push(newChild()); step = 1; render(); };
}

/* ── Step 2 · children ── */
const SUGGESTED_INTERESTS = ['drawing','basketball','dinosaurs','reading','music','soccer','Legos','baking','video games','animals','dancing','space','skateboarding','fashion','fishing','cars'];

function childForm(c, i){
  return `
  <div class="panel form-card mb-4" data-cid="${c.id}">
    <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:18px">
      <h3 class="t-lg">Child ${i + 1}${c.first ? ' · ' + c.first : ''}</h3>
      ${CHILDREN.length > 1 ? `<button class="rm" data-delkid="${c.id}"><i class="fa-solid fa-trash"></i> Remove</button>` : ''}
    </div>
    <div class="row3">
      <div class="field"><label class="f">First name</label>
        <input class="i" data-k="first" value="${c.first}" placeholder="Amelia">
        <p class="hint"><i class="fa-solid fa-lock t-2xs"></i> Staff only. Donors see <b>${c.alias}</b>.</p></div>
      <div class="field"><label class="f">Age</label>
        <input class="i" data-k="age" type="number" min="0" max="18" value="${c.age}" placeholder="9"></div>
      <div class="field"><label class="f">Gender</label>
        <select class="i" data-k="gender">
          <option value="">Choose</option>
          <option value="girl" ${c.gender === 'girl' ? 'selected' : ''}>Girl</option>
          <option value="boy" ${c.gender === 'boy' ? 'selected' : ''}>Boy</option>
        </select></div>
    </div>

    <div class="field">
      <label class="f">What are they into?</label>
      <div class="tags" style="margin-bottom:10px" data-chips="${c.id}">
        ${c.interests.map(t => `<span class="tag" style="cursor:pointer" data-untag="${t}">${t} <i class="fa-solid fa-xmark t-2xs" style="opacity:.6"></i></span>`).join('') || '<span class="tiny muted">Nothing added yet</span>'}
      </div>
      <input class="i" data-addtag="${c.id}" placeholder="Type an interest and press enter">
      <div class="chip-scroll" style="margin-top:10px">
        ${SUGGESTED_INTERESTS.filter(t => !c.interests.includes(t)).slice(0, 9)
          .map(t => `<button class="chip btn-sm" data-tagsug="${c.id}" data-v="${t}">+ ${t}</button>`).join('')}
      </div>
    </div>
    <div class="field" style="margin-bottom:0">
      <label class="f">One thing a donor should know</label>
      <textarea class="i" data-k="note" rows="2" placeholder="Draws on every napkin in the house.">${c.note}</textarea>
      <p class="hint">This shows on their page. Keep it about who they are, not about their case.</p>
    </div>
  </div>`;
}

function stepKids(){
  return `
  ${stepHeader('Who is in your home right now?',
     'One entry per child. Donors see a stand-in name we assign, the age, and the interests. Nothing else.')}
  ${CHILDREN.map(childForm).join('')}
  <div class="form-card"><button class="btn btn-ghost" id="addKid"><i class="fa-solid fa-plus"></i> Add another child</button></div>`;
}

function bindKids(){
  $$('[data-cid]').forEach(card => {
    const c = CHILDREN.find(x => x.id === card.dataset.cid);
    $$('[data-k]', card).forEach(el => {
      el.oninput = () => {
        const k = el.dataset.k;
        if (k === 'age'){
          if (el.value !== '') el.value = String(Math.max(0, Math.min(18, Math.floor(+el.value) || 0)));
          c.age = el.value;
        }
        else c[k] = el.value;
        checkK();
      };
    });
    const tagIn = $(`[data-addtag="${c.id}"]`, card);
    tagIn.onkeydown = e => {
      if (e.key === 'Enter' && tagIn.value.trim()){
        e.preventDefault();
        c.interests.push(tagIn.value.trim().toLowerCase());
        render();
      }
    };
  });
  $('#addKid').onclick = () => { CHILDREN.push(newChild()); render(); };
  const ok = () => CHILDREN.length && CHILDREN.every(c => c.first && c.age && c.gender);
  const checkK = () => { const b = $('#next'); if (b) b.disabled = !ok(); };
  foot(`<span class="tiny muted">${CHILDREN.length} child${CHILDREN.length === 1 ? '' : 'ren'}</span>
        <button class="btn btn-primary" id="next" ${ok() ? '' : 'disabled'}>Build their lists <i class="fa-solid fa-arrow-right"></i></button>`);
  $('#next').onclick = () => { step = 2; cur = 0; render(); };
}

/* ── Step 3 · the lists ── */
/* A typed gift still tries to land on a catalog product, so the donor side
   keeps its photo and its "4 children asked for this" grouping. Only an
   unambiguous match counts; anything else becomes its own line. */
function matchCatalog(name){
  const n = name.toLowerCase().trim();
  if (n.length < 3) return null;
  const hits = CATALOG.filter(x => {
    const c = x.name.toLowerCase();
    return c === n || c.startsWith(n + ' ') || c.includes(' ' + n + ' ') || n.includes(c);
  });
  return hits.length === 1 ? hits[0] : null;
}

function stepLists(){
  const c = CHILDREN[cur];
  const total = childTotal(c);
  const who = c.first || 'them';
  return `
  ${stepHeader(`What would ${who} want?`,
     'Add five or six things, with a link if you have one. Each line becomes a gift a donor can fund.')}

  ${CHILDREN.length > 1 ? `<div class="form-card mb-4">
    <div class="chip-scroll">
      ${CHILDREN.map((k, i) => `<button class="chip ${i === cur ? 'on' : ''}" data-cur="${i}">
        ${k.first || 'Child ' + (i + 1)} · ${money(childTotal(k))}</button>`).join('')}
    </div>
  </div>` : ''}

  <div class="panel form-card">
    <div class="add-row">
      <div class="field m-0"><label class="f" for="cusName">What is it?</label>
        <input class="i" id="cusName" placeholder="Skateboard and helmet"></div>
      <div class="field m-0"><label class="f" for="cusPrice">About what it costs</label>
        <input class="i" id="cusPrice" type="number" min="5" step="5" placeholder="$"></div>
    </div>
    <div class="field mt-3 m-0"><label class="f" for="cusLink">Link to it, if you have one</label>
      <input class="i" id="cusLink" placeholder="Paste the page where you would buy it">
      <p class="hint">Optional. Donors see it as the item you had in mind.</p></div>
    <button class="btn btn-primary btn-block mt-3" id="addCustom">
      <i class="fa-solid fa-plus"></i> Add to the list</button>

    <div class="list-divider"></div>

    ${c.items.length ? c.items.map(i => `
      <div class="picked-row">
        <div style="flex:1">
          <div class="w-600 ink t-base">${i.name}</div>
          ${i.link ? `<a class="item-link" href="${i.link}" target="_blank" rel="noopener">
            <i class="fa-solid fa-link t-2xs"></i> ${linkHost(i.link)}</a>` : ''}
        </div>
        <span class="price t-base">${money(i.price)}</span>
        <button class="rm ml-3" data-drop="${i.id}" aria-label="Remove ${i.name}">
          <i class="fa-solid fa-xmark"></i></button>
      </div>`).join('')
      : '<p class="tiny muted m-0">Nothing on the list yet. Add the first thing above.</p>'}

    <div class="total-row mt-4" style="padding-top:14px; border-top:1px solid var(--line-soft)">
      <span class="muted">List total</span><b>${money(total)}</b>
    </div>
    <div class="bar ${total > CAP ? '' : 'done'}">
      <i style="width:${Math.min(100, total / CAP * 100)}%; ${total > CAP ? 'background:var(--brand-light)' : ''}"></i></div>
    <p class="tiny muted mt-2">
      ${total > CAP
        ? `Above the ${money(CAP)} we ask donors to expect. That is allowed, it just tends to take longer to fully fund.`
        : `Most lists land near ${money(CAP)}. Lists in that range usually fund completely.`}
    </p>
  </div>

  <div class="disclosure form-card mt-4">
    A donor funds a line at this price. You get the money, not the object, so if it no longer fits
    ${who} by December, buy what does.
  </div>`;
}

function bindLists(){
  const c = CHILDREN[cur];
  $$('[data-cur]').forEach(b => b.onclick = () => { cur = +b.dataset.cur; render(); });
  $$('[data-drop]').forEach(b => b.onclick = () => {
    c.items = c.items.filter(i => i.id !== b.dataset.drop); render();
  });

  const add = () => {
    const n = $('#cusName').value.trim(), p = +$('#cusPrice').value;
    if (!n || !p) return;
    const m = matchCatalog(n);
    c.items.push({ id:uid(), catId:m ? m.id : 'x' + uid(), name:n, spec:null,
                   link:tidyLink($('#cusLink').value), price:p,
                   icon:m ? m.icon : '🎁', cat:m ? m.cat : 'toys', claimed:false, claimedBy:null });
    render();
  };
  $('#addCustom').onclick = add;
  ['cusName','cusPrice','cusLink'].forEach(id => {
    $('#' + id).onkeydown = e => { if (e.key === 'Enter'){ e.preventDefault(); add(); } };
  });

  const ok = CHILDREN.every(k => k.items.length >= 1);
  foot(`<span class="tiny muted">${CHILDREN.length} list${CHILDREN.length === 1 ? '' : 's'} · ${money(allTotal())} in total</span>
        <button class="btn btn-primary" id="next" ${ok ? '' : 'disabled'}>Set up how you get paid <i class="fa-solid fa-arrow-right"></i></button>`);
  $('#next').onclick = () => { step = 3; render(); };
}

/* ── Step 4 · payout ── */
function stepPay(){
  return `
  ${stepHeader('How should we get the money to you?',
     'When your lists close on December 8, we send you everything they raised. Pick the way that actually works for your household.')}

  <div class="row2 form-card" style="gap:20px; align-items:start; max-width:900px">
    <button class="card-pick ${PAY.method === 'stripe' ? 'on' : ''}" data-pay="stripe">
      <span class="rec">Recommended</span>
      <div style="display:flex; gap:13px; align-items:flex-start">
        <span class="icon t3 t-lg" style="width:44px; height:44px; border-radius:12px; display:flex; align-items:center; justify-content:center; background:var(--green-bg)">
          <i class="fa-solid fa-building-columns c-green"></i></span>
        <div>
          <h3 class="t-md" style="margin-bottom:6px">Bank account or debit card</h3>
          <p class="t-base" style="margin:0 0 12px">Connect once through Stripe. The money lands in your account and you shop wherever you want.</p>
          <ul class="t-sm" style="margin:0; padding-left:18px; color:var(--body)">
            <li>In your account in one to two days</li>
            <li>Instant to a debit card for a $0.50 fee</li>
            <li>Works online, in store, anywhere</li>
            <li>Nothing to lose in the mail</li>
          </ul>
        </div>
      </div>
    </button>

    <button class="card-pick ${PAY.method === 'card' ? 'on' : ''}" data-pay="card">
      <div style="display:flex; gap:13px; align-items:flex-start">
        <span class="icon t-lg" style="width:44px; height:44px; border-radius:12px; display:flex; align-items:center; justify-content:center; background:var(--brand-wash)">
          <i class="fa-solid fa-credit-card c-brand"></i></span>
        <div>
          <h3 class="t-md" style="margin-bottom:6px">Visa gift card in the mail</h3>
          <p class="t-base" style="margin:0 0 12px">No bank needed. We mail a prepaid Visa to your home address.</p>
          <ul class="t-sm" style="margin:0; padding-left:18px; color:var(--soft)">
            <li>Arrives seven to ten days after lists close</li>
            <li>Some online checkouts reject prepaid cards</li>
            <li>If it is lost or stolen, the money is gone</li>
            <li>Cannot be split across two stores easily</li>
          </ul>
        </div>
      </div>
    </button>
  </div>

  <div id="payDetail" class="form-card mt-5"></div>`;
}

function bindPay(){
  $$('[data-pay]').forEach(b => b.onclick = () => { PAY.method = b.dataset.pay; render(); });
  const d = $('#payDetail');
  if (PAY.method === 'stripe'){
    d.innerHTML = PAY.connected ? `
      <div class="panel panel-green" style="max-width:640px">
        <div class="note"><i class="fa-solid fa-circle-check c-green"></i>
          <div><b class="ink">Connected.</b> Payouts go to ${PAY.bank}. You can change this any time
          from your account. Atlanta Angels never sees your full account number.</div></div>
      </div>` : `
      <div class="panel" style="max-width:640px">
        <h3 class="t-md" style="margin-bottom:8px">Connect with Stripe</h3>
        <p class="t-base" style="margin:0 0 18px">
          Stripe handles the account details, not us. You will confirm your name and date of birth,
          then link a bank account or debit card. It takes about three minutes.
        </p>
        <button class="btn btn-ink" id="connect"><i class="fa-brands fa-stripe-s"></i> &nbsp;Connect with Stripe</button>
        <p class="hint" style="margin-top:12px">Prototype: this opens a simulated Stripe screen.</p>
      </div>`;
    const c = $('#connect');
    if (c) c.onclick = stripeModal;
  } else if (PAY.method === 'card'){
    d.innerHTML = `
      <div class="panel" style="max-width:640px">
        <h3 class="t-md" style="margin-bottom:14px">Where should we mail it?</h3>
        <div class="field"><label class="f">Name on the envelope</label>
          <input class="i" id="p_name" value="${PAY.mailName || H.caregiver}"></div>
        <div class="field" style="margin-bottom:8px"><label class="f">Mailing address</label>
          <input class="i" id="p_addr" value="${PAY.mailAddr || [H.street, H.city, H.zip].filter(Boolean).join(', ')}"></div>
        <div class="panel panel-warm" style="margin-top:18px">
          <div class="note"><i class="fa-solid fa-triangle-exclamation"></i>
            <div>Gift cards are the slowest and riskiest way we pay. If a bank or debit card is possible
            at all, take that instead. You can switch later without redoing your lists.</div></div>
        </div>
      </div>`;
    $('#p_name').oninput = e => PAY.mailName = e.target.value;
    $('#p_addr').oninput = e => PAY.mailAddr = e.target.value;
  } else {
    d.innerHTML = '';
  }
  const ok = (PAY.method === 'stripe' && PAY.connected) || (PAY.method === 'card');
  foot(`<span class="tiny muted">${money(allTotal())} across ${CHILDREN.length} list${CHILDREN.length === 1 ? '' : 's'}</span>
        <button class="btn btn-primary" id="next" ${ok ? '' : 'disabled'}>Review and submit <i class="fa-solid fa-arrow-right"></i></button>`);
  $('#next').onclick = () => { step = 4; render(); };
}

function stripeModal(){
  $('#modalBox').innerHTML = `
    <div class="modal-hd">
      <div><div class="t-base" style="font-weight:700; color:#635bff; letter-spacing:-.02em">stripe</div>
      <h3 class="t-lg" style="margin-top:6px">Atlanta Angels wants to pay you</h3></div>
      <button class="x" data-close="1"><i class="fa-solid fa-xmark"></i></button>
    </div>
    <div class="modal-bd">
      <p class="muted" style="margin-top:0">Simulated Stripe Connect onboarding. In the real product this is
      Stripe's own hosted screen, so account and identity details never touch our servers.</p>
      <div class="mini" style="margin-bottom:10px"><span class="icon t3"><i class="fa-solid fa-user-check c-green"></i></span>
        <div style="flex:1"><b class="t-base ink">Identity</b><div class="tiny muted">Name, date of birth, last four of SSN</div></div>
        <span class="tag" style="background:var(--green-bg); color:var(--green)">Verified</span></div>
      <div class="mini" style="margin-bottom:18px"><span class="icon t2"><i class="fa-solid fa-building-columns" style="color:#5b6bbf"></i></span>
        <div style="flex:1"><b class="t-base ink">Payout method</b><div class="tiny muted">Choose where the money lands</div></div></div>
      <button class="card-pick on" style="margin-bottom:10px"><b class="ink">Bank account</b>
        <div class="tiny muted">Truist checking •••• 4321 · 1 to 2 business days · no fee</div></button>
      <button class="card-pick" id="altDebit"><b class="ink">Debit card</b>
        <div class="tiny muted">Visa •••• 8890 · instant · $0.50 per payout</div></button>
      <button class="btn btn-primary btn-block" style="margin-top:20px" id="finishStripe">Agree and finish</button>
    </div>`;
  $('#modal').classList.add('on');
  let bank = 'Truist checking •••• 4321';
  $('#altDebit').onclick = () => {
    bank = 'Visa debit •••• 8890';
    $('#altDebit').classList.add('on');
    $$('.card-pick')[0].classList.remove('on');
  };
  $('#finishStripe').onclick = () => {
    PAY.connected = true; PAY.bank = bank;
    $('#modal').classList.remove('on');
    render();
  };
}

/* ── Step 5 · review ── */
function stepReview(){
  return `
  ${stepHeader('One last look',
     'Once you submit, Atlanta Angels verifies your household and your lists go live to donors.')}

  <div class="row2" style="grid-template-columns:1.4fr 1fr; gap:24px; align-items:start">
    <div>
      ${CHILDREN.map(c => `
        <div class="panel" style="margin-bottom:16px">
          <div style="display:flex; align-items:center; gap:12px; margin-bottom:14px">
            <span class="avatar" style="background:var(--brand)">${c.alias[0]}</span>
            <div><div class="kid-name t-md">${c.alias}, ${c.age}</div>
              <div class="tiny muted">${c.gender === 'girl' ? 'Girl' : 'Boy'} · ${c.items.length} gifts · ${money(childTotal(c))}</div></div>
            <button class="btn btn-ghost btn-sm" style="margin-left:auto" data-edit="${CHILDREN.indexOf(c)}">Edit list</button>
          </div>
          <div class="tags" style="margin-bottom:12px">${c.interests.map(t => `<span class="tag">${t}</span>`).join('')}</div>
          ${c.items.map(i => `<div class="mini" style="margin-bottom:8px; padding:9px 11px">
            ${art(i.catId, i.cat, i.icon, 'icon icon-sm')}
            <div style="flex:1">
              <div class="t-sm w-600 ink">${i.name}</div>
              ${i.spec ? `<div class="tiny muted"><i class="fa-solid fa-tag t-2xs"></i> ${i.spec}</div>` : ''}
              ${i.link ? `<div class="tiny"><a href="${i.link}" target="_blank" rel="noopener" class="c-brand"><i class="fa-solid fa-link t-2xs"></i> ${linkHost(i.link)}</a></div>` : ''}
            </div>
            <span class="price t-base">${money(i.price)}</span></div>`).join('')}
          <div class="disclosure" style="margin-top:12px">
            Donors see: ${c.alias}, ${c.age}, ${c.interests.join(', ') || 'no interests listed'}, and these gift names.
            They do not see ${c.first || 'the first name'}, your address, or your county beyond the region.
          </div>
        </div>`).join('')}
    </div>
    <div style="position:sticky; top:78px">
      <div class="panel">
        <h3 class="t-md" style="margin-bottom:14px">Summary</h3>
        <div class="fund-line" style="margin-bottom:9px"><span>Children</span><b>${CHILDREN.length}</b></div>
        <div class="fund-line" style="margin-bottom:9px"><span>Gifts listed</span><b>${CHILDREN.reduce((s, c) => s + c.items.length, 0)}</b></div>
        <div class="fund-line" style="margin-bottom:14px"><span>If fully funded</span><b>${money(allTotal())}</b></div>
        <hr style="border:none; border-top:1px solid var(--line-soft); margin:0 0 14px">
        <div class="t-sm"><b class="ink">Paid by</b><br>
          ${PAY.method === 'stripe' ? PAY.bank + ' via Stripe' : 'Visa gift card mailed to ' + (PAY.mailAddr || 'your address')}</div>
        <button class="btn btn-primary btn-block" style="margin-top:20px" id="submit">Submit my lists</button>
        <p class="tiny muted" style="text-align:center; margin-top:10px">You can edit any list until December 8.</p>
      </div>
    </div>
  </div>`;
}

function bindReview(){
  foot('');
  $$('[data-edit]').forEach(b => b.onclick = () => { cur = +b.dataset.edit; step = 2; render(); });
  $('#submit').onclick = () => {
    try {
      const prior = JSON.parse(localStorage.getItem('aa_submitted_kids') || '[]');
      const payload = CHILDREN.map(c => ({
        id:c.id, alias:c.alias, age:+c.age, gender:c.gender,
        hh:'new', hhName:`The ${(H.caregiver.split(' ').pop() || 'new')} home`,
        area:H.county ? H.county + ' County' : 'Metro Atlanta', caregiver:H.caregiver,
        interests:c.interests, note:c.note,
        items:c.items.map(i => ({ ...i, claimed:false, claimedBy:null })),
      }));
      localStorage.setItem('aa_submitted_kids', JSON.stringify([...payload, ...prior]));
    } catch (e) { /* file:// with storage blocked, the flow still completes */ }
    step = 5; render();
  };
}

/* ── Submitted ── */
function stepDone(){
  return `
  <div style="text-align:center; margin:40px 0 32px">
    <div class="emoji-xl">✨</div>
    <h1 style="font-size:clamp(1.7rem,3.8vw,2.3rem); margin:14px 0 10px" class="text-balance">
      ${CHILDREN.length} list${CHILDREN.length === 1 ? ' is' : 's are'} in.
    </h1>
    <p class="muted" style="max-width:540px; margin:0 auto">
      Atlanta Angels is confirming your household now. Once that clears, usually within a day,
      donors can start funding.
    </p>
  </div>
  <div class="panel" style="max-width:720px; margin:0 auto">
    <h3 class="t-md" style="margin-bottom:16px">What happens from here</h3>
    <div class="flow" style="grid-template-columns:1fr; gap:12px; margin-top:20px">
      <div class="flow-step"><b>Now to December 8</b><span>Donors fund gifts one at a time. You get a text each time a line is claimed, and you can edit anything until the deadline.</span></div>
      <div class="flow-step"><b>December 9</b><span>We total each child's list and send the full amount ${PAY.method === 'stripe' ? 'to ' + PAY.bank : 'as a Visa gift card in the mail'}.</span></div>
      <div class="flow-step"><b>Whenever works for you</b><span>You shop. Right sizes, right week. If something no longer fits the child, spend it on what does. Keep the receipts in the app so we can report back to donors.</span></div>
      <div class="flow-step"><b>January</b><span>Write one short note back. We pass it to everyone who gave, without any photo or detail about the child.</span></div>
    </div>
    <div class="panel panel-warm" style="margin-top:22px">
      <div class="note"><i class="fa-solid fa-eye"></i>
        <div><b class="ink">Want to see what donors see?</b> Your lists now appear in the donor
        view of this prototype, marked new. <a href="index.html" class="link">Open the shop</a>.</div></div>
    </div>
  </div>`;
}
function bindDone(){ foot(''); }

/* ── Events ── */
document.addEventListener('click', e => {
  const del = e.target.closest('[data-delkid]');
  if (del){ CHILDREN = CHILDREN.filter(c => c.id !== del.dataset.delkid); cur = 0; render(); return; }
  const un = e.target.closest('[data-untag]');
  if (un){
    const card = un.closest('[data-cid]');
    const c = CHILDREN.find(x => x.id === card.dataset.cid);
    c.interests = c.interests.filter(t => t !== un.dataset.untag); render(); return;
  }
  const sug = e.target.closest('[data-tagsug]');
  if (sug){
    const c = CHILDREN.find(x => x.id === sug.dataset.tagsug);
    c.interests.push(sug.dataset.v); render(); return;
  }
  if (e.target.closest('[data-close]') || e.target.id === 'modalScrim') $('#modal').classList.remove('on');
});

$('#start').onclick = () => { step = 0; render(); };
$('#helpLink').onclick = e => {
  e.preventDefault();
  $('#modalBox').innerHTML = `
    <div class="modal-hd"><h3 class="t-lg">We can do this with you</h3>
      <button class="x" data-close="1"><i class="fa-solid fa-xmark"></i></button></div>
    <div class="modal-bd">
      <p>Call or text your Angels coordinator at (404) 555-0180 and they will build the lists with you
      over the phone. Plenty of families do it that way.</p>
      <p class="muted" style="margin-bottom:0">If you are between placements or a child leaves before December 8,
      tell us and we redirect that list rather than cancel it.</p>
    </div>`;
  $('#modal').classList.add('on');
};
