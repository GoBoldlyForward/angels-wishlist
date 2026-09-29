# Wish List

A gift-list program that looks like shopping and settles like cash. Donors browse a catalog and
fund specific gifts for specific children. The money goes to the caregiver, who buys the gift in
the right size, in the right week, or buys what the child actually needs if the list has aged out.

The donor catalog is not a store. It is the union of every child's list, so a tile can only exist
because a caregiver put it there. What the donor experiences is a purchase. What actually happens
is a designated donation.

## The plan

- [`docs/build-plan.md`](docs/build-plan.md) is the plan: the program's rules, what is built, what
  has to change, the order of the remaining work, and the decisions Atlanta Angels still owes.
- [`docs/prototype.md`](docs/prototype.md) describes the prototype this is built from, screen by
  screen, and where it disagrees with itself.

The prototype lives on this repository's `prototype` branch and is published at
https://goboldlyforward.github.io/angels-wishlist/.

## Getting started

```
bin/setup
bin/rails db:seed
bin/dev
```

Without Stripe keys the app runs in test mode: a banner says so, checkout records the donation
without charging, and payouts are marked sent without moving money.

`bin/dev` runs the server and the Dart Sass watcher together, on port 3000 unless `PORT` is set
in the shell or in `.env`.

The seed builds the Atlanta chapter, its Passion City partner skin, one event dated around today,
and the twenty children across ten households that the prototype holds, with each list fitted to
the $200 cap. A small Nashville chapter with one open event gives the organization switcher
somewhere to go. Every seeded write runs as the user who would have made it, so the audit trail
reads as caregivers building lists, Sam verifying and approving, and donors giving.

Every seeded account signs in with `password123`. Set `SEED_PASSWORD` to choose another.

| Account | Role | What it reaches |
| --- | --- | --- |
| `admin@wishlist.example.org` | admin | `/admin` for any chapter |
| `regional@angels.example.org` | organizer | `/admin` for Atlanta and Nashville, the switcher case |
| `staff@atlantaangels.example.org` | organizer | `/admin` for Atlanta only |
| `serve@passioncity.example.org` | organizer | nothing yet: a partner's organizer has no staff pages |
| `denise.brooks@example.com` | caregiver | `/caregiver`, as does any other seeded caregiver |

### A second checkout

Two checkouts can run at once if each has its own port and database. `PORT` goes in `.env`, which
is the only file `bin/dev` reads. `DATABASE_URL` goes in `.env.development`, never `.env`: a
`DATABASE_URL` in `.env` reaches the test environment too, and `bin/rails test` would then load
fixtures over the development database. `.env.test` carries the matching test database.

## The three scopes

| Scope | Prefix | Who | What lives there |
| --- | --- | --- | --- |
| `Public` | none, or `/with/<partner>` | donors, unauthenticated | the storefront, categories, cart, checkout |
| `Caregiver` | `/caregiver` | the authenticated caregiver | their household, children, lists, payout |
| `Admin` | `/admin` | organizers and admins | verification, list review, the ledger, payouts, for the current organization |

An organizer can belong to several chapters. `organization_memberships` records which, the switcher
in the staff topbar picks one, and `current_organization` (held in the session) chooses the chapter
`/admin` works in. An admin reaches every chapter and partner without membership rows; agencies
place children and cannot have members.

The caregiver scope is named for the person, not the record, because `Household` is a model class
and a controller namespace of the same name collides with it.

## Modeling decisions

- **Organizations are one table.** Chapters, placing agencies, and co-branding partners share it,
  distinguished by `kind` and nested through `parent_id`. A partner-hosted drive is an organization
  with a theme. A partner skin changes who hosts the drive, never who holds the funds, so the
  Stripe account is looked up through the tree.
- **Events belong to an organization.** A chapter can run several drives a year or skip a year.
  Households persist across events; a wishlist is one child in one event.
- **Every person is a user.** Admins, organizers, caregivers, and donors share the table with one
  `role` each. A donor row created at checkout has no password, which is what lets guest giving
  and a returning donor share one row.
- **A line item is funded whole by one donation.** `donation_id` on `line_items` is what "funded"
  means. There is no funded flag and no funded-at column.
