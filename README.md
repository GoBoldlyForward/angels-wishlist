# Atlanta Angels · Wish List

A gift-list program that looks like shopping and settles like cash. Donors browse a catalog and
fund specific gifts for specific children. The money goes to the caregiver, who buys the gift in
the right size, in the right week, or buys what the child actually needs if the list has aged out.

Open `index.html` by double clicking it. No server needed.
Registered as `angels-wishlist` on port 5201.

Files: `index.html` (donor home, checkout, FAQ), `index-passion.html` (the same home page in a
partner skin), `category.html?c=<id>` (one landing page per category), `caregiver.html` (the
five-step caregiver flow), `admin.html` (the staff side), `theme-*.css` (brand layers), and
`img/` (product photography).

## The admin

`admin.html` is the third side of this: the room where Atlanta Angels staff actually run the
program. Six record indexes plus an overview, sharing one table engine so search, tabs, filters,
column sort, bulk select, pagination, and the detail drawer are written once rather than six times.

The nav groups by what each record belongs to, widest unit first, because a household holds
children, a child holds a wishlist, and a wishlist holds line items:

| Group | Index | The grain | What staff do here |
| --- | --- | --- | --- |
| Families | **Households** | one home | verification, contact, payout method, payout hold |
| Families | **Wishlists** | one child | see who is furthest behind and aim general giving |
| Families | **Line items** | one gift one child asked for | the atomic row the whole program settles on |
| Funding | **Donors** | one giver | receipts, anonymity, who gave to whom |
| Funding | **Donations** | one card charge | the ledger, fees, refunds, disputes |
| Inbox | **Submissions** | one thing somebody typed | the review queue for text, not gifts or dollars |

Submissions sits on its own because it carries both sides: a caregiver's note about a child and a
donor's note to the family land in the same queue.

Layout, tokens, and components come from `_templates/admin:records#index.html`, so this reads as the
same product as every other admin in the portfolio.

**Nothing is invented twice.** Every row is derived from `data.js`: a line exists because a caregiver
put it on a list, a donor exists because a line says who funded it, a charge exists because a donor
funded something, and a household rollup is the sum of its children's lists. The season goal is the
sum of every list, which is exactly how the donor home page computes it. Keeping one source means the
two sides cannot quietly disagree about the same season.

`admin-data.js` adds only what genuinely does not exist on the donor side and never could: caregiver
email and phone, the placing agency, verification state, payout destination, the real name behind an
anonymous gift, and the charge ledger. That split is the point. Everything a donor must not see lives
in one file that the donor pages do not load.

**Submissions is the index worth arguing about.** It holds everything a caregiver or a donor typed
that is not a gift and not a dollar: child profiles, brand and size details, custom gift requests,
list edits, payout changes, agency letters, donor notes to the family, anonymity requests, and
checkout questions. Each row carries a **Visibility** column, because whether a piece of text
publishes to the wish list site or never leaves the admin is a real decision staff make row by row,
and burying it in a footnote is how the wrong sentence ends up in front of a donor.

The seeded queue is deliberately uncomfortable in a few places. A donor note asks for a photo of a
child, which is the one thing this program never sends. A child profile mentions a caseworker, which
is case detail rather than who the child is. A household changed its payout account four days before
a reported placement change. Each one is flagged with a staff note saying what the call is, because
an inbox that only contains clean rows teaches nobody how the job actually goes.

**The caregiver flow lands here.** Submitting lists in `caregiver.html` writes them to `localStorage`,
and the admin reads the same key the donor site does. A submitted household shows up as pending
verification with no payout method, its lists sit in review, its lines are flagged, and a **New
household** row hits the top of the submissions queue. Same handoff, two audiences.

**The demo clock is fixed.** `SEASON.today` is November 18, 2026, twenty days before lists close, so
the admin always opens on a program mid-flight instead of an empty pre-launch one. Charge ids, dates,
card brands, and the identities behind anonymous gifts are seeded from a deterministic PRNG, so every
reload shows the same program and a screenshot stays true.

