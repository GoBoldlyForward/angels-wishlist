# Wish List · Build plan

The plan for turning the Wish List prototype into this Rails application. It states the program's
rules, what is built, what has to change, and the order of the remaining work.

[The prototype](prototype.md) is the companion reference. It inventories every screen and lists
where the prototype disagrees with itself.

**This is the only current plan.** Two earlier ones exist outside this repository: a September
2026 `docs/build-plan.md` on an unmerged branch of the prototype, and a phased plan in
`~/code/_buildplans/angels-wishlist`. Both were written before Atlanta Angels' September changes
and both describe rules the program no longer follows. Neither should be built from.

## Where things stand

| Step | State |
| --- | --- |
| Foundation: schema, models, seeds, tests, deploy | Built |
| 1. Bring the foundation in line with the prototype | Not started |
| 2. Staff setup: organizations, events, categories, catalog | Not started |
| 3. Caregiver intake | Not started |
| 4. Staff review | Not started |
| 5. Donor storefront and checkout | Not started |
| 6. Close and payouts | Not started |
| 7. Communications | Not started |

**Built:** all twelve program tables, their models and derived values, seeds generated from the
prototype's data, model tests, Devise, Ahoy, PaperTrail, Active Storage, rate limits, and three
authenticated scopes that each render one placeholder page.

**Deployed:** Heroku app `angels-wishlist`, deploying from `main` after CI passes. The production
database is empty and has no Stripe or S3 credentials.

## Rules of the program

These come from the prototype as Atlanta Angels left it. Each is a requirement.

### Money coming in

- A gift is a **donation to Atlanta Angels designated to the holiday wish list program**. It is
  not a purchase. Copy says *goes toward*, *shows on your receipt*, never *buys*.
- A donor chooses gifts from lists, gives a general amount, or both. One checkout is one donation.
- A line is funded whole, once, by one donation. Funding drives the storefront's counters and the
  donor's receipt. It does not decide what any household is paid.
- A general gift is $5 or more.
- Covering card processing adds 3% and is checked by default. The fee is stored apart from the
  gift.
- A refunded or disputed donation leaves the pool, and its lines return to open.

### Money going out

- **Everything raised is pooled and spread evenly.** The pool is every succeeded donation's gift
  and general gift for the event. Fees are not part of it.
- **Every list is funded to the same percentage.** That percentage is the pool divided by the
  total asked across every live list of a verified household, and never more than 100%.
- A household's share is the sum of its children's list shares.
- A list that is withdrawn, or whose household leaves, drops out of the total. Its share moves to
  the other lists.
- A household is paid by direct deposit through Stripe or by a mailed Visa gift card.
- A household on hold, unverified, or without a payout method is not paid.

If every child asks for $200 and donors give 75% of the total asked, every list receives $150.

### Lists

- **A list may ask for at most $200 per child.** A gift that would exceed it is refused.
- A gift has a name, a price of $5 or more, and an optional link.
- A typed gift joins a catalog product only when exactly one catalog name matches. Otherwise it
  is a line of its own.
- A line with no brand or size is pooled. A donor funding that product covers the oldest open
  pooled line. A line that names a brand or size is funded on its own.
- A caregiver may edit a list until the event closes. Any edit to a live list returns it to
  review. A funded line cannot be edited.

### Households

- Staff verify a household before any of its lists go live.
- The caregiver agrees to spend the funds on holiday gifts for the child each list is for.
- Every household customizes one Love Box per event. It is separate from the gift funds.
- Caregivers are not asked for receipts.

### What donors can see

A donor sees a child's alias, age, girl or boy, county, interests, the caregiver's one-sentence
note, and the gifts with their prices, details, and links.

A donor never sees a legal name, a birthdate, a photograph, a school, an address, a household or
caregiver name, the placing agency, the Love Box, or any payout detail.

- Aliases are assigned by the system and unique among the organization's active children.
- A list is public only when it is live, its event is open, and its household is verified.
- Anonymity is a display rule. An anonymous donor still has a full record for the receipt.
- Public pages render a fixed set of fields. A new column cannot reach a donor by being added.

## Decisions needed

The prototype leaves these open or contradicts itself on them. The build proceeds on the
assumption in the last column until Atlanta Angels says otherwise.

