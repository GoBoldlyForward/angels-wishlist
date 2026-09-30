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
| 1. Bring the foundation in line with the prototype | Built |
| 2. Staff setup: organizations, events, categories, catalog | Built |
| 3. Caregiver intake | Built |
| 4. Staff review | Built |
| 5. Donor storefront and checkout | Built. Runs in test mode until Stripe keys are set |
| 6. Close and payouts | Built. Transfers run in test mode until Stripe keys are set |
| 7. Communications | Written. Nothing is sent until a mail provider is set |
| 8. Multiple chapters on Stripe Connect | Built. Chapter accounts, destination charges, and account debits run in test mode until Stripe keys are set |

**Deployed:** Heroku app `angels-wishlist`, deploying from `main` after CI passes.

### What is switched off until it is configured

| Needs | Until then |
| --- | --- |
| `STRIPE_SECRET_KEY` and `STRIPE_WEBHOOK_SECRET` | A banner says test mode. Checkout records the donation without charging. Caregiver onboarding and transfers succeed at once without moving money |
| `SMTP_ADDRESS`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `MAIL_FROM` | Every message is skipped and logged. Password reset emails do not arrive |
| An S3 bucket and its credentials | Catalog items show the photos bundled with the app. Uploading a photo or a logo fails |
| `CAREGIVER_HELP_PHONE` | The caregiver help dialog says to call a coordinator but gives no number |

### Where the build departs from this plan

- **Caregivers choose a password at the start of intake.** The plan calls for an emailed link,
  which needs a mail provider. Once mail works, password reset covers returning caregivers.
- **Checkout uses Stripe's hosted payment page**, so no card field touches this application. It
  creates the Payment Intent the plan describes.
- **Staff detail views are pages**, where the prototype slides a drawer over the index.

## Rules of the program

These come from the prototype as Atlanta Angels left it. Each is a requirement.

### Money coming in

- A gift is a **donation to Atlanta Angels designated to the holiday wish list program**. It is
  not a purchase. Copy says *goes toward*, *shows on your receipt*, never *buys*.
- A donor chooses gifts from lists, gives a general amount, or both. One checkout is one donation.
- A line is funded whole, once, by one donation. Funding drives the storefront's counters and the
  donor's receipt. It does not decide what any household is paid.
- A general gift is $5 or more.
- Covering the fees is checked by default. It adds what card processing and the platform fee
  take, so the whole gift reaches the families. The fee is stored apart from the gift.
- A refunded or disputed donation leaves the pool, and its lines return to open.

### Money going out

- **Everything raised is pooled and spread evenly.** The pool is every succeeded donation's gift
  and general gift for the event, less whatever of card processing and the platform fee its donor
  did not cover.
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
| 12 | How much is the fee a donor may cover? | Whatever lets the whole gift reach the families after card processing and the platform fee. It is worked out from the gift, not a flat 3% |
| 13 | Where does a partner's storefront live? | At its own path on the same site, skinned throughout, checkout included |
| 14 | Do the Love Box choices change each year? | Yes. They are set per event and staff can edit them |
| 15 | Is there more than one kind of staff? | Two. Admins (us) reach every chapter. Organizers reach the chapters they are members of and can do everything inside them |
| 16 | Whose product photographs? | The prototype's are placeholders. Atlanta Angels supplies or licenses replacements before launch |
| 17 | How does a visitor reach a chapter? | By hostname. Each chapter has its own domain or subdomain. A partner storefront stays at `/with/<partner>` under its chapter's host |
| 18 | Where does our platform fee come from? | Out of each donation, together with card processing, as Stripe's application fee. A donor who covers the fees pays both. When a donor does not, both come out of that gift before it joins the pool |
| 19 | What is the platform fee? | A percentage of each gift, stored on the chapter so it can differ per chapter. Each donation records the fee it was charged |
| 20 | Which Stripe account type does a chapter get? | Express, with card payments and transfers, onboarded as a nonprofit. Account debits need the platform to carry the account's losses, which Express does |
| 21 | Is the catalog shared across chapters? | No. Each chapter has its own categories and catalog, copied from a starter set when the chapter is created |
| 22 | Can one person staff two chapters? | Yes. An organizer's memberships list their chapters, and a switcher picks the one they are working in. Donors and caregivers are not tied to a chapter |

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

### Changed: smaller additions

- `enrollments.intake_step`: the furthest intake step a caregiver has reached.
- `catalog_items.stock_photo`: a photo bundled with the app, shown until one is uploaded.
- `donations.cart` (jsonb): the gifts a donor chose, held until the payment settles.
- `wishlists.review_note`: why staff returned a list to the caregiver.
- `payouts.method` may be empty, for a household with no payout method.

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

The models follow the rules above. A gift that would exceed the cap is invalid. The pool is
spread by `Event#shares`, and a payout is a household's share. `Enrollment` holds the spending
agreement and the Love Box. `Wishlist.visible_to_donors` is the one scope every public page reads
through. A funded line is locked, and a caregiver's change to a live list returns it to review.

The seeds fit every list to the $200 cap. The prototype's own data does not, so `db/seeds.rb`
keeps funded gifts, then gifts naming a brand or size, then the least expensive.

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

### 8. Multiple chapters on Stripe Connect

The application serves any number of chapters. Each chapter runs its own events, families,
storefront, catalog, and staff, and links its own Stripe account. We take a platform fee on every
gift.

#### How money moves

Donations land in the chapter's own Stripe balance. The platform only touches money in passing.

