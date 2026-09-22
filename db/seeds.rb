# frozen_string_literal: true

# Seeds the program the prototype describes: one chapter, one partner skin, one
# event, and the twenty children across ten households that donor-side data.js
# already holds. db/seeds/prototype.json is generated from that file, so the two
# cannot drift.

require "json"

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
             hold_reason: "Placement change reported Nov 14. Confirming with the Clayton case manager before this household is paid out." },
}.freeze

CAREGIVER_NAMES = {
  "Denise B." => %w[Denise Brooks], "Grace O." => %w[Grace Okafor],
  "Marcus V." => %w[Marcus Vance],  "Rosa D." => %w[Rosa Delgado],
  "Tamika W." => %w[Tamika Whitfield], "Carmen A." => %w[Carmen Alvarez],
  "Kofi B." => %w[Kofi Boateng], "Renee S." => %w[Renee Sinclair],
  "Mai T." => %w[Mai Tran], "Pam W." => %w[Pam Whitaker],
}.freeze

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
  "Emory service group" => "volunteer@emory.example.edu",
}.freeze

ActiveRecord::Base.transaction do
  puts "Clearing existing records"
  # Users and organizations reference each other, so ordered deletes cannot
  # satisfy both constraints. Truncate resolves the cycle in one statement.
  tables = %w[payouts line_items donations wishlists children households catalog_items
              categories events organizations users addresses friendly_id_slugs]
  ActiveRecord::Base.connection.execute("TRUNCATE #{tables.join(', ')} RESTART IDENTITY CASCADE")

  puts "Organizations"
  angels = Organization.create!(name: "Atlanta Angels", short_name: "Angels", kind: "chapter",
                                website_url: "https://atlantaangels.org",
                                stripe_account_id: "acct_seed_angels",
                                theme: { brand: "#a29060", on_brand: "#241f16", font_sans: "Work Sans" })

  Organization.create!(name: "Passion City Church", short_name: "Passion", kind: "partner",
                       parent: angels, co_brand_line: "Wish List · with Atlanta Angels",
                       theme: { brand: "#00b6cd", on_brand: "#06242a", font_sans: "system-ui" })

  agencies = HOUSEHOLD_STAFF_FACTS.values.filter_map { |f| f[:agency] }.uniq.to_h do |name|
    [ name, Organization.create!(name: name, kind: "agency", parent: angels) ]
  end

  puts "Staff"
  User.create!(email: "staff@atlantaangels.example.org", password: "password123",
               first_name: "Sam", last_name: "Reed", role: "staff", is_admin: true,
               organization: angels)

  puts "Event"
  # Dated relative to now so the seed always opens on a program mid-flight
  # rather than an empty pre-launch one, whenever it is run.
  event = Event.create!(organization: angels, name: "Christmas #{Date.current.year}",
                        opened_at: 6.weeks.ago.change(hour: 9),
                        closes_at: 3.weeks.from_now.change(hour: 23),
                        payout_at: (3.weeks.from_now + 1.day).change(hour: 9),
                        per_child_cap_in_cents: 30_000)

  puts "Categories and catalog"
  categories = DATA["categories"].each_with_index.to_h do |row, index|
    [ row["id"], Category.create!(name: row["label"], icon: row["icon"], tint: row["tint"],
                                  position: index + 1, headline: DATA["cat_copy"][row["id"]]) ]
  end

  with_photo = DATA["has_photo"].to_set
  catalog = DATA["catalog"].to_h do |row|
    [ row["id"], CatalogItem.create!(category: categories.fetch(row["cat"]), name: row["name"],
                                     price_in_cents: row["price"] * 100,
                                     min_age: row["ages"][0], max_age: row["ages"][1],
                                     icon: row["icon"],
                                     photo_attribution: with_photo.include?(row["id"]) ? "Openverse, CC licensed" : nil) ]
  end

  puts "Households, children, and lists"
  households = DATA["households"].to_h do |row|
    facts = HOUSEHOLD_STAFF_FACTS.fetch(row["id"])
    first, last = CAREGIVER_NAMES.fetch(row["caregiver"])

    caregiver = User.create!(email: "#{first}.#{last}@example.com".downcase, password: "password123",
                             first_name: first, last_name: last, role: "caregiver",
                             preferred_language: facts[:language])

    address = Address.create!(street_line_1: "#{100 + rand(800)} Peachtree Way",
                              city: row["area"].sub(" County", ""), state: "GA",
                              zipcode: format("30%03d", rand(1000)))

    household = Household.create!(
      organization: angels, placing_organization: facts[:agency] && agencies[facts[:agency]],
      caregiver: caregiver, mailing_address: address,
      display_name: row["name"], county: row["area"],
      verification_status: facts[:verification],
      verified_at: facts[:verification] == "verified" ? event.opened_at + (facts[:joined] + 1).days : nil,
      hold_reason: facts[:hold_reason],
      payout_method: facts[:payout],
      stripe_account_id: facts[:payout] == "stripe" ? "acct_seed_#{row['id']}" : nil,
      created_at: event.opened_at + facts[:joined].days
    )
    [ row["id"], household ]
  end

  donors = {}
  donations = {}

  DATA["kids"].each do |kid_row|
    household = households.fetch(kid_row["hh"])
    child = Child.create!(household: household, legal_first_name: kid_row["alias"],
                          display_name: kid_row["alias"], gender: kid_row["gender"],
                          birthdate: Date.current.advance(years: -kid_row["age"], days: -30))

    # A household still awaiting verification has lists in review, not live.
    status = household.verification_pending? ? "in_review" : "live"
    wishlist = Wishlist.create!(child: child, event: event, status: status,
                                interests: kid_row["interests"], caregiver_note: kid_row["note"],
                                submitted_at: household.created_at,
                                approved_at: status == "live" ? household.verified_at : nil)

    kid_row["items"].each do |item|
      catalog_item = catalog[item["catId"]]
      line = LineItem.create!(wishlist: wishlist, catalog_item: catalog_item, name: item["name"],
                              spec: item["spec"], link_url: item["link"],
                              price_in_cents: item["price"] * 100,
                              status: status == "in_review" ? "needs_review" : "open")

      next unless item["claimed"] && status == "live"

      display = item["claimedBy"]
      anonymous = display == "Anonymous"
      key = anonymous ? "anon-#{line.id}" : display

      donor = donors[key] ||= begin
        name = anonymous ? Faker::Name.name : display
        email = anonymous ? Faker::Internet.unique.email : DONOR_EMAILS.fetch(display, "#{display.parameterize}@example.com")
        User.create!(email: email, role: "donor",
                     first_name: name.split.first, last_name: name.split.last)
      end

      # A donor's gifts on one visit ride one charge, the way a cart would.
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

  puts "General giving"
  [ [ "Priya S.", 100_00 ], [ "Buckhead Rotary", 500_00 ], [ "Emory service group", 250_00 ] ].each do |name, cents|
    donor = donors[name] || User.create!(email: DONOR_EMAILS.fetch(name), role: "donor",
                                         first_name: name.split.first, last_name: name.split.last)
    Donation.create!(donor: donor, event: event, storefront_organization: angels,
                     gift_in_cents: 0, general_gift_in_cents: cents,
                     fee_in_cents: (cents * 0.03).round, status: "succeeded",
                     display_name: name, payment_method_label: "Visa ••••1881",
                     stripe_payment_intent_id: "pi_seed_#{SecureRandom.hex(8)}",
                     receipt_sent_at: Time.current)
  end

  puts "A donor note awaiting staff review"
  Donation.where.not(display_name: nil).first.update!(
    note_to_family: "We picked the art set because our daughter draws too. Could you send a photo of her with it?"
  )
end

puts ""
puts "Seeded #{Organization.count} organizations, #{User.count} users, #{Household.count} households,"
puts "        #{Child.count} children, #{Wishlist.count} lists, #{LineItem.count} line items,"
puts "        #{LineItem.funded.count} of them funded, across #{Donation.count} donations."
