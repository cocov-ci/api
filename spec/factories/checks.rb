# frozen_string_literal: true

# == Schema Information
#
# Table name: checks
#
#  id           :bigint           not null, primary key
#  plugin_name  :citext           not null
#  started_at   :datetime
#  finished_at  :datetime
#  status       :integer          not null
#  error_output :text
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  check_set_id :bigint           not null
#
# Indexes
#
#  index_checks_on_check_set_id                  (check_set_id)
#  index_checks_on_plugin_name_and_check_set_id  (plugin_name,check_set_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (check_set_id => check_sets.id)
#
FactoryBot.define do
  factory :check do
    plugin_name { Faker::Science.tool }
    status { :waiting }
    check_set { nil }

    transient do
      commit { nil }
    end

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

    after(:build) do |check, evaluator|
      next unless evaluator.commit

      evaluator.commit.create_check_set if evaluator.commit.check_set.nil?

      check.check_set_id = evaluator.commit.check_set.id
    end
  end
end
