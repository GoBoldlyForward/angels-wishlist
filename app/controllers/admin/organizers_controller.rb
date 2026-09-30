# frozen_string_literal: true

module Admin
  class OrganizersController < BaseController
    def index
      @memberships = current_chapter.organization_memberships.joins(:user).includes(:user)
                                    .order("users.first_name, users.last_name")
    end

    def new
      @invite = OrganizerInvite.new(chapter: current_chapter)
    end

    def create
      @invite = OrganizerInvite.new(chapter: current_chapter, **invite_params)

      if @invite.save
        notice = if @invite.creating_account?
          "#{@invite.user.full_name} is an organizer of #{current_chapter.display_name}. They were sent a link to choose a password."
        else
          "#{@invite.user.full_name} is now an organizer of #{current_chapter.display_name} too."
        end
        redirect_to admin_organizers_path, notice: notice
      else
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      membership = current_chapter.organization_memberships.find(params[:id])
      return redirect_to(admin_organizers_path, alert: "You cannot remove yourself.") if membership.user == current_user

      membership.destroy!
      redirect_to admin_organizers_path, notice: "#{membership.user.full_name} no longer reaches #{current_chapter.display_name}."
    end

    private

    def invite_params
      params.expect(organizer_invite: %i[email first_name last_name]).to_h.symbolize_keys
    end
  end
end
