/* ──────────────────────────────────────────────
   Atlanta Angels · Wish List — seed data
   The donor catalog is not a store. It is the union of every child's
   wish list, so a tile can only exist because a caregiver put it there.
   ────────────────────────────────────────────── */

const CATEGORIES = [
  { id:'clothes',  label:'Clothes & Shoes',   icon:'fa-shirt',            tint:'t1' },
  { id:'toys',     label:'Toys & Play',       icon:'fa-shapes',           tint:'t2' },
  { id:'sports',   label:'Sports & Outdoors', icon:'fa-basketball',       tint:'t3' },
  { id:'books',    label:'Books & Learning',  icon:'fa-book-open',        tint:'t4' },
  { id:'art',      label:'Art & Music',       icon:'fa-palette',          tint:'t5' },
  { id:'tech',     label:'Tech & Gaming',     icon:'fa-headphones',       tint:'t6' },
  { id:'wheels',   label:'Bikes & Wheels',    icon:'fa-bicycle',          tint:'t7' },
  { id:'room',     label:'Comfort & Bedroom', icon:'fa-bed',              tint:'t8' },
  { id:'care',     label:'Care & Getting Ready', icon:'fa-pump-soap',     tint:'t1' },
  { id:'outings',  label:'Outings & Experiences', icon:'fa-ticket',       tint:'t3' },
];

/* The picker a caregiver browses. Prices are what the item typically runs
   in metro Atlanta, and they become the funding target for that line. */
