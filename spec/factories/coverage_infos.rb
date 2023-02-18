# frozen_string_literal: true

# == Schema Information
#
# Table name: coverage_infos
#
#  id              :bigint           not null, primary key
#  commit_id       :bigint           not null
#  percent_covered :float
#  lines_total     :integer
#  lines_covered   :integer
#  status          :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_coverage_infos_on_commit_id  (commit_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (commit_id => commits.id)
#
FactoryBot.define do
  factory :coverage_info do
    percent_covered { 50 }
    lines_total { 100 }
    status { :waiting }

    trait :with_commit do
      commit { create(:commit, :with_repository) }
    end

    trait :with_file do
      after :create do |cov|
        create(:coverage_file, coverage: cov)
      end
    end
  end
end
