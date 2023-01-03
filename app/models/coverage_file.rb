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
class CoverageFile < ApplicationRecord
  validates :raw_data, presence: true
  validates :file, presence: true
  validates :lines_covered, presence: true
  validates :lines_missed, presence: true
  validates :lines_total, presence: true
  validates :percent_covered, presence: true

  belongs_to :coverage, class_name: :CoverageInfo, foreign_key: :coverage_info_id, inverse_of: :files

  def apply_lines(lines)
    accountable_lines = lines.filter { _1.is_a? Numeric }
    self.lines_total = accountable_lines.length
    self.lines_missed = accountable_lines.count(&:zero?)
    self.lines_covered = accountable_lines.count(&:positive?)
    self.percent_covered = lines_total.zero? ? 0 : ((lines_covered.to_f / lines_total) * 100)
  end
end