const CATALOG = [
  { id:'c01', cat:'clothes', name:'Winter coat',              price:65,  icon:'🧥', ages:[2,18] },
  { id:'c02', cat:'clothes', name:'Sneakers that fit right now', price:70, icon:'👟', ages:[2,18] },
  { id:'c03', cat:'clothes', name:'Jeans, two pairs',         price:55,  icon:'👖', ages:[3,18] },
  { id:'c04', cat:'clothes', name:'Hoodie',                   price:40,  icon:'🧢', ages:[5,18] },
  { id:'c05', cat:'clothes', name:'Church or picture-day outfit', price:60, icon:'👗', ages:[2,18] },
  { id:'c06', cat:'clothes', name:'Pajama set',               price:28,  icon:'🌙', ages:[1,16] },
  { id:'c07', cat:'clothes', name:'Socks and underwear, full restock', price:35, icon:'🧦', ages:[1,18] },
  { id:'c08', cat:'clothes', name:'Rain boots',               price:32,  icon:'🥾', ages:[2,14] },

  { id:'c10', cat:'toys',    name:'Lego building set',        price:60,  icon:'🧱', ages:[5,14] },
  { id:'c11', cat:'toys',    name:'Dinosaur figure set',      price:30,  icon:'🦕', ages:[2,9] },
  { id:'c12', cat:'toys',    name:'Wooden train set',         price:48,  icon:'🚂', ages:[2,7] },
  { id:'c13', cat:'toys',    name:'Doll with extra outfits',  price:45,  icon:'🪆', ages:[2,10] },
  { id:'c14', cat:'toys',    name:'Board game for family night', price:28, icon:'🎲', ages:[5,18] },
  { id:'c15', cat:'toys',    name:'Dress-up trunk',           price:38,  icon:'👑', ages:[2,8] },
  { id:'c16', cat:'toys',    name:'Remote control car',       price:42,  icon:'🏎️', ages:[5,13] },
  { id:'c17', cat:'toys',    name:'Bubble machine',           price:22,  icon:'🫧', ages:[1,6] },

  { id:'c20', cat:'sports',  name:'Basketball and pump',      price:35,  icon:'🏀', ages:[6,18] },
  { id:'c21', cat:'sports',  name:'Soccer cleats',            price:55,  icon:'⚽', ages:[5,18] },
  { id:'c22', cat:'sports',  name:'Season fees for one sport', price:120, icon:'🏅', ages:[5,18] },
  { id:'c23', cat:'sports',  name:'Swim goggles and suit',    price:38,  icon:'🥽', ages:[3,17] },
  { id:'c24', cat:'sports',  name:'Skateboard and helmet',    price:85,  icon:'🛹', ages:[7,18] },
  { id:'c25', cat:'sports',  name:'Camping sleeping bag',     price:45,  icon:'🏕️', ages:[6,18] },

  { id:'c30', cat:'books',   name:'Chapter book series',      price:35,  icon:'📚', ages:[6,14] },
  { id:'c31', cat:'books',   name:'Picture books, stack of six', price:40, icon:'📖', ages:[1,7] },
  { id:'c32', cat:'books',   name:'Science kit',              price:45,  icon:'🔬', ages:[7,15] },
  { id:'c33', cat:'books',   name:'Baking set and cookbook',  price:50,  icon:'🧁', ages:[7,17] },
  { id:'c34', cat:'books',   name:'Backpack and school supplies', price:65, icon:'🎒', ages:[4,18] },
  { id:'c35', cat:'books',   name:'Graphic novel bundle',     price:38,  icon:'💥', ages:[8,17] },

  { id:'c40', cat:'art',     name:'Art supply set',           price:48,  icon:'🎨', ages:[3,18] },
  { id:'c41', cat:'art',     name:'Sketchbook and markers',   price:30,  icon:'✏️', ages:[5,18] },
  { id:'c42', cat:'art',     name:'Beginner keyboard',        price:110, icon:'🎹', ages:[6,18] },
  { id:'c43', cat:'art',     name:'Ukulele',                  price:65,  icon:'🪕', ages:[6,18] },
  { id:'c44', cat:'art',     name:'Jewelry making kit',       price:32,  icon:'📿', ages:[6,15] },
  { id:'c45', cat:'art',     name:'Instant camera and film',  price:95,  icon:'📸', ages:[8,18] },

  { id:'c50', cat:'tech',    name:'Headphones',               price:60,  icon:'🎧', ages:[6,18] },
  { id:'c51', cat:'tech',    name:'Bluetooth speaker',        price:45,  icon:'🔊', ages:[8,18] },
  { id:'c52', cat:'tech',    name:'Game controller',          price:65,  icon:'🎮', ages:[7,18] },
  { id:'c53', cat:'tech',    name:'Tablet for schoolwork',    price:180, icon:'📱', ages:[6,18] },
  { id:'c54', cat:'tech',    name:'Beginner music production app + mic', price:90, icon:'🎙️', ages:[11,18] },

  { id:'c60', cat:'wheels',  name:'Bicycle',                  price:150, icon:'🚲', ages:[4,16] },
  { id:'c61', cat:'wheels',  name:'Bike helmet and lock',     price:45,  icon:'⛑️', ages:[4,18] },
  { id:'c62', cat:'wheels',  name:'Scooter',                  price:70,  icon:'🛴', ages:[4,13] },
  { id:'c63', cat:'wheels',  name:'Roller skates',            price:65,  icon:'🛼', ages:[6,17] },

  { id:'c70', cat:'room',    name:'Bedding set they picked',  price:70,  icon:'🛏️', ages:[1,18] },
  { id:'c71', cat:'room',    name:'Weighted blanket',         price:60,  icon:'🧸', ages:[4,18] },
  { id:'c72', cat:'room',    name:'Night light and lamp',     price:28,  icon:'💡', ages:[1,12] },
  { id:'c73', cat:'room',    name:'Storage bins and shelf',   price:55,  icon:'📦', ages:[2,18] },
  { id:'c74', cat:'room',    name:'Stuffed animal to keep',   price:25,  icon:'🐻', ages:[1,12] },

  { id:'c80', cat:'care',    name:'Skincare and hair basics', price:45,  icon:'🧴', ages:[10,18] },
  { id:'c81', cat:'care',    name:'Hair care for textured hair', price:55, icon:'💇', ages:[2,18] },
  { id:'c82', cat:'care',    name:'Barber or salon visit',    price:40,  icon:'✂️', ages:[2,18] },
  { id:'c83', cat:'care',    name:'Toiletry kit and towels',  price:35,  icon:'🧼', ages:[6,18] },

  { id:'c90', cat:'outings', name:'Zoo Atlanta family pass',  price:90,  icon:'🦁', ages:[1,14] },
  { id:'c91', cat:'outings', name:'Movie night out',          price:45,  icon:'🍿', ages:[3,18] },
  { id:'c92', cat:'outings', name:'Aquarium day',             price:110, icon:'🐠', ages:[1,16] },
  { id:'c93', cat:'outings', name:'Trampoline park with a friend', price:50, icon:'🤸', ages:[5,15] },
  { id:'c94', cat:'outings', name:'Braves game, two tickets', price:80,  icon:'⚾', ages:[5,18] },
  { id:'c95', cat:'outings', name:'Driver’s ed course',  price:350, icon:'🚗', ages:[15,18] },
];


