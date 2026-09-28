# frozen_string_literal: true

module Intake
  # One child on step two: the child, and the list that carries what donors
  # read about them.
  class ChildEntry
    include ActiveModel::Model
    include ActiveModel::Attributes

    GENDERS = %w[girl boy].freeze
    OLDEST_AGE = 18
    MOST_INTERESTS = 12
    LONGEST_INTEREST = 40
    SUGGESTED_INTERESTS = [ "drawing", "basketball", "dinosaurs", "reading", "music", "soccer", "Legos", "baking",
                            "video games", "animals", "dancing", "space", "skateboarding", "fashion", "fishing",
                            "cars" ].freeze
    SUGGESTIONS_SHOWN = 9
    LABELS = { legal_first_name: "First name", caregiver_note: "The sentence for donors" }.freeze

    attribute :key, :string
    attribute :legal_first_name, :string
    attribute :birthdate, :date
    attribute :gender, :string
    attribute :interests, default: -> { [] }
    attribute :caregiver_note, :string
    attribute :display_name, :string
    attribute :remove, :boolean, default: false

    attr_reader :child, :wishlist

    validates :legal_first_name, presence: true
    validates :birthdate, presence: true
    validates :gender, inclusion: { in: GENDERS, message: "must be chosen" }
    validates :caregiver_note, length: { maximum: 400 }
    validate :young_enough, if: -> { birthdate.present? }

    def initialize(child:, event:, attributes: nil)
      @child = child
      @wishlist = child.wishlists.find { |list| list.event_id == event.id } || child.wishlists.build(event: event)
      super()
      attributes.nil? ? read_records : assign_attributes(attributes)
      self.display_name = child.display_name if child.persisted?
      self.key ||= child.persisted? ? "c#{child.id}" : "n#{SecureRandom.hex(4)}"
    end

    def interests=(values)
      tidy = Array(values).map { |value| value.to_s.strip.downcase.first(LONGEST_INTEREST) }
      super(tidy.compact_blank.uniq.first(MOST_INTERESTS))
    end

    def suggested_interests
      SUGGESTED_INTERESTS.reject { |interest| interests.include?(interest.downcase) }.first(SUGGESTIONS_SHOWN)
    end

    def save!
      child.assign_attributes(legal_first_name: legal_first_name.strip, birthdate: birthdate, gender: gender,
                              display_name: child.display_name.presence || display_name)
      if wishlist.new_record? || wishlist.editable_by_caregiver?
        wishlist.assign_attributes(interests: interests, caregiver_note: caregiver_note.to_s.strip.presence)
      end
      child.save!
      wishlist.save!
    end

    def new_child?
      child.new_record?
    end

    def removable?
      !child.persisted? || child.line_items.funded.none?
    end

    def self.human_attribute_name(attribute, options = {})
      LABELS[attribute.to_sym] || super
    end

    private

    def read_records
      assign_attributes(child.slice(:legal_first_name, :birthdate, :gender))
      self.gender = nil unless GENDERS.include?(gender)
      self.interests = wishlist.interests
      self.caregiver_note = wishlist.caregiver_note
    end

    def young_enough
      if birthdate > Date.current
        errors.add(:birthdate, "cannot be in the future")
      elsif birthdate <= Date.current.advance(years: -(OLDEST_AGE + 1))
        errors.add(:birthdate, "must make them #{OLDEST_AGE} or younger")
      end
    end
  end
end
