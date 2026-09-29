# frozen_string_literal: true

require "test_helper"
require_relative "storefront_program"

module Public
  # Each chapter's storefront lives at its own host; a host no chapter claims reaches the oldest.
  class ChapterHostTest < ActionDispatch::IntegrationTest
    include StorefrontProgram

    setup do
      build_storefront
      @chapter.update!(hostname: "wishlist.atlantaangels.example")
      @nashville = build_organization(name: "Nashville Angels", hostname: "wishlist.nashvilleangels.example")
      build_event(organization: @nashville, name: "Nashville Christmas")
      @quilts = build_category(organization: @nashville, name: "Quilts")
    end

    test "a chapter's host shows that chapter" do
      host! "wishlist.nashvilleangels.example"
      get root_path

      assert_select ".brand-name", /Nashville Angels/
      assert_not_includes response.body, "Maya"
    end

    test "a host no chapter claims reaches the oldest chapter" do
      host! "angels-wishlist.herokuapp.com"
      get root_path

      assert_select ".brand-name", /Atlanta Angels/
    end

    test "another chapter's category is not found" do
      host! "wishlist.atlantaangels.example"
      get category_path(@quilts)

      assert_response :not_found
    end

    test "another chapter's partner is not a storefront here" do
      elsewhere = build_organization(name: "Belmont Church", kind: "partner", parent: @nashville)
      host! "wishlist.atlantaangels.example"
      get root_path(storefront: elsewhere.slug)

      assert_select ".brand-name", /Atlanta Angels/
      assert_not_includes response.body, "Belmont Church"
    end
  end
end
