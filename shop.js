/* ──────────────────────────────────────────────
   Atlanta Angels · Wish List — donor side
   The catalog is assembled from the children's lists, so browsing by
   category and browsing by child are two views of the same rows.
   ────────────────────────────────────────────── */

const $  = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const money = n => '$' + Math.round(n).toLocaleString();
const hhById = Object.fromEntries(HOUSEHOLDS.map(h => [h.id, h]));
/* Submitted lists carry their own household label rather than a seed id. */
const house = k => hhById[k.hh] || { name:k.hhName || 'A new household', area:k.area || 'Metro Atlanta', caregiver:k.caregiver || 'their caregiver' };

/* Lists submitted from the caregiver side land here, so the two halves of
   the prototype are one loop instead of two demos. */
function loadSubmitted(){
  try {
    const raw = localStorage.getItem('aa_submitted_kids');
    if (!raw) return [];
    return JSON.parse(raw).map(k => ({ ...k, fresh:true }));
  } catch (e) { return []; }
}
const kids = [...loadSubmitted(), ...KIDS];
const kidById = Object.fromEntries(kids.map(k => [k.id, k]));
const itemIds = new Set(kids.flatMap(k => k.items.map(i => i.id)));

const linkHost = u => { try { return new URL(u).hostname.replace(/^www\./, ''); } catch (e) { return 'the link'; } };
const linkChip = it => it.link
  ? `<a class="item-link" href="${it.link}" target="_blank" rel="noopener nofollow"
        onclick="event.stopPropagation()"><i class="fa-solid fa-arrow-up-right-from-square"></i>
        What their caregiver linked <span class="muted">${linkHost(it.link)}</span></a>`
  : '';

/* Avatar and confetti colours come from the active theme rather than a fixed
   palette, so a partner skin does not leave the previous brand behind. */
const themeVar = n => getComputedStyle(document.documentElement).getPropertyValue(n).trim();
const themeList = (prefix, n, fallback) => {
  const out = [];
  for (let i = 1; i <= n; i++){ const v = themeVar(`--${prefix}-${i}`); if (v) out.push(v); }
  return out.length ? out : fallback;
};
const AV = themeList('av', 6, ['#a29060','#ed1566','#2f7d5d','#5b6bbf','#c2700a','#7d5ba6']);
const avatarColor = id => AV[[...id].reduce((a,c) => a + c.charCodeAt(0), 0) % AV.length];

/* The cart has to survive the jump to a category page, so it lives in
   storage rather than in memory. */
function loadCart(){
  try { return JSON.parse(localStorage.getItem('aa_cart') || '[]'); } catch (e) { return []; }
}
function saveCart(){
  try { localStorage.setItem('aa_cart', JSON.stringify(cart)); } catch (e) { /* file:// with storage off */ }
}

const PAGE = document.body.dataset.page || 'home';
const params = new URLSearchParams(location.search);

let cart = [];
let tab = 'browse';
const filters = { cat:'all', gender:'all', age:'all', price:'all' };

cart = loadCart().filter(l => l.type === 'flex' || (itemIds.has(l.itemId) && kidById[l.kidId]));

const rows = () => kids.flatMap(k => k.items.map(it => ({ ...it, kid:k })));

/* Two children asking for a hoodie is one hoodie tile that needs two.
   Grouping happens on the catalog id, so a caregiver's brand request stays
   inside the group it belongs to instead of becoming its own product. */
function groups(list = rows()){
  const m = new Map();
  list.forEach(r => {
    if (!m.has(r.catId)) m.set(r.catId, { catId:r.catId, cat:r.cat, icon:r.icon,
      name:(catalogById[r.catId] || {}).name || r.name, rows:[] });
    m.get(r.catId).rows.push(r);
  });
  return [...m.values()];
}
const groupOpen = g => g.rows.filter(r => !r.claimed && !inCart(r.id));
const inCart = itemId => cart.some(l => l.type === 'item' && l.itemId === itemId);
const openLines = () => rows().filter(r => !r.claimed);

const kidTotal   = k => k.items.reduce((s, i) => s + i.price, 0);
const kidFunded  = k => k.items.filter(i => i.claimed).reduce((s, i) => s + i.price, 0);
const kidLeft    = k => k.items.filter(i => !i.claimed && !inCart(i.id));
const cartTotal  = () => cart.reduce((s, l) => s + (l.type === 'item' ? l.price : l.amount), 0);

const ageBand = a => a <= 5 ? '0-5' : a <= 9 ? '6-9' : a <= 12 ? '10-12' : '13-18';

function matches(r){
  const k = r.kid;
  if (filters.cat !== 'all'    && r.cat !== filters.cat) return false;
  if (filters.gender !== 'all' && k.gender !== filters.gender) return false;
  if (filters.age !== 'all'    && ageBand(k.age) !== filters.age) return false;
  if (filters.price === 'u25'  && r.price > 25) return false;
  if (filters.price === '25-50'&& (r.price < 25 || r.price > 50)) return false;
  if (filters.price === '50-100'&& (r.price < 50 || r.price > 100)) return false;
  if (filters.price === '100+' && r.price < 100) return false;
  return true;
}

/* ── Tiles ── */
/* One art element for both treatments: a photo when we have one, the tinted
   emoji tile when we do not. */
function art(catId, cat, icon, cls = 'tile-art'){
  const photo = photoFor(catId);
  return photo
    ? `<div class="${cls} has-photo"><img src="${photo}" alt="${(catalogById[catId] || {}).name || ''}" loading="lazy"></div>`
    : `<div class="${cls} ${catById[cat].tint}">${icon}</div>`;
}

function tile(r){
  const dis  = r.claimed;
  const has  = inCart(r.id);
  return `
  <div class="tile ${dis ? 'is-claimed' : ''}" data-kid="${r.kid.id}">
    <div class="art-wrap">
      ${art(r.catId, r.cat, r.icon)}
      <span class="cat-tag">${catById[r.cat].label.split(' ')[0]}</span>
      ${dis ? '<span class="claimed-tag"><i class="fa-solid fa-check"></i> Funded</span>' : ''}
    </div>
    <div class="tile-body">
      <div class="tile-name">${r.name}</div>
      <div class="tile-for">
        <span class="dot" style="background:${avatarColor(r.kid.id)}">${r.kid.alias[0]}</span>
        For ${r.kid.alias}, ${r.kid.age}
      </div>
      <div class="tile-foot">
        <span class="price">${money(r.price)}</span>
        ${dis ? '<span class="tiny muted">Thank you</span>'
              : `<button class="add-btn ${has ? 'in' : ''}" data-add="${r.id}" aria-label="Add to cart">
                   <i class="fa-solid ${has ? 'fa-check' : 'fa-plus'}"></i></button>`}
      </div>
    </div>
  </div>`;
}

