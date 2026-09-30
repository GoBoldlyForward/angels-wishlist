# frozen_string_literal: true

require "test_helper"

module Storefront
  class ContentTest < ActiveSupport::TestCase
    NEVER_SAID = [
      /send that\s+amount to the child's household/i, /aliases each caregiver\s+chose/i, /caregiver chose/i,
      /furthest-behind/i, /closest-to-complete/i, /note (back )?from the household/i, /reaches the household/i,
      /recorded, not pooled/i, /prototype/i, /thank-you card/i
    ].freeze

    setup do
      @event = build_event(closes_at: Time.zone.local(2027, 1, 9, 23))
      @content = Content.new(chapter: @event.organization, event: @event)
    end

    test "it carries the ten questions, four reasons, and five steps" do
      assert_equal 10, @content.faqs.size
      assert_equal 4, @content.reasons.size
      assert_equal 5, @content.steps.size
      assert_equal 3, @content.checkout_steps.size
    end

    test "none of it says what the program no longer does" do
      words = (@content.faqs.flat_map { |faq| [ faq.question, faq.answer ] } +
               @content.reasons.flat_map { |reason| [ reason.title, reason.body ] } +
               (@content.steps + @content.checkout_steps).flat_map { |step| [ step.title, step.body ] }).join(" ")

      NEVER_SAID.each { |phrase| assert_no_match phrase, words }
      assert_match(/pooled and spread evenly across every child's list/, words)
      assert_match(/A thank-you and an impact statement from #{@event.organization.name} in January/, words)
      assert_match(/stand-ins that #{@event.organization.name} assigns/, words)
    end

    test "the closing step uses the event's own date" do
      assert_match(/\AOn January 9 we total everything raised/, @content.steps.second.body)
    end

    test "with no event the closing step still reads as a sentence" do
      content = Content.new(chapter: nil, event: nil)

      assert_match(/\AWhen the lists close we total everything raised/, content.steps.second.body)
      assert_match(/charged by Wish List/, content.steps.first.body)
    end
  end
end
