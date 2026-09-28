# frozen_string_literal: true

module Admin
  # Whether a giver is a person, a family, or a group, read off their name.
  class DonorType
    GROUP_WORDS = "group|team|rotary|crew|church|club|chapter|company|foundation"
    FAMILY_WORDS = "family|household"
    NAME_SQL = "concat_ws(' ', users.first_name, users.last_name)"
    LABELS = { "individual" => "Individual", "family" => "Family", "group" => "Group or team" }.freeze

    attr_reader :key

    def initialize(key)
      @key = key
    end

    def label
      LABELS.fetch(key)
    end

    def self.for(name)
      return new("group") if name.to_s.match?(/#{GROUP_WORDS}/i)

      new(name.to_s.match?(/#{FAMILY_WORDS}/i) ? "family" : "individual")
    end

    # The name as typed, never the email that User#full_name falls back to.
    def self.of(user)
      self.for([ user.first_name, user.last_name ].compact_blank.join(" "))
    end

    def self.narrow(users, key)
      case key
      when "group" then users.where("#{NAME_SQL} ~* ?", GROUP_WORDS)
      when "family" then users.where("#{NAME_SQL} !~* ? AND #{NAME_SQL} ~* ?", GROUP_WORDS, FAMILY_WORDS)
      else users.where("#{NAME_SQL} !~* ?", "#{GROUP_WORDS}|#{FAMILY_WORDS}")
      end
    end
  end
end
