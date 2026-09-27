class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAIL_FROM", "Atlanta Angels Wish List <wishlist@example.org>") }
  layout "mailer"
end