**What is faked:** the charge ledger, card brands, Stripe payout destinations, agency verification,
staff accounts, and every action button in the drawer. **What is real:** every line, list, child,
household, price, and funder, because all of it comes from `data.js`.

## Two experiences

```
caregiver.html                         index.html
  your home                              browse gifts, by child,
  the children (name, age, gender)       still unfunded, give any amount
  their lists  (name, price, link)             ↓
  getting paid (Stripe, or gift card)      cart → review → give
  review and submit ──────────────────→  the lists a donor shops
```

Intake is deliberately short. It asks for a household, a first name and age per
child, and then gifts as free text with a price and an optional link. It does
**not** ask for the agency, the case manager, clothing sizes, or a stand-in
name: the alias is assigned by the system, so a caregiver is never asked to
invent one for a child in their care.

A typed gift still tries to land on a catalog product. Type "Hoodie" and it
joins the eight-child hoodie group with its photo; type something the catalog
has no clear match for and it becomes its own line with a gift icon. Only an
unambiguous match counts, because a wrong guess would put one child's request
inside another product's counter.

Submitting a list on the caregiver side writes it to `localStorage`, so it shows up in the donor
view marked **New**. That is the whole loop in one prototype. To reset the demo, run
`localStorage.removeItem('aa_submitted_kids')` in the console, or use a private window.

## One tile per product, not per child

Five children asking for a hoodie is one hoodie tile that needs five. The donor sees `4 needed`
on the tile, opens it, and chooses a quantity with a stepper capped at what is actually left. Each
one they fund is assigned to a specific child and named on the receipt, so aggregation happens in
the browsing layer and never in the accounting.

Grouping keys on the catalog id, which is what makes the generic and the specific coexist:

```
Hoodie · 5 asked for
  ├─ Nike, size L · Amari, 14      ← its own line, funded on its own
  ├─ (no detail) · Nia, 12         ┐
  ├─ (no detail) · Elena, 11       ├─ the pool: "fund one for any child who asked"
  ├─ (no detail) · Darius, 17      ┘
  └─ funded already · Kai, 8
```

Fund the Nike line and the tile drops to three needed. Fund two from the pool and it drops to one.
Same counter either way, which is the behaviour a donor expects and the reason the two kinds of
request cannot live in separate tiles.

On the caregiver side this is one optional field under each gift they pick: *brand, size, or color?*
Leaving it blank puts the gift in the pool, which funds faster. Filling it in gives the child their
own line. The form says exactly that, because it is a real tradeoff the caregiver should get to make.

## The donor home

Three things carry the page beyond a plain grid.

**Editorial shelves before categories.** Same rows, sliced the way a person would pitch them:
*One gift from a finished list*, *Nobody has funded these yet*, *Everything under $40*,
*Teenagers get skipped*, *New lists this week*. Categories follow underneath. Apply any filter and
the shelves step aside, because a filtered shelf is just a grid wearing a hat.

**One season goal instead of a stat row.** Raised of goal, gifts funded, lists finished, percent
there, and the deadline. It turns an abstraction into a finish line.

**Motion.** Photos zoom on hover, the add button throws confetti, the cart bumps, and sections rise
as they enter view.

Three details in there are load bearing, and each one is a bug I shipped first and then fixed:

- The progress bar's real width is in the markup and the grow is a `transform`. The first version
  set the width from `requestAnimationFrame`, which is throttled to a standstill in a background
  tab, so the bar could render at 0% — wrong information, not a missing flourish.
- The reveal animation is **visible by default**. An element is only hidden once JS has taken
  responsibility for it, with a 1.4s failsafe. Hidden-by-default meant a stuck observer left a
  blank page.
- The confetti fires from the **click coordinates**, in the bubble phase, registered *after* the
  cart handler. Measuring the button gives zeros (adding re-renders the grid and detaches it) and
  registering first reads a stale cart, so it fired one click behind.

## Theming for partners

The stylesheet is split so a partner skin is a one-line swap:

```
wishlist.css        structure, layout, components, behaviour. No brand values.
theme-angels.css    Atlanta Angels: gold, Work Sans, soft pills
theme-passion.css   Passion City Church: cyan, system grotesque, hard pills
```

