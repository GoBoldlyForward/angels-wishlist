# frozen_string_literal: true

module Admin
  # Adds a person to a chapter's organizers, creating their account when they have none.
  class OrganizerInvite
    include ActiveModel::Model

    attr_accessor :email, :first_name, :last_name
    attr_reader :chapter, :user

    validates :email, presence: true
    validates :first_name, :last_name, presence: true, if: -> { existing.nil? }
    validate :one_role_per_person
    validate :not_already_here
    validate :new_account_is_valid

    def initialize(chapter:, **attributes)
      @chapter = chapter
      super(**attributes)
    end

    def save
      return false unless valid?

      creating = existing.nil?
      User.transaction do
        @user = existing || new_account.tap(&:save!)
        chapter.organization_memberships.create!(user: @user)
      end
      @user.send_reset_password_instructions if creating
      true
    end

    def creating_account?
      existing.nil?
    end

    private

    def existing
      return @existing if defined?(@existing)

      @existing = User.find_by(email: email.to_s.strip.downcase)
    end

    def new_account
      @new_account ||= User.new(email: email.to_s.strip.downcase, first_name: first_name, last_name: last_name,
                                role: "organizer", password: SecureRandom.base58(24))
    end

    def one_role_per_person
      return if existing.nil? || existing.organizer?

      errors.add(:email, existing.admin? ? "belongs to an admin, who already reaches every chapter" :
                                           "belongs to a #{existing.role}, and one person has one role")
    end

    def not_already_here
      return unless existing&.organizer? && chapter.organizers.exists?(existing.id)

      errors.add(:email, "already belongs to an organizer of #{chapter.display_name}")
    end

    def new_account_is_valid
      return if existing || email.blank? || new_account.valid?

      new_account.errors.full_messages.each { |message| errors.add(:base, message) }
    end
  end
end
