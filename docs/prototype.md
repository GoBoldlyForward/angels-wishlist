# The prototype

What the Wish List prototype contains, side by side with where it disagrees with itself. This is
the reference the [build plan](build-plan.md) is written against.

- **Live:** https://goboldlyforward.github.io/angels-wishlist/
- **Source:** the `prototype` branch of this repository. It shares no history with `main`.
- **Described here:** commit `1e7c370`, which includes the changes Atlanta Angels asked for in
  September 2026.

The prototype's own `README.md` predates those changes. Where it and the code disagree, the code
is right. It still describes a $300 cap, caregiver receipts, a gift picker, and five intake steps.

## The idea

A gift program that looks like shopping and settles like cash. Donors browse a catalog and choose
gifts that children asked for. The money is a donation to Atlanta Angels, which pays caregivers,
who do the shopping.

The donor catalog is not a store. It is the union of every child's list, so a tile exists only
because a caregiver put that gift on a list. Browsing by gift and browsing by child are two views
of the same rows.

## Files

| File | What it is |
| --- | --- |
| `index.html`, `shop.js` | Donor home, product and child dialogs, cart, checkout, confirmation, FAQ |
| `index-passion.html` | The same home page in the Passion City Church skin |
| `category.html` | One landing page per category, `?c=<id>` |
| `caregiver.html`, `caregiver.js` | The six-step caregiver flow |
| `admin.html`, `admin.js`, `admin-data.js` | The staff side |
| `data.js` | Categories, catalog, households, children, lists, FAQ, and reasons |
| `wishlist.css`, `theme-angels.css`, `theme-passion.css` | Structure, then one brand layer per skin |
| `img/` | 48 product photos, credited in `img/ATTRIBUTION.md` |

## Seed data

Everything on all three sides derives from `data.js`. `admin-data.js` adds only what a donor must
never see.

| | Count | Notes |
| --- | --- | --- |
| Categories | 10 | clothes, toys, sports, books, art, tech, wheels, room, care, outings |
| Catalog items | 58 | $22 to $350. 48 have a photo, 10 fall back to an illustrated tile |
| Households | 10 | 8 verified, 1 pending, 1 on hold. 5 returning |
| Children and lists | 20 | two per household, ages 2 to 17 |
| Line items | 103 | 4 to 6 per child. 23 funded, 80 open |
| Lines naming a brand or size | 8 | the rest are pooled |
| Lines with a link | 6 | |
| Donors | 28 | 13 give anonymously. 18 individuals, 5 families, 5 groups |
| Donations | 34 | 31 succeeded, 1 pending, 1 disputed, 1 refunded |
| General gifts | 12 | $2,575 |
| Review queue rows | 39 | 14 need review, 3 flagged, 22 approved |

| Money | Amount |
| --- | --- |
| Asked across every list | $6,478 |
| Given toward named gifts | $1,180 |
| Given as general gifts | $2,575 |
| Refunded | $40 |
| Raised | $3,715, which is 57% of what was asked |

The staff side runs on a fixed clock: the season is Christmas 2026, it opened October 6, today is
November 18, lists close December 8, and payouts go out December 9.

**18 of the 20 seeded lists ask for more than $200**, from $151 to $730. They were written before
the cap came down.

## The donor side

### Home

1. **Header.** Logo, How it works, FAQ, For caregivers, and the cart with a count.
2. **Hero.** "Choose the types of gifts, situations, and families you want to fund."
3. **Season panel.** Raised of goal, a progress bar, "Closes December 8", gifts funded, children
   with lists, lists finished, and percent there. The goal is the sum of every line on every list.
4. **Four tabs.** Browse gifts, By child, Still unfunded, Give any amount.
5. **FAQ.** Ten questions.
6. **How it works.** Four reasons for cash over gifts, and five steps after checkout.
7. **Footer.** The privacy and tax-deductibility statement.

There is no search box and no sort control.

### Browsing

**Filters** are dropdown pills: who it is for (anyone, a girl, a boy), age (0 to 5, 6 to 9, 10 to
12, 13 to 18), price (under $25, $25 to $50, $50 to $100, $100 and up), and category. Choosing a
category on the home page opens that category's page.