/* Catalog ids with real photography in img/. Anything not listed falls back
   to the illustrated tile, which is why both treatments have to look deliberate. */
const HAS_PHOTO = new Set(['c01', 'c02', 'c03', 'c04', 'c05', 'c08', 'c10', 'c11', 'c12', 'c13', 'c14', 'c16', 'c17', 'c20', 'c21', 'c23', 'c24', 'c30', 'c32', 'c33', 'c40', 'c41', 'c42', 'c43', 'c44', 'c45', 'c50', 'c51', 'c52', 'c53', 'c54', 'c60', 'c61', 'c62', 'c70', 'c71', 'c72', 'c73', 'c74', 'c80', 'c82', 'c83', 'c90', 'c91', 'c92', 'c93', 'c94', 'c95']);
const photoFor = catId => HAS_PHOTO.has(catId) ? `img/${catId}.jpg` : null;

const catalogById = Object.fromEntries(CATALOG.map(c => [c.id, c]));
const catById = Object.fromEntries(CATEGORIES.map(c => [c.id, c]));

/* Households and children. Every display name is an alias the caregiver
   chose; the legal first name never leaves the caregiver's own screen. */
const HOUSEHOLDS = [
  { id:'h1', name:'The Brooks home',   area:'Clayton County',  caregiver:'Denise B.' },
  { id:'h2', name:'The Okafor home',   area:'DeKalb County',   caregiver:'Grace O.' },
  { id:'h3', name:'The Vance home',    area:'Cobb County',     caregiver:'Marcus V.' },
  { id:'h4', name:'The Delgado home',  area:'South Fulton',    caregiver:'Rosa D.' },
  { id:'h5', name:'The Whitfield home',area:'Gwinnett County', caregiver:'Tamika W.' },
  { id:'h6', name:'The Alvarez home',  area:'Henry County',    caregiver:'Carmen A.' },
  { id:'h7', name:'The Boateng home',  area:'Rockdale County', caregiver:'Kofi B.' },
  { id:'h8', name:'The Sinclair home', area:'Douglas County',  caregiver:'Renee S.' },
  { id:'h9', name:'The Tran home',     area:'North Fulton',    caregiver:'Mai T.' },
  { id:'h10',name:'The Whitaker home', area:'Clayton County',  caregiver:'Pam W.' },
];

/* A line is [catalogId, priceOverride, specificRequest, fundedBy, link].
   `spec` is how a caregiver names a brand or a detail: the line still groups
   under Hoodie, but it reads as "Nike, size L" and can be funded on its own. */
function kid(id, alias, age, gender, hh, interests, note, lines){
  return { id, alias, age, gender, hh, interests, note,
    items: lines.map((l, i) => {
      const c = catalogById[l[0]];
      return { id:`${id}-${i}`, catId:l[0], name:c.name, spec:l[2] || null, link:l[4] || null,
               price:l[1] || c.price, icon:c.icon, cat:c.cat,
               claimed:!!l[3], claimedBy:l[3] || null };
    }) };
}

