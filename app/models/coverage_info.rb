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
class CoverageInfo < ApplicationRecord
  enum status: { updating: 0, ready: 1 }

  before_validation :ensure_status

  validates :status, presence: true
  validates :commit, uniqueness: true

  belongs_to :commit
  has_many :files, class_name: :CoverageFile, dependent: :destroy

  private

  def ensure_status
    self.status = :updating if status.blank?
  end
end