/* A product tile. It shows how many are still needed and never adds to the
   cart directly, because quantity is a decision the donor makes inside. */
function productTile(g){
  const open = g.rows.filter(r => !r.claimed);
  const carted = g.rows.filter(r => !r.claimed && inCart(r.id)).length;
  const left = open.filter(r => !inCart(r.id));
  /* Fall back to every row once nothing is open, so a fully funded tile keeps
     showing what it cost instead of $0. */
  const prices = [...new Set((open.length ? open : g.rows).map(r => r.price))];
  const spec = open.filter(r => r.spec).length;
  const done = !left.length;
  /* In the cart is reserved, not funded. Saying "All funded" here would take
     credit for money nobody has given yet. */
  return `
  <div class="tile ${done ? 'is-claimed' : ''}" data-product="${g.catId}"
       role="button" tabindex="0"
       aria-label="${g.name}. ${left.length ? left.length + ' still needed' : 'Fully funded'}. See details.">
    <div class="art-wrap">
      ${art(g.catId, g.cat, g.icon)}
      <span class="cat-tag">${catById[g.cat].label.split(' ')[0]}</span>
      ${done ? (carted ? '<span class="cart-tag"><i class="fa-solid fa-cart-shopping"></i> In your cart</span>'
                        : '<span class="claimed-tag"><i class="fa-solid fa-check"></i> All funded</span>')
             : left.length > 1 ? `<span class="need-tag">${left.length} needed</span>` : ''}
    </div>
    <div class="tile-body">
      <div class="tile-name">${g.name}</div>
      <div class="tile-for">
        ${left.length === 1
          ? `<span class="dot" style="background:${avatarColor(left[0].kid.id)}">${left[0].kid.alias[0]}</span>
             For ${left[0].kid.alias}, ${left[0].kid.age}`
          : left.length
            ? `<i class="fa-solid fa-children" style="opacity:.5"></i> ${left.length} children asked for this`
            : carted
              ? `<i class="fa-solid fa-cart-shopping" style="color:var(--brand-deep)"></i> ${carted} in your cart`
              : '<i class="fa-solid fa-circle-check c-green"></i> Every one is funded'}
      </div>
      ${spec && left.length > 1 ? `<div class="tiny c-brand">
        <i class="fa-solid fa-tag t-2xs"></i> ${spec} specific request${spec > 1 ? 's' : ''}</div>` : ''}
      <div class="tile-foot">
        <span class="price">${prices.length > 1 ? 'from ' + money(Math.min(...prices)) : money(prices[0] || 0)}</span>
        ${done ? '<span class="tiny muted">Thank you</span>'
               : `<span class="add-btn ${carted ? 'in' : ''}">
                    <i class="fa-solid ${carted ? 'fa-check' : 'fa-plus'}"></i></span>`}
      </div>
    </div>
  </div>`;
}

function kidCard(k){
  const total = kidTotal(k), funded = kidFunded(k), left = kidLeft(k);
  const pct = Math.round(funded / total * 100);
  return `
  <div class="kid-card" data-kid="${k.id}" role="button" tabindex="0"
       aria-label="${k.alias}, ${k.age}. See their list.">
    <div class="kid-top">
      <span class="avatar" style="background:${avatarColor(k.id)}">${k.alias[0]}</span>
      <div>
        <div class="kid-name">${k.alias}, ${k.age}</div>
        <div class="kid-meta">${k.gender === 'girl' ? 'Girl' : 'Boy'} · ${house(k).area}</div>
      </div>
      ${k.fresh ? '<span class="tag" style="margin-left:auto; background:var(--accent-wash); color:var(--accent-deep)">New</span>' : ''}
    </div>
    <div class="tags">${k.interests.slice(0,3).map(t => `<span class="tag">${t}</span>`).join('')}</div>
    <div class="bar ${pct>= 100 ? 'done' : ''}"><i style="width:${pct}%"></i></div>
    <div class="fund-line">
      <span><b>${money(funded)}</b> of ${money(total)} funded</span>
      <span>${left.length ? left.length + ' gift' + (left.length > 1 ? 's' : '') + ' left'
              : k.items.some(i => inCart(i.id)) ? 'In your cart' : 'Complete'}</span>
    </div>
  </div>`;
}

/* ── Tabs ── */
function renderTabs(){
  const open = openLines().length;
  const almost = kids.filter(k => kidLeft(k).length === 1 && kidFunded(k) > 0).length;
  const t = [
    ['browse',   'fa-shapes',  'Browse gifts', ''],
    ['kids',     'fa-children','By child', kids.length],
    ['unclaimed','fa-hourglass-half','Still unfunded', open],
    ['flex',     'fa-heart',   'Give any amount', ''],
  ];
  $('#tabs').innerHTML = t.map(([id, ic, lbl, n]) => `
    <button class="tab ${tab === id ? 'on' : ''}" data-tab="${id}">
      <i class="fa-solid ${ic}"></i> ${lbl} ${n !== '' ? `<span class="pill">${n}</span>` : ''}
    </button>`).join('');
}

/* One goal beats four flat stats: it gives the page a finish line. */
function seasonPanel(){
  const panel = $('#seasonPanel');
  if (!panel) return;
  const all    = rows();
  const goal   = all.reduce((s, r) => s + r.price, 0);
  const raised = all.filter(r => r.claimed).reduce((s, r) => s + r.price, 0);
  const pct    = Math.round(raised / goal * 100);
  panel.innerHTML = `
    <div class="season">
      <div class="season-top">
        <div class="season-raised">${money(raised)} <span>of ${money(goal)} for this year's lists</span></div>
        <span class="season-deadline"><i class="fa-regular fa-clock"></i> Closes December 8</span>
      </div>
      <div class="season-bar"><i style="width:${Math.max(pct, 2)}%"></i></div>
      <div class="season-legs">
        <div class="season-leg"><b>${all.filter(r => r.claimed).length}</b>gifts funded</div>
        <div class="season-leg"><b>${kids.length}</b>children with lists</div>
        <div class="season-leg"><b>${kids.filter(k => !kidLeft(k).length).length}</b>lists finished</div>
        <div class="season-leg"><b>${pct}%</b>of the way there</div>
      </div>
    </div>`;
}

/* One pill per dimension. The pill states the current answer, so the row
   reads as a sentence rather than a wall of unselected options. */
const FILTER_OPTS = {
  gender: [['all','Anyone'], ['girl','A girl'], ['boy','A boy']],
  age:    [['all','Any age'], ['0-5','0 to 5'], ['6-9','6 to 9'], ['10-12','10 to 12'], ['13-18','13 to 18']],
  price:  [['all','Any price'], ['u25','Under $25'], ['25-50','$25 to $50'], ['50-100','$50 to $100'], ['100+','$100 and up']],
  cat:    [['all','All categories'], ...CATEGORIES.map(c => [c.id, c.label])],
};
const FILTER_ICON = { gender:'fa-child-reaching', age:'fa-cake-candles', price:'fa-tag', cat:'fa-shapes' };
const filterLabel = grp => (FILTER_OPTS[grp].find(o => o[0] === filters[grp]) || FILTER_OPTS[grp][0])[1];

