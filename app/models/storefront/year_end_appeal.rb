# frozen_string_literal: true

module Storefront
  # The chapter's year-end appeal, shown once at checkout: what the year has
  # looked like so far, and the gifts a donor can add on top of the lists.
  # Staff edit it under Setup; a field they have never saved falls back to this.
  class YearEndAppeal
    Stat = Data.define(:figure, :label)
    Tier = Data.define(:dollars, :title, :teaser, :body, :open_ended) do
      def cents
        dollars * 100
      end

      # The top tier reads as a floor, not a price.
      def amount_label
        label = ActiveSupport::NumberHelper.number_to_currency(dollars, precision: 0)
        open_ended ? "#{label}+" : label
      end
    end

    TEXT_FIELDS = %w[headline lede period source_label source_url].freeze

    # Atlanta Angels' 2026 mid-year impact snapshot.
    STATS = [
      { "figure" => "163", "label" => "kids matched in Love Box®" },
      { "figure" => "62", "label" => "youth matched in Dare to Dream®" },
      { "figure" => "92", "label" => "families supported" },
      { "figure" => "98%", "label" => "foster parent retention" }
    ].freeze

    TIERS = [
      { "dollars" => 50, "title" => "A choice of their own",
        "teaser" => "A favorite color. The perfect fit. A pair that feels like them.",
        "body" => "Your gift can provide new shoes for a child experiencing foster care, with the freedom to " \
                  "choose their own." },
      { "dollars" => 100, "title" => "A place at the table",
        "teaser" => "A birthday dinner. An adoption celebration. A graduation worth gathering for.",
        "body" => "Your gift can help fund a celebration meal through Love Box®, making room for families to " \
                  "mark the moments that matter." },
      { "dollars" => 250, "title" => "Their day, remembered",
        "teaser" => "Someone remembered. Someone chose something just for them.",
        "body" => "Your gift can provide personalized birthday gifts for 25 children experiencing foster care." },
      { "dollars" => 500, "title" => "Someone to call",
        "teaser" => "For the good news. The hard days. The questions that can’t wait.",
        "body" => "Your gift can help launch a new Dare to Dream® match, connecting a young person approaching " \
                  "adulthood with a trained mentor and beginning a relationship built on consistent support." },
      { "dollars" => 1_000, "title" => "Support when it matters",
        "teaser" => "Groceries in the kitchen. A way to get to work. Help keeping rent paid.",
        "body" => "Your gift can help meet five urgent needs for young adults who have aged out of foster care." },
      { "dollars" => 2_500, "title" => "Someone who shows up",
        "teaser" => "Support becomes personal when someone learns your family’s names, understands your needs, " \
                    "and keeps coming back.",
        "body" => "Your gift can help match five foster families with consistent, practical support through " \
                  "the Love Box® program." },
      { "dollars" => 5_000, "title" => "A year of showing up",
        "teaser" => "Growing into adulthood takes time. Having someone beside you matters.",
        "body" => "Your gift can fund a year of dedicated Dare to Dream® mentorship and case management " \
                  "support for a young person aging out of foster care." }
    ].freeze

    def initialize(chapter:)
      @name = chapter&.name || "Atlanta Angels"
      @settings = defaults.merge((chapter&.year_end_appeal || {}).compact)
    end

    TEXT_FIELDS.each { |field| define_method(field) { @settings[field].to_s } }

    def stats
      Array(@settings["stats"]).map { |stat| Stat.new(figure: stat["figure"].to_s, label: stat["label"].to_s) }
    end

    # Smallest first. The largest reads as a floor.
    def tiers
      rows = Array(@settings["tiers"]).sort_by { |tier| tier["dollars"].to_i }
      rows.map.with_index do |tier, index|
        Tier.new(dollars: tier["dollars"].to_i, title: tier["title"].to_s, teaser: tier["teaser"].to_s,
                 body: tier["body"].to_s, open_ended: index == rows.size - 1)
      end
    end

    def tier_for(cents)
      tiers.find { |tier| tier.cents == cents }
    end

    def to_h
      @settings.deep_dup
    end

    def enabled?
      ActiveModel::Type::Boolean.new.cast(@settings["enabled"]) != false
    end

    private

    def defaults
      {
        "enabled" => true,
        "headline" => "The lists are for December. #{@name} is there all year.",
        "lede" => "Your cart is designated to the wish list program. A year-end gift goes directly to #{@name} " \
                  "and carries the rest of the work: Love Box® families, Dare to Dream® mentors, and urgent " \
                  "needs between holidays.",
        "period" => "January through June 2026",
        "source_label" => "#{@name}' mid-year impact snapshot",
        "source_url" => "https://heyzine.com/flip-book/7c3a3be980.html",
        "stats" => STATS,
        "tiers" => TIERS
      }
    end
  end
end
