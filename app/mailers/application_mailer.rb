class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAIL_FROM", "Wish List <wishlist@example.org>") }
  layout "mailer"

  private

  # A chapter sends as itself once its address is verified with the mail provider.
  def from_chapter(chapter)
    chapter&.mail_from.presence || self.class.default[:from].call
  end
end