function drop(grp){
  const set = filters[grp] !== 'all';
  return `
  <div class="fdrop" data-drop="${grp}">
    <button class="fpill ${set ? 'on' : ''}" aria-haspopup="true" aria-expanded="false">
      <i class="fa-solid ${FILTER_ICON[grp]}"></i>${filterLabel(grp)}
      <i class="fa-solid fa-chevron-down caret"></i>
    </button>
    <div class="fmenu" role="menu">
      ${FILTER_OPTS[grp].map(([v, lbl]) => `
        <button class="fopt ${filters[grp] === v ? 'on' : ''}" data-f="${grp}" data-v="${v}"
                data-href="${grp === 'cat' && v !== 'all' && PAGE === 'home' ? 'category.html?c=' + v : ''}" role="menuitem">
          ${grp === 'cat' && v !== 'all' ? `<i class="fa-solid ${catById[v].icon} fopt-ic"></i>` : ''}
          <span>${lbl}</span>
          ${filters[grp] === v ? '<i class="fa-solid fa-check tick"></i>' : ''}
        </button>`).join('')}
    </div>
  </div>`;
}

function filterBar(opts = {}){
  const grps = ['gender', 'age', ...(opts.price === false ? [] : ['price']), ...(opts.cats === false ? [] : ['cat'])];
  const anySet = grps.some(g => filters[g] !== 'all');
  return `
  <div class="filters">
    ${grps.map(drop).join('')}
    ${anySet ? '<button class="btn-plain btn-sm" data-clear="1">Clear all</button>' : ''}
  </div>`;
}

/* Editorial shelves. Same rows as the category rails, sliced the way a person
   would pitch them rather than the way a taxonomy would. */
function shelves(){
  const out = [];
  const shelf = (kicker, tone, title, blurb, body) => out.push(`
    <section class="shelf">
      <div class="shelf-head">
        <div>
          <h2><span class="shelf-kicker ${tone}">${kicker}</span> ${title}</h2>
          <p>${blurb}</p>
        </div>
      </div>
      <div class="rail">${body}</div>
    </section>`);

  const almost = kids.filter(k => kidLeft(k).length === 1);
  if (almost.length) shelf('Almost there', '', 'One gift from a finished list',
    'A single line stands between these kids and a complete list.',
    almost.map(k => tile({ ...kidLeft(k)[0], kid:k })).join(''));

  const untouched = kids.filter(k => !kidFunded(k) && kidLeft(k).length);
  if (untouched.length) shelf('Still waiting', 'gold', 'Nobody has funded these yet',
    'Every list here is at zero. Being first on a list changes it the most.',
    untouched.map(kidCard).join(''));

  const cheap = groups(rows().filter(r => !r.claimed && r.price <= 40));
  if (cheap.length) shelf('Easy yes', 'green', 'Everything under $40',
    'Small gifts finish lists. Most of these are the last line on somebody\'s.',
    cheap.map(productTile).join(''));

  const teens = kids.filter(k => k.age >= 13 && kidLeft(k).length);
  if (teens.length) shelf('The hard part', '', 'Teenagers get skipped',
    'Younger kids get picked first every year. These lists are practical, and they matter more.',
    teens.map(kidCard).join(''));

  const fresh = kids.filter(k => k.fresh).concat(kids.filter(k => !k.fresh).slice(-4)).slice(0, 6);
  if (fresh.length) shelf('Just added', 'gold', 'New lists this week',
    'Caregivers who finished their lists in the last few days.',
    fresh.map(kidCard).join(''));

  return out.join('') + '<hr class="shelf-rule">';
}

function renderBrowse(){
  const list = rows().filter(matches);
  const anyFilter = filters.cat !== 'all' || filters.gender !== 'all' || filters.age !== 'all' || filters.price !== 'all';
  if (anyFilter){
    const gs = groups(list);
    return filterBar() + `
      <div class="sec">
        <div class="sec-head">
          <div><h2>${gs.length} gift${gs.length === 1 ? '' : 's'} match</h2>
          <p>${list.filter(r => !r.claimed).length} still needed across them</p></div>
        </div>
        <div class="grid">${gs.map(productTile).join('') || '<p class="muted">Nothing matches yet. Try widening the price range.</p>'}</div>
      </div>`;
  }
  const secs = CATEGORIES.map(c => {
    const gs = groups(list.filter(r => r.cat === c.id));
    if (!gs.length) return '';
    const need = list.filter(r => r.cat === c.id && !r.claimed).length;
    const open = gs.filter(g => g.rows.some(r => !r.claimed));
    return `
    <div class="sec">
      <div class="sec-head">
        <div><h2><i class="fa-solid ${c.icon} t-md" style="color:var(--brand); margin-right:9px"></i>${c.label}</h2>
        <p>${need} still needed · from ${money(Math.min(...list.filter(r => r.cat === c.id).map(r => r.price)))}</p></div>
        <a class="sec-link" href="category.html?c=${c.id}">See all ${gs.length} <i class="fa-solid fa-chevron-right t-2xs"></i></a>
      </div>
      <div class="rail">${[...open, ...gs.filter(g => !open.includes(g))].map(productTile).join('')}</div>
    </div>`;
  }).join('');
  return filterBar() + shelves() + secs;
}

function renderKids(){
  const list = kids.filter(k =>
    (filters.gender === 'all' || k.gender === filters.gender) &&
    (filters.age === 'all' || ageBand(k.age) === filters.age));
  return filterBar({ cats:false, price:false }) + `
    <div class="sec">
      <div class="sec-head"><div>
        <h2>${list.length} children waiting on a list</h2>
        <p>Names are aliases their caregiver chose. Tap a child to see everything they asked for.</p>
      </div></div>
      <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(280px,1fr))">
        ${list.map(kidCard).join('')}
      </div>
    </div>`;
}

function renderUnclaimed(){
  const almost = kids.filter(k => kidLeft(k).length === 1);
  const gs = groups(openLines().filter(matches))
    .sort((a, b) => groupOpen(b).length - groupOpen(a).length || a.name.localeCompare(b.name));
  return `
  ${almost.length ? `
  <div class="sec">
    <div class="sec-head"><div>
      <h2>One gift from a finished list</h2>
      <p>These children have a single line left. Closing it finishes their whole list.</p>
    </div></div>
    <div class="rail">${almost.map(k => tile({ ...kidLeft(k)[0], kid:k })).join('')}</div>
  </div>` : ''}
  ${filterBar()}
  <div class="sec">
    <div class="sec-head"><div>
      <h2>Everything still unfunded</h2>
      <p>${openLines().filter(matches).length} gifts across ${gs.length} products, most-needed first.</p>
    </div></div>
    <div class="grid">${gs.map(productTile).join('') || '<p class="muted">Every gift is funded. That has never happened before.</p>'}</div>
  </div>`;
}

