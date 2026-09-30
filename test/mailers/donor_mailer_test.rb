# frozen_string_literal: true

require "test_helper"

class DonorMailerTest < ActionMailer::TestCase
  test "a receipt comes from the chapter and names its legal name and EIN" do
    chapter = build_organization(name: "Nashville Angels", legal_name: "Nashville Angels, Inc.", ein: "62-1234567",
                                 mail_from: "Nashville Angels <wishlist@nashvilleangels.example>")
    donation = build_donation(event: build_event(organization: chapter))

    mail = DonorMailer.receipt(donation)

    assert_equal [ "wishlist@nashvilleangels.example" ], mail.from
    assert_equal "Your receipt from Nashville Angels", mail.subject
    assert_match(/Nashville Angels, Inc\. is a 501\(c\)\(3\), EIN 62-1234567\./, mail.body.to_s)
  end

  test "a chapter with no sending address of its own uses the application's" do
    donation = build_donation(event: build_event)

    assert_equal [ "wishlist@example.org" ], DonorMailer.receipt(donation).from
  end
end