**Editorial shelves** lead the Browse tab and step aside as soon as any filter is applied.

| Shelf | Rule |
| --- | --- |
| One gift from a finished list | children with exactly one gift left |
| Nobody has funded these yet | children with nothing funded |
| Everything under $40 | open gifts at $40 or less, grouped by product |
| Teenagers get skipped | children 13 and older with gifts left |
| New lists this week | newly submitted lists first, then the most recent seeded ones |

Below the shelves is one row of product tiles per category, open products first.

**By child** shows a card per child: alias, age, girl or boy, county, the first three interests, a
progress bar, and how many gifts are left.

**Still unfunded** shows every open gift grouped by product, most-needed first.

### One tile per product

Lines are grouped by catalog item. Five children asking for a hoodie is one hoodie tile that needs
five. Opening a tile shows two ways to give.

- **Fund one for any child who asked.** Lines with no brand or size form a pool. The donor picks a
  quantity with a stepper capped at what is left.
- **Fund a specific request.** Each line that names a brand or size is listed on its own with the
  child, the detail, the caregiver's link, and its own add button.

Both count down the same "needed" number on the tile. A gift sitting in someone's cart stops
counting as needed but does not count as funded.

### A child's page

Alias, age, girl or boy, county, every interest, the caregiver's one-sentence note, progress, and
every gift on the list with its price. Funded gifts show who funded them. One button funds
everything left on the list.

### Category pages

A headline written for the category, a count of what is still unfunded and how many children and
verified households it spans, the filters, the grouped grid, and links to the other categories.

The funding block offers a stepper to give a few gifts from the category and one button to **cover
the whole category**, both priced from what is open.

### Give any amount

Presets of $25, $50, $100, and $250, or a custom amount of $5 or more. It goes into the cart as
its own line.

### Cart and checkout

The cart is a drawer. Each gift is one line, and general gifts are their own lines. It persists
across pages.

Checkout collects three things:

| Field | Behavior |
| --- | --- |
| Your name, as the household should see it | Blank means the gift is anonymous |
| A short note for the family | Optional. Read by the caregiver |
| Cover card processing | Adds 3%. Checked by default |

It does not collect an email address or a payment method.

The confirmation names the amount, lists what was funded and for whom, echoes the note, and says
what happens next.

### Partner skins

A theme sets color, type, button shape, and avatar swatches. Markup and scripts do not know which
brand is active. The Passion page differs from the Angels page in its title, its header line
("Passion City Church", then "Wish List · with Atlanta Angels"), an empty logo slot, and a footer
naming Atlanta Angels as the 501(c)(3) receiving the money.

Angels gold and Passion cyan both fail contrast against white text. Each pairs with a dark text
color through the `--on-brand` token.

## The caregiver side

A landing page, six steps, and a confirmation. The landing page badge reads "For approved foster
and kinship caregivers."

| Step | Asks for | Continue when |
| --- | --- | --- |
| 1. Your home | Name, email, mobile number, county, home address, city, ZIP | name, email, and county are filled |
| 2. The children | First name, age (0 to 18), girl or boy, interests, one sentence for donors | every child has a first name, age, and gender |
| 3. Love Box | One pick from each of eleven groups | every group has a pick, and a count when cups are chosen |
| 4. Their lists | Per child: gift name, approximate price, optional link | every child has at least one gift and is at or under the cap |
| 5. Getting paid | Bank or debit card through Stripe, or a mailed Visa gift card. The spending agreement | a method is set and the agreement is checked |
| 6. Review | Nothing new. Shows each child as donors will see them, the Love Box, and the payout method | submitted |

**Counties offered:** Clayton, Cobb, DeKalb, Douglas, Fulton, Gwinnett, Henry, Rockdale, and South
Fulton.

**Aliases are assigned by the system** from a fixed pool of twenty names. The caregiver sees the
alias beside the first-name field and is never asked to invent one.

**The cap is $200 per child and it is hard.** A gift that would put the list over is refused with
a note saying how much room is left. The minimum price is $5.

**A typed gift tries to join a catalog product.** It joins only when exactly one catalog name
matches. Otherwise it becomes its own line. The flow has no catalog picker and no field for brand
or size.

