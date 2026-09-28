# frozen_string_literal: true

module Admin
  # Forms take dollars and the database holds cents.
  module Dollars
    module_function

    def to_cents(dollars)
      cleaned = dollars.to_s.delete("$, ")
      return nil if cleaned.empty?

      (BigDecimal(cleaned) * 100).round
    rescue ArgumentError
      nil
    end

    def from_cents(cents)
      return nil if cents.nil?

      (cents % 100).zero? ? (cents / 100).to_s : format("%.2f", cents / 100.0)
    end
  end
end
