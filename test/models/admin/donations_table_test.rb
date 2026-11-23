# frozen_string_literal: true

require "test_helper"

module Admin
  class DonationsTableTest < ActiveSupport::TestCase
    test "Came through offers only the chapter's own partners" do
      chapter = build_organization
      passion = build_organization(name: "Passion City Church", short_name: "Passion", kind: "partner", parent: chapter)
      build_organization(name: "Fulton DFCS", kind: "agency", parent: chapter)
      elsewhere = build_organization(name: "Cross Point Church", kind: "partner", parent: build_organization)

      params = ActionController::Parameters.new(f: { through: elsewhere.id.to_s })
      table = DonationsTable.new(build_event(organization: chapter), params)
      came_through = table.filters.find { |filter| filter.key == "through" }

      assert_equal({ "Passion" => passion.id }, came_through.options)
      assert_nil table.filter_value(came_through)
    end
  end
end
