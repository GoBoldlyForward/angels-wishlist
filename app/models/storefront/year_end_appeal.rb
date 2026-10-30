# frozen_string_literal: true

module Storefront
  # The chapter's year-end appeal, shown once at checkout: what the year has
  # looked like so far, and the gifts a donor can add on top of the lists.
  class YearEndAppeal
    Stat = Data.define(:figure, :label)
    Tier = Data.define(:dollars, :title, :teaser, :body) do
      def cents
        dollars * 100
      end

      # The top tier reads as a floor, not a price.
      def amount_label
        label = ActiveSupport::NumberHelper.number_to_currency(dollars, precision: 0)
        open_ended? ? "#{label}+" : label
      end

      def open_ended?
        dollars >= 5_000
      end
    end

    PERIOD = "January through June 2026"
    SOURCE_URL = "https://heyzine.com/flip-book/7c3a3be980.html"

    # Atlanta Angels' 2026 mid-year impact snapshot.
    STATS = [
      Stat.new(figure: "163", label: "kids matched in Love Box®"),
      Stat.new(figure: "62", label: "youth matched in Dare to Dream®"),
      Stat.new(figure: "92", label: "families supported"),
      Stat.new(figure: "98%", label: "foster parent retention")
    ].freeze

    TIERS = [
      Tier.new(dollars: 50, title: "A choice of their own",
               teaser: "A favorite color. The perfect fit. A pair that feels like them.",
               body: "Your gift can provide new shoes for a child experiencing foster care, with the freedom to " \
                     "choose their own."),
      Tier.new(dollars: 100, title: "A place at the table",
               teaser: "A birthday dinner. An adoption celebration. A graduation worth gathering for.",
               body: "Your gift can help fund a celebration meal through Love Box®, making room for families to " \
                     "mark the moments that matter."),
      Tier.new(dollars: 250, title: "Their day, remembered",
               teaser: "Someone remembered. Someone chose something just for them.",
               body: "Your gift can provide personalized birthday gifts for 25 children experiencing foster care."),
      Tier.new(dollars: 500, title: "Someone to call",
               teaser: "For the good news. The hard days. The questions that can’t wait.",
               body: "Your gift can help launch a new Dare to Dream® match, connecting a young person approaching " \
                     "adulthood with a trained mentor and beginning a relationship built on consistent support."),
      Tier.new(dollars: 1_000, title: "Support when it matters",
               teaser: "Groceries in the kitchen. A way to get to work. Help keeping rent paid.",
               body: "Your gift can help meet five urgent needs for young adults who have aged out of foster care."),
      Tier.new(dollars: 2_500, title: "Someone who shows up",
               teaser: "Support becomes personal when someone learns your family’s names, understands your needs, " \
                       "and keeps coming back.",
               body: "Your gift can help match five foster families with consistent, practical support through " \
                     "the Love Box® program."),
      Tier.new(dollars: 5_000, title: "A year of showing up",
               teaser: "Growing into adulthood takes time. Having someone beside you matters.",
               body: "Your gift can fund a year of dedicated Dare to Dream® mentorship and case management " \
                     "support for a young person aging out of foster care.")
    ].freeze

    def initialize(chapter:)
      @name = chapter&.name || "Atlanta Angels"
    end

    def headline
      "The lists are for December. #{@name} is there all year."
    end

    def lede
      "Everything in your cart is designated to the holiday wish list program. A year-end gift goes directly " \
        "to #{@name} and funds the rest of the work: Love Box® families, Dare to Dream® mentors, and the " \
        "urgent needs that come up between holidays. Here is what that looked like in the first half of 2026."
    end

    def period
      PERIOD
    end

    def source_url
      SOURCE_URL
    end

    def stats
      STATS
    end

    def tiers
      TIERS
    end

    def tier_for(cents)
      TIERS.find { |tier| tier.cents == cents }
    end
  end
end
