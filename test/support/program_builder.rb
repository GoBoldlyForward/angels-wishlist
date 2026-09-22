# frozen_string_literal: true

# Builds the object graph a test needs without spreading it across fixtures,
# because most of what is worth asserting here is arithmetic over a whole
# household rather than one row.
module ProgramBuilder
  def build_organization(**attrs)
    Organization.create!({ name: "Atlanta Angels #{SecureRandom.hex(3)}", kind: "chapter" }.merge(attrs))
  end

  def build_event(organization: nil, **attrs)
    Event.create!({
      organization: organization || build_organization,
      name: "Christmas #{SecureRandom.hex(3)}",
      opened_at: 2.weeks.ago, closes_at: 2.weeks.from_now, payout_at: 3.weeks.from_now,
      per_child_cap_in_cents: 30_000
    }.merge(attrs))
  end

  def build_caregiver(**attrs)
    User.create!({ email: "cg-#{SecureRandom.hex(4)}@example.com", password: "password123",
                   first_name: "Denise", last_name: "Brooks", role: "caregiver" }.merge(attrs))
  end

  def build_donor(**attrs)
    User.create!({ email: "donor-#{SecureRandom.hex(4)}@example.com", role: "donor",
                   first_name: "Priya", last_name: "Sundaram" }.merge(attrs))
  end

  def build_household(organization: nil, **attrs)
    organization ||= build_organization
    Household.create!({ organization: organization, caregiver: build_caregiver,
                        display_name: "The Brooks home #{SecureRandom.hex(3)}",
                        verification_status: "verified", payout_method: "stripe",
                        stripe_account_id: "acct_test" }.merge(attrs))
  end

  def build_child(household: nil, age: 9, **attrs)
    Child.create!({ household: household || build_household, display_name: "Maya",
                    gender: "girl",
                    birthdate: Date.current.advance(years: -age, days: -30) }.merge(attrs))
  end

  def build_wishlist(child: nil, event: nil, **attrs)
    child ||= build_child
    event ||= build_event(organization: child.household.organization)
    Wishlist.create!({ child: child, event: event, status: "live" }.merge(attrs))
  end

  def build_catalog_item(**attrs)
    category = Category.create!(name: "Art & Music #{SecureRandom.hex(3)}")
    CatalogItem.create!({ category: category, name: "Art supply set #{SecureRandom.hex(3)}",
                          price_in_cents: 4_800 }.merge(attrs))
  end

  def build_line_item(wishlist: nil, **attrs)
    wishlist ||= build_wishlist
    LineItem.create!({ wishlist: wishlist, name: "Art supply set",
                       price_in_cents: 4_800 }.merge(attrs))
  end

  def build_donation(event:, **attrs)
    Donation.create!({ donor: build_donor, event: event, gift_in_cents: 4_800,
                       status: "succeeded", display_name: "Priya S." }.merge(attrs))
  end
end
