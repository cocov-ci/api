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
require "rails_helper"

RSpec.describe Check do
  subject(:check) { build(:check, :with_commit) }

  it_behaves_like "a validated model", %i[
    check_set
    status
    plugin_name
  ]

  it "requires started_at when not waiting" do
    check.status = :in_progress
    expect(check).not_to be_valid

    check.started_at = Time.zone.now
    expect(check).to be_valid
  end

  it "requires finished_at when completed" do
    check.status = :completed
    check.started_at = Time.zone.now
    expect(check).not_to be_valid

    check.status = :errored
    check.started_at = Time.zone.now
    check.error_output = "bla"
    expect(check).not_to be_valid

    check.status = :completed
    check.finished_at = Time.zone.now
    expect(check).to be_valid

    check.status = :errored
    check.finished_at = Time.zone.now
    check.error_output = "bla"
    expect(check).to be_valid
  end

  it "requires error_output when errored" do
    check.status = :errored
    check.started_at = Time.zone.now
    check.finished_at = Time.zone.now
    expect(check).not_to be_valid

    check.error_output = "bla"
    expect(check).to be_valid
  end
end
