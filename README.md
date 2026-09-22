# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

## Soft delete

Models that soft-delete declare `acts_as_paranoid` and carry a `deleted_at` column with an index.

`deleted_at` means gone. `archived_at` means hidden but still real. They are different states and
most models want both: a household that left the program is archived, a household created by
mistake is deleted.
