# frozen_string_literal: true

# Seeds the program the prototype describes: one chapter, one partner skin, one
# event, and the twenty children across ten households that donor-side data.js
# already holds. db/seeds/prototype.json is generated from that file, so the two
# cannot drift. The prototype's lists run past the cap, so each is fitted to it.
#
# Each write runs as the user who would have made it, so the versions table
# carries the same trail a real program would: caregivers build households and
# lists, Sam verifies and approves, donors give.

require "json"

if Rails.env.production? && ENV["SEED_DEMO_DATA"] != "yes"
  abort "These seeds replace every record with demo data. Set SEED_DEMO_DATA=yes to run them here."
end

# Every seeded account signs in with this.
SEED_PASSWORD = ENV.fetch("SEED_PASSWORD", "password123")

DATA = JSON.parse(Rails.root.join("db/seeds/prototype.json").read)

# What only staff know. Intake never asks a caregiver for the placing agency,
# so it exists here and not in the donor data.
HOUSEHOLD_STAFF_FACTS = {
  "h1"  => { agency: "Bethany Christian Services", verification: "verified", payout: "stripe",    joined: 0 },
  "h2"  => { agency: "DFCS · DeKalb",              verification: "verified", payout: "stripe",    joined: 1 },
  "h3"  => { agency: "DFCS · Cobb",                verification: "verified", payout: "gift_card", joined: 2 },
  "h4"  => { agency: "Faithbridge Foster Care",    verification: "verified", payout: "stripe",    joined: 1 },
  "h5"  => { agency: "DFCS · Gwinnett",            verification: "verified", payout: "stripe",    joined: 3 },
  "h6"  => { agency: "DFCS · Henry",               verification: "verified", payout: "gift_card", joined: 4, language: "Spanish" },
  "h7"  => { agency: "Bethany Christian Services", verification: "verified", payout: "stripe",    joined: 5 },
  "h8"  => { agency: nil,                          verification: "pending",  payout: "none",      joined: 9 },
  "h9"  => { agency: "Faithbridge Foster Care",    verification: "verified", payout: "stripe",    joined: 2 },
  "h10" => { agency: "DFCS · Clayton",             verification: "hold",     payout: "stripe",    joined: 7,
             hold_reason: "Placement change reported Nov 14. Confirming with the Clayton case manager before this household is paid out." }
}.freeze

CAREGIVER_NAMES = {
  "Denise B." => %w[Denise Brooks], "Grace O." => %w[Grace Okafor],
  "Marcus V." => %w[Marcus Vance],  "Rosa D." => %w[Rosa Delgado],
  "Tamika W." => %w[Tamika Whitfield], "Carmen A." => %w[Carmen Alvarez],
  "Kofi B." => %w[Kofi Boateng], "Renee S." => %w[Renee Sinclair],
  "Mai T." => %w[Mai Tran], "Pam W." => %w[Pam Whitaker]
}.freeze

# Who is behind each anonymous gift. Staff see both the name and the alias.
ANONYMOUS_DONORS = [
  [ "Nathan Poole", "nathan.poole@example.com" ], [ "Bettina Ruiz", "b.ruiz@example.com" ],
  [ "Chris Yamada", "cyamada@example.com" ], [ "Dana Kirkland", "dana.k@example.com" ],
  [ "Wes Aldridge", "wesa@example.com" ], [ "Priscilla Bowen", "pbowen@example.com" ],
  [ "Trent Alcott", "trent.alcott@example.com" ], [ "Joanna Meier", "jmeier@example.com" ],
  [ "Rafael Cordova", "rcordova@example.com" ], [ "Hannah Steed", "h.steed@example.com" ],
  [ "Miles Ferrante", "miles.f@example.com" ], [ "Ada Lindqvist", "ada.l@example.com" ]
].freeze

CAP_IN_DOLLARS = 200

