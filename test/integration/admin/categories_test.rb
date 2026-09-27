# frozen_string_literal: true

require_relative "funding_case"

module Admin
  class CategoriesTest < FundingCase
    setup do
      @toys = Category.create!(name: "Toys & Games", icon: "fa-puzzle-piece", tint: "t2", position: 1)
      @clothes = Category.create!(name: "Clothes & Shoes", icon: "fa-shirt", tint: "t1", position: 1)
    end

    test "the list is in position order" do
      get admin_categories_path

      assert_response :success
      assert_select "tbody tr:nth-child(1) td", text: /Clothes & Shoes/
      assert_select "tbody tr:nth-child(2) td", text: /Toys & Games/
    end

    test "creating a category" do
      get new_admin_category_path
      assert_response :success

      assert_difference -> { Category.count }, 1 do
        post admin_categories_path, params: { category: {
          name: "Books", icon: "fa-book", tint: "t3", headline: "Stories to keep", blurb: "Books of their own.", position: ""
        } }
      end

      assert_redirected_to admin_categories_path
      books = Category.find_by!(name: "Books")
      assert_equal [ "fa-book", "t3", "Stories to keep" ], [ books.icon, books.tint, books.headline ]
      assert_equal 3, books.position
    end

    test "a category without a name is refused" do
      post admin_categories_path, params: { category: { name: "" } }

      assert_response :unprocessable_entity
      assert_select ".alert-danger"
    end

    test "editing a category" do
      get edit_admin_category_path(@toys)
      assert_response :success

      patch admin_category_path(@toys), params: { category: { headline: "Play, on purpose", tint: "t5" } }

      assert_redirected_to admin_categories_path
      assert_equal [ "Play, on purpose", "t5" ], [ @toys.reload.headline, @toys.tint ]
    end

    test "deleting an empty category" do
      assert_difference -> { Category.count }, -1 do
        delete admin_category_path(@toys)
      end
      assert_redirected_to admin_categories_path
    end

    test "deleting a category that has catalog items is refused" do
      build_catalog_item(category: @toys)

      assert_no_difference -> { Category.count } do
        delete admin_category_path(@toys)
      end

      assert_redirected_to admin_categories_path
      assert_match(/still has catalog items/, flash[:alert])
    end
  end
end
