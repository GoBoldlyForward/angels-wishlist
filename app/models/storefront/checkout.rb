# frozen_string_literal: true

module Storefront
  # What the donor tells us at checkout, turned into one pending donation.
  class Checkout
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :email, :string
    attribute :display_name, :string
    attribute :note_to_family, :string
    attribute :cover_fee, :boolean, default: true

    attr_reader :cart, :donation

    validates :email, presence: { message: "is required so we can send your receipt" }
    validates :display_name, length: { maximum: 120 }
    validates :note_to_family, length: { maximum: 1000 }
    validate :email_can_receive_a_receipt
    validate :cart_holds_something
    validate :every_gift_is_still_open
    validate :chapter_takes_cards

    def initialize(attributes = {}, cart:, event:, storefront: nil, visit: nil)
      @cart = cart
      @event = event
      @storefront = storefront
      @visit = visit
      super(attributes)
    end

    def fee_in_cents
      cover_fee ? cart.fee_in_cents : 0
    end

    def charged_in_cents
      cart.total_in_cents + fee_in_cents
    end

    def save
      return false unless valid?

      Donation.transaction do
        donor.save! if donor.new_record?
        PaperTrail.request.whodunnit ||= donor.id
        @donation = Donation.create!(donation_attributes)
      end
      cart.clear
      true
    rescue ActiveRecord::RecordNotUnique
      errors.add(:email, "could not be used. Please try again")
      false
    end

    def anonymous?
      display_name.blank?
    end

    # A note goes to the households whose gifts were chosen, so a general gift carries none.
    def note_offered?
      cart.holds_gifts?
    end

    private

    def donor
      @donor ||= User.find_by(email: normalized_email) || User.new(email: normalized_email, role: "donor")
    end

    def normalized_email
      email.to_s.strip.downcase
    end

    def donation_attributes
      { donor: donor, event: @event, status: "pending", storefront_organization: @storefront,
        ahoy_visit_id: @visit&.id,
        gift_in_cents: cart.gift_in_cents, general_gift_in_cents: cart.general_gift_in_cents,
        fee_in_cents: fee_in_cents,
        display_name: display_name.to_s.strip.presence, anonymous: anonymous?,
        note_to_family: (note_to_family.to_s.strip.presence if note_offered?),
        cart: { "line_item_ids" => cart.lines.map(&:id) } }
    end

    def email_can_receive_a_receipt
      return if email.blank? || donor.persisted? || donor.valid?

      errors.add(:email, donor.errors[:email].first || "is not valid")
    end

    def cart_holds_something
      errors.add(:base, "Your cart is empty.") if @event.nil? || cart.empty?
    end

    def chapter_takes_cards
      return if !PaymentGateway.live? || @event.nil? || @event.organization.stripe_charges_enabled?

      errors.add(:base, "#{@event.organization.name} is not taking card donations yet. Nothing has been charged.")
    end

    def every_gift_is_still_open
      cart.lines
      return if cart.dropped_count.zero?

      errors.add(:base, "A gift in your cart was chosen by someone else first, so we took it out. " \
                        "Please look over your cart again. Nothing has been charged.")
    end
  end
end
