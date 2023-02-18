# frozen_string_literal: true

# == Schema Information
#
# Table name: check_sets
#
#  id         :bigint           not null, primary key
#  commit_id  :bigint           not null
#  status     :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_check_sets_on_commit_id  (commit_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (commit_id => commits.id)
#
class CheckSet < ApplicationRecord
  enum status: {
    waiting: 0,
    queued: 1,
    processing: 2,
    processed: 3,
    errored: 4,
    not_configured: 5
  }

  belongs_to :commit
  has_many :checks, dependent: :destroy

  before_validation :ensure_status

  def reset!
    transaction do
      self.status = :waiting
      checks.destroy_all!
      commit.issues.destroy_all!
    end
    true
  end

  def ensure_status
    self.status = :waiting if status.blank?
  end
end
