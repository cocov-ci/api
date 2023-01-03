# frozen_string_literal: true

# == Schema Information
#
# Table name: checks
#
#  id           :bigint           not null, primary key
#  commit_id    :bigint           not null
#  plugin_name  :citext           not null
#  started_at   :datetime
#  finished_at  :datetime
#  status       :integer          not null
#  error_output :text
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_checks_on_commit_id                  (commit_id)
#  index_checks_on_commit_id_and_plugin_name  (commit_id,plugin_name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (commit_id => commits.id)
#
class Check < ApplicationRecord
  enum status: { waiting: 0, running: 1, succeeded: 2, errored: 3 }

  belongs_to :commit
  validates :status, presence: true
  validates :plugin_name, presence: true, uniqueness: { scope: [:commit] }
  validates :error_output, presence: true, if: -> { errored? }
  validates :finished_at, presence: true, if: -> { succeeded? || errored? }
  validates :started_at, presence: true, if: -> { !waiting? }
end
