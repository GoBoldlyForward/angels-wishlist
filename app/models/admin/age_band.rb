# frozen_string_literal: true

module Admin
  # Age is read off the birthdate, so a band of ages is a range of birthdates.
  module AgeBand
    OPTIONS = { "0 to 5" => "0-5", "6 to 11" => "6-11", "12 to 18" => "12-18" }.freeze

    module_function

    def birthdates(band, today = Date.current)
      youngest, oldest = band.split("-").map(&:to_i)
      (today.advance(years: -(oldest + 1)) + 1.day)..today.advance(years: -youngest)
    end

    # rows must already join children.
    def narrow(rows, band)
      rows.where(children: { birthdate: birthdates(band) })
    end
  end
end
