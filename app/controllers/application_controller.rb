class ApplicationController < ActionController::Base
  include Pagy::Method

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  layout :layout_for_devise

  before_action :set_paper_trail_whodunnit
  before_action :set_current_user

  helper_method :current_storefront, :current_event, :current_chapter

  private

  # Versions store the user's id; Version#actor turns it back into a User.
  def user_for_paper_trail
    current_user&.id
  end

  def set_current_user
    Current.user = current_user
  end

  def current_chapter
    @current_chapter ||= Organization.chapter.order(:id).first
  end

  def current_storefront
    @current_storefront ||= Organization.hosting.where(active: true).find_by(slug: params[:storefront]) ||
                            current_chapter
  end

  def current_event
    @current_event ||= current_chapter && Event.where(organization: current_chapter).current
  end

  def layout_for_devise
    devise_controller? ? "account" : "application"
  end

  def after_sign_in_path_for(user)
    stored_location_for(user) || home_path_for(user)
  end

  def home_path_for(user)
    return admin_root_path if user.is_admin?
    return caregiver_root_path if user.caregiver?

    root_path
  end
end
