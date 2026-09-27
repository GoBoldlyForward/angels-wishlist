# frozen_string_literal: true

class AddReviewNoteToWishlists < ActiveRecord::Migration[8.1]
  def change
    add_column :wishlists, :review_note, :text
  end
end
