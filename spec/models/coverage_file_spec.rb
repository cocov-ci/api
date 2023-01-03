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
require "rails_helper"

RSpec.describe CoverageFile do
  subject { create(:coverage_file, :with_coverage) }

  it_behaves_like "a validated model", %i[
    raw_data
    file
    lines_covered
    lines_missed
    lines_total
    percent_covered
    coverage
  ]
end