**The spending agreement** reads: "By accepting these funds, I agree to use them for holiday gifts
for the child each list is for. If something on a list no longer fits or is no longer wanted, I
will spend that money on what that child actually needs."

### The Love Box

Every household receives a holiday Love Box from Atlanta Angels volunteers, delivered with the
holiday visit. It is separate from the gift funds.

| Group | Picks | Options |
| --- | --- | --- |
| Holiday celebrated | 1 | Christmas, Hanukkah, Kwanzaa, Winter themed |
| Festive cups | 1, with a count | One holiday mug per caregiver, Holiday plastic cups for each member of the family, No thank you |
| Family drink | 1 | Hot chocolate, Apple cider, No thank you |
| Family snack | up to 2 | Microwave popcorn, Boxed candy, No thank you |
| Family treat | 1, or 2 for more than five children | Gingerbread house, Decorate-a-cookie kit, No thank you |
| Family game | 1, or 2 for more than five children | Uno, Taco Cat Goat Cheese, Herd Mentality, Tapple, Taboo, Throw Throw Burrito, Sushi Go!, No thank you |
| Family activity | 1 | Two coloring books, word search book, puzzle, two craft kits, No thank you |
| Holiday or winter themed book | 1 | The Snowy Day, Santa Mouse, The Polar Express, The Night Before Christmas, No thank you |
| $25 grocery gift card | 1 | Walmart, Target, Publix, ALDI, Trader Joe's |
| Cozy item | 1 | Holiday blanket, Holiday candle, No thank you |
| Love Box container | 1 | Cloth, or Cardboard ready to decorate |

### After submitting

The confirmation says Atlanta Angels is confirming the household, usually within a day, and lays
out four dates: donors fund until December 8, the household's share is sent December 9, the
caregiver shops whenever works, and in January the caregiver writes a short note back.

A help link offers a phone number to build the lists with a coordinator.

## The staff side

An overview and six indexes. All six share one table engine: tabs with counts, search, filters,
sort on every column, row selection, pagination at 25 per page, and a detail drawer.

| Group | Index | One row is | Tabs |
| --- | --- | --- | --- |
| Families | Households | one home | All, Verified, Pending, On hold, No payout method, Returning |
| Families | Wishlists | one child | All, Live, Still short, Fully funded, In review, On hold |
| Families | Line items | one gift one child asked for | All, Open, Funded, Brand or size, In the pool, Needs review |
| Funding | Donors | one giver | All, Individuals, Families, Groups & teams, Anonymous, Gave more than once |
| Funding | Donations | one card charge | All, Succeeded, Pending, Disputed, Refunded, General giving |
| Inbox | Submissions | one thing somebody typed | Needs review, Flagged, From caregivers, From donors, Donor visible, All |

### Overview

Five figures: raised, gifts funded, wishlists finished, households, and days left. Three panels
follow.

- **Needs your attention.** Households that cannot be paid and why, flagged submissions,
  submissions awaiting a decision, lists with nothing funded, and disputed or pending charges.
- **Furthest behind.** The six live lists with the lowest percent funded.
- **Where the open lines are.** Open line counts by category.

### What each drawer holds

| Index | Sections | Actions |
| --- | --- | --- |
| Households | Contact, Verification, Payout, Children, and a hold reason when present | Message the caregiver, Mark verified, Hold payout |
| Wishlists | The wishlist, What a donor sees, Still open, Privacy | Open the wishlist, Message the caregiver, Direct general giving here |
| Line items | The gift, Who it is for, Funding | Edit line, Move to another child, Withdraw |
| Donors | This season, What they funded, Charges, and a callout for anonymous donors | Resend receipt, January note list, Merge duplicate |
| Donations | The charge, Donor, Designated gifts, General giving, What this is | Resend receipt, Refund, Open in Stripe |
| Submissions | What they submitted, Details, Staff note | Approve, Reply, Flag for a call |

Header buttons across the indexes: Export CSV, Add household, New wishlist, Add a line, Add donor,
Export for accounting, Record an offline gift, and Approve all clear.

### Statuses

