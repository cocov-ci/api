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

ActiveRecord::Schema[7.0].define(version: 2023_04_15_014042) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_trgm"
  enable_extension "plpgsql"

  create_table "branches", force: :cascade do |t|
    t.bigint "repository_id", null: false
    t.citext "name", null: false
    t.integer "issues"
    t.integer "coverage"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "head_id"
    t.index ["head_id"], name: "index_branches_on_head_id"
    t.index ["repository_id", "name"], name: "index_branches_on_repository_id_and_name", unique: true
    t.index ["repository_id"], name: "index_branches_on_repository_id"
  end

  create_table "cache_artifacts", force: :cascade do |t|
    t.bigint "repository_id", null: false
    t.citext "name", null: false
    t.string "name_hash", null: false
    t.bigint "size", null: false
    t.datetime "last_used_at", precision: nil
    t.citext "engine", null: false
    t.string "mime", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_cache_artifacts_on_name"
    t.index ["name_hash"], name: "index_cache_artifacts_on_name_hash"
    t.index ["repository_id", "name", "engine"], name: "index_cache_artifacts_on_repository_id_and_name_and_engine", unique: true
    t.index ["repository_id", "name_hash", "engine"], name: "index_cache_artifacts_on_repository_id_and_name_hash_and_engine", unique: true
    t.index ["repository_id"], name: "index_cache_artifacts_on_repository_id"
  end

  create_table "cache_tools", force: :cascade do |t|
    t.citext "name", null: false
    t.string "name_hash", null: false
    t.integer "size", null: false
    t.datetime "last_used_at", precision: nil
    t.citext "engine", null: false
    t.string "mime", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["engine"], name: "index_cache_tools_on_engine"
    t.index ["last_used_at"], name: "index_cache_tools_on_last_used_at"
    t.index ["name", "engine"], name: "index_cache_tools_on_name_and_engine", unique: true
    t.index ["name_hash", "engine"], name: "index_cache_tools_on_name_hash_and_engine", unique: true
    t.index ["name_hash"], name: "index_cache_tools_on_name_hash"
  end

  create_table "check_sets", force: :cascade do |t|
    t.bigint "commit_id", null: false
    t.integer "status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "finished_at", precision: nil
    t.datetime "started_at", precision: nil
    t.string "job_id"
    t.boolean "canceling", default: false, null: false
    t.integer "error_kind", default: 0, null: false
    t.string "error_extra"
    t.index ["commit_id"], name: "index_check_sets_on_commit_id", unique: true
    t.index ["job_id"], name: "index_check_sets_on_job_id", unique: true
  end

  create_table "checks", force: :cascade do |t|
    t.citext "plugin_name", null: false
    t.datetime "started_at", precision: nil
    t.datetime "finished_at", precision: nil
    t.integer "status", null: false
    t.text "error_output"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "check_set_id", null: false
    t.index ["check_set_id"], name: "index_checks_on_check_set_id"
    t.index ["plugin_name", "check_set_id"], name: "index_checks_on_plugin_name_and_check_set_id", unique: true
  end

  create_table "commits", force: :cascade do |t|
    t.bigint "repository_id", null: false
    t.citext "sha", null: false
    t.string "author_name", null: false
    t.string "author_email", null: false
    t.text "message", null: false
    t.bigint "user_id"
    t.integer "issues_count"
    t.integer "coverage_percent"
    t.integer "clone_status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "minimum_coverage"
    t.bigint "clone_size"
    t.index ["repository_id"], name: "index_commits_on_repository_id"
    t.index ["sha", "repository_id"], name: "index_commits_on_sha_and_repository_id", unique: true
    t.index ["sha"], name: "index_commits_on_sha"
    t.index ["user_id"], name: "index_commits_on_user_id"
  end

  create_table "coverage_files", force: :cascade do |t|
    t.bigint "coverage_info_id", null: false
    t.string "file", null: false
    t.integer "percent_covered", null: false
    t.binary "raw_data", null: false
    t.integer "lines_missed", null: false
    t.integer "lines_covered", null: false
    t.integer "lines_total", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["coverage_info_id"], name: "index_coverage_files_on_coverage_info_id"
  end

  create_table "coverage_histories", force: :cascade do |t|
    t.bigint "repository_id", null: false
    t.bigint "branch_id", null: false
    t.float "percentage", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_coverage_histories_on_branch_id"
    t.index ["created_at"], name: "index_coverage_histories_on_created_at"
    t.index ["repository_id"], name: "index_coverage_histories_on_repository_id"
  end

  create_table "coverage_infos", force: :cascade do |t|
    t.bigint "commit_id", null: false
    t.float "percent_covered"
    t.integer "lines_total"
    t.integer "lines_covered"
    t.integer "status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["commit_id"], name: "index_coverage_infos_on_commit_id", unique: true
  end

  create_table "issue_histories", force: :cascade do |t|
    t.bigint "repository_id", null: false
    t.bigint "branch_id", null: false
    t.integer "quantity", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_issue_histories_on_branch_id"
    t.index ["created_at"], name: "index_issue_histories_on_created_at"
    t.index ["repository_id"], name: "index_issue_histories_on_repository_id"
  end

  create_table "issue_ignore_rules", force: :cascade do |t|
    t.bigint "repository_id", null: false
    t.bigint "user_id", null: false
    t.string "reason"
    t.string "check_source", null: false
    t.string "file", null: false
    t.integer "kind", null: false
    t.integer "line_start", null: false
    t.integer "line_end", null: false
    t.string "message", null: false
    t.string "uid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["repository_id"], name: "index_issue_ignore_rules_on_repository_id"
    t.index ["uid", "repository_id"], name: "index_issue_ignore_rules_on_uid_and_repository_id", unique: true
    t.index ["uid"], name: "index_issue_ignore_rules_on_uid"
    t.index ["user_id"], name: "index_issue_ignore_rules_on_user_id"
  end

  create_table "issues", force: :cascade do |t|
    t.bigint "commit_id", null: false
    t.integer "kind", null: false
    t.string "file", null: false
    t.citext "uid", null: false
    t.integer "line_start", null: false
    t.integer "line_end", null: false
    t.string "message", null: false
    t.string "check_source", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "ignored_at", precision: nil
    t.integer "ignore_source"
    t.bigint "ignore_user_id"
    t.bigint "ignore_rule_id"
    t.string "ignore_user_reason"
    t.index ["commit_id"], name: "index_issues_on_commit_id"
    t.index ["ignore_rule_id"], name: "index_issues_on_ignore_rule_id"
    t.index ["ignore_user_id"], name: "index_issues_on_ignore_user_id"
    t.index ["ignored_at"], name: "index_issues_on_ignored_at"
    t.index ["uid", "commit_id"], name: "index_issues_on_uid_and_commit_id", unique: true
    t.index ["uid"], name: "index_issues_on_uid"
  end

  create_table "private_keys", force: :cascade do |t|
    t.integer "scope", null: false
    t.bigint "repository_id"
    t.citext "name", null: false
    t.binary "encrypted_key", null: false
    t.text "digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_private_keys_on_name"
    t.index ["repository_id"], name: "index_private_keys_on_repository_id"
    t.index ["scope", "name", "repository_id"], name: "index_private_keys_on_scope_and_name_and_repository_id", unique: true
    t.index ["scope"], name: "index_private_keys_on_scope"
  end

  create_table "repositories", force: :cascade do |t|
    t.citext "name", null: false
    t.text "description"
    t.citext "default_branch", null: false
    t.text "token", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "github_id", null: false
    t.integer "issue_ignore_rules_count", default: 0, null: false
    t.bigint "cache_size", default: 0, null: false
    t.bigint "commits_size", default: 0, null: false
    t.index ["github_id"], name: "index_repositories_on_github_id", unique: true
    t.index ["name"], name: "index_repositories_on_name", unique: true
    t.index ["token"], name: "index_repositories_on_token", unique: true
  end

  create_table "repository_members", force: :cascade do |t|
    t.bigint "repository_id", null: false
    t.integer "github_member_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "level", null: false
    t.index ["github_member_id"], name: "index_repository_members_on_github_member_id"
    t.index ["repository_id", "github_member_id"], name: "index_repository_members_on_repository_id_and_github_member_id", unique: true
    t.index ["repository_id"], name: "index_repository_members_on_repository_id"
  end

  create_table "secrets", force: :cascade do |t|
    t.integer "scope", null: false
    t.citext "name", null: false
    t.bigint "repository_id"
    t.binary "secure_data", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_used_at", precision: nil
    t.bigint "owner_id", null: false
    t.index ["name"], name: "index_secrets_on_name"
    t.index ["owner_id"], name: "index_secrets_on_owner_id"
    t.index ["repository_id"], name: "index_secrets_on_repository_id"
    t.index ["scope", "name", "repository_id"], name: "index_secrets_on_scope_and_name_and_repository_id", unique: true
    t.index ["scope"], name: "index_secrets_on_scope"
  end

  create_table "service_tokens", force: :cascade do |t|
    t.text "hashed_token", null: false
    t.text "description", null: false
    t.bigint "owner_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_used_at", precision: nil
    t.index ["hashed_token"], name: "index_service_tokens_on_hashed_token", unique: true
    t.index ["owner_id"], name: "index_service_tokens_on_owner_id"
  end

  create_table "user_emails", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.citext "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_user_emails_on_email", unique: true
    t.index ["user_id"], name: "index_user_emails_on_user_id"
  end

  create_table "user_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "kind", null: false
    t.text "hashed_token", null: false
    t.datetime "expires_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_used_at", precision: nil
    t.index ["hashed_token"], name: "index_user_tokens_on_hashed_token", unique: true
    t.index ["user_id"], name: "index_user_tokens_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.citext "login", null: false
    t.integer "github_id", null: false
    t.boolean "admin", default: false, null: false
    t.text "github_token", null: false
    t.text "avatar_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["github_id"], name: "index_users_on_github_id", unique: true
    t.index ["login"], name: "index_users_on_login", unique: true
  end

  add_foreign_key "branches", "commits", column: "head_id"
  add_foreign_key "branches", "repositories"
  add_foreign_key "cache_artifacts", "repositories"
  add_foreign_key "check_sets", "commits"
  add_foreign_key "checks", "check_sets"
  add_foreign_key "commits", "repositories"
  add_foreign_key "commits", "users"
  add_foreign_key "coverage_files", "coverage_infos"
  add_foreign_key "coverage_histories", "branches"
  add_foreign_key "coverage_histories", "repositories"
  add_foreign_key "coverage_infos", "commits"
  add_foreign_key "issue_histories", "branches"
  add_foreign_key "issue_histories", "repositories"
  add_foreign_key "issue_ignore_rules", "repositories"
  add_foreign_key "issue_ignore_rules", "users"
  add_foreign_key "issues", "commits"
  add_foreign_key "issues", "issue_ignore_rules", column: "ignore_rule_id"
  add_foreign_key "issues", "users", column: "ignore_user_id"
  add_foreign_key "private_keys", "repositories"
  add_foreign_key "repository_members", "repositories"
  add_foreign_key "secrets", "repositories"
  add_foreign_key "secrets", "users", column: "owner_id"
  add_foreign_key "service_tokens", "users", column: "owner_id"
  add_foreign_key "user_emails", "users"
  add_foreign_key "user_tokens", "users"
end
