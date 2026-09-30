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

### Signing in as each role

Everyone signs in at http://localhost:3000/users/sign_in and lands on their own home page. The
username is the email. Every seeded account's password is `password123`, unless `SEED_PASSWORD`
was set when the seed ran.

| Role | URL | Username | Password | What it reaches |
| --- | --- | --- | --- | --- |
| Donor | http://localhost:3000/ | none | none | The Atlanta storefront. Donors give as guests and never sign in |
| Donor, partner storefront | http://localhost:3000/with/passion-city-church | none | none | The same drive in the Passion City skin |
| Donor, second chapter | http://nashville.localhost:3000/ | none | none | The Nashville storefront, chosen by hostname |
| Caregiver | http://localhost:3000/caregiver | `denise.brooks@example.com` | `password123` | Their household, children, lists, and payout. Any other seeded caregiver works the same way |
| Organizer, one chapter | http://localhost:3000/admin | `staff@atlantaangels.example.org` | `password123` | Staff pages for Atlanta only |
| Organizer, two chapters | http://localhost:3000/admin | `regional@angels.example.org` | `password123` | Staff pages for Atlanta and Nashville, the switcher case |
| Organizer, Nashville | http://localhost:3000/admin | `staff@nashvilleangels.example.org` | `password123` | Staff pages for Nashville only |
| Organizer, partner | http://localhost:3000/admin | `serve@passioncity.example.org` | `password123` | Nothing yet: a partner's organizer has no staff pages and is sent back to the storefront |
| Admin | http://localhost:3000/admin | `admin@wishlist.example.org` | `password123` | Staff pages for any chapter, plus chapter setup |

To get the same sign-ins in an environment that was not seeded, paste this into `bin/rails console`
there (`heroku run bin/rails console -a angels-wishlist` for production). It deletes nothing and
can be run again: it creates the admin, an organizer on the oldest chapter, and a caregiver with no
household yet, who lands in intake. Running it again resets those three passwords. Change
`password` before pasting it anywhere real.

```ruby
password = "password123"

accounts = [
  { email: "admin@wishlist.example.org", role: "admin", first_name: "Ada", last_name: "Byrne" },
  { email: "staff@atlantaangels.example.org", role: "organizer", first_name: "Sam", last_name: "Reed" },
  { email: "denise.brooks@example.com", role: "caregiver", first_name: "Denise", last_name: "Brooks" }
]

users = accounts.map do |attributes|
  user = User.find_or_initialize_by(email: attributes[:email])
  user.update!(attributes.merge(password: password))
  user
end

chapter = Organization.chapter.order(:id).first
organizer = users.find(&:organizer?)
OrganizationMembership.find_or_create_by!(user: organizer, organization: chapter) if chapter

host = ENV.fetch("APP_HOST", "localhost:3000")
users.each do |user|
  path = user.caregiver? ? "/caregiver" : "/admin"
  puts "#{user.role.ljust(10)} #{user.email.ljust(34)} #{password}  #{host}#{path}"
end
puts "No chapter exists yet, so the organizer has no staff pages. Sign in as the admin and add one." unless chapter
```

The other caregivers are `grace.okafor`, `marcus.vance`, `rosa.delgado`, `tamika.whitfield`,
`carmen.alvarez`, `kofi.boateng`, `renee.sinclair`, `mai.tran`, and `pam.whitaker`, each
`@example.com`. Renee's household is still awaiting verification and Pam's is on hold, which makes
them the accounts to use for those two states.

### A second checkout

Two checkouts can run at once if each has its own port and database. `PORT` goes in `.env`, which
is the only file `bin/dev` reads. `DATABASE_URL` goes in `.env.development`, never `.env`: a
`DATABASE_URL` in `.env` reaches the test environment too, and `bin/rails test` would then load
fixtures over the development database. `.env.test` carries the matching test database.

## Configuration

Every key the app reads comes from the environment. Locally they go in `.env`, copied from
`.env.example`; on Heroku they are config vars. Nothing is read from Rails credentials except
`secret_key_base`.

