# frozen_string_literal: true

require "test_helper"
require_relative "storefront_program"

module Public
  # Public pages render a fixed set of fields. Nothing private about a child,
  # a caregiver, or a household may reach a response body.
  class PrivacyTest < ActionDispatch::IntegrationTest
    include StorefrontProgram

    STALE_COPY = [
      "Recorded, not pooled", "on its way toward", "directed to each child's household",
      "reaches the household", "furthest-behind", "closest-to-complete", "note back from the household",
      "aliases chosen", "caregiver chose", "Prototype", "paid to "
    ].freeze

    setup do
      build_storefront
      @mayas_hoodie = ask(@maya, @hoodie, days_ago: 9)
      @mayas_art = ask(@maya, @art_set, days_ago: 8, spec: "Washable", link_url: "https://www.example.com/art")
      @theos_hoodie = ask(@theo, @hoodie, days_ago: 7, spec: "Nike, size L")
      @scooter = ask(@theo, nil, days_ago: 3, name: "Purple scooter")
      @mayas_art.fund!(build_donation(event: @event, gift_in_cents: 2_000, display_name: "The Reyes family"))
    end

    test "no private detail appears on any public page" do
      each_public_page do |page|
        private_details.each do |detail|
          assert_not_includes response.body, detail, "#{page} shows #{detail}"
        end
        assert_no_match(/#{@maya.child.birthdate.year}-\d\d-\d\d/, response.body, "#{page} shows a birthdate")
        assert_not_includes response.body, @maya.child.birthdate.to_fs(:long), "#{page} shows a birthdate"
        assert_not_includes response.body, @household.caregiver.email, "#{page} shows a caregiver's email"
      end
    end

    test "no page carries the prototype's stale wording" do
      each_public_page do |page|
        STALE_COPY.each do |phrase|
          assert_not_includes response.body, phrase, "#{page} says #{phrase.inspect}"
        end
      end
    end

    private

    def each_public_page
      add_to_cart @mayas_hoodie
      add_to_cart @theos_hoodie
      post cart_general_gifts_path, params: { amount: 25 }, headers: BROWSER

      pages = [ root_path, root_path(tab: "children"), root_path(tab: "unfunded"), root_path(tab: "give"),
                root_path(gender: "girl"), category_path(id: "clothes-shoes"), gift_path(id: "hoodie"),
                gift_path(id: "art-supply-set"), gift_path(id: "#{@theo.slug}--purple-scooter"),
                child_path(id: @maya.slug), child_path(id: @theo.slug), cart_path, checkout_path ]
      pages.each do |page|
        visit page
        assert_response :success, "#{page} did not render"
        assert_includes response.body, "Maya", "#{page} shows no child at all"
        yield page
      end

      check_out note_to_family: "Thinking of you all this Christmas."
      follow_redirect!
      assert_response :success
      assert_select ".mini", text: /For Maya, 9/
      yield "the confirmation"
    end
  end
end
