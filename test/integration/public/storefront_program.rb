# frozen_string_literal: true

# A small program for the donor-side tests: one chapter, one partner, one open
# event, and two households whose private details are easy to search for.
module StorefrontProgram
  LEGAL_NAMES = %w[Zephyrine Bartholomew Guinevere].freeze
  HOUSEHOLD_NAME = "The Quackenbush home"
  CAREGIVER_LAST_NAME = "Quackenbush"
  STREET = "411 Marigold Terrace"
  AGENCY = "Longleaf Family Services"

  BROWSER = { "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                              "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36" }.freeze

  def build_storefront
    @chapter = build_organization(name: "Atlanta Angels")
    @partner = build_organization(name: "Passion City Church", kind: "partner", parent: @chapter,
                                  theme: { stylesheet: "theme-passion" })
    @event = build_event(organization: @chapter, name: "Christmas")
    @art = Category.create!(organization: @chapter, name: "Art & Music", icon: "fa-palette", tint: "t5", position: 2,
                            headline: "For the kids who draw, build, and make noise")
    @clothes = Category.create!(organization: @chapter, name: "Clothes & Shoes", icon: "fa-shirt", tint: "t1", position: 1,
                                headline: "The clothes they actually need this winter")
    @hoodie = CatalogItem.create!(category: @clothes, name: "Hoodie", price_in_cents: 4_000, icon: "🧥")
    @art_set = CatalogItem.create!(category: @art, name: "Art supply set", price_in_cents: 2_000, icon: "🎨")

    @household = build_private_household
    @maya = build_listed_child(@household, "Maya", age: 9, gender: "girl", legal_first_name: LEGAL_NAMES[0],
                                                   interests: %w[drawing soccer slime baking],
                                                   note: "She draws on every page she can find.")
    @theo = build_listed_child(@household, "Theo", age: 14, gender: "boy", legal_first_name: LEGAL_NAMES[1])
  end

  def build_private_household(**attrs)
    caregiver = build_caregiver(first_name: "Philippa", last_name: CAREGIVER_LAST_NAME)
    address = Address.create!(street_line_1: STREET, city: "Decatur", state: "GA", zipcode: "30030")
    agency = Organization.find_by(name: AGENCY) || build_organization(name: AGENCY, kind: "agency")
    build_household(organization: @chapter, caregiver: caregiver, display_name: HOUSEHOLD_NAME,
                    county: "DeKalb County", mailing_address: address, placing_organization: agency, **attrs)
  end

  def build_listed_child(household, name, age:, gender:, legal_first_name: nil, interests: [], note: nil,
                         status: "live", approved_at: 3.weeks.ago)
    child = build_child(household: household, age: age, gender: gender, display_name: name,
                        legal_first_name: legal_first_name)
    build_wishlist(child: child, event: @event, status: status, interests: interests,
                   caregiver_note: note, approved_at: approved_at)
  end

  # Lines are dated apart so "oldest first" means something.
  def ask(wishlist, item, days_ago:, **attrs)
    build_line_item(wishlist: wishlist, catalog_item: item, name: item&.name || "Purple scooter",
                    price_in_cents: item&.price_in_cents || 3_500, created_at: days_ago.days.ago, **attrs)
  end

  def gift_key(line)
    Storefront::Gift.new(line, child: Storefront::ChildCard.new(line.wishlist)).key
  end

  def add_to_cart(line, storefront: nil)
    post cart_gifts_path(storefront: storefront), params: { gift: gift_key(line) }, headers: BROWSER
  end

  def check_out(storefront: nil, **fields)
    post checkout_path(storefront: storefront),
         params: { checkout: { email: "kate.hollis@example.com", display_name: "The Hollis family",
                               cover_fee: "1" }.merge(fields) },
         headers: BROWSER
  end

  def visit(path)
    get path, headers: BROWSER
  end

  def private_details
    LEGAL_NAMES + [ HOUSEHOLD_NAME, CAREGIVER_LAST_NAME, STREET, AGENCY, "Philippa" ]
  end
end