| Record | Values |
| --- | --- |
| Household verification | verified, pending, on hold |
| Payout method | direct deposit, mailed gift card, not set up |
| Payout status | scheduled, no method, blocked, on hold |
| Wishlist | live, in review, fully funded, on hold |
| Line item | open, funded, needs review, withdrawn |
| Donation | succeeded, pending, refunded, disputed |
| Submission | needs review, approved, flagged |

A household on hold is never paid. One with no payout method is next. One still pending
verification is blocked. Everything else is scheduled.

A line needs review when its price is above the catalog price for that product.

### Submissions

Everything a caregiver, donor, or agency typed that is not a gift or a dollar. Visibility is fixed
by type.

| Publishes to the donor site | Never leaves the admin |
| --- | --- |
| Child profile | Payout details |
| Custom gift request | Address change |
| Gift detail | New household |
| List edit | Agency verification |
| Note to the family | Message to staff |
| Display name | Donor question |

The seeded queue includes hard calls on purpose: a donor note asking for a photo, a child profile
that mentions a caseworker, a payout account changed four days before a placement change, a price
raised on a gift that was already funded, and a donor note disclosing the donor was once in care.

### Staff-only facts

Caregiver email and phone, preferred language, placing agency, verification state and date,
payout method and destination, hold reason, the real name and email behind an anonymous gift, and
the charge ledger.

## What is simulated

- **Payments.** No card is collected and nothing is charged. Funded state lasts until reload.
- **Stripe onboarding.** A mock dialog with a sample bank account and debit card.
- **Email and text.** Receipts, confirmations, and texts are promised and never sent.
- **Verification.** Statuses are seeded. No agency is contacted.
- **Every staff action.** Navigation, tabs, search, filters, sort, and drawers work. Every button
  that would change a record does nothing.
- **Close and payout.** Nothing totals, spreads, or pays. No payout record exists.
- **Staff accounts.** One hard-coded staff user with access to everything.
- **The handoff.** Submitted lists are saved in the browser and appear on the donor side marked
  New and on the staff side in review. The payout method, the Love Box, the spending agreement,
  and the caregiver's contact details are not saved.

## Where the prototype disagrees with itself

The donor FAQ and the caregiver flow carry Atlanta Angels' September changes. The staff side and
parts of the donor checkout do not. The build plan resolves each of these.

| Topic | One place says | Another place says |
| --- | --- | --- |
| Where money goes | Donor FAQ, How it works, product dialog, general giving: everything is pooled and spread evenly across every child's list | Donor checkout: "Recorded, not pooled" and "sends the funds to that verified household". Confirmation: "on its way toward Maya's list" |
| Payout amount | Caregiver flow: "your household's share of everything raised" | Staff household drawer: the amount is what that household's own lists raised |
| General giving | General giving panel: same pool, spread evenly | Same panel's intro: "the households with the furthest-behind lists". Cart and checkout: "closest-to-complete lists". Staff: "Direct general giving here" |
| The cap | Caregiver flow: $200, hard | Staff: $300, with an over-the-cap flag on 11 lists. Seed data: 18 lists over $200 |
| What donors hear back | FAQ and How it works: a thank-you and an impact statement in January | Checkout confirmation: "one email in January with a note back from the household". Caregiver confirmation: the caregiver writes that note |
| Receipts by email | FAQ and confirmation: an itemized receipt is in your inbox | Checkout never asks for an email address |
| Who picks the alias | Caregiver flow: the system assigns it | Donor footer, FAQ, and By child tab: "aliases chosen by each caregiver" |
| Last names | Donor footer: no last names are published | Child dialog shows "The Brooks home". Checkout shows "paid to Denise B." |
| Pooled gifts | Product dialog: applied to "the child who has been waiting longest" | The code takes children in list order, newest submissions first. Staff line drawer: "whichever child is furthest behind" |
| Brand or size | Donor side lists specific requests separately | Caregiver flow has no field to enter one |
| Text messages | Caregiver flow: "We text you when your lists are funded" and "a text each time a line is claimed" | Nothing sends or schedules a text |
| Partner skin | The Passion home page is fully skinned | Category pages and the checkout redirect drop a Passion visitor into the Angels skin |
| Love Box | Caregiver flow collects eleven choices per household | The staff side never mentions it |