# Funded gifts stay, then gifts naming a brand or size, then the least expensive.
FIT_TO_CAP = lambda do |items|
  ranked = items.each_with_index.sort_by do |item, index|
    [ item["claimed"] ? 0 : 1, item["spec"] ? 0 : 1, item["claimed"] || item["spec"] ? 0 : item["price"], index ]
  end
  kept = ranked.each_with_object([]) do |(item, _index), list|
    list << item if list.sum { |row| row["price"] } + item["price"] <= CAP_IN_DOLLARS
  end
  items.select { |item| kept.include?(item) }
end

DONOR_EMAILS = {
  "Priya S." => "priya.sundaram@example.com",
  "The Hollis family" => "kate.hollis@example.com",
  "Piedmont Church youth group" => "students@piedmontchurch.example.org",
  "M. Okonkwo" => "m.okonkwo@example.com",
  "Kroger volunteer team" => "atl.volunteers@kroger.example.com",
  "The Nguyen family" => "thenguyens@example.com",
  "Delta ATL crew" => "giving@deltacrew.example.org",
  "The Reyes family" => "reyes.household@example.com",
  "Buckhead Rotary" => "service@buckheadrotary.example.org",
  "The Ferrell family" => "ferrell4@example.com",
  "Emory service group" => "volunteer@emory.example.edu"
}.freeze

