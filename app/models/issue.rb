# frozen_string_literal: true

# == Schema Information
#
# Table name: issues
#
#  id            :bigint           not null, primary key
#  commit_id     :bigint           not null
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
#  index_issues_on_commit_id          (commit_id)
#  index_issues_on_uid                (uid)
#  index_issues_on_uid_and_commit_id  (uid,commit_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (commit_id => commits.id)
#
class Issue < ApplicationRecord
  include IssueFields

  enum status: { new: 0, resolved: 1, ignored: 2 }, _prefix: :status
  validates :status, presence: true

  validates :uid, presence: true, uniqueness: { scope: :commit_id }
  belongs_to :commit, counter_cache: true

  before_validation :ensure_status

  private

  def ensure_status
    self.status = :new if status.blank?
  end
end
