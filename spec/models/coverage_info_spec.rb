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
require "rails_helper"

RSpec.describe CoverageInfo do
  subject { build(:coverage_info, :with_commit) }

  it_behaves_like "a validated model", [
    :commit
  ]
end