Every page loads `wishlist.css` plus exactly one theme. A theme sets colour
(`--brand`, `--on-brand`, `--accent`, ink and paper), type (`--font-sans`,
`--h1-weight` / `--h1-tracking` / `--h1-leading`), shape (`--r`, `--btn-radius`,
`--btn-weight`, `--btn-transform`, `--btn-tracking`), and the avatar swatches
`--av-1..6`. Neither the markup nor the JS knows which brand is active: avatar
colours and confetti read the theme at runtime instead of carrying a palette.

`--on-brand` is the token that matters most. Some brand colours carry white and
some carry ink, and getting it wrong is how a re-skin ends up illegible: Angels
gold with white text is 2.9:1 and Passion cyan with white is 2.4:1. Both pair
with a dark value instead, at 5.5:1 and 7.0:1.

**index-passion.html** is the same home page under `theme-passion.css`. Values
came from passioncitychurch.com as published on 2026-08-19, while their full
site is in a limited state and serving a system font stack rather than a
licensed brand face. Treat the type as provisional and confirm it; it is one
variable. The header keeps an empty logo slot for their real asset, because
inventing a church's mark is not a thing to do in a prototype.

The co-brand line is deliberate. Funds still go to Atlanta Angels, so the header
reads *Wish List · with Atlanta Angels* and the footer names the 501(c)(3)
receiving the money. A partner skin changes who hosts the drive, never who holds
the funds.

## Design system

Everything comes from tokens, and nothing sets a font size inline.

**Type.** An eight-step scale (`--fs-2xs` 11.5 through `--fs-2xl` 28) with `.t-*`
utilities. The page went from 23 distinct computed sizes to 12, and the
remaining outliers are the clamped display headline and the emoji in an
illustrated tile.

**Spacing and radius.** `--s1` through `--s8`, three radii plus a pill.

**Contrast.** Body text is 8.9:1. `--soft` was 4.3:1 and was darkened to clear
AA at 5.2:1, with `--faint` moving to match. Focus rings use a themed `--ring`
on every interactive element.

**Accessibility.** Product tiles and child cards are keyboard operable
(`role="button"`, Enter and Space). The per-gift tiles deliberately are not,
because they contain a real button and nesting one inside `role="button"` is
invalid; that list is reachable from the By child tab. Both overlays are
`role="dialog" aria-modal="true"`, take focus on open, and hand it back on
close. Product photos carry the gift name as alt text.

## Category landing pages

`category.html?c=sports` is a real page, not a filter. It gets its own headline, a count of what is
still unfunded and how many verified households it spans, the age/gender/price pills, the grouped
grid, and a row of the other categories. The thing that makes it worth a page is the funding block:
a stepper for *give a couple of gifts in here* and a single button for **Cover the whole category**,
priced live off what is actually still open.

Because the cart now spans two pages it lives in `localStorage`, and checking out from a category
page hands off to `index.html?checkout=1` with the cart intact.

## Product photography

`img/` holds 48 CC-licensed photos pulled through the Openverse API and resized, one per catalog id,
credited in `img/ATTRIBUTION.md`. Ten gifts had no usable free photo and fall back to the illustrated
tile, so both treatments are styled to look deliberate rather than broken.

Two rules shaped the picks. **No photographs of children** — on a foster care site a stock kid reads
as one of the actual children, which is exactly the confusion the alias system exists to prevent. And
**the subject has to be the product**, which killed a lot of otherwise nice lifestyle shots.

This is prototype-grade imagery. Before it goes in front of donors, replace it with photography
Atlanta Angels owns or licenses, and note that a few files are BY-SA, which carries share-alike terms
you do not want on a fundraising page.

## The load-bearing idea

The donor catalog is not a store. It is the union of every child's list, so a tile can only exist
because a caregiver put it there. Browse-by-category and browse-by-child are two views of the same
rows, which is what keeps "shopping" honest: there is no inventory, and nothing is for sale.

What the donor experiences is a purchase. What actually happens is a designated donation. The
prototype never hides the second part. It appears at the tile, in the cart, on the child's page,
at checkout, and in the confirmation, in plain language rather than a footnote.