function renderFlex(){
  const short = kids.map(k => ({ k, gap:kidTotal(k) - kidFunded(k) })).filter(x => x.gap > 0)
                    .sort((a, b) => a.gap - b.gap);
  return `
  <div class="sec" style="padding-top:30px">
    <div class="panel" style="padding:30px; max-width:760px">
      <h2 class="t-xl" style="margin-bottom:10px">Give an amount instead</h2>
      <p style="margin:0 0 22px">
        If nothing on the lists is quite right, or you have an amount in mind rather than an item,
        this goes to the same place: the households with the furthest-behind lists, in the order
        that finishes the most lists.
      </p>
      <div class="filters" style="padding:0 0 16px">
        ${FLEX_PRESETS.map(a => `<button class="chip" data-flex="${a}">${money(a)}</button>`).join('')}
      </div>
      <div class="row2" style="align-items:end">
        <div class="field" style="margin:0">
          <label class="f" for="flexAmt">Any amount</label>
          <input class="i" id="flexAmt" type="number" min="5" step="5" placeholder="75">
        </div>
        <button class="btn btn-primary" id="flexAdd" style="height:47px">Add to cart</button>
      </div>
      <div class="disclosure" style="margin-top:20px">
        Unlike the gift lines, this one is not promised to a specific child up front. We apply it
        at close, and your receipt in January names the households it reached.
      </div>
    </div>
  </div>
  <div class="sec">
    <div class="sec-head"><div>
      <h2>Where it would land today</h2>
      <p>The five lists with the smallest remaining gap.</p>
    </div></div>
    <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(280px,1fr))">
      ${short.slice(0,5).map(x => kidCard(x.k)).join('')}
    </div>
  </div>`;
}

/* ── Category landing page ── */
let catQty = 2;

function renderCategory(){
  const c = catById[params.get('c')] || CATEGORIES[0];
  document.title = `${c.label} | Atlanta Angels Wish List`;
  const all  = rows().filter(r => r.cat === c.id);
  const open = all.filter(r => !r.claimed && !inCart(r.id));
  const kidsHere = [...new Set(open.map(r => r.kid.id))];
  const allTotal = open.reduce((s2, r) => s2 + r.price, 0);
  const pick = open.slice(0, Math.min(catQty, open.length));
  const pickTotal = pick.reduce((s2, r) => s2 + r.price, 0);
  const shown = groups(all.filter(matches));

  $('#catBody').innerHTML = `
  <div class="cat-hero">
    <div class="container">
      <a class="btn-plain" href="index.html"><i class="fa-solid fa-arrow-left"></i> &nbsp;All categories</a>
      <div class="cat-head">
        <div>
          <span class="cat-eyebrow"><i class="fa-solid ${c.icon}"></i> ${c.label}</span>
          <h1>${CAT_COPY[c.id] || c.label}</h1>
          <p class="cat-lede">
            ${open.length} gift${open.length === 1 ? '' : 's'} in this category are still unfunded,
            asked for by ${kidsHere.length} ${kidsHere.length === 1 ? 'child' : 'children'} across
            ${[...new Set(open.map(r => r.kid.hh))].length} verified households.
          </p>
        </div>

        <div class="panel cat-cta">
          <h3 class="t-md" style="margin-bottom:4px">Fund this category</h3>
          <p class="tiny muted" style="margin:0 0 16px">
            We apply each gift to the child who has been waiting longest.</p>
          <div class="stepper-row" style="margin-bottom:14px">
            <div class="stepper">
              <button class="step-btn" data-catq="-1" ${catQty <= 1 ? 'disabled' : ''}><i class="fa-solid fa-minus"></i></button>
              <span class="step-n">${pick.length}</span>
              <button class="step-btn" data-catq="1" ${catQty>= open.length ? 'disabled' : ''}><i class="fa-solid fa-plus"></i></button>
            </div>
            <div style="flex:1">
              <div class="tiny muted">gift${pick.length === 1 ? '' : 's'} from this category</div>
              <div class="price">${money(pickTotal)}</div>
            </div>
          </div>
          <button class="btn btn-primary btn-block" data-catadd="some" ${!pick.length ? 'disabled' : ''}>
            Add ${pick.length} to cart · ${money(pickTotal)}</button>
          <button class="btn btn-ghost btn-block" style="margin-top:10px" data-catadd="all" ${!open.length ? 'disabled' : ''}>
            Cover the whole category · ${money(allTotal)}</button>
          <p class="tiny muted" style="margin:12px 0 0; text-align:center">
            ${open.length} gifts for ${kidsHere.length} children</p>
        </div>
      </div>
    </div>
  </div>

  <div class="container">
    ${filterBar({ cats:false })}
    <div class="sec">
      <div class="sec-head"><div>
        <h2>Everything on this list</h2>
        <p>${shown.length} product${shown.length === 1 ? '' : 's'}, grouped so repeats show as one tile.</p>
      </div></div>
      <div class="grid">${shown.map(productTile).join('') || '<p class="muted">Nothing matches these filters.</p>'}</div>
    </div>

    <div class="sec">
      <div class="sec-head"><div><h2>Other categories</h2></div></div>
      <div class="chip-scroll" style="padding-bottom:30px">
        ${CATEGORIES.filter(x => x.id !== c.id).map(x => {
          const n = rows().filter(r => r.cat === x.id && !r.claimed).length;
          return `<a class="chip" href="category.html?c=${x.id}">
            <i class="fa-solid ${x.icon}" style="opacity:.6; margin-right:7px"></i>${x.label}
            <span style="color:var(--faint); margin-left:6px">${n}</span></a>`;
        }).join('')}
      </div>
    </div>
  </div>`;
  renderCart();
}

function render(){
  if (PAGE === 'category'){ renderCategory(); observeReveals(); return; }
  renderTabs();
  seasonPanel();
  $('#tabBody').innerHTML =
    tab === 'browse' ? renderBrowse() :
    tab === 'kids'   ? renderKids()   :
    tab === 'unclaimed' ? renderUnclaimed() : renderFlex();
  renderCart();
  observeReveals();
}

