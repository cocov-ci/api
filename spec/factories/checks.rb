# frozen_string_literal: true

# == Schema Information
#
# Table name: checks
#
#  id           :bigint           not null, primary key
#  commit_id    :bigint           not null
#  plugin_name  :citext           not null
#  started_at   :datetime
#  finished_at  :datetime
#  status       :integer          not null
#  error_output :text
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_checks_on_commit_id                  (commit_id)
#  index_checks_on_commit_id_and_plugin_name  (commit_id,plugin_name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (commit_id => commits.id)
#
FactoryBot.define do
  factory :check do
    commit { nil }
    plugin_name { Faker::Science.tool }
    status { :waiting }

    trait :running do
      status { :running }
      started_at { Time.zone.now }
    end

    trait :succeeded do
      status { :succeeded }
      started_at { 30.seconds.ago }
      finished_at { Time.zone.now }
    end

    trait :errored do
      status { :errored }
      started_at { 30.seconds.ago }
      finished_at { Time.zone.now }
      error_output { "Process exited with status 127" }
    end

    trait :with_commit do
      commit { create(:commit, :with_repository) }
    end
  end
end
