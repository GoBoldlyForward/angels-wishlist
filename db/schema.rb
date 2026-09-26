# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_26_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "addresses", force: :cascade do |t|
    t.string "city"
    t.string "country", default: "US", null: false
    t.datetime "created_at", null: false
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.string "state"
    t.string "street_line_1"
    t.string "street_line_2"
    t.datetime "updated_at", null: false
    t.string "zipcode"
  end

  create_table "ahoy_events", force: :cascade do |t|
    t.string "name"
    t.jsonb "properties"
    t.datetime "time"
    t.bigint "user_id"
    t.bigint "visit_id"
    t.index ["name", "time"], name: "index_ahoy_events_on_name_and_time"
    t.index ["properties"], name: "index_ahoy_events_on_properties", opclass: :jsonb_path_ops, using: :gin
    t.index ["user_id"], name: "index_ahoy_events_on_user_id"
    t.index ["visit_id"], name: "index_ahoy_events_on_visit_id"
  end

  create_table "ahoy_visits", force: :cascade do |t|
    t.string "app_version"
    t.string "browser"
    t.string "city"
    t.string "country"
    t.string "device_type"
    t.string "ip"
    t.text "landing_page"
    t.float "latitude"
    t.float "longitude"
    t.string "os"
    t.string "os_version"
    t.string "platform"
    t.text "referrer"
    t.string "referring_domain"
    t.string "region"
    t.datetime "started_at"
    t.text "user_agent"
    t.bigint "user_id"
    t.string "utm_campaign"
    t.string "utm_content"
    t.string "utm_medium"
    t.string "utm_source"
    t.string "utm_term"
    t.string "visit_token"
    t.string "visitor_token"
    t.index ["user_id"], name: "index_ahoy_visits_on_user_id"
    t.index ["visit_token"], name: "index_ahoy_visits_on_visit_token", unique: true
    t.index ["visitor_token", "started_at"], name: "index_ahoy_visits_on_visitor_token_and_started_at"
  end

  create_table "catalog_items", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "icon"
    t.integer "max_age"
    t.integer "min_age"
    t.string "name", null: false
    t.string "photo_attribution"
    t.integer "price_in_cents", null: false
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_catalog_items_on_active"
    t.index ["category_id"], name: "index_catalog_items_on_category_id"
    t.index ["deleted_at"], name: "index_catalog_items_on_deleted_at"
    t.index ["slug"], name: "index_catalog_items_on_slug", unique: true
  end

  create_table "categories", force: :cascade do |t|
    t.text "blurb"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "headline"
    t.string "icon"
    t.string "name", null: false
    t.integer "position"
    t.string "slug"
    t.string "tint"
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_categories_on_deleted_at"
    t.index ["position"], name: "index_categories_on_position"
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "children", force: :cascade do |t|
    t.datetime "archived_at"
    t.date "birthdate"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "display_name", null: false
    t.string "gender"
    t.bigint "household_id", null: false
    t.string "legal_first_name"
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_children_on_deleted_at"
    t.index ["household_id"], name: "index_children_on_household_id"
  end

  create_table "donations", force: :cascade do |t|
    t.bigint "ahoy_visit_id"
    t.boolean "anonymous", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "display_name"
    t.bigint "donor_id", null: false
    t.bigint "event_id", null: false
    t.integer "fee_in_cents", default: 0, null: false
    t.integer "general_gift_in_cents", default: 0, null: false
    t.integer "gift_in_cents", default: 0, null: false
    t.datetime "note_approved_at"
    t.text "note_to_family"
    t.string "payment_method_label"
    t.datetime "receipt_sent_at"
    t.string "status", default: "pending", null: false
    t.bigint "storefront_organization_id"
    t.string "stripe_payment_intent_id"
    t.datetime "updated_at", null: false
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.index ["ahoy_visit_id"], name: "index_donations_on_ahoy_visit_id"
    t.index ["deleted_at"], name: "index_donations_on_deleted_at"
    t.index ["donor_id"], name: "index_donations_on_donor_id"
    t.index ["event_id"], name: "index_donations_on_event_id"
    t.index ["status"], name: "index_donations_on_status"
    t.index ["storefront_organization_id"], name: "index_donations_on_storefront_organization_id"
    t.index ["stripe_payment_intent_id"], name: "index_donations_on_stripe_payment_intent_id", unique: true
    t.index ["uuid"], name: "index_donations_on_uuid", unique: true
  end

  create_table "events", force: :cascade do |t|
    t.datetime "closes_at"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "name", null: false
    t.datetime "opened_at"
    t.bigint "organization_id", null: false
    t.datetime "payout_at"
    t.integer "per_child_cap_in_cents", default: 30000, null: false
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_events_on_deleted_at"
    t.index ["organization_id"], name: "index_events_on_organization_id"
    t.index ["slug"], name: "index_events_on_slug", unique: true
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.datetime "created_at"
    t.string "scope"
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "households", force: :cascade do |t|
    t.bigint "ahoy_visit_id"
    t.datetime "archived_at"
    t.bigint "caregiver_id", null: false
    t.string "county"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "display_name", null: false
    t.text "hold_reason"
    t.bigint "mailing_address_id"
    t.bigint "organization_id", null: false
    t.string "payout_method", default: "none", null: false
    t.bigint "placing_organization_id"
    t.string "slug"
    t.string "stripe_account_id"
    t.datetime "updated_at", null: false
    t.string "verification_status", default: "pending", null: false
    t.datetime "verified_at"
    t.index ["ahoy_visit_id"], name: "index_households_on_ahoy_visit_id"
    t.index ["caregiver_id"], name: "index_households_on_caregiver_id"
    t.index ["deleted_at"], name: "index_households_on_deleted_at"
    t.index ["mailing_address_id"], name: "index_households_on_mailing_address_id"
    t.index ["organization_id"], name: "index_households_on_organization_id"
    t.index ["placing_organization_id"], name: "index_households_on_placing_organization_id"
    t.index ["slug"], name: "index_households_on_slug", unique: true
    t.index ["verification_status"], name: "index_households_on_verification_status"
  end

  create_table "line_items", force: :cascade do |t|
    t.bigint "catalog_item_id"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.bigint "donation_id"
    t.string "link_url"
    t.string "name", null: false
    t.integer "price_in_cents", null: false
    t.string "spec"
    t.string "status", default: "open", null: false
    t.datetime "updated_at", null: false
    t.bigint "wishlist_id", null: false
    t.index ["catalog_item_id"], name: "index_line_items_on_catalog_item_id"
    t.index ["deleted_at"], name: "index_line_items_on_deleted_at"
    t.index ["donation_id"], name: "index_line_items_on_donation_id"
    t.index ["status"], name: "index_line_items_on_status"
    t.index ["wishlist_id"], name: "index_line_items_on_wishlist_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "co_brand_line"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "kind", default: "chapter", null: false
    t.bigint "mailing_address_id"
    t.string "name", null: false
    t.bigint "parent_id"
    t.bigint "primary_contact_id"
    t.string "short_name"
    t.string "slug"
    t.string "stripe_account_id"
    t.jsonb "theme", default: {}, null: false
    t.datetime "updated_at", null: false
    t.string "website_url"
    t.index ["deleted_at"], name: "index_organizations_on_deleted_at"
    t.index ["kind"], name: "index_organizations_on_kind"
    t.index ["mailing_address_id"], name: "index_organizations_on_mailing_address_id"
    t.index ["parent_id"], name: "index_organizations_on_parent_id"
    t.index ["primary_contact_id"], name: "index_organizations_on_primary_contact_id"
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "payouts", force: :cascade do |t|
    t.text "adjustment_note"
    t.integer "amount_in_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.bigint "event_id", null: false
    t.string "gift_card_tracking_number"
    t.text "hold_reason"
    t.bigint "household_id", null: false
    t.bigint "mailing_address_id"
    t.string "method", default: "stripe", null: false
    t.datetime "scheduled_for"
    t.datetime "sent_at"
    t.string "status", default: "blocked", null: false
    t.string "stripe_transfer_id"
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_payouts_on_deleted_at"
    t.index ["event_id"], name: "index_payouts_on_event_id"
    t.index ["household_id", "event_id"], name: "index_payouts_on_household_id_and_event_id", unique: true
    t.index ["household_id"], name: "index_payouts_on_household_id"
    t.index ["mailing_address_id"], name: "index_payouts_on_mailing_address_id"
    t.index ["status"], name: "index_payouts_on_status"
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.string "var", null: false
    t.index ["var"], name: "index_settings_on_var", unique: true
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.integer "completed_jobs", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.datetime "enqueued_at"
    t.datetime "failed_at"
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "finished_at"
    t.text "metadata"
    t.text "on_failure"
    t.text "on_finish"
    t.text "on_success"
    t.integer "total_jobs", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.bigint "batch_id"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.bigint "ahoy_visit_id"
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.datetime "deleted_at"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name"
    t.boolean "is_admin", default: false, null: false
    t.string "last_name"
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.bigint "organization_id"
    t.string "phone"
    t.string "preferred_language"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "donor", null: false
    t.integer "sign_in_count", default: 0, null: false
    t.string "slug"
    t.datetime "updated_at", null: false
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.index ["ahoy_visit_id"], name: "index_users_on_ahoy_visit_id"
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["slug"], name: "index_users_on_slug", unique: true
    t.index ["uuid"], name: "index_users_on_uuid", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.jsonb "object_changes"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  create_table "wishlists", force: :cascade do |t|
    t.datetime "approved_at"
    t.text "caregiver_note"
    t.bigint "child_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.bigint "event_id", null: false
    t.string "interests", default: [], null: false, array: true
    t.string "slug"
    t.string "status", default: "draft", null: false
    t.datetime "submitted_at"
    t.datetime "updated_at", null: false
    t.index ["child_id", "event_id"], name: "index_wishlists_on_child_id_and_event_id", unique: true
    t.index ["child_id"], name: "index_wishlists_on_child_id"
    t.index ["deleted_at"], name: "index_wishlists_on_deleted_at"
    t.index ["event_id"], name: "index_wishlists_on_event_id"
    t.index ["slug"], name: "index_wishlists_on_slug", unique: true
    t.index ["status"], name: "index_wishlists_on_status"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "catalog_items", "categories"
  add_foreign_key "children", "households"
  add_foreign_key "donations", "events"
  add_foreign_key "donations", "organizations", column: "storefront_organization_id"
  add_foreign_key "donations", "users", column: "donor_id"
  add_foreign_key "events", "organizations"
  add_foreign_key "households", "addresses", column: "mailing_address_id"
  add_foreign_key "households", "organizations"
  add_foreign_key "households", "organizations", column: "placing_organization_id"
  add_foreign_key "households", "users", column: "caregiver_id"
  add_foreign_key "line_items", "catalog_items"
  add_foreign_key "line_items", "donations"
  add_foreign_key "line_items", "wishlists"
  add_foreign_key "organizations", "addresses", column: "mailing_address_id"
  add_foreign_key "organizations", "organizations", column: "parent_id"
  add_foreign_key "organizations", "users", column: "primary_contact_id"
  add_foreign_key "payouts", "addresses", column: "mailing_address_id"
  add_foreign_key "payouts", "events"
  add_foreign_key "payouts", "households"
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "users", "organizations"
  add_foreign_key "wishlists", "children"
  add_foreign_key "wishlists", "events"
end
