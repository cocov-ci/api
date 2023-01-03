# frozen_string_literal: true

# == Schema Information
#
# Table name: coverage_files
#
#  id               :bigint           not null, primary key
#  coverage_info_id :bigint           not null
#  file             :string           not null
#  percent_covered  :integer          not null
#  raw_data         :binary           not null
#  lines_missed     :integer          not null
#  lines_covered    :integer          not null
#  lines_total      :integer          not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_coverage_files_on_coverage_info_id  (coverage_info_id)
#
# Foreign Keys
#
#  fk_rails_...  (coverage_info_id => coverage_infos.id)
#
FactoryBot.define do
  factory :coverage_file do
    coverage { nil }
    file { "foo/bar.rb" }
    percent_covered { 50 }
    raw_data { "0\0" }
    lines_missed { 1 }
    lines_covered { 1 }
    lines_total { 2 }

    trait :with_coverage do
      coverage { create(:coverage_info, :with_commit) }
    end
  end
end
