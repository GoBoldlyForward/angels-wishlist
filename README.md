# Wish List

A gift-list program that looks like shopping and settles like cash. Donors browse a catalog and
fund specific gifts for specific children. The money goes to the caregiver, who buys the gift in
the right size, in the right week, or buys what the child actually needs if the list has aged out.

The donor catalog is not a store. It is the union of every child's list, so a tile can only exist
because a caregiver put it there. What the donor experiences is a purchase. What actually happens
is a designated donation.

Built from the prototype in `_prototypes/angels-wishlist` and the database plan in that repo's
`docs/build-plan.md`.

## Getting started

```
bin/setup
bin/rails db:seed
bin/dev
```

`bin/dev` runs the server and the Dart Sass watcher together. The seed builds one chapter, one
partner skin, one event dated around today, and the twenty children across ten households that the
prototype holds. Sign in as `staff@atlantaangels.example.org` with `password123`; every seeded
caregiver uses the same password. Every seeded write runs as the user who would have made it, so
the audit trail reads as caregivers building lists, Sam verifying and approving, and donors giving.

## The three scopes

| Scope | Prefix | Who | What lives there |
| --- | --- | --- | --- |
| `Public` | none | donors, unauthenticated | the storefront, categories, cart, checkout |
| `Caregiver` | `/caregiver` | the authenticated caregiver | their household, children, lists, payout |
| `Admin` | `/admin` | staff | verification, list review, the ledger, payouts |

The caregiver scope is named for the person, not the record, because `Household` is a model class
and a controller namespace of the same name collides with it.

## Modeling decisions

- **Organizations are one table.** Chapters, placing agencies, and co-branding partners share it,
  distinguished by `kind` and nested through `parent_id`. A partner-hosted drive is an organization
  with a theme. A partner skin changes who hosts the drive, never who holds the funds, so the
  Stripe account is looked up through the tree.
- **Events belong to an organization.** A chapter can run several drives a year or skip a year.
  Households persist across events; a wishlist is one child in one event.
- **Every person is a user.** Staff, caregivers, and donors share the table with a `role`. A donor
  row created at checkout has no password, which is what lets guest giving and a returning donor
  share one row.
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
| Wishlist asked / raised / remaining | sums over its line items |
| Household asked / raised | sums over its wishlists for the event |
| Event phase (draft, open, closed, paid out) | `opened_at`, `closes_at`, `payout_at` against now |
| Child age | `birthdate` |
| Donation charged | gift plus general gift plus fee |
| Fee covered | fee greater than zero |
| Payout default | the household's raised total for that event |
| Payout overridden | amount differs from raised |
| Unapplied general giving | the event's pool minus what top-ups have spent |
| Who verified or approved | PaperTrail `whodunnit`, the acting user's id, resolved by `Version#actor` |

## Rules worth knowing

- Editing a live wishlist sends it back to `in_review`. PaperTrail records what changed.
- A line item with a blank `spec` is pooled, and any donor funding that gift can cover it. A line
  with a spec gives that child their own line.
- A typed gift joins a catalog tile only on an unambiguous name match, because a wrong guess puts
  one child's request inside another product's counter.
- A list may exceed the per-child cap. The caregiver flow warns and lets them continue.
- A payout defaults to what the household's lists raised. Staff may override it with a note saying
  why, and general giving is the pool those overrides draw on.
- Donors never see a legal name, a photograph, a size, a school, an address, or anything about the
  case. Those columns live on households and children and are never serialized to the storefront.

## Soft delete

Models that soft-delete declare `acts_as_paranoid` and carry a `deleted_at` column with an index.

`deleted_at` means gone. `archived_at` means hidden but still real. They are different states and
most models want both: a household that left the program is archived, a household created by
mistake is deleted.

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
- [ ] **Heroku.** Create the app, add Postgres, and note that Rails 8 puts Solid Queue, Solid Cache,
      and Solid Cable on separate databases. Either provision them or point all four at the primary.
- [ ] **Donor-facing copy.** The prototype promises a January note back to donors and says general
      giving goes to the furthest-behind lists automatically. Neither is true under this plan.
      Both are Christie's call before anything is rewritten.
