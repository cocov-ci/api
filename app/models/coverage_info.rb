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
  enum status: {
    waiting: 0,
    queued: 1,
    in_progress: 2,
    completed: 3,
    errored: 4
  }.freeze

  before_validation :ensure_status

  validates :status, presence: true
  validates :commit, uniqueness: true

  belongs_to :commit
  has_many :files, class_name: :CoverageFile, dependent: :destroy

  def reset!(status: nil)
    transaction do
      files.destroy_all
      if status.nil?
        waiting!
      else
        self.status = status
        save!
      end
    end
    true
  end

  private

  def ensure_status
    self.status = :waiting if status.blank?
  end
end