const KIDS = [
  kid('k1','Maya',9,'girl','h1',['drawing','horses','anything sparkly'],
      'She draws on every napkin in the house. A real set of supplies would mean the world.',
      [['c40',null,null,'Priya S.'],['c02'],['c30'],['c74',null,null,'The Hollis family'],['c91']]),

  kid('k2','Theo',6,'boy','h1',['dinosaurs','trucks','being outside'],
      'He asks to go to the park every single day, rain or shine.',
      [['c11',null,null,'Piedmont Church youth group'],['c62',null,'Razor A5 Lo-Ride, blue','Anonymous','https://www.amazon.com/s?k=razor+a5+lo+ride+scooter'],
       ['c01'],['c31',null,null,'M. Okonkwo'],['c72',null,null,'Anonymous']]),

  kid('k3','Amari',14,'boy','h2',['basketball','sneakers','making beats'],
      'He has been teaching himself to produce music on a borrowed phone.',
      [['c54'],['c20'],['c02',85,'Basketball shoes, size 11',null,'https://www.amazon.com/s?k=basketball+shoes+size+11'],
       ['c50',null,null,'Kroger volunteer team'],['c04',null,'Nike, size L']]),

  kid('k4','Nia',12,'girl','h2',['reading','science','baking'],
      'She reads a book every two days and has started cooking dinner on Sundays.',
      [['c32'],['c33'],['c30'],['c34'],['c04'],['c50']]),

  kid('k5','Luca',3,'boy','h3',['trains','bubbles','his blue blanket'],
      'First placement. He is just starting to settle in and loves anything with wheels.',
      [['c12'],['c17',null,null,'The Nguyen family'],['c31'],['c06'],['c74']]),

  kid('k6','Selah',16,'girl','h3',['photography','thrifting','skincare'],
      'She is saving for a camera and takes photos of everyone at church on Sundays.',
      [['c45',null,'Instax Mini, any color',null,'https://www.amazon.com/s?k=fujifilm+instax+mini+camera'],['c80'],['c03'],['c82'],
       ['c94',null,null,'Anonymous'],['c50']]),

  kid('k7','Kai',8,'boy','h4',['Legos','swimming','space'],
      'He built a rocket out of cereal boxes last week. It took him four days.',
      [['c10'],['c23'],['c71'],['c04',null,null,'Anonymous'],['c60']]),

  kid('k8','Rosie',4,'girl','h4',['dress-up','unicorns','dancing'],
      'She has worn the same costume for three weeks straight.',
      [['c15'],['c13',null,null,'Delta ATL crew'],['c05',null,null,'The Reyes family'],
       ['c31',null,null,'Anonymous'],['c90',null,null,'Buckhead Rotary']]),

  kid('k9','Elena',11,'girl','h5',['soccer','her sketchbook','sleepovers'],
      'She made the school team and needs cleats before the season starts.',
      [['c21',null,'Size 6, any brand'],['c41'],['c70'],['c04'],['c60']]),

  kid('k10','Darius',17,'boy','h5',['cars','working out','graduating on time'],
      'He ages out in eleven months. Driving is the difference between a job and no job.',
      [['c95'],['c02'],['c83'],['c04']]),

  kid('k11','Jaylen',10,'boy','h6',['skateboarding','drawing','pizza'],
      'He redraws the same skate logo on everything he owns, including his math homework.',
      [['c24'],['c40',null,'Copic markers if possible',null,'https://www.amazon.com/s?k=copic+marker+set'],['c02'],['c01',null,null,'The Ferrell family'],['c04']]),

  kid('k12','Aria',5,'girl','h6',['unicorns','swimming','stickers'],
      'She has been in this home since March and finally asked for something for herself.',
      [['c15'],['c23'],['c90'],['c93',null,null,'Anonymous'],['c31']]),

  kid('k13','Micah',13,'boy','h7',['video games','football','sneakers'],
      'He plays with his younger brothers every night without being asked.',
      [['c02',95,'Air Force 1s, size 7',null,'https://www.amazon.com/s?k=nike+air+force+1+size+7'],['c52'],['c22'],['c03'],['c82',null,null,'Anonymous'],['c04']]),

  kid('k14','Zoe',15,'girl','h7',['fashion','doing nails','her playlists'],
      'She is the one who braids everyone else\'s hair before school.',
      [['c50'],['c80'],['c03',null,null,'Emory service group'],['c05'],['c44']]),

  kid('k15','Ruby',2,'girl','h8',['blocks','dogs','being carried'],
      'Placed with her two brothers in September. Everything in her room came from a donation bin.',
      [['c70'],['c74',null,null,'The Ferrell family'],['c31'],['c72'],['c01']]),

  kid('k16','Isaiah',7,'boy','h8',['space','Legos','running everywhere'],
      'He can name every planet in order and will do it unprompted.',
      [['c60'],['c34'],['c71'],['c82'],['c10',null,null,'Anonymous']]),

  kid('k17','Camila',9,'girl','h9',['soccer','art','her cousin'],
      'She switched schools twice this year and made the team anyway.',
      [['c21',null,'Size 4',null,'https://www.amazon.com/s?k=youth+soccer+cleats+size+4'],['c41'],['c43'],['c02'],['c22',null,null,'Buckhead Rotary']]),

  kid('k18','Owen',11,'boy','h9',['fishing','Minecraft','bikes'],
      'His caseworker says he has not asked for anything in two years.',
      [['c52'],['c35'],['c25'],['c34'],['c60']]),

  kid('k19','Tasha',16,'girl','h10',['cooking','college applications','thrifting'],
      'She is applying to four schools and doing all of it on a library computer.',
      [['c53'],['c95'],['c33'],['c80',null,null,'Anonymous'],['c04'],['c34']]),

  kid('k20','Malik',4,'boy','h10',['trucks','dinosaurs','bubbles'],
      'He is the loudest, happiest kid in the house and he has been here two weeks.',
      [['c11'],['c17'],['c74'],['c08'],['c16',null,null,'Delta ATL crew']]),
];

