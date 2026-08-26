/* ──────────────────────────────────────────────
   Atlanta Angels · Wish List — admin

   One table engine, six record indexes. Search, tab, filter, sort,
   select, paginate, and open a detail drawer are written once here and
   configured per record type in VIEWS, because six near-identical index
   pages is how an admin drifts out of sync with itself.
   ────────────────────────────────────────────── */

const $  = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];

const esc = s => String(s ?? '').replace(/[&<>"']/g, c =>
  ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' }[c]));

const AV = ['#a29060','#7d5ba6','#2f7d5d','#5b6bbf','#c2700a','#b0455e'];
const avColor = id => AV[[...String(id)].reduce((a, c) => a + c.charCodeAt(0), 0) % AV.length];
const initials = n => String(n).trim().split(/\s+/).slice(0, 2).map(w => w[0]).join('').toUpperCase();

const avatar = (name, id) =>
  `<span class="avatar-sm" style="background:${avColor(id || name)}">${esc(initials(name))}</span>`;

const artCell = l => l.photo
  ? `<img class="thumb" src="${esc(l.photo)}" alt="" loading="lazy">`
  : `<span class="thumb-emoji">${esc(l.icon || '🎁')}</span>`;

const badge = (tone, label) =>
  `<span class="status-badge ${tone}"><span class="status-dot"></span>${esc(label)}</span>`;

const bar = pct => {
  const tone = pct >= 100 ? '' : pct >= 50 ? 'part' : 'low';
  return `<span class="mini-bar"><i class="${tone}" style="width:${Math.min(100, pct)}%"></i></span>`;
};

const progress = pct => `<span class="progress-cell">${bar(pct)}<span class="pct">${pct}%</span></span>`;

/* ── Shared status vocabularies ── */
const LINE_TONE   = { open:['amber','Open'], funded:['green','Funded'], flagged:['violet','Needs review'], withdrawn:['grey','Withdrawn'] };
const LIST_TONE   = { live:['green','Live'], review:['amber','In review'], complete:['blue','Fully funded'], hold:['red','On hold'] };
const VERIFY_TONE = { verified:['green','Verified'], pending:['amber','Pending'], hold:['red','On hold'] };
const PAYOUT_TONE = { scheduled:['blue','Scheduled Dec 9'], nomethod:['amber','No method'], blocked:['grey','Blocked'], hold:['red','On hold'] };
const CHARGE_TONE = { succeeded:['green','Succeeded'], pending:['amber','Pending'], refunded:['grey','Refunded'], disputed:['red','Disputed'] };
const SUB_TONE    = { review:['amber','Needs review'], approved:['green','Approved'], flagged:['red','Flagged'] };

const tone = (map, k) => badge(...(map[k] || ['grey', k]));

const CAT_OPTIONS = [{ v:'', label:'All categories' }, ...CATEGORIES.map(c => ({ v:c.id, label:c.label }))];
const HH_OPTIONS  = [{ v:'', label:'All households' }, ...HOUSES.map(h => ({ v:h.id, label:h.name }))];

/* ══════════════════════════════════════════════
   View definitions
   ══════════════════════════════════════════════ */
const VIEWS = {

  /* ── Overview ── */
  overview: {
    title: 'Overview',
    lede: `${SEASON.name}. ${TOTALS.daysLeft} days until wishlists close on ${fmtDate(new Date(SEASON.closes + 'T12:00:00'))}, ${TOTALS.listsLive} wishlists live across ${TOTALS.households} households.`,
    crumbs: ['Program', 'Overview'],
    custom: renderOverview,
  },

  /* ── Line items ── */
  lines: {
    title: 'Line items',
    lede: 'Every gift a caregiver put on a child\'s list. One row is one thing one child asked for, which is the grain the whole program settles on.',
    crumbs: ['Families', 'Line items'],
    icon: 'gift',
    rows: () => lines,
    actions: [
      { label:'Export CSV', icon:'download' },
      { label:'Add a line', icon:'plus-lg', primary:true },
    ],
    stats: () => [
      { label:'Lines on lists', value: lines.length, icon:'list-ul', color:'blue', note:`across ${TOTALS.children} children` },
      { label:'Funded',         value: TOTALS.fundedLines, icon:'check2-circle', color:'green', note:`${Math.round(TOTALS.fundedLines / lines.length * 100)}% of all lines` },
      { label:'Still open',     value: TOTALS.openLines, icon:'hourglass-split', color:'amber', note: money(lines.filter(l => l.status === 'open').reduce((s, l) => s + l.price, 0)) + ' outstanding' },
      { label:'Designated',     value: money(TOTALS.designated), icon:'currency-dollar', color:'gold', note:'recorded against a named child' },
    ],
    searchPlaceholder: 'Search gifts, details, children, households...',
    search: r => [r.gift, r.spec, r.alias, r.household, r.caregiver, r.donorName, r.funderDisplay, r.id].join(' '),
    tabs: [
      { id:'all',      label:'All',            test: () => true },
      { id:'open',     label:'Open',           tone:'warning', test: r => r.status === 'open' },
      { id:'funded',   label:'Funded',         tone:'success', test: r => r.status === 'funded' },
      { id:'specific', label:'Brand or size',  test: r => !!r.spec },
      { id:'pooled',   label:'In the pool',    test: r => r.pooled && r.status === 'open' },
      { id:'review',   label:'Needs review',   tone:'danger',  test: r => r.status === 'flagged' || r.price > r.listPrice },
    ],
    filters: [
      { key:'cat',    label:'Category',  options: CAT_OPTIONS, test:(r, v) => r.cat === v },
      { key:'hh',     label:'Household', options: HH_OPTIONS,  test:(r, v) => r.hhId === v },
      { key:'age',    label:'Age band',  options:[{v:'',label:'Any age'},{v:'0-5',label:'0 to 5'},{v:'6-11',label:'6 to 11'},{v:'12-18',label:'12 to 18'}],
        test:(r, v) => { const [lo, hi] = v.split('-').map(Number); return r.age >= lo && r.age <= hi; } },
      { key:'price',  label:'Price',     options:[{v:'',label:'Any amount'},{v:'0-40',label:'Under $40'},{v:'40-80',label:'$40 to $80'},{v:'80-999',label:'Over $80'}],
        test:(r, v) => { const [lo, hi] = v.split('-').map(Number); return r.price >= lo && r.price < hi; } },
    ],
    columns: [
      { key:'gift', label:'Gift', val: r => r.gift, cell: r => `
        <div class="cell-media">${artCell(r)}
          <div><span class="item-name">${esc(r.gift)}</span>
          <span class="cell-sub">${r.spec ? esc(r.spec) : r.status === 'open' ? '<i>In the pool</i>' : '<i>No detail named</i>'}${r.link ? ' · linked' : ''}</span></div>
        </div>` },
      { key:'child', label:'Child', val: r => r.alias, cell: r => `
        <div class="cell-media">${avatar(r.alias, r.kidId)}
          <div><span class="item-name">${esc(r.alias)}, ${r.age}</span>
          <span class="cell-sub">${esc(r.household)}</span></div>
        </div>` },
      { key:'cat', label:'Category', val: r => r.catLabel, cell: r => `<span class="tag-soft">${esc(r.catLabel)}</span>` },
      { key:'price', label:'Price', align:'end', val: r => r.price, cell: r => `
        <span class="num">${money(r.price)}</span>${r.price > r.listPrice ? `<span class="cell-sub">over the ${money(r.listPrice)} line</span>` : ''}` },
      { key:'status', label:'Status', val: r => r.status, cell: r => tone(LINE_TONE, r.status) },
      { key:'funder', label:'Funded by', val: r => r.funderDisplay || '', cell: r => r.status === 'funded'
        ? `<span>${esc(r.funderDisplay)}</span>${r.funderDisplay === 'Anonymous' ? `<span class="cell-sub">${esc(r.donorName)}</span>` : ''}`
        : '<span class="text-muted">—</span>' },
      { key:'added', label:'Added', val: r => +r.addedAt, cell: r => `<span class="num">${fmtShort(r.addedAt)}</span>` },
    ],
    detail: lineDetail,
  },

  /* ── Wishlists ── */
  lists: {
    title: 'Wishlists',
    lede: 'One row per child. Asked, raised, and what is still open, which is the number that decides where general giving goes.',
    crumbs: ['Families', 'Wishlists'],
    icon: 'list-check',
    rows: () => wishlists,
    actions: [
      { label:'Export CSV', icon:'download' },
      { label:'New wishlist', icon:'plus-lg', primary:true },
    ],
    stats: () => [
      { label:'Wishlists',      value: wishlists.length, icon:'list-check', color:'blue', note:`${TOTALS.listsLive} live to donors` },
      { label:'Fully funded',   value: TOTALS.listsComplete, icon:'patch-check', color:'green', note:`${Math.round(TOTALS.listsComplete / wishlists.length * 100)}% of all wishlists` },
      { label:'Still short',    value: wishlists.filter(w => w.pct < 100 && w.status === 'live').length, icon:'exclamation-circle', color:'amber', note: money(wishlists.reduce((s, w) => s + w.remaining, 0)) + ' to close them all' },
      { label:'Over the cap',   value: wishlists.filter(w => w.overCap).length, icon:'arrow-up-right', color:'red', note:'above the $300 we ask donors to expect' },
    ],
    searchPlaceholder: 'Search children, households, interests...',
    search: r => [r.alias, r.household, r.caregiver, r.county, r.interests.join(' '), r.note].join(' '),
    tabs: [
      { id:'all',      label:'All',           test: () => true },
      { id:'live',     label:'Live',          tone:'success', test: r => r.status === 'live' },
      { id:'short',    label:'Still short',   tone:'warning', test: r => r.status === 'live' && r.pct < 100 },
      { id:'complete', label:'Fully funded',  test: r => r.status === 'complete' },
      { id:'review',   label:'In review',     tone:'warning', test: r => r.status === 'review' },
      { id:'hold',     label:'On hold',       tone:'danger',  test: r => r.status === 'hold' },
    ],
    filters: [
      { key:'hh',  label:'Household', options: HH_OPTIONS, test:(r, v) => r.hhId === v },
      { key:'age', label:'Age band',  options:[{v:'',label:'Any age'},{v:'0-5',label:'0 to 5'},{v:'6-11',label:'6 to 11'},{v:'12-18',label:'12 to 18'}],
        test:(r, v) => { const [lo, hi] = v.split('-').map(Number); return r.age >= lo && r.age <= hi; } },
      { key:'pct', label:'Progress',  options:[{v:'',label:'Any'},{v:'0-25',label:'Under 25%'},{v:'25-75',label:'25% to 75%'},{v:'75-100',label:'75% to 99%'},{v:'100-999',label:'Complete'}],
        test:(r, v) => { const [lo, hi] = v.split('-').map(Number); return r.pct >= lo && r.pct < hi; } },
    ],
    columns: [
      { key:'child', label:'Child', val: r => r.alias, cell: r => `
        <div class="cell-media">${avatar(r.alias, r.id)}
          <div><span class="item-name">${esc(r.alias)}, ${r.age}</span>
          <span class="cell-sub">${esc(r.interests.slice(0, 3).join(' · ') || 'no interests yet')}</span></div>
        </div>` },
      { key:'hh', label:'Household', val: r => r.household, cell: r => `
        <span>${esc(r.household)}</span><span class="cell-sub">${esc(r.county)} · ${esc(r.caregiver)}</span>` },
      { key:'gifts', label:'Gifts', align:'end', val: r => r.gifts, cell: r => `
        <span class="num">${r.fundedCount} / ${r.gifts}</span>` },
      { key:'asked', label:'Asked', align:'end', val: r => r.asked, cell: r => `
        <span class="num">${money(r.asked)}</span>${r.overCap ? '<span class="cell-sub">over cap</span>' : ''}` },
      { key:'raised', label:'Raised', align:'end', val: r => r.raised, cell: r => `<span class="num">${money(r.raised)}</span>` },
      { key:'pct', label:'Funded', val: r => r.pct, cell: r => progress(r.pct) },
      { key:'status', label:'Status', val: r => r.status, cell: r => tone(LIST_TONE, r.status) },
      { key:'act', label:'Last gift', val: r => +r.lastActivity, cell: r => `<span class="num">${fmtAgo(r.lastActivity)}</span>` },
    ],
    detail: listDetail,
  },

  /* ── Households ── */
  households: {
    title: 'Households',
    lede: 'Who we verify, who we pay, and how. None of this is ever shown to a donor, which is exactly why it lives here and not in the seed data.',
    crumbs: ['Families', 'Households'],
    icon: 'house-heart',
    rows: () => HOUSES,
    actions: [
      { label:'Export CSV',  icon:'download' },
      { label:'Add household', icon:'plus-lg', primary:true },
    ],
    stats: () => [
      { label:'Households',   value: HOUSES.length, icon:'house-heart', color:'blue', note:`${TOTALS.children} children` },
      { label:'Verified',     value: HOUSES.filter(h => h.verify === 'verified').length, icon:'shield-check', color:'green', note:'cleared with the placing agency' },
      { label:'Payout ready', value: HOUSES.filter(h => h.payoutStatus === 'scheduled').length, icon:'bank', color:'gold', note:`paid ${fmtDate(new Date(SEASON.payout + 'T12:00:00'))}` },
      { label:'Blocked',      value: HOUSES.filter(h => h.payoutStatus !== 'scheduled').length, icon:'exclamation-triangle', color:'red', note:'cannot be paid as things stand' },
    ],
    searchPlaceholder: 'Search households, caregivers, counties, agencies...',
    search: r => [r.name, r.caregiver, r.county, r.agency, r.email, r.phone].join(' '),
    tabs: [
      { id:'all',      label:'All',              test: () => true },
      { id:'verified', label:'Verified',         tone:'success', test: r => r.verify === 'verified' },
      { id:'pending',  label:'Pending',          tone:'warning', test: r => r.verify === 'pending' },
      { id:'hold',     label:'On hold',          tone:'danger',  test: r => r.verify === 'hold' },
      { id:'nopay',    label:'No payout method', tone:'warning', test: r => r.payout === 'none' },
      { id:'return',   label:'Returning',        test: r => r.returning },
    ],
    filters: [
      { key:'county', label:'County', options:[{v:'',label:'All counties'}, ...[...new Set(HOUSES.map(h => h.county))].map(c => ({ v:c, label:c }))], test:(r, v) => r.county === v },
      { key:'agency', label:'Agency', options:[{v:'',label:'All agencies'}, ...[...new Set(HOUSES.map(h => h.agency))].map(a => ({ v:a, label:a }))], test:(r, v) => r.agency === v },
      { key:'payout', label:'Payout method', options:[{v:'',label:'Any method'},{v:'stripe',label:'Direct deposit'},{v:'giftcard',label:'Mailed gift card'},{v:'none',label:'Not set up'}], test:(r, v) => r.payout === v },
    ],
    columns: [
      { key:'name', label:'Household', val: r => r.name, cell: r => `
        <div class="cell-media">${avatar(r.name.replace(/^The /, ''), r.id)}
          <div><span class="item-name">${esc(r.name)}</span>
          <span class="cell-sub">${esc(r.county)}</span></div>
        </div>` },
      { key:'caregiver', label:'Caregiver', val: r => r.caregiver, cell: r => `
        <span>${esc(r.caregiver)}</span><span class="cell-sub">${esc(r.email)}</span>` },
      { key:'agency', label:'Agency', val: r => r.agency, cell: r => `<span class="tag-soft">${esc(r.agency)}</span>` },
      { key:'kids', label:'Children', align:'end', val: r => r.children, cell: r => `<span class="num">${r.children}</span>` },
      { key:'raised', label:'Raised', align:'end', val: r => r.raised, cell: r => `
        <span class="num">${money(r.raised)}</span><span class="cell-sub">of ${money(r.asked)}</span>` },
      { key:'pct', label:'Funded', val: r => r.pct, cell: r => progress(r.pct) },
      { key:'verify', label:'Verification', val: r => r.verify, cell: r => tone(VERIFY_TONE, r.verify) },
      { key:'payout', label:'Payout', val: r => r.payoutStatus, cell: r => `
        ${tone(PAYOUT_TONE, r.payoutStatus)}<span class="cell-sub">${esc(r.dest)}</span>` },
    ],
    detail: householdDetail,
  },

  /* ── Donors ── */
  donors: {
    title: 'Donors',
    lede: 'An anonymous gift still has a donor record. The alias is a display rule for the household, not missing information, and staff need both to send a receipt.',
    crumbs: ['Funding', 'Donors'],
    icon: 'people',
    rows: () => donors,
    actions: [
      { label:'Export CSV', icon:'download' },
      { label:'Add donor',  icon:'plus-lg', primary:true },
    ],
    stats: () => [
      { label:'Donors',        value: donors.length, icon:'people', color:'blue', note:`${donors.filter(d => d.anonymous).length} giving anonymously` },
      { label:'Average gift',  value: money(TOTALS.raised / donors.length), icon:'graph-up', color:'green', note:'across every charge this season' },
      { label:'Groups & teams',value: donors.filter(d => d.type === 'group').length, icon:'building', color:'gold', note: money(donors.filter(d => d.type === 'group').reduce((s, d) => s + d.total, 0)) + ' from groups' },
      { label:'Fees covered',  value: money(TOTALS.fees), icon:'credit-card', color:'amber', note:`${Math.round(charges.filter(c => c.feeCovered).length / charges.length * 100)}% of donors added it` },
    ],
    searchPlaceholder: 'Search donors, emails, display names...',
    search: r => [r.name, r.display, r.email, r.type].join(' '),
    tabs: [
      { id:'all',    label:'All',          test: () => true },
      { id:'indiv',  label:'Individuals',  test: r => r.type === 'individual' },
      { id:'family', label:'Families',     test: r => r.type === 'family' },
      { id:'group',  label:'Groups & teams', test: r => r.type === 'group' },
      { id:'anon',   label:'Anonymous',    tone:'secondary', test: r => r.anonymous },
      { id:'repeat', label:'Gave more than once', test: r => r.chargeCount > 1 },
    ],
    filters: [
      { key:'type',  label:'Donor type', options:[{v:'',label:'Any type'},{v:'individual',label:'Individual'},{v:'family',label:'Family'},{v:'group',label:'Group or team'}], test:(r, v) => r.type === v },
      { key:'size',  label:'Total given', options:[{v:'',label:'Any amount'},{v:'0-100',label:'Under $100'},{v:'100-300',label:'$100 to $300'},{v:'300-99999',label:'Over $300'}],
        test:(r, v) => { const [lo, hi] = v.split('-').map(Number); return r.total >= lo && r.total < hi; } },
      { key:'shown', label:'Shown to family', options:[{v:'',label:'Either'},{v:'named',label:'By name'},{v:'anon',label:'As anonymous'}], test:(r, v) => v === 'anon' ? r.anonymous : !r.anonymous },
    ],
    columns: [
      { key:'name', label:'Donor', val: r => r.name, cell: r => `
        <div class="cell-media">${avatar(r.name, r.id)}
          <div><span class="item-name">${esc(r.name)}</span>
          <span class="cell-sub">${r.anonymous ? '<i class="bi bi-incognito"></i> shown as Anonymous'
            : r.display !== r.name ? 'shown as ' + esc(r.display) : ''}</span></div>
        </div>` },
      { key:'email', label:'Email', val: r => r.email, cell: r => `<span>${esc(r.email)}</span>` },
      { key:'type', label:'Type', val: r => r.type, cell: r => `<span class="tag-soft">${r.type === 'group' ? 'Group or team' : r.type === 'family' ? 'Family' : 'Individual'}</span>` },
      { key:'gifts', label:'Gifts', align:'end', val: r => r.giftCount, cell: r => `
        <span class="num">${r.giftCount}</span>${r.flex.length ? `<span class="cell-sub">+${r.flex.length} general</span>` : ''}` },
      { key:'kids', label:'Children', align:'end', val: r => r.kidCount, cell: r => `
        <span class="num">${r.kidCount}</span><span class="cell-sub">${r.hhCount} household${r.hhCount === 1 ? '' : 's'}</span>` },
      { key:'total', label:'This season', align:'end', val: r => r.total, cell: r => `
        <span class="num item-name">${money(r.total)}</span>${r.feesCovered ? `<span class="cell-sub">+${money2(r.feesCovered)} fees</span>` : ''}` },
      { key:'last', label:'Last gift', val: r => +(r.lastAt || 0), cell: r => r.lastAt ? `<span class="num">${fmtAgo(r.lastAt)}</span>` : '—' },
      { key:'receipt', label:'Receipt', val: r => r.receipts, cell: r => r.receipts === 'sent'
        ? badge('green', 'Sent') : badge('amber', 'Queued') },
    ],
    detail: donorDetail,
  },

  /* ── Donations / charges ── */
  charges: {
    title: 'Donations',
    lede: 'What actually hit a card. One charge can carry gifts for several children in several households plus a general gift, which is why it needs its own ledger.',
    crumbs: ['Funding', 'Donations'],
    icon: 'receipt',
    rows: () => charges,
    actions: [
      { label:'Export for accounting', icon:'download' },
      { label:'Record an offline gift', icon:'plus-lg', primary:true },
    ],
    stats: () => [
      { label:'Raised',        value: money(TOTALS.raised), icon:'currency-dollar', color:'gold', note:`${TOTALS.goalPct}% of the ${money(SEASON.goal)} goal` },
      { label:'Designated',    value: money(TOTALS.designated), icon:'bookmark-check', color:'green', note:`${TOTALS.fundedLines} gifts on named lists` },
      { label:'General giving',value: money(TOTALS.general), icon:'heart', color:'blue', note:`${flexGifts.length} gifts, applied at close` },
      { label:'Needs a look',  value: charges.filter(c => c.status === 'disputed' || c.status === 'pending').length, icon:'exclamation-triangle', color:'red', note:`${charges.filter(c => c.status === 'refunded').length} refunded this season` },
    ],
    searchPlaceholder: 'Search charge ID, donor, household, child...',
    search: r => [r.id, r.donorName, r.display, r.method, r.households.join(' '), r.kids.join(' ')].join(' '),
    tabs: [
      { id:'all',       label:'All',        test: () => true },
      { id:'succeeded', label:'Succeeded',  tone:'success', test: r => r.status === 'succeeded' },
      { id:'pending',   label:'Pending',    tone:'warning', test: r => r.status === 'pending' },
      { id:'disputed',  label:'Disputed',   tone:'danger',  test: r => r.status === 'disputed' },
      { id:'refunded',  label:'Refunded',   test: r => r.status === 'refunded' },
      { id:'general',   label:'General giving', test: r => r.flexIds.length > 0 },
    ],
    filters: [
      { key:'status', label:'Status', options:[{v:'',label:'Any status'},{v:'succeeded',label:'Succeeded'},{v:'pending',label:'Pending'},{v:'refunded',label:'Refunded'},{v:'disputed',label:'Disputed'}], test:(r, v) => r.status === v },
      { key:'method', label:'Method', options:[{v:'',label:'Any method'},{v:'Visa',label:'Visa'},{v:'Mastercard',label:'Mastercard'},{v:'Amex',label:'Amex'},{v:'Apple Pay',label:'Apple Pay'},{v:'ACH',label:'ACH'}], test:(r, v) => r.method.includes(v) },
      { key:'fee',    label:'Fee covered', options:[{v:'',label:'Either'},{v:'yes',label:'Donor covered it'},{v:'no',label:'Came out of the gift'}], test:(r, v) => v === 'yes' ? r.feeCovered : !r.feeCovered },
      { key:'size',   label:'Amount', options:[{v:'',label:'Any amount'},{v:'0-75',label:'Under $75'},{v:'75-200',label:'$75 to $200'},{v:'200-99999',label:'Over $200'}],
        test:(r, v) => { const [lo, hi] = v.split('-').map(Number); return r.gift >= lo && r.gift < hi; } },
    ],
    columns: [
      { key:'id', label:'Charge', val: r => r.id, cell: r => `
        <span class="item-name num">${esc(r.id)}</span><span class="cell-sub">${fmtDate(r.at)}</span>` },
      { key:'donor', label:'Donor', val: r => r.donorName, cell: r => `
        <div class="cell-media">${avatar(r.donorName, r.donorId)}
          <div><span class="item-name">${esc(r.donorName)}</span>
          <span class="cell-sub">${r.anonymous ? '<i class="bi bi-incognito"></i> shown as Anonymous'
            : r.display !== r.donorName ? 'shown as ' + esc(r.display) : ''}</span></div>
        </div>` },
      { key:'what', label:'Designated to', val: r => r.households.join(' '), cell: r => {
        const parts = [];
        if (r.lineIds.length) parts.push(`${r.lineIds.length} gift${r.lineIds.length === 1 ? '' : 's'} · ${esc(r.kids.join(', '))}`);
        if (r.flexIds.length) parts.push('Where it is needed most');
        return `<span>${parts[0] || '—'}</span><span class="cell-sub">${r.households.length ? esc(r.households.join(', ')) : 'applied at close'}</span>`;
      } },
      { key:'gift', label:'Gift', align:'end', val: r => r.gift, cell: r => `<span class="num">${money2(r.gift)}</span>` },
      { key:'fee', label:'Fee', align:'end', val: r => r.fee, cell: r => r.fee
        ? `<span class="num">${money2(r.fee)}</span><span class="cell-sub">donor covered</span>`
        : '<span class="text-muted num">—</span>' },
      { key:'charged', label:'Charged', align:'end', val: r => r.charged, cell: r => `<span class="num item-name">${money2(r.charged)}</span>` },
      { key:'method', label:'Method', val: r => r.method, cell: r => `<span class="cell-sub" style="margin:0">${esc(r.method)}</span>` },
      { key:'status', label:'Status', val: r => r.status, cell: r => tone(CHARGE_TONE, r.status) },
    ],
    detail: chargeDetail,
  },

  /* ── Submissions ── */
  submissions: {
    title: 'Submissions',
    lede: 'Everything a caregiver or a donor typed that is not a gift or a dollar. Some of it publishes to the donor site and some of it never leaves this room, so that is a column rather than a footnote.',
    crumbs: ['Inbox', 'Submissions'],
    icon: 'inbox',
    rows: () => submissions,
    actions: [
      { label:'Export CSV',   icon:'download' },
      { label:'Approve all clear', icon:'check2-all', primary:true },
    ],
    stats: () => [
      { label:'Needs review',   value: TOTALS.needsReview, icon:'inbox', color:'amber', note:'waiting on a staff decision' },
      { label:'Flagged',        value: TOTALS.flagged, icon:'flag', color:'red', note:'someone has to make a call' },
      { label:'Donor visible',  value: submissions.filter(s => s.donorVisible).length, icon:'eye', color:'blue', note:'publishes to the wish list site' },
      { label:'Staff only',     value: submissions.filter(s => !s.donorVisible).length, icon:'shield-lock', color:'green', note:'never leaves this admin' },
    ],
    searchPlaceholder: 'Search submissions, people, content...',
    search: r => [r.typeLabel, r.about, r.from, r.body, r.staffNote, r.channel].join(' '),
    tabs: [
      { id:'review',    label:'Needs review', tone:'warning', test: r => r.status === 'review' },
      { id:'flagged',   label:'Flagged',      tone:'danger',  test: r => r.status === 'flagged' },
      { id:'caregiver', label:'From caregivers', test: r => r.who === 'caregiver' },
      { id:'donor',     label:'From donors',  test: r => r.who === 'donor' },
      { id:'visible',   label:'Donor visible', test: r => r.donorVisible },
      { id:'all',       label:'All',          test: () => true },
    ],
    filters: [
      { key:'type', label:'Type', options:[{v:'',label:'All types'}, ...Object.entries(SUB_TYPES).map(([v, m]) => ({ v, label:m.label }))], test:(r, v) => r.type === v },
      { key:'who',  label:'Submitted by', options:[{v:'',label:'Anyone'},{v:'caregiver',label:'Caregiver'},{v:'donor',label:'Donor'},{v:'agency',label:'Agency'}], test:(r, v) => r.who === v },
      { key:'vis',  label:'Visibility', options:[{v:'',label:'Either'},{v:'yes',label:'Donor visible'},{v:'no',label:'Staff only'}], test:(r, v) => v === 'yes' ? r.donorVisible : !r.donorVisible },
      { key:'status', label:'Status', options:[{v:'',label:'Any status'},{v:'review',label:'Needs review'},{v:'approved',label:'Approved'},{v:'flagged',label:'Flagged'}], test:(r, v) => r.status === v },
    ],
    columns: [
      { key:'type', label:'Type', val: r => r.typeLabel, cell: r => `
        <div class="cell-media">
          <span class="stat-icon ${r.who === 'donor' ? 'blue' : r.who === 'agency' ? 'green' : 'gold'}" style="width:32px;height:32px;font-size:15px"><i class="bi bi-${r.icon}"></i></span>
          <div><span class="item-name">${r.status === 'flagged' ? '<span class="flag-dot"></span>' : ''}${esc(r.typeLabel)}</span>
          <span class="cell-sub">${esc(r.channel)}</span></div>
        </div>` },
      { key:'about', label:'About', val: r => r.about, cell: r => `<span class="item-name">${esc(r.about)}</span>` },
      { key:'from', label:'From', val: r => r.from, cell: r => `
        <span>${esc(r.from)}</span><span class="cell-sub">${r.who === 'donor' ? 'Donor' : r.who === 'agency' ? 'Agency' : 'Caregiver'}</span>` },
      { key:'body', label:'What they submitted', val: r => r.body, cell: r => `
        <span style="display:inline-block;max-width:420px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;vertical-align:middle">${esc(r.body)}</span>` },
      { key:'vis', label:'Visibility', val: r => r.donorVisible, cell: r => r.donorVisible
        ? badge('blue', 'Donor visible') : badge('grey', 'Staff only') },
      { key:'status', label:'Status', val: r => r.status, cell: r => tone(SUB_TONE, r.status) },
      { key:'at', label:'Submitted', val: r => +r.at, cell: r => `<span class="num">${fmtAgo(r.at)}</span>` },
    ],
    detail: submissionDetail,
  },
};

/* ══════════════════════════════════════════════
   Detail drawers
   ══════════════════════════════════════════════ */
const kv = pairs => `<dl class="kv">${pairs.filter(Boolean).map(([k, v]) => `<dt>${esc(k)}</dt><dd>${v}</dd>`).join('')}</dl>`;
const section = (title, body) => `<div class="drawer-section"><h4>${esc(title)}</h4>${body}</div>`;
const actions = btns => `<div class="drawer-actions">${btns.map(b =>
  `<button class="btn btn-sm ${b.tone || 'btn-outline-secondary'}"><i class="bi bi-${b.icon} me-1"></i>${esc(b.label)}</button>`).join('')}</div>`;

function lineDetail(r){
  const list = wishlistById[r.kidId];
  return {
    title: 'Line item ' + r.id,
    html: `
    <div class="drawer-hero">${artCell(r)}
      <div><h3>${esc(r.gift)}</h3><p>${r.spec ? esc(r.spec) : r.status === 'open' ? 'No brand or size named, so it sits in the pool' : 'No brand or size was named'}</p></div>
    </div>
    ${section('The gift', kv([
      ['Status', tone(LINE_TONE, r.status)],
      ['Price', `${money(r.price)}${r.price > r.listPrice ? ` <span class="text-danger">(catalog line is ${money(r.listPrice)})</span>` : ''}`],
      ['Category', esc(r.catLabel)],
      ['Added', fmtDate(r.addedAt)],
      r.link ? ['Caregiver link', `<a href="${esc(r.link)}" target="_blank" rel="noopener nofollow">${esc(new URL(r.link).hostname.replace(/^www\./, ''))}</a>`] : null,
    ]))}
    ${section('Who it is for', kv([
      ['Child', `${esc(r.alias)}, ${r.age}`],
      ['Household', esc(r.household)],
      ['Caregiver', esc(r.caregiver)],
      ['County', esc(r.county)],
      ['Their wishlist', `${money(list.raised)} of ${money(list.asked)} · ${list.pct}%`],
    ]))}
    ${r.status === 'funded' ? section('Funding', kv([
      ['Funded by', esc(r.donorName)],
      ['Shown as', esc(r.funderDisplay)],
      ['Funded on', fmtDate(r.fundedAt)],
      ['Charge', `<span class="num">${esc(r.chargeId || '—')}</span>`],
    ])) : section('Funding', `<div class="drawer-note">Still open. ${r.pooled
      ? 'No brand or size was named, so any donor funding this gift can cover it for whichever child is furthest behind.'
      : 'A specific brand or size was named, so this line has to be funded on its own.'}</div>`)}
    ${section('Actions', actions([
      { label:'Edit line', icon:'pencil' },
      { label:'Move to another child', icon:'arrow-left-right' },
      { label:'Withdraw', icon:'x-circle', tone:'btn-outline-danger' },
    ]))}`,
  };
}

function listDetail(r){
  const open = r.lines.filter(l => l.status !== 'funded');
  return {
    title: r.alias + '’s wishlist',
    html: `
    <div class="drawer-hero">${avatar(r.alias, r.id)}
      <div><h3>${esc(r.alias)}, ${r.age}</h3><p>${esc(r.household)} · ${esc(r.county)}</p></div>
    </div>
    ${section('The wishlist', kv([
      ['Status', tone(LIST_TONE, r.status)],
      ['Gifts', `${r.fundedCount} funded of ${r.gifts}`],
      ['Asked', `${money(r.asked)}${r.overCap ? ' <span class="text-danger">(over the $300 cap)</span>' : ''}`],
      ['Raised', money(r.raised)],
      ['Still open', money(r.remaining)],
      ['Submitted', fmtDate(r.submittedAt)],
      ['Last gift', fmtAgo(r.lastActivity)],
    ]))}
    ${section('What a donor sees', `
      <div class="drawer-quote">${esc(r.note || 'No note yet.')}</div>
      <div style="margin-top:10px">${r.interests.map(i => `<span class="tag-soft me-1 mb-1">${esc(i)}</span>`).join('')}</div>`)}
    ${section('Still open', open.length ? `
      <dl class="kv">${open.map(l => `<dt>${esc(l.gift)}</dt><dd>${money(l.price)}${l.spec ? ` <span class="text-muted">· ${esc(l.spec)}</span>` : ''}</dd>`).join('')}</dl>`
      : '<div class="drawer-note">Every line on this list is funded.</div>')}
    ${section('Privacy', `<div class="privacy-note"><i class="bi bi-shield-lock"></i>
      <div>Donors see the alias, the age, girl or boy, the county, the interests, and the one-line note. They never see a legal name, a photograph, a size, a school, or anything about the case.</div></div>`)}
    ${section('Actions', actions([
      { label:'Open the wishlist', icon:'box-arrow-up-right' },
      { label:'Message the caregiver', icon:'chat-left-text' },
      { label:'Direct general giving here', icon:'heart', tone:'btn-outline-primary' },
    ]))}`,
  };
}

function householdDetail(r){
  const kids = wishlists.filter(w => w.hhId === r.id);
  return {
    title: r.name,
    html: `
    <div class="drawer-hero">${avatar(r.name.replace(/^The /, ''), r.id)}
      <div><h3>${esc(r.name)}</h3><p>${esc(r.caregiver)} · ${esc(r.county)}</p></div>
    </div>
    ${r.holdReason ? `<div class="privacy-note" style="margin-bottom:18px;color:#991b1b;background:#fef2f2;border-color:#fecaca">
      <i class="bi bi-exclamation-octagon"></i><div>${esc(r.holdReason)}</div></div>` : ''}
    ${section('Contact', kv([
      ['Caregiver', esc(r.caregiver)],
      ['Email', `<a href="mailto:${esc(r.email)}">${esc(r.email)}</a>`],
      ['Phone', esc(r.phone)],
      r.prefLang ? ['Preferred language', esc(r.prefLang)] : null,
      ['Joined', fmtDate(r.joinedAt) + (r.returning ? ' · returning caregiver' : '')],
    ]))}
    ${section('Verification', kv([
      ['Status', tone(VERIFY_TONE, r.verify)],
      ['Agency', esc(r.agency)],
      ['Verified on', r.verifiedAt ? fmtDate(r.verifiedAt) : '<span class="text-muted">not yet</span>'],
    ]))}
    ${section('Payout', kv([
      ['Method', r.payout === 'stripe' ? 'Direct deposit via Stripe' : r.payout === 'giftcard' ? 'Mailed Visa gift card' : '<span class="text-danger">Not set up</span>'],
      ['Destination', esc(r.dest)],
      ['Status', tone(PAYOUT_TONE, r.payoutStatus)],
      ['Amount', money(r.raised)],
      ['Scheduled', fmtDate(new Date(SEASON.payout + 'T12:00:00'))],
    ]))}
    ${section('Children', `<dl class="kv">${kids.map(k =>
      `<dt>${esc(k.alias)}, ${k.age}</dt><dd>${money(k.raised)} of ${money(k.asked)} · ${k.pct}%</dd>`).join('')}</dl>`)}
    ${section('Actions', actions([
      { label:'Message the caregiver', icon:'chat-left-text' },
      { label:'Mark verified', icon:'shield-check', tone:'btn-outline-success' },
      { label:'Hold payout', icon:'pause-circle', tone:'btn-outline-danger' },
    ]))}`,
  };
}

function donorDetail(r){
  const mine = charges.filter(c => c.donorId === r.id);
  return {
    title: r.name,
    html: `
    <div class="drawer-hero">${avatar(r.name, r.id)}
      <div><h3>${esc(r.name)}</h3><p>${esc(r.email)}</p></div>
    </div>
    ${r.anonymous ? `<div class="privacy-note" style="margin-bottom:18px"><i class="bi bi-incognito"></i>
      <div>This donor gives anonymously. Households and the public wish list see <b>Anonymous</b>. Receipts and any correspondence still go to ${esc(r.name)}.</div></div>` : ''}
    ${section('This season', kv([
      ['Given', money(r.total)],
      ['Fees covered', r.feesCovered ? money2(r.feesCovered) : '<span class="text-muted">none</span>'],
      ['Gifts funded', String(r.giftCount)],
      ['General giving', r.flex.length ? `${r.flex.length} gift${r.flex.length === 1 ? '' : 's'} · ${money(r.flex.reduce((s, f) => s + f.amount, 0))}` : '<span class="text-muted">none</span>'],
      ['Children', `${r.kidCount} across ${r.hhCount} household${r.hhCount === 1 ? '' : 's'}`],
      ['First gift', r.firstAt ? fmtDate(r.firstAt) : '—'],
      ['Last gift', r.lastAt ? fmtDate(r.lastAt) : '—'],
      ['Lifetime', money(r.lifetime)],
    ]))}
    ${r.lines.length ? section('What they funded', `<dl class="kv">${r.lines.map(l =>
      `<dt>${esc(l.gift)}</dt><dd>${esc(l.alias)}, ${l.age} · ${money(l.price)}</dd>`).join('')}</dl>`) : ''}
    ${section('Charges', `<dl class="kv">${mine.map(c =>
      `<dt><span class="num">${esc(c.id)}</span></dt><dd>${money2(c.charged)} · ${fmtShort(c.at)} · ${esc(c.status)}</dd>`).join('')}</dl>`)}
    ${section('Actions', actions([
      { label:'Resend receipt', icon:'envelope' },
      { label:'January note list', icon:'send' },
      { label:'Merge duplicate', icon:'union' },
    ]))}`,
  };
}

function chargeDetail(r){
  const cLines = lines.filter(l => r.lineIds.includes(l.id));
  const cFlex  = flexGifts.filter(f => r.flexIds.includes(f.id));
  return {
    title: 'Charge ' + r.id,
    html: `
    <div class="drawer-hero">
      <span class="thumb-emoji"><i class="bi bi-receipt" style="font-size:22px;color:#6b7280"></i></span>
      <div><h3>${money2(r.charged)}</h3><p>${fmtDate(r.at)} · ${esc(r.method)}</p></div>
    </div>
    ${section('The charge', kv([
      ['Status', tone(CHARGE_TONE, r.status)],
      ['Gift amount', money2(r.gift)],
      ['Processing fee', r.fee ? `${money2(r.fee)} · donor covered` : 'Came out of the gift'],
      ['Total charged', money2(r.charged)],
      ['To the program', money2(r.net)],
      ['Method', esc(r.method)],
    ]))}
    ${section('Donor', kv([
      ['Name', esc(r.donorName)],
      ['Shown to the family', r.anonymous ? 'Anonymous' : esc(r.display)],
      ['Receipt', r.status === 'succeeded' ? 'Sent' : 'Held until the charge settles'],
    ]))}
    ${cLines.length ? section('Designated gifts', `<dl class="kv">${cLines.map(l =>
      `<dt>${esc(l.gift)}</dt><dd>${esc(l.alias)}, ${l.age} · ${esc(l.household)} · ${money(l.price)}</dd>`).join('')}</dl>`) : ''}
    ${cFlex.length ? section('General giving', `<dl class="kv">${cFlex.map(f =>
      `<dt>Where it is needed most</dt><dd>${money(f.amount)} · applied at close</dd>`).join('')}</dl>`) : ''}
    ${section('What this is', `<div class="drawer-note">A designated donation to Atlanta Angels, not a purchase. The donor picked the gift; the funds go to the verified household and Atlanta Angels holds final discretion, which is the condition of the gift being deductible.</div>`)}
    ${section('Actions', actions([
      { label:'Resend receipt', icon:'envelope' },
      { label:'Refund', icon:'arrow-counterclockwise', tone:'btn-outline-danger' },
      { label:'Open in Stripe', icon:'box-arrow-up-right' },
    ]))}`,
  };
}

function submissionDetail(r){
  return {
    title: r.typeLabel,
    html: `
    <div class="drawer-hero">
      <span class="stat-icon ${r.who === 'donor' ? 'blue' : r.who === 'agency' ? 'green' : 'gold'}" style="width:52px;height:52px;font-size:22px;border-radius:10px"><i class="bi bi-${r.icon}"></i></span>
      <div><h3>${esc(r.about)}</h3><p>${esc(r.from)} · ${fmtAgo(r.at)}</p></div>
    </div>
    ${section('What they submitted', `<div class="drawer-quote">${esc(r.body)}</div>`)}
    ${section('Details', kv([
      ['Type', esc(r.typeLabel)],
      ['Submitted by', r.who === 'donor' ? 'Donor' : r.who === 'agency' ? 'Placing agency' : 'Caregiver'],
      ['Channel', esc(r.channel)],
      ['Received', fmtDate(r.at)],
      ['Status', tone(SUB_TONE, r.status)],
      ['Visibility', r.donorVisible ? badge('blue', 'Publishes to the donor site') : badge('grey', 'Never leaves this admin')],
    ]))}
    ${r.staffNote ? section('Staff note', `<div class="privacy-note"><i class="bi bi-sticky"></i><div>${esc(r.staffNote)}</div></div>`) : ''}
    ${section('Actions', actions([
      { label:'Approve', icon:'check2', tone:'btn-outline-success' },
      { label:'Reply', icon:'reply' },
      { label:'Flag for a call', icon:'flag', tone:'btn-outline-danger' },
    ]))}`,
  };
}

/* ══════════════════════════════════════════════
   Overview
   ══════════════════════════════════════════════ */
function renderOverview(){
  /* Sort by how far behind, then by the size of the gap, so six lists all
     sitting at zero still come back in the order worth working. */
  const short = wishlists.filter(w => w.status === 'live' && w.pct < 100)
    .sort((a, b) => a.pct - b.pct || b.remaining - a.remaining).slice(0, 6);
  const catMix = CATEGORIES.map(c => {
    const inCat = lines.filter(l => l.cat === c.id);
    return { label: c.label, open: inCat.filter(l => l.status === 'open').length, total: inCat.length };
  }).filter(c => c.total).sort((a, b) => b.open - a.open).slice(0, 7);
  const maxOpen = Math.max(...catMix.map(c => c.open), 1);

  const attention = [
    ...(HOUSES.filter(h => h.payoutStatus !== 'scheduled').map(h => ({
      icon:'bank', color:'red', title: h.name + ' cannot be paid',
      sub: h.payoutStatus === 'nomethod' ? 'No payout method on file, and two lists are live'
        : h.payoutStatus === 'hold' ? 'On hold pending a placement change'
        : 'Agency verification has not cleared',
      go:'households' }))),
    ...(submissions.filter(s => s.status === 'flagged').slice(0, 3).map(s => ({
      icon:'flag', color:'red', title: s.typeLabel + ' flagged · ' + s.about, sub: s.staffNote || s.body, go:'submissions' }))),
    { icon:'inbox', color:'amber', title: TOTALS.needsReview + ' submissions need a decision',
      sub:'Child profiles, gift details, and donor notes waiting on staff', go:'submissions' },
    { icon:'exclamation-circle', color:'amber',
      title: wishlists.filter(w => w.pct === 0).length + ' wishlists have not had a single gift funded',
      sub:'General giving goes here first', go:'lists' },
    { icon:'credit-card', color:'blue',
      title: charges.filter(c => c.status === 'disputed').length + ' disputed and ' + charges.filter(c => c.status === 'pending').length + ' pending charges',
      sub:'Receipts are held until they settle', go:'charges' },
  ];

  return `
  <div class="stat-cards five">
    ${statCard('Raised', money(TOTALS.raised), 'currency-dollar', 'gold', `${TOTALS.goalPct}% of the ${money(SEASON.goal)} goal`, 'up')}
    ${statCard('Gifts funded', `${TOTALS.fundedLines} / ${lines.length}`, 'gift', 'green', `${TOTALS.openLines} lines still open`, 'up')}
    ${statCard('Wishlists finished', `${TOTALS.listsComplete} / ${wishlists.length}`, 'patch-check', 'blue', `${wishlists.filter(w => w.pct < 100 && w.status === 'live').length} still short`, 'flat')}
    ${statCard('Households', String(TOTALS.households), 'house-heart', 'amber', `${HOUSES.filter(h => h.verify !== 'verified').length} not yet verified`, 'flat')}
    ${statCard('Days left', String(TOTALS.daysLeft), 'calendar-event', 'red', `wishlists close ${fmtShort(new Date(SEASON.closes + 'T12:00:00'))}`, 'down')}
  </div>

  <div class="overview-grid">
    <div class="panel-card">
      <div class="panel-card-head"><h2>Needs your attention</h2><a data-go="submissions">Open submissions</a></div>
      <ul class="attention-list">
        ${attention.map(a => `
          <li data-go="${a.go}">
            <span class="att-icon stat-icon ${a.color}"><i class="bi bi-${a.icon}"></i></span>
            <span class="att-body"><b>${esc(a.title)}</b><span>${esc(a.sub)}</span></span>
            <i class="bi bi-chevron-right" style="color:#d1d5db"></i>
          </li>`).join('')}
      </ul>
    </div>

    <div style="display:flex;flex-direction:column;gap:18px">
      <div class="panel-card">
        <div class="panel-card-head"><h2>Furthest behind</h2><a data-go="lists">All wishlists</a></div>
        <ul class="attention-list">
          ${short.map(w => `
            <li data-go="lists">
              ${avatar(w.alias, w.id)}
              <span class="att-body"><b>${esc(w.alias)}, ${w.age}</b><span>${money(w.raised)} of ${money(w.asked)} · ${esc(w.household)}</span></span>
              <span class="pct" style="font-size:12.5px;font-weight:600;color:#6b7280">${w.pct}%</span>
            </li>`).join('')}
        </ul>
      </div>

      <div class="panel-card">
        <div class="panel-card-head"><h2>Where the open lines are</h2><a data-go="lines">All line items</a></div>
        ${catMix.map(c => `
          <div class="mix-row">
            <span class="mix-label">${esc(c.label)}</span>
            <span class="mix-bar"><i style="width:${c.open / maxOpen * 100}%"></i></span>
            <span class="mix-val">${c.open}</span>
          </div>`).join('')}
      </div>
    </div>
  </div>`;
}

const statCard = (label, value, icon, color, note, dir) => `
  <div class="stat-card">
    <div class="stat-card-header">
      <span class="stat-label">${esc(label)}</span>
      <div class="stat-icon ${color}"><i class="bi bi-${icon}"></i></div>
    </div>
    <div class="stat-value">${esc(value)}</div>
    <div class="stat-change ${dir || 'flat'}">
      ${dir === 'up' ? '<i class="bi bi-arrow-up"></i>' : dir === 'down' ? '<i class="bi bi-arrow-down"></i>' : ''}
      <span>${esc(note)}</span>
    </div>
  </div>`;

/* ══════════════════════════════════════════════
   Table engine
   ══════════════════════════════════════════════ */
const state = {
  view: 'overview',
  tab: {},
  q: '',
  filters: {},
  sort: {},
  page: 1,
  per: 25,
  selected: new Set(),
  filtersOpen: false,
};

function currentRows(){
  const v = VIEWS[state.view];
  const tabId = state.tab[state.view] || v.tabs[0].id;
  const tab = v.tabs.find(t => t.id === tabId) || v.tabs[0];
  const f = state.filters[state.view] || {};
  const q = state.q.trim().toLowerCase();

  let rows = v.rows().filter(tab.test);
  if (q) rows = rows.filter(r => v.search(r).toLowerCase().includes(q));
  v.filters?.forEach(def => { if (f[def.key]) rows = rows.filter(r => def.test(r, f[def.key])); });

  const s = state.sort[state.view];
  if (s){
    const col = v.columns.find(c => c.key === s.key);
    if (col?.val){
      rows = [...rows].sort((a, b) => {
        const av = col.val(a), bv = col.val(b);
        const cmp = typeof av === 'string' ? av.localeCompare(bv) : (av === bv ? 0 : av > bv ? 1 : -1);
        return s.dir === 'desc' ? -cmp : cmp;
      });
    }
  }
  return rows;
}

function render(){
  const v = VIEWS[state.view];

  $('#crumbs').innerHTML = ['Atlanta Angels', ...v.crumbs].map((c, i, a) =>
    i === a.length - 1
      ? `<li class="breadcrumb-item active" aria-current="page">${esc(c)}</li>`
      : `<li class="breadcrumb-item"><a href="#">${esc(c)}</a></li>`).join('');

  $$('.sidebar-nav .nav-link').forEach(a => a.classList.toggle('active', a.dataset.go === state.view));
  document.title = v.title + ' · Wish List admin';

  if (v.custom){
    $('#page').innerHTML = `
      <div class="page-header">
        <div><h1>${esc(v.title)}</h1><p class="page-lede">${esc(v.lede)}</p></div>
      </div>
      ${v.custom()}`;
    return;
  }

  const tabId = state.tab[state.view] || v.tabs[0].id;
  const f = state.filters[state.view] || {};
  const activeFilters = Object.values(f).filter(Boolean).length;
  const rows = currentRows();
  const pages = Math.max(1, Math.ceil(rows.length / state.per));
  const page = Math.min(state.page, pages);
  const slice = rows.slice((page - 1) * state.per, page * state.per);
  const s = state.sort[state.view];
  const allRows = v.rows();

  $('#page').innerHTML = `
    <div class="page-header">
      <div><h1>${esc(v.title)}</h1><p class="page-lede">${esc(v.lede)}</p></div>
      <div class="page-header-actions">
        ${v.actions.map(a => `<button class="btn ${a.primary ? 'btn-primary' : 'btn-outline-secondary'}">
          <i class="bi bi-${a.icon} me-1"></i>${esc(a.label)}</button>`).join('')}
      </div>
    </div>

    <div class="stat-cards">
      ${v.stats().map(st => statCard(st.label, String(st.value), st.icon, st.color, st.note)).join('')}
    </div>

    <div class="page-tabs">
      <ul class="nav nav-tabs" role="tablist">
        ${v.tabs.map(t => {
          const n = allRows.filter(t.test).length;
          const cls = t.tone ? `bg-${t.tone} bg-opacity-10 text-${t.tone}` : 'bg-secondary bg-opacity-10 text-secondary';
          return `<li class="nav-item"><button class="nav-link ${t.id === tabId ? 'active' : ''}" data-tab="${t.id}">
            ${esc(t.label)} <span class="badge ${cls}">${n}</span></button></li>`;
        }).join('')}
      </ul>
    </div>

    <div class="toolbar">
      <div class="toolbar-search">
        <i class="bi bi-search search-icon"></i>
        <input type="text" class="form-control" id="q" placeholder="${esc(v.searchPlaceholder)}" value="${esc(state.q)}">
      </div>
      <div class="toolbar-right">
        <button class="toolbar-btn ${state.filtersOpen || activeFilters ? 'on' : ''}" id="filterBtn">
          <i class="bi bi-funnel"></i> Filter${activeFilters ? ` <span class="count-pill">${activeFilters}</span>` : ''}
        </button>
        <div class="dropdown">
          <button class="toolbar-btn dropdown-toggle" data-bs-toggle="dropdown"><i class="bi bi-sort-down"></i> Sort</button>
          <ul class="dropdown-menu dropdown-menu-end">
            ${v.columns.filter(c => c.val).map(c => `
              <li><button class="dropdown-item" data-sort="${c.key}" data-dir="asc">${esc(c.label)} ascending</button></li>
              <li><button class="dropdown-item" data-sort="${c.key}" data-dir="desc">${esc(c.label)} descending</button></li>`).join('')}
            <li><hr class="dropdown-divider"></li>
            <li><button class="dropdown-item" data-sort="" data-dir="">Clear sort</button></li>
          </ul>
        </div>
        <button class="toolbar-btn"><i class="bi bi-columns-gap"></i> Columns</button>
        <div class="layout-toggle">
          <button class="toggle-btn active" title="List view"><i class="bi bi-list-ul"></i></button>
          <button class="toggle-btn" title="Grid view"><i class="bi bi-grid-3x3-gap"></i></button>
        </div>
      </div>
    </div>

    <div class="filter-bar ${state.filtersOpen ? 'open' : ''}" id="filterBar">
      ${(v.filters || []).map(def => `
        <div class="filter-field">
          <label for="f_${def.key}">${esc(def.label)}</label>
          <select class="form-select" id="f_${def.key}" data-filter="${def.key}">
            ${def.options.map(o => `<option value="${esc(o.v)}" ${f[def.key] === o.v ? 'selected' : ''}>${esc(o.label)}</option>`).join('')}
          </select>
        </div>`).join('')}
      <button class="clear-filters" id="clearFilters">Clear all filters</button>
    </div>

    <div class="bulk-bar ${state.selected.size ? 'open' : ''}">
      <span class="bulk-count">${state.selected.size} selected</span>
      <span class="spacer"></span>
      <button class="toolbar-btn"><i class="bi bi-download"></i> Export selected</button>
      <button class="toolbar-btn"><i class="bi bi-tag"></i> Tag</button>
      <button class="toolbar-btn" id="clearSel"><i class="bi bi-x-lg"></i> Clear</button>
    </div>

    <div class="data-table-wrapper">
      <div class="table-scroll">
        <table class="table">
          <thead>
            <tr>
              <th style="width:40px"><input class="form-check-input" type="checkbox" id="selAll"
                ${slice.length && slice.every(r => state.selected.has(r.id)) ? 'checked' : ''}></th>
              ${v.columns.map(c => `<th class="${c.val ? 'sortable' : ''} ${s?.key === c.key ? 'sorted' : ''} ${c.align === 'end' ? 'text-end' : ''}"
                data-col="${c.key}">${esc(c.label)}${c.val ? `<i class="bi bi-caret-${s?.key === c.key && s.dir === 'asc' ? 'up' : 'down'}-fill sort-caret"></i>` : ''}</th>`).join('')}
              <th style="width:48px"></th>
            </tr>
          </thead>
          <tbody>
            ${slice.length ? slice.map(r => `
              <tr data-id="${esc(r.id)}" class="${state.selected.has(r.id) ? 'selected' : ''}">
                <td><input class="form-check-input" type="checkbox" data-sel="${esc(r.id)}" ${state.selected.has(r.id) ? 'checked' : ''}></td>
                ${v.columns.map(c => `<td class="${c.align === 'end' ? 'text-end' : ''}">${c.cell(r)}</td>`).join('')}
                <td><button class="row-actions-btn" data-bs-toggle="dropdown"><i class="bi bi-three-dots"></i></button>
                  <ul class="dropdown-menu dropdown-menu-end">
                    <li><button class="dropdown-item" data-open="${esc(r.id)}"><i class="bi bi-eye me-2"></i>View details</button></li>
                    <li><button class="dropdown-item"><i class="bi bi-pencil me-2"></i>Edit</button></li>
                    <li><button class="dropdown-item"><i class="bi bi-download me-2"></i>Export row</button></li>
                    <li><hr class="dropdown-divider"></li>
                    <li><button class="dropdown-item text-danger"><i class="bi bi-archive me-2"></i>Archive</button></li>
                  </ul>
                </td>
              </tr>`).join('')
            : `<tr><td colspan="${v.columns.length + 2}">
                <div class="empty-state"><i class="bi bi-inbox"></i>
                  <h3>Nothing matches</h3>
                  <p>No ${esc(v.title.toLowerCase())} match this tab, search, and filter combination.</p>
                </div></td></tr>`}
          </tbody>
        </table>
      </div>

      <div class="table-footer">
        <div class="table-footer-left">
          <nav>
            <ul class="pagination pagination-sm">
              <li class="page-item ${page === 1 ? 'disabled' : ''}"><a class="page-link" data-page="${page - 1}"><i class="bi bi-chevron-left"></i></a></li>
              ${pageNumbers(page, pages).map(p => p === '…'
                ? '<li class="page-item disabled"><a class="page-link">…</a></li>'
                : `<li class="page-item ${p === page ? 'active' : ''}"><a class="page-link" data-page="${p}">${p}</a></li>`).join('')}
              <li class="page-item ${page === pages ? 'disabled' : ''}"><a class="page-link" data-page="${page + 1}"><i class="bi bi-chevron-right"></i></a></li>
            </ul>
          </nav>
          <span class="ms-3 text-muted">${rows.length
            ? `Showing ${(page - 1) * state.per + 1}–${Math.min(page * state.per, rows.length)} of ${rows.length} ${rows.length === 1 ? 'record' : 'records'}`
            : 'No results'}</span>
        </div>
        <div class="table-footer-right">
          <span class="text-muted">Rows per page:</span>
          <select class="form-select form-select-sm" id="per">
            ${[10, 25, 50, 100].map(n => `<option ${n === state.per ? 'selected' : ''}>${n}</option>`).join('')}
          </select>
        </div>
      </div>
    </div>`;

  state.page = page;
}

function pageNumbers(page, pages){
  if (pages <= 7) return Array.from({ length: pages }, (_, i) => i + 1);
  if (page <= 4) return [1, 2, 3, 4, 5, '…', pages];
  if (page >= pages - 3) return [1, '…', pages - 4, pages - 3, pages - 2, pages - 1, pages];
  return [1, '…', page - 1, page, page + 1, '…', pages];
}

/* ── Detail drawer ── */
const drawer = new bootstrap.Offcanvas('#drawer');

function openDetail(id){
  const v = VIEWS[state.view];
  const row = v.rows().find(r => String(r.id) === String(id));
  if (!row || !v.detail) return;
  const d = v.detail(row);
  $('#drawerTitle').textContent = d.title;
  $('#drawerBody').innerHTML = d.html;
  drawer.show();
}

/* ── Events ── */
function go(view){
  state.view = view;
  state.q = '';
  state.page = 1;
  state.selected.clear();
  state.filtersOpen = false;
  render();
  window.scrollTo({ top: 0 });
  $('.sidebar').classList.remove('open');
}

document.addEventListener('click', e => {
  const nav = e.target.closest('[data-go]');
  if (nav){ e.preventDefault(); go(nav.dataset.go); return; }

  const tab = e.target.closest('[data-tab]');
  if (tab){ state.tab[state.view] = tab.dataset.tab; state.page = 1; state.selected.clear(); render(); return; }

  if (e.target.closest('#filterBtn')){ state.filtersOpen = !state.filtersOpen; render(); return; }

  if (e.target.closest('#clearFilters')){ state.filters[state.view] = {}; state.page = 1; render(); return; }

  const sortItem = e.target.closest('[data-sort]');
  if (sortItem){
    state.sort[state.view] = sortItem.dataset.sort ? { key: sortItem.dataset.sort, dir: sortItem.dataset.dir } : null;
    render();
    return;
  }

  const col = e.target.closest('th.sortable');
  if (col){
    const cur = state.sort[state.view];
    state.sort[state.view] = cur && cur.key === col.dataset.col && cur.dir === 'asc'
      ? { key: col.dataset.col, dir: 'desc' }
      : { key: col.dataset.col, dir: 'asc' };
    render();
    return;
  }

  const pg = e.target.closest('[data-page]');
  if (pg){ const n = +pg.dataset.page; if (n >= 1){ state.page = n; render(); } return; }

  if (e.target.closest('#clearSel')){ state.selected.clear(); render(); return; }

  const sel = e.target.closest('[data-sel]');
  if (sel){
    e.stopPropagation();
    const id = sel.dataset.sel;
    state.selected.has(id) ? state.selected.delete(id) : state.selected.add(id);
    render();
    return;
  }

  if (e.target.closest('#selAll')){
    const rows = currentRows().slice((state.page - 1) * state.per, state.page * state.per);
    const all = rows.every(r => state.selected.has(r.id));
    rows.forEach(r => all ? state.selected.delete(r.id) : state.selected.add(r.id));
    render();
    return;
  }

  const openBtn = e.target.closest('[data-open]');
  if (openBtn){ openDetail(openBtn.dataset.open); return; }

  const row = e.target.closest('tbody tr[data-id]');
  if (row && !e.target.closest('.row-actions-btn, .dropdown-menu, input')){ openDetail(row.dataset.id); return; }

  if (e.target.closest('.sidebar-toggle')){ $('.sidebar').classList.toggle('open'); return; }
});

document.addEventListener('input', e => {
  if (e.target.id === 'q'){
    state.q = e.target.value;
    state.page = 1;
    render();
    const box = $('#q');
    box.focus();
    box.setSelectionRange(box.value.length, box.value.length);
  }
});

document.addEventListener('change', e => {
  const fl = e.target.closest('[data-filter]');
  if (fl){
    state.filters[state.view] = { ...(state.filters[state.view] || {}), [fl.dataset.filter]: fl.value };
    state.page = 1;
    render();
    return;
  }
  if (e.target.id === 'per'){ state.per = +e.target.value; state.page = 1; render(); }
});

/* ── Sidebar counts and season strip ── */
function chrome(){
  $('#cLines').textContent = lines.length;
  $('#cLists').textContent = wishlists.length;
  $('#cHouseholds').textContent = HOUSES.length;
  $('#cDonors').textContent = donors.length;
  $('#cCharges').textContent = charges.length;
  $('#cSubs').textContent = TOTALS.needsReview + TOTALS.flagged;
  $('#seasonName').textContent = SEASON.name;
  $('#seasonRaised').textContent = money(TOTALS.raised) + ' of ' + money(SEASON.goal);
  $('#seasonBar').style.width = Math.min(100, TOTALS.goalPct) + '%';
  $('#seasonNote').textContent = `${TOTALS.goalPct}% there · ${TOTALS.daysLeft} days left`;
  $('#notifCount').textContent = TOTALS.needsReview;
}

chrome();
go('overview');
