# frozen_string_literal: true

module Storefront
  # The words the shopping metaphor cannot carry: this is a donation, the money
  # is pooled, and what donors read about a child comes from the caregiver.
  class Content
    Reason = Data.define(:icon, :title, :body)
    Question = Data.define(:question, :answer, :link) do
      def initialize(question:, answer:, link: nil)
        super
      end
    end
    Link = Data.define(:label, :path)
    Step = Data.define(:title, :body)

    GENERAL_GIFT_PRESETS_IN_DOLLARS = [ 25, 50, 100, 250 ].freeze

    # year_end_path is the chapter's year-end giving page, or nil while its appeal is switched off.
    def initialize(chapter:, event:, year_end_path: nil)
      @name = chapter&.name || "Wish List"
      @event = event
      @year_end_path = year_end_path
    end

    def reasons
      [
        Reason.new(icon: "fa-arrows-rotate", title: "Kids change fast, lists cannot keep up",
                   body: "A coat that fit in October does not fit in January. Interests move on. The caregiver " \
                         "buys at the moment the child actually needs it, in the right size, in the color " \
                         "they want."),
        Reason.new(icon: "fa-hand-holding-heart", title: "The caregiver is the expert",
                   body: "They know the sensory stuff, the sizes, what already came from a case worker, and " \
                         "what is sitting unopened in a closet. They wrote every line on this site, and " \
                         "leaving the final call with them is the point, not a shortcut."),
        Reason.new(icon: "fa-truck-fast", title: "No warehouse, no sorting weekend",
                   body: "Physical gift drives cost a nonprofit storage, volunteers, drivers, and duplicates. " \
                         "Every dollar of that is a dollar that never reaches a child. This program runs on " \
                         "a spreadsheet and a payout."),
        Reason.new(icon: "fa-eye", title: "You still see what your gift did",
                   body: "You chose the science kit on Nia's list. Your receipt shows that, and in January you " \
                         "receive an impact statement showing exactly how your support funded holiday gifts " \
                         "for kids.")
      ]
    end

    def steps
      [
        Step.new(title: "You check out",
                 body: "Your card is charged by #{@name}. You get an itemized receipt showing what you chose."),
        Step.new(title: "The list closes",
                 body: "#{closing_day.upcase_first} we total everything raised for the lists and spread it " \
                       "evenly across every child's list, so each one is funded to the same share."),
        Step.new(title: "The household is paid",
                 body: "Funds land in their bank account in one to two days through Stripe, or on a Visa gift " \
                       "card if they cannot use a bank."),
        Step.new(title: "They shop",
                 body: "The caregiver gets the joy of shopping for their kids, and makes sure they get exactly " \
                       "what they want and what fits in that moment."),
        Step.new(title: "You hear back",
                 body: "A thank-you and an impact statement from #{@name} in January. For privacy, you will " \
                       "not receive photos of kids' faces.")
      ]
    end

    def checkout_steps
      [
        Step.new(title: "Pooled, then shared evenly",
                 body: "Everything raised for the lists is pooled and spread evenly across every child's " \
                       "list, so every list is funded to the same share."),
        Step.new(title: "Paid, not shipped",
                 body: "#{@name} pays each verified household its share. No warehouse in between."),
        Step.new(title: "Spent by the family",
                 body: "Their caregiver shops for what fits by the time the holidays arrive.")
      ]
    end

    def faqs
      [
        Question.new(
          question: "Am I actually buying this gift?",
          answer: "No. You are making a donation to #{@name} in the amount of the gift you picked. Everything " \
                  "raised for the lists is pooled and spread evenly across every child's list, and each " \
                  "household is paid its share so the caregiver can do the shopping. Nothing ships from us, " \
                  "no merchant is involved, and the tile you clicked is a wish a caregiver typed in, not " \
                  "inventory."
        ),
        Question.new(
          question: "So where does my money actually go?",
          answer: "To #{@name}, a 501(c)(3), as a charitable donation. We pool wish list gifts together, " \
                  "spread the total evenly across every child's list, and pay each household its share. " \
                  "#{"A year-end gift is separate and stays out of the pool. " if year_end?}As with any gift " \
                  "to a nonprofit, #{@name} holds final discretion over how the funds are used, which is " \
                  "what the IRS requires in order for your gift to be tax-deductible. If a child leaves a " \
                  "placement or a household withdraws, their share moves to the other lists rather than " \
                  "back to you."
        ),
        *year_end_faqs,
        Question.new(
          question: "Where does the information about each child come from?",
          answer: "Their caregiver, directly. The age, the interests, the one-line note, and every gift on the " \
                  "list are typed in by the person raising that child. We confirm the placement with the " \
                  "agency or DFCS office and read each list before it goes live, but we do not write or " \
                  "embellish what a caregiver tells us. If something looks off, we call them. We work hard " \
                  "to keep what you see aligned with the child it describes, and we will not pretend to more " \
                  "certainty than that."
        ),
        Question.new(
          question: "How do you know the money is spent on the child?",
          answer: "We work directly and personally with each family whose lists you see. Our Program " \
                  "Coordinators are in frequent contact with them, and we have built relationships with " \
                  "them. We trust them and are empowering them with this opportunity. When they accept the " \
                  "funds, they agree to use them for the purpose described."
        ),
        Question.new(
          question: "What if the gift I funded is not what the child needs by December?",
          answer: "Their caregiver buys what does fit. That is the entire reason this program sends money " \
                  "instead of merchandise. A coat that fit in October does not fit in January, an " \
                  "eight-year-old's favorite thing changes twice before Christmas, and the caregiver is the " \
                  "only person in the room who knows that."
        ),
        Question.new(
          question: "Five kids want the same thing. Am I funding all of them?",
          answer: "Only the number you choose. Items that more than one child asked for are grouped, so a " \
                  "hoodie that four children want shows up once with four still needed. You pick a " \
                  "quantity, and each one you fund shows on your receipt. When a caregiver asked for a " \
                  "particular brand or size, that request is listed separately so you can fund exactly " \
                  "that one."
        ),
        Question.new(
          question: "What happens if a list is not fully funded?",
          answer: "The household still receives its share. We spread everything raised for the lists evenly " \
                  "across every child's list, so each one is funded to the same percentage. If every child " \
                  "asked for $200 and donors covered 75 percent of the total, every child's list receives " \
                  "$150. We do not hold funds back waiting for a list to complete."
        ),
        Question.new(
          question: "Is my gift tax-deductible?",
          answer: "Yes#{", for wish list gifts and year-end gifts alike" if year_end?}. #{@name} is a " \
                  "registered 501(c)(3), and you will get an itemized receipt by email. No goods or services " \
                  "are provided to you in exchange, which is the other reason the money has to be a donation " \
                  "to us rather than a purchase from a family."
        ),
        Question.new(
          question: "What will I hear back?",
          answer: "A thank-you and an impact statement from #{@name} in January. For privacy reasons you " \
                  "will not receive any personal details or photos of children's faces. The names on this " \
                  "site are stand-ins that #{@name} assigns for exactly that reason."
        ),
        Question.new(
          question: "Why not just collect the actual gifts?",
          answer: "We have in the past. We found that the lists provided in September often no longer " \
                  "reflect the child's wishes or needs in December, and that purchasing and providing the " \
                  "gifts directly takes away the joy of shopping from the caregiver. As we have grown, it " \
                  "also pulls too many resources away from our primary programs and is not scalable: " \
                  "hundreds of hours of additional staff and administrative time. We want to steward funds " \
                  "and time in the way that is most mission-aligned and impactful for the families we " \
                  "support."
        )
      ]
    end

    def closing_date
      @event&.closes_at&.strftime("%B %-d")
    end

    private

    def closing_day
      closing_date ? "on #{closing_date}" : "when the lists close"
    end

    def year_end?
      @year_end_path.present?
    end

    # What a year-end gift is, asked only while the chapter's appeal is on.
    def year_end_faqs
      return [] unless year_end?

      [
        Question.new(
          question: "What is a year-end gift?",
          answer: "A gift directly to #{@name}, separate from the wish lists. It does not join the wish list " \
                  "pool or go to any one child's list. It carries the rest of our work through the year, like " \
                  "supporting our Love Box® and Dare to Dream® programs, urgent needs between holidays, " \
                  "supplemental support for our families and youth, and other general operations. You can " \
                  "add one at checkout, or give one on its own.",
          link: Link.new(label: "Give a year-end gift", path: @year_end_path)
        ),
        Question.new(
          question: "How is that different from \"Give any amount\"?",
          answer: "\"Give any amount\" goes into the wish list pool and is spread evenly across every child's " \
                  "list. Your receipt calls it \"Where it is needed most.\" A year-end gift supports #{@name}' " \
                  "year-round programs and operations and stays out of the wish list pool, ensuring we can " \
                  "support our kids and families all year long, not just at the holidays. You can give " \
                  "either one or both, and your receipt lists each one on its own line."
        ),
        Question.new(
          question: "Will my year-end gift pay for the exact thing at the level I chose?",
          answer: "The levels show what a gift of that size can do, such as new shoes for a child or a new " \
                  "mentor match. A year-end gift is unrestricted, so #{@name} decides how it is used."
        )
      ]
    end
  end
end
