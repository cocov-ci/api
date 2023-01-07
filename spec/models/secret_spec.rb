# frozen_string_literal: true

# == Schema Information
#
# Table name: secrets
#
#  id            :bigint           not null, primary key
#  scope         :integer          not null
#  name          :citext           not null
#  repository_id :bigint
#  secure_data   :binary           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  last_used_at  :datetime
#  owner_id      :bigint           not null
#
# Indexes
#
#  index_secrets_on_name                              (name)
#  index_secrets_on_owner_id                          (owner_id)
#  index_secrets_on_repository_id                     (repository_id)
#  index_secrets_on_scope                             (scope)
#  index_secrets_on_scope_and_name_and_repository_id  (scope,name,repository_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (owner_id => users.id)
#  fk_rails_...  (repository_id => repositories.id)
#
require "rails_helper"

RSpec.describe Secret do
  subject(:secret) do
    user = create(:user)
    build(:secret, owner: user)
  end

  before { stub_crypto_key! }

  it_behaves_like "a validated model", %i[
    scope
    name
    data
    owner
  ]

  describe "uniqueness" do
    it "is guaranteed for name + scope" do
      secret.save!
      new_subject = build(:secret, :with_owner, name: secret.name)
      expect(new_subject).not_to be_valid

      repo = create(:repository)
      other_subject = build(:secret, :with_owner, name: secret.name, scope: :repository, repository: repo)
      expect(other_subject).to be_valid
    end

    it "is guaranteed for name + scope + repo" do
      repo = create(:repository)
      secret.scope = :repository
      secret.repository = repo
      secret.save!

      new_subject = build(:secret, :with_owner, name: secret.name, scope: :repository, repository: repo)
      expect(new_subject).not_to be_valid

      other_subject = build(:secret, :with_owner, name: secret.name)
      expect(other_subject).to be_valid
    end
  end

  it "saves and loads data" do
    secret.save!

    loaded = described_class.find(secret.id)
    expect(loaded.data).to eq secret.data
  end

  it "handles authorizations" do
    mock_redis!

    secret.save!

    auth = secret.generate_authorization
    expect(auth).to start_with("csa_")

    recovered = described_class.from_authorization(auth)
    expect(recovered.id).to eq secret.id
  end
end