| Variable | Needed | What it is for | When it is missing |
| --- | --- | --- | --- |
| `RAILS_MASTER_KEY` or `SECRET_KEY_BASE` | production | Signs sessions and Devise tokens. The master key decrypts `config/credentials.yml.enc` | Production does not boot |
| `DATABASE_URL` | production | Postgres. Heroku sets it | Development and test use the databases named in `config/database.yml` |
| `APP_HOST` | production | The host in links inside emails, such as password resets | Links point at `localhost:3000` |
| `STRIPE_SECRET_KEY` | live money | Every call to Stripe: checkout, refunds, chapter and caregiver onboarding, account debits, transfers, chapter balances and bank payouts | Test mode: a banner says so, checkout records the donation without charging, and onboarding and payouts succeed at once without moving money |
| `STRIPE_WEBHOOK_SECRET` | live money | Verifies the platform's own events at `/stripe/webhooks`: checkouts, refunds, disputes | Webhooks are refused, so a donor who closes the tab after paying is not recorded until they return |
| `STRIPE_CONNECT_WEBHOOK_SECRET` | live money | Verifies connected accounts' events at the same URL. `account.updated` is what turns a chapter's donations on | A chapter's account is only rechecked when an organizer returns from Stripe onboarding |
| `SMTP_ADDRESS`, `SMTP_USERNAME`, `SMTP_PASSWORD` | sending mail | The mail provider. `SMTP_PORT` defaults to 587 | Production skips and logs every message, password resets included |
| `MAIL_FROM` | sending mail | The default sender, such as `Wish List <wishlist@example.org>`. A chapter with its own verified address sends as that instead | Mail comes from `wishlist@example.org` |
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | uploads | Active Storage on S3, for catalog photos and logos. `AWS_REGION` defaults to `us-east-1` and `AWS_BUCKET` to `angels-wishlist`, with the environment name appended | Catalog items show their bundled photos, and uploading a photo or logo fails |
| `CAREGIVER_HELP_PHONE` | optional | The number caregivers are told to call for help with their lists | The help panel says to call their coordinator, with no number |
| `PINPOINT_EMBED_URL` | optional | The Pinpoint feedback widget | No widget |
| `CORS_ORIGINS` | optional | Comma-separated origins allowed to call `/api` | None |
| `SEED_PASSWORD` | optional | The password every seeded account gets | `password123` |
| `SEED_DEMO_DATA` | production seeding | Must be `yes` for `db:seed` to run in production, since it replaces every record | The seed refuses to run |
| `PORT`, `RAILS_MAX_THREADS`, `WEB_CONCURRENCY`, `JOB_CONCURRENCY`, `SOLID_QUEUE_IN_PUMA`, `RAILS_LOG_LEVEL` | optional | Server tuning. Defaults: port 3000, 3 threads, one job process, `info` logs | The defaults |

`STRIPE_PUBLISHABLE_KEY` is not read. Checkout and onboarding both use Stripe's hosted pages, so
no key reaches the browser.

Stripe needs more than keys before live money moves: a Connect platform account with account
debits enabled, and each chapter's signed consent to account debits. Point both webhook endpoints,
the platform's and Connect's, at `https://<host>/stripe/webhooks`. The Connect endpoint needs
`account.updated`. The platform endpoint needs `checkout.session.completed`,
`checkout.session.async_payment_succeeded`, `checkout.session.async_payment_failed`,
`checkout.session.expired`, `charge.refunded`, and `charge.dispute.created`.

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
- [ ] **Stripe.** Set `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, and
      `STRIPE_CONNECT_WEBHOOK_SECRET`, enable account debits, and register both webhook endpoints.
      See [Configuration](#configuration).
- [ ] **Mail.** Choose a provider and a sending domain, then set `SMTP_ADDRESS`, `SMTP_USERNAME`,
      `SMTP_PASSWORD`, `MAIL_FROM`, and `APP_HOST`.
- [ ] **Decisions.** Sixteen questions in the build plan are waiting on Atlanta Angels. The build
      follows a stated assumption for each.
- [ ] **Demo data.** The seeds replace every record and refuse to run in production unless
      `SEED_DEMO_DATA=yes` is set. Clear the demo data before real households arrive.
