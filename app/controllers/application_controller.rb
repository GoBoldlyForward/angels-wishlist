class ApplicationController < ActionController::Base
  include Pagy::Method

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_paper_trail_whodunnit

  private

  # Versions store the user's id; Version#actor turns it back into a User.
  def user_for_paper_trail
    current_user&.id
  end
end