| When | What happens in Stripe |
| --- | --- |
| A donor checks out | A **destination charge** to the chapter's Express account, `on_behalf_of` the chapter. The chapter is on the donor's statement and receipt. The application fee is card processing plus the platform fee |
| A payout is sent | An **account debit** pulls the household's share from the chapter's balance to the platform, and a transfer sends it to the caregiver's Express account |
| After payouts | Chapter staff send the rest of the balance to the chapter's bank. It holds the gift card households' shares, which the chapter buys itself, and any surplus |

Caregivers' accounts stay connected to the platform. Stripe does not let a connected account have
connected accounts of its own, and a transfer to a caregiver can only come from the platform's
balance. That is what the account debit is for. Each caregiver's account is tied to a chapter
through the household, and carries the chapter in its Stripe metadata.

Each donation records its platform fee and its card processing. Processing is estimated at the
platform's rate, 2.9% plus 30¢, when the donation is created. The pool is every succeeded gift,
less whatever of those two fees the donor did not cover.

What this commits us to:

- **Chapter accounts pay out manually.** The balance has to be there on payout day, because a
  debit cannot take an account below zero. The staff funds page shows what is held back for
  unsent payouts and sends the rest to the bank.
- **Every chapter signs consent to account debits.** Stripe charges extra for each one.
- **Stripe charges processing to the platform** on a destination charge. The application fee
  covers it. A card that costs more than 2.9% plus 30¢ costs the platform the difference.
- **A refund reverses the chapter's transfer and returns the application fee.** It fails when the
  chapter's balance cannot cover it, and staff see Stripe's reason.

#### Tenancy

- **Resolve the chapter on every request.** Public and caregiver pages find it by hostname, and a
  host no chapter claims falls back to the oldest chapter. Admin pages use the chapter the
  signed-in organizer or admin has switched to.
- **Every admin lookup starts from the chapter.** Payouts, donations, organizations, categories,
  catalog items, and the audit trail all narrow to it.
- **Partners and agencies stay under their chapter** through `parent_id`. A partner's storefront
  is found among its chapter's partners.
- **Caregivers start intake at their chapter's host.** A household belongs to the chapter it
  enrolled with.
- **Donors are shared.** One donor row can give to any chapter. Receipts, the January statement,
  and the admin donor list are per chapter.
- **Nothing says "Atlanta Angels" in code.** Name, legal name, EIN, sending address, logo, and
  theme come from the chapter.

#### Roles

| Who | Signs in as | Reaches |
| --- | --- | --- |
| Donor | a donor, or not at all | their chapter's storefront |
| Caregiver | a caregiver | their household at the chapter they are on |
| Organizer | `role: organizer` with memberships | everything inside the chapters they belong to, and adding organizers to them |
| Admin | `role: admin` | every chapter, and creating chapters |

Organizers and admins switch chapters from the staff topbar. The chapter they are working in is
held in the session.

#### Chapter onboarding

1. A platform administrator creates the chapter, its hostname, and its fee rate. Its categories
   and catalog are copied from the oldest chapter.
2. Organizers are added from the chapter's Staff page and choose a password from an emailed link.
3. An organizer completes Stripe's hosted onboarding for an Express account, as the nonprofit.
4. Returning from Stripe, and every `account.updated` webhook, records whether the account can
   take charges.
5. The storefront refuses checkout until it can.

#### Schema

- `organizations`: `hostname` (unique), `legal_name`, `ein`, `mail_from`,
  `platform_fee_basis_points`, `stripe_charges_enabled`. `stripe_account_id` already exists.
- `categories` and `catalog_items`: `organization_id`.
- `donations`: `platform_fee_in_cents`, `processing_fee_in_cents`.
- `payouts`: `stripe_debit_id`, so a retried payout never debits twice.
- `versions`: `organization_id`, so the audit trail filters to a chapter.
- A Connect webhook endpoint beside the existing one, with its own signing secret.

#### Order of work

| Part | Done when |
| --- | --- |
| a. Tenancy | Two chapters on two hosts each run a season, and a test walks the admin as each chapter's organizer and never reaches the other chapter's records |
| b. Chapter branding | Nothing in `app/` names Atlanta Angels, and each chapter's storefront, emails, and receipt carry its own name and EIN |
| c. Chapter Stripe onboarding | A chapter reaches charges enabled through hosted onboarding, and checkout is refused before then |
| d. Destination charges | A donation goes to the chapter's account with the application fee, and the pool is net of what the donor did not cover |
| e. Payouts by account debit | A Stripe payout debits the chapter once and transfers once, even when retried |
| f. Chapter funds | Staff see the chapter's balance, what is held for unsent payouts, and send the rest to the bank |

## Before launch

- [ ] Stripe keys, webhook secret, and a Connect platform account. A caregiver counts as connected once Stripe
      reports its onboarding form finished, checked when they return to the payout step
- [ ] S3 bucket and credentials
- [ ] A mail provider and a sending domain
- [ ] Font Awesome kit
- [ ] Brand tokens checked for contrast. Angels gold with white text is 2.9:1 and fails
- [ ] Product photography Atlanta Angels owns or licenses
- [ ] A real staff administrator in production. The seeds create demo accounts with a known
      password and must not run there
- [ ] Every decision above answered
- [ ] Account debits enabled on the platform, and each chapter's signed consent to them
- [ ] `STRIPE_CONNECT_WEBHOOK_SECRET` for the Connect webhook endpoint
- [ ] A hostname and TLS certificate for each chapter