## Why cash instead of items

Four reasons, and the site says all four out loud in the **How it works** section:

| | |
| --- | --- |
| Kids change fast | A coat that fit in October does not fit in January |
| The caregiver is the expert | Sizes, sensory needs, what a case worker already delivered |
| No warehouse | Physical drives cost storage, sorters, drivers, and duplicates |
| Donors keep the visibility | You picked the skateboard, you get the receipt for the skateboard |

The tag-on-a-tree model puts the work on the donor *and* the operational lift on the nonprofit,
and still delivers the wrong size. This model removes both and improves the outcome, which is why
it is worth the one thing it costs: explaining itself.

## Payout, and why Stripe is the recommendation

The caregiver picks between Stripe Connect and a mailed Visa gift card, and the tradeoffs are
stated rather than implied. Bank or debit lands in one to two days, works anywhere, and cannot be
lost in the mail. A gift card takes seven to ten days, gets rejected by some online checkouts, and
is gone if it is stolen. The gift card exists because unbanked caregivers exist, not because it is
a real second-best. The Stripe screen in the prototype is a simulation of Stripe's own hosted
onboarding, which is where the identity and account details would actually live.

## What the site does and does not claim

Three things are said plainly and often: every family is **verified by Atlanta Angels**, every gift
was **added by a caregiver for a specific child**, and funds go to the household. A trust strip under
the hero carries all three.

What the site deliberately stops short of is promising that your $65 buys that particular coat for
that particular child. It cannot: the money is a donation to Atlanta Angels, and the org holds final
discretion, which is the condition of it being deductible. So the verbs are *recorded against*,
*directed to*, *goes toward*, never *buys*. The one place that gets spelled out in full is the FAQ.
Everywhere else it is simply not overclaimed, which is a copy discipline rather than a disclaimer.

## The FAQ is not decoration

The bottom of the donor homepage carries ten questions, and the first two do the heavy lifting:
you are not buying anything, and your money is a donation to Atlanta Angels, which holds final
discretion over how it is used. That sentence is not hedging, it is the condition of the gift being
tax deductible, and burying it would make the rest of the site dishonest. The third question says
plainly that every detail about a child comes from their caregiver, that Angels verifies the
placement and reads the lists, and that this is alignment rather than certainty.

The FAQ also answers the things a nonprofit is tempted to leave vague: what happens to an underfunded
list, how spending is actually verified (receipts and follow-up, not a locked card), and what a donor
hears back.

## Privacy

Donors see an alias, an age, girl or boy, a county, the interests the caregiver typed, and one
sentence about the child. They never see a legal name, a photograph, a size, a school, an address,
or anything about the case. Sizes are not collected at all: a caregiver names a size only when they
want one specific gift bought a specific way, as free text on that single line. The review step shows
the caregiver exactly what a donor will and will not see, in the caregiver's own words about their
own child.

## What is real and what is faked

Real: the full donor browse, filter, cart, checkout, and confirmation; product grouping with
quantity funding and brand-specific lines; the full caregiver flow across five steps including the
picker, per-gift detail field, and per-child totals; the handoff between the two sides.

Faked: payments, Stripe onboarding, agency verification, email and text, and the seeded twenty
children across ten households. Prices are plausible metro-Atlanta numbers, not researched ones.

## Open questions for Atlanta Angels

1. **The cap.** The caregiver side suggests $300 per child and lets a list go over. Is that the
   right number, and should over-cap lists be allowed at all?
2. **Receipts.** The flow promises caregivers upload receipts. Is that enforced, spot-checked,
   or dropped? It is the main accountability lever and also the main friction.
3. **Partial funding.** The FAQ currently states that a household receives whatever its list
   raised, and that general giving goes to the furthest-behind lists first. Confirm that is the
   real policy before this copy goes anywhere near a donor.
4. **What the donor hears back.** The prototype promises one note in January with no child photos.
   That is a real operational commitment for a small staff.
5. **Aging-out lists.** Darius, 17, has a $700 list because driver's ed is on it. Big-ticket
   practical items may deserve their own lane rather than competing with toys.