| # | Question | The build assumes |
| --- | --- | --- |
| 1 | What are the real open, close, and payout dates? | The prototype's: October 6, December 8, December 9 |
| 2 | May staff change a household's share? | No. The amount is always the computed share. Staff may hold a payout |
| 3 | What if donors give more than every list asked for? | Lists stop at 100%. The surplus stays with Atlanta Angels |
| 4 | What do donors receive in January, and from whom? | One thank-you and impact statement from Atlanta Angels. Caregivers are not asked to write a note |
| 5 | Who receives a donor's note to the family? | The households whose gifts that donor chose, after staff approve it. A general gift carries no note |
| 6 | May donors see a household name or a caregiver's name? | No. Donors see the county |
| 7 | Do caregivers get text messages? | No. Email only, and the copy stops promising texts |
| 8 | Who may start intake? | Anyone with the link. Nothing is public until staff verify the household |
| 9 | Age or birthdate at intake? | Birthdate, seen by staff only. Donors see the age computed from it |
| 10 | Can a caregiver name a brand or size? | Not at intake. Staff add the detail when a caregiver asks |
| 11 | What does the staff Inbox hold? | Households to verify, lists to review, lines to review, donor notes to approve. Messages, donor questions, and agency letters stay in email |
| 12 | Is the fee 3%? | Yes |
| 13 | Where does a partner's storefront live? | At its own path on the same site, skinned throughout, checkout included |
| 14 | Do the Love Box choices change each year? | Yes. They are set per event and staff can edit them |
| 15 | Is there more than one kind of staff? | No. Any staff administrator can do everything |
| 16 | Whose product photographs? | The prototype's are placeholders. Atlanta Angels supplies or licenses replacements before launch |

## Schema

The twelve program tables are built as the models describe them: organizations, addresses, users,
events, households, children, wishlists, categories, catalog items, line items, donations, and
payouts.

Three changes follow from the rules above.

### New: enrollments

One row per household per event. It holds what a household commits to for one season.

- household_id → households
- event_id → events
- spending_agreed_at
- love_box (jsonb: one entry per group, each with its picks and a count where the group asks)
- submitted_at
- created_at, updated_at

Unique on household and event. Audited with PaperTrail.

### Changed: events

- `love_box_options` (jsonb): the groups a caregiver chooses from, each with a label, its options,
  how many picks it allows, and whether the second pick is only for more than five children.
- `per_child_cap_in_cents` is seeded at $200.

### Unchanged but reinterpreted: payouts

`amount_in_cents` holds the household's computed share. `adjustment_note` stays in the table and
is unused until decision 2 is answered.

## Derived values

Computed on the model, never stored.

| Value | Source |
| --- | --- |
| Line item funded | `donation_id` present |
| Wishlist asked | sum of its line items |
| Wishlist chosen by donors | sum of its funded line items |
| Event pool | gift plus general gift over succeeded donations |
| Event asked | sum of asked over live lists of verified households |
| Event funded ratio | pool divided by asked, at most 1 |
| Wishlist share | its asked times the event's funded ratio |
| Household share | sum of its wishlists' shares for the event |
| Wishlist at cap | asked equals the event's cap |
| Event phase | `opened_at`, `closes_at`, `payout_at` against now |
| Child age | `birthdate` |
| Donation charged | gift plus general gift plus fee |
| Returning caregiver | the household has a wishlist on an earlier event |
| Who verified or approved | PaperTrail `whodunnit` |
| Staff Inbox | pending households, lists in review, lines needing review, unapproved donor notes |

Shares are computed in whole cents and rounded down. Leftover cents go to the lists with the
largest remainders so the shares add up to the pool.

## The work

### 1. Bring the foundation in line with the prototype

The models were written against the earlier rules. Correct them before anything is built on top.

| Area | Now | Change to |
| --- | --- | --- |
| Cap | `Wishlist#over_cap?` flags a list and allows it. Seeded at $300 | A line that would put its list over the cap is invalid. Seeded at $200 |
| Payout amount | Defaults to what the household's own lists raised | The household's share of the pool |
| General giving | `Event` tracks a pool that staff overrides draw on | Part of the one pool. Remove the top-up methods |
| Payout override | A differing amount requires a note | No override. See decision 2 |
| Visibility | `Wishlist#shoppable?` checks the list and the event | Also requires a verified, active household |
| Edits to a live list | A changed note or interest returns it to review | A changed, added, or removed line does too |
| Funded lines | Editable | Locked once funded |
| Enrollment | No table | Add it, with the spending agreement and the Love Box |
| Love Box options | None | Seed the eleven groups from the prototype onto the event |
| Aliases | Set by whoever creates the child | Assigned from a name pool, unique among active children |
| Seeds | 18 of 20 lists exceed $200 | Trim each list to fit |

**Done when** the model tests cover the cap, the funded ratio, a withdrawn list leaving the total,
rounding that sums to the pool, and a list from an unverified household staying private.

### 2. Staff setup

Staff create what a season needs before any caregiver arrives.

- **Organizations.** The chapter, its placing agencies, and its partners. A partner has a theme,
  a logo, and a co-brand line.
- **Events.** Name, dates, cap, and Love Box options.
- **Categories.** Name, icon, tint, headline, blurb, position.
- **Catalog items.** Name, price, age range, category, photo and its attribution, active.

Build the shared index here, since steps 4 and 6 reuse it: tabs with counts, search, filters,
sort, pagination, and a detail view.

**Done when** staff can set up an event from an empty database without the seeds.

### 3. Caregiver intake

The six steps in the prototype, saved as the caregiver goes so they can return.

| Step | Writes |
| --- | --- |
| Your home | the caregiver's user, the household, its address and county |
| The children | each child, an assigned alias, and a draft wishlist holding interests and the note |
| Love Box | the enrollment's choices |
| Their lists | line items, matched to the catalog where one name fits |
| Getting paid | the payout method, a Stripe Connect account or a mailing address, and the agreement |
| Review | submits every list for review |

