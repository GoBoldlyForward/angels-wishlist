# frozen_string_literal: true

require_relative "funding_case"

module Admin
  class CatalogItemsTest < FundingCase
    PNG = "\x89PNG\r\n\x1A\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\b\x06\x00\x00\x00\x1F\x15\xC4\x89" \
          "\x00\x00\x00\rIDATx\x9Cc\xF8\xFF\xFF?\x00\x05\xFE\x02\xFE\xA7\x9A\x8D\xB0\x00\x00\x00\x00IEND\xAEB`\x82".b

    setup do
      @toys = Category.create!(name: "Toys & Games", position: 1)
      @books = Category.create!(name: "Books", position: 2)
      @blocks = CatalogItem.create!(category: @toys, name: "Building blocks", price_in_cents: 3_500, icon: "🧱",
                                    min_age: 3, max_age: 8)
      @novel = CatalogItem.create!(category: @books, name: "Chapter book set", price_in_cents: 2_200, active: false,
                                   stock_photo: "catalog/c01.jpg")
    end

    test "the index lists the catalog with search and a category filter" do
      get admin_catalog_items_path
      assert_response :success
      assert_select "tbody tr", 2
      assert_select ".thumb-emoji", text: "🧱"

      get admin_catalog_items_path(q: "block")
      assert_select "tbody tr", 1
      assert_select "td", text: /Building blocks/

      get admin_catalog_items_path(f: { category: @books.id })
      assert_select "tbody tr", 1
      assert_select "td", text: /Chapter book set/

      get admin_catalog_items_path(tab: "inactive")
      assert_select "tbody tr", 1
    end

    test "the index exports to CSV" do
      get admin_catalog_items_path(format: :csv)

      assert_response :success
      assert_equal "text/csv", response.media_type
      assert_equal [ "Building blocks", "Chapter book set" ], csv_rows.map { |row| row["Name"] }.sort
      assert_equal "35", csv_rows.find { |row| row["Name"] == "Building blocks" }["Price"]
    end

    test "creating a catalog item takes its price in dollars" do
      get new_admin_catalog_item_path
      assert_response :success

      assert_difference -> { CatalogItem.count }, 1 do
        post admin_catalog_items_path, params: { catalog_item: {
          name: "Scooter", category_id: @toys.id, price_in_dollars: "64.99", min_age: "5", max_age: "12",
          icon: "🛴", active: "1", photo_attribution: "Photo by Atlanta Angels"
        } }
      end

      assert_redirected_to admin_catalog_items_path
      scooter = CatalogItem.find_by!(name: "Scooter")
      assert_equal 6_499, scooter.price_in_cents
      assert_equal [ 5, 12, "🛴", true ], [ scooter.min_age, scooter.max_age, scooter.icon, scooter.active ]
      assert_equal @toys, scooter.category
    end

    test "a catalog item without a price is refused" do
      assert_no_difference -> { CatalogItem.count } do
        post admin_catalog_items_path, params: { catalog_item: { name: "Scooter", category_id: @toys.id, price_in_dollars: "" } }
      end

      assert_response :unprocessable_entity
      assert_select ".alert-danger", text: /price must be a dollar amount/
    end

    test "editing a catalog item" do
      get edit_admin_catalog_item_path(@blocks)
      assert_response :success
      assert_select "input[name=?][value=?]", "catalog_item[price_in_dollars]", "35"

      patch admin_catalog_item_path(@blocks), params: { catalog_item: { price_in_dollars: "40", active: "0", category_id: @books.id } }

      assert_redirected_to admin_catalog_items_path
      assert_equal [ 4_000, false, @books ], [ @blocks.reload.price_in_cents, @blocks.active, @blocks.category ]
    end

    test "uploading a photo attaches it" do
      patch admin_catalog_item_path(@blocks), params: { catalog_item: { name: "Building blocks", photo: png_upload } }

      assert_redirected_to admin_catalog_items_path
      assert_nil flash[:alert]
      assert @blocks.reload.photo.attached?
    end

    test "when storage refuses the upload the item is still saved and staff are told" do
      service = ActiveStorage::Blob.service
      service.define_singleton_method(:upload) { |*, **| raise ActiveStorage::Error, "storage is not configured" }

      patch admin_catalog_item_path(@blocks), params: { catalog_item: { name: "Wooden blocks", photo: png_upload } }

      assert_redirected_to admin_catalog_items_path
      assert_match(/photo could not be stored/, flash[:alert])
      assert_equal "Wooden blocks", @blocks.reload.name
      assert_not @blocks.photo.attached?
    ensure
      service.singleton_class.send(:remove_method, :upload)
    end

    test "a file that is not an image is refused and the rest is saved" do
      upload = Rack::Test::UploadedFile.new(StringIO.new("not a picture"), "text/plain", original_filename: "notes.txt")

      patch admin_catalog_item_path(@blocks), params: { catalog_item: { name: "Wooden blocks", photo: upload } }

      assert_match(/Photo/, flash[:alert])
      assert_equal "Wooden blocks", @blocks.reload.name
      assert_not @blocks.photo.attached?
    end

    test "deleting a catalog item leaves the gifts that asked for it" do
      _household, wishlist, = build_list(asking: [])
      line = build_line_item(wishlist: wishlist, catalog_item: @blocks, price_in_cents: 3_500)

      assert_difference -> { CatalogItem.count }, -1 do
        delete admin_catalog_item_path(@blocks)
      end

      assert_redirected_to admin_catalog_items_path
      assert LineItem.exists?(line.id)
    end

    private

    def png_upload
      Rack::Test::UploadedFile.new(StringIO.new(PNG), "image/png", original_filename: "gift.png")
    end
  end
end