/* Donations that are not tied to a line. Kept separate so the donor can
   see them landing on real lists rather than disappearing into a fund. */
const FLEX_PRESETS = [25, 50, 100, 250];

const REASONS = [
  { icon:'fa-arrows-rotate', title:'Kids change fast, lists cannot keep up',
    body:'A coat that fit in October does not fit in January. Interests move on. The caregiver buys at the moment the child actually needs it, in the right size, in the color they want.' },
  { icon:'fa-hand-holding-heart', title:'The caregiver is the expert',
    body:'They know the sensory stuff, the sizes, what already came from a case worker, and what is sitting unopened in a closet. They wrote every line on this site, and leaving the final call with them is the point, not a shortcut.' },
  { icon:'fa-truck-fast', title:'No warehouse, no sorting weekend',
    body:'Physical gift drives cost a nonprofit storage, volunteers, drivers, and duplicates. Every dollar of that is a dollar that never reaches a child. This program runs on a spreadsheet and a payout.' },
  { icon:'fa-eye', title:'You still see where your gift went',
    body:'You chose the science kit on Nia\'s list. Your receipt names it, and in January you hear back from the household about what they were able to get. Nothing about your side of this changes.' },
];

/* The FAQ carries the part the shopping metaphor cannot: this is a donation,
   the org holds final discretion, and the child details come from caregivers. */
