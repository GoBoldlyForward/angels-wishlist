# frozen_string_literal: true

module Admin
  # A form over one record, for fields the record stores in another shape:
  # dollars held as cents, a list held as JSON.
  class RecordForm
    include ActiveModel::Model

    attr_reader :record

    delegate :persisted?, :new_record?, :to_param, :to_key, :id, to: :record

    def initialize(record, params = {})
      @record = record
      @params = params.to_h.with_indifferent_access
      assign
    end

    def save
      check
      return false if errors.any?
      return true if record.save

      record.errors.each { |error| errors.add(:base, error.full_message) }
      false
    end

    private

    def assign
      record.assign_attributes(@params.slice(*self.class::PASSED_THROUGH))
    end

    def check
    end
  end
end
