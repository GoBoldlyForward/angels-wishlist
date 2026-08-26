/* ──────────────────────────────────────────────
   Atlanta Angels · Wish List — admin dataset

   Everything here is derived from data.js rather than invented alongside it,
   so the admin and the donor site cannot drift. A line item exists because a
   caregiver put it on a child's list; a donor exists because a line says who
   funded it; a charge exists because a donor funded something.

   Lists submitted through caregiver.html land in localStorage and show up
   here as Needs review, which is the same handoff the donor site uses.
   ────────────────────────────────────────────── */

/* The demo clock. Fixed so the prototype always opens mid-season with a
   populated program instead of an empty pre-launch one. */
const SEASON = {
  name: 'Christmas 2026',
  opened: '2026-10-06',
  today:  '2026-11-18',
  closes: '2026-12-08',
  payout: '2026-12-09',
  /* The goal is what the lists actually ask for, which is how the donor
     home page computes it too. An invented target would let the two pages
     disagree about the same season. */
  goal:   0,
};

const TODAY = new Date(SEASON.today + 'T12:00:00');

/* Deterministic pseudo-random so every reload shows the same program. */
function mulberry(seed){
  return function(){
    seed |= 0; seed = seed + 0x6D2B79F5 | 0;
    let t = Math.imul(seed ^ seed >>> 15, 1 | seed);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}
const seedOf = s => [...String(s)].reduce((a, c) => a * 31 + c.charCodeAt(0) | 0, 7);
const pick = (arr, key) => arr[Math.floor(mulberry(seedOf(key))() * arr.length)];
const between = (lo, hi, key) => lo + Math.floor(mulberry(seedOf(key))() * (hi - lo + 1));

const money = n => '$' + Math.round(n).toLocaleString('en-US');
const money2 = n => '$' + n.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const dayShift = (iso, days) => {
  const d = new Date(iso + 'T12:00:00');
  d.setDate(d.getDate() + days);
  return d;
};
const fmtDate = d => d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
const fmtShort = d => d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
const fmtAgo = d => {
  const days = Math.round((TODAY - d) / 86400000);
  if (days <= 0) return 'today';
  if (days === 1) return 'yesterday';
  if (days < 7) return days + ' days ago';
  if (days < 14) return 'a week ago';
  return Math.floor(days / 7) + ' weeks ago';
};

/* ── Lists submitted through the caregiver flow ──
   The same localStorage key the donor site reads, so a list built in
   caregiver.html appears here as a household awaiting verification. */
function loadSubmitted(){
  try {
    const raw = localStorage.getItem('aa_submitted_kids');
    return raw ? JSON.parse(raw).map(k => ({ ...k, fresh: true })) : [];
  } catch (e) { return []; }
}

/* ── Households ──
   Contact, agency, verification, and payout live only on this side. A donor
   never sees any of it, which is why none of it is in data.js.

   Intake does not ask a caregiver for the placing agency or the case manager,
   so this is the only place either one exists: staff record the agency when
   they verify the placement. A household that signed up and has not been
   verified yet carries no agency at all, which is the honest state. */
const HH_EXTRA = {
  h1:  { email:'denise.brooks@example.com',  phone:'(404) 555-0134', agency:'Bethany Christian Services', verify:'verified', verifiedOn:12, payout:'stripe',   dest:'Wells Fargo ••••4471',      joined:0,  returning:true  },
  h2:  { email:'grace.okafor@example.com',   phone:'(678) 555-0192', agency:'DFCS · DeKalb',              verify:'verified', verifiedOn:11, payout:'stripe',   dest:'Truist ••••8890',           joined:1,  returning:true  },
  h3:  { email:'marcus.vance@example.com',   phone:'(770) 555-0148', agency:'DFCS · Cobb',                verify:'verified', verifiedOn:14, payout:'giftcard', dest:'Mailed to Marietta, GA',    joined:2,  returning:false },
  h4:  { email:'rosa.delgado@example.com',   phone:'(404) 555-0177', agency:'Faithbridge Foster Care',    verify:'verified', verifiedOn:10, payout:'stripe',   dest:'Chase ••••2015',            joined:1,  returning:true  },
  h5:  { email:'tamika.whitfield@example.com',phone:'(678) 555-0110',agency:'DFCS · Gwinnett',            verify:'verified', verifiedOn:15, payout:'stripe',   dest:'Bank of America ••••7723',  joined:3,  returning:true  },
  h6:  { email:'carmen.alvarez@example.com', prefLang:'Spanish', phone:'(470) 555-0163', agency:'DFCS · Henry', verify:'verified', verifiedOn:9, payout:'giftcard', dest:'Mailed to McDonough, GA', joined:4, returning:false },
  h7:  { email:'kofi.boateng@example.com',   phone:'(678) 555-0129', agency:'Bethany Christian Services', verify:'verified', verifiedOn:8,  payout:'stripe',   dest:'Navy Federal ••••3364',     joined:5,  returning:false },
  h8:  { email:'renee.sinclair@example.com', phone:'(770) 555-0155', agency:'DFCS · Douglas',             verify:'pending',  verifiedOn:null,payout:'none',    dest:'Not set up yet',            joined:9,  returning:false },
  h9:  { email:'mai.tran@example.com',       phone:'(404) 555-0181', agency:'Faithbridge Foster Care',    verify:'verified', verifiedOn:13, payout:'stripe',   dest:'Regions ••••6602',          joined:2,  returning:true  },
  h10: { email:'pam.whitaker@example.com',   phone:'(678) 555-0138', agency:'DFCS · Clayton',             verify:'hold',     verifiedOn:null,payout:'stripe',  dest:'Synovus ••••9018',          joined:7,  returning:false },
};

const HOLD_REASON = 'Placement change reported Nov 14. Confirming with the Clayton case manager before this household is paid out.';

const submittedKids = loadSubmitted();

/* Any list submitted through caregiver.html becomes a real household here. */
const submittedHouseholds = [];
submittedKids.forEach(k => {
  if (submittedHouseholds.some(h => h.name === k.hhName)) return;
  submittedHouseholds.push({
    id: 'hs' + (submittedHouseholds.length + 1),
    name: k.hhName || 'New household',
    area: k.area || 'Metro Atlanta',
    caregiver: k.caregiver || 'New caregiver',
    submitted: true,
  });
});
const submittedHhIdByName = Object.fromEntries(submittedHouseholds.map(h => [h.name, h.id]));

const HOUSES = [...HOUSEHOLDS, ...submittedHouseholds].map(h => {
  const x = HH_EXTRA[h.id] || {
    email: h.caregiver.toLowerCase().replace(/[^a-z]/g, '.') + '@example.com',
    phone: '(404) 555-01' + between(10, 99, h.id),
    agency: 'Awaiting agency confirmation',
    verify: 'pending', verifiedOn: null, payout: 'none', dest: 'Not set up yet',
    joined: 0, returning: false,
  };
  return {
    ...h, ...x,
    joinedAt: dayShift(SEASON.opened, x.joined || 0),
    verifiedAt: x.verifiedOn != null ? dayShift(SEASON.opened, x.joined + 1) : null,
    county: h.area,
    holdReason: x.verify === 'hold' ? HOLD_REASON : null,
  };
});
const houseById = Object.fromEntries(HOUSES.map(h => [h.id, h]));

/* ── Children and their lists ── */
const ALL_KIDS = [
  ...submittedKids.map(k => ({ ...k, hh: submittedHhIdByName[k.hhName] || 'hs1' })),
  ...KIDS,
];
const kidById = Object.fromEntries(ALL_KIDS.map(k => [k.id, k]));

/* ── Donors ──
   Names come off the funded lines in data.js. An anonymous gift still has a
   donor record with a real name and an email; the alias is a display rule,
   not missing data. Staff see both, which is the point of this table. */
const ANON_IDENTITIES = [
  ['Nathan Poole','nathan.poole@example.com'], ['Bettina Ruiz','b.ruiz@example.com'],
  ['Chris Yamada','cyamada@example.com'], ['Dana Kirkland','dana.k@example.com'],
  ['Wes Aldridge','wesa@example.com'], ['Priscilla Bowen','pbowen@example.com'],
  ['Trent Alcott','trent.alcott@example.com'], ['Joanna Meier','jmeier@example.com'],
  ['Rafael Cordova','rcordova@example.com'], ['Hannah Steed','h.steed@example.com'],
  ['Miles Ferrante','miles.f@example.com'], ['Ada Lindqvist','ada.l@example.com'],
];

const DONOR_EMAIL = {
  'Priya S.': 'priya.sundaram@example.com',
  'The Hollis family': 'kate.hollis@example.com',
  'Piedmont Church youth group': 'students@piedmontchurch.example.org',
  'M. Okonkwo': 'm.okonkwo@example.com',
  'Kroger volunteer team': 'atl.volunteers@kroger.example.com',
  'The Nguyen family': 'thenguyens@example.com',
  'Delta ATL crew': 'giving@deltacrew.example.org',
  'The Reyes family': 'reyes.household@example.com',
  'Buckhead Rotary': 'service@buckheadrotary.example.org',
  'The Ferrell family': 'ferrell4@example.com',
  'Emory service group': 'volunteer@emory.example.edu',
};

const GROUP_WORDS = /group|team|rotary|crew|church|club|chapter|company|foundation/i;
const donorType = name => GROUP_WORDS.test(name) ? 'group' : (/family|household/i.test(name) ? 'family' : 'individual');

const donors = [];
const donorByKey = {};
let anonSeq = 0;

function donorFor(displayName, key){
  const anon = displayName === 'Anonymous';
  const lookup = anon ? 'anon:' + key : displayName;
  if (donorByKey[lookup]) return donorByKey[lookup];

  const [realName, email] = anon
    ? ANON_IDENTITIES[anonSeq++ % ANON_IDENTITIES.length]
    : [displayName, DONOR_EMAIL[displayName] || displayName.toLowerCase().replace(/[^a-z]+/g, '.') + '@example.com'];

  const d = {
    id: 'd' + String(donors.length + 1).padStart(3, '0'),
    name: realName,
    display: anon ? 'Anonymous' : displayName,
    anonymous: anon,
    email,
    type: donorType(realName),
    lines: [], flex: [], charges: [],
    total: 0, feesCovered: 0,
    firstAt: null, lastAt: null,
    receipts: 'sent',
  };
  donors.push(d);
  donorByKey[lookup] = d;
  return d;
}

/* ── Line items ──
   One row per gift a caregiver put on a child's list. This is the grain the
   whole program settles on: it names the gift, the child, the household, and
   who funded it. */
const LINE_STATUS = { open:'Open', funded:'Funded', flagged:'Needs review', withdrawn:'Withdrawn' };

const lines = ALL_KIDS.flatMap((k, ki) => k.items.map((it, ii) => {
  const hh = houseById[k.hh] || HOUSES[0];
  const key = it.id;
  const addedAt = dayShift(SEASON.opened, (hh.joined || 0) + between(0, 3, key + 'a'));
  const funded = !!it.claimed;
  const fundedAt = funded ? dayShift(SEASON.opened, (hh.joined || 0) + between(4, 42, key + 'f')) : null;
  const custom = !catalogById[it.catId];

  return {
    id: 'L-' + String(ki * 10 + ii + 1001),
    lineId: it.id,
    gift: it.name,
    spec: it.spec || null,
    link: it.link || null,
    catId: it.catId,
    cat: it.cat,
    catLabel: (catById[it.cat] || {}).label || 'Other',
    icon: it.icon,
    photo: typeof photoFor === 'function' ? photoFor(it.catId) : null,
    price: it.price,
    listPrice: (catalogById[it.catId] || {}).price ?? it.price,
    custom,
    kidId: k.id,
    alias: k.alias,
    age: k.age,
    gender: k.gender,
    hhId: hh.id,
    household: hh.name,
    county: hh.county || hh.area,
    caregiver: hh.caregiver,
    status: k.fresh ? 'flagged' : (funded ? 'funded' : 'open'),
    funderDisplay: it.claimedBy || null,
    addedAt,
    fundedAt,
    pooled: !it.spec,
  };
}));

/* Attach a donor to every funded line. */
lines.filter(l => l.status === 'funded').forEach(l => {
  const d = donorFor(l.funderDisplay, l.lineId);
  l.donorId = d.id;
  l.donorName = d.name;
  d.lines.push(l);
});

const linesByKid = {};
lines.forEach(l => (linesByKid[l.kidId] = linesByKid[l.kidId] || []).push(l));

/* ── General giving ──
   Donations that are not tied to a line. Kept as their own rows so the
   ledger never implies a child chose them. */
const FLEX_GIVERS = [
  ['Priya S.', 100, 26], ['Anonymous', 250, 31], ['Buckhead Rotary', 500, 18],
  ['The Hollis family', 50, 35], ['Anonymous', 25, 39], ['Sandra Coyle', 250, 22],
  ['Emory service group', 150, 29], ['Anonymous', 100, 41], ['Dev Raghunathan', 500, 12],
  ['Anonymous', 50, 37], ['The Marchetti family', 200, 33], ['Grady nurses fund', 400, 24],
];

const flexGifts = FLEX_GIVERS.map(([name, amount, day], i) => {
  const d = donorFor(name, 'flex' + i);
  const g = {
    id: 'F-' + (2001 + i),
    amount,
    donorId: d.id,
    donorName: d.name,
    display: d.display,
    at: dayShift(SEASON.opened, day),
    applied: false,
  };
  d.flex.push(g);
  return g;
});

/* ── Donations / charges ──
   A charge is what actually hit a card. It can carry many lines across many
   households plus a general gift, which is exactly why it needs its own
   index rather than living inside the line item table. */
/* Stripe-shaped ids. Seeded from the charge key so they are stable across
   reloads, mixed hard enough that neighbouring charges do not share a prefix. */
function chargeId(key){
  let h = 0x811c9dc5;
  for (const ch of 'ch' + key){ h ^= ch.charCodeAt(0); h = Math.imul(h, 0x01000193) >>> 0; }
  let out = '';
  while (out.length < 20){
    h = Math.imul(h ^ h >>> 15, 0x2545f491) >>> 0;
    out += h.toString(36);
  }
  return 'ch_3' + out.slice(0, 20);
}

const METHODS = ['Visa ••••4242', 'Mastercard ••••5518', 'Visa ••••1881', 'Amex ••••3007', 'Apple Pay · Visa ••••9021', 'ACH · Truist ••••3390'];

const charges = [];
donors.forEach(d => {
  /* Group a donor's activity into charges the way a cart would: everything
     they funded on the same day rode the same card. */
  const events = [
    ...d.lines.map(l => ({ kind:'line', at: l.fundedAt, ref: l })),
    ...d.flex.map(f => ({ kind:'flex', at: f.at, ref: f })),
  ].sort((a, b) => a.at - b.at);

  const buckets = [];
  events.forEach(e => {
    const last = buckets[buckets.length - 1];
    if (last && Math.abs(e.at - last[0].at) < 3 * 86400000) last.push(e);
    else buckets.push([e]);
  });

  buckets.forEach((bucket, bi) => {
    const key = d.id + bi;
    const gift = bucket.reduce((s, e) => s + (e.kind === 'line' ? e.ref.price : e.ref.amount), 0);
    const covered = mulberry(seedOf(key + 'fee'))() > 0.22;
    const fee = covered ? Math.round(gift * 3) / 100 : 0;
    const roll = mulberry(seedOf(key + 'st'))();
    const status = roll > 0.965 ? 'refunded' : roll > 0.945 ? 'disputed' : roll > 0.925 ? 'pending' : 'succeeded';

    const c = {
      id: chargeId(key),
      donorId: d.id,
      donorName: d.name,
      display: d.display,
      anonymous: d.anonymous,
      at: bucket[bucket.length - 1].at,
      gift,
      fee,
      charged: gift + fee,
      net: status === 'refunded' ? 0 : gift,
      feeCovered: covered,
      method: pick(METHODS, key + 'm'),
      status,
      lineIds: bucket.filter(e => e.kind === 'line').map(e => e.ref.id),
      flexIds: bucket.filter(e => e.kind === 'flex').map(e => e.ref.id),
      households: [...new Set(bucket.filter(e => e.kind === 'line').map(e => e.ref.household))],
      kids: [...new Set(bucket.filter(e => e.kind === 'line').map(e => e.ref.alias))],
      note: null,
    };
    charges.push(c);
    d.charges.push(c.id);
    bucket.forEach(e => { e.ref.chargeId = c.id; });
  });
});

charges.sort((a, b) => b.at - a.at);

/* Roll charge totals back onto the donor rows. */
donors.forEach(d => {
  const mine = charges.filter(c => c.donorId === d.id);
  d.total = mine.filter(c => c.status !== 'refunded').reduce((s, c) => s + c.gift, 0);
  d.feesCovered = mine.reduce((s, c) => s + c.fee, 0);
  d.giftCount = d.lines.length;
  d.kidCount = new Set(d.lines.map(l => l.kidId)).size;
  d.hhCount = new Set(d.lines.map(l => l.hhId)).size;
  d.firstAt = mine.length ? new Date(Math.min(...mine.map(c => +c.at))) : null;
  d.lastAt = mine.length ? new Date(Math.max(...mine.map(c => +c.at))) : null;
  d.chargeCount = mine.length;
  d.receipts = mine.some(c => c.status === 'pending') ? 'queued' : 'sent';
  d.lifetime = d.total + (d.type === 'individual' ? between(0, 3, d.id) * 120 : between(0, 5, d.id) * 260);
});

/* ── Wish lists ──
   One row per child. Funded, asked, and what is still open, which is the
   number staff use to decide where general giving goes. */
const wishlists = ALL_KIDS.map(k => {
  const mine = linesByKid[k.id] || [];
  const asked = mine.reduce((s, l) => s + l.price, 0);
  const raised = mine.filter(l => l.status === 'funded').reduce((s, l) => s + l.price, 0);
  const hh = houseById[k.hh] || HOUSES[0];
  const pct = asked ? Math.round(raised / asked * 100) : 0;

  let status = 'live';
  if (k.fresh) status = 'review';
  else if (hh.verify === 'pending') status = 'review';
  else if (hh.verify === 'hold') status = 'hold';
  else if (pct >= 100) status = 'complete';

  return {
    id: k.id,
    alias: k.alias,
    age: k.age,
    gender: k.gender,
    interests: k.interests || [],
    note: k.note || '',
    hhId: hh.id,
    household: hh.name,
    county: hh.county || hh.area,
    caregiver: hh.caregiver,
    gifts: mine.length,
    fundedCount: mine.filter(l => l.status === 'funded').length,
    asked, raised, pct,
    remaining: Math.max(0, asked - raised),
    overCap: asked > 300,
    status,
    submittedAt: dayShift(SEASON.opened, hh.joined || 0),
    lastActivity: mine.filter(l => l.fundedAt).sort((a, b) => b.fundedAt - a.fundedAt)[0]?.fundedAt || dayShift(SEASON.opened, hh.joined || 0),
    lines: mine,
  };
});
const wishlistById = Object.fromEntries(wishlists.map(w => [w.id, w]));

/* Household rollups depend on the lists, so they come last. */
HOUSES.forEach(h => {
  const kids = wishlists.filter(w => w.hhId === h.id);
  h.children = kids.length;
  h.asked = kids.reduce((s, w) => s + w.asked, 0);
  h.raised = kids.reduce((s, w) => s + w.raised, 0);
  h.pct = h.asked ? Math.round(h.raised / h.asked * 100) : 0;
  h.gifts = kids.reduce((s, w) => s + w.gifts, 0);
  h.fundedGifts = kids.reduce((s, w) => s + w.fundedCount, 0);
  h.payoutStatus = h.verify === 'hold' ? 'hold'
    : h.payout === 'none' ? 'nomethod'
    : h.verify === 'pending' ? 'blocked'
    : 'scheduled';
});

/* ── Submissions ──
   Everything a caregiver or a donor typed that is not a gift or a dollar.
   Some of it publishes to the donor site, some of it never leaves this room,
   and the difference is a column rather than a footnote. */
const SUB_TYPES = {
  'child-profile':   { label:'Child profile',        icon:'person-badge',        who:'caregiver', visible:true  },
  'custom-gift':     { label:'Custom gift request',  icon:'plus-square',         who:'caregiver', visible:true  },
  'gift-detail':     { label:'Gift detail',          icon:'tag',                 who:'caregiver', visible:true  },
  'list-edit':       { label:'List edit',            icon:'pencil-square',       who:'caregiver', visible:true  },
  'payout-method':   { label:'Payout details',       icon:'bank',                who:'caregiver', visible:false },
  'address-change':  { label:'Address change',       icon:'geo-alt',             who:'caregiver', visible:false },
  'household-signup':{ label:'New household',        icon:'house-add',           who:'caregiver', visible:false },
  'agency-doc':      { label:'Agency verification',  icon:'file-earmark-check',  who:'agency',    visible:false },
  'caregiver-msg':   { label:'Message to staff',     icon:'chat-left-text',      who:'caregiver', visible:false },
  'donor-note':      { label:'Note to the family',   icon:'envelope-heart',      who:'donor',     visible:true  },
  'donor-name':      { label:'Display name',         icon:'incognito',           who:'donor',     visible:true  },
  'donor-question':  { label:'Donor question',       icon:'question-circle',     who:'donor',     visible:false },
};

const SUB_SEED = [
  ['child-profile','k5','Luca, 3','Marcus V.','First placement. He is just starting to settle in and loves anything with wheels.','review',6,'Placement date is three weeks old. Confirm the caregiver is comfortable with this going live.'],
  ['child-profile','k10','Darius, 17','Tamika W.','He ages out in eleven months. Driving is the difference between a job and no job.','approved',4,null],
  ['child-profile','k18','Owen, 11','Mai T.','His caseworker says he has not asked for anything in two years.','flagged',7,'Mentions the caseworker. Rewrite with the caregiver so it stays about the child, not the case.'],
  ['child-profile','k15','Ruby, 2','Renee S.','Placed with her two brothers in September. Everything in her room came from a donation bin.','review',9,'New household, still pending agency confirmation.'],
  ['child-profile','k12','Aria, 5','Carmen A.','She has been in this home since March and finally asked for something for herself.','approved',5,null],

  ['gift-detail','k3','Amari, 14 · Hoodie','Grace O.','Nike, size L','approved',8,null],
  ['gift-detail','k6','Selah, 16 · Instant camera and film','Marcus V.','Instax Mini, any color','approved',10,null],
  ['gift-detail','k13','Micah, 13 · Sneakers that fit right now','Kofi B.','Air Force 1s, size 7','review',3,'Priced at $95 against a $70 catalog line. Confirm before it goes live at the higher amount.'],
  ['gift-detail','k9','Elena, 11 · Soccer cleats','Tamika W.','Size 6, any brand','approved',12,null],
  ['gift-detail','k17','Camila, 9 · Soccer cleats','Mai T.','Size 4','approved',11,null],
  ['gift-detail','k11','Jaylen, 10 · Art supply set','Carmen A.','Copic markers if possible','review',2,'Copic sets run well above the $48 line. Ask whether a smaller set works.'],

  ['custom-gift','k19','Tasha, 16 · Graphing calculator','Pam W.','TI-84 for her college placement math. $120.','review',3,'Reasonable, but this household is on hold pending a placement change.'],
  ['custom-gift','k10','Darius, 17 · Work boots for his job','Tamika W.','Steel toe, he starts at the warehouse in January. $95.','approved',6,null],
  ['custom-gift','k4','Nia, 12 · Cake decorating class','Grace O.','Six weeks at the rec center. $140.','review',1,'Above the usual line price. Worth approving, flagging for the cap conversation.'],

  ['list-edit','k7','Kai, 8','Rosa D.','Removed the bicycle, added a weighted blanket after his OT appointment.','approved',4,null],
  ['list-edit','k14','Zoe, 15','Kofi B.','Swapped the jewelry kit for hair care after a size mix-up last year.','approved',9,null],
  ['list-edit','k1','Maya, 9','Denise B.','Raised the art set from $48 to $60 for the tin she actually wants.','review',2,'Price change on a line that is already funded at $48. Needs a decision before payout.'],

  ['payout-method','h5','The Whitfield home','Tamika W.','Connected Bank of America ••••7723 through Stripe.','approved',14,null],
  ['payout-method','h3','The Vance home','Marcus V.','Chose a mailed Visa gift card instead of direct deposit.','approved',13,null],
  ['payout-method','h10','The Whitaker home','Pam W.','Switched from a gift card to Synovus ••••9018.','flagged',3,'Payout details changed four days before a reported placement change. Verify by phone, not email.'],
  ['payout-method','h8','The Sinclair home','Renee S.','Has not set up a payout method yet.','review',9,'Blocking. Two lists are live and cannot be paid.'],

  ['address-change','h6','The Alvarez home','Carmen A.','New mailing address in McDonough for the gift card.','approved',7,null],

  ['household-signup','h8','The Sinclair home','Renee S.','Three children placed in September. Referred by a Douglas County case manager.','review',9,'Waiting on the agency letter before the lists can go live.'],
  ['household-signup','h10','The Whitaker home','Pam W.','Two children, returning caregiver from last season.','approved',7,null],

  ['agency-doc','h8','The Sinclair home','DFCS · Douglas','Placement verification letter, requested Nov 9.','review',9,'Second request sent. Nothing publishes until this clears.'],
  ['agency-doc','h7','The Boateng home','Bethany Christian Services','Placement verification letter received and filed.','approved',10,null],

  ['caregiver-msg','h4','The Delgado home','Rosa D.','Kai has an OT appointment Dec 3 and we may need to swap the blanket size. Is that still okay after the deadline?','review',2,null],
  ['caregiver-msg','h2','The Okafor home','Grace O.','Amari asked if the music gear could come as one thing instead of two. Whatever is easier for you.','approved',5,null],

  ['donor-note','k1','To The Brooks home','Priya S.','Maya, keep drawing. The world needs people who see things the rest of us miss.','approved',20,null],
  ['donor-note','k8','To The Delgado home','Delta ATL crew','From all of us at the Delta ATL ramp. Merry Christmas to your whole house.','approved',17,null],
  ['donor-note','k10','To The Whitfield home','Anonymous','Darius, I aged out too. Get the license. It changes everything. Rooting for you.','review',4,'Discloses the donor was in care. Beautiful, but confirm they want it passed on before we forward it.'],
  ['donor-note','k16','To The Sinclair home','Anonymous','Isaiah, name all the planets for me at Christmas dinner.','approved',6,null],
  ['donor-note','k2','To The Brooks home','Piedmont Church youth group','Our whole youth group picked this one together. We are praying for your family.','approved',22,null],
  ['donor-note','k20','To The Whitaker home','Anonymous','Ask your foster mom to send us a picture of the truck. Just kidding. Have the best day.','flagged',5,'Asks for a photo. We do not pass photo requests to households. Reply and drop the last line.'],

  ['donor-name','k7','Funded a Lego building set','Anonymous','Wants the household to see Anonymous. Receipt still goes to their real name.','approved',13,null],
  ['donor-name','k6','Funded a Braves game, two tickets','Anonymous','Asked us not to use their employer name on the receipt.','approved',15,null],

  ['donor-question','d000','Checkout question','Sandra Coyle','If I give $250 to where it is needed most, do I find out which family it went to?','review',22,null],
  ['donor-question','d000','Checkout question','Dev Raghunathan','Can my company match this? Who do I send the confirmation to?','review',12,null],
  ['donor-question','d000','Checkout question','The Marchetti family','We funded the driver’s ed course. Can we add to it if the price went up?','approved',33,null],
];

const submissions = SUB_SEED.map((s, i) => {
  const [type, ref, about, from, body, status, daysAgo, staffNote] = s;
  const meta = SUB_TYPES[type];
  const at = new Date(+TODAY - daysAgo * 86400000);
  return {
    id: 'S-' + (3001 + i),
    type, typeLabel: meta.label, icon: meta.icon,
    who: meta.who,
    donorVisible: meta.visible,
    ref, about, from, body, status, staffNote, at,
    channel: meta.who === 'donor' ? 'Checkout' : meta.who === 'agency' ? 'Email' : 'Caregiver app',
  };
});

/* Lists submitted through caregiver.html join the top of the queue. */
submittedKids.forEach((k, i) => {
  submissions.unshift({
    id: 'S-' + (3900 + i),
    type: 'household-signup',
    typeLabel: 'New household',
    icon: 'house-add',
    who: 'caregiver',
    donorVisible: false,
    ref: k.hh,
    about: k.hhName + ' · ' + k.alias,
    from: k.caregiver,
    body: `${k.alias}, ${k.age}. ${k.items.length} gifts, ${money(k.items.reduce((s, it) => s + it.price, 0))}. ${k.note || ''}`.trim(),
    status: 'review',
    staffNote: 'Submitted from the caregiver flow in this browser. Verify the placement before the list goes live.',
    at: TODAY,
    channel: 'Caregiver app',
  });
});

submissions.sort((a, b) => b.at - a.at);

/* ── Program totals ── */
const TOTALS = {
  asked: lines.reduce((s, l) => s + l.price, 0),
  fundedLines: lines.filter(l => l.status === 'funded').length,
  openLines: lines.filter(l => l.status === 'open').length,
  designated: lines.filter(l => l.status === 'funded').reduce((s, l) => s + l.price, 0),
  general: flexGifts.reduce((s, f) => s + f.amount, 0),
  fees: charges.reduce((s, c) => s + c.fee, 0),
  refunded: charges.filter(c => c.status === 'refunded').reduce((s, c) => s + c.gift, 0),
  donors: donors.length,
  households: HOUSES.length,
  children: wishlists.length,
  listsComplete: wishlists.filter(w => w.pct >= 100).length,
  listsLive: wishlists.filter(w => w.status === 'live' || w.status === 'complete').length,
  needsReview: submissions.filter(s => s.status === 'review').length,
  flagged: submissions.filter(s => s.status === 'flagged').length,
  daysLeft: Math.round((new Date(SEASON.closes + 'T12:00:00') - TODAY) / 86400000),
};
SEASON.goal = TOTALS.asked;
TOTALS.raised = TOTALS.designated + TOTALS.general - TOTALS.refunded;
TOTALS.goalPct = Math.round(TOTALS.raised / SEASON.goal * 100);
