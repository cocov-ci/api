# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id            :bigint           not null, primary key
#  login         :citext           not null
#  github_id     :integer          not null
#  admin         :boolean          default(FALSE), not null
#  github_token  :text             not null
#  github_scopes :text             not null
#  avatar_url    :text
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_users_on_github_id  (github_id) UNIQUE
#  index_users_on_login      (login) UNIQUE
#
require "rails_helper"

RSpec.describe User do
  subject(:user) { build(:user) }

  it_behaves_like "a validated model", %i[
    login
    github_id
    github_token
    github_scopes
  ]

  it "does not allow duplicated github ids" do
    user.save!
    other = build(:user, github_id: user.github_id)
    expect(other).not_to be_valid
  end

  it "does not allow duplicated logins" do
    user.save!
    other = build(:user, login: user.login)
    expect(other).not_to be_valid
  end
end