/* ── Cart ── */
function renderCart(){
  saveCart();
  $('#cartCount').textContent = cart.length;
  const body = $('#drawerBody'), foot = $('#drawerFoot');
  if (!cart.length){
    body.innerHTML = `<div style="text-align:center; padding:50px 10px">
      <div class="emoji-lg">🎁</div>
      <p class="muted" style="margin-top:12px">Nothing in your cart yet.</p></div>`;
    foot.innerHTML = `<button class="btn btn-ghost btn-block" id="closeDrawer2">Browse the lists</button>`;
    $('#closeDrawer2').onclick = closeDrawer;
    return;
  }
  body.innerHTML = cart.map((l, i) => {
    if (l.type === 'flex') return `
      <div class="line" style="--i:${i}">
        <div class="line-art t5">💛</div>
        <div style="flex:1">
          <div class="line-name">Give where it is needed</div>
          <div class="line-sub">Applied to the closest-to-complete lists</div>
          <button class="rm" data-rm="${i}">Remove</button>
        </div>
        <div class="price">${money(l.amount)}</div>
      </div>`;
    const k = kidById[l.kidId];
    return `
      <div class="line" style="--i:${i}">
        ${art(l.catId, l.cat, l.icon, 'line-art')}
        <div style="flex:1">
          <div class="line-name">${l.name}</div>
          <div class="line-sub">${l.spec ? l.spec + ' · ' : ''}For ${k.alias}, ${k.age}</div>
          <button class="rm" data-rm="${i}">Remove</button>
        </div>
        <div class="price">${money(l.price)}</div>
      </div>`;
  }).join('');
  foot.innerHTML = `
    <div class="total-row"><span class="muted">Total</span><b>${money(cartTotal())}</b></div>
    <button class="btn btn-primary btn-block" id="toCheckout">Review and give</button>
    <p class="tiny muted" style="text-align:center; margin:11px 0 0">
      Donations to Atlanta Angels, directed to each child's household. Nothing ships.</p>`;
  $('#toCheckout').onclick = () => {
    if (PAGE === 'home'){ closeDrawer(); showCheckout(); }
    else { saveCart(); location.href = 'index.html?checkout=1'; }
  };
}

function addItem(itemId){
  const r = rows().find(x => x.id === itemId);
  if (!r || r.claimed) return;
  const at = cart.findIndex(l => l.type === 'item' && l.itemId === itemId);
  if (at > -1) cart.splice(at, 1);
  else cart.push({ type:'item', itemId, kidId:r.kid.id, name:r.name, spec:r.spec,
                   price:r.price, icon:r.icon, cat:r.cat, catId:r.catId });
  render();
if (PAGE === 'home' && params.get('checkout') && cart.length) showCheckout();
  if (modalState && $('#modal').classList.contains('on')){
    modalState.kind === 'kid' ? openKid(modalState.key) : openProduct(modalState.key);
  }
}

/* Whatever had focus before a layer opened gets it back when the layer
   closes, so keyboard users are not dumped at the top of the document. */
let restoreFocus = null;
const remember = () => { restoreFocus = document.activeElement; };
const giveBack = () => { if (restoreFocus && restoreFocus.isConnected) restoreFocus.focus(); restoreFocus = null; };

let cascadeTimer;
const openDrawer  = () => {
  remember();
  const d = $('#drawer');
  d.classList.add('on'); $('#scrim').classList.add('on');
  /* Restart the stagger on each open. Dropped after it plays so that adding or
     removing a line while the drawer is open does not re-cascade the whole list. */
  d.classList.remove('cascade'); void d.offsetWidth; d.classList.add('cascade');
  clearTimeout(cascadeTimer);
  cascadeTimer = setTimeout(() => d.classList.remove('cascade'), 200 + cart.length * 60);
  $('#closeDrawer').focus();
};
const closeDrawer = () => { $('#drawer').classList.remove('on'); $('#scrim').classList.remove('on'); giveBack(); };
const closeModal  = () => { $('#modal').classList.remove('on'); modalState = null; giveBack(); };

/* ── Product detail ── */
let modalState = null;
const qty = {};

function openProduct(catId){
  const g = groups().find(x => x.catId === catId);
  if (!g) return;
  modalState = { kind:'product', key:catId };
  const open    = g.rows.filter(r => !r.claimed && !inCart(r.id));
  const generic = open.filter(r => !r.spec);
  const spec    = open.filter(r => r.spec);
  const carted  = g.rows.filter(r => inCart(r.id));
  const funded  = g.rows.filter(r => r.claimed);
  const n = Math.min(qty[catId] || (generic.length ? 1 : 0), generic.length);
  const runningTotal = generic.slice(0, n).reduce((s2, r) => s2 + r.price, 0);

  $('#modalBox').innerHTML = `
    <div class="modal-hd">
      <div style="display:flex; gap:15px; align-items:center">
        ${art(g.catId, g.cat, g.icon, 'prod-art')}
        <div>
          <h3 class="t-xl">${g.name}</h3>
          <div class="kid-meta">${catById[g.cat].label} · ${open.length + carted.length} still needed
            of ${g.rows.length} asked for</div>
        </div>
      </div>
      <button class="x" data-close="1"><i class="fa-solid fa-xmark"></i></button>
    </div>
    <div class="modal-bd">
      ${generic.length ? `
      <div class="panel" style="padding:20px; margin-bottom:16px">
        <h4 class="t-md" style="margin-bottom:5px">Fund one for any child who asked</h4>
        <p class="tiny muted" style="margin:0 0 16px">
          Waiting: ${generic.map(r => r.kid.alias + ', ' + r.kid.age).join(' · ')}.
          We apply each one to the child who has been waiting longest, and name them on your receipt.
        </p>
        <div class="stepper-row">
          <div class="stepper">
            <button class="step-btn" data-qty="${catId}" data-d="-1" ${n <= 0 ? 'disabled' : ''}>
              <i class="fa-solid fa-minus"></i></button>
            <span class="step-n">${n}</span>
            <button class="step-btn" data-qty="${catId}" data-d="1" ${n>= generic.length ? 'disabled' : ''}>
              <i class="fa-solid fa-plus"></i></button>
          </div>
          <div style="flex:1">
            <div class="tiny muted">of ${generic.length} still needed</div>
            <div class="price">${money(runningTotal)}</div>
          </div>
          <button class="btn btn-primary" data-addqty="${catId}" ${n <= 0 ? 'disabled' : ''}>
            Add ${n || ''} to cart</button>
        </div>
      </div>` : ''}

      ${spec.length ? `
      <h4 class="t-base" style="margin:${generic.length ? '22px' : '4px'} 0 4px">
        ${generic.length ? 'Or fund a specific request' : 'Specific requests'}</h4>
      <p class="tiny muted" style="margin:0 0 12px">These caregivers named a brand or a size.</p>
      ${spec.map(r => `
        <div class="mini" style="margin-bottom:9px">
          ${art(r.catId, r.cat, r.icon, 'icon')}
          <div style="flex:1">
            <div class="t-base w-600 ink">${r.spec}</div>
            <div class="tiny muted">For ${r.kid.alias}, ${r.kid.age}</div>
            ${linkChip(r)}
          </div>
          <span class="price t-base">${money(r.price)}</span>
          <button class="add-btn" data-add="${r.id}" style="margin-left:10px"><i class="fa-solid fa-plus"></i></button>
        </div>`).join('')}` : ''}

      ${carted.length ? `
      <div class="panel panel-warm" style="padding:14px 16px; margin-top:18px">
        <div class="note"><i class="fa-solid fa-cart-shopping" style="color:var(--brand-deep)"></i>
          <div>${carted.length} in your cart for ${carted.map(r => r.kid.alias).join(', ')}.
          <button class="rm" data-undo="${catId}" style="margin-left:6px">Remove them</button></div></div>
      </div>` : ''}

      ${funded.length ? `<p class="tiny muted" style="margin-top:16px">
        ${funded.length} already funded by ${[...new Set(funded.map(r => r.claimedBy))].join(', ')}.</p>` : ''}

      <div class="disclosure" style="margin-top:16px">
        This request was added by the child's caregiver, and their household is verified by Atlanta Angels.
        What you fund is recorded against their list and sent to that household. A named brand is the
        request we pass along, not a guarantee of what gets bought.
      </div>
    </div>`;
  if (!$('#modal').classList.contains('on')) remember();
  $('#modal').classList.add('on');
  const x = $('#modalBox .x'); if (x) x.focus();
}

