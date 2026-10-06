# frozen_string_literal: true

class SendGiftCardsByEmail < ActiveRecord::Migration[8.0]
  def change
    add_column :households, :gift_card_email, :string
    add_column :payouts, :gift_card_email, :string
    rename_column :payouts, :gift_card_tracking_number, :gift_card_order_id
    remove_reference :households, :mailing_address, foreign_key: { to_table: :addresses }, index: true
    remove_reference :payouts, :mailing_address, foreign_key: { to_table: :addresses }, index: true
  end
end