- Starting intake creates the caregiver with no password. An emailed link lets them set one and
  come back.
- A caregiver reaches only their own household.
- Stripe's hosted onboarding collects identity and account details. None of it touches this
  application.
- The review step shows each child exactly as a donor will see them.
- After submitting, the caregiver's dashboard shows each list's status and lets them edit until
  the event closes.

**Not in the prototype, and required:** saving progress between visits, signing back in, and
the dashboard after submission.

**Done when** a caregiver can complete intake on a phone, leave halfway, return by email link,
and submit. A list over the cap cannot be submitted.

### 4. Staff review

The six indexes and the overview from the prototype, on the index built in step 2.

| Index | Staff can |
| --- | --- |
| Households | verify, place on hold with a reason, record the placing agency, add a household |
| Wishlists | approve, return to the caregiver, withdraw |
| Line items | edit, add a brand or size, withdraw, approve a price above the catalog's |
| Donors | see the name behind an anonymous gift, resend a receipt |
| Donations | see the ledger, refund, record an offline gift |
| Inbox | work the four queues in decision 11 |

- The overview shows raised, percent funded, gifts chosen, lists live, households, days left, and
  what needs attention.
- Every index exports to CSV.
- **Love Box packing list.** One page per event: each household's choices, and a total per item
  for the volunteers who assemble the boxes.

**Not carried over from the prototype:** the over-the-cap flag, "Direct general giving here",
"Furthest behind" as a place to aim money, and "January note list". Each belongs to a rule the
program dropped.

**Not in the prototype, and required:** the Love Box packing list, and an audit view of who
verified and approved what.

**Done when** a submitted household can be verified and its lists approved, and those lists then
appear to donors.

### 5. Donor storefront and checkout

- **Home.** Season panel, editorial shelves, category rows, By child, Still unfunded, Give any
  amount, FAQ, and How it works.
- **Category pages.** Headline, counts, filters, grouped grid, and the funding block.
- **Product and child views.** Pooled and specific lines under one product, with one shared count.
- **Cart.** Held in the session and carried across pages.
- **Checkout.** Email, display name, note, and the fee, then payment through Stripe.
- **Partner storefronts.** Every page, checkout included, in the partner's skin.

Rules specific to this step:

- Checkout **requires an email address**. It creates or finds the donor's user.
- Funding a line locks the row first. When two donors reach for the same line, one succeeds and
  the other is told before being charged.
- The donation is recorded from Stripe's webhook, so closing the tab after paying still produces
  it. Receiving the same webhook twice produces one donation.
- A donor's note is held until staff approve it.

Copy to correct while building, all from the contradictions in the prototype reference:

| Where | Replace |
| --- | --- |
| Checkout panel | "Recorded, not pooled" and "sends the funds to that verified household" |
| Checkout groups | the household name and "paid to" the caregiver |
| Confirmation | "on its way toward Maya's list" and "a note back from the household" |
| General giving, cart, checkout | "furthest-behind lists" and "closest-to-complete lists" |
| Footer, FAQ, By child | "aliases chosen by each caregiver" |
| Product dialog | "the child who has been waiting longest", unless the oldest open line is what is funded |

**Done when** a donor can fund gifts across two households plus a general gift in one checkout
with a Stripe test card, and receives one receipt.

### 6. Close and payouts

- When the event closes, create one payout per enrolled household for its share.
- Staff review the run before anything is sent: each household's asked, share, method, and
  whether it is blocked and why.
- Send through Stripe Connect, or record a mailed gift card with its tracking number.
- A blocked payout stays blocked until its household is verified, off hold, and has a method.
- A failed transfer is marked and can be retried.

**Done when** the payouts for an event add up to its pool, to the cent.

### 7. Communications

| Message | To | Sent when |
| --- | --- | --- |
| Set your password | caregiver | intake begins |
| Lists received | caregiver | lists are submitted |
| Household verified, lists live | caregiver | staff approve |
| List returned | caregiver | staff return a list with a reason |
| Receipt | donor | the donation succeeds |
| Payout sent | caregiver | the transfer or gift card goes out |
| Thank-you and impact statement | every donor to the event | staff send it in January |

The receipt is itemized and carries the required language: Atlanta Angels is a 501(c)(3), the
gift is a tax-deductible donation designated to the holiday wish list program, and no goods or
services were provided in return.

Production has no mail provider configured. Choosing one is part of this step.

## Before launch

- [ ] Stripe keys, webhook secret, and a Connect platform account
- [ ] S3 bucket and credentials
- [ ] A mail provider and a sending domain
- [ ] Font Awesome kit
- [ ] Brand tokens checked for contrast. Angels gold with white text is 2.9:1 and fails
- [ ] Product photography Atlanta Angels owns or licenses
- [ ] A real staff administrator in production. The seeds create demo accounts with a known
      password and must not run there
- [ ] Every decision above answered