/* ── Child detail ── */
function openKid(kidId){
  const k = kidById[kidId];
  if (!k) return;
  modalState = { kind:'kid', key:kidId };
  const left = kidLeft(k), total = kidTotal(k), funded = kidFunded(k);
  const pct = Math.round(funded / total * 100);
  $('#modalBox').dataset.kid = kidId;
  $('#modalBox').innerHTML = `
    <div class="modal-hd">
      <div style="display:flex; gap:14px; align-items:center">
        <span class="avatar t-xl" style="background:${avatarColor(k.id)}; width:58px; height:58px">${k.alias[0]}</span>
        <div>
          <h3 class="t-xl">${k.alias}, ${k.age}</h3>
          <div class="kid-meta">${k.gender === 'girl' ? 'Girl' : 'Boy'} · ${house(k).name} · ${house(k).area}</div>
        </div>
      </div>
      <button class="x" data-close="1"><i class="fa-solid fa-xmark"></i></button>
    </div>
    <div class="modal-bd">
      <div class="tags" style="margin-bottom:16px">${k.interests.map(t => `<span class="tag">${t}</span>`).join('')}</div>
      ${k.note ? `<div class="panel panel-warm" style="padding:16px 18px; margin-bottom:20px">
        <div class="note"><i class="fa-solid fa-quote-left"></i><div style="font-style:italic">${k.note}
        <div class="tiny" style="font-style:normal; margin-top:6px; color:var(--brand-deep)">From their caregiver</div></div></div>
      </div>` : ''}

      <div class="bar ${pct>= 100 ? 'done' : ''}" style="margin-bottom:8px"><i style="width:${pct}%"></i></div>
      <div class="fund-line" style="margin-bottom:20px"><span><b>${money(funded)}</b> of ${money(total)} funded</span><span>${pct}%</span></div>

      ${k.items.map(it => {
        const has = inCart(it.id);
        return `
        <div class="mini" style="margin-bottom:9px; ${it.claimed ? 'opacity:.6' : ''}">
          ${art(it.catId, it.cat, it.icon, 'icon')}
          <div style="flex:1">
            <div class="t-base w-600 ink">${it.name}</div>
            <div class="tiny muted">${it.claimed ? 'Funded by ' + it.claimedBy
              : it.spec ? '<i class="fa-solid fa-tag t-2xs"></i> ' + it.spec : catById[it.cat].label}</div>
            ${it.claimed ? '' : linkChip(it)}
          </div>
          <span class="price t-base">${money(it.price)}</span>
          ${it.claimed ? '<i class="fa-solid fa-circle-check" style="color:var(--green); margin-left:10px"></i>'
            : `<button class="add-btn ${has ? 'in' : ''}" data-add="${it.id}" style="margin-left:10px">
                 <i class="fa-solid ${has ? 'fa-check' : 'fa-plus'}"></i></button>`}
        </div>`;
      }).join('')}

      ${left.length ? `<button class="btn btn-primary btn-block" style="margin-top:18px" data-all="${k.id}">
        Fund the rest of ${k.alias}'s list · ${money(left.reduce((s, i) => s + i.price, 0))}</button>` : ''}
      <div class="disclosure" style="margin-top:16px">
        ${k.alias} is an alias, and their caregiver wrote this list. Their household is verified by
        Atlanta Angels, and what you fund goes toward this list.
      </div>
    </div>`;
  if (!$('#modal').classList.contains('on')) remember();
  $('#modal').classList.add('on');
  const xk = $('#modalBox .x'); if (xk) xk.focus();
}

/* ── Checkout ── */
function showCheckout(){
  $('#shopView').hidden = true; $('#doneView').hidden = true; $('#checkoutView').hidden = false;
  window.scrollTo(0, 0);
  const byHouse = {};
  cart.forEach(l => {
    const key = l.type === 'flex' ? 'flex' : house(kidById[l.kidId]).name;
    (byHouse[key] = byHouse[key] || []).push(l);
  });
  const total = cartTotal();
  $('#checkoutBody').innerHTML = `
    <div class="row2" style="grid-template-columns:1.4fr 1fr; align-items:start; gap:26px">
      <div>
        ${Object.entries(byHouse).map(([hh, lines]) => `
          <div class="panel" style="margin-bottom:18px">
            <div style="display:flex; justify-content:space-between; align-items:baseline; margin-bottom:14px">
              <h3 class="t-md">${hh === 'flex' ? 'Given where it is needed' : house(kidById[lines[0].kidId]).name}</h3>
              <span class="tiny muted">${hh === 'flex' ? 'Applied at close'
                : house(kidById[lines[0].kidId]).area + ' · paid to ' + house(kidById[lines[0].kidId]).caregiver}</span>
            </div>
            ${lines.map(l => l.type === 'flex' ? `
              <div class="mini" style="margin-bottom:9px"><span class="icon t5">💛</span>
                <div style="flex:1"><div class="t-base w-600 ink">Where it is needed most</div>
                <div class="tiny muted">Split across the closest-to-complete lists</div></div>
                <span class="price t-base">${money(l.amount)}</span></div>` : `
              <div class="mini" style="margin-bottom:9px">${art(l.catId, l.cat, l.icon, 'icon')}
                <div style="flex:1"><div class="t-base w-600 ink">${l.name}</div>
                <div class="tiny muted">${l.spec ? l.spec + ' · ' : ''}For ${kidById[l.kidId].alias}, ${kidById[l.kidId].age}</div></div>
                <span class="price t-base">${money(l.price)}</span></div>`).join('')}
          </div>`).join('')}

        <div class="panel panel-warm">
          <h3 class="t-md" style="margin-bottom:12px">What your ${money(total)} actually does</h3>
          <div class="flow" style="margin-top:22px">
            <div class="flow-step"><b>Recorded, not pooled</b><span>Every line names the child and the household it was chosen for.</span></div>
            <div class="flow-step"><b>Directed, not shipped</b><span>Atlanta Angels sends the funds to that verified household. No warehouse in between.</span></div>
            <div class="flow-step"><b>Spent by the family</b><span>Their caregiver shops for what fits by the time the holidays arrive.</span></div>
          </div>
        </div>
      </div>

      <div>
        <div class="panel" style="position:sticky; top:80px">
          <div class="field">
            <label class="f" for="dName">Your name, as the household should see it</label>
            <input class="i" id="dName" placeholder="The Hollis family" value="The Hollis family">
            <p class="hint">Or leave it blank to give anonymously.</p>
          </div>
          <div class="field">
            <label class="f" for="dNote">A short note for the family</label>
            <textarea class="i" id="dNote" rows="3" placeholder="Thinking of you all this Christmas."></textarea>
            <p class="hint">Read by the caregiver. Never shows a child's information back to you.</p>
          </div>
          <label class="t-sm" style="display:flex; gap:10px; align-items:flex-start; margin-bottom:18px; cursor:pointer">
            <input type="checkbox" id="coverFee" checked style="margin-top:4px">
            <span>Add ${money(total * 0.03)} to cover card processing, so the full ${money(total)} reaches the household.</span>
          </label>
          <div class="total-row"><span class="muted">Total charged</span><b id="ckTotal">${money(total * 1.03)}</b></div>
          <button class="btn btn-primary btn-block btn-xl" id="place">Give ${money(total)}</button>
          <p class="tiny muted" style="text-align:center; margin:12px 0 0">
            Prototype. No card is collected and nothing is charged.</p>
        </div>
        <div class="disclosure" style="margin-top:16px">
          Atlanta Angels is a 501(c)(3). Your gift is a tax deductible donation designated to
          a household's wish list, not a purchase of goods, and no goods or services are
          provided to you in return.
        </div>
      </div>
    </div>`;
  const upd = () => {
    const charged = total * ($('#coverFee').checked ? 1.03 : 1);
    $('#ckTotal').textContent = money(charged);
    $('#place').textContent = 'Give ' + money(charged);
  };
  $('#coverFee').onchange = upd;
  upd();
  $('#place').onclick = placeGift;
}

function placeGift(){
  const name = ($('#dName').value || '').trim() || 'Anonymous';
  const note = ($('#dNote').value || '').trim();
  const total = cartTotal();
  const given = [...cart];
  cart.filter(l => l.type === 'item').forEach(l => {
    const it = kidById[l.kidId].items.find(i => i.id === l.itemId);
    if (it){ it.claimed = true; it.claimedBy = name; }
  });
  cart = [];
  render();
  $('#shopView').hidden = true; $('#checkoutView').hidden = true; $('#doneView').hidden = false;
  window.scrollTo(0, 0);
  const kidsTouched = [...new Set(given.filter(l => l.type === 'item').map(l => l.kidId))].map(id => kidById[id]);
  const finished = kidsTouched.filter(k => !kidLeft(k).length);
  $('#doneBody').innerHTML = `
    <div style="text-align:center; margin-bottom:32px">
      <div class="emoji-xl">🎁</div>
      <h1 style="font-size:clamp(1.8rem,4vw,2.4rem); margin:14px 0 10px" class="text-balance">
        ${money(total)} is on its way toward ${kidsTouched.length ? (kidsTouched.length === 1 ? kidsTouched[0].alias + "'s list" : kidsTouched.length + " children's lists") : 'the lists that need it'}.
      </h1>
      <p class="muted" style="max-width:520px; margin:0 auto">
        A receipt is in your inbox with every line itemized. ${finished.length ? `You finished ${finished.map(k => k.alias).join(' and ')}'s list.` : ''}
      </p>
    </div>
    <div class="panel">
      <h3 class="t-md" style="margin-bottom:14px">You gave</h3>
      ${given.map(l => l.type === 'flex' ? `
        <div class="mini" style="margin-bottom:9px"><span class="icon t5">💛</span>
          <div style="flex:1"><div class="t-base w-600 ink">Where it is needed most</div></div>
          <span class="price t-base">${money(l.amount)}</span></div>` : `
        <div class="mini" style="margin-bottom:9px">${art(l.catId, l.cat, l.icon, 'icon')}
          <div style="flex:1"><div class="t-base w-600 ink">${l.name}</div>
          <div class="tiny muted">${l.spec ? l.spec + ' · ' : ''}For ${kidById[l.kidId].alias}, ${kidById[l.kidId].age}</div></div>
          <span class="price t-base">${money(l.price)}</span></div>`).join('')}
      ${note ? `<div class="panel panel-warm" style="padding:14px 16px; margin-top:14px; font-style:italic">"${note}"
        <div class="tiny" style="font-style:normal; color:var(--brand-deep); margin-top:5px">Sent to the household from ${name}</div></div>` : ''}
    </div>
    <div class="panel panel-green" style="margin-top:20px">
      <div class="note"><i class="fa-solid fa-calendar-check c-green"></i>
        <div><b class="ink">Next: December 8.</b> Lists close, we total each household, and payouts
        go out the same week. You get one email in January with a note back from the household.</div></div>
    </div>
    <div style="text-align:center; margin-top:30px">
      <button class="btn btn-ghost" id="again">Back to the lists</button>
    </div>`;
  $('#again').onclick = () => {
    $('#doneView').hidden = true; $('#shopView').hidden = false; window.scrollTo(0, 0); render();
  };
}

/* ── Motion ──
   Takes coordinates, not an element: adding to the cart re-renders the grid,
   so the button that was clicked is usually detached by now and measuring it
   would fire every piece from the top-left corner. */
function confetti(x, y){
  const colors = [themeVar('--brand'), themeVar('--brand-light'), themeVar('--accent'),
                  themeVar('--green'), themeVar('--brand-wash')].filter(Boolean);
  for (let i = 0; i < 14; i++){
    const c = document.createElement('i');
    c.className = 'confetti';
    c.style.left = x + 'px';
    c.style.top  = y + 'px';
    c.style.background = colors[i % colors.length];
    c.style.setProperty('--dx', (Math.cos(i / 14 * 6.28) * (34 + i * 4)).toFixed(1) + 'px');
    c.style.setProperty('--dy', (Math.sin(i / 14 * 6.28) * (34 + i * 4) - 26).toFixed(1) + 'px');
    c.style.setProperty('--rot', (i * 47) + 'deg');
    c.style.animation = `fly ${520 + i * 12}ms cubic-bezier(.2,.7,.3,1) forwards`;
    document.body.appendChild(c);
    setTimeout(() => c.remove(), 900);
  }
}

/* Visible by default. An element is only hidden once this has taken
   responsibility for it, and the failsafe un-hides everything if the observer
   never fires, because no animation is worth a blank page. */
const showSection = el => { el.classList.remove('pending'); io.unobserve(el); };
const io = new IntersectionObserver(
  es => es.forEach(en => { if (en.isIntersecting) showSection(en.target); }),
  { rootMargin: '0px 0px -6% 0px' });

let failsafe;
function observeReveals(){
  $$('.shelf, #tabBody .sec').filter(el => !el.dataset.io).forEach(el => {
    el.dataset.io = 1;
    el.classList.add('reveal', 'pending');
    io.observe(el);
  });
  clearTimeout(failsafe);
  failsafe = setTimeout(() => $$('.reveal.pending').forEach(showSection), 1400);
}

/* ── Events ── */
document.addEventListener('click', e => {
  const t = e.target;

  if (!t.closest('.fdrop')) $$('.fdrop.open').forEach(d => d.classList.remove('open'));
  const pill = t.closest('.fpill');
  if (pill){
    const d = pill.parentElement, was = d.classList.contains('open');
    $$('.fdrop').forEach(x => x.classList.remove('open'));
    d.classList.toggle('open', !was);
    pill.setAttribute('aria-expanded', String(!was));
    return;
  }

  const add = t.closest('[data-add]');
  if (add){ e.stopPropagation(); addItem(add.dataset.add); return; }

  const q = t.closest('[data-qty]');
  if (q){
    const id = q.dataset.qty;
    const max = groups().find(g => g.catId === id).rows.filter(r => !r.claimed && !inCart(r.id) && !r.spec).length;
    qty[id] = Math.max(0, Math.min(max, (qty[id] === undefined ? 1 : qty[id]) + (+q.dataset.d)));
    openProduct(id);
    return;
  }

  const aq = t.closest('[data-addqty]');
  if (aq){
    const id = aq.dataset.addqty;
    const generic = groups().find(g => g.catId === id).rows.filter(r => !r.claimed && !inCart(r.id) && !r.spec);
    generic.slice(0, qty[id] === undefined ? 1 : qty[id]).forEach(r => addItem(r.id));
    qty[id] = 1;
    openProduct(id);
    return;
  }

  const undo = t.closest('[data-undo]');
  if (undo){
    const ids = new Set(groups().find(g => g.catId === undo.dataset.undo).rows.map(r => r.id));
    cart = cart.filter(l => !(l.type === 'item' && ids.has(l.itemId)));
    render(); openProduct(undo.dataset.undo);
    return;
  }

  const cq = t.closest('[data-catq]');
  if (cq){
    const c = catById[params.get('c')];
    const open = rows().filter(r => r.cat === c.id && !r.claimed && !inCart(r.id));
    catQty = Math.max(1, Math.min(open.length, catQty + (+cq.dataset.catq)));
    render();
    return;
  }
  const ca = t.closest('[data-catadd]');
  if (ca){
    const c = catById[params.get('c')];
    const open = rows().filter(r => r.cat === c.id && !r.claimed && !inCart(r.id));
    (ca.dataset.catadd === 'all' ? open : open.slice(0, catQty)).forEach(r => addItem(r.id));
    openDrawer();
    return;
  }

  const prod = t.closest('[data-product]');
  if (prod){ openProduct(prod.dataset.product); return; }

  const all = t.closest('[data-all]');
  if (all){
    kidLeft(kidById[all.dataset.all]).forEach(i => addItem(i.id));
    closeModal(); openDrawer(); return;
  }
  const tb = t.closest('[data-tab]');
  if (tb){ tab = tb.dataset.tab; filters.cat = 'all'; render(); window.scrollTo({ top:$('.tabs-wrap').offsetTop - 60, behavior:'smooth' }); return; }

  const f = t.closest('[data-f]');
  if (f && f.dataset.href){ location.href = f.dataset.href; return; }
  if (f){ filters[f.dataset.f] = f.dataset.v; if (f.dataset.f === 'cat' && tab !== 'browse') tab = 'browse'; render(); return; }

  if (t.closest('[data-clear]')){ Object.keys(filters).forEach(k => filters[k] = 'all'); render(); return; }

  const flex = t.closest('[data-flex]');
  if (flex){ cart.push({ type:'flex', amount:+flex.dataset.flex }); render(); openDrawer(); return; }

  const rm = t.closest('[data-rm]');
  if (rm){ cart.splice(+rm.dataset.rm, 1); render(); return; }

  if (t.closest('#flexAdd')){
    const v = +$('#flexAmt').value;
    if (v >= 5){ cart.push({ type:'flex', amount:v }); $('#flexAmt').value = ''; render(); openDrawer(); }
    return;
  }

  const kc = t.closest('[data-kid]');
  if (kc){ openKid(kc.dataset.kid); return; }

  if (t.closest('[data-close]') || t.id === 'modalScrim') closeModal();
});

let lastCount = cart.length;
/* Bubble phase and no timer: the delegated cart handler below is registered
   first, so the cart is already updated by the time this runs, and anything
   deferred here would die with a throttled frame loop. */
document.addEventListener('click', e => {
  const btn = e.target.closest('.add-btn, [data-addqty], [data-catadd]');
  if (!btn) return;
  if (cart.length <= lastCount){ lastCount = cart.length; return; }
  lastCount = cart.length;
  const c = $('#cartBtn');
  if (e.clientX || e.clientY) confetti(e.clientX, e.clientY);
  else { const r = c.getBoundingClientRect(); confetti(r.left + r.width / 2, r.top + r.height / 2); }
  c.classList.remove('bump'); void c.offsetWidth; c.classList.add('bump');
});

$('#cartBtn').onclick = openDrawer;
$('#closeDrawer').onclick = closeDrawer;
$('#scrim').onclick = closeDrawer;
if ($('#backToShop')){
  $('#backToShop').onclick = () => {
    $('#checkoutView').hidden = true; $('#shopView').hidden = false; window.scrollTo(0, 0);
  };
}
document.addEventListener('keydown', e => {
  if (e.key === 'Escape'){ closeDrawer(); closeModal(); $$('.fdrop.open').forEach(d => d.classList.remove('open')); }
  if ((e.key === 'Enter' || e.key === ' ') && e.target.matches('[role="button"]')){
    e.preventDefault();
    e.target.click();
  }
});
if ($('#whyGrid')){
  $('#whyGrid').innerHTML = REASONS.map(r => `
    <div class="why-card"><i class="fa-solid ${r.icon}"></i><h4>${r.title}</h4><p>${r.body}</p></div>`).join('');
}

if ($('#faqList')){
  $('#faqList').innerHTML = FAQS.map(f => `
    <details class="faq-item"><summary>${f.q}</summary><p>${f.a}</p></details>`).join('');
}

render();
if (PAGE === 'home' && params.get('checkout') && cart.length) showCheckout();