const FAQS = [
  { q:'Am I actually buying this gift?',
    a:`No. You are making a donation to Atlanta Angels in the amount of the gift you picked. We send that
       amount to the child's household so their caregiver can do the shopping. Nothing ships from us,
       no merchant is involved, and the tile you clicked is a wish a caregiver typed in, not inventory.` },

  { q:'So where does my money actually go?',
    a:`To Atlanta Angels, a 501(c)(3), as a charitable donation. We designate it to the household you chose
       and pay it out to that child's caregiver. As with any gift to a nonprofit, Atlanta Angels holds final
       discretion over how the funds are used, which is what the IRS requires in order for your gift to be
       deductible. In practice we honor your choice almost every time. When we cannot, because a child
       leaves the placement, a household withdraws, or a list closes early, the money moves to another
       child's list rather than back to you.` },

  { q:'Where does the information about each child come from?',
    a:`Their caregiver, directly. The age, the interests, the one-line note, and every gift on the list are
       typed in by the person raising that child. We confirm the placement with the agency or DFCS office and
       read each list before it goes live, but we do not write or embellish what a caregiver tells us. If
       something looks off, we call them. We work hard to keep what you see aligned with the child it
       describes, and we will not pretend to more certainty than that.` },

  { q:'How do you know the money is spent on the child?',
    a:`Caregivers agree in writing that designated funds are spent on the named child, and they upload
       receipts after they shop. We review them and follow up on the ones that do not come in. This is trust
       plus verification, not a locked card, and we would rather say so plainly than imply a control we do
       not have.` },

  { q:'What if the gift I funded is not what the child needs by December?',
    a:`Their caregiver buys what does fit. That is the entire reason this program sends money instead of
       merchandise. A coat that fit in October does not fit in January, an eight-year-old's favorite thing
       changes twice before Christmas, and the caregiver is the only person in the room who knows that.` },

  { q:'Five kids want the same thing. Am I funding all of them?',
    a:`Only the number you choose. Items that more than one child asked for are grouped, so a hoodie that
       four children want shows up once with four still needed. You pick a quantity, and each one you fund is
       assigned to a specific child and named on your receipt. When a caregiver asked for a particular brand
       or size, that request is listed separately so you can fund exactly that one.` },

  { q:'What happens if a list is not fully funded?',
    a:`The household receives what the list raised. We do not hold funds back waiting for a list to complete,
       and we do not quietly cancel the gifts nobody claimed. Lists that are still short as the deadline gets
       close are where general giving goes first.` },

  { q:'Is my gift tax deductible?',
    a:`Yes. Atlanta Angels is a registered 501(c)(3), and you will get an itemized receipt by email. No goods
       or services are provided to you in exchange, which is the other reason the money has to be a donation
       to us rather than a purchase from a family.` },

  { q:'What will I hear back?',
    a:`One email in January with what the household bought and a short note from them. You will never receive
       a photograph of a child, a last name, a school, or anything about a case. The names on this site are
       aliases each caregiver chose for exactly that reason.` },

  { q:'Why not just collect the actual gifts?',
    a:`Because that program costs a nonprofit storage, sorting volunteers, drivers, and a pile of duplicates,
       and it still hands a family the wrong size in a bag with a stranger's handwriting on it. Every hour
       and dollar of that comes out of the same donations. This way costs us a spreadsheet and a payout.` },
];

/* A landing-page headline per category. Generic labels make a category page
   feel like a filter; these make it feel like a place. */
const CAT_COPY = {
  clothes:'The clothes they actually need this winter',
  toys:   'Toys a caregiver picked out for one specific kid',
  sports: 'Everything it takes to play the season',
  books:  'Books, school supplies, and the stuff school assumes you have',
  art:    'For the kids who draw, build, and make noise',
  tech:   'The screens and sound a teenager asked for by name',
  wheels: 'Wheels, and the helmet that has to come with them',
  room:   'A room that feels like theirs',
  care:   'Getting ready in the morning without borrowing anything',
  outings:'A day out, not a thing to unwrap',
};
