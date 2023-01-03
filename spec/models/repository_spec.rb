# frozen_string_literal: true

# == Schema Information
#
# Table name: repositories
#
#  id             :bigint           not null, primary key
#  name           :citext           not null
#  description    :text
#  default_branch :citext           not null
#  token          :text             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_repositories_on_name   (name) UNIQUE
#  index_repositories_on_token  (token) UNIQUE
#
require "rails_helper"

RSpec.describe Repository do
  subject(:repo) { build(:repository) }

  it_behaves_like "a validated model", %i[
    name
    default_branch
  ]

  it "automatically assigns a default token" do
    repo.token = nil
    expect(repo).to be_valid
    expect(repo.token).not_to be_blank
  end
end
