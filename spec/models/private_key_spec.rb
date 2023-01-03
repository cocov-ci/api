# frozen_string_literal: true

# == Schema Information
#
# Table name: private_keys
#
#  id            :bigint           not null, primary key
#  scope         :integer          not null
#  repository_id :bigint
#  name          :citext           not null
#  encrypted_key :binary           not null
#  digest        :text             not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_private_keys_on_name                              (name)
#  index_private_keys_on_repository_id                     (repository_id)
#  index_private_keys_on_scope                             (scope)
#  index_private_keys_on_scope_and_name_and_repository_id  (scope,name,repository_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (repository_id => repositories.id)
#
require "rails_helper"

RSpec.describe PrivateKey do
  subject(:key) { build(:private_key) }

  before { stub_crypto_key! }

  it_behaves_like "a validated model", %i[
    scope
    name
    encrypted_key
  ]

  describe "uniqueness" do
    it "is guaranteed for name + scope" do
      key.save!
      new_subject = build(:private_key, name: key.name)
      expect(new_subject).not_to be_valid

      repo = create(:repository)
      other_subject = build(:private_key, name: key.name, scope: :repository, repository: repo)
      expect(other_subject).to be_valid
    end

    it "is guaranteed for name + scope + repo" do
      repo = create(:repository)
      key.scope = :repository
      key.repository = repo
      key.save!

      new_subject = build(:private_key, name: key.name, scope: :repository, repository: repo)
      expect(new_subject).not_to be_valid

      other_subject = build(:private_key, name: key.name)
      expect(other_subject).to be_valid
    end
  end
end
