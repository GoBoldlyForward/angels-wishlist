# frozen_string_literal: true

require_relative "funding_case"

module Admin
  class OrganizationsTest < FundingCase
    setup do
      @agency = build_organization(name: "Bethany Christian Services", kind: "agency", parent: @chapter)
      @partner = build_organization(name: "Passion City Church", kind: "partner", parent: @chapter,
                                    theme: { "stylesheet" => "theme-passion", "tokens" => { "brand" => "#00b5e2" } })
    end

    test "the list groups organizations by kind" do
      get admin_organizations_path

      assert_response :success
      assert_select ".panel-card-head h2", text: /Chapters\s+1/
      assert_select ".panel-card-head h2", text: /Placing agencies\s+1/
      assert_select ".panel-card-head h2", text: /Partners\s+1/
      assert_select "a[href=?]", "/with/#{@partner.slug}"
    end

    test "a partner's page links to its storefront" do
      get admin_organization_path(@partner)

      assert_response :success
      assert_select "a[href=?]", "/with/#{@partner.slug}", text: "/with/#{@partner.slug}"
      assert_select "dd", text: "theme-passion"
    end

    test "creating a partner stores its theme" do
      get new_admin_organization_path(kind: "partner")
      assert_response :success

      assert_difference -> { Organization.partner.count }, 1 do
        post admin_organizations_path, params: { organization: {
          name: "North Point Church", short_name: "North Point", kind: "partner", parent_id: @chapter.id,
          website_url: "https://northpoint.example.org", active: "1",
          co_brand_line: "Wish List · with Atlanta Angels", theme_stylesheet: "theme-passion"
        } }
      end

      partner = Organization.find_by!(name: "North Point Church")
      assert_redirected_to admin_organization_path(partner)
      assert_equal "theme-passion", partner.theme["stylesheet"]
      assert_equal [ "North Point", @chapter, "Wish List · with Atlanta Angels" ],
                   [ partner.short_name, partner.parent, partner.co_brand_line ]
    end

    test "an agency never keeps a theme" do
      post admin_organizations_path, params: { organization: {
        name: "Wellroot Family Services", kind: "agency", parent_id: @chapter.id, theme_stylesheet: "theme-passion"
      } }

      assert_equal({}, Organization.find_by!(name: "Wellroot Family Services").theme)
    end

    test "a theme that is not bundled is refused" do
      assert_no_difference -> { Organization.count } do
        post admin_organizations_path, params: { organization: {
          name: "North Point Church", kind: "partner", theme_stylesheet: "theme-elsewhere"
        } }
      end

      assert_response :unprocessable_entity
      assert_select ".alert-danger", text: /bundled themes/
    end

    test "editing an organization keeps the rest of its theme" do
      get edit_admin_organization_path(@partner)
      assert_response :success

      patch admin_organization_path(@partner), params: { organization: {
        short_name: "Passion", active: "0", theme_stylesheet: "theme-angels"
      } }

      assert_redirected_to admin_organization_path(@partner)
      assert_equal [ "Passion", false ], [ @partner.reload.short_name, @partner.active ]
      assert_equal({ "stylesheet" => "theme-angels", "tokens" => { "brand" => "#00b5e2" } }, @partner.theme)
    end

    test "an admin adds a chapter, which starts from the oldest chapter's catalog" do
      shelf = build_category(organization: @chapter, name: "Toys & Games", position: 1)
      build_catalog_item(category: shelf, name: "Building blocks", price_in_cents: 3_500)

      post admin_organizations_path, params: { organization: {
        name: "Nashville Angels", kind: "chapter", hostname: "https://Wishlist.NashvilleAngels.example/",
        legal_name: "Nashville Angels, Inc.", ein: "12-3456789", platform_fee_basis_points: 150
      } }

      chapter = Organization.find_by!(name: "Nashville Angels")
      assert_redirected_to admin_organization_path(chapter)
      assert_nil chapter.parent
      assert_equal [ "wishlist.nashvilleangels.example", "12-3456789", 150 ],
                   [ chapter.hostname, chapter.ein, chapter.platform_fee_basis_points ]
      assert_equal [ "Toys & Games" ], chapter.categories.pluck(:name)
      assert_equal [ [ "Building blocks", 3_500 ] ], chapter.catalog_items.pluck(:name, :price_in_cents)
    end

    test "an organizer adds agencies and partners to their own chapter, never a chapter" do
      sign_in build_organizer(organization: @chapter)

      post admin_organizations_path, params: { organization: {
        name: "Nashville Angels", kind: "chapter", hostname: "wishlist.nashvilleangels.example",
        platform_fee_basis_points: 0
      } }

      added = Organization.find_by!(name: "Nashville Angels")
      assert added.agency?
      assert_equal @chapter, added.parent
      assert_nil added.hostname
    end

    test "an organizer cannot change the chapter's host name or fee" do
      sign_in build_organizer(organization: @chapter)

      patch admin_organization_path(@chapter), params: { organization: {
        legal_name: "Atlanta Angels, Inc.", hostname: "evil.example", platform_fee_basis_points: 0
      } }

      assert_redirected_to admin_organization_path(@chapter)
      @chapter.reload
      assert_equal "Atlanta Angels, Inc.", @chapter.legal_name
      assert_nil @chapter.hostname
    end

    test "an organizer switches the Getting paid step off and back on" do
      sign_in build_organizer(organization: @chapter)

      get edit_admin_organization_path(@chapter)
      assert_select "input[type=checkbox][name=?][checked]", "organization[collects_payout_details]"

      patch admin_organization_path(@chapter), params: { organization: { collects_payout_details: "0" } }
      assert_not @chapter.reload.collects_payout_details?

      get admin_organization_path(@chapter)
      assert_select "dd", text: "Switched off. Lists come in without payout details"

      patch admin_organization_path(@chapter), params: { organization: { collects_payout_details: "1" } }
      assert @chapter.reload.collects_payout_details?
    end

    test "an organization without a name is refused" do
      patch admin_organization_path(@agency), params: { organization: { name: "" } }

      assert_response :unprocessable_entity
      assert_equal "Bethany Christian Services", @agency.reload.name
    end
  end
end
