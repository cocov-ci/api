# frozen_string_literal: true

# == Schema Information
#
# Table name: issues
#
#  id            :bigint           not null, primary key
#  commit_id     :bigint           not null
#  assignee_id   :bigint
#  kind          :integer          not null
#  status        :integer          not null
#  status_reason :text
#  file          :string           not null
#  uid           :citext           not null
#  line_start    :integer          not null
#  line_end      :integer          not null
#  message       :string           not null
#  check_source  :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_issues_on_assignee_id        (assignee_id)
#  index_issues_on_commit_id          (commit_id)
#  index_issues_on_uid                (uid)
#  index_issues_on_uid_and_commit_id  (uid,commit_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (assignee_id => users.id)
#  fk_rails_...  (commit_id => commits.id)
#
class Issue < ApplicationRecord
  enum kind: {
    style: 0,
    performance: 1,
    security: 2,
    bug: 3,
    complexity: 4,
    duplication: 5,
    convention: 6,
    quality: 7
  }
  enum status: { new: 0, resolved: 1, ignored: 2 }, _prefix: :status

  before_validation :ensure_status

  validates :check_source, presence: true
  validates :status, presence: true
  validates :file, presence: true
  validates :kind, presence: true
  validates :line_end, presence: true
  validates :line_start, presence: true
  validates :message, presence: true
  validates :uid, presence: true, uniqueness: { scope: :commit_id }

  belongs_to :commit, counter_cache: true
  belongs_to :assignee, class_name: :User, optional: true

  def assign!(user)
    self.assignee = user
    save!
  end

  private

  def ensure_status
    self.status = :new if status.blank?
  end
end
