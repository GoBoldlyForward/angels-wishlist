# frozen_string_literal: true

class Version < PaperTrail::Version
  # The trail outlives the staff who wrote it, so a deleted user still resolves.
  belongs_to :actor, -> { with_deleted }, class_name: "User", foreign_key: :whodunnit, optional: true
end
