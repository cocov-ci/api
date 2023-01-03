# frozen_string_literal: true

# == Schema Information
#
# Table name: coverage_histories
#
#  id            :bigint           not null, primary key
#  repository_id :bigint           not null
#  branch_id     :bigint           not null
#  percentage    :float            not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_coverage_histories_on_branch_id      (branch_id)
#  index_coverage_histories_on_created_at     (created_at)
#  index_coverage_histories_on_repository_id  (repository_id)
#
# Foreign Keys
#
#  fk_rails_...  (branch_id => branches.id)
#  fk_rails_...  (repository_id => repositories.id)
#
FactoryBot.define do
  factory :coverage_history do
    repository { nil }
    percentage { 1.5 }
    branch { nil }
  end
end
