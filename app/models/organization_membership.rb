# frozen_string_literal: true

class OrganizationMembership < ApplicationRecord
  acts_as_paranoid

  belongs_to :user
  belongs_to :organization

  validates :user_id, uniqueness: { scope: :organization_id }
  validate :organization_hosts_drives
  validate :user_organizes

  private

  # Agencies place children; they run no storefront and hold no funds, so there
  # is nothing there for a member to administer.
  def organization_hosts_drives
    return if organization.blank? || organization.hosts_drives?

    errors.add(:organization, "must be a chapter or a partner")
  end

  def user_organizes
    return if user.blank? || user.organizer? || user.admin?

    errors.add(:user, "must be an organizer")
  end
end
