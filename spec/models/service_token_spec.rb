# frozen_string_literal: true

# == Schema Information
#
# Table name: service_tokens
#
#  id           :bigint           not null, primary key
#  hashed_token :text             not null
#  description  :text             not null
#  owner_id     :bigint           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  last_used_at :datetime
#
# Indexes
#
#  index_service_tokens_on_hashed_token  (hashed_token) UNIQUE
#  index_service_tokens_on_owner_id      (owner_id)
#
# Foreign Keys
#
#  fk_rails_...  (owner_id => users.id)
#
require "rails_helper"

RSpec.describe ServiceToken do
  subject(:token) { build(:service_token, :with_owner) }

  it_behaves_like "a model using LastUsageTracker"
  it_behaves_like "a validated model", %i[
    owner
    description
  ]

  it "does not allow duplicated tokens" do
    token.save!
    other = build(:service_token, value: token.value)
    expect(other).not_to be_valid
  end

  it "finds a token" do
    token.save!
    reloaded = described_class.by_token(token.value)
    expect(reloaded.id).to eq token.id
  end

  it "reports its type correctly" do
    expect(token).to be_service
    expect(token).not_to be_auth
    expect(token).not_to be_personal
    expect(token.kind).to eq :service
  end
end