ActiveRecord::Base.transaction do
  puts "Clearing existing records"
  # Users and organizations reference each other, so ordered deletes cannot
  # satisfy both constraints. Truncate resolves the cycle in one statement.
  tables = %w[versions payouts enrollments line_items donations wishlists children households
              organization_memberships catalog_items categories events organizations users addresses
              friendly_id_slugs]
  ActiveRecord::Base.connection.execute("TRUNCATE #{tables.join(', ')} RESTART IDENTITY CASCADE")

  puts "Organizations"
  angels = Organization.create!(name: "Atlanta Angels", short_name: "Angels", kind: "chapter",
                                website_url: "https://atlantaangels.org",
                                stripe_account_id: "acct_seed_angels", stripe_charges_enabled: true,
                                theme: { stylesheet: "theme-angels" })

  passion = Organization.create!(name: "Passion City Church", short_name: "Passion", kind: "partner",
                                 parent: angels, co_brand_line: "Wish List · with Atlanta Angels",
                                 theme: { stylesheet: "theme-passion" })

  # A second chapter gives the organization switcher somewhere to go.
  nashville = Organization.create!(name: "Nashville Angels", short_name: "Nashville", kind: "chapter",
                                   website_url: "https://nashvilleangels.example.org",
                                   hostname: "nashville.localhost",
                                   stripe_account_id: "acct_seed_nashville", stripe_charges_enabled: true)

  agencies = HOUSEHOLD_STAFF_FACTS.values.filter_map { |f| f[:agency] }.uniq.to_h do |name|
    [ name, Organization.create!(name: name, kind: "agency", parent: angels) ]
  end

  puts "Staff"
  User.create!(email: "admin@wishlist.example.org", password: SEED_PASSWORD,
               first_name: "Ada", last_name: "Byrne", role: "admin")
  staff = User.create!(email: "staff@atlantaangels.example.org", password: SEED_PASSWORD,
                       first_name: "Sam", last_name: "Reed", role: "organizer")
  june = User.create!(email: "staff@nashvilleangels.example.org", password: SEED_PASSWORD,
                      first_name: "June", last_name: "Whitlock", role: "organizer")
  drew = User.create!(email: "serve@passioncity.example.org", password: SEED_PASSWORD,
                      first_name: "Drew", last_name: "Halloran", role: "organizer")
  # One organizer in two chapters is what the organization switcher is for.
  nadia = User.create!(email: "regional@angels.example.org", password: SEED_PASSWORD,
                       first_name: "Nadia", last_name: "Iyer", role: "organizer")

  { staff => [ angels ], june => [ nashville ], drew => [ passion ], nadia => [ angels, nashville ] }
    .each { |user, orgs| orgs.each { |org| OrganizationMembership.create!(user: user, organization: org) } }

  angels.update!(primary_contact: staff)
  nashville.update!(primary_contact: june)
  passion.update!(primary_contact: drew)

  puts "Event"
  # Dated relative to now so the seed always opens on a program mid-flight
  # rather than an empty pre-launch one, whenever it is run.
  event = Event.create!(organization: angels, name: "Christmas #{Date.current.year}",
                        opened_at: 6.weeks.ago.change(hour: 9),
                        closes_at: 3.weeks.from_now.change(hour: 23),
                        payout_at: (3.weeks.from_now + 1.day).change(hour: 9),
                        per_child_cap_in_cents: CAP_IN_DOLLARS * 100,
                        love_box_options: LoveBox::DEFAULT_GROUPS)

  Event.create!(organization: nashville, name: "Christmas #{Date.current.year}",
                opened_at: event.opened_at, closes_at: event.closes_at, payout_at: event.payout_at,
                per_child_cap_in_cents: CAP_IN_DOLLARS * 100, love_box_options: LoveBox::DEFAULT_GROUPS)

  puts "Categories and catalog"
  categories = DATA["categories"].each_with_index.to_h do |row, index|
    [ row["id"], Category.create!(organization: angels, name: row["label"], icon: row["icon"], tint: row["tint"],
                                  position: index + 1, headline: DATA["cat_copy"][row["id"]]) ]
  end

  with_photo = DATA["has_photo"].to_set
  catalog = DATA["catalog"].to_h do |row|
    [ row["id"], CatalogItem.create!(category: categories.fetch(row["cat"]), name: row["name"],
                                     price_in_cents: row["price"] * 100,
                                     min_age: row["ages"][0], max_age: row["ages"][1],
                                     icon: row["icon"],
                                     stock_photo: with_photo.include?(row["id"]) ? "catalog/#{row['id']}.jpg" : nil,
                                     photo_attribution: with_photo.include?(row["id"]) ? "Openverse, CC licensed" : nil) ]
  end

  nashville.copy_catalog_from(angels)

  puts "Households, children, and lists"
  households = DATA["households"].to_h do |row|
    facts = HOUSEHOLD_STAFF_FACTS.fetch(row["id"])
    first, last = CAREGIVER_NAMES.fetch(row["caregiver"])

    caregiver = User.create!(email: "#{first}.#{last}@example.com".downcase, password: SEED_PASSWORD,
                             first_name: first, last_name: last, role: "caregiver",
                             preferred_language: facts[:language])

    household = PaperTrail.request(whodunnit: caregiver.id) do
      Household.create!(
        organization: angels, placing_organization: facts[:agency] && agencies[facts[:agency]],
        caregiver: caregiver, gift_card_email: facts[:payout] == "gift_card" ? caregiver.email : nil,
        display_name: row["name"], county: row["area"],
        payout_method: facts[:payout],
        stripe_account_id: facts[:payout] == "stripe" ? "acct_seed_#{row['id']}" : nil,
        stripe_onboarded_at: facts[:payout] == "stripe" ? event.opened_at + facts[:joined].days : nil,
        created_at: event.opened_at + facts[:joined].days
      )
    end

    # A hold follows verification, so a held household shows both steps.
    PaperTrail.request(whodunnit: staff.id) do
      unless facts[:verification] == "pending"
        household.update!(verification_status: "verified", verified_at: household.created_at + 1.day)
      end
      if facts[:verification] == "hold"
        household.update!(verification_status: "hold", hold_reason: facts[:hold_reason])
      end
    end

    enrollment = Enrollment.new(household: household, event: event, intake_step: "review",
                                spending_agreed_at: household.created_at, submitted_at: household.created_at)
    enrollment.love_box_selection.assign(
      event.love_box_groups.to_h { |group| [ group.id, { picks: [ group.options.sample ], count: rand(2..5) } ] }
    )
    PaperTrail.request(whodunnit: caregiver.id) { enrollment.save! }

    [ row["id"], household ]
  end

  donors = {}
  donations = {}
  anonymous_gifts = 0

  DATA["kids"].each do |kid_row|
    household = households.fetch(kid_row["hh"])
    gifts = FIT_TO_CAP.call(kid_row["items"])
    child = Child.create!(household: household, legal_first_name: kid_row["alias"],
                          display_name: kid_row["alias"], gender: kid_row["gender"],
                          birthdate: Date.current.advance(years: -kid_row["age"], days: -30))

    wishlist, lines = PaperTrail.request(whodunnit: household.caregiver_id) do
      list = Wishlist.create!(child: child, event: event, status: "in_review",
                              interests: kid_row["interests"], caregiver_note: kid_row["note"],
                              submitted_at: household.created_at)
      items = gifts.map do |item|
        LineItem.create!(wishlist: list, catalog_item: catalog[item["catId"]], name: item["name"],
                         spec: item["spec"], link_url: item["link"],
                         price_in_cents: item["price"] * 100,
                         status: household.verification_pending? ? "needs_review" : "open")
      end
      [ list, items ]
    end

    # A household still awaiting verification has lists in review, not live.
    next if household.verification_pending?

    PaperTrail.request(whodunnit: staff.id) do
      wishlist.update!(status: "live", approved_at: household.verified_at)
    end

    gifts.zip(lines).each do |item, line|
      next unless item["claimed"]

      display = item["claimedBy"]
      anonymous = display == "Anonymous"
      name, email = anonymous ? ANONYMOUS_DONORS[anonymous_gifts % ANONYMOUS_DONORS.size] : [ display, nil ]
      anonymous_gifts += 1 if anonymous
      key = anonymous ? "anon-#{name}" : display

      donor = donors[key] ||= begin
        email ||= DONOR_EMAILS.fetch(display, "#{display.parameterize}@example.com")
        User.create!(email: email, role: "donor",
                     first_name: name.split.first, last_name: name.split.last)
      end

      # A donor's gifts on one visit ride one charge, the way a cart would.
      PaperTrail.request(whodunnit: donor.id) do
        donation = donations[key]
        if donation
          donation.increment!(:gift_in_cents, line.price_in_cents)
        else
          donation = donations[key] = Donation.create!(
            donor: donor, event: event, storefront_organization: angels,
            gift_in_cents: line.price_in_cents, status: "succeeded",
            display_name: anonymous ? nil : display, anonymous: anonymous,
            payment_method_label: [ "Visa ••••4242", "Mastercard ••••5518", "Amex ••••3007" ].sample,
            stripe_payment_intent_id: "pi_seed_#{SecureRandom.hex(8)}",
            receipt_sent_at: Time.current
          )
        end

        line.fund!(donation)
        donation.update!(fee_in_cents: (donation.gift_in_cents * 0.03).round)
      end
    end
  end

  puts "General giving"
  [ [ "Priya S.", 100_00 ], [ "Buckhead Rotary", 500_00 ], [ "Emory service group", 250_00 ] ].each do |name, cents|
    donor = donors[name] || User.create!(email: DONOR_EMAILS.fetch(name), role: "donor",
                                         first_name: name.split.first, last_name: name.split.last)
    PaperTrail.request(whodunnit: donor.id) do
      Donation.create!(donor: donor, event: event, storefront_organization: angels,
                       gift_in_cents: 0, general_gift_in_cents: cents,
                       fee_in_cents: (cents * 0.03).round, status: "succeeded",
                       display_name: name, payment_method_label: "Visa ••••1881",
                       stripe_payment_intent_id: "pi_seed_#{SecureRandom.hex(8)}",
                       receipt_sent_at: Time.current)
    end
  end

  puts "A donor note awaiting staff review"
  Donation.where.not(display_name: nil).first.update!(
    note_to_family: "We picked the art set because our daughter draws too. Could you send a photo of her with it?"
  )
end

puts ""
puts "Seeded #{Organization.count} organizations, #{User.count} users, #{Household.count} households,"
puts "        #{Child.count} children, #{Wishlist.count} lists, #{LineItem.count} line items,"
puts "        #{LineItem.funded.count} of them funded, across #{Donation.count} donations,"
puts "        with #{Version.count} versions in the audit trail."
