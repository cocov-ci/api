# frozen_string_literal: true

# == Schema Information
#
# Table name: checks
#
#  id           :bigint           not null, primary key
#  plugin_name  :citext           not null
#  started_at   :datetime
#  finished_at  :datetime
#  status       :integer          not null
#  error_output :text
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  check_set_id :bigint           not null
#
# Indexes
#
#  index_checks_on_check_set_id                  (check_set_id)
#  index_checks_on_plugin_name_and_check_set_id  (plugin_name,check_set_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (check_set_id => check_sets.id)
#
class Check < ApplicationRecord
  enum status: { waiting: 0, running: 1, succeeded: 2, errored: 3 }

  belongs_to :check_set
  validates :status, presence: true
  validates :plugin_name, presence: true, uniqueness: { scope: [:check_set] }
  validates :error_output, presence: true, if: -> { errored? }
  validates :finished_at, presence: true, if: -> { succeeded? || errored? }
  validates :started_at, presence: true, if: -> { !waiting? }
end
