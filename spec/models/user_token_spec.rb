# frozen_string_literal: true

# == Schema Information
#
# Table name: user_tokens
#
#  id           :bigint           not null, primary key
#  user_id      :bigint           not null
#  kind         :integer          not null
#  hashed_token :text             not null
#  expires_at   :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  last_used_at :datetime
#
# Indexes
#
#  index_user_tokens_on_hashed_token  (hashed_token) UNIQUE
#  index_user_tokens_on_user_id       (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require "rails_helper"

RSpec.describe UserToken do
  subject(:token) { build(:user_token, :with_user) }

  it_behaves_like "a model using LastUsageTracker"
  it_behaves_like "a validated model", %i[
    user
    kind
  ]

  it "does not allow duplicated tokens" do
    token.save!
    other = build(:user_token, value: token.value)
    expect(other).not_to be_valid
  end

  it "finds a token" do
    token.save!
    reloaded = described_class.by_token(token.value)
    expect(reloaded.id).to eq token.id
  end

  it "correctly reports its type" do
    expect(token).to be_auth
    expect(token).not_to be_personal
    expect(token).not_to be_service

    token.kind = :personal
    expect(token).not_to be_auth
    expect(token).to be_personal
    expect(token).not_to be_service
  end
end