- **Review is a status on the record that owns the text.** Households carry a verification status,
  wishlists and line items carry review statuses, and a donor's note carries an approval timestamp.
  The staff Inbox is a query across those four, not a table of its own.
- **Nothing derived is stored.** Asked, raised, remaining, percent funded, funded-at, event phase,
  child age, amount charged, and who approved what are all computed. See the table below.

### Derived values

| Value | Source |
| --- | --- |
| Line item funded | `donation_id` present |
| Line item funded at | the donation's `created_at` |
| Wishlist asked / chosen / remaining | sums over its line items |
| Household asked / chosen | sums over its wishlists for the event |
| Event phase (draft, open, closed, paid out) | `opened_at`, `closes_at`, `payout_at` against now |
| Child age | `birthdate` |
| Donation charged | gift plus general gift plus fee |
| Fee covered | fee greater than zero |
| Event raised | gift plus general gift over succeeded donations |
| Event funded ratio | raised divided by what the counted lists ask, at most 1 |
| Wishlist share, household share | what was asked times the funded ratio |
| Who verified or approved | PaperTrail `whodunnit`, the acting user's id, resolved by `Version#actor` |

## Rules worth knowing

The full list is in [`docs/build-plan.md`](docs/build-plan.md). The ones that shape the code:

- A list asks for at most the event's cap per child, $200 in the seeds. A gift that would exceed
  it is invalid.
- Everything raised is one pool. Every counted list is funded to the same percentage, and a
  household's payout is the sum of its lists' shares. Which gifts donors chose changes the
  storefront's counters and the receipt, never a share.
- A list is public only when it is live, its event is open, and its household is verified. Every
  public page reads through `Wishlist.visible_to_donors`.
- A line item with a blank `spec` is pooled, and a donor funding that gift covers the oldest open
  one. A line with a spec gives that child their own line.
- A typed gift joins a catalog tile only on an unambiguous name match.
- A funded gift cannot be changed. A caregiver's change to a live list sends it back to
  `in_review`. PaperTrail records what changed.
- Donors never see a legal name, a birthdate, a household or caregiver name, an address, or
  anything about the case.

## Soft delete

Models that soft-delete declare `acts_as_paranoid` and carry a `deleted_at` column with an index.

`deleted_at` means gone. `archived_at` means hidden but still real. They are different states and
most models want both: a household that left the program is archived, a household created by
mistake is deleted.

## Deployment

Production runs on Heroku as `angels-wishlist` in the `goboldlyforward` team, on one Postgres
add-on. Solid Queue, Solid Cache, and Solid Cable share the primary database, so their tables live
in `db/schema.rb` like any other, and `SOLID_QUEUE_IN_PUMA=true` runs the job supervisor inside the
web dyno rather than paying for a worker. The `release` phase in the `Procfile` migrates on every
deploy.

The app is connected to this GitHub repository. Every merge to `main` deploys automatically once
CI passes; nothing else needs to be pushed to Heroku by hand.

```
heroku logs --tail -a angels-wishlist
heroku run bin/rails console -a angels-wishlist
```

## TODO before this runs anywhere real

- [ ] **Font Awesome.** Add the kit script and confirm the category icons render. The seeded
      `icon` values are Font Awesome class names carried over from the prototype.
- [ ] **Bootstrap.** Verify `app/assets/stylesheets/_tokens.scss` overrides land before Bootstrap's
      own variables, and replace the placeholder brand values with the real Angels palette. Check
      `--on-brand` contrast: Angels gold on white is 2.9:1 and fails.
- [ ] **S3.** Create the bucket and set `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`,
      and `AWS_BUCKET`. Production Active Storage already points at the `amazon` service.
- [ ] **Stripe.** Set `STRIPE_PUBLISHABLE_KEY`, `STRIPE_SECRET_KEY`, and `STRIPE_WEBHOOK_SECRET`.
      Payment Intents for donations, Connect for caregiver payouts.
- [ ] **Mail.** Choose a provider and a sending domain. Production has no outgoing mail settings.
- [ ] **Decisions.** Sixteen questions in the build plan are waiting on Atlanta Angels. The build
      follows a stated assumption for each.
- [ ] **Demo data.** The seeds replace every record and refuse to run in production unless
      `SEED_DEMO_DATA=yes` is set. Clear the demo data before real households arrive.
