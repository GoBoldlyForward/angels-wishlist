# frozen_string_literal: true

require_relative "funding_case"

module Admin
  class OrganizersTest < FundingCase
    setup do
      @sam = build_organizer(organization: @chapter, first_name: "Sam", last_name: "Reed")
      sign_in @sam
    end

    test "the staff page lists the chapter's organizers" do
      build_organizer(organization: build_organization(name: "Nashville Angels"), first_name: "June", last_name: "Whitlock")

      get admin_organizers_path

      assert_response :success
      assert_includes response.body, "Sam Reed"
      assert_not_includes response.body, "June Whitlock"
    end

    test "someone new gets an organizer account and an email to choose a password" do
      assert_emails 1 do
        post admin_organizers_path, params: { organizer_invite: {
          email: "Casey.Nunez@example.com", first_name: "Casey", last_name: "Nunez"
        } }
      end

      casey = User.find_by!(email: "casey.nunez@example.com")
      assert_redirected_to admin_organizers_path
      assert casey.organizer?
      assert_equal [ @chapter ], casey.organizations.to_a
    end

    test "an organizer of another chapter is added here too, without a new account" do
      june = build_organizer(organization: build_organization(name: "Nashville Angels"))

      assert_no_emails do
        post admin_organizers_path, params: { organizer_invite: { email: june.email } }
      end

      assert_includes june.reload.organizations, @chapter
    end

    test "a caregiver's email cannot become an organizer" do
      caregiver = build_caregiver

      post admin_organizers_path, params: { organizer_invite: { email: caregiver.email } }

      assert_response :unprocessable_entity
      assert_select ".alert-danger", /one person has one role/
      assert caregiver.reload.caregiver?
    end

    test "removing an organizer ends their reach into the chapter" do
      june = build_organizer(organization: @chapter)
      membership = june.organization_memberships.first

      delete admin_organizer_path(membership)

      assert_redirected_to admin_organizers_path
      assert_not june.organizes?(@chapter)
    end

    test "an organizer cannot remove themselves" do
      delete admin_organizer_path(@sam.organization_memberships.first)

      assert @sam.organizes?(@chapter)
    end
  end
end
