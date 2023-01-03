# frozen_string_literal: true

# == Schema Information
#
# Table name: commits
#
#  id               :bigint           not null, primary key
#  repository_id    :bigint           not null
#  sha              :citext           not null
#  author_name      :string           not null
#  author_email     :string           not null
#  message          :text             not null
#  user_id          :bigint
#  checks_status    :integer          not null
#  coverage_status  :integer          not null
#  issues_count     :integer
#  coverage_percent :integer
#  clone_status     :integer          not null
#  check_job_id     :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_commits_on_check_job_id           (check_job_id)
#  index_commits_on_repository_id          (repository_id)
#  index_commits_on_sha                    (sha)
#  index_commits_on_sha_and_repository_id  (sha,repository_id) UNIQUE
#  index_commits_on_user_id                (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (repository_id => repositories.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :commit do
    sha { SecureRandom.hex(32) }
    author_name { Faker::Name.name }
    author_email { Faker::Internet.safe_email }
    message { "Commit message" }
    user_id { nil }
    checks_status { :queued }
    coverage_status { :queued }
    issues_count { 0 }
    coverage_percent { 0 }
    clone_status { 0 }

    trait :with_repository do
      repository { create(:repository) }
    end

    trait :with_user do
      user { create(:user) }
    end
  end
end
